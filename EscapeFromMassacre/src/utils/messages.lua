local debugUtils = require "src.utils.debug-utils"
local stream = require "client.stream"

local log = debugUtils.createLog("[MESSAGES]").log

local M = {
    BASE_MSG_IDS = {
        ROOMS = "NOT_GS_ROOMS",
        ROOMS_GET = "NOT_GS_ROOMS_GET",
        USERNAMES = "NOT_GS_USERNAMES",
        GET_USERNAMES = "NOT_GS_GET_USERNAMES",
        SET_PLAYER_USERNAME = "NOT_GS_SET_PLAYER_USERNAME",
        CREATE_ROOM = "NOT_GS_CREATE_ROOM",
        JOIN_ROOM = "NOT_GS_JOIN_ROOM",
        LEAVE_ROOM = "NOT_GS_LEAVE_ROOM",
        PLAYER_READY = "NOT_GS_PLAYER_READY",
        PLAYER_COMMANDS = "NOT_GS_PLAYER_COMMANDS",
        START_GAME = "NOT_GS_START_GAME",

        CREATE_PLAYER = "CREATE_PLAYER",
        RELIABLE_GO = "GAO",
        RELIABLE_GOD = "GAOD",
    },
    BROADSOCK = {
        connect = {
            name = "connect",
            hash = hash("connect")}
    },
    ROOMS = {
        SHOW = {
            name = "show",
            hash = hash("show"),
        },
        HIDE = {
            name = "hide",
            hash = hash("hide"),
        },
        RECIEVE_ROOMS = {
            name = "recieve_rooms",
            hash = hash("recieve_rooms"),
        },
        RECIEVE_USERNAMES = {
            name = "recieve_usernames",
            hash = hash("recieve_usernames"),
        },
    },
    LEVEL_CHANGE = {
        map_level_change = {
            name = "map_level_change",
            hash = hash("map_level_change"),
        }
    },
    FUZE_FACTORY = {
        create_fuzes = {
            name = "create_fuzes",
            hash = hash("create_fuzes"),
        },
        pick_fuze = {
            name = "pick_fuze",
            hash = hash("pick_fuze"),
        },
        throw_fuze = {
            name = "throw_fuze",
            hash = hash("throw_fuze"),
        }
    }
}
M.BROADSOCK = {
    URL = msg.url("default:/broadsock#script"),
    msg_ids = {
        connect = hash("connect"),
        register_gameobject = hash("register_gameobject"),
        unregister_gameobject = hash("unregister_gameobject"),
        register_factory = hash("register_factory"),
        send_message = hash("send_message"),
        create_room = hash("create_room"),
        join_room = hash("join_room"),
        leave_room = hash("leave_room"),
        get_rooms = hash("get_rooms"),
        player_ready = hash("player_ready"),
        player_commands = hash("player_commands"),
        get_usernames = hash("get_usernames"),
        set_player_username = hash("set_player_username"),
        create_player = hash("create_player"),
        send_reliable_go = hash("send_reliable_go"),
        send_reliable_god = hash("send_reliable_god"),
    },
    connect = function (self, data)
        msg.post(self.URL, "connect", data)
    end,
    register_factory = function (self, data)
        msg.post(self.URL, "register_factory", data)
    end,
    get_rooms = function (self)
        msg.post(self.URL, "get_rooms", {})
    end,
    get_usernames = function (self)
        msg.post(self.URL, "get_usernames", {})
    end,
    create_room = function (self, data)
        msg.post(self.URL, "create_room", data)
    end,
    join_room = function (self, data)
        msg.post(self.URL, "join_room", {data = string.format("%s.%s.%s", M.BASE_MSG_IDS.JOIN_ROOM, data.room_name, data.type)})
    end,
    leave_room = function (self, data)
        msg.post(self.URL, "leave_room", {data = M.BASE_MSG_IDS.LEAVE_ROOM})
    end,
    player_ready = function (self, data)
        msg.post(self.URL, "player_ready", {data = string.format("%s.%s", M.BASE_MSG_IDS.PLAYER_READY, data.room_name)})
    end,
    set_player_username = function (self, data)
        msg.post(self.URL, "set_player_username", {data = string.format("%s.%s", M.BASE_MSG_IDS.SET_PLAYER_USERNAME, data.username)})
    end,
    create_player = function (self)
        msg.post(self.URL, "create_player", {})
    end,
    send_reliable_go = function (self, data)
        msg.post(self.URL, "send_reliable_go", {
            data = stream.writer()
                    .number(data.player_uid)
                    .string(M.BASE_MSG_IDS.RELIABLE_GO)
                    .number(data.map_level)
                    .number(data.fuze_color)
                    .vector3(data.pos)
        })
    end,
    send_reliable_god = function (self, data)
        msg.post(self.URL, "send_reliable_god", {
            data = stream.writer()
                         .number(data.player_uid)
                         .string(M.BASE_MSG_IDS.RELIABLE_GOD)
                         .number(data.fuze_color)
        })
    end,
    send_command = function (self, data)
        msg.post(self.URL, "player_commands", {
            data = data
        })
    end,
}
return M
