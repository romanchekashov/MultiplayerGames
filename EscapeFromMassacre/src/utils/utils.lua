local M = {wall = {x = 3700, y = 2600, offset = {x = 200, y = 200}}}

function M.get_timestamp_in_ms()
	return socket.gettime() * 1000
end

function M.random_position()
	return vmath.vector3(math.random(200, 3700), math.random(200, 2600), 0) -- vmath.vector3(x,y,z)
end

function M.split(str, delimiter)
	local result = {}
	local index = 1

	for i = index, #str do
		if str:sub(i, i) == delimiter then
			local s = str:sub(index, i - 1)
			index = index + #s + 1
			table.insert(result, s)
		end
	end

	table.insert(result, str:sub(index, #str))

	return result
end

return M
