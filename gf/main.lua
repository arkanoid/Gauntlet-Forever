server_address = "127.0.0.1"
server_port = 3333
version = "0.7"

-- Tile size
tile_size = 50
-- Player size
player_w = 45
player_h = 45
-- Arrow size (showed when another player is offscreen)
arrow_size = 20

-- Map character codes
floor_code = 32		-- " "
wall_code  = 35		-- #
exit_code  = 69		-- E
door_code  = 43		-- +
key_code   = 63		-- ?
passable = { 
	[floor_code] = true, [exit_code] = true,
	[wall_code] = false,
	[key_code] = true, [door_code] = false
	}

require "player.lua"
require "LUBE.lua"
require "monsters.lua"
require "server.lua"
require "client.lua"

math.randomseed( os.time() )

function love.load()
	-- Resources
	color =	 { background = {0,0,0},
		menu_selected = {245,93,63},
		menu = {176,177,178},
		panel = {0,0,0},
		default	= {255,255,255},
		player_quit = {80,80,80},
		player_damaged = {255,150,150},
		player_invuln  = {255,255,130},
		monster_damaged = {255,150,150}
		}
	font = { 
		default = love.graphics.newFont(24),
		large = love.graphics.newFont(32),
		small = love.graphics.newFont(18),
		title = love.graphics.newFont(80), 
		player_status = love.graphics.newFont(18),
		player_status_big = love.graphics.newFont(24)
		}
	player_status_text_h = font["player_status"]:getHeight()
	graphics = { 
		player1 = love.graphics.newImage("media/1.png"),
		player2 = love.graphics.newImage("media/2.png"),
		player3 = love.graphics.newImage("media/3.png"),
		player4 = love.graphics.newImage("media/4.png"),
		}
	dirs = { 'ul','u','ur','r','dr','d','dl','l' }
	for p = 1,4 do
	    for d = 1,8 do
	    	graphics["player"..p..dirs[d]] = love.graphics.newImage("media/player"..p..dirs[d]..".png");
	    end
	end

	floor = love.graphics.newImage("media/floorstone0.png")
	floor2 = love.graphics.newImage("media/floorstone2.png")
	floor3 = love.graphics.newImage("media/floorstone3.png")
	floor5 = love.graphics.newImage("media/floorstone5.png")
	floor7 = love.graphics.newImage("media/floorstone7.png")
	floor11 = love.graphics.newImage("media/floorstone11.png")
	tiles = { 
		[wall_code] = love.graphics.newImage("media/bricks.png"),
		[floor_code] = floor,
		[103] = floor, [116] = floor,
		[43] = floor,
		[exit_code] = love.graphics.newImage("media/exit.png"),
		[door_code] = love.graphics.newImage("media/door.png"),
		[key_code] = love.graphics.newImage("media/chave.png"),
		[71] = love.graphics.newImage("media/bonepile.png"),
		[84] = love.graphics.newImage("media/ie.png")
		}

	--music =	{ 
	--	menu = love.audio.newSource("music/1.02-title-alt-.mp3"),
	--	game = love.audio.newSource("music/1.06-city-under-siege-2.mp3")
	--	}
	--sound =	{	click = love.audio.newSource("media/click.ogg", "static"),
	--			shush = love.audio.newSource("media/shh.ogg", "static"),
	--			pling = love.audio.newSource("media/pling.ogg", "static") }

	last_dt = 0

    -- map variables
    map_display_buffer = 2 -- We have to buffer one tile before and behind our viewpoint.
                           -- Otherwise, the tiles will just pop into view, and we don't want that.
	-- How many tiles fit on the screen
	tile_display_w = math.floor(love.graphics.getWidth() / tile_size)
	tile_display_h = math.floor(love.graphics.getHeight() / tile_size)
	tile_display_w = tile_display_h		-- so we have space for the status panel.
	-- Half the tiles that fit on the screen (for the drawing routines)
	half_display_w = math.floor(tile_display_w / 2)
	half_display_h = math.floor(tile_display_h / 2)

	status_panel_w = love.graphics.getWidth() - (tile_display_w * tile_size)
	status_panel_x = love.graphics.getWidth() - status_panel_w

	maps = {}
	current_map = 0
	next_level()

	me = 0
	players[0] = make_player()

	menu = {
		save   = { text = "Save...",			x = 450, y = 400, role = "server" },
		server = { text = "Start (as server)",	x = 450, y = 400, role = nil },
		continues = { text = "Continue",			x = 450, y = 450, role = "server" },
		continuec = { text = "Continue",			x = 450, y = 450, role = "client" },
		client = { text = "Connect to server...",	x = 450, y = 450, role = nil },
		about  = { text = "About",				x = 450, y = 500, role = "any" },
		quit   = { text = "Quit",				x = 450, y = 550, role = "any" }
		}
	for id,item in pairs(menu) do
		item.width = font["large"]:getWidth(item.text)
		item.height = font["large"]:getHeight()
		item.hover = false
	end
    
	-- starts game at main menu
	change_state("menu")
	myrole = nil	-- server or client

	love.graphics.setBackgroundColor(unpack(color["background"]))
