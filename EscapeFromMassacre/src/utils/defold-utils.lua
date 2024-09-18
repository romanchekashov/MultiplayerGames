local utils = require "src.utils.utils"
local Collections = require "src.utils.collections"


local M = {
	getAngle = function (action)
		local to = go.get_world_position()
		local from = vmath.vector3(action.x, action.y, 0)
		return math.atan2(to.x - from.x, from.y - to.y)
	end,
    collectionIds = Collections.createList(),
    CURRENT_COLLECTION_IDS = {},
    CURRENT_COLLECTION_IDS_2 = {},
    COLLECTION_URLS = {},
    getCollectionId = function (self, key)
        local result = self.CURRENT_COLLECTION_IDS[key]

        if result ~= nil then
            return result
        end

        self.collectionIds:for_each(function (ids)
            if ids[key] ~= nil then
                result = ids[key]
            end
        end)
        print("getCollectionId", key, result)
        return result
    end
}

-- https://forum.defold.com/t/collection-factory/73020/6
-- https://forum.defold.com/t/get-address-of-component-from-collection-factory-instance-solved/66441/3
-- https://defold.com/manuals/factory/#addressing-of-factory-created-objects
local EXCLUDE = {["#"]=true,["."]=true,["@"]=true,}
old_msg_post = msg.post
msg.post = function(url, ...)
    if type(url) ~= "string" or EXCLUDE[url:sub(1, 1)] ~= nil or url:sub(1, 8) == "/screens" then
        --if url == nil then
        --    print(url, ...)
        --end
        old_msg_post(url, ...)
        return
    end

    if M.COLLECTION_URLS[url] == nil then
        local res = utils.split(url, "#")
        -- print(url, res[1], #res > 1 and res[2] or nil, M.CURRENT_COLLECTION_IDS[res[1]])
        local collectionId = M.CURRENT_COLLECTION_IDS[res[1]]
        if collectionId == nil then
            collectionId = M.CURRENT_COLLECTION_IDS_2[res[1]]
        end
        print("msg.post", url, collectionId)
        if collectionId ~= nil then
            M.COLLECTION_URLS[url] = msg.url("default", collectionId, #res > 1 and res[2] or nil)
        end
    end

    old_msg_post(M.COLLECTION_URLS[url] or url, ...)
end

old_factory_create = factory.create
factory.create = function(url, ...)
    if type(url) ~= "string" or EXCLUDE[url:sub(1, 1)] ~= nil or url:sub(1, 8) == "/screens" then
        return old_factory_create(url, ...)
    end

    if M.COLLECTION_URLS[url] == nil then
        local res = utils.split(url, "#")
        -- print(url, res[1], #res > 1 and res[2] or nil, M.CURRENT_COLLECTION_IDS[res[1]])
        local collectionId = M.CURRENT_COLLECTION_IDS[res[1]]
        if collectionId == nil then
            collectionId = M.CURRENT_COLLECTION_IDS_2[res[1]]
        end
        print("factory.create", url, collectionId)
        if collectionId ~= nil then
            M.COLLECTION_URLS[url] = msg.url("default", collectionId, #res > 1 and res[2] or nil)
        end
    end

    return old_factory_create(M.COLLECTION_URLS[url] or url, ...)
end

local function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function M.SET_CURRENT_COLLECTION_IDS(ids)
    M.collectionIds:add(ids)
    --if tablelength(M.CURRENT_COLLECTION_IDS) > 0 then
    --    M.CURRENT_COLLECTION_IDS_2 = ids
    --else
    --    M.CURRENT_COLLECTION_IDS = ids
    --end
    M.CURRENT_COLLECTION_IDS = ids
    M.COLLECTION_URLS = {}
    for key, value in pairs(ids) do
        print("CURRENT_COLLECTION_IDS", key, value)
    end
end

local getAngle = M.getAngle

-- https://forum.defold.com/t/help-with-virtual-gamepad-example/46337/2
function M.getRotation(action)
    return vmath.quat_rotation_z(getAngle(action))
end


M.virtualGamepadLeftStickPressed = false

local pauseBound = {
    x1 = 0,
    x2 = 0,
    y1 = 0,
    y2 = 0
}

function M.setVirtualGamepadLeftStickBound(pos, size)
    local diffX = size.x / 2
    local diffY = size.y / 2
    pauseBound.x1 = pos.x - diffX
    pauseBound.x2 = pos.x + diffX
    pauseBound.y1 = pos.y - diffY
    pauseBound.y2 = pos.y + diffY
end

function M.insideVirtualGamepadLeftStickBound(action)
    return action.screen_x >= pauseBound.x1 and action.screen_x <= pauseBound.x2
        and action.screen_y >= pauseBound.y1 and action.screen_y <= pauseBound.y2
end

return M
