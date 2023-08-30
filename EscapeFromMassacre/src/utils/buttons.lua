local M = {}

local nBtnPressed = {}

function M.action(action, nodeId, btnTextureId, btnTextureIdPressed, onClick)
	local nBtn = gui.get_node(nodeId)
	local enabled = gui.is_enabled(nBtn)
	
	if not enabled then
		return
	end

	local actionInBtn = gui.pick_node(nBtn, action.x, action.y)

	if enabled and actionInBtn and action.pressed then 
		-- print("pressed: " .. nodeId .. " " .. btnTextureId .. " " .. btnTextureIdPressed)
		nBtnPressed[nodeId] = {nBtn, btnTextureId}

		-- if nBtnPressed[nodeId][1] ~= nil then
		-- 	gui.set_texture(nBtnPressed[nodeId][1], "main")
		-- 	gui.play_flipbook(nBtnPressed[nodeId][1], btnTextureIdPressed)
		-- end
	elseif action.released and nBtnPressed[nodeId] ~= nil then
		-- print("released: " .. nodeId .. " " .. btnTextureId .. " " .. btnTextureIdPressed)
		-- if nBtnPressed[nodeId][1] ~= nil then
		-- 	gui.set_texture(nBtnPressed[nodeId][1], "main")
		-- 	gui.play_flipbook(nBtnPressed[nodeId][1], nBtnPressed[nodeId][2])
		-- end
		
		nBtnPressed[nodeId] = nil

		if enabled and actionInBtn and onClick ~= nil then
			onClick()
		end
	end
end

return M