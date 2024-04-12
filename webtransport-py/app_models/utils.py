def get_uid_from_msg(msg) -> int:
    return int(msg[0:msg.index('.')])
