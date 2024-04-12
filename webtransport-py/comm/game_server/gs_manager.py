import os
import psutil
import asyncio
import queue

from sys import platform
from typing import Any, List
from subprocess import Popen
from app_logs import getLogger
from stream import stream_encode

Log = getLogger(__name__)

class GameServerMessages:
    GO = 'GO'
    GOD = 'GOD'
    PLAYER_CREATE_POS = 'PLAYER_CREATE_POS'
    CONNECT_ME = 'CONNECT_ME'
    CONNECT_SELF = 'CONNECT_SELF'
    CONNECT_OTHER = 'CONNECT_OTHER'
    DISCONNECT = 'DISCONNECT'
    GAME_PRE_START = 'GAME_PRE_START'
    GAME_START = 'GAME_START'
    GAME_OVER = 'GAME_OVER'

class GameServer:
    def __init__(self, reader, writer, pid):
        self.reader = reader
        self.writer = writer
        self.pid = pid
        Log.info(f'SERVER connected: {self}')

    def write(self, msg):
        out_data = stream_encode(msg)
        self.writer.write(out_data)

    def __str__(self):
        return f'GameServer(pid = {self.pid}, reader = {id(self.reader)}, writer = {id(self.writer)})'

GAME_SERVER_STOP_TIMEOUT = 10
GAME_SERVER_START_TIMEOUT = 1
MAX_ROOMS = 10
event_loop = None
gameStopNeeded = False
gameServerStopCallbackFn = None
game_server_start_pid_queue = queue.Queue()
game_server_pid_to_process = dict()

isLinux = platform == "linux" or platform == "linux2"
isMac = platform == "darwin"
isWin = platform == "win32"

def set_event_loop(loop):
    global event_loop
    event_loop = loop

def get_gspid() -> int:
    return game_server_start_pid_queue.get()

# ps aux | grep 'dmengine_headless'
def findGameProcess() -> List[Any]:
    # Log.info(f'len = {len(psutil.pids())}: {psutil.pids()}')
    arr = []
    if isLinux:
        for process in psutil.process_iter():
            cmdline = process.cmdline()
            if len(cmdline) > 0 and 'dmengine_headless' in cmdline[0]:
                arr.append(process)
    else:
        for process in psutil.process_iter():
            if 'dmengine_headless' in process.name():
                arr.append(process)
        # children = process.children()
        # for p in children:
        #     Log.info(f'child: [pid: {p.pid}] {p.name()}')
    Log.info(f'Found {len(arr)} GS processes')
    return arr

async def terminate_process_by_pid(pid):
    process = game_server_pid_to_process[pid]
    print(f'{process} {process is not None}')
    if process is not None:
        Log.info(f'[PID:{process.pid}] - Process found. Terminating it.')
        process.terminate()
        await process.wait()
        del game_server_pid_to_process[pid]
    else:
        Log.info(f'[PID:{pid}] - Process NOT found')

def terminate_process(process):
    Log.info(f'{process}[PID:{process.pid}] - Process found. Terminating it.')
    process.terminate()
    process.wait()

def _terminate_game_server(pid = None):
    global gameServerStopCallbackFn
    Log.info(f'_terminate_game_server {pid}')
    processList = findGameProcess()
    if pid is None:
        Log.info(f'Found {len(processList)} game servers to terminate.')
        for process in processList:
            terminate_process(process)
    else:
        for process in processList:
            Log.info(process)
            if (process.pid == (pid + 1)) and (game_server_pid_to_process[pid] is not None):
                terminate_process(process)
                del game_server_pid_to_process[pid]

    # if gameServerStopCallbackFn is not None:
    #     gameServerStopCallbackFn()

async def _stop_game_server(pid):
    Log.info('stop started...')
    await asyncio.sleep(GAME_SERVER_STOP_TIMEOUT)
    if not gameStopNeeded:
        Log.info('Connected clients found: stop_game_server cancelled.')
        return
    _terminate_game_server(pid)

def stop_game_server(pid, fn):
    global gameStopNeeded, gameServerStopCallbackFn
    gameServerStopCallbackFn = fn
    gameStopNeeded = True
    Log.info(f'stop {gameStopNeeded}')
    # asyncio.ensure_future(_stop_game_server(pid), loop=event_loop)
    _terminate_game_server(pid)

async def _start_game_server():
    Log.info(f'Game Server starting...')
    # create as a subprocess using create_subprocess_shell
    process = await asyncio.create_subprocess_shell(os.environ['START_GAME_SERVER_SHELL_SCRIPT'])
    # report the details of the subprocess
    # print(f'subprocess: {process}, {process.pid}')
    if process.pid not in game_server_pid_to_process.keys():
        game_server_pid_to_process[process.pid] = process
        game_server_start_pid_queue.put(process.pid)
        Log.info(f'Game Server[PID:{process.pid}], running: {len(game_server_pid_to_process)}, in queue: {game_server_start_pid_queue.qsize()}')
    # await asyncio.sleep(3)
    # https://docs.python.org/3/library/subprocess.html#subprocess.Popen
    # Popen(os.environ['START_GAME_SERVER_SHELL_SCRIPT'], shell=True)

    # Log.info(f'_put_start_game_server')
    # processList = findGameProcess()
    # for process in processList:
    #     if process.pid not in game_server_pid_to_process.keys():
    #         game_server_pid_to_process[process.pid] = process
    #         game_server_start_pid_queue.put(process.pid)
    #         Log.info(f'Game Server[PID:{process.pid}] started: {len(game_server_pid_to_process)}')

async def start_game_server():
    global gameStopNeeded, event_loop
    gameStopNeeded = False
    processList = findGameProcess()
    size = len(processList)

    if size < MAX_ROOMS:
        await _start_game_server()
        # Popen(os.environ['START_GAME_SERVER_SHELL_SCRIPT'], shell=True)
        # asyncio.ensure_future(_start_game_server(), loop=event_loop)
    else:
        Log.info(f'MAX {size} Game Sever Processes like {processList[0].name()} already running.')
