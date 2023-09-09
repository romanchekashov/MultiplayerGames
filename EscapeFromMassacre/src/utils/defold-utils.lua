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

return M
