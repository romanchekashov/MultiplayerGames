local Collections = require "src.utils.collections"
local MSG = require "src.utils.messages"
local utils = require "src.utils.utils"

local M = {
    pause = true,
    players = Collections.createMap(),
    zombies = Collections.createMap(),
    rooms = Collections.createList(),
    selectedRoom = nil,
    GAME_STATES = {
        START = 1,
        RUNNING = 2,
        END = 3,
        LOBBY = 4,
    },
    GAME_START_TIMEOUT_IN_SEC = 5,
    -- GAME_TIMEOUT_IN_SEC = 60 * 15,
    GAME_TIMEOUT_IN_SEC = 30,
    PLAYER_TYPE = {
        SURVIVOR = 0,
        FAMILY = 1
    },
    bulletBelongToPlayerUid = {},
    playerUidToScore = {},
    playerUidToWsLatency = {},
    ACTION_IDS = {
        JOIN = hash("join"),
        USE = hash("use"),
        GAMEPAD = {
            CONNECTED = hash("gamepad_connected"),
            DISCONNECTED = hash("gamepad_dicconnected"),
            START = hash("gamepad_start"),
            RIGHT_STICK = {
                RIGHT = hash("rs_right"),
                LEFT = hash("rs_left"),
                UP = hash("rs_up"),
                DOWN = hash("rs_down")
            },
            LEFT_STICK = {
                RIGHT = hash("ls_right"),
                LEFT = hash("ls_left"),
                UP = hash("ls_up"),
                DOWN = hash("ls_down")
            }
        }
    },
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
    COLORS = {
        GREEN = vmath.vector4(39 / 255, 174 / 255, 96 / 255, 0),
        RED_DARK = vmath.vector4(128 / 255, 36 / 255, 15 / 255, 0),
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
M.isGamepadActionId = {
    [M.ACTION_IDS.GAMEPAD.CONNECTED] = true,
    [M.ACTION_IDS.GAMEPAD.START] = true,

    [M.ACTION_IDS.GAMEPAD.LEFT_STICK.DOWN] = true,
    [M.ACTION_IDS.GAMEPAD.LEFT_STICK.UP] = true,
    [M.ACTION_IDS.GAMEPAD.LEFT_STICK.RIGHT] = true,
    [M.ACTION_IDS.GAMEPAD.LEFT_STICK.LEFT] = true,

    [M.ACTION_IDS.GAMEPAD.RIGHT_STICK.DOWN] = true,
    [M.ACTION_IDS.GAMEPAD.RIGHT_STICK.UP] = true,
    [M.ACTION_IDS.GAMEPAD.RIGHT_STICK.RIGHT] = true,
    [M.ACTION_IDS.GAMEPAD.RIGHT_STICK.LEFT] = true,
}
M.isGamepadLeftStickActionId = {
    [M.ACTION_IDS.GAMEPAD.LEFT_STICK.DOWN] = true,
    [M.ACTION_IDS.GAMEPAD.LEFT_STICK.UP] = true,
    [M.ACTION_IDS.GAMEPAD.LEFT_STICK.RIGHT] = true,
    [M.ACTION_IDS.GAMEPAD.LEFT_STICK.LEFT] = true,
}
M.isGamepadRightStickActionId = {
    [M.ACTION_IDS.GAMEPAD.RIGHT_STICK.DOWN] = true,
    [M.ACTION_IDS.GAMEPAD.RIGHT_STICK.UP] = true,
    [M.ACTION_IDS.GAMEPAD.RIGHT_STICK.RIGHT] = true,
    [M.ACTION_IDS.GAMEPAD.RIGHT_STICK.LEFT] = true,
}

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
        startPressPlayers = Collections.createMap(),
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

function M.setRooms(str)
    print(str)
    local res = utils.split(str, ".")
    local rooms = Collections.createList()
    local room = nil
    local is_family = false
    local is_ready = false
    local client_uid = nil

    for index, value in ipairs(res) do
        if index ~= 1 then
            if value == "family" then
                is_family = true
            end
            if value == "survivors" then
                is_family = false
            end
            if value == "ready" then
                is_ready = true
            end
            if value ~= "survivors" and value ~= "family" and value ~= "ready" then
                num = tonumber(value)
                if num == nil then
                    room = M.createRoom(value)
                    rooms:add(room)
                else
                    if is_ready then
                        room.ready_players = num
                        is_ready = false
                    else
                        if is_family then
                            room:joinFamily(num)
                        else
                            room:joinSurvivors(num)
                        end
                    end
                end
            end
        end
    end
    M.rooms = rooms
	msg.post("/gui#rooms", MSG.ROOMS.RECIEVE_ROOMS.name)
end

return M
