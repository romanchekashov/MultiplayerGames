local Collections = require "src.utils.collections"
local ACTION_IDS = require "src.utils.actions"
local stream = require "client.stream"
local debugUtils = require "src.utils.debug-utils"
local Utils = require "src.utils.utils"

local log = debugUtils.createLog("[PLAYER_COMMAND]").log
local compareTables = debugUtils.compareTables
local get_timestamp_in_ms = Utils.get_timestamp_in_ms

local M = {
    ActionIdToCode = {
        [ACTION_IDS.JOIN] = 1,
        [ACTION_IDS.USE] = 2,
        [ACTION_IDS.LEFT] = 3,
        [ACTION_IDS.RIGHT] = 4,
        [ACTION_IDS.UP] = 5,
        [ACTION_IDS.DOWN] = 6,
        [ACTION_IDS.TOUCH] = 7,
        [ACTION_IDS.TOUCH_X] = 8,
        [ACTION_IDS.TOUCH_Y] = 9,
        [ACTION_IDS.TRIGGER] = 10
    },
    CodeToActionId = {
        [1] = ACTION_IDS.JOIN,
        [2] = ACTION_IDS.USE,
        [3] = ACTION_IDS.LEFT,
        [4] = ACTION_IDS.RIGHT,
        [5] = ACTION_IDS.UP,
        [6] = ACTION_IDS.DOWN,
        [7] = ACTION_IDS.TOUCH,
        [8] = ACTION_IDS.TOUCH_X,
        [9] = ACTION_IDS.TOUCH_Y,
        [10] = ACTION_IDS.TRIGGER
    },
    ActionState = {
        released = 0,
        pressed = 1
    }
};

function M.create()
    return {
        commands = Collections.createList(),
        MAX_COMMANDS_BUFFER_SIZE = 2,
        build = function (self, player_uid, data)
            --log("build", data.action_id, data.action.pressed, data.action.released, data.action.x, data.action.y)
            --log("commands.length", tostring(self.commands.length))
            local last_command = self.commands:getLast()
            if last_command == nil then
                last_command = {
                    ts = get_timestamp_in_ms(),
                    [M.ActionIdToCode[ACTION_IDS.JOIN]] = M.ActionState.released,
                    [M.ActionIdToCode[ACTION_IDS.USE]] = M.ActionState.released,
                    [M.ActionIdToCode[ACTION_IDS.LEFT]] = M.ActionState.released,
                    [M.ActionIdToCode[ACTION_IDS.RIGHT]] = M.ActionState.released,
                    [M.ActionIdToCode[ACTION_IDS.UP]] = M.ActionState.released,
                    [M.ActionIdToCode[ACTION_IDS.DOWN]] = M.ActionState.released,
                    [M.ActionIdToCode[ACTION_IDS.TOUCH_X]] = 0,
                    [M.ActionIdToCode[ACTION_IDS.TOUCH_Y]] = 0,
                    [M.ActionIdToCode[ACTION_IDS.TRIGGER]] = M.ActionState.released
                }
            end

            local num_action_id = M.ActionIdToCode[data.action_id]
            local num_action_state = last_command[num_action_id]
            if data.action.pressed then
                num_action_state = 1
            end
            if data.action.released then
                num_action_state = 0
            end

            local copy = table.shallow_copy(last_command)
            copy.ts = get_timestamp_in_ms()
            copy[num_action_id] = num_action_state
            copy[M.ActionIdToCode[ACTION_IDS.TOUCH_X]] = math.floor(data.action.x * 1000)
            copy[M.ActionIdToCode[ACTION_IDS.TOUCH_Y]] = math.floor(data.action.y * 1000)

            if not compareTables(last_command, copy) then
                self.commands:add(copy)
            end

            if self.commands.length > self.MAX_COMMANDS_BUFFER_SIZE then
                self.commands:removeFirst()
            end

            local sendData = stream.writer()
                                   --.number(player_uid)
                                   .string("NOT_GS_PLAYER_COMMANDS").number(self.commands.length)

            self.commands:for_each(function (command)
                sendData = sendData
                        .number(command.ts)
                        .number(command[M.ActionIdToCode[ACTION_IDS.JOIN]])
                        .number(command[M.ActionIdToCode[ACTION_IDS.USE]])
                        .number(command[M.ActionIdToCode[ACTION_IDS.LEFT]])
                        .number(command[M.ActionIdToCode[ACTION_IDS.RIGHT]])
                        .number(command[M.ActionIdToCode[ACTION_IDS.UP]])
                        .number(command[M.ActionIdToCode[ACTION_IDS.DOWN]])
                        .number(command[M.ActionIdToCode[ACTION_IDS.TOUCH_X]])
                        .number(command[M.ActionIdToCode[ACTION_IDS.TOUCH_Y]])
                        .number(command[M.ActionIdToCode[ACTION_IDS.TRIGGER]])
            end)

            return sendData.tostring()
        end
    }
end

return M
