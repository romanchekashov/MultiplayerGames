"""
https://docs.python.org/3/howto/logging-cookbook.html#dealing-with-handlers-that-block
https://docs.python.org/3/library/asyncio-dev.html
https://www.logicmonitor.com/blog/python-logging-levels-explained

Logging levels:
NOTSET=0
DEBUG=10
INFO=20
WARN=30
ERROR=40
CRITICAL=50
"""

import logging

from settings import LOGS # type: ignore

from datetime import datetime
LOG_FORMAT = '%(asctime)s : %(levelname)-8.8s : %(name)-30.30s : Fn %(funcName)-20.20s : Ln %(lineno)-5d : %(message)s'
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
from logging.handlers import RotatingFileHandler

class LoggerWrapper:
    disabled = False
    def __init__(self, prefix):
        self.logger = logging.getLogger(prefix)
        self.prefix = prefix or 'LOG'
        self._prev_msg = None
        self._prev_msgs = set()
        self._calls_count = 0

    def get(self):
        return self.logger

    def print(self, msg):
        if LoggerWrapper.disabled:
            return

        self._calls_count += 1
        if msg not in self._prev_msgs:
            print(f'{datetime.now()}:[{self.prefix}](calls: {self._calls_count}): {msg}')
            self._prev_msgs.add(msg)

    def __str__(self):
        return f'Log({self.__dict__}'

def add_file_log(logger, file_path):
    """
    Creates a file log
    """
    # create file handler which logs even debug messages
    fh = logging.FileHandler(file_path)
    # fh.setLevel(logging.DEBUG)
    formatter = logging.Formatter(LOG_FORMAT)
    fh.setFormatter(formatter)
    logger.addHandler(fh)


def add_rotating_file_log(logger, file_path, maxMbPerFile = 5):
    """
    Creates a rotating log
    """
    ONE_MB_IN_BYTES = 1000000
    # add a rotating handler
    rfh = RotatingFileHandler(file_path, maxBytes = maxMbPerFile * ONE_MB_IN_BYTES, backupCount = 5)
    # rfh.setLevel(logging.DEBUG)
    formatter = logging.Formatter(LOG_FORMAT)
    rfh.setFormatter(formatter)
    logger.addHandler(rfh)

def getLogger(name):
    logger = logging.getLogger(name)
    # add_file_log(logger, 'webtransport.log')
    add_rotating_file_log(logger, LOGS)
    # logger.setLevel(logging.DEBUG)
    logger.setLevel(logging.INFO)

    # create console handler with a higher log level
    # ch = logging.StreamHandler()
    # ch.setLevel(logging.DEBUG)
    # formatter = logging.Formatter(LOG_FORMAT)
    # ch.setFormatter(formatter)
    # logger.addHandler(ch)
    return logger
