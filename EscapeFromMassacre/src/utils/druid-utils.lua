---
--- Generated by Luanalysis
--- Created by romanchekashov.
--- DateTime: 9/16/23 4:20 PM
---
local N = {}

function N.player_show_results(self, prefix, player_create_function)
    local M = {player_create_function = player_create_function}

    M.prefab = gui.get_node(prefix .. "prefab")
    gui.set_enabled(M.prefab, false)

    M.scroll = self.druid:new_scroll(prefix .. "data_list_view", prefix .. "data_list_content")
    M.scroll:set_horizontal_scroll(false)
    M.grid = self.druid:new_static_grid(prefix .. "data_list_content", prefix .. "prefab", 1)

    -- Pass already created scroll and grid components to data_list:
    M.data_list = self.druid:new_data_list(M.scroll, M.grid, M.player_create_function)

    M.data_list:set_data({})
    return M
end

return N
