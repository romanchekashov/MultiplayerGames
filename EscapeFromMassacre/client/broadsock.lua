local stream = require "client.stream"
local multiplayer = require "server.multiplayer"
local debugUtils = require "src.utils.debug-utils"
local MainState = require "src.main_state"
local performance_utils = require "server.performance_utils"
local MSG = require "src.utils.messages"
local Collections = require "src.utils.collections"
local Utils = require "src.utils.utils"
local player_commands = require "client.player_commands"

local get_timestamp_in_ms = Utils.get_timestamp_in_ms
local log = debugUtils.createLog("[BROADSOCK CLIENT]").log
local rateLimiter = performance_utils.createRateLimiter(performance_utils.TIMES._100_MILISECONDS)

local M = {}
local MSG_IDS = multiplayer.MSG_IDS
local FACTORY_TYPE_PLAYER = MainState.FACTORY_TYPES.player

--- Create a broadsock instance
-- @param server_ip
-- @param server_port
-- @param on_custom_message
-- @param on_connected
-- @param on_disconnect
-- @return instance Instance or nil if something went wrong
-- @return error_message
function M.create(server_ip, server_port, on_custom_message, on_connected, on_disconnect,
	sendToReliableConnection, sendToUnreliableAndFastConnection)

	assert(server_ip, "You must provide a server IP")
	assert(server_port, "You must provide a server port")
	assert(on_custom_message, "You must provide an on_custom_message callback")
	assert(on_connected, "You must provide an on_connected callback")
	assert(on_disconnect, "You must provide an on_disconnect callback")
	local instance = {}

	local clients = {}
	local client_count = 0

	local go_id_set = Collections.createSet()
	local remote_gameobjects = Collections.createMap()

	local go_uid_sequence = 0

	local uid = nil

	local connection = {}

	local function add_client(uid_to_add)
		log("add_client", uid_to_add)

		clients[uid_to_add] = { uid = uid_to_add }
		client_count = client_count + 1
	end

	local function remove_client(uid_to_remove)
		log("remove_client", uid_to_remove, "client_count = ", client_count)

		clients[uid_to_remove] = nil
		client_count = client_count - 1
	end

	local function add_game_object(uid_to_add, type, go_id)
		log("add_game_object", uid_to_add, type, go_id)

		remote_gameobjects:put(uid_to_add, { id = go_id, type = type })
		go_id_set:add(go_id)
	end

	local function remove_game_object(uid_to_remove)
		log("remove_game_object", uid_to_remove, "remote_gameobjects.length:", remote_gameobjects.length)

		if remote_gameobjects:has(uid_to_remove) then
			local v = remote_gameobjects:remove(uid_to_remove)
			if v ~= nil and v.id ~= nil then
				go.delete(v.id)
				go_id_set:remove(v.id)
			end
		end
	end

	local function clear_remote_gameobjects()
		log("clear_remote_gameobjects: remote_gameobjects.length = ", remote_gameobjects.length)

		local deleting_uid_list = Collections.createList()
		remote_gameobjects:for_each(function (uid, v)
			deleting_uid_list:add(uid)
		end)
		deleting_uid_list:for_each(function (uid)
			local v = remote_gameobjects:remove(uid)
			if v ~= nil and v.id ~= nil then
				go.delete(v.id)
				go_id_set:remove(v.id)
			end
		end)
	end

	--- Get the number of clients (including self)
	-- @return Client count
	function instance.client_count()
		return client_count
	end

	--- Register a game object with the instance
	-- The game object transform will from this point on be sent to the server
	-- and broadcast to any other client
	-- @param id Id of the game object
	-- @param type Type of game object. Must match a known factory type
	function instance.register_gameobject(id, type)
		assert(id, "You must provide a game object id")
		assert(type and MainState.factories[type], "You must provide a known game object type")
		go_uid_sequence = go_uid_sequence + 1
		local gouid = tostring(uid) .. "_" .. go_uid_sequence
		MainState.gameobjects[gouid] = { id = id, type = type, gouid = gouid }
		MainState.gameobject_count = MainState.gameobject_count + 1
		go_id_set:add(id)
		log("register_gameobject", id, type, "go_id_set.length = ", go_id_set.length)
	end

	--- Unregister a game object
	-- The game object will no longer send its transform
	-- This will result in a message to the server to notify connected clients
	-- that the game object has been removed
	-- @param id Id of the game object
	function instance.unregister_gameobject(message)
		local id = message.id
		--local killer_uid = message.killer_uid
		for gouid,gameobject in pairs(MainState.gameobjects) do
			if gameobject.id == id then
				MainState.gameobjects[gouid] = nil
				MainState.gameobject_count = MainState.gameobject_count - 1
				go_id_set:remove(id)
				log("unregister_gameobject", id, gameobject.type, "go_id_set.length = ", go_id_set.length)
				return
			end
		end
		error("Unable to find game object")
	end

	--- Get the number of registered game objects
	-- @return count Game object count
	function instance.gameobject_count()
		return MainState.gameobject_count
	end


	--- Register a factory and associate it with a game object type
	-- The factory will be used to create game objects that have been spawned
	-- by a remote client
	-- @param url URL of the factory
	-- @param type Game object type
	function instance.register_factory(url, type)
		assert(url, "You must provide a factory URL")
		assert(type, "You must provide a game object type")
		log("register_factory", url, type)
		MainState.factories[type] = url
	end

	--- Check if a specific factory type is registered or not
	-- @param type
	-- @return True if registered, otherwise false
	function instance.has_factory(type)
		assert(type, "You must provide a game object type")
		return MainState.factories[type] ~= nil
	end


	--- Get the url of the factory associated with a specific type
	-- @param type
	-- @return Factory url or nil if it's not registered
	function instance.get_factory_url(type)
		assert(type, "You must provide a game object type")
		return MainState.factories[type]
	end

	--- Send data to the broadsock server
	-- Note: The data will actually not be sent until update() is called
	-- @param data
	function instance.send(data)
		if connection.connected then
			--log("send", #data, "data:", data)
			sendToReliableConnection(data)
			--sendToUnreliableAndFastConnection(data)
			-- server_nakama.send_player_move(stream.number_to_int32(#data) .. data)
		end
	end
	local count = 0
	function instance.on_data(data, data_length)
		count = count + 1
		-- log("on_data: data:", data_length, data)
		local sr = stream.reader(data, data_length)
		local from_uid = sr.number()
		local msg_id = sr.string()
		--log("on_data: from:", from_uid, "msg_id:", msg_id, "data:", data)

		if msg_id == "GAME_STATE" then
			MainState.server_update_rate = sr.number()
			MainState.currentGameState = sr.number()

			if MainState.gameInitialized and MainState.currentGameState == MainState.GAME_STATES.RUNNING then
				local newTime = sr.number()
				if MainState.gameTime ~= newTime then
					MainState.gameTime = newTime
					log("SERVER: GAME_STATE: MainState.gameTime = " .. tostring(newTime))
					msg.post("/gui#menu", "update_timer", {time = newTime})
				end
				sr.string() -- GATE
				local gateState = sr.number()
				MainState.isGateOpen = gateState == 1

				-- game objects
				local go_length = sr.number()

				local existing_go_uid_set = Collections.createSet()

				while go_length > 0 do
					go_length = go_length - 1

					local enable = true
					local name = sr.string() -- GO
					local object_type = sr.string()
					local uid = sr.number()
					local remote = MainState.player.uid ~= uid

					existing_go_uid_set:add(uid)

					local pos = sr.vector3()
					local rot = sr.quat()
					local scale = sr.vector3()

					local player_type
					local last_processed_input_ts

					local fuze_box_color
					local fuze_box_state = 0

					local fuze_color
					local fuze_map_level = 0
					local player_uid_with_fuze = 0

					local bullet_belongs_to_player_uid = 0
					local bullet_map_level = 0

					local zombie_map_level = 0
					local zombie_speed = 0

					local main_player = MainState.players:get(MainState.player.uid)

					if MainState.FACTORY_TYPES.player == object_type then
						player_type = sr.number()
						local player_map_level = sr.number()
						local player_health = sr.number()
						local player_score = sr.number()
						local last_processed_input_ts = sr.number()
						player_commands:server_reconciliation(last_processed_input_ts)

						local player = MainState.players:get(uid)
						if player ~= nil then
							player.map_level = player_map_level
							player.score = player_score
							player.last_processed_input_ts = last_processed_input_ts

							if player.health ~= player_health then
								player.health = player_health
								if player.health > 1 then
									msg.post(player.go_id, "update_health", {uid = player.uid, health = player_health})
								end
							end

							if player.score ~= player_score then
								player.score = player_score
								msg.post(player.go_id, "update_score", {uid = player.uid, score = player_score})
							end
						end

						enable = main_player ~= nil and player_map_level == main_player.map_level

					elseif MainState.FACTORY_TYPES.fuze_box == object_type then
						fuze_box_color = sr.number()
						fuze_box_state = sr.number()
						if fuze_box_color > 0 then
							if MainState.fuzeBoxColorToState[fuze_box_color] ~= fuze_box_state then
								MainState.fuzeBoxColorToState[fuze_box_color] = fuze_box_state
							end

							enable = main_player ~= nil and MainState.fuzeBoxColorToMapLevel[fuze_box_color] == main_player.map_level
						end
					elseif MainState.FACTORY_TYPES.fuze == object_type then
						fuze_color = sr.number()
						fuze_map_level = sr.number()
						player_uid_with_fuze = sr.number()

						if fuze_color > 0 and fuze_map_level > 0 then
							if player_uid_with_fuze > 0 then
								MainState.fuzeColorToPlayerUid:put(fuze_color, player_uid_with_fuze)
							else
								MainState.fuzeColorToPlayerUid:remove(fuze_color)
							end

							MainState.fuzeColorToMapLevel[fuze_color] = fuze_map_level

							enable = main_player ~= nil and fuze_map_level == main_player.map_level and player_uid_with_fuze == 0 and MainState.fuzeBoxColorToState[fuze_color] == 0
							--log("fuze enable", tostring(enable), fuze_color, fuze_map_level, MainState.playerOnMapLevel, "player_uid_with_fuze", player_uid_with_fuze, tostring(count))
						end
					elseif MainState.FACTORY_TYPES.bullet == object_type then
						bullet_belongs_to_player_uid = sr.number()
						bullet_map_level = sr.number()
						MainState.bulletUidBelongToPlayerUid:put(uid, bullet_belongs_to_player_uid)

						enable = main_player ~= nil and bullet_map_level == main_player.map_level
					elseif MainState.FACTORY_TYPES.zombie == object_type then
						zombie_map_level = sr.number()
						zombie_speed = sr.number()

						enable = main_player ~= nil and zombie_map_level == main_player.map_level
					end

					local game_object = remote_gameobjects:get(uid)

					if game_object == nil then
						local factory_url = MainState.factories[object_type]
						if factory_url then
							local factory_data = {remote = remote, uid = uid}
							log("create obj", uid, MainState.player.uid, tostring(object_type), factory_url, "remote:", factory_data.remote)

							if object_type == FACTORY_TYPE_PLAYER then
								factory_data.player_type = player_type
								factory_data.map_level = MainState.MAP_LEVELS.HOUSE
								factory_data.health = 100
								factory_data.score = 0
							elseif object_type == MainState.FACTORY_TYPES.fuze_box then
								if fuze_box_color > 0 then
									factory_data.color = fuze_box_color
								else
									factory_data = nil
								end
							elseif object_type == MainState.FACTORY_TYPES.fuze then
								if fuze_color > 0 and fuze_map_level > 0 then
									factory_data.color = fuze_color
									factory_data.map_level = fuze_map_level
								else
									factory_data = nil
								end
							elseif object_type == MainState.FACTORY_TYPES.bullet then
								factory_data.player_uid = bullet_belongs_to_player_uid
								factory_data.map_level = bullet_map_level
							elseif object_type == MainState.FACTORY_TYPES.zombie then
								factory_data.map_level = zombie_map_level
								factory_data.speed = zombie_speed
							end

							if factory_data ~= nil then
								local id = factory.create(factory_url, pos, rot, factory_data, scale)
								assert(id, factory_url .. " should return non nil id")
								log("obj created", uid, tostring(object_type), id)

								add_game_object(uid, object_type, id)
								game_object = remote_gameobjects:get(uid)

								if enable then
									msg.post(id, "enable")
								else
									msg.post(id, "disable")
								end
							end
						end
					else
						local update_pos = true

						if MainState.FACTORY_TYPES.player == object_type then
							local server_state_buffer = MainState.server_state_buffer:get(uid)
							if server_state_buffer == nil then
								server_state_buffer = Collections.createList()
								MainState.server_state_buffer:put(uid, server_state_buffer)
							end
							server_state_buffer:add({ts = get_timestamp_in_ms(), pos = pos, rot = rot, scale = scale})
							if server_state_buffer.length > 1 then
								update_pos = false
							end
							--if remote then
							--else
							--	--update_pos = false
							--	--update_pos = player_commands.commands.length == 0
							--end
						end

						if update_pos then
							local id = game_object.id
							if enable then
								msg.post(id, "enable")
								local ok, err = pcall(function()
									go.set_position(pos, id)
									go.set_rotation(rot, id)
									go.set_scale(scale, id)
								end)
							else
								-- log("disable", id, uid, object_type)
								msg.post(id, "disable")
							end
						end

					end
				end

				-- remove game objects that are not in the message
				local deleting_uid_list = Collections.createList()
				remote_gameobjects:for_each(function (uid, v)
					if not existing_go_uid_set:has(uid) then
						deleting_uid_list:add(uid)
					end
				end)
				deleting_uid_list:for_each(function (uid)
					local v = remote_gameobjects:remove(uid)
					if v ~= nil and v.id ~= nil then
						if go.exists(v.id) then
							go.delete(v.id)
						end
						go_id_set:remove(v.id)
					end
				end)
			end
		elseif msg_id == MSG_IDS.CONNECT_OTHER then
			log("CONNECT_OTHER")
			add_client(from_uid)
		elseif msg_id == MSG_IDS.CONNECT_SELF then
			log("CONNECT_SELF")
			add_client(from_uid)
			uid = from_uid
			on_connected()
			MainState.player.uid = uid
			msg.post("/gui#rooms", "set_username", {username = sr.string()})
			print("show connected user in lobby")
		elseif msg_id == MSG_IDS.DISCONNECT then
			log("DISCONNECT")
			remove_client(from_uid)
		elseif msg_id == MSG_IDS.GAME_OVER then
			log("SERVER: TIMER GAME_OVER", "go_id_set.length:", go_id_set.length)
			local won_player_type = sr.number()

			MainState.players:for_each(function (uid, v)
				MainState.game_over_players:put(uid, v)
			end)

			clear_remote_gameobjects()
			go_id_set:for_each(function (go_id)
				go.delete(go_id)
			end)

			while sr.string() == "player" do
				local uid = sr.number()
				local player = MainState.game_over_players:get(uid)
				player.type = sr.number()
				player.map_level = sr.number()
				player.health = sr.number()
				player.score = sr.number()
			end

			remove_client(uid)

			msg.post("/gui#menu", "game_over", {won_player_type = won_player_type})
			msg.post("/spawner-player#script", "remove_player", {uid = uid})
		elseif msg_id == MSG_IDS.PLAYER_LEAVE_ROOM then
			log("SERVER: PLAYER_LEAVE_ROOM", from_uid)
			local remote = MainState.player.uid ~= from_uid
			if not remote then
				msg.post("/screens#main", "load_screen", {map_level = MainState.GAME_SCREENS.LOBBY})
			end
		elseif msg_id == MSG_IDS.GAME_PRE_START then
			log("SERVER: GAME_PRE_START")
			msg.post("/gui#rooms", "game_pre_start")
		elseif msg_id == MSG_IDS.GAME_START then
			log("SERVER: TIMER GAME_START")
			msg.post("/gui#rooms", "game_start")
		elseif msg_id == MSG_IDS.ONLINE then
			MainState.online = sr.number()
		elseif msg_id == MSG_IDS.LATENCY then
			local t = sr.number()
			while t > 0 do
				t = t - 1
				local player = MainState.players:get(sr.number())
				if player ~= nil then
					player.ws_latency = sr.number()
					player.wt_latency = sr.number()
				end
			end
		else
			log("CUSTOM MESSAGE", msg_id)
			local message_data, message_length = sr.rest()
			on_custom_message(msg_id, from_uid, stream.reader(message_data, message_length))
		end
	end

	--- Destroy this broadsock instance
	-- Nothing can be done with the instance after this call
	function instance.destroy()
		if connection.connected then
			log("destroy")
			-- connection.socket:close()
			-- connection.socket = nil
			-- connection.writer = nil
			-- connection.reader = nil
			-- connection.socket_table = nil
			connection.connected = false
			client_count = 0
		end
	end

	connection.connected = true
	log("created client", connection.connected)
	return instance
end


return M
