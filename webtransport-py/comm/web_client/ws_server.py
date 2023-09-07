import asyncio
import random
import websockets
import json
import ssl

from broadsock import set_game_client_communication_websocket, handle_client_disconnected, to_game_server
from utils import getLogger

Log = getLogger(__name__)

async def handler(websocket):

    client = set_game_client_communication_websocket(websocket)
    Log.info(f'handler: websocket = {id(websocket)}: client = {client}')
    # create periodic task:
    # asyncio.create_task(send(websocket))

    while True:
        try:
            message = await websocket.recv()
            Log.debug(f'websocket = {id(websocket)}, latency = {websocket.latency}: client = {client}')
            to_game_server(message, client)
        # client disconnected?
        except (websockets.ConnectionClosedOK, websockets.ConnectionClosedError):
            Log.debug(f'DISCONECT: websocket {id(websocket)}, client {client}')
            await handle_client_disconnected(websocket)
            break


# async def send(websocket):
#     while True:
#         data = [
#             {"name": "Random Int 1", "number": random.randint(0, 1000)},
#             {"name": "Random Int 2", "number": random.randint(1001, 2000)},
#             {"name": "Random Int 3", "number": random.randint(2001, 3000)},
#         ]

#         try:
#             await websocket.send(json.dumps(data))

#         # client disconnected?
#         except websockets.ConnectionClosedOK:
#             break

#         await asyncio.sleep(0.5)

async def run_server_websockets(host, port, ssl_cert, ssl_key):
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ssl_context.load_cert_chain(ssl_cert, keyfile=ssl_key)

    Log.info("[WebSockets] Listening on wss://{}:{}".format(host, port))
    await websockets.serve(handler, host, port, ssl=ssl_context)
    # async with websockets.serve(handler, host, port):
    #     print("[WebSockets] Listening on ws://{}:{}".format(host, port))
    #     await asyncio.Future()  # run forever
