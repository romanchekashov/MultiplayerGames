local Collections = require "src.utils.collections"
local MSG = require "src.utils.messages"
local utils = require "src.utils.utils"
local stream = require "client.stream"
local debugUtils = require "src.utils.debug-utils"
local log = debugUtils.createLog("[MAIN_STATE]").log

local PLAYER_STATUS = {
    DISCONNECTED = 0,
    CONNECTED = 1,
    READY = 2,
    PLAYING = 3,
    DEAD = 4
}

local M = {
    factories = {},
    gameobjects = {},
    gameobject_count = 0,
    go_uid_sequence = 0,
    gameTime = 0,
    isGateOpen = false,

    fuzeBoxIdsToColor = {},
    fuzeBoxColorToState = {},

    fuzesIdToColor = {},
    fuzesColorToState = {},
    fuzeToPlayerUid = {},
    fixedFuzeBoxCount = 0,

    pause = true,
    players = Collections.createMap(),
    game_over_players = Collections.createMap(),
    zombies = Collections.createMap(),
    uid_to_username = Collections.createMap(),
    rooms = Collections.createList(),
    INITIAL_FUZES_CREATE = {},
    FACTORY_TYPES = {
        player = "player",
        zombie = "zombie",
        bullet = "bullet",
        fuze = "fuze",
        fuze_box = "fuze-box",
    },
    selectedRoom = nil,
    GAME_STATES = {
        START = 1,
        RUNNING = 2,
        END = 3,
        LOBBY = 4,
    },
    RECREATE_PLAYER_TIMEOUT_IN_SEC = 2,
    GAME_START_TIMEOUT_IN_SEC = 5,
    -- GAME_TIMEOUT_IN_SEC = 60 * 15,
    GAME_TIMEOUT_IN_SEC = 60 * 1,
    PLAYER_STATUS = PLAYER_STATUS,
    PLAYER_TYPE = {
        SURVIVOR = 0,
        FAMILY = 1
    },
    bulletBelongToPlayerUid = {},
    playerUidToScore = {},
    playerUidToWsLatency = {},
    MSG_IDS = {
        GAME_START = hash("game_start")
    },
    MSG_GROUPS = {
        COLLISION_RESPONSE = hash("collision_response"),
        CONTACT_POINT_RESPONSE = hash("contact_point_response"),
        ENABLE = hash("enable"),
        DISABLE = hash("disable"),
        EXIT = hash("exit"),
        WALL = hash("wall"),
        BOX = hash("box"),
        FUZE = hash("fuze"),
        FUZE_BOX = hash("fuze-box"),
        PLAYER = hash("player")
    },
    HAS_GAMEPAD = false,
    SOUND = {
        level_up = function ()
            msg.post("default:/sound#level_up", "play_sound")
        end,
        laser = function ()
            msg.post("default:/sound#laser", "play_sound")
        end,
        pistol_9mm_shoot_1 = function ()
            msg.post("default:/sound#pistol_9mm_shoot_1", "play_sound")
        end,
        pistol_9mm_shoot_2 = function ()
            msg.post("default:/sound#pistol_9mm_shoot_2", "play_sound")
        end,
        shotgun_fire_1 = function ()
            msg.post("default:/sound#shotgun_fire_1", "play_sound")
        end,
        loop_step = {
            play = function ()
                msg.post("default:/sound#step", "play_sound")
            end,
            stop = function ()
                msg.post("default:/sound#step", "stop_sound")
            end
        },
        loop_run = {
            play = function ()
                msg.post("default:/sound#run", "play_sound")
            end,
            stop = function ()
                msg.post("default:/sound#run", "stop_sound")
            end
        }
    },
    GAME_SCREENS = {
        LOBBY = 0,
        GAME = 1
    },
    MAP_LEVELS = {
        HOUSE = 1,
        BASEMENT = 0
    },
    FUZE = {
        RED = 1,
        GREEN = 2,
        BLUE = 3,
        YELLOW = 4,
    },
    playerSlots = {}
}

M.player = {
    uid = 0,
    username = "N/A",
    type = M.PLAYER_TYPE.SURVIVOR,
    room = nil,
    status = PLAYER_STATUS.CONNECTED
}

M.gameTime = M.GAME_TIMEOUT_IN_SEC
M.currentGameState = M.GAME_STATES.LOBBY
M.playerOnMapLevel = M.MAP_LEVELS.HOUSE
M.fuzeBoxColorToState = {
    [M.FUZE.RED] = 0,
    [M.FUZE.GREEN] = 0,
    [M.FUZE.BLUE] = 0,
    [M.FUZE.YELLOW] = 0
}
M.fuzesColorToState = {
    [M.FUZE.RED] = 0,
    [M.FUZE.GREEN] = 0,
    [M.FUZE.BLUE] = 0,
    [M.FUZE.YELLOW] = 0
}

