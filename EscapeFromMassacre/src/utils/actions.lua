---
--- Generated by Luanalysis
--- Created by romanchekashov.
--- DateTime: 9/18/23 6:59 PM
---
local ACTION_IDS = {
    JOIN = hash("join"),
    USE = hash("use"),
    LEFT = hash("left"),
    RIGHT = hash("right"),
    UP = hash("up"),
    DOWN = hash("down"),
    TOUCH = hash("touch"),
    TOUCH_X = hash("touch_x"),
    TOUCH_Y = hash("touch_y"),
    TRIGGER = hash("trigger"),

    GAMEPAD = {
        CONNECTED = hash("gamepad_connected"),
        DISCONNECTED = hash("gamepad_dicconnected"),
        START = hash("gamepad_start"),
        RIGHT_STICK = {
            RIGHT = hash("rs_right"),
            LEFT = hash("rs_left"),
            UP = hash("rs_up"),
            DOWN = hash("rs_down")
        },
        LEFT_STICK = {
            RIGHT = hash("ls_right"),
            LEFT = hash("ls_left"),
            UP = hash("ls_up"),
            DOWN = hash("ls_down")
        }
    },

    VIRTUAL_GAMEPAD = {
        ANALOG = hash("analog"),
        ANALOG_X = hash("analog_x"),
        ANALOG_Y = hash("analog_y"),
        BUTTON_A = hash("button_a"),
        BUTTON_B = hash("button_b"),
    }
}

ACTION_IDS.isGamepadActionId = {
    [ACTION_IDS.GAMEPAD.CONNECTED] = true,
    [ACTION_IDS.GAMEPAD.START] = true,

    [ACTION_IDS.GAMEPAD.LEFT_STICK.DOWN] = true,
    [ACTION_IDS.GAMEPAD.LEFT_STICK.UP] = true,
    [ACTION_IDS.GAMEPAD.LEFT_STICK.RIGHT] = true,
    [ACTION_IDS.GAMEPAD.LEFT_STICK.LEFT] = true,

    [ACTION_IDS.GAMEPAD.RIGHT_STICK.DOWN] = true,
    [ACTION_IDS.GAMEPAD.RIGHT_STICK.UP] = true,
    [ACTION_IDS.GAMEPAD.RIGHT_STICK.RIGHT] = true,
    [ACTION_IDS.GAMEPAD.RIGHT_STICK.LEFT] = true,
}
ACTION_IDS.isGamepadLeftStickActionId = {
    [ACTION_IDS.GAMEPAD.LEFT_STICK.DOWN] = true,
    [ACTION_IDS.GAMEPAD.LEFT_STICK.UP] = true,
    [ACTION_IDS.GAMEPAD.LEFT_STICK.RIGHT] = true,
    [ACTION_IDS.GAMEPAD.LEFT_STICK.LEFT] = true,
}
ACTION_IDS.isGamepadRightStickActionId = {
    [ACTION_IDS.GAMEPAD.RIGHT_STICK.DOWN] = true,
    [ACTION_IDS.GAMEPAD.RIGHT_STICK.UP] = true,
    [ACTION_IDS.GAMEPAD.RIGHT_STICK.RIGHT] = true,
    [ACTION_IDS.GAMEPAD.RIGHT_STICK.LEFT] = true,
}

return ACTION_IDS
