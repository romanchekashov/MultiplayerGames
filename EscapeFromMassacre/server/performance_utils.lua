local M = {}

-- https://forum.defold.com/t/can-i-control-dmengine-headless-fps-def-2054-solved/2626
-- http://lua-users.org/wiki/SleepFunction
M.TIMES = {
	_100_MICROSECONDS = 0.0001,
	ONE_MILISECOND = 0.001,
	_10_MILISECONDS = 0.01,
	_20_MILISECONDS = 0.02,
	_30_MILISECONDS = 0.03,
	_100_MILISECONDS = 0.1,
	ONE_SECOND = 1
}

M.CPU_USAGE = {
	LESS_THEN_2_PERCENT = M.TIMES.ONE_SECOND,
	LESS_THEN_4_PERCENT = M.TIMES._100_MILISECONDS,
	ABOUT_5_PERCENT = M.TIMES._30_MILISECONDS,
	ABOUT_33_PERCENT = M.TIMES._20_MILISECONDS,
	ABOUT_55_PERCENT = M.TIMES._10_MILISECONDS,
	ABOUT_75_PERCENT = M.TIMES.ONE_MILISECOND,
	ABOUT_80_PERCENT = M.TIMES._100_MICROSECONDS, -- less number doesn't increase CPU usage
	UNLIMITED = 0
}

function M.create_sleep_fn(sleepTime)
    return function()
        if sleepTime > 0 then
            os.execute("sleep " .. tonumber(sleepTime))
        end
    end
end

M.RATE_LIMIT = 1

function M.createRateLimiter(rateLimit)
	local _rateLimit = rateLimit or M.RATE_LIMIT
	local send_cooldown = _rateLimit

	return function (dt)
		send_cooldown = send_cooldown - dt
		if send_cooldown > 0 then
			return true
		else
			send_cooldown = _rateLimit
		end
		return false
	end
end

return M
