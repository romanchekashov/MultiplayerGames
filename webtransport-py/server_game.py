import psutil
import asyncio
from subprocess import Popen
from utils import Logger

Log = Logger('GAME_SERVER')

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
    Log.print('stop started...')
    await asyncio.sleep(GAME_SERVER_STOP_TIMEOUT)
    
    if not gameStopNeeded:
        Log.print('Connected clients found: stop_game_server cancelled.')
        return
    
    Log.print('stoping...')
    process = findGameProcess()
    if process is not None:
        Log.print(f'{process.name()} - Process found. Terminating it.')
        process.terminate()
        process.wait()

def stop_game_server():
    global gameStopNeeded
    gameStopNeeded = True
    Log.print(f'stop {gameStopNeeded}')
    asyncio.ensure_future(_stop_game_server(), loop=event_loop)

def start_game_server():
    global gameStopNeeded
    gameStopNeeded = False
    process = findGameProcess()
    if process is None:
        Popen('./run_x86_64_macos.sh', shell=True)
    else:
        Log.print(f'{process.name()} - Game Sever Process already running.')
