from typing import List, Dict
from app_logs import getLogger
from app_models import GameServerMessages, ClientGameMessages
from datetime import datetime

Log = getLogger(__name__)

# https://websockets.readthedocs.io/en/stable/reference/asyncio/common.html#websockets.legacy.protocol.WebSocketCommonProtocol.latency
def get_ws_latency_in_ms(ws):
    return int(ws.latency * 1000)

PLAYER_TYPE_FAMILY = 1
PLAYER_TYPE_SURVIVOR = 2

class Client:
    def __init__(self, uid, web_transport, websocket, data):
        self.uid = uid
        self.username = f'user-{uid}'
        self.type = PLAYER_TYPE_SURVIVOR
        self.reliableWS = websocket
        self.unreliableFastWT = web_transport
        self.wt_latency = -1
        self.ws_latency = -1
        self.wsPingSentTime = datetime.now()
        self.data = data
        self.connected = True
        self.disconnected_time = None

    def calc_ws_latency(self):
        self.ws_latency = int((datetime.now() - self.wsPingSentTime).total_seconds() * 1000 / 2)

    def connect(self):
        self.connected = True
        self.disconnected_time = None

    def can_connect(self):
        return (datetime.now() - self.disconnected_time).total_seconds() < 10

    def disconnect(self):
        self.connected = False
        self.disconnected_time = datetime.now()

    def set_uid(self, uid):
        self.uid = uid
        self.username = f'user-{uid}'

    def set_username(self, username):
        self.username = username

    def __str__(self):
        return f'Client(uid = {self.uid}, WS = {id(self.reliableWS)}, WT = {id(self.unreliableFastWT)})'

class ReliableConnection:
    def __init__(self, clients: List[Client]):
        self.clients = clients

    async def send_msg_to(self, client: Client, msg):
        if client.reliableWS is not None:
            try:
                if ClientGameMessages.WS_PING in msg:
                    client.wsPingSentTime = datetime.now()
                    await client.reliableWS.send(msg)
                # elif GameServerMessages.GO in msg:
                #     await client.reliableWS.send(f'{msg}.{get_ws_latency_in_ms(client.reliableWS)}')
                else:
                    await client.reliableWS.send(msg)
            except Exception as e:
                Log.info(f'Cannot send to {client} because {str(e)}')

    async def send_message_all(self, msg: str) -> None:
        for client in self.clients:
            await self.send_msg_to(client, msg)

    async def send_message_others(self, msg: str, c_uid: int) -> None:
        for client in self.clients:
            if client.uid != c_uid:
                Log.debug(f'send_message_others from {msg} to {client}')
                await self.send_msg_to(client, msg)


class FastUnreliableConnection:
    def __init__(self, reliable_con: ReliableConnection):
        self.reliable_con = reliable_con
        self.clients = reliable_con.clients

    async def send_msg_to(self, client: Client, msg):
        if client.unreliableFastWT is not None:
            # if GameServerMessages.GO in msg:
            #     client.unreliableFastWT.send_datagram(f'{msg}.{client.wt_latency}')
            # else:
            client.unreliableFastWT.send_datagram(msg)
        else:
            await self.reliable_con.send_msg_to(client, msg)

    async def send_message_all(self, msg: str) -> None:
        for client in self.clients:
            await self.send_msg_to(client, msg)

    async def send_message_others(self, msg: str, c_uid: int) -> None:
        for client in self.clients:
            if client.uid != c_uid:
                await self.send_msg_to(client, msg)
