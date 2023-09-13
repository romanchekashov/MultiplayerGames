import queue

from stream import stream_encode, get_uid_from_msg
from enum import Enum
from typing import List
from utils import getLogger

from comm.game_server.gs_manager import start_game_server, stop_game_server, GameServer, GameServerMessages

Log = getLogger(__name__)

class Room:
    def __init__(self, name, creator_uid):
        self.name = name
        self.creator_uid = creator_uid
        self.survivor_uids = {}
        self.family_uids = {}

    def players_len(self):
        return len(self.family_uids) + len(self.survivor_uids)
    
    def has_player(self, c_uid) -> bool:
        if c_uid == self.creator_uid:
            return True
        if c_uid in self.family_uids.keys():
            return True
        if c_uid in self.survivor_uids.keys():
            return True
        return False
    
    def remove_player(self, c_uid):
        if c_uid in self.family_uids.keys():
            del self.family_uids[c_uid]
        if c_uid in self.survivor_uids.keys():
            del self.survivor_uids[c_uid]

    def add_player(self, type, c_uid):
        self.remove_player(c_uid)
        if type == 'family':
            self.family_uids[c_uid] = {'ready' : False}
        else:
            self.survivor_uids[c_uid] = {'ready' : False}
    
    def player_ready(self, c_uid):
        if c_uid in self.family_uids.keys():
            if not self.family_uids[c_uid]['ready']:
                self.family_uids[c_uid] = {'ready' : True}
        if c_uid in self.survivor_uids.keys():
            if not self.survivor_uids[c_uid]['ready']:
                self.survivor_uids[c_uid] = {'ready' : True}

    def __str__(self):
        ready_players = 0
        res = f'{self.name}.family'
        for key, value in self.family_uids.items():
            res += f'.{key}'
            if value['ready']:
                ready_players += 1
        
        res += '.survivors'
        for key, value in self.survivor_uids.items():
            res += f'.{key}'
            if value['ready']:
                ready_players += 1

        return res + f'.ready.{ready_players}'
    
class Rooms:
    def __init__(self):
        self.list: List[Room] = []

    def add(self, room):
        self.list.append(room)

    def add_player(self, room_name, type, c_uid):
        for item in self.list:
            if item.name == room_name:
                item.add_player(type, c_uid)
            else:
                item.remove_player(c_uid)

    def player_ready(self, room_name, c_uid):
        for item in self.list:
            if item.name == room_name:
                item.player_ready(c_uid)
                break
    
    def remove_room_by_player(self, c_uid):
        for room in self.list:
            players_len = room.players_len()
            if room.has_player(c_uid) and (players_len == 0 or players_len == 1):
                self.list.remove(room)

    def size(self):
        return len(self.list)

    def __str__(self):
        res = f'NOT_GS_ROOMS'
        for item in self.list:
            res += f'.{item}'
        return res

class Client:
    def __init__(self, uid, web_transport, websocket, data):
        self.uid = uid
        self.username = f'user-{uid}'
        self.reliableWS = websocket
        self.unreliableFastWT = web_transport
        self.wt_latency = -1
        self.data = data

    def set_uid(self, uid):
        self.uid = uid
        self.username = f'user-{uid}'

    def set_username(self, username):
        self.username = username

    def __str__(self):
        return f'Client(uid = {self.uid}, WS = {id(self.reliableWS)}, WT = {id(self.unreliableFastWT)})'

# create a queue with no size limit
cache_client_msg_while_server_not_ready_queue = queue.Queue()
uid_sequence = 0
clients: List[Client] = []
rooms = Rooms()
game_server = None
game_client_websocket = None

# https://websockets.readthedocs.io/en/stable/reference/asyncio/common.html#websockets.legacy.protocol.WebSocketCommonProtocol.latency
def get_ws_latency_in_ms(ws):
    return int(ws.latency * 1000)

class ReliableConnection:
    def __init__(self):
        print()

    async def send_msg_to(self, client: Client, msg):
        if client.reliableWS is not None:
            try:
                if GameServerMessages.GO in msg:
                    await client.reliableWS.send(f'{msg}.{get_ws_latency_in_ms(client.reliableWS)}')
                else:
                    await client.reliableWS.send(msg)
            except Exception as e:
                Log.info(f'Cannot send to {client} because {str(e)}')
            
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


