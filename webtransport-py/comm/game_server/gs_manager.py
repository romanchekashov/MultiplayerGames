import os
import psutil
import asyncio

from sys import platform
from typing import Any, List
from subprocess import Popen
from utils import getLogger
from stream import stream_encode


Log = getLogger(__name__)

class GameServerMessages:
    CONNECT_ME = 'CONNECT_ME'
    GO = 'GO'
    GOD = 'GOD'
    CONNECT_SELF = 'CONNECT_SELF'
    CONNECT_OTHER = 'CONNECT_OTHER'
    DISCONNECT = 'DISCONNECT'

class GameServer:
    def __init__(self, reader, writer):
        self.reader = reader
        self.writer = writer
        Log.info(f'SERVER connected: {self}')
    
    def write(self, msg):
        out_data = stream_encode(msg)
        self.writer.write(out_data)

    def __str__(self):
        return f'GameServer(reader = {id(self.reader)}, writer = {id(self.writer)})'

GAME_SERVER_STOP_TIMEOUT = 10
event_loop = None
gameStopNeeded = False
gameServerStopCallbackFn = None

isLinux = platform == "linux" or platform == "linux2"
isMac = platform == "darwin"
isWin = platform == "win32"

def set_event_loop(loop):
    event_loop = loop

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
    return arr

def _terminate_game_server():
    global gameServerStopCallbackFn
    processList = findGameProcess()
    Log.info(f'Found {len(processList)} servers to terminate.')
    for process in processList:
        Log.info(f'{process.name()} - Process found. Terminating it.')
        process.terminate()
        process.wait()
    
    if gameServerStopCallbackFn is not None:
        gameServerStopCallbackFn()

async def _stop_game_server():
    Log.info('stop started...')
    await asyncio.sleep(GAME_SERVER_STOP_TIMEOUT)
    if not gameStopNeeded:
        Log.info('Connected clients found: stop_game_server cancelled.')
        return
    _terminate_game_server()

def stop_game_server(fn):
    global gameStopNeeded, gameServerStopCallbackFn
    gameServerStopCallbackFn = fn
    gameStopNeeded = True
    Log.info(f'stop {gameStopNeeded}')
    asyncio.ensure_future(_stop_game_server(), loop=event_loop)

def start_game_server():
    global gameStopNeeded
    gameStopNeeded = False
    processList = findGameProcess()
    size = len(processList)
    if size == 0:
        Log.info(f'Game Server starting...')
        Popen(os.environ['START_GAME_SERVER_SHELL_SCRIPT'], shell=True)
    else:
        Log.info(f'{size} Game Sever Processes like {processList[0].name()} already running.')