end


-- function used to randomize the floor appearance. <div> is usually a prime number.
function match_pattern(x,y,div)
	return ( math.floor((x+y)/div) == (x+y)/div )
end
function match_pattern2(x,y,div)
	return ( 
		math.floor(x/div) == x/div 
		and math.floor(y/div) == y/div
		and math.mod((x/div)+(y/div), 2) ~= 0
		)
end

function change_state(newstate)
	--[[if newstate == "menu" then
		myrole = nil
	end]]--
	
	state = newstate
	love.graphics.setColor(unpack({255,255,255}))
	
	--[[if state == "menu" or state == "game" then
		love.audio.stop()
		love.audio.play(music[state], 0)
	end]]--
	
	if state == "wait_selection" then
		-- we must set these coords here so the clients will be set accordingly
		players[me].x = maps[current_map].start_x * tile_size
		players[me].y = maps[current_map].start_y * tile_size
	end
end


--
-- Functions to put the game in server or client state

function game_server()
	players = {}
	players[me] = make_player()
	players[me].ready = true -- TODO: must be set at selection screen
	myserver()
	myrole = "server"
	change_state("wait_selection")
end

function game_client()
	myrole = "client"
	change_state("wait_selection")
	myclient()
end


--
-- Loads a new map from a file.
--
function loadmap(filename)
	local map = { cell = {}, start_x = 1, start_y = 1, generators = {} }
	local pos
	for line in love.filesystem.lines(filename) do
		pos = string.find(line, "S")
		if pos ~= nil then
			map.start_x = pos
			map.start_y = #(map.cell)
			line = string.gsub(line, "S", " ")
		end
		table.insert(map.cell, line)
	end
	map.width = #(map.cell[1]) -- Obtains the width of the first row of the map
	map.height = #(map.cell) -- Obtains the height of the map
	map.x = 0
	map.y = 0
	map.display_w = math.floor(love.graphics.getWidth() / tile_size)
	map.display_h = math.floor(love.graphics.getHeight() / tile_size)

	map.monsters = {}
	map.monsterindex = 0 -- only for creating new monsters, dead ones are simply deleted
	map.monstergrid2 = create_monster_grid(map)
	map.monstergrid = create_empty_monster_grid(map)
	
	-- identify generators
	for y,line in pairs(map.cell) do
		for x = 1, #line do
			if string.byte(map.cell[y], x) ~= floor_code and
				string.byte(map.cell[y], x) ~= wall_code and
				string.byte(map.cell[y], x) ~= exit_code then
				for i,gt in pairs(generatortypes) do
					if string.byte(map.cell[y], x) == i then
						map.generators[#map.generators+1] = { 
							type = i, 
							x = x, y = y, -- tile coords
							hp = gt.hp,
							timer = 200 * gt.timer
							}
					end
				end
			end
		end
	end
	
	return map
end


-- tx,ty are tile coords
function replace_map_cell(tx,ty,code)
	maps[current_map].cell[ty] =
		string.sub(maps[current_map].cell[ty], 1, tx-1) .. string.char(code) ..
		string.sub(maps[current_map].cell[ty], tx+1)
end

-- x,y are tile coords
function open_door_around(x,y)
	local i,j,k,l
	
	-- looks for a door
	for j = y-1, y+1 do
		for i = x-1, x+1 do
			if map_cell(i,j) == door_code then
				-- horizontal door?
				if map_cell(i-1,j) == door_code or map_cell(i+1,j) == door_code then
					k = i
					while map_cell(k-1,j) == door_code do
						k = k - 1
					end
					l = i
					while map_cell(l+1,j) == door_code do
						l = l + 1
					end
					for i = k,l do
						replace_map_cell(i,j,floor_code)
					end
				-- vertical door?
				elseif map_cell(i,j-1) == door_code or map_cell(i,j+1) == door_code then
					k = j
					while map_cell(i,k-1) == door_code do
						k = k - 1
					end
					l = j
					while map_cell(i,l+1) == door_code do
						l = l + 1
					end
					for j = k,l do
						replace_map_cell(i,j,floor_code)
					end
				end
			end
		end
	end
