local Collections = require "src.utils.collections"

local M = {
    pause = false, 
    players = Collections.createMap(),
    zombies = Collections.createMap(),
    player = {
        uid = 0,
        username = "N/A"
    }
}

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

function M.createGameObject(id, username, pos, rot, scale)
    local obj = {
        id = id or nil,
        username = username or nil,
        pos = pos or nil,
        rot = rot or nil,
        scale = scale or nil
    }
    return obj
end

return M
