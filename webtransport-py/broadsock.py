import queue

from typing import List, Dict
from utils import getLogger
from models import Client, ReliableConnection, FastUnreliableConnection, PLAYER_TYPE_FAMILY, PLAYER_TYPE_SURVIVOR
from room import Room, RoomState

from comm.game_server.gs_manager import start_game_server, stop_game_server, GameServer, GameServerMessages, _terminate_game_server

Log = getLogger(__name__)


game_server_star_room_queue = queue.Queue()
uid_sequence = 0
clients: List[Client] = []

class ClientGameMessages:
    ROOMS = 'NOT_GS_ROOMS'
    ROOMS_GET = 'NOT_GS_ROOMS_GET'
    USERNAMES = 'NOT_GS_USERNAMES'
    GET_USERNAMES = 'NOT_GS_GET_USERNAMES'
    SET_PLAYER_USERNAME = 'NOT_GS_SET_PLAYER_USERNAME'
    CREATE_ROOM = 'NOT_GS_CREATE_ROOM'
    JOIN_ROOM = 'NOT_GS_JOIN_ROOM'
    LEAVE_ROOM = 'NOT_GS_LEAVE_ROOM'
    PLAYER_READY = 'NOT_GS_PLAYER_READY'
    START_GAME = 'NOT_GS_START_GAME'


class Rooms:
    def __init__(self):
        self.list: List[Room] = []
        self.client_to_room: Dict[int, Room] = dict()

    def add(self, room: Room):
        self.list.append(room)

    def get_room_by_client_uid(self, c_uid: int) -> Room | None:
        if c_uid in self.client_to_room.keys():
            return self.client_to_room[c_uid]

    def remove_player(self, client: Client):
        room = self.get_room_by_client_uid(client.uid)
        if client.uid in self.client_to_room.keys():
            del self.client_to_room[client.uid]
        room.remove_player(client)

    def add_player(self, room_name: str, type: 0 | 1, client: Client):
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
        res = f'NOT_GS_ROOMS.{len(self.list)}'
        for item in self.list:
            res += f'.{item}'
        return res


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
    elif client.uid is not None:
        to_game_server(GameServerMessages.DISCONNECT, client)


"""
Set client/server connection
"""
def set_game_server_communication(reader, writer, pid) -> Room:
    game_server = GameServer(reader, writer, pid)
    room: Room = game_server_star_room_queue.get()
    Log.debug(f'{pid} {room}')
    if room != None:
        room.set_game_server(game_server)
        for client in room.clients:
            game_server.write(f'{client.uid}.CONNECT_ME.{client.type}')

    return room

async def set_game_client_communication_websocket(websocket) -> Client:
    client = handle_client_connected(websocket)
    await reliable_connection.send_message_all(f'{rooms}')
    return client

def set_game_client_communication_web_transport(c_uid: int, web_transport) -> Client:
    for client in clients:
        if client.uid == c_uid:
            client.unreliableFastWT = web_transport
            return client

async def send_usernames():
    res = ClientGameMessages.USERNAMES
    for client in clients:
        res += f'{client.uid}.{len(client.username)}#{client.username}'
    await reliable_connection.send_message_all(f'{res}')
"""
Send messages to server and client
"""
async def to_server(msg, client: Client):
    Log.debug(f'TO-SERVER: {msg}, client: {client}')

    global rooms
    send_to_server = True

    if GameServerMessages.CONNECT_ME in msg:
        await reliable_connection.send_msg_to(client, f'{client.uid}.CONNECT_SELF.{client.username}')
        await reliable_connection.send_message_others(f'{client.uid}.CONNECT_OTHER', client.uid)
        await send_usernames()
        return

    if ClientGameMessages.GET_USERNAMES in msg:
        await send_usernames()
        return

    if 'NOT_GS_ROOMS_GET' in msg:
        send_to_server = False
    # elif 'NOT_GS_CREATE_ROOM' in msg:
    #     rooms.add(Room(f'Room {rooms.size()}'))
    #     send_to_server = False
    elif 'NOT_GS_JOIN_ROOM' in msg:
        parts = msg.split('.')
        room_name = parts[1]
        player_type = PLAYER_TYPE_SURVIVOR
        if parts[2] == 'family':
            player_type = PLAYER_TYPE_FAMILY
        rooms.add_player(room_name, player_type, client)
        send_to_server = False
    elif ClientGameMessages.PLAYER_READY in msg:
        parts = msg.split('.')
        rooms.player_ready(parts[1], client)
        room = rooms.get_room_by_client_uid(client.uid)
        if room is not None and room.can_start_game():
            game_server_star_room_queue.put(room)
            await start_game_server()
        send_to_server = False
    elif ClientGameMessages.SET_PLAYER_USERNAME in msg:
        client.set_username(msg[27:])
        await send_usernames()
        return
    elif ClientGameMessages.LEAVE_ROOM in msg:
        rooms.remove_player(client)
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
