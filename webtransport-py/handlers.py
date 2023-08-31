import argparse
import asyncio
import logging
from collections import defaultdict
from typing import Dict, Optional

from aioquic.asyncio import QuicConnectionProtocol, serve
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import H3Event, HeadersReceived, WebTransportStreamDataReceived, DatagramReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.connection import stream_is_unidirectional
from aioquic.quic.events import ProtocolNegotiated, StreamReset, QuicEvent

from broadsock import send_message_others

logger = logging.getLogger(__name__)

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

    def __init__(self, session_id, http: H3Connection, client_uid: int) -> None:
        self._session_id = session_id
        self._http = http
        self._counters = defaultdict(int)
        self._encoding = 'ascii'
        self.client_uid = client_uid
        # self._encoding = 'utf-8'
    
    def send_datagram(self, data) -> None:
        payload = str(data).encode(self._encoding)
        self._http.send_datagram(self._session_id, payload[2:-1]) # remove b'<str_bytes>'

    def h3_event_received(self, event: H3Event) -> None:
        if isinstance(event, DatagramReceived):
            if 'PLAYER_READY' == event.data.decode(self._encoding):
                send_message_others(f'{self.client_uid}|CONNECT_OTHER', self.client_uid)
                self.send_datagram(f'{self.client_uid}|CONNECT_SELF')

            self.send_datagram(event.data)

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
