from typing import List, Dict

import queue
from datetime import datetime

from app_models import get_uid_from_msg
from app_logs import getLogger
from app_models import Client, ReliableConnection, FastUnreliableConnection, PLAYER_TYPE_FAMILY, GameServerMessages, ClientGameMessages, get_ws_latency_in_ms
from app_msg.game_server import GameServer, terminate_game_server

from app_msg.game_server import start_game_server, GameServer, MAX_ROOMS

Log = getLogger(__name__)


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
        self.wsLatencyCheckTime = datetime.now()

    def get_client_by_uid(self, uid: int) -> Client:
        for c in self.clients:
            if c.uid == uid:
                return c

    def add_client(self, client: Client):
        self.clients.append(client)
        self.reliable_connection.clients = self.clients
        self.fast_unreliable_connection.clients = self.clients

    def remove_client(self, client: Client):
        self.clients.remove(client)
        self.reliable_connection.clients = self.clients
        self.fast_unreliable_connection.clients = self.clients

    async def check_latency(self):
        if (datetime.now() - self.wsLatencyCheckTime).total_seconds() < 5:
            return

        await self.reliable_connection.send_message_all(ClientGameMessages.WS_PING)

        self.wsLatencyCheckTime = datetime.now()
        msg = f'-1.LATENCY.{len(self.clients)}'
        for client in self.clients:
            msg += f'.{client.uid}.{client.ws_latency}.{client.wt_latency}'
        await self.reliable_connection.send_message_all(msg)

    async def to_game_client(self, msg):
        await self.check_latency()

        if GameServerMessages.CONNECT_SELF in msg:
            uid = get_uid_from_msg(msg)
            for client in self.clients:
                if client.uid == uid:
                    Log.info(f'client get game server uid: {client}')
                    await self.reliable_connection.send_msg_to(client, msg)
                    break
        elif GameServerMessages.CONNECT_OTHER in msg:
            await self.reliable_connection.send_message_others(msg, get_uid_from_msg(msg))
        elif GameServerMessages.DISCONNECT in msg:
            await self.reliable_connection.send_message_all(msg)
        else:
            await self.fast_unreliable_connection.send_message_all(msg)

    def set_game_server(self, gs: GameServer):
        self.game_server = gs
        self.state = RoomState.PLAYING

    def end_game(self):
        terminate_game_server(self.game_server.pid)
        self.state = RoomState.MATCHING
        # stop_game_server(self.game_server.pid, game_server_stopped_clear_communication)
        for c_uid in self.family_uids.keys():
            self.family_uids[c_uid]['ready'] = False
        for c_uid in self.survivor_uids.keys():
            self.survivor_uids[c_uid]['ready'] = False

    def players_len(self) -> int:
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

    def add_player(self, type: 0 | 1, client: Client):
        client.type = type
        c_uid = client.uid
        self.remove_player(client)
        self.add_client(client)
        if type == PLAYER_TYPE_FAMILY:
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
        res = f'{self.name}.{self.state}'

        res += '.family'
        for c_uid, value in self.family_uids.items():
            ready = 1 if self.family_uids[c_uid]['ready'] else 0
            res += f'.{c_uid}.{ready}'
            if value['ready']:
                ready_players += 1

        res += '.survivors'
        for c_uid, value in self.survivor_uids.items():
            ready = 1 if self.survivor_uids[c_uid]['ready'] else 0
            res += f'.{c_uid}.{ready}'
            if value['ready']:
                ready_players += 1

        return res + f'.ready.{ready_players}'


class Rooms:
    def __init__(self):
        self.game_server_star_room_queue = queue.Queue()
        self.list: List[Room] = []
        self.client_to_room: Dict[int, Room] = dict()

        for i in range(1, MAX_ROOMS + 1):
            self.add(Room(f'Room {i}'))

    async def to_room_client(self, room, msg):
        # Log.info(f'TO-CLIENT: {msg}')

        await room.to_game_client(msg)

        if GameServerMessages.PLAYER_LEAVE_ROOM in msg:
            uid = get_uid_from_msg(msg)
            client = room.get_client_by_uid(uid)
            self.remove_player(client)
            if room.players_len() == 0:
                room.end_game()
        elif GameServerMessages.GAME_OVER in msg:
            room.end_game()

    def set_game_server_communication(self, reader, writer, pid) -> Room:
        game_server = GameServer(reader, writer, pid)
        room: Room = self.game_server_star_room_queue.get()
        Log.debug(f'{pid} {room}')
        if room != None:
            room.set_game_server(game_server)
            for client in room.clients:
                game_server.write(f'{client.uid}.CONNECT_ME.{client.type}')

        return room

    def add(self, room: Room):
        self.list.append(room)

    def get_room_by_client_uid(self, c_uid: int) -> Room | None:
        if c_uid in self.client_to_room.keys():
            return self.client_to_room[c_uid]

    def remove_player(self, client: Client):
        room = self.get_room_by_client_uid(client.uid)
        if client.uid in self.client_to_room.keys():
            del self.client_to_room[client.uid]
        if room is not None:
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

    async def player_ready(self, room_name: str, client: Client):
        for room in self.list:
            if room.name == room_name:
                room.player_ready(client.uid)
                break

        room = self.get_room_by_client_uid(client.uid)
        if room is not None and room.can_start_game():
            if room.state == RoomState.MATCHING:
                self.game_server_star_room_queue.put(room)
                await start_game_server()
            else:
                room.game_server.write(f'{client.uid}.CONNECT_ME.{client.type}')
                await room.reliable_connection.send_msg_to(client, f'-1.GAME_START')

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
