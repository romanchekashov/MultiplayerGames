import os
import psutil
import asyncio
from subprocess import Popen
from utils import getLogger

Log = getLogger(__name__)

GAME_SERVER_STOP_TIMEOUT = 10
event_loop = None
gameStopNeeded = False

def set_event_loop(loop):
    event_loop = loop

def findGameProcess():
    for process in psutil.process_iter():
        if 'dmengine_headless' in process.name():
            return process

async def _stop_game_server():
    Log.info('stop started...')
    await asyncio.sleep(GAME_SERVER_STOP_TIMEOUT)
    
    if not gameStopNeeded:
        Log.info('Connected clients found: stop_game_server cancelled.')
        return
    
    Log.info('stoping...')
    process = findGameProcess()
    if process is not None:
        Log.info(f'{process.name()} - Process found. Terminating it.')
        process.terminate()
        process.wait()

def stop_game_server():
    global gameStopNeeded
    gameStopNeeded = True
    Log.info(f'stop {gameStopNeeded}')
    asyncio.ensure_future(_stop_game_server(), loop=event_loop)

def start_game_server():
    global gameStopNeeded
    gameStopNeeded = False
    process = findGameProcess()
    if process is None:
        Popen(os.environ['START_GAME_SERVER_SHELL_SCRIPT'], shell=True)
    else:
        Log.info(f'{process.name()} - Game Sever Process already running.')
