local Collections = require "src.utils.collections"
local player_commands = require "client.player_commands"
local debugUtils = require "src.utils.debug-utils"
local log = debugUtils.createLog("[MULTIPLAYER_INPUT]").log

local ACT_CODE = {
    JOIN = 1,
    USE = 2,
    LEFT = 3,
    RIGHT = 4,
    UP = 5,
    DOWN = 6
}
local M = {
    playerCommands = Collections.createMap(),
    is_pressed = function (self, uid, action_id)
        log("is_pressed", uid, action_id)
        local playerCommands = self.playerCommands:get(uid)

        if playerCommands == nil then
            return false
        end

        local last_command = playerCommands.commands:getLast()

        if last_command == nil then
            return false
        end

        local isPressed = last_command[player_commands.ActionIdToCode[action_id]] == 1
        log("is_pressed", action_id, isPressed)

        return isPressed
    end,
    consumeCommands = function (self, from_uid, streamReader)
        local playerCommands = self.playerCommands:get(from_uid)
        self.playerCommands:put(from_uid, {commands = Collections.createList()})
        playerCommands = self.playerCommands:get(from_uid)
        --if playerCommands == nil then
        --end

        local t = streamReader.number()
        while t > 0 do
            local command = {
                ts = streamReader.number(),
                [ACT_CODE.JOIN] = streamReader.number(),
                [ACT_CODE.USE] = streamReader.number(),
                [ACT_CODE.LEFT] = streamReader.number(),
                [ACT_CODE.RIGHT] = streamReader.number(),
                [ACT_CODE.UP] = streamReader.number(),
                [ACT_CODE.DOWN] = streamReader.number()
            }

            playerCommands.commands:add(command)

            log("command", command.ts, command[ACT_CODE.JOIN], command[ACT_CODE.USE], command[ACT_CODE.LEFT], command[ACT_CODE.RIGHT], command[ACT_CODE.UP], command[ACT_CODE.DOWN])

            t = t - 1
        end

        log("consumeCommands", from_uid, playerCommands.commands.length)
    end
}

return M
