local M = {}

GameObject = {id = nil, pos = nil, rot = nil, scale = nil}

function GameObject:new(id, pos)
	local items = {}   -- create object if user does not provide one
	setmetatable(items, self)
	self.__index = self
	self.length = 0
	return items
end

function Set:add(o)
	self.items[o] = true
	self.length = self.length + 1
end

function Set:remove(o)
	if self.items[o] then
		self.items[o] = nil
		self.length = self.length - 1
	end
end

function Set:has(o)
	if self.items[o] then
		return true
	end

	return false
end

function M.createSet()
	return Set:new()
end

return M