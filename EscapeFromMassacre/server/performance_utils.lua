local M = {}

-- https://forum.defold.com/t/can-i-control-dmengine-headless-fps-def-2054-solved/2626
-- http://lua-users.org/wiki/SleepFunction
local _100_MICROSECONDS = 0.0001
local ONE_MILISECOND = 0.001
local _10_MILISECONDS = 0.01
local _20_MILISECONDS = 0.02
local _30_MILISECONDS = 0.03
local _100_MILISECONDS = 0.1
local ONE_SECOND = 1

M.CPU_USAGE = {
	LESS_THEN_2_PERCENT = ONE_SECOND,
	LESS_THEN_4_PERCENT = _100_MILISECONDS,
	ABOUT_5_PERCENT = _30_MILISECONDS,
	ABOUT_33_PERCENT = _20_MILISECONDS,
	ABOUT_55_PERCENT = _10_MILISECONDS,
	ABOUT_75_PERCENT = ONE_MILISECOND,
	ABOUT_80_PERCENT = _100_MICROSECONDS, -- less number doesn't increase CPU usage
	UNLIMITED = 0
}

function M.create_sleep_fn(sleepTime)
    return function()
        if sleepTime > 0 then
            os.execute("sleep " .. tonumber(sleepTime))
        end
    end
end

return M
