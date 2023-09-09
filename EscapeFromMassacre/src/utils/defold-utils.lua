local M = {
	getAngle = function (action)
		local to = go.get_world_position()
		local from = vmath.vector3(action.x, action.y, 0)
		return math.atan2(to.x - from.x, from.y - to.y)
	end
}

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