end


-- Goes to next level, loading it into maps[].
function next_level()
	current_map = current_map + 1
	if maps[current_map] == nil then
		maps[current_map] = loadmap(string.format("levels/%03d.txt", current_map))
	end
end



function draw_menu()
	local title = "Gauntlet Forever"

	love.graphics.setColor(unpack(color["menu"]))
	love.graphics.setFont(font["title"])
	love.graphics.print(title, 50, 25)
	love.graphics.setFont(font["small"])
	love.graphics.print(version, 60 + font["title"]:getWidth(title), font["title"]:getHeight())

	love.graphics.setFont(font["large"])

	for id,item in pairs(menu) do
		if item.role == "any" or item.role == myrole then
			if item.hover then love.graphics.setColor(unpack(color["menu_selected"]))
			else love.graphics.setColor(unpack(color["menu"])) end
			love.graphics.print(item.text, item.x, item.y)
		end
	end
end


function draw_status_panel()
	love.graphics.setColor(unpack(color["panel"]))
	love.graphics.rectangle("fill", status_panel_x, 0, status_panel_w, love.graphics.getHeight())
	draw_player_status(status_panel_x, 0, players[me])
	if myrole ~= nil then	-- not a single player game
		local y = tile_size * 2
		for id,p in pairs(players) do
			if id ~= me then
				draw_player_status(status_panel_x, y, p)
				y = y + (tile_size * 2)
			end
		end
	end

	if myrole == "client" then
		love.graphics.setFont(font["small"])
		love.graphics.print("Server:" .. server_address, status_panel_x + 5, love.graphics.getHeight() - 20)
	end
end


-- Shown when state == "wait_selection"
-- Here the player will select a character. Also, the server will wait until everybody has chosen,
-- and the clients will wait the server's ok
function draw_selection_screen()
	local text

	if me ~= 0 then me = 0 end -- TODO: debugging client.lua, delete this line!!!
	
	if myrole == "server" then
		text = "Waiting clients (".. count_ready_clients() .."/".. clientcount ..") press p to start"
	else
		text = "Data sent, waiting for server"
		if players[me].ready then
			text = text .. " (already sent my data)"
		else
			text = text .. " (sending my data...)"
		end
	end

	love.graphics.setFont(font["default"])
	love.graphics.setColor(unpack(color["menu"]))
	love.graphics.print(text, 
		(love.graphics.getWidth() - font["default"]:getWidth(text)) / 2, 
		love.graphics.getHeight() / 2)
end

function draw_select_server()
	local text

	love.graphics.setColor(unpack(color["menu"]))

	love.graphics.setFont(font["default"])
	text = "Type the server IP"
	love.graphics.print(text, 
		(love.graphics.getWidth() - font["default"]:getWidth(text)) / 2, 
		love.graphics.getHeight() / 2 - 100)

	love.graphics.setFont(font["large"])
	text = server_address .. "_"
	love.graphics.print(text, 
		(love.graphics.getWidth() - font["large"]:getWidth(text)) / 2, 
		love.graphics.getHeight() / 2)
end



