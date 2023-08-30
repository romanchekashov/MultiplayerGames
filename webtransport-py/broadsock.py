from handlers import CounterHandler
from aioquic.h3.connection import H3_ALPN, H3Connection

uid_sequence = 0
clients = []

class Client:
    def __init__(self, uid, handler, data):
        self.uid = uid
        self.handler = handler
        self.data = data

    def __str__(self):
        return f'Client({self.__dict__}'

def get_next_uid_sequence() -> int:
    global uid_sequence
    return uid_sequence + 1

def handle_client_connected(http: H3Connection):
    global uid_sequence, clients
    uid_sequence += 1
    client = Client(uid_sequence, CounterHandler(uid_sequence, http), None)
    print(f'add_client {client.uid}')
    print(client.handler)
    print(f'CounterHandler({client.handler.__dict__}')
    clients.append(client)
    send_message_others(f'{client.uid}|CONNECT_OTHER', client.uid)
    client.handler.send_datagram(f'{client.uid}|CONNECT_SELF')
    return client

def handle_client_disconnected(client):
    global clients
    send_message_all(f'{client.uid}|DISCONNECT')
    for c in clients:
        if c.uid == client.uid:
            clients.remove(c)
            break

def send_message_all(msg: str) -> None:
    global clients
    for client in clients:
        client.handler.send_datagram(msg)

def send_message_others(msg: str, c_uid: int) -> None:
    global clients
    for client in clients:
        if client.uid != c_uid:
            client.handler.send_datagram(msg)