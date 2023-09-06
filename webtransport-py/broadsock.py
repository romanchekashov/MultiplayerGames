import queue

from stream import stream_encode, get_uid_from_msg
from enum import Enum
from typing import List
from utils import getLogger

from server_game import start_game_server, stop_game_server

Log = getLogger(__name__)

class GameClientMessages:
    CONNECT_ME = 'CONNECT_ME'

class GameServerMessages:
    GO = 'GO'
    GOD = 'GOD'
    CONNECT_SELF = 'CONNECT_SELF'
    CONNECT_OTHER = 'CONNECT_OTHER'
    DISCONNECT = 'DISCONNECT'

class Client:
    def __init__(self, uid, web_transport, websocket, data):
        self.uid = uid
        self.reliableWS = websocket
        self.unreliableFastWT = web_transport
        self.data = data

    def __str__(self):
        return f'Client(uid = {self.uid}, WS = {id(self.reliableWS)}, WT = {id(self.unreliableFastWT)})'

# create a queue with no size limit
cache_client_msg_while_server_not_ready_queue = queue.Queue()
uid_sequence = 0
clients: List[Client] = []
game_server_reader = None
game_server_writer = None
game_client_websocket = None
game_client_web_transport = None


class FastUnreliableConnection:
    def __init__(self):
        print()

    async def send_msg_to(self, client, msg):
        if client.unreliableFastWT is not None:
            client.unreliableFastWT.send_datagram(msg)
        elif client.reliableWS is not None:
            await client.reliableWS.send(msg)

    async def send_message_all(self, msg: str) -> None:
        global clients
        for client in clients:
            await self.send_msg_to(client, msg)

    async def send_message_others(self, msg: str, c_uid: int) -> None:
        global clients
        for client in clients:
            if client.uid != c_uid:
                await self.send_msg_to(client, msg)


class ReliableConnection:
    def __init__(self):
        print()

    async def send_msg_to(self, client, msg):
        if client.reliableWS is not None:
            await client.reliableWS.send(msg)
            
    async def send_message_all(self, msg: str) -> None:
        global clients
        for client in clients:
            await self.send_msg_to(client, msg)

    async def send_message_others(self, msg: str, c_uid: int) -> None:
        global clients
        for client in clients:
            if client.uid != c_uid:
                Log.debug(f'send_message_others from {msg} to {client}')
                await self.send_msg_to(client, msg)


reliable_connection = ReliableConnection()
fast_unreliable_connection = FastUnreliableConnection()


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


"""
Client connect/disconnect
"""
def handle_client_connected(websocket, web_transport):
    if websocket is not None:
        client = get_client_by_ws(websocket)
    if client is None and web_transport is not None:
        client = get_client_by_wt(web_transport)
    
    # uid_sequence += 1
    
    if client is None:
        client = Client(None, web_transport, websocket, None)
        clients.append(client)
    
    if client.reliableWS is None and websocket is not None:
        client.reliableWS = websocket
    if client.unreliableFastWT is None and web_transport is not None:
        client.unreliableFastWT = web_transport

    Log.info(f'client connected: {client}, clients = {len(clients)}')

    if len(clients) > 0:
        start_game_server()

    return client

async def handle_client_disconnected(websocket):
    Log.debug(f'clients = {", ".join(map(str, clients))}: disconnecting..., WS: {id(websocket)}')
    if len(clients) == 0:
        return
    
    client = get_client_by_ws(websocket)
    clients.remove(client)
    
    Log.info(f'client disconected: {client}, clients = {len(clients)}')

    if len(clients) == 0:
        Log.info(f'clients = {len(clients)}: Need stop game server')
        stop_game_server()
    elif client.uid is not None:
        to_game_server(GameServerMessages.DISCONNECT, client)


"""
Set client/server connection
"""
def set_game_server_communication(reader, writer):
    global game_server_reader, game_server_writer
    game_server_reader = reader
    game_server_writer = writer
    Log.info('SERVER connected.')
    while not cache_client_msg_while_server_not_ready_queue.empty():
        item = cache_client_msg_while_server_not_ready_queue.get()
        # Log.debug(item)
        to_game_server(item.get("msg"), item.get("client"))

def set_game_client_communication_websocket(websocket) -> Client:
    global game_client_websocket, game_client_web_transport
    game_client_websocket = websocket
    return handle_client_connected(websocket, game_client_web_transport)

def set_game_client_communication_web_transport(web_transport) -> Client:
    global game_client_web_transport
    game_client_web_transport = web_transport
    return handle_client_connected(game_client_websocket, web_transport)

"""
Send messages to server and client
"""
def to_game_server(msg, client: Client):
    global game_server_reader
    if client.uid is not None:
        msg = f'{client.uid}.{msg}'

    Log.debug(f'TO-SERVER: {msg}, client: {client}')
    if game_server_writer is not None:
        out_data = stream_encode(msg)
        game_server_writer.write(out_data)
    else:
        cache_client_msg_while_server_not_ready_queue.put({'msg': msg, 'client': client})

async def to_game_client(msg):
    Log.debug(f'TO-CLIENT: {msg}, WS: {id(game_client_websocket)}, WT: {id(game_client_web_transport)}')
    if GameServerMessages.GO in msg:
        await fast_unreliable_connection.send_message_others(msg, get_uid_from_msg(msg))
    elif GameServerMessages.GOD in msg:
        await reliable_connection.send_message_others(msg, get_uid_from_msg(msg))
    elif GameServerMessages.CONNECT_SELF in msg:
        client = get_client_by_ws(game_client_websocket)
        uid = get_uid_from_msg(msg)
        if client is not None and client.uid != uid:
            client.uid = uid
            client.unreliableFastWT = game_client_web_transport
            Log.info(f'client get game server uid: {client}')
            await reliable_connection.send_msg_to(client, msg)
    elif GameServerMessages.CONNECT_OTHER in msg:
        await reliable_connection.send_message_others(msg, get_uid_from_msg(msg))
    elif GameServerMessages.DISCONNECT in msg:
        Log.info(f'TO-CLIENT: {msg}')
        await reliable_connection.send_message_all(msg)
    else:
        await fast_unreliable_connection.send_message_all(msg)