M.isServer = false

function M.increasePlayerScore(killer_uid)
	if killer_uid ~= nil and killer_uid ~= "" then
        killer_uid = tostring(killer_uid)
        if M.playerUidToScore[killer_uid] == nil then
            M.playerUidToScore[killer_uid] = 0
        end

        M.playerUidToScore[killer_uid] = M.playerUidToScore[killer_uid] + 1

        local player = M.players:get(tonumber(killer_uid))
        if player ~= nil then
            player.score = player.score + 1
			msg.post(player.go_id, "update_score", {uid = player.uid, score = player.score})
        end
    end
end

function M.playerUidToScoreSortedForEach(fn)
    local list = {}

	M.players:for_each(function (player)
		local item = {player = player, score = M.playerUidToScore[tostring(player.uid)]}
		table.insert(list, item)
	end)

	local function compare(a,b)
		return a.score > b.score
	end

	table.sort(list, compare)

	for _, item in ipairs(list) do
        fn(item.player)
	end
end

local pauseBound = {
    x1 = 0,
    x2 = 0,
    y1 = 0,
    y2 = 0
}

function M.setPauseBound(pos, size)
    local diffX = size.x / 2
    local diffY = size.y / 2
    pauseBound.x1 = pos.x - diffX
    pauseBound.x2 = pos.x + diffX
    pauseBound.y1 = pos.y - diffY
    pauseBound.y2 = pos.y + diffY
end

function M.insidePauseBound(action)
    return action.screen_x >= pauseBound.x1 and action.screen_x <= pauseBound.x2
        and action.screen_y >= pauseBound.y1 and action.screen_y <= pauseBound.y2
end

function M.createGameObject(uid, username, go_id, player_type, map_level)
    local obj = {
        uid = uid or nil,
        username = username or nil,
        go_id = go_id or nil,
        score = 0,
        map_level = map_level or M.MAP_LEVELS.HOUSE,
        health = 100,
        manna = 100,
        level = 1,
        xp = 0,
        type = player_type or M.PLAYER_TYPE.SURVIVOR,

        is_family = function (self)
            return self.type == M.PLAYER_TYPE.FAMILY
        end
    }
    return obj
end

function M.createRoom(name)
    return {
        name = name or "n/a",
        survivors = Collections.createSet(),
        family = Collections.createSet(),
        ready_players = 0,
        ready_players_map = Collections.createMap(),
        pressStart = function (self, playerUid)
            -- self.startPressCount:put(playerUid, true)
        end,
        joinFamily = function (self, playerUid)
            if self.survivors:has(playerUid) then
                self.survivors:remove(playerUid)
                -- self.startPressCount:remove(playerUid)
            end
            self.family:add(playerUid)
            -- print("joinFamily", self.family.length, self.survivors.length)
        end,
        joinSurvivors = function (self, playerUid)
            if self.family:has(playerUid) then
                self.family:remove(playerUid)
                -- self.startPressCount:remove(playerUid)
            end
            self.survivors:add(playerUid)
            -- print("joinSurvivors", self.family.length, self.survivors.length)
        end,
        leave = function (self, playerUid)
            if self.family:has(playerUid) then
                self.family:remove(playerUid)
            end
            if self.survivors:has(playerUid) then
                self.survivors:remove(playerUid)
            end
            -- self.startPressCount:remove(playerUid)
        end
    }
end

