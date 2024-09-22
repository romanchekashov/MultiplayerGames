class ClientGameMessages:
    ROOMS = 'NOT_GS_ROOMS'
    ROOMS_GET = 'NOT_GS_ROOMS_GET'
    USERNAMES = 'NOT_GS_USERNAMES'
    GET_USERNAMES = 'NOT_GS_GET_USERNAMES'
    SET_PLAYER_USERNAME = 'NOT_GS_SET_PLAYER_USERNAME'
    CREATE_ROOM = 'NOT_GS_CREATE_ROOM'
    JOIN_ROOM = 'NOT_GS_JOIN_ROOM'
    LEAVE_ROOM = 'NOT_GS_LEAVE_ROOM'
    PLAYER_READY = 'NOT_GS_PLAYER_READY'
    START_GAME = 'NOT_GS_START_GAME'
    WS_PING = 'WS_PING'
    WS_PONG = 'WS_PONG'

class GameServerMessages:
    GO = 'GO'
    GOD = 'GOD'
    PLAYER_CREATE_POS = 'PLAYER_CREATE_POS'
    PLAYER_LEAVE_ROOM = 'PLAYER_LEAVE_ROOM'
    CONNECT_ME = 'CONNECT_ME'
    CONNECT_SELF = 'CONNECT_SELF'
    CONNECT_OTHER = 'CONNECT_OTHER'
    DISCONNECT = 'DISCONNECT'
    GAME_PRE_START = 'GAME_PRE_START'
    GAME_START = 'GAME_START'
    GAME_OVER = 'GAME_OVER'
