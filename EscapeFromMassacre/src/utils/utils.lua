local M = {wall = {x = 3700, y = 2600, offset = {x = 200, y = 200}}}

function M.random_position()
	return vmath.vector3(math.random(200, 3700), math.random(200, 2600), 0) -- vmath.vector3(x,y,z)
end

return M
