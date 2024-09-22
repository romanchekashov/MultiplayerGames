from typing import List, Dict
from app_logs import getLogger
from app_models import Client, ReliableConnection, FastUnreliableConnection, PLAYER_TYPE_FAMILY, PLAYER_TYPE_SURVIVOR, Rooms, ClientGameMessages, GameServerMessages, get_uid_from_msg

Log = getLogger(__name__)


uid_sequence = 0
clients: List[Client] = []
disconnected_clients: List[Client] = []
reliable_connection = ReliableConnection(clients)
fast_unreliable_connection = FastUnreliableConnection(reliable_connection)
rooms = Rooms()

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

    if client.uid is not None:
        to_game_server(GameServerMessages.DISCONNECT, client)

    client.disconnect()
    disconnected_clients.append(client)
    clients.remove(client)

    # rooms.remove_room_by_player(client.uid)
    rooms.remove_player(client)

    await reliable_connection.send_message_all(f'{rooms}')
    await reliable_connection.send_message_all(f'-1.ONLINE.{len(clients)}')

    Log.info(f'client disconected: {client}, clients = {len(clients)}')

    if len(clients) == 0:
        Log.info(f'clients = {len(clients)}: Need stop game server')


"""
Set client/server connection
"""
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
        uid = get_uid_from_msg(msg)
        disconnected = None
        if uid:
            for c in disconnected_clients:
                if c.uid == uid:
                    disconnected = c

        if disconnected:
            disconnected_clients.remove(disconnected)
            if disconnected.can_connect():
                client.uid = uid
                client.username = f'user-{uid}'

        await reliable_connection.send_msg_to(client, f'{client.uid}.CONNECT_SELF.{client.username}')
        await reliable_connection.send_message_others(f'{client.uid}.CONNECT_OTHER', client.uid)
        await reliable_connection.send_message_all(f'-1.ONLINE.{len(clients)}')
        await send_usernames()
        return

    if ClientGameMessages.GET_USERNAMES in msg:
        await send_usernames()
        return

    if ClientGameMessages.ROOMS_GET in msg:
        send_to_server = False
    # elif 'NOT_GS_CREATE_ROOM' in msg:
    #     rooms.add(Room(f'Room {rooms.size()}'))
    #     send_to_server = False
    elif ClientGameMessages.WS_PONG in msg:
        client.calc_ws_latency()
        return
    elif ClientGameMessages.JOIN_ROOM in msg:
        parts = msg.split('.')
        room_name = parts[1]
        player_type = PLAYER_TYPE_SURVIVOR
        if parts[2] == 'family':
            player_type = PLAYER_TYPE_FAMILY
        rooms.add_player(room_name, player_type, client)
        send_to_server = False
    elif ClientGameMessages.PLAYER_READY in msg:
        parts = msg.split('.')
        await rooms.player_ready(parts[1], client)
        send_to_server = False
    elif ClientGameMessages.SET_PLAYER_USERNAME in msg:
        client.set_username(msg[27:])
        await send_usernames()
        return

    if send_to_server:
        to_game_server(msg, client)
    else:
        await reliable_connection.send_message_all(f'{rooms}')

def to_game_server(msg, client: Client):
    msg = f'{client.uid}.{msg}'

    room = rooms.get_room_by_client_uid(client.uid)
    if room is not None and room.game_server is not None:
        room.game_server.write(msg)
