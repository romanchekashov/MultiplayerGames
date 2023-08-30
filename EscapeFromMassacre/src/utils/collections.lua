local M = {}

Set = {items = {}, length = 0}

function Set:new()
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

-- Map
Map = {items = {}, length = 0}

function Map:new()
	local items = {}   -- create object if user does not provide one
	setmetatable(items, self)
	self.__index = self
	self.length = 0
	return items
end

function Map:put(key, obj)
	self.items[key] = obj
	self.length = self.length + 1
end

function Map:remove(key)
	if self.items[key] then
		self.items[key] = nil
		self.length = self.length - 1
	end
end

function Map:has(key)
	if self.items[key] then
		return true
	end

	return false
end

function M.createMap()
	return Map:new()
end

return M