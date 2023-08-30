local nk = require("nakama")

local M = {}

function M.match_init(context, setupstate)
  local gamestate = {
    presences = {}
  }

  local tickrate = 1 -- per sec
  local label = ""

  return gamestate, tickrate, label
end

function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  local acceptuser = true
  return state, acceptuser
end

function M.match_join(context, dispatcher, tick, state, presences)
  for _, presence in ipairs(presences) do
    state.presences[presence.session_id] = presence
  end

  return state
end

function M.match_leave(context, dispatcher, tick, state, presences)
  for _, presence in ipairs(presences) do
    state.presences[presence.session_id] = nil
  end

  return state
end

function M.match_loop(context, dispatcher, tick, state, messages)
  for _, p in pairs(state.presences) do
    nk.logger_info(string.format("Presence %s named %s", p.user_id, p.username))
  end

  for _, m in ipairs(messages) do
    nk.logger_info(string.format("Received %s from %s", m.data, m.sender.username))
    local decoded = nk.json_decode(m.data)

    for k, v in pairs(decoded) do
      nk.logger_info(string.format("Key %s contains value %s", k, v))
    end

    -- PONG message back to sender
    dispatcher.broadcast_message(1, m.data, { m.sender })
  end

  return state
end

function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  local message = "Server shutting down in " .. grace_seconds .. " seconds"
  dispatcher.broadcast_message(2, message)

  return nil
end

local function match_signal(context, dispatcher, tick, state, data)
  return state, "signal received: " .. data
end

return M
