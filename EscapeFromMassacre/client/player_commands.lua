local Collections = require "src.utils.collections"
local ACTION_IDS = require "src.utils.actions"
local stream = require "client.stream"
local debugUtils = require "src.utils.debug-utils"

local log = debugUtils.createLog("[PLAYER_COMMAND]").log

local function get_timestamp_in_ms()
    return socket.gettime() * 1000
end

local M = {
    ActionIdToCode = {
        [ACTION_IDS.JOIN] = 1,
        [ACTION_IDS.USE] = 2,
        [ACTION_IDS.LEFT] = 3,
        [ACTION_IDS.RIGHT] = 4,
        [ACTION_IDS.UP] = 5,
        [ACTION_IDS.DOWN] = 6
    },
    CodeToActionId = {
        [1] = ACTION_IDS.JOIN,
        [2] = ACTION_IDS.USE,
        [3] = ACTION_IDS.LEFT,
        [4] = ACTION_IDS.RIGHT,
        [5] = ACTION_IDS.UP,
        [6] = ACTION_IDS.DOWN
    }
};

function M.create()
    return {
        commands = Collections.createList(),
        MAX_COMMANDS_BUFFER_SIZE = 100,
        last_num_action_id = -1,
        last_num_action_state = -1,
        build = function (self, player_uid, data)
            --log("build", data)
            log("commands.length", tostring(self.commands.length))

            local num_action_id = M.ActionIdToCode[data.action_id]
            local num_action_state = 0
            if data.action.released then
                num_action_state = 0
            end
            if data.action.pressed then
                num_action_state = 1
            end

            if self.last_num_action_id ~= num_action_id or self.last_num_action_state ~= num_action_state then
                self.commands:add({
                    ts = get_timestamp_in_ms(),
                    num_action_id = num_action_id,
                    num_action_state = num_action_state
                })
                self.last_num_action_id = num_action_id
                self.last_num_action_state = num_action_state
            end

            if self.commands.length > self.MAX_COMMANDS_BUFFER_SIZE then
                self.commands:removeFirst()
            end

            local sendData = stream.writer()
                                   --.number(player_uid)
                                   .string("NOT_GS_PLAYER_COMMANDS")

            self.commands:for_each(function (command)
                sendData = sendData
                        .number(command.ts)
                        .number(command.num_action_id)
                        .number(command.num_action_state)
            end)

            return sendData.tostring()
        end
    }
end

return M
