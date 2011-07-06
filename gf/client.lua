function rcvCallback(data)
	local data2

	if state == "wait_selection" then
		-- we're assuming the client data (character selection) were already sent to the server,
		-- so we're just waiting the server initial data
		lube.bin:setseperators(string.char(3), string.char(4))
		data2 = lube.bin:unpack(data)
		me = data2.yourip
		lube.bin:setseperators(string.char(1), string.char(2))
		for i,p in pairs(data2) do
			if i ~= "yourip" then
				players[i] = lube.bin:unpack(p)
			end
		end
		change_state("game")
	elseif state == "game" then
		receive_update_clients(data)
	end
end

-- See update_clients() for more details.
function receive_update_clients(data)
	local data2
	local new_players = {}
	local monsterdata
	local new_monsters = {}
	local misc

	lube.bin:setseperators(string.char(3), string.char(4))
	data2 = lube.bin:unpack(data)
	for i,p in pairs(data2) do
		if i ~= 'monsters' and i~= 'misc' then
			lube.bin:setseperators(string.char(1), string.char(2))
			new_players[i] = lube.bin:unpack(p)
		elseif i == 'monsters' then
			lube.bin:setseperators(string.char(1), string.char(2))
			monsterdata = lube.bin:unpack(p)
			lube.bin:setseperators(string.char(5), string.char(6))
			for mi,mm in pairs(monsterdata) do
				new_monsters[mi] = lube.bin:unpack(mm)
			end
			maps[current_map].monsters = new_monsters
		elseif i == 'misc' then
			lube.bin:setseperators(string.char(5), string.char(6))
			misc = lube.bin:unpack(p)
			if misc['global_monster_steps'] ~= nil then
				global_monster_steps = misc['global_monster_steps']
			end
		end
	end
	
	players = new_players
end

function myclient()
	lube.client:Init()
	lube.client:setHandshake("GauntletCPE"..version)
	lube.client:setCallback(rcvCallback) --set rcvCallback as the callback for received messages
	lube.client:connect(server_address, server_port)
end

