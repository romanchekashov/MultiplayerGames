import argparse
import asyncio
import logging
from utils import getLogger
from collections import defaultdict
from typing import Dict, Optional

from aioquic.asyncio import QuicConnectionProtocol, serve
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import H3Event, HeadersReceived, WebTransportStreamDataReceived, DatagramReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.connection import stream_is_unidirectional
from aioquic.quic.events import ProtocolNegotiated, StreamReset, QuicEvent

from broadsock import to_game_server, Client
from broadsock import set_game_client_communication_web_transport
from datetime import datetime


Log = getLogger(__name__)

# difference = (datetime.now() - now).total_seconds()

# CounterHandler implements a really simple protocol:
#   - For every incoming bidirectional stream, it counts bytes it receives on
#     that stream until the stream is closed, and then replies with that byte
#     count on the same stream.
#   - For every incoming unidirectional stream, it counts bytes it receives on
#     that stream until the stream is closed, and then replies with that byte
#     count on a new unidirectional stream.
#   - For every incoming datagram, it sends a datagram with the length of
#     datagram that was just received.
class CounterHandler:

    def __init__(self, session_id, http: H3Connection) -> None:
        self._session_id = session_id
        self._http = http
        self._counters = defaultdict(int)
        self._encoding = 'ascii'
        self.client = None
        self.now = datetime.now()
        # self._encoding = 'utf-8'
    
    def send_datagram(self, data) -> None:
        payload = str(data).encode(self._encoding)
        self._http.send_datagram(self._session_id, payload) # remove b'<str_bytes>'
        # self._http.send_datagram(self._session_id, payload[2:-1]) # remove b'<str_bytes>'

    def h3_event_received(self, event: H3Event) -> None:
        if isinstance(event, DatagramReceived):
            msg = event.data.decode(self._encoding)
            if 'BIND_WT_CONNECTION' in msg:
                self.client = set_game_client_communication_web_transport(int(msg.split('.')[1]), self)
                Log.info(f'handler: WT = {id(self)}: client = {self.client}')
                self.send_datagram(f'BIND_WT_CONNECTED.{self.client.uid}')
            elif self.client:
                if msg == 'PING':
                    self.client.wt_latency = int((datetime.now() - self.now).total_seconds() * 1000 / 2)
                    # Log.info(f'{self.client.wt_latency}, {(datetime.now() - self.now).total_seconds()}')
                else:
                    to_game_server(msg, self.client)
                
                if (datetime.now() - self.now).total_seconds() > 5:
                    self.now = datetime.now()
                    self.send_datagram('PING')

        if isinstance(event, WebTransportStreamDataReceived):
            self._counters[event.stream_id] += len(event.data)
            if event.stream_ended:
                if stream_is_unidirectional(event.stream_id):
                    response_id = self._http.create_webtransport_stream(
                        self._session_id, is_unidirectional=True)
                else:
                    response_id = event.stream_id
                payload = str(self._counters[event.stream_id]).encode(self._encoding)
                self._http._quic.send_stream_data(
                    response_id, payload, end_stream=True)
                self.stream_closed(event.stream_id)

    def stream_closed(self, stream_id: int) -> None:
        try:
            del self._counters[stream_id]
        except KeyError:
            pass
