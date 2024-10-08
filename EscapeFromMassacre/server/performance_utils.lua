local M = {}

-- https://forum.defold.com/t/can-i-control-dmengine-headless-fps-def-2054-solved/2626
-- http://lua-users.org/wiki/SleepFunction
M.TIMES = {
	_100_MICROSECONDS = 0.0001,
	ONE_MILISECOND = 0.001,
	_10_MILISECONDS = 0.01,
	_20_MILISECONDS = 0.02,
	_25_MILISECONDS = 0.025,
	_30_MILISECONDS = 0.03,
	_50_MILISECONDS = 0.05,
	_100_MILISECONDS = 0.1,
	_200_MILISECONDS = 0.2,
	_300_MILISECONDS = 0.3,
	_500_MILISECONDS = 0.5,
	ONE_SECOND = 1
}

M.CPU_USAGE = {
	LESS_THEN_2_PERCENT = M.TIMES.ONE_SECOND,
	LESS_THEN_3_PERCENT = M.TIMES._500_MILISECONDS,
	LESS_THEN_3_5_PERCENT = M.TIMES._200_MILISECONDS,
	ABOUT_3_BUT_IN_DOCKER_6_PERCENT_AT_MIN = M.TIMES._100_MILISECONDS, -- update called 8 times in Ubuntu 22.04.4 LTS(amd64)
	ABOUT_4_BUT_IN_DOCKER_10_PERCENT_AT_MIN = M.TIMES._50_MILISECONDS, -- update called 17 times in Ubuntu 22.04.4 LTS(amd64)
	ABOUT_5_BUT_IN_DOCKER_15_PERCENT_AT_MIN = M.TIMES._30_MILISECONDS, -- update called 28 times in Ubuntu 22.04.4 LTS(amd64)
	ABOUT_20_PERCENT = M.TIMES._25_MILISECONDS,
	ABOUT_33_PERCENT = M.TIMES._20_MILISECONDS,
	ABOUT_55_PERCENT = M.TIMES._10_MILISECONDS,
	ABOUT_75_PERCENT = M.TIMES.ONE_MILISECOND,
	ABOUT_80_PERCENT = M.TIMES._100_MICROSECONDS, -- less number doesn't increase CPU usage
	UNLIMITED = 0
}

function M.create_sleep_fn(sleepTime)
    return function()
        if sleepTime > 0 then
			--socket.select(nil, nil, tonumber(sleepTime))
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
