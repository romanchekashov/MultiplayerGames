#!/usr/bin/env python3

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""
An example WebTransport over HTTP/3 server based on the aioquic library.
Processes incoming streams and datagrams, and
replies with the ASCII-encoded length of the data sent in bytes.
Example use:
  python3 webtransport_server.py certificate.pem certificate.key
Example use from JavaScript:
  let transport = new WebTransport("https://localhost:4433/counter");
  await transport.ready;
  let stream = await transport.createBidirectionalStream();
  let encoder = new TextEncoder();
  let writer = stream.writable.getWriter();
  await writer.write(encoder.encode("Hello, world!"))
  writer.close();
  console.log(await new Response(stream.readable).text());
This will output "13" (the length of "Hello, world!") into the console.
"""

# ---- Dependencies ----
#
# This server only depends on Python standard library and aioquic 0.9.19 or
# later. See https://github.com/aiortc/aioquic for instructions on how to
# install aioquic.
#
# ---- Certificates ----
#
# HTTP/3 always operates using TLS, meaning that running a WebTransport over
# HTTP/3 server requires a valid TLS certificate.  The easiest way to do this
# is to get a certificate from a real publicly trusted CA like
# <https://letsencrypt.org/>.
# https://developers.google.com/web/fundamentals/security/encrypt-in-transit/enable-https
# contains a detailed explanation of how to achieve that.
#
# As an alternative, Chromium can be instructed to trust a self-signed
# certificate using command-line flags.  Here are step-by-step instructions on
# how to do that:
#
#   1. Generate a certificate and a private key:
#         openssl req -newkey rsa:2048 -nodes -keyout certificate.key \
#                   -x509 -out certificate.pem -subj '/CN=Test Certificate' \
#                   -addext "subjectAltName = DNS:localhost"
#
#   2. Compute the fingerprint of the certificate:
#         openssl x509 -pubkey -noout -in certificate.pem |
#                   openssl rsa -pubin -outform der |
#                   openssl dgst -sha256 -binary | base64
#      The result should be a base64-encoded blob that looks like this:
#          "Gi/HIwdiMcPZo2KBjnstF5kQdLI5bPrYJ8i3Vi6Ybck="
#
#   3. Pass a flag to Chromium indicating what host and port should be allowed
#      to use the self-signed certificate.  For instance, if the host is
#      localhost, and the port is 4433, the flag would be:
#         --origin-to-force-quic-on=localhost:4433
#
#   4. Pass a flag to Chromium indicating which certificate needs to be trusted.
#      For the example above, that flag would be:
#         --ignore-certificate-errors-spki-list=Gi/HIwdiMcPZo2KBjnstF5kQdLI5bPrYJ8i3Vi6Ybck=
#
# See https://www.chromium.org/developers/how-tos/run-chromium-with-flags for
# details on how to run Chromium with flags.
import os
import argparse
import asyncio
import aioquic
from collections import defaultdict
from typing import Dict, Optional

from aioquic.asyncio import QuicConnectionProtocol, serve
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import H3Event, HeadersReceived, WebTransportStreamDataReceived, DatagramReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.connection import stream_is_unidirectional
from aioquic.quic.events import ProtocolNegotiated, StreamReset, QuicEvent
from server_websockets import run_server_websockets
from server_game_connector import run_game_server_connector

from dotenv import load_dotenv
from pathlib import Path

from protocols import WebTransportProtocol
from utils import getLogger
from server_game import set_event_loop, _terminate_game_server

Log = getLogger(__name__)

dotenv_path = Path('../.env.local')
# dotenv_path = Path('.env.local')
load_dotenv(dotenv_path=dotenv_path)

# BIND_ADDRESS = '::1'
# BIND_ADDRESS = 'game.look.ovh'
BIND_PORT = 4433

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    # parser.add_argument('bind_address')
    parser.add_argument('certificate')
    parser.add_argument('key')
    args = parser.parse_args()
    
    # BIND_ADDRESS = args.bind_address
    BIND_ADDRESS = os.environ['BIND_ADDRESS']

    _terminate_game_server()

    configuration = QuicConfiguration(
        alpn_protocols=H3_ALPN,
        is_client=False,
        max_datagram_frame_size=65536,
    )
    configuration.load_cert_chain(args.certificate, args.key)

    event_loop = asyncio.get_event_loop()
    set_event_loop(event_loop)
    event_loop.create_task(
        serve(
            BIND_ADDRESS,
            BIND_PORT,
            configuration=configuration,
            create_protocol=WebTransportProtocol,
        ))
    # loop.create_task(run_game_server_connector(socket.gethostname(), 5001))
    event_loop.create_task(run_game_server_connector('127.0.0.1', 5001))
    event_loop.create_task(run_server_websockets(BIND_ADDRESS, 5002, args.certificate, args.key))
    
    try:
        Log.info("[WebTransport] Listening on https://{}:{}".format(BIND_ADDRESS, BIND_PORT))
        event_loop.run_forever()
    except KeyboardInterrupt:
        pass