--
-- Draws main game screen
--
function draw_map(map)
	love.graphics.setColor(unpack({255,255,255}))
	
	-- focustile is the tile show at center of screen
	local focustile_x = math.floor(players[me].x / tile_size)
	local focustile_y = math.floor(players[me].y / tile_size)
	local offset_x = players[me].x % tile_size
	local offset_y = players[me].y % tile_size
	-- player at center of screen, if possible...
	local px = (half_display_w)*tile_size
	local py = (half_display_h)*tile_size
	local x,y
	local image, tmp, char
	
	-- Checks when single player is too close one of the borders
	-- so it stops being anchored at screen center and move
	-- towards border
	-- too close of left border
	if focustile_x < half_display_w then
		focustile_x = half_display_w
		offset_x = 0
		px = players[me].x
	end
	-- too close of right border
	if focustile_x > map.width - half_display_w - 1 then
		focustile_x = map.width - half_display_w
		offset_x = 0
		px = players[me].x - ((focustile_x - half_display_w)*tile_size)
	end
	-- too close of upper border
	if focustile_y < half_display_h then
		focustile_y = half_display_h
		offset_y = 0
		py = players[me].y
	end
	-- too close of lower border
	if focustile_y > map.height - half_display_h - 1 then
		focustile_y = map.height - half_display_h
		offset_y = 0
		py = players[me].y - ((focustile_y - half_display_h)*tile_size)
	end
	players[me].last_screenx = px
	players[me].last_screeny = py
	
	local offset_tile_x = focustile_x - half_display_w
	local offset_tile_y = focustile_y - half_display_h
	
	local leftmost_tile = offset_tile_x - 1
	local rightmost_tile = offset_tile_x + tile_display_w + 1
	local topmost_tile = offset_tile_y - 1
	local bottommost_tile = offset_tile_y + tile_display_h + 1
	
	-- draws tiles
	for y = topmost_tile, bottommost_tile do
		for x = leftmost_tile, rightmost_tile do
			if x >= 0 and x <= map.width and 
				y >= 0 and y < map.height then
				tmp = string.byte(map.cell[y+1], x+1)
				image = tiles[tmp]
				if image ~= nil then
					if tmp ~= floor_code then
						love.graphics.draw(tiles[floor_code], 
							(x-offset_tile_x)*tile_size - offset_x, 
							(y-offset_tile_y)*tile_size - offset_y)
					else
						-- randomizes the floor a bit.
						if match_pattern(x,y,2) then
							image = floor2
						end
						if match_pattern2(x,y,3) then
							image = floor3
						end
						if match_pattern2(x,y,5) then
							image = floor5
						end
						if match_pattern2(x,y,7) then
							image = floor7
						end
						if match_pattern2(x,y,11) then
							image = floor11
						end
					end
					love.graphics.draw(image, 
						(x-offset_tile_x)*tile_size - offset_x, 
						(y-offset_tile_y)*tile_size - offset_y)
				end
			end
		end
	end
	
	-- draws monsters
	for i,m in pairs(map.monsters) do
		if m.x/2 >= leftmost_tile and m.x/2 <= rightmost_tile
			and m.y/2 >= topmost_tile and m.y/2 <= bottommost_tile then
			x = m.x * tile_size / 2
			y = m.y * tile_size / 2
			if m.dx > 0 then
				image = monstertypes[m.type].image_right
			else
				image = monstertypes[m.type].image_left
			end
			if m.washit > 0 then
				love.graphics.setColor(unpack(color["monster_damaged"]))
			else
				love.graphics.setColor(unpack({255,255,255}))
			end
			love.graphics.draw(image, 
				px - players[me].x + x + (m.dx*global_monster_steps), 
				py - players[me].y + y + (m.dy*global_monster_steps))
		end
	end

	-- draws other players
	local opx, opy, oh, ov, image
	for i,p in pairs(players) do
		if i ~= me and p.ready then
			oh = "" -- h,v directions for arrows, if any
			ov = ""
			opx = px - players[me].x + p.x
			opy = py - players[me].y + p.y
			if opx < 0 then
				opx = 0
				oh = "l"
			end
			if opy < 0 then 
				opy = 0
				ov = "u"
			end
			if opx > tile_display_w * tile_size then
				opx = tile_display_w * tile_size - arrow_size
				oh = "r"
			end
			if opy > tile_display_h * tile_size then
				opy = tile_display_h * tile_size - arrow_size
				ov = "d"
			end
			love.graphics.draw(graphics['player'..p.class..ov..oh], opx, opy)
			-- draws shot
			if p.shot_x ~= -1 and p.shot_y ~= -1 then
				love.graphics.setColor(unpack({255,255,255}))
				love.graphics.draw(pclasses[p.class].shot_pic, 
					px - players[me].x + p.shot_x,
					py - players[me].y + p.shot_y)
			end
		end
	end

	-- draws player (always on top of other players)
	if players[me].invulnerable then
		love.graphics.setColor(unpack(color["player_invuln"]))
	elseif players[me].was_hit > 0 then
		love.graphics.setColor(unpack(color["player_damaged"]))
	else
		love.graphics.setColor(unpack({255,255,255}))
	end
	love.graphics.draw(graphics['player'..players[me].class], px, py)
	-- draws player shot
	if players[me].shot_x ~= -1 and players[me].shot_y ~= -1 then
		love.graphics.setColor(unpack({255,255,255}))
		love.graphics.draw(pclasses[players[me].class].shot_pic, 
			px - players[me].x + players[me].shot_x,
			py - players[me].y + players[me].shot_y)
	end	


	draw_status_panel()

	if players[me].hp <= 0 then
		local text = "GANHOU um OVO"
		love.graphics.setFont(font["default"])
		love.graphics.print(text, 
			(love.graphics.getWidth() - status_panel_w - font["default"]:getWidth(text)) / 2, 
			love.graphics.getHeight()/2 - 20)
	end

	love.graphics.setFont(font["small"])
	love.graphics.print(clientcount, 5, love.graphics.getHeight() - 20)
