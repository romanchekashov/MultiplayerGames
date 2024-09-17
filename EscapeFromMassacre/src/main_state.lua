local Collections = require "src.utils.collections"
local MSG = require "src.utils.messages"
local utils = require "src.utils.utils"
local stream = require "client.stream"

local M = {
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
    playerSlots = {},
    fuzesIdToColor = {},
    fuzeBoxIdsToColor = {},
    fuzeToPlayerUid = {},
    fixedFuzeBoxCount = 0
}

M.player = {
    uid = 0,
    username = "N/A",
    type = M.PLAYER_TYPE.SURVIVOR,
    room = nil
}

M.currentGameState = M.GAME_STATES.LOBBY

M.playerOnMapLevel = M.MAP_LEVELS.HOUSE

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

return M
