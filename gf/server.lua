clientcount = 0

-- When a client connects
function connCallback(ip, port)
	if state == "wait_selection" then
		clientcount = clientcount + 1
		players[ip] = make_player()
		players[ip].ip = ip
		players[ip].x = players[me].x
		players[ip].y = players[me].y
		-- didn't send its data yet
		players[ip].ready = false
	elseif state == "game" then
		-- must be a client that got DC'ed and is coming back
		-- TODO: not working, client doesn't know it's coming back. must inform it.
		for i,p in pairs(players) do
			if i == ip and not p.ready then
				p.ready = true
			end
		end
	end
end

-- same as in client, but also receives ip and port of sender
function serverRcvCallback(data, ip, port)
	local data2
	
	if state == "wait_selection" then
		lube.bin:setseperators(string.char(1), string.char(2))
		data2 = lube.bin:unpack(data)
		-- only updates the client data if it hasn't sent it already
		if not players[ip].ready then
			players[ip] = data2
			players[ip].ip = ip -- the one that the client sent is wrong (0)
			players[ip].ready = true
			-- TODO APAGUE A LINHA ABAIXO
			players[ip].class = 1
		end
	elseif state == "game" then
		-- data received is client intended deltas (dx,dy)
		lube.bin:setseperators(string.char(1), string.char(2))
		data2 = lube.bin:unpack(data)
		players[ip].dx = data2.dx
		players[ip].dy = data2.dy
		-- client pressed shot key
		if data2.shot then
			players[ip].shot_dx = data2.shot_dx
			players[ip].shot_dy = data2.shot_dy
		   shoot(players[ip])
		end
	end
end

function check_ready_clients()
	local allready = true
	for i,p in pairs(players) do
		allready = (allready and p.ready)
	end
	
	return allready
end

function count_ready_clients()
	local howmany = 0
	for i,p in pairs(players) do
		if i ~= 0 and p.ready then
			howmany = howmany + 1
		end
	end
	
	return howmany
end

-- This function is used once when all clients have selected their characters.
-- Sends every client info about all clients and what's the client number (ip).
function send_initial_data()
	local data

	for i,p in pairs(players) do
		if i ~= me then
			data = { yourip = i }
			lube.bin:setseperators(string.char(1), string.char(2))
			for i2,p2 in pairs(players) do
				data[i2] = lube.bin:pack(p2)
			end
			lube.bin:setseperators(string.char(3), string.char(4))
			lube.server:send( lube.bin:pack(data) )
		end
	end
end


function update_clients()
	local data = {}
	local monsterdata = {}
	local data2send

	-- players data
	lube.bin:setseperators(string.char(1), string.char(2))
	for i2,p2 in pairs(players) do
		data[i2] = lube.bin:pack(p2)
	end

	-- monsters array go in as a player with an ID of 'monsters'
	lube.bin:setseperators(string.char(5), string.char(6))
	for mi,mm in pairs(maps[current_map].monsters) do
		monsterdata[mi] = lube.bin:pack(mm)
	end
	lube.bin:setseperators(string.char(1), string.char(2))
	data['monsters'] = lube.bin:pack(monsterdata)
	
	-- other stuff go in as 'misc'
	lube.bin:setseperators(string.char(5), string.char(6))
	data['misc'] = lube.bin:pack( {
		global_monster_steps = global_monster_steps
		} )

	-- create the final string to be sent
	lube.bin:setseperators(string.char(3), string.char(4))
	data2send = lube.bin:pack(data)

	-- Sends data update individually for each player
	for i,p in pairs(players) do
		-- Except the offline ones and, of course, myself
		if i ~= me and p.ready then
			lube.server:send( data2send, i )
		end
	end
end

function disconnCallback(ip, port) --when a client disconnects
	players[ip].ready = false
end

function myserver()
    lube.server:Init(server_port)
    lube.server:setCallback(serverRcvCallback, connCallback, disconnCallback) --set the callbacks
    lube.server:setHandshake("GauntletCPE"..version) -- should be the same as the client
end

