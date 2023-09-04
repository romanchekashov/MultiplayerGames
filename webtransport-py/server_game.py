import os
from sys import platform
from typing import Any, List
import psutil
import asyncio
from subprocess import Popen
from utils import getLogger

Log = getLogger(__name__)

GAME_SERVER_STOP_TIMEOUT = 10
event_loop = None
gameStopNeeded = False

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
    processList = findGameProcess()
    Log.info(f'Found {len(processList)} servers to terminate.')
    for process in processList:
        Log.info(f'{process.name()} - Process found. Terminating it.')
        process.terminate()
        process.wait()

async def _stop_game_server():
    Log.info('stop started...')
    await asyncio.sleep(GAME_SERVER_STOP_TIMEOUT)
    if not gameStopNeeded:
        Log.info('Connected clients found: stop_game_server cancelled.')
        return
    _terminate_game_server()

def stop_game_server():
    global gameStopNeeded
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
