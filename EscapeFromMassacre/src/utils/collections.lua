local M = {}

function M.createList()
	return {
		items = {},
		length = 0,
		add = function (self, o)
			table.insert(self.items, o)
			self.length = self.length + 1
		end,
		-- index is 1-based
		removeFirst = function (self)
			if self.length == 0 then
				return
			end
			table.remove(self.items, 1)
			self.length = self.length - 1
		end,
		remove = function (self, index)
			table.remove(self.items, index)
			self.length = self.length - 1
		end,
		getLast = function (self)
			if self.length == 0 then
				return
			end
			return self.items[self.length]
		end,
		for_each = function (self, fn)
			for k, v in pairs(self.items) do
				fn(v)
			end
		end,
		find = function (self, field_name, field_val)
			for k, v in ipairs(self.items) do
				if v[field_name] == field_val then
					return v
				end
			end
		end
	}
end

-- Set
function M.createSet()
	return {
		items = {},
		length = 0,
		has = function (self, o)
			if self.items[o] ~= nil then
				return true
			end
			return false
		end,
		add = function (self, o)
			if not self:has(o) then
				self.items[o] = true
				self.length = self.length + 1
			end
		end,
		remove = function (self, o)
			if self.items[o] ~= nil then
				self.items[o] = nil
				self.length = self.length - 1
			end
		end,
		for_each = function (self, fn)
			for k, v in pairs(self.items) do
				fn(k)
			end
		end
	}
end

-- Map
function M.createMap()
	return {
		items = {},
		length = 0,
		get = function(self, key)
			return self.items[key]
		end,
		has = function (self, key)
			if self.items[key] ~= nil then
				return true
			end
			return false
		end,
		put = function (self, key, o)
			if not self:has(key) then
				self.length = self.length + 1
			end
			self.items[key] = o
		end,
		remove = function (self, key)
			if self.items[key] ~= nil then
				local removed = self.items[key]
				self.items[key] = nil
				self.length = self.length - 1
				return removed
			end
		end,
		for_each = function (self, fn)
			for k, v in pairs(self.items) do
				fn(k, v)
			end
		end
	}
end

return M
