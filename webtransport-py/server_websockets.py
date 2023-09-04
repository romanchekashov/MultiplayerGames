import asyncio
import random
import websockets
import json

from broadsock import set_game_client_communication_websocket, handle_client_disconnected, to_game_server
from utils import getLogger

Log = getLogger(__name__)

async def handler(websocket):

    client = set_game_client_communication_websocket(websocket)
    # create periodic task:
    # asyncio.create_task(send(websocket))

    while True:
        try:
            message = await websocket.recv()
            if client.uid is None:
                to_game_server(message)
            else:
                to_game_server(f'{client.uid}.{message}')

        # client disconnected?
        except websockets.ConnectionClosedOK:
            Log.info(f'websocket DISCONECT {websocket}')
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

async def run_server_websockets(host, port):
    Log.info("[WebSockets] Listening on ws://{}:{}".format(host, port))
    await websockets.serve(handler, host, port)
    # async with websockets.serve(handler, host, port):
    #     print("[WebSockets] Listening on ws://{}:{}".format(host, port))
    #     await asyncio.Future()  # run forever
