import queue

from stream import stream_encode, get_uid_from_msg
from enum import Enum
from typing import List, Dict
from utils import getLogger
from models import Client, ReliableConnection, FastUnreliableConnection

from comm.game_server.gs_manager import start_game_server, stop_game_server, GameServer, GameServerMessages

Log = getLogger(__name__)


game_server_star_room_queue = queue.Queue()
uid_sequence = 0
clients: List[Client] = []


class RoomState:
    MATCHING = 'MATCHING'
    PLAYING = 'PLAYING'

class Room:
    def __init__(self, name):
        self.name = name
        self.survivor_uids = {}
        self.family_uids = {}
        self.state = RoomState.MATCHING
        self.game_server: GameServer = None
        self.clients: List[Client] = []
        self.reliable_connection = ReliableConnection(self.clients)
        self.fast_unreliable_connection = FastUnreliableConnection(self.reliable_connection)

    def add_client(self, client: Client):
        self.clients.append(client)
        self.reliable_connection.clients = self.clients
        self.fast_unreliable_connection.clients = self.clients

    def remove_client(self, client: Client):
        self.clients.remove(client)
        self.reliable_connection.clients = self.clients
        self.fast_unreliable_connection.clients = self.clients

    async def to_game_client(self, msg):
        Log.debug(f'TO-CLIENT: {msg}')
        if GameServerMessages.GO in msg: # and GOD
            # await fast_unreliable_connection.send_message_others(msg, get_uid_from_msg(msg))
            await self.fast_unreliable_connection.send_message_all(msg)
        # elif GameServerMessages.GOD in msg:
        #     await reliable_connection.send_message_others(msg, get_uid_from_msg(msg))
        elif GameServerMessages.CONNECT_SELF in msg:
            client = get_client_by_ws(game_client_websocket)
            uid = get_uid_from_msg(msg)
            if client is not None and client.uid != uid:
                client.set_uid(uid)
                Log.info(f'client get game server uid: {client}')
                await self.reliable_connection.send_msg_to(client, msg)
        elif GameServerMessages.CONNECT_OTHER in msg:
            await self.reliable_connection.send_message_others(msg, get_uid_from_msg(msg))
        elif GameServerMessages.DISCONNECT in msg:
            await self.reliable_connection.send_message_all(msg)
        else:
            await self.fast_unreliable_connection.send_message_all(msg)

    def set_game_server(self, gs: GameServer):
        self.game_server = gs
        self.state = RoomState.PLAYING

    def start_game(self):
        game_server_star_room_queue.put(self)
        start_game_server()

    def end_game(self):
        stop_game_server(self.game_server.pid, game_server_stopped_clear_communication)

    def players_len(self):
        return len(self.family_uids) + len(self.survivor_uids)
    
    def has_player(self, c_uid) -> bool:
        if c_uid in self.family_uids.keys():
            return True
        if c_uid in self.survivor_uids.keys():
            return True
        return False
    
    def remove_player(self, client: Client):
        c_uid = client.uid
        if c_uid in self.family_uids.keys():
            self.remove_client(client)
            del self.family_uids[c_uid]
        if c_uid in self.survivor_uids.keys():
            self.remove_client(client)
            del self.survivor_uids[c_uid]

    def add_player(self, type, client: Client):
        c_uid = client.uid
        self.remove_player(client)
        self.add_client(client)
        if type == 'family':
            self.family_uids[c_uid] = {'ready' : False}
        else:
            self.survivor_uids[c_uid] = {'ready' : False}
    
    def ready_players(self):
        ready_players = 0
        for value in self.family_uids.values():
            if value['ready']:
                ready_players += 1
        for value in self.survivor_uids.values():
            if value['ready']:
                ready_players += 1
        return ready_players

    def can_start_game(self):
        half_players_count = self.players_len() / 2
        return self.ready_players() > half_players_count

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
        self.client_to_room: Dict[int, Room] = dict()

    def add(self, room: Room):
        self.list.append(room)

    def get_room_by_client_uid(self, c_uid: int) -> Room:
        return self.client_to_room[c_uid]

    def remove_player(self, client: Client):
        room = self.get_room_by_client_uid(client.uid)
        if client.uid in self.client_to_room.keys():
            del self.client_to_room[client.uid]
        room.remove_player(client)

    def add_player(self, room_name: str, type, client: Client):
        if client.uid in self.client_to_room.keys():
            del self.client_to_room[client.uid]
        for room in self.list:
            if room.name == room_name:
                room.add_player(type, client)
                self.client_to_room[client.uid] = room
            else:
                room.remove_player(client)

    def player_ready(self, room_name: str, client: Client):
        for room in self.list:
            if room.name == room_name:
                room.player_ready(client.uid)
                break
    
    def remove_room_by_player(self, c_uid: int):
        for room in self.list:
            players_len = room.players_len()
            if room.has_player(c_uid) and (players_len == 0 or players_len == 1):
                self.list.remove(room)
                if c_uid in self.client_to_room.keys():
                    del self.client_to_room[c_uid]

    def size(self):
        return len(self.list)

    def __str__(self):
        res = f'NOT_GS_ROOMS'
        for item in self.list:
            res += f'.{item}'
        return res