-- NOT_GS_ROOMS.2.Room 1.family.15.survivors.ready.0.Room 2.family.survivors.ready.0
function M.setRooms(str)
    --print(str)
    local sr = stream.reader(str, #str)
    local rooms = Collections.createList()
    local room = nil

    sr.string() -- NOT_GS_ROOMS
    local count = sr.number()
    for _=1,count do
        room = M.createRoom(sr.string())
        rooms:add(room)
        sr.string() -- family
        local uid = sr.number()
        while uid ~= nil do
            room:joinFamily(uid)
            room.ready_players_map:put(uid, sr.number())
            uid = sr.number()
        end
        -- survivors
        uid = sr.number()
        while uid ~= nil do
            room:joinSurvivors(uid)
            room.ready_players_map:put(uid, sr.number())
            uid = sr.number()
        end
        -- ready
        room.ready_players = sr.number()
    end

    M.rooms = rooms
	msg.post("/gui#rooms", MSG.ROOMS.RECIEVE_ROOMS.name)
end

function M.setUsernames(str)
    print(str)
    local map = Collections.createMap()
    local uid = -1
    local username = ""
    local index = 17

    for i = index, #str do
        if str:sub(i, i) == "." then
            local s = str:sub(index, i - 1)
            index = index + #s + 1
            uid = tonumber(s)
        elseif str:sub(i, i) == "#" then
            local s = str:sub(index, i - 1)
            index = index + #s + 1
            local len = tonumber(s)
            username = str:sub(index, index + len - 1)
            index = index + #username
            print(uid, username, len)
            map:put(uid, username)
        end
    end

    --table.insert(result, str:sub(index, #str))
    map:for_each(function (v)
        print(v)
    end)
    M.uid_to_username = map
	msg.post("/gui#rooms", MSG.ROOMS.RECIEVE_USERNAMES.name)
end

function M.register_gameobject(uid, go_id, type)
    assert(go_id, "You must provide a game object id")
    assert(type and M.factories[type], "You must provide a known game object type")
    log("register_gameobject", go_id, type)
    M.go_uid_sequence = M.go_uid_sequence + 1
    local gouid = tostring(uid) .. "_" .. M.go_uid_sequence
    M.gameobjects[gouid] = { id = go_id, type = type, gouid = gouid, player_uid = uid }
    M.gameobject_count = M.gameobject_count + 1
end

function M.unregister_gameobject(message)
    local id = message.id
    --local killer_uid = message.killer_uid
    log("unregister_gameobject", id)
    for gouid,gameobject in pairs(M.gameobjects) do
        if gameobject.id == id then
            M.gameobjects[gouid] = nil
            M.gameobject_count = M.gameobject_count - 1

            --local sw = stream.writer().string("GOD").string(gouid)
            --if killer_uid ~= nil then
            --    sw.string(killer_uid)
            --end
            --instance.send(sw.tostring())
            return
        end
    end
    error("Unable to find game object")
end
function M.register_factory(obj)
    assert(obj.url, "You must provide a factory URL")
    assert(obj.type, "You must provide a game object type")
    log("register_factory", obj.url, obj.type)
    M.factories[obj.type] = obj.url
end
function M.has_factory(type)
    assert(type, "You must provide a game object type")
    return M.factories[type] ~= nil
end
function M.get_factory_url(type)
    assert(type, "You must provide a game object type")
    return M.factories[type]
end
function M.tostring(self)
    local sw = stream.writer()
    sw.number(-1)
    sw.string("GAME_STATE")
    sw.number(self.currentGameState)
    sw.string(tostring(self.gameTime))
    sw.string("GATE")
    sw.number(0) -- 0 - closed, 1 - opened
    -- fuze boxes
    sw.string("FUZE_BOX_1")
    sw.number(1) -- 1: red, 2: green, 3: blue, 4: yellow
    sw.number(0) -- 0: broken, 1: working
    sw.string("FUZE_BOX_2")
    sw.number(2)
    sw.number(0)
    sw.string("FUZE_BOX_3")
    sw.number(3)
    sw.number(0)
    sw.string("FUZE_BOX_4")
    sw.number(4)
    sw.number(0)
    -- fuzes
    sw.string("FUZE_1")
    sw.number(1) -- 1: red, 2: green, 3: blue, 4: yellow
    --sw.vector3(pos)
    sw.number(0) -- 0: not used, 1: used
    sw.number(123) -- player with uid 123 has a red fuze
    sw.string("FUZE_2")
    sw.number(2)
    --sw.vector3(pos)
    sw.number(0)
    sw.number(0) -- fuze is on the ground
    sw.string("FUZE_3")
    sw.number(3)
    --sw.vector3(pos)
    sw.number(0)
    sw.number(0)
    sw.string("FUZE_4")
    sw.number(4)
    --sw.vector3(pos)
    sw.number(0)
    sw.number(0)
    -- game objects
    for gouid, v in pairs(self.gameobjects) do
        sw.string("GO")
        sw.string(v.type)
        sw.string(gouid)

        local pos = go.get_position(v.id)
        local rot = go.get_rotation(v.id)
        local scale = go.get_scale(v.id)
        sw.vector3(pos)
        sw.quat(rot)
        sw.vector3(scale)

        if M.FACTORY_TYPES.player == v.type then
            sw.number(v.playerOnMapLevel)
            sw.number(v and v.health or 100)
            sw.number(v and v.score or 0)
            --sw.number(0) -- 0: disconnected, 1: connected
        end
        -- log(gameobject_count, gouid, tostring(gameobject.type), pos, rot, scale, tostring(sw.tostring()))
    end

    return sw.tostring()
end

return M
