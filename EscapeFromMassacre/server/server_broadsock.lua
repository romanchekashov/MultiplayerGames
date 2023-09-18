local socket = require "builtins.scripts.socket"
local tcp_writer = require "server.tcp_writer"
local tcp_reader = require "server.tcp_reader"
local stream = require "client.stream"
local multiplayer = require "server.multiplayer"
local debugUtils = require "src.utils.debug-utils"
local performance_utils = require "server.performance_utils"
local MainState = require "src.main_state"
local Utils = require "src.utils.utils"

local log = debugUtils.createLog("[BROADSOCK SERVER]").log
local rateLimiter = performance_utils.createRateLimiter(performance_utils.TIMES._20_MILISECONDS)

local M = {}
local MSG_IDS = multiplayer.MSG_IDS
local CLIENT_MSG_IDS = multiplayer.CLIENT_MSG_IDS

M.TCP_SEND_CHUNK_SIZE = 255

local clients = {}
local clients_map = {}

local uid_sequence = 0

local connection = {}



--- Convert a Lua number to an int32 (4 bytes)
-- @param number The number to convert, only the integer part will be converted
-- @return String with 4 bytes representing the number
local function number_to_int32(number)
	local b1 = bit.rshift(bit.band(number, 0xFF000000), 24)
	local b2 = bit.rshift(bit.band(number, 0x00FF0000), 16)
	local b3 = bit.rshift(bit.band(number, 0x0000FF00), 8)
	local b4 = bit.band(number, 0x000000FF)
	return string.char(b1, b2, b3, b4)
end

