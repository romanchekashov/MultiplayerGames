
class Logger:
    disabled = True
    def __init__(self, prefix):
        self.prefix = prefix or 'LOG'
        self._prev_msg = None
        self._prev_msgs = set()
        self._calls_count = 0

    def print(self, msg):
        if Logger.disabled:
            return
        
        self._calls_count += 1
        if msg not in self._prev_msgs:
            print(f'[{self.prefix}](calls: {self._calls_count}): {msg}')
            self._prev_msgs.add(msg)

    def __str__(self):
        return f'Log({self.__dict__}'
