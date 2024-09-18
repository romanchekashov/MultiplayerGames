local stream = require "client.stream"
local multiplayer = require "server.multiplayer"
local debugUtils = require "src.utils.debug-utils"
local MainState = require "src.main_state"
local performance_utils = require "server.performance_utils"
local MSG = require "src.utils.messages"


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

	local remote_gameobjects = {}

	local go_uid_sequence = 0

	local uid = nil

	local connection = {}

	local function add_game_object(uid_to_add)
		log("add_game_object", uid_to_add)
		clients[uid_to_add] = { uid = uid_to_add }
		remote_gameobjects[uid_to_add] = {gouid = nil}
		client_count = client_count + 1
	end

	local function remove_client(uid_to_remove)
		log("remove_client", uid_to_remove, "remote_gameobjects.length:", #remote_gameobjects)
		clients[uid_to_remove] = nil
		for _,gameobject in pairs(remote_gameobjects[uid_to_remove]) do
			go.delete(gameobject.id)
		end
		remote_gameobjects[uid_to_remove] = nil
		client_count = client_count - 1
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
		log("register_gameobject", id, type)
		go_uid_sequence = go_uid_sequence + 1
		local gouid = tostring(uid) .. "_" .. go_uid_sequence
		MainState.gameobjects[gouid] = { id = id, type = type, gouid = gouid }
		MainState.gameobject_count = MainState.gameobject_count + 1
	end

	--- Unregister a game object
	-- The game object will no longer send its transform
	-- This will result in a message to the server to notify connected clients
	-- that the game object has been removed
	-- @param id Id of the game object
	function instance.unregister_gameobject(message)
		local id = message.id
		local killer_uid = message.killer_uid
		log("unregister_gameobject", id)
		for gouid,gameobject in pairs(gameobjects) do
			if gameobject.id == id then
				MainState.gameobjects[gouid] = nil
				MainState.gameobject_count = MainState.gameobject_count - 1

				local sw = stream.writer().string("GOD").string(gouid)
				if killer_uid ~= nil then
					sw.string(killer_uid)
				end
				instance.send(sw.tostring())
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
			sendToUnreliableAndFastConnection(data)
			-- server_nakama.send_player_move(stream.number_to_int32(#data) .. data)
		end
	end

	function instance.on_data(data, data_length)
		--log("on_data: data:", data_length, data)
		local sr = stream.reader(data, data_length)
		local from_uid = sr.number()
		local msg_id = sr.string()
		log("on_data: from:", from_uid, "msg_id:", msg_id, "data:", data)

		if msg_id == "GAME_STATE" then
			MainState.currentGameState = sr.number()

			if MainState.currentGameState == MainState.GAME_STATES.RUNNING then
				local newTime = sr.number()
				if MainState.gameTime ~= newTime then
					MainState.gameTime = newTime
					log("SERVER: GAME_STATE: MainState.gameTime = " .. tostring(newTime))
					msg.post("/gui#menu", "update_timer", {time = newTime})
				end
				sr.string() -- GATE
				local gateState = sr.number()
				MainState.isGateOpen = gateState == 1

				sr.string() -- FUZE_BOX_1
				MainState.fuzeBoxColorToState[sr.number()] = sr.number()
				sr.string() -- FUZE_BOX_2
				MainState.fuzeBoxColorToState[sr.number()] = sr.number()
				sr.string() -- FUZE_BOX_3
				MainState.fuzeBoxColorToState[sr.number()] = sr.number()
				sr.string() -- FUZE_BOX_4
				MainState.fuzeBoxColorToState[sr.number()] = sr.number()

				sr.string() -- FUZE_1
				local color = sr.number()
				MainState.fuzesColorToState[color] = sr.number()
				MainState.fuzeToPlayerUid[color] = sr.number()
				sr.string() -- FUZE_2
				color = sr.number()
				MainState.fuzesColorToState[color] = sr.number()
				MainState.fuzeToPlayerUid[color] = sr.number()
				sr.string() -- FUZE_3
				color = sr.number()
				MainState.fuzesColorToState[color] = sr.number()
				MainState.fuzeToPlayerUid[color] = sr.number()
				sr.string() -- FUZE_4
				color = sr.number()
				MainState.fuzesColorToState[color] = sr.number()
				MainState.fuzeToPlayerUid[color] = sr.number()

				local name = sr.string() -- GO
				local enable = true

				while name == "GO" do
					local object_type = sr.string()
					local uid = sr.number()

					local pos = sr.vector3()
					local rot = sr.quat()
					local scale = sr.vector3()
					local player_type

					if MainState.FACTORY_TYPES.player == object_type then
						player_type = sr.number()
						local player_map_level = sr.number()
						sr.number()
						sr.number()

						if MainState.player.uid == uid then
							MainState.playerOnMapLevel = player_map_level
						end
						--enable = player_map_level == MainState.playerOnMapLevel
					end

					if not clients[uid] then
						add_game_object(uid)
						log("remote GO add_game_object", uid)
					end

					local game_object = remote_gameobjects[uid]

					if game_object.gouid == nil then
						local factory_url = MainState.factories[object_type]
						if factory_url then
							local factory_data = {remote = MainState.player.uid ~= uid, uid = uid}
							log("GO create obj", uid, MainState.player.uid, tostring(object_type), factory_url, "remote:", factory_data.remote)

							if object_type == FACTORY_TYPE_PLAYER then
								factory_data.player_type = player_type
								factory_data.map_level = MainState.MAP_LEVELS.HOUSE
								factory_data.health = 100
								factory_data.score = 0
								factory_data.ws_latency = -1
							end

							local id = factory.create(factory_url, pos, rot, factory_data, scale)
							assert(id, factory_url .. " should return non nil id")
							log("GO obj created", uid, tostring(object_type), id)
							game_object.gouid = { id = id, type = object_type }

							if enable then
								msg.post(id, "enable")
							else
								msg.post(id, "disable")
							end
						end
					else
						local id = game_object.gouid.id
						if enable then
							msg.post(id, "enable")
							local ok, err = pcall(function()
								go.set_position(pos, id)
								go.set_rotation(rot, id)
								go.set_scale(scale, id)
							end)
						else
							msg.post(id, "disable")
						end
					end

					if MainState.FACTORY_TYPES.player == object_type then

						--local player_type = sr.number()
						--local player_map_level = sr.number()
						--local player = MainState.players:get(from_uid)
						--if player ~= nil then
						--	player.map_level = player_map_level
						--end
						--
						--local enable = player_map_level == MainState.playerOnMapLevel
						--
						--local remote_gameobjects_for_user = remote_gameobjects[from_uid]
						--local count = sr.number()
						--log("remote GO", tostring(count))
						--for _=1,count do
						--	local gouid = sr.string()
						--	local type = sr.string()
						--
						--	local pos = sr.vector3()
						--	local rot = sr.quat()
						--	local scale = sr.vector3()
						--
						--	if from_uid ~= uid then
						--		if not remote_gameobjects_for_user[gouid] then
						--			local factory_url = factories[type]
						--			if factory_url then
						--				log("GO create obj", from_uid, tostring(type))
						--				local factory_data = {remote = true, uid = from_uid}
						--				if type == FACTORY_TYPE_PLAYER then
						--					factory_data.player_type = player_type
						--				end
						--				local id = factory.create(factory_url, pos, rot, factory_data, scale)
						--				--assert(id, factory_url .. " should return non nil id")
						--				remote_gameobjects_for_user[gouid] = { id = id, type = type }
						--				if enable then
						--					msg.post(id, "enable")
						--				else
						--					msg.post(id, "disable")
						--				end
						--			end
						--		else
						--			local id = remote_gameobjects_for_user[gouid].id
						--			if enable then
						--				msg.post(id, "enable")
						--				local ok, err = pcall(function()
						--					go.set_position(pos, id)
						--					go.set_rotation(rot, id)
						--					go.set_scale(scale, id)
						--				end)
						--			else
						--				msg.post(id, "disable")
						--			end
						--		end
						--	end
						--end
						--
						--local new_health = sr.number()
						--local new_score = sr.number()
						--if from_uid ~= uid and player ~= nil then
						--	if player.health ~= new_health then
						--		msg.post(player.go_id, "update_health", {uid = player.uid, health = new_health})
						--		player.health = new_health
						--	end
						--	if player.score ~= new_score then
						--		msg.post(player.go_id, "update_score", {uid = player.uid, score = new_score})
						--		player.score = new_score
						--	end
						--end
						--MainState.playerUidToWsLatency[from_uid] = sr.number()
					end
					name = sr.string()
				end
			end
		elseif msg_id == MSG_IDS.GOD then
			log("GOD")
			if clients[from_uid] and from_uid ~= uid then
				local gouid = sr.string()
				local killer_uid = sr.number()
				MainState.increasePlayerScore(killer_uid)

				local remote_gameobjects_for_user = remote_gameobjects[from_uid]
				if remote_gameobjects_for_user[gouid] ~= nil then
					local id = remote_gameobjects_for_user[gouid].id
					local ok, err = pcall(function()
						go.delete(id)
					end)
					remote_gameobjects_for_user[gouid] = nil
				end
			end
		elseif msg_id == MSG_IDS.CREATE_FUZES then
			MainState.INITIAL_FUZES_CREATE = {}
			table.insert(MainState.INITIAL_FUZES_CREATE, {color = sr.number(), pos = sr.vector3()})
			table.insert(MainState.INITIAL_FUZES_CREATE, {color = sr.number(), pos = sr.vector3()})
			table.insert(MainState.INITIAL_FUZES_CREATE, {color = sr.number(), pos = sr.vector3()})
			table.insert(MainState.INITIAL_FUZES_CREATE, {color = sr.number(), pos = sr.vector3()})
			--msg.post("/factory#factory-fuze", MSG.FUZE_FACTORY.create_fuzes.name, {
			--	color_red = sr.number(), color_red_pos = sr.vector3(),
			--	color_green = sr.number(), color_green_pos = sr.vector3(),
			--	color_blue = sr.number(), color_blue_pos = sr.vector3(),
			--	color_yellow = sr.number(), color_yellow_pos = sr.vector3(),
			--})
		elseif msg_id == MSG.BASE_MSG_IDS.RELIABLE_GO then
			msg.post("/factory#fuze", MSG.FUZE_FACTORY.throw_fuze.name, {map_level = sr.number(), color = sr.number(), pos = sr.vector3()})
		elseif msg_id == MSG.BASE_MSG_IDS.RELIABLE_GOD then
			msg.post("/factory#fuze", MSG.FUZE_FACTORY.pick_fuze.name, {color = sr.number()})
		elseif msg_id == MSG_IDS.PLAYER_CREATE_POS then
			local remote = MainState.player.uid ~= from_uid
			log("PLAYER_CREATE_POS: remote = " .. tostring(remote))
			msg.post("/spawner-player#script", "add_player", {uid = MainState.player.uid, player_type = MainState.player.type, pos = sr.vector3(), remote = remote})
		elseif msg_id == MSG_IDS.CONNECT_OTHER then
			log("CONNECT_OTHER")
			add_game_object(from_uid)
		elseif msg_id == MSG_IDS.CONNECT_SELF then
			log("CONNECT_SELF")
			add_game_object(from_uid)
			uid = from_uid
			on_connected()
			MainState.player.uid = uid
			msg.post("/gui#rooms", "set_username", {username = sr.string()})
			print("show connected user in lobby")
		elseif msg_id == MSG_IDS.DISCONNECT then
			log("DISCONNECT")
			remove_client(from_uid)
		elseif msg_id == MSG_IDS.GAME_TIME then
			log("SERVER: TIMER GAME_TIME: " .. data)
			msg.post("/gui#menu", "update_timer", {time = sr.number()})
		elseif msg_id == MSG_IDS.GAME_OVER then
			log("SERVER: TIMER GAME_OVER")
			MainState.players:for_each(function (v)
				MainState.game_over_players:put(v.uid, v)
			end)

			while sr.string() == "player" do
				local uid = sr.number()
				local player = MainState.game_over_players:get(uid)
				player.type = sr.number()
				local map_level = sr.number()
				local health = sr.number()
				player.score = sr.number()
				local ws_latency = sr.number()
			end
			remove_client(uid)
			msg.post("/gui#menu", "game_over")
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
		else
			log("CUSTOM MESSAGE", msg_id)
			local message_data, message_length = sr.rest()
			on_custom_message(msg_id, from_uid, stream.reader(message_data, message_length))
		end
	end

	--- Update the broadsock client instance
	-- Any registered game objects will send their transforms
	-- This will also send any other queued data
	function instance.update(dt)
		if uid == nil or MainState.currentGameState ~= MainState.GAME_STATES.RUNNING then
			return
		end

		if connection.connected then
			if rateLimiter(dt) then
				return
			end
			log("update - sending game objects", instance.gameobject_count(), "gameobjects.length:", #gameobjects)
			local player = MainState.players:get(uid)
			local sw = stream.writer()
			sw.string("GO")
			sw.number(MainState.playerOnMapLevel)
			sw.number(MainState.player.type)
			sw.number(MainState.gameobject_count)
			for gouid,gameobject in pairs(MainState.gameobjects) do
				local pos = go.get_position(gameobject.id)
				local rot = go.get_rotation(gameobject.id)
				local scale = go.get_scale(gameobject.id)
				sw.string(gouid)
				sw.string(gameobject.type)
				sw.vector3(pos)
				sw.quat(rot)
				sw.vector3(scale)
				-- log(gameobject_count, gouid, tostring(gameobject.type), pos, rot, scale, tostring(sw.tostring()))
			end
			sw.number(player and player.health or 100)
			sw.number(player and player.score or 0)
			instance.send(sw.tostring())

			-- check if the socket is ready for reading and/or writing
			-- local receivet, sendt = socket.select(connection.socket_table, connection.socket_table, 0)

			-- if sendt[connection.socket] then
			-- 	log("ready to send")
			-- 	if not connection.writer.empty() then
			-- 		log("update - sending from writer")
			-- 	end
			-- 	local ok, err = connection.writer.send()
			-- 	if not ok and err == "closed" then
			-- 		instance.destroy()
			-- 		on_disconnect()
			-- 		return
			-- 	end
			-- end

			-- if receivet[connection.socket] then
			-- 	log("update - receiving from reader")
			-- 	local ok, err = connection.reader.receive()
			-- 	if not ok then
			-- 		instance.destroy()
			-- 		on_disconnect()
			-- 		return
			-- 	end
			-- end
		else
			log("not connected")
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
