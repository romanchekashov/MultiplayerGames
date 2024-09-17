local collections = require "src.utils.collections"

-- print decorator
old_print = print
print = function(...)
    local calling_script = debug.getinfo(2).short_src
    old_print(calling_script, ...)
end

local M = {}
M.isProd = false
local isDebug = false
local isTest = false

function string:split(inSplitPattern, outResults)
    if not outResults then
        outResults = {}
    end
    local theStart = 1
    local theSplitStart, theSplitEnd = string.find(self, inSplitPattern, theStart)
    while theSplitStart do
        table.insert(outResults, string.sub(self, theStart, theSplitStart - 1))
        theStart = theSplitEnd + 1
        theSplitStart, theSplitEnd = string.find(self, inSplitPattern, theStart)
    end
    table.insert(outResults, string.sub(self, theStart))
    return outResults
end

function table.val_to_str(v)
    if "string" == type(v) then
        v = string.gsub(v, "\n", "\\n")
        if string.match(string.gsub(v, "[^'\"]", ""), '^"+$') then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v, '"', '\\"') .. '"'
    else
        return "table" == type(v) and table.tostring(v) or
                tostring(v)
    end
end

function table.key_to_str(k)
    if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
        return k
    else
        return "[" .. table.val_to_str(k) .. "]"
    end
end

function table.tostring(tbl)
    local result, done = {}, {}
    for k, v in ipairs(tbl) do
        table.insert(result, table.val_to_str(v))
        done[k] = true
    end
    for k, v in pairs(tbl) do
        if not done[k] then
            table.insert(result,
                table.key_to_str(k) .. ":" .. table.val_to_str(v))
        end
    end
    return "{" .. table.concat(result, ",") .. "}"
end

local function is_table(var)
    return type(var) == "table"
end

function M.isTest(is)
    if is ~= nil then
        isTest = is
    end
    return isTest
end

function M.debug(isOn)
    if isOn then
        print("Logger ON")
    else
        print("Logger OFF")
    end
    isDebug = isOn
end

function M.print(arguments)
    if isDebug then
        print(arguments)
    end
end

function M.table_to_str(tbl)
    local line = "{"
    for index, data in ipairs(tbl) do
        line = line .. "[" .. index .. "] {"
        for key, value in pairs(data) do
            -- print('\t', key, value)
            if type(value) == "table" then
                line = line .. key .. ', '.. table.concat(value, ";") .. ', '
            else
                line = line .. key .. ', '.. value .. ', '
            end
        end
        line = line .. "}"
    end
    line = line .. "}"
    return line
end

function M.printTable(tbl)
    if not isDebug then
        return
    end

    -- for _, line in ipairs(tbl) do
    --     print(table.concat(line, ", "))
    -- end
    print(M.table_to_str(tbl))
end

function M.createLog(prefix)
    local instance = {}
    local _prefix = prefix or "LOG"
    local prev_msgs = collections.createSet()
    -- You need to use local arg = {...} to assign function parameters to a table or
    -- use select(i, ...) to get i-th parameter from the list and
    -- select('#', ...) to get the number of parameters.
    function instance.log(...)
        if not isDebug then
            return
        end
        -- local msg = select(1, ...)
        local arg = {...}
        local msg = ""

        for i=1,#arg do
            local v = tostring(arg[i])
            if is_table(arg[i]) then
                v = M.table_to_str(arg[i])
            end
            msg = msg .. tostring(v)
        end

        if not prev_msgs:has(msg) then
            print(_prefix, ...)
            prev_msgs:add(msg)
        end
    end

    return instance
end

return M
