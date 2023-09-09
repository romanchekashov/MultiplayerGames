local Collections = require "src.utils.collections"

local M = {
    pause = true,
    players = Collections.createMap(),
    zombies = Collections.createMap(),
    player = {
        uid = 0,
        username = "N/A"
    },
    bulletBelongToPlayerUid = {},
    playerUidToScore = {},
    playerUidToWsLatency = {},
    SOUND = {
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
        end
    },
    COLORS = {
        GREEN = vmath.vector4(39 / 255, 174 / 255, 96 / 255, 0),
        RED_DARK = vmath.vector4(128 / 255, 36 / 255, 15 / 255, 0),
    },
    LEVELS = {
        HOUSE = 1,
        BASEMENT = 0
    },
    playerSlots = {}
}

M.playerOnLevel = M.LEVELS.HOUSE

function M.increasePlayerScore(killer_uid)
	if killer_uid ~= nil and killer_uid ~= "" then
        killer_uid = tostring(killer_uid)
        if M.playerUidToScore[killer_uid] == nil then
            M.playerUidToScore[killer_uid] = 0
        end

        M.playerUidToScore[killer_uid] = M.playerUidToScore[killer_uid] + 1
        -- local player = M.players:get(tonumber(killer_uid))
        -- if player ~= nil then
        --     player.score = player.score + 1
        -- end
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

function M.createGameObject(uid, username, go_id, level)
    local obj = {
        uid = uid or nil,
        username = username or nil,
        go_id = go_id or nil,
        score = 0,
        level = level or M.LEVELS.HOUSE
    }
    return obj
end

return M
