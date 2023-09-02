from stream import stream_encode
from enum import Enum
from typing import List
from utils import Logger

ToServerLog = Logger('TO-SERVER')
ToClientLog = Logger('TO-CLIENT')

class Messages:
    CONNECT_ME = 'CONNECT_ME'

class GameServerMessages:
    CONNECT_SELF = 'CONNECT_SELF'
    CONNECT_OTHER = 'CONNECT_OTHER'
    DISCONNECT = 'DISCONNECT'

class Client:
    def __init__(self, uid, handler, websocket, data):
        self.uid = uid
        self.unreliableFastWT = handler
        self.reliableWS = websocket
        self.data = data

    def __str__(self):
        return f'Client({self.__dict__}'


uid_sequence = 0
clients: List[Client] = []
game_server_reader = None
game_server_writer = None
game_client_websocket = None
game_client_web_transport = None


def get_next_uid_sequence() -> int:
    global uid_sequence
    return uid_sequence + 1

def handle_client_connected(websocket):
    global uid_sequence, clients
    # uid_sequence += 1
    client = Client(None, None, websocket, None)
    # print(f'add_client {client.uid}')
    # print(client.handler)
    # print(f'CounterHandler({client.handler.__dict__}')
    clients.append(client)
    # send_message_others(f'{client.uid}|CONNECT_OTHER', client.uid)
    # client.handler.send_datagram(f'{client.uid}|CONNECT_SELF')
    return client

def get_client_by_ws(ws) -> Client:
    global clients
    # print(f'get_client_by_ws clients: {len(clients)}')
    for c in clients:
        if c.reliableWS is ws:
            return c

async def handle_client_disconnected(websocket):
    global clients
    client = get_client_by_ws(websocket)
    clients.remove(client)
    print(f'{client.__dict__} {len(clients)}')
    msg = f'{client.uid}.{GameServerMessages.DISCONNECT}'
    await send_message_all(msg)
    to_game_server(msg)

async def send_message_all(msg: str) -> None:
    global clients
    for client in clients:
        await client.reliableWS.send(msg)

async def send_message_others(msg: str, c_uid: int) -> None:
    global clients
    for client in clients:
        if client.uid != c_uid:
            await client.reliableWS.send(msg)


def set_game_server_communication(reader, writer):
    global game_server_reader, game_server_writer
    game_server_reader = reader
    game_server_writer = writer


def to_game_server(msg):
    global game_server_reader, prev_msg
    if game_server_writer is not None:
        ToServerLog.print(msg)
        out_data = stream_encode(msg)
        game_server_writer.write(out_data)


def set_game_client_communication_websocket(websocket) -> Client:
    global game_client_websocket
    game_client_websocket = websocket
    return handle_client_connected(websocket)

def set_game_client_communication_web_transport(web_transport):
    global game_client_web_transport
    game_client_web_transport = web_transport

async def to_game_client(msg):
    global game_client_websocket, game_client_web_transport

    if game_client_websocket is not None:
        ToClientLog.print(msg)
        if GameServerMessages.CONNECT_SELF in msg:
            client = get_client_by_ws(game_client_websocket)
            client.uid = int(msg[:msg.index('.')])
            client.unreliableFastWT = game_client_web_transport
            # print(client.uid)
            await game_client_websocket.send(msg)
        elif GameServerMessages.CONNECT_OTHER in msg or "GO" in msg:
            await send_message_others(msg, int(msg[:msg.index('.')]))
        else:
            await send_message_all(msg)
