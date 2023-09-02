
class Logger:
    def __init__(self, prefix):
        self.prefix = prefix or 'LOG'
        self._prev_msg = None
        self._prev_msgs = set()

    def print(self, msg):
        if msg not in self._prev_msgs:
            print(msg)
            self._prev_msgs.add(msg)

    def __str__(self):
        return f'Log({self.__dict__}'