local function tomessage(str)
	-- log("tomessage " .. str)
	return number_to_int32(#str) .. str
end

local function create_client(uid, player_type)
	assert(uid, "you must provide an uid")
	local client = {
		uid = uid,
		type = player_type,
		map_level = MainState.MAP_LEVELS.HOUSE,
		health = 100,
		score = 0,
		ws_latency = -1
	}
	return client
end

local function add_client(client)
	assert(client)
	table.insert(clients, client)
	clients_map[client.uid] = client
	log("add_client", client.uid, "clients.length = ", #clients)
end

local function remove_client(uid_to_remove)
	assert(uid_to_remove, "You must provide an uid")
	log("remove_client", uid_to_remove)
	for i=1,#clients do
		local client = clients[i]
		if client.uid == uid_to_remove then
			log("remove_client - removed")
			table.remove(clients, i)
			clients_map[client.uid] = nil
			return
		end
	end
	log("remove_client", uid_to_remove, "clients.length:", #clients)
end

function M.client_count()
	return #clients
end

function M.send_message(client_uid, message)
	assert(client_uid, "You must provide a client_uid")
	assert(message, "You must provide a message")
	log("send uid:", client_uid, "message:", message, "length:", #message)
	-- connection.writer.add(message)
	-- connection.writer.send()

	if connection.connected then
		log("send_message: client_uid", client_uid, "message_len", #message, "message:", message)
		-- connection.writer.add(data)
		connection.writer.add(message)
		connection.writer.send()
	end
end

function M.send_message_others(message, uid)
	assert(message, "You must provide a message")
	assert(uid, "You must provide a uid")
	--log("send_message_others", uid, message)
	for i=1,#clients do
		local client = clients[i]
		if client.uid ~= uid then
			M.send_message(client.uid, message)
		end
	end
end

function M.send_message_all(message)
	assert(message, "You must provide a message")
	log("send_message_all", message)
	for i=1,#clients do
		local client = clients[i]
		M.send_message(client.uid, message)
	end
end

function M.send_message_client(message, uid)
	assert(message, "You must provide a message")
	assert(uid, "You must provide a uid")
	log("send_message_client", uid, message)
	for i=1,#clients do
		local client = clients[i]
		if client.uid == uid then
			M.send_message(client.uid, message)
			break
		end
	end
end

function M.handle_client_message(client_uid, message)
	assert(client_uid, "You must provide a client")
	assert(message, "You must provide a message")
	log("handle_client_message", client_uid, stream.dump(message))
	local out = stream.writer().number(client_uid).bytes(message).tostring()
	M.send_message_others(tomessage(out), client_uid)
end

function M.handle_client_disconnected(client_uid)
	assert(client_uid, "You must provide a client")
	local _disconnect_message = stream.writer()
		.number(client_uid)
		.string(MSG_IDS.DISCONNECT)
		.tostring()
	-- local disconnect_message = tomessage(_disconnect_message)
	-- M.send_message_all(disconnect_message)
	M.send(_disconnect_message)

	remove_client(client_uid)
end

function M.handle_client_connected(uid, player_type)
	local client = create_client(uid, player_type)
	add_client(client)
	--local pos = Utils.random_position()

	--local _other = stream.writer()
	--		.number(client.uid)
	--		.string(MSG_IDS.CONNECT_OTHER)
	--		.vector3(pos)
	--		.tostring()
	--log("handle_client_connected: ", _other)
	--M.send_message_others(tomessage(_other), client.uid)

	--local _self = stream.writer()
	--		.number(client.uid)
	--		.string(MSG_IDS.PLAYER_CREATE_POS)
	--		.vector3(pos)
	--		.tostring()
	--log("handle_client_connected: ", _self)
	--M.send_message(client.uid, tomessage(_self))
	return client
end


--- Send data to the broadsock server
-- Note: The data will actually not be sent until update() is called
-- @param data
function M.send(data)
	if connection.connected then
		log("send", #data, "data:", data)
		connection.writer.add(number_to_int32(#data) .. data)
	end
end

function M.sendGameOver()
	local sw = stream.writer()
	sw.number(-1)
	sw.string(MSG_IDS.GAME_OVER)
	for _, client in pairs(clients_map) do
		sw.string("player")
		sw.number(client.uid)
		sw.number(client.type)
		sw.number(client.map_level)
		sw.number(client.health)
		sw.number(client.score)
		sw.number(client.ws_latency)
	end
	M.send(sw.tostring())
end

local function on_data(data, data_length)
	log("on_data", #data, "data:", data, table.tostring(M.clients or {}))

	local sr = stream.reader(data, data_length)
	local from_uid = sr.number()
	local msg_id = sr.string()
	log("on_data from:", from_uid, "msg_id:", msg_id)

	if msg_id == MSG_IDS.GO then
		-- M.send_message_others(data, from_uid)
		-- if cannotUpdate(0) then
		-- 	return
		-- end
		M.send(data)

		local player_map_level = sr.number()
		local player_type = sr.number()
		local player = clients_map[from_uid]
		if player ~= nil then
			player.map_level = player_map_level
			player.type = player_type
		end

		local count = sr.number()
		--log("remote GO", tostring(count))
		for _=1,count do
			local gouid = sr.string()
			local type = sr.string()

			local pos = sr.vector3()
			local rot = sr.quat()
			local scale = sr.vector3()
		end

		if player ~= nil then
			player.health = sr.number()
			player.score = sr.number()
			player.ws_latency = sr.number()
		end
	elseif msg_id == MSG_IDS.GOD then
		M.send(data)
	elseif msg_id == CLIENT_MSG_IDS.CREATE_PLAYER then
		M.send(stream.writer()
					 .number(from_uid)
					 .string(MSG_IDS.PLAYER_CREATE_POS)
					 .vector3(Utils.random_position())
					 .tostring())
	elseif msg_id == MSG_IDS.CONNECT_ME then
		 M.handle_client_connected(from_uid, sr.number())
	elseif msg_id == MSG_IDS.DISCONNECT then
		M.handle_client_disconnected(from_uid)
	end
end

--- Start the server. This will set up the server socket.
-- @param port The port to listen to connections on
-- @return success True on success, otherwise false
-- @return error Error message on failure, otherwise nil
function M.start(port)
	local server_ip = "127.0.0.1"
	local server_port = port

	local ok, err = pcall(function()
		connection.socket = socket.tcp()
		assert(connection.socket:connect(server_ip, server_port))
		assert(connection.socket:settimeout(0))
		connection.socket_table = { connection.socket }
		connection.writer = tcp_writer.create(connection.socket, M.TCP_SEND_CHUNK_SIZE)
		connection.reader = tcp_reader.create(connection.socket, on_data)
	end)
	if not ok or not connection.socket then
		log("broadsock.create() error", err)
		return nil, ("Unable to connect to %s:%d"):format(server_ip, server_port)
	end
	log("created client")
	connection.connected = true

	M.send(MSG_IDS.GAME_PRE_START)
	timer.delay(MainState.GAME_START_TIMEOUT_IN_SEC, false, function ()
		M.send(MSG_IDS.GAME_START)
		M.send(stream.writer()
					 .number(-1)
					 .string(MSG_IDS.CREATE_FUZES)
					 .number(MainState.FUZE.RED)
					 .vector3(Utils.random_position())
					 .number(MainState.FUZE.GREEN)
					 .vector3(Utils.random_position())
					 .number(MainState.FUZE.BLUE)
					 .vector3(Utils.random_position())
					 .number(MainState.FUZE.YELLOW)
					 .vector3(Utils.random_position())
					 .tostring())
		msg.post("/gui#gui", "game_start")
	end)

	return true
end

--- Stop the server. This will close the server socket
-- and close any client connections
function M.stop()
	if connection.connected then
		log("destroy")
		connection.socket:close()
		connection.socket = nil
		connection.writer = nil
		connection.reader = nil
		connection.socket_table = nil
		connection.connected = false
	end
end

--- Update the server. The server will listen for new connections
-- and read from connected client sockets.
function M.update(dt)
	if connection.connected then
		if rateLimiter(dt) then
			return
		end
		-- send("HELLO")
		-- log("update - sending game objects", instance.gameobject_count())
		-- local sw = stream.writer()
		-- sw.string("GO")
		-- sw.number(gameobject_count)
		-- for gouid,gameobject in pairs(gameobjects) do
		-- 	local pos = go.get_position(gameobject.id)
		-- 	local rot = go.get_rotation(gameobject.id)
		-- 	local scale = go.get_scale(gameobject.id)
		-- 	sw.string(gouid)
		-- 	sw.string(gameobject.type)
		-- 	sw.vector3(pos)
		-- 	sw.quat(rot)
		-- 	sw.vector3(scale)
		-- end
		-- instance.send(sw.tostring())

		-- check if the socket is ready for reading and/or writing
		local receivet, sendt = socket.select(connection.socket_table, connection.socket_table, 0)

		if sendt[connection.socket] then
			-- log("ready to send")
			if not connection.writer.empty() then
				-- log("update - sending from writer")
			end
			local ok, err = connection.writer.send()
			if not ok and err == "closed" then
				M.stop()
				-- instance.destroy()
				-- on_disconnect()
				return
			end
		end

		if receivet[connection.socket] then
			-- log("update - receiving from reader")
			local ok, err = connection.reader.receive()
			if not ok then
				M.stop()
				-- instance.destroy()
				-- on_disconnect()
				return
			end
		end
	else
		log("not connected")
	end
end

return M
