import struct

def stream_encode(data):
    out_bytes = data.encode('utf8')
    out_size = struct.pack('>L', len(out_bytes))
    return out_size + out_bytes

def get_uid_from_msg(msg) -> int:
    return int(msg[0:msg.index('.')])
