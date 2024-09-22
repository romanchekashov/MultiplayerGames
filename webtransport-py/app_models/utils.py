def get_uid_from_msg(msg) -> int:
    try:
        return int(msg[0:msg.index('.')])
    except ValueError:
        print("Error: Message does not contain a period or valid UID")
        return None
