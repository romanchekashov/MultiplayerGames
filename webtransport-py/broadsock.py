from handlers import CounterHandler

uid_sequence = 0
clients = []

def create_client(uid, handler, data):
    return {uid, handler, data}

def handle_client_connected(handler: CounterHandler):
    uid_sequence = uid_sequence + 1
    client = create_client(uid_sequence, handler)
    print("add_client", client.uid)
    clients.append(client)
    send_message_others(client.uid + '|CONNECT_OTHER')
    handler.send_datagram(client.uid + '|CONNECT_SELF')

def handle_client_disconnected(client):
    send_message_all(client.uid + '|DISCONNECT')
    for c in clients:
        if c.uid == client.uid:
            clients.remove(c)
            break

def send_message_all(msg: str) -> None:
    for client in clients:
        client.handler.send_datagram(msg)

def send_message_others(msg: str, c_uid: int) -> None:
    for client in clients:
        if client.uid != c_uid:
            client.handler.send_datagram(msg)