local Collections = require "src.utils.collections"
local ACTION_IDS = require "src.utils.actions"
local stream = require "client.stream"
local debugUtils = require "src.utils.debug-utils"
local Utils = require "src.utils.utils"

local log = debugUtils.createLog("[PLAYER_COMMAND]").log
local compareTables = debugUtils.compareTables
local get_timestamp_in_ms = Utils.get_timestamp_in_ms

local ActionIdToCode = {
    [ACTION_IDS.JOIN] = 1,
    [ACTION_IDS.USE] = 2,
    [ACTION_IDS.LEFT] = 3,
    [ACTION_IDS.RIGHT] = 4,
    [ACTION_IDS.UP] = 5,
    [ACTION_IDS.DOWN] = 6,
    [ACTION_IDS.TOUCH] = 7,
    [ACTION_IDS.TOUCH_X] = 8,
    [ACTION_IDS.TOUCH_Y] = 9,
    [ACTION_IDS.TRIGGER] = 10,
    [ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG] = 11,
    [ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_X] = 12,
    [ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_Y] = 13
}

local CodeToActionId = {
    [1] = ACTION_IDS.JOIN,
    [2] = ACTION_IDS.USE,
    [3] = ACTION_IDS.LEFT,
    [4] = ACTION_IDS.RIGHT,
    [5] = ACTION_IDS.UP,
    [6] = ACTION_IDS.DOWN,
    [7] = ACTION_IDS.TOUCH,
    [8] = ACTION_IDS.TOUCH_X,
    [9] = ACTION_IDS.TOUCH_Y,
    [10] = ACTION_IDS.TRIGGER,
    [11] = ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG,
    [12] = ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_X,
    [13] = ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_Y
}

local ActionState = {
    released = 0,
    pressed = 1
}

local M = {
    ActionIdToCode = ActionIdToCode,
    CodeToActionId = CodeToActionId,
    ActionState = ActionState,
    commands = Collections.createList(),
    --MAX_COMMANDS_BUFFER_SIZE = 100,
    build = function (self, player_uid, data)
        local action_id, action = data.action_id, data.action
        print("PLAYER_COMMAND:", action_id, " x = ", action.x, " y = ", action.y, " pressed = ", action.pressed, " released = ", action.released)
        --log("build", data.action_id, data.action.pressed, data.action.released, data.action.x, data.action.y)
        --log("commands.length", tostring(self.commands.length))
        local last_command = self.commands:getLast()
        if last_command == nil then
            last_command = {
                ts = get_timestamp_in_ms(),
                [ActionIdToCode[ACTION_IDS.JOIN]] = ActionState.released,
                [ActionIdToCode[ACTION_IDS.USE]] = ActionState.released,
                [ActionIdToCode[ACTION_IDS.LEFT]] = ActionState.released,
                [ActionIdToCode[ACTION_IDS.RIGHT]] = ActionState.released,
                [ActionIdToCode[ACTION_IDS.UP]] = ActionState.released,
                [ActionIdToCode[ACTION_IDS.DOWN]] = ActionState.released,
                [ActionIdToCode[ACTION_IDS.TOUCH_X]] = 0,
                [ActionIdToCode[ACTION_IDS.TOUCH_Y]] = 0,
                [ActionIdToCode[ACTION_IDS.TRIGGER]] = ActionState.released,
                [ActionIdToCode[ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_X]] = 0,
                [ActionIdToCode[ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_Y]] = 0
            }
        end

        local copy = table.shallow_copy(last_command)
        copy.ts = get_timestamp_in_ms()

        if action.pressed ~= nil and action.released ~= nil then
            local num_action_id = ActionIdToCode[action_id]
            local num_action_state = last_command[num_action_id]
            
            if action.pressed then
                num_action_state = 1
            elseif action.released then
                num_action_state = 0
            end

            copy[num_action_id] = num_action_state
        end

        local is_touch = action_id == ACTION_IDS.TOUCH
        local is_analog = action_id == ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG

        if is_touch or is_analog then
            local x = math.floor(action.x * 1000)
            local y = math.floor(action.y * 1000)
    
            if is_touch then
                copy[ActionIdToCode[ACTION_IDS.TOUCH_X]] = x
                copy[ActionIdToCode[ACTION_IDS.TOUCH_Y]] = y
            end
            
            if is_analog then
                copy[ActionIdToCode[ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_X]] = x
                copy[ActionIdToCode[ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_Y]] = y
            end
        end

        if not compareTables(last_command, copy) then
            self.commands:add(copy)
        end

        --if self.commands.length > self.MAX_COMMANDS_BUFFER_SIZE then
        --    self.commands:removeFirst()
        --end

        local sendData = stream.writer()
        --.number(player_uid)
                               .string("NOT_GS_PLAYER_COMMANDS").number(self.commands.length)

        self.commands:for_each(function (command)
            sendData = sendData
                    .number(command.ts)
                    .number(command[ActionIdToCode[ACTION_IDS.JOIN]])
                    .number(command[ActionIdToCode[ACTION_IDS.USE]])
                    .number(command[ActionIdToCode[ACTION_IDS.LEFT]])
                    .number(command[ActionIdToCode[ACTION_IDS.RIGHT]])
                    .number(command[ActionIdToCode[ACTION_IDS.UP]])
                    .number(command[ActionIdToCode[ACTION_IDS.DOWN]])
                    .number(command[ActionIdToCode[ACTION_IDS.TOUCH_X]])
                    .number(command[ActionIdToCode[ACTION_IDS.TOUCH_Y]])
                    .number(command[ActionIdToCode[ACTION_IDS.TRIGGER]])
                    .number(command[ActionIdToCode[ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_X]])
                    .number(command[ActionIdToCode[ACTION_IDS.VIRTUAL_GAMEPAD.ANALOG_Y]])
        end)

        return sendData.tostring()
    end,
    server_reconciliation = function (self, last_processed_input_ts)
        self.commands:for_each(function (command)
            if command.ts <= last_processed_input_ts then
                self.commands:removeFirst()
            end
        end)
        log("server_reconciliation: unprocessed commands =", self.commands.length)
    end
};

return M