end



--
-- Update function when showing the menu.
--
function menu_update(dt)
	local x = love.mouse.getX()
	local y = love.mouse.getY() - 50

	for id,item in pairs(menu) do
		if x > item.x 
			and x < item.x + item.width
			and y > item.y - item.height
			and y < item.y then
			item.hover = true
		else
			item.hover = false
		end
	end

	if love.keyboard.isDown("q") then
		quit()
	elseif love.keyboard.isDown("s") then
		game_server()
	elseif love.keyboard.isDown("c") then
		change_state("select_server")
	end
end



-- Update own player, checking pressed keys.
-- Other updates are handled by game_update_server() or game_update_client().
function game_update_player(dt)
	local delta = { dx = 0, dy = 0, shot = false, shot_dx = 0, shot_dy = 0 }
	
	if love.keyboard.isDown("escape") then
		change_state("menu")
	end

	-- get intended movement deltas (dx,dy)
	if love.keyboard.isDown("w") then
		delta.dy = - pclasses[players[me].class].speed
	end
	if love.keyboard.isDown("s") then
		delta.dy = pclasses[players[me].class].speed
	end
	if love.keyboard.isDown("a") then
		delta.dx = - pclasses[players[me].class].speed
	end
	if love.keyboard.isDown("d") then
		delta.dx = pclasses[players[me].class].speed
	end

	-- if love.keyboard.isDown("lctrl") or love.keyboard.isDown("space") then
	if players[me].create_shot then
	   if players[me].shot_x == -1 and players[me].shot_y == -1 then
	      delta.shot = true
	      delta.shot_dx = players[me].shot_dx
	      delta.shot_dy = players[me].shot_dy
	      players[me].create_shot = false
	   end
	end

	return delta
end



-- Update functions when playing.
--
function game_update_server(dt)
	local mons
	local tx, ty
	
	-- Use deltas to update players if applicable
	for i,p in pairs(players) do
		if p.hp > 0 then
		   	-- if deltas are ~= 0,0 then update old deltas
			if p.dx ~= 0 or p.dy ~= 0 then
			   p.old_dx = p.dx
			   p.old_dy = p.dy
			end

			-- player will hit a door
			if player_hits_code(p.x, p.y, p.x+p.dx, p.y+p.dy, door_code) and p.keys > 0 then
				open_door_around(player_x_to_tile_x(p.x+p.dx), player_y_to_tile_y(p.y+p.dy))
				p.keys = p.keys - 1
			end

			if player_can_pass(p.x, p.y, p.x + p.dx, p.y + p.dy) or
				player_hits_monster(p.x + p.dx, p.y + p.dy) > 0 then
				p.x = p.x + p.dx
				p.y = p.y + p.dy
			end
			
			-- gets key?
			tx = player_x_to_tile_x(p.x + (player_w/2))
			ty = player_y_to_tile_y(p.y + (player_h/2))
			if map_cell(tx,ty) == key_code then
				p.keys = p.keys + 1
				replace_map_cell(tx, ty, floor_code)
			end
			-- found exit?
			if map_cell(tx,ty) == exit_code then
				p.exit = true
				if clientcount == 0 then
					next_level()
				end
			end
			
			mons = monsters_hitting_player(p)
			if mons[0] > 0 then
				p.was_hit = 20
			elseif p.was_hit > 0 then
				p.was_hit = p.was_hit - 1
			end
			if not p.invulnerable then
				p.hp = p.hp - 0.01
			end
			apply_damage_player(p,mons)
		end
		if p.shot_x ~= -1 and p.shot_y ~= -1 then
			mons = monster_hit_by_shot(p)
			if mons ~= 0 then
				monster_hit(mons, pclasses[p.class].shot)
				p.shot_x = -1
				p.shot_y = -1
			else
				if shot_can_pass(p) then
					p.shot_x = p.shot_x + p.shot_dx
					p.shot_y = p.shot_y + p.shot_dy
				else
					p.shot_x = -1
					p.shot_y = -1
				end
			end
		end
	end
	
	-- generates more monsters
	for i,g in pairs(maps[current_map].generators) do
		g.timer = g.timer - 1
		if g.timer <= 0 then
			g.timer = generatortypes[g.type].timer * (200 - (current_map*2))
			generate_monster(g)
		end
	end

	update_clients()
	lube.server:update(dt)
