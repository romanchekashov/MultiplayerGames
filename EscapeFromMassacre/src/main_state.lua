local Collections = require "src.utils.collections"

local M = {
    pause = true,
    players = Collections.createMap(),
    zombies = Collections.createMap(),
    player = {
        uid = 0,
        username = "N/A"
    },
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
    MSG_GROUPS = {
        COLLISION_RESPONSE = hash("collision_response"),
        CONTACT_POINT_RESPONSE = hash("contact_point_response"),
        ENABLE = hash("enable"),
        DISABLE = hash("disable"),
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
    fuzeToPlayerUid = {}
}

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
        type = player_type or M.PLAYER_TYPE.SURVIVOR
    }
    return obj
end

return M