# create a queue with no size limit
cache_client_msg_while_server_not_ready_queue = queue.Queue()
game_server = None
game_client_websocket = None
reliable_connection = ReliableConnection(clients)
fast_unreliable_connection = FastUnreliableConnection(reliable_connection)
rooms = Rooms()
for i in range(1, 11):
    rooms.add(Room(f'Room {i}'))

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
    global uid_sequence

    if websocket is not None:
        client = get_client_by_ws(websocket)
    
    uid_sequence += 1
    
    if client is None:
        client = Client(uid_sequence, None, websocket, None)
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
    
    # rooms.remove_room_by_player(client.uid)
    rooms.remove_player(client)
    
    await reliable_connection.send_message_all(f'{rooms}')

    Log.info(f'client disconected: {client}, clients = {len(clients)}')

    if len(clients) == 0:
        Log.info(f'clients = {len(clients)}: Need stop game server')
        # stop_game_server(game_server_stopped_clear_communication)
    elif client.uid is not None:
        to_game_server(GameServerMessages.DISCONNECT, client)


"""
Set client/server connection
"""
def set_game_server_communication(reader, writer, pid) -> Room:
    global game_server
    game_server = GameServer(reader, writer, pid)
    room: Room = game_server_star_room_queue.get()
    if room != None:
        room.set_game_server(game_server)
        for client in room.clients:
            game_server.write(f'{client.uid}.CONNECT_ME')

    return room
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
    Log.info(f'TO-SERVER: {msg}, client: {client}')

    global game_server, rooms
    send_to_server = True

    if 'CONNECT_ME' in msg:
        await reliable_connection.send_msg_to(client, f'{client.uid}.CONNECT_SELF')
        await reliable_connection.send_message_others(f'{client.uid}.CONNECT_OTHER', client.uid)
        return

    if 'NOT_GS_ROOMS_GET' in msg:
        send_to_server = False
    # elif 'NOT_GS_CREATE_ROOM' in msg:
    #     rooms.add(Room(f'Room {rooms.size()}'))
    #     send_to_server = False
    elif 'NOT_GS_JOIN_ROOM' in msg:
        parts = msg.split('.')
        rooms.add_player(parts[1], parts[2], client)
        send_to_server = False
    elif 'NOT_GS_PLAYER_READY' in msg:
        parts = msg.split('.')
        rooms.player_ready(parts[1], client)
        # room = rooms.get_room_by_client_uid(client.uid)
        # if room.can_start_game():
        #     room.start_game()
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
    msg = f'{client.uid}.{msg}'

    room = rooms.get_room_by_client_uid(client.uid)
    if room.game_server is not None:
        room.game_server.write(msg)

    # if game_server is not None:
    #     game_server.write(msg)
    # else:
    #     cache_client_msg_while_server_not_ready_queue.put({'msg': msg, 'client': client})