end

-- Client sends his movement & shot info 
function game_update_client(dt, delta)
	lube.bin:setseperators(string.char(1), string.char(2))
	lube.client:send( lube.bin:pack(delta) )
	lube.client:update(dt)
end



--
-- Main update
--
function love.update( dt )
	 local delta

	if state == "menu" then
		menu_update(dt)

	elseif state == "game" then
		-- only 200 times per second
		last_dt = last_dt + dt
		if last_dt < 0.005 then
			return
		end
		last_dt = 0
		-- update monster steps
		global_monster_steps = global_monster_steps + 1
		if global_monster_steps == monster_steps then
			global_monster_steps = 0
			if myrole == "server" then
				update_monsters_objectives(maps[current_map])
			end
		end
		delta = game_update_player(dt)
		-- run client or server
		if myrole == "server" or myrole == nil then
			game_update_server(dt)
			players[me].dx = delta.dx
			players[me].dy = delta.dy
			if delta.shot then
			   shoot(players[me])
			end
		elseif myrole == "client" then
			game_update_client(dt, delta)
		end

	elseif state == "wait_selection" then
		if myrole == "client" then
			-- the client sends its player data
			--if not players[me].ready then
				lube.bin:setseperators(string.char(1), string.char(2))
				lube.client:send( lube.bin:pack(players[me]) )
			--	players[me].ready = true
			--end
			lube.client:update(dt)
		elseif myrole == "server" then
			if love.keyboard.isDown("p") and check_ready_clients() then
				send_initial_data()
				change_state("game")
			end
			lube.server:update(dt)
		end
		if love.keyboard.isDown( "escape" ) then
			change_state("menu")
		end
		
	end
end


--
-- Main mouse event dispatcher
--
function love.mousepressed(x, y, button)
	-- When in game
	if state == "game" and not players[me].create_shot 
		and players[me].shot_x == -1 and players[me].shot_y == -1 then
		local mdx, mdy
		mdx = x - players[me].last_screenx - (player_w/2)
		mdy = y - players[me].last_screeny - (player_h/2)
		if math.abs(mdx) > math.abs(mdy) then
			if mdx ~= 0 then
				mdy = mdy / math.abs(mdx)
			end
			if mdx < 0 then mdx = -1
			else mdx = 1 end
		elseif math.abs(mdy) > math.abs(mdx) then
			if mdy ~= 0 then
				mdx = mdx / math.abs(mdy)
			end
			if mdy < 0 then mdy = -1
			else mdy = 1 end
		end
		players[me].shot_dx = mdx * pclasses[players[me].class].shot_speed
		players[me].shot_dy = mdy * pclasses[players[me].class].shot_speed
		players[me].create_shot = true
	
	-- When in menu
	elseif state == "menu" then
		for id,item in pairs(menu) do
			if item.hover then
				if id == "quit" then
					love.event.push("q")
				elseif id == "server" then
					game_server()
				elseif id == "client" then
					change_state("select_client")
				elseif id == "continues" or id == "continuec" then
					change_state("game")
				elseif id == "save" then
					change_state("game")
				end
			end
		end
	end
end


--
-- Main keyboard event dispatcher
-- At the moment, used only for the client to type in the server IP
--
function love.keyreleased( key, unicode )
	if state == "select_server" then
		if key == "backspace" and #server_address > 0 then
			server_address = string.sub(server_address, 1, -2)
		elseif key == "escape" then
			myrole = nil
			change_state("menu")
		elseif key == "return" and #server_address > 0 then
			game_client()
		elseif (key >= "0" and key <= "9") or key == "." then
			server_address = server_address .. key
		end
	end
end


--
-- Main draw function
--
function love.draw()
	if state == "menu" then
		draw_menu()
	elseif state == "game" then
		draw_map(maps[current_map])
	elseif state == "wait_selection" then
		draw_selection_screen()
	elseif state == "select_server" then
		draw_select_server()
	end
end


function quit()
	if myrole == "client" then
		lube.client:disconnect()
	end
	love.event.push("q")
end
