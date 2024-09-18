local Collections = require "src.utils.collections"
local player_commands = require "client.player_commands"

local M = {
    playerCommands = Collections.createMap(),
    is_pressed = function (self, uid, action_id)
        local playerCommands = self.playerCommands:get(uid)
        local num_action_id = playerCommands.commands:getLast().num_action_id
        local num_action_state = playerCommands.commands:getLast().num_action_state

        return num_action_id == player_commands.ActionIdToCode[action_id] and num_action_state == 1
    end,
    consumeCommands = function (self, from_uid, streamReader)
        local playerCommands = self.playerCommands:get(from_uid)
        if playerCommands == nil then
            self.playerCommands:put(from_uid, {commands = Collections.createList()})
            playerCommands = self.playerCommands:get(from_uid)
        end

        local i
        repeat
            local ts = streamReader.number()
            i = ts
            if i == nil then
                break
            end

            local num_action_id = streamReader.number()
            local num_action_state = streamReader.number()

            playerCommands.commands:add({
                ts = ts,
                num_action_id = num_action_id,
                num_action_state = num_action_state
            })
        until i ~= nil
    end
}

return M
