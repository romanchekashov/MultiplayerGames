from stream import stream_encode
from enum import Enum
from typing import List
from utils import getLogger

from server_game import start_game_server, stop_game_server

Log = getLogger(__name__)

class Messages:
    CONNECT_ME = 'CONNECT_ME'

class GameServerMessages:
    CONNECT_SELF = 'CONNECT_SELF'
    CONNECT_OTHER = 'CONNECT_OTHER'
    DISCONNECT = 'DISCONNECT'

class Client:
    def __init__(self, uid, web_transport, websocket, data):
        self.uid = uid
        self.unreliableFastWT = web_transport
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

def has_connected_clients() -> bool:
    return len(clients) > 0

def get_client_by_ws(ws) -> Client:
    global clients
    # Log.info(f'get_client_by_ws clients: {len(clients)}')
    for c in clients:
        if c.reliableWS is ws:
            return c

def get_client_by_wt(wt) -> Client:
    global clients
    # Log.info(f'get_client_by_ws clients: {len(clients)}')
    for c in clients:
        if c.unreliableFastWT is wt:
            return c

def handle_client_connected(websocket, web_transport):
    global uid_sequence, clients
    if websocket is not None:
        client = get_client_by_ws(websocket)
    if client is None and web_transport is not None:
        client = get_client_by_wt(web_transport)
    # uid_sequence += 1
    if client is None:
        client = Client(None, web_transport, websocket, None)
        clients.append(client)
        Log.info(f'connected: clients = {len(clients)}')
    
    if websocket is not None:
        client.reliableWS = websocket
    if web_transport is not None:
        client.unreliableFastWT = web_transport

    if len(clients) > 0:
        start_game_server()

    return client

async def handle_client_disconnected(websocket):
    global clients
    Log.info(f'disconnected: clients = {len(clients)}')
    if len(clients) == 0:
        return
    client = get_client_by_ws(websocket)
    clients.remove(client)
    Log.info(f'{client.__dict__} {len(clients)}')
    msg = f'{client.uid}.{GameServerMessages.DISCONNECT}'

    if len(clients) == 0:
        Log.info(f'clients = {len(clients)}: Need stop game server')
        stop_game_server()
    else:
        await send_message_all(msg)
        to_game_server(msg)

async def send_message_all(msg: str, fast) -> None:
    global clients
    for client in clients:
        if fast is not None and client.unreliableFastWT is not None:
            client.unreliableFastWT.send_datagram(msg)
        else:
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
    global game_server_reader
    if game_server_writer is not None:
        Log.info(f'TO-SERVER: {msg}')
        out_data = stream_encode(msg)
        game_server_writer.write(out_data)


def set_game_client_communication_websocket(websocket) -> Client:
    global game_client_websocket, game_client_web_transport
    game_client_websocket = websocket
    return handle_client_connected(websocket, game_client_web_transport)

def set_game_client_communication_web_transport(web_transport) -> Client:
    global game_client_web_transport
    game_client_web_transport = web_transport
    return handle_client_connected(game_client_websocket, web_transport)

async def to_game_client(msg):
    global game_client_websocket, game_client_web_transport

    if game_client_websocket is not None:
        Log.info(f'TO-CLIENT: {msg}')
        if GameServerMessages.CONNECT_SELF in msg:
            client = get_client_by_ws(game_client_websocket)
            client.uid = int(msg[:msg.index('.')])
            client.unreliableFastWT = game_client_web_transport
            # Log.info(client.uid)
            await game_client_websocket.send(msg)
        elif GameServerMessages.CONNECT_OTHER in msg or "GO" in msg:
            await send_message_others(msg, int(msg[:msg.index('.')]))
        elif GameServerMessages.DISCONNECT in msg:
            await send_message_all(msg)
        else:
            await send_message_all(msg, True)
