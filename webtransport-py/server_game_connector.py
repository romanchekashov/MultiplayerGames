import socket
import struct
import asyncio

from broadsock import to_game_client, set_game_server_communication

from stream import stream_encode

async def handle_client(reader, writer):
    set_game_server_communication(reader, writer)
    request = None
    while request != 'quit':
        # request = (await reader.read(255)).decode('utf8')
        in_len = await reader.readexactly(4)
        size = struct.unpack('>L', in_len)[0]
        in_bytes = await reader.readexactly(size)
        in_msg = in_bytes.decode('utf8')

        out_data = stream_encode(in_msg)
        writer.write(out_data)
        print(f'in_msg {in_msg}, out {out_data}')
        
        await to_game_client(in_msg)

        await writer.drain()
    writer.close()

async def run_game_server_connector(host, port):
    server = await asyncio.start_server(handle_client, host, port)
    print("[GAME SERVER] Listening on http(s)://{}:{}".format(host, port))
    async with server:
        await server.serve_forever()