class FastUnreliableConnection:
    def __init__(self, reliable_con: ReliableConnection):
        self.reliable_con = reliable_con

    async def send_msg_to(self, client: Client, msg):
        if client.unreliableFastWT is not None:
            if GameServerMessages.GO in msg:
                client.unreliableFastWT.send_datagram(f'{msg}.{client.wt_latency}')
            else:
                client.unreliableFastWT.send_datagram(msg)
        else:
            await self.reliable_con.send_msg_to(client, msg)

    async def send_message_all(self, msg: str) -> None:
        global clients
        for client in clients:
            await self.send_msg_to(client, msg)

    async def send_message_others(self, msg: str, c_uid: int) -> None:
        global clients
        for client in clients:
            if client.uid != c_uid:
                await self.send_msg_to(client, msg)


reliable_connection = ReliableConnection()
fast_unreliable_connection = FastUnreliableConnection(reliable_connection)


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

def game_server_stopped_clear_communication():
    global game_server
    game_server = None
    Log.info(f'SERVER stopped.')

"""
Client connect/disconnect
"""
def handle_client_connected(websocket) -> Client:
    if websocket is not None:
        client = get_client_by_ws(websocket)
    
    # uid_sequence += 1
    
    if client is None:
        client = Client(None, None, websocket, None)
        clients.append(client)
    
    if client.reliableWS is None and websocket is not None:
        client.reliableWS = websocket

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
    rooms.remove_room_by_player(client.uid)
    await reliable_connection.send_message_all(f'{rooms}')

    Log.info(f'client disconected: {client}, clients = {len(clients)}')

    if len(clients) == 0:
        Log.info(f'clients = {len(clients)}: Need stop game server')
        stop_game_server(game_server_stopped_clear_communication)
    elif client.uid is not None:
        to_game_server(GameServerMessages.DISCONNECT, client)


"""
Set client/server connection
"""
def set_game_server_communication(reader, writer):
    global game_server
    game_server = GameServer(reader, writer)
    while not cache_client_msg_while_server_not_ready_queue.empty():
        item = cache_client_msg_while_server_not_ready_queue.get()
        # Log.debug(item)
        to_game_server(item.get("msg"), item.get("client"))

async def set_game_client_communication_websocket(websocket) -> Client:
    global game_client_websocket
    game_client_websocket = websocket
    client = handle_client_connected(websocket)
    await reliable_connection.send_message_all(f'{rooms}')
    return client

def set_game_client_communication_web_transport(c_uid: int, web_transport) -> Client:
    for client in clients:
        if client.uid == c_uid:
            client.unreliableFastWT = web_transport
            return client

"""
Send messages to server and client
"""
async def to_server(msg, client: Client):
    global game_server, rooms
    send_to_server = True

    if 'NOT_GS_ROOMS_GET' in msg:
        send_to_server = False
    elif 'NOT_GS_CREATE_ROOM' in msg:
        rooms.add(Room(f'Room {rooms.size()}', client.uid))
        send_to_server = False
    elif 'NOT_GS_JOIN_ROOM' in msg:
        parts = msg.split('.')
        rooms.add_player(parts[1], parts[2], client.uid)
        send_to_server = False
    elif 'NOT_GS_PLAYER_READY' in msg:
        parts = msg.split('.')
        rooms.player_ready(parts[1], client.uid)
        send_to_server = False
    elif 'NOT_GS_SET_PLAYER_USERNAME' in msg:
        parts = msg.split('.')
        client.set_username(parts[1])
        send_to_server = False
    
    if send_to_server:
        to_game_server(msg, client)
    else:
        await reliable_connection.send_message_all(f'{rooms}')

def to_game_server(msg, client: Client):
    global game_server
    if client.uid is not None:
        msg = f'{client.uid}.{msg}'

    Log.debug(f'TO-SERVER: {msg}, client: {client}')
    if game_server is not None:
        game_server.write(msg)
    else:
        cache_client_msg_while_server_not_ready_queue.put({'msg': msg, 'client': client})

async def to_game_client(msg):
    Log.debug(f'TO-CLIENT: {msg}')
    if GameServerMessages.GO in msg: # and GOD
        # await fast_unreliable_connection.send_message_others(msg, get_uid_from_msg(msg))
        await fast_unreliable_connection.send_message_all(msg)
    # elif GameServerMessages.GOD in msg:
    #     await reliable_connection.send_message_others(msg, get_uid_from_msg(msg))
    elif GameServerMessages.CONNECT_SELF in msg:
        client = get_client_by_ws(game_client_websocket)
        uid = get_uid_from_msg(msg)
        if client is not None and client.uid != uid:
            client.set_uid(uid)
            Log.info(f'client get game server uid: {client}')
            await reliable_connection.send_msg_to(client, msg)
    elif GameServerMessages.CONNECT_OTHER in msg:
        await reliable_connection.send_message_others(msg, get_uid_from_msg(msg))
    elif GameServerMessages.DISCONNECT in msg:
        await reliable_connection.send_message_all(msg)
    else:
        await fast_unreliable_connection.send_message_all(msg)
