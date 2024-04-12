import socket
import struct
import asyncio

from comm.game_server.gs_manager import get_gspid
from broadsock import set_game_server_communication

from stream import stream_encode
from app_logs import getLogger

Log = getLogger(__name__)

async def handle_client(reader, writer):
    room = set_game_server_communication(reader, writer, get_gspid())
    request = None
    while request != 'quit':
            # request = (await reader.read(255)).decode('utf8')
            in_len = await reader.readexactly(4)
            size = struct.unpack('>L', in_len)[0]
            in_bytes = await reader.readexactly(size)
            in_msg = in_bytes.decode('utf8')

            await room.to_game_client(in_msg)
            await writer.drain()
        # try:
        # except Exception as e:
        #     # asyncio.exceptions.IncompleteReadError: 0 bytes read on a total of 4 expected bytes
        #     error_message = "resetting connection: {}".format(e.args)
        #     Log.error(error_message)
        #     request = 'quit'
            # writer.write_eof()
            # raise Exception(error_message)

    writer.close()

async def run_game_server_connector(host, port):
    server = await asyncio.start_server(handle_client, host, port)
    Log.info("[GAME SERVER] Listening on http(s)://{}:{}".format(host, port))
    async with server:
        await server.serve_forever()
