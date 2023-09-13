local M = {
    BASE_MSG_IDS = {
        ROOMS = "NOT_GS_ROOMS",
        ROOMS_GET = "NOT_GS_ROOMS_GET",
        CREATE_ROOM = "NOT_GS_CREATE_ROOM",
        JOIN_ROOM = "NOT_GS_JOIN_ROOM",
        PLAYER_READY = "NOT_GS_PLAYER_READY",
        SET_PLAYER_USERNAME = "NOT_GS_SET_PLAYER_USERNAME",
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
        get_rooms = hash("get_rooms"),
        player_ready = hash("player_ready"),
        set_player_username = hash("set_player_username"),
    },
    connect = function (self, data)
        msg.post(self.URL, "connect", data)
    end,
    register_factory = function (self, data)
        msg.post(self.URL, "register_factory", data)
    end,
    get_rooms = function (self, data)
        msg.post(self.URL, "get_rooms", data)
    end,
    create_room = function (self, data)
        msg.post(self.URL, "create_room", data)
    end,
    join_room = function (self, data)
        msg.post(self.URL, "join_room", {data = string.format("%s.%s.%s", M.BASE_MSG_IDS.JOIN_ROOM, data.room_name, data.type)})
    end,
    player_ready = function (self, data)
        msg.post(self.URL, "player_ready", {data = string.format("%s.%s", M.BASE_MSG_IDS.PLAYER_READY, data.room_name)})
    end,
    set_player_username = function (self, data)
        msg.post(self.URL, "set_player_username", {data = string.format("%s.%s", M.BASE_MSG_IDS.SET_PLAYER_USERNAME, data.username)})
    end,
}
return M
