local Collections = require "src.utils.collections"
local player_commands = require "client.player_commands"
local debugUtils = require "src.utils.debug-utils"
local MainState = require "src.main_state"
local log = debugUtils.createLog("[MULTIPLAYER_INPUT]").log

local ACT_CODE = {
    JOIN = 1,
    USE = 2,
    LEFT = 3,
    RIGHT = 4,
    UP = 5,
    DOWN = 6,
    TOUCH = 7,
    TOUCH_X = 8,
    TOUCH_Y = 9,
    TRIGGER = 10
}
local M = {
    playerCommands = Collections.createMap(),
    last_touch_x = 0,
    last_touch_y = 0,
    last_command = function (self, uid)
        local playerCommands = self.playerCommands:get(uid)
        return playerCommands and playerCommands.commands and playerCommands.commands:getLast()
    end,
    touched = function (self, uid)
        local last_command = self:last_command(uid)

        if last_command == nil then
            return nil
        end

        local x = last_command[ACT_CODE.TOUCH_X]
        local y = last_command[ACT_CODE.TOUCH_Y]

        if x == self.last_touch_x or y == self.last_touch_y then
            return nil
        end

        self.last_touch_x = x
        self.last_touch_y = y

        log("touched", uid, x, y)

        local player = MainState.players:get(uid)
        if player ~= nil then
            player.last_processed_input_ts = last_command.ts
        end

        return {x = x, y = y}
    end,
    is_pressed = function (self, uid, action_id)
        log("is_pressed", uid, action_id)
        local last_command = self:last_command(uid)

        if last_command == nil then
            return false
        end

        local isPressed = last_command[player_commands.ActionIdToCode[action_id]] == 1
        log("is_pressed", action_id, isPressed)

        local player = MainState.players:get(uid)
        if player ~= nil then
            player.last_processed_input_ts = last_command.ts
        end

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
                [ACT_CODE.DOWN] = streamReader.number(),
                [ACT_CODE.TOUCH_X] = streamReader.double(),
                [ACT_CODE.TOUCH_Y] = streamReader.double(),
                [ACT_CODE.TRIGGER] = streamReader.number()
            }

            playerCommands.commands:add(command)

            --log("command", command.ts, command[ACT_CODE.JOIN], command[ACT_CODE.USE], command[ACT_CODE.LEFT], command[ACT_CODE.RIGHT], command[ACT_CODE.UP], command[ACT_CODE.DOWN])

            t = t - 1
        end

        log("consumeCommands", from_uid, playerCommands.commands.length)
    end
}

return M
