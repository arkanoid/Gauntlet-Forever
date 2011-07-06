players = {}

pclasses = {
 [1] = {
	name = "Troglo",
	class = "Warrior",
	color = {255,0,0},
	armor = 20,
	shot = 2,		-- shot damage
	shot_speed = 2,
	magic = 2,		-- magic damage vs monsters
	magic_vs_gen = 0,	-- magic damage vs generators
	melee = 2,
	speed = 1,
	shot_size = 45,
	shot_pic = love.graphics.newImage("media/shot1.png")
	},
 [2] = {
	name = "Sherra",
	class = "Valkyrie",
	color = {130,130,255},
	armor = 30,
	shot = 1,
	shot_speed = 3,
	magic = 2,
	magic_vs_gen = 0,
	melee = 2,
	speed = 2,
	shot_size = 35,
	shot_pic = love.graphics.newImage("media/shot2.png")
	},
 [3] = {
	name = "Sunda",
	class = "Wizard",
	color = {255,255,0},
	armor = 0,
	shot = 2,
	shot_speed = 4,
	magic = 3,
	magic_vs_gen = 3,
	melee = 1,
	speed = 1,
	shot_size = 35,
	shot_pic = love.graphics.newImage("media/shot3.png")
	},
 [4] = {
	name = "Esar",
	class = "Elf",
	color = {0,255,0},
	armor = 10,
	shot = 1,
	shot_speed = 4,
	magic = 3,
	magic_vs_gen = 2,
	melee = 1,
	speed = 3,
	shot_size = 25,
	shot_pic = love.graphics.newImage("media/shot4.png")
	}
}


function make_player()
	return { 
		ip = 0,	-- for now, LUBE seems to return a number instead of the client IP
		class = 2,
		x = 0, y = 0, 
		dx = 0, dy = 0,	-- direction (integer between -1 and 1)
		last_screenx = 0, -- last screen coordinates (for drawing & shot direction calculation)
		last_screeny = 0,
		hp = 1000,
		keys = 0,

		-- if > 0, shows player in a red tint (means it was hit by a monster)
		-- will be decreased until hits 0
		was_hit = 0,

		invulnerable = false,
		
		-- ready: when connecting to server, flags if client already sent class selection
		-- when during the game, flags if client is still connected
		ready = false,
		
		exit = false,	-- found exit

		-- each player can have only 1 shot in the screen at a given time.
		-- if the shot coordinates are -1,-1 then no shot is displayed
		shot_x = -1,
		shot_y = -1,
		shot_dx = 0,
		shot_dy = 0,
		-- kludge. use by mouse functions to signal a shot will be created
		-- function game_update_player() will read this
		create_shot = false,

		-- old dx,dy different than 0,0 for the shot
		old_dx = 1,
		old_dy = 0
		}
end


function draw_player_status(x,y,player)
	local a
	local hp = math.floor(player.hp)
	local border = 5

	if player.ready then
		love.graphics.setColor(unpack(pclasses[player.class].color))
	else
		love.graphics.setColor(unpack(color["player_quit"]))
	end
	love.graphics.setLineWidth(2)
	love.graphics.setFont(font["player_status"])
	love.graphics.rectangle("line", x+border, y+border, status_panel_w-10, (tile_size*2)-10)

	-- player class
	love.graphics.print(pclasses[player.class].name .. " - " .. pclasses[player.class].class, 
		x + (border*2), y + (border*2))

	-- player HP & bar
	love.graphics.print(hp, x + (border*2), y + player_status_text_h + border)
	love.graphics.rectangle("line", x + (player_status_text_h*2.5), y + player_status_text_h + (border*2),
		(status_panel_w - 70), player_status_text_h/2)
	love.graphics.rectangle("fill", x + (player_status_text_h*2.5), y + player_status_text_h + (border*2),
		(status_panel_w - 70)*hp/1000, player_status_text_h/2)

	-- Keys
	love.graphics.setFont(font["player_status_big"])
	love.graphics.print(player.keys, x + (border*2), y + (player_status_text_h*2.5))
	love.graphics.draw(tiles[key_code], x + (border*2) + player_status_text_h, y + (player_status_text_h*2))
	
	if myrole == "server" and state == "wait_selection" then
		if player.ready then
			a = "Ready"
		else
			a = "Not ready"
		end
		love.graphics.setFont(font["small"])
		love.graphics.print(player.ip .." ".. a, x + 20, y + (tile_size*2) - font["small"]:getHeight())
	end
end


function player_x_to_tile_x(x)
	return math.ceil(x/tile_size)
end
function player_y_to_tile_y(y)
	return math.ceil(y/tile_size)
end

-- Returns char at tile coords x,y (in current map)
function map_cell(x,y)
	local s = maps[current_map].cell[y]
	if s then
		-- bugs.
		return string.byte(s, x)
	end
end

-- x,y are NOT tile coordinates, but player coordinates.
function pmapchar(x,y)
	local s = maps[current_map].cell[ math.ceil(y/tile_size) ]
	if s then
		-- bugs.
		return string.byte(s, math.ceil(x/tile_size) )
	end
end

function player_can_pass(x,y,nx,ny)
	local offx = 0
	local offy = 0
	local result = false
	if (x - nx < 0) then offx = player_w end
	if (y - ny < 0) then offy = player_h end
	
	result = passable[ pmapchar(nx+offx,ny+offy) ]
	if (nx % player_w > 0) then
		result = result and passable[ pmapchar(nx+player_w,ny) ]
	end
	if (ny % player_h > 0) then
		result = result and passable[ pmapchar(nx,ny+player_h) ]
	end
	if (nx % player_w > 0) and (ny % player_h > 0) then
		result = result and passable[ pmapchar(nx+player_w,ny+player_h) ]
	end
	return result
end

-- Checks if the player hits a tile with a certain code.
-- This function looks like player_can_pass(), but it uses OR instead of AND
function player_hits_code(x,y,nx,ny,code)
	local offx = 0
	local offy = 0
	local result = false
	
	if (x - nx < 0) then offx = player_w end
	if (y - ny < 0) then offy = player_h end
	
	result = (pmapchar(nx+offx,ny+offy) == code)
	if (nx % player_w > 0) then
		result = result or (pmapchar(nx+player_w,ny) == code)
	end
	if (ny % player_h > 0) then
		result = result or (pmapchar(nx,ny+player_h) == code)
	end
	if (nx % player_w > 0) and (ny % player_h > 0) then
		result = result or (pmapchar(nx+player_w,ny+player_h) == code)
	end
	return result
end

function shot_can_pass(player)
	 local nx = player.shot_x + player.shot_dx
	 local ny = player.shot_y + player.shot_dy
	 local size = pclasses[player.class].shot_size
	local offx = 0
	local offy = 0
	local result = false
	if (player.shot_dx > 0) then offx = pclasses[player.class].shot_size end
	if (player.shot_dy > 0) then offy = pclasses[player.class].shot_size end
	
	result = passable[ pmapchar(nx+offx,ny+offy) ]
	if (nx % size > 0) then
		result = result and passable[ pmapchar(nx+size,ny) ]
	end
	if (ny % size > 0) then
		result = result and passable[ pmapchar(nx,ny+size) ]
	end
	if (nx % size > 0) and (ny % size > 0) then
		result = result and passable[ pmapchar(nx+size, ny+size) ]
	end
	return result
end

-- Returns a monster number if there are one in x,y or 0 if none
function player_hits_monster(x,y)
	local m
	m = maps[current_map].monstergrid[math.floor(y/monster_steps)][math.floor(x/monster_steps)]
	if m > 0 then
		return m
	end
	m = maps[current_map].monstergrid2[math.floor(y/monster_steps)][math.floor(x/monster_steps)]
	return 0
end

-- Returns list of monster numbers hitting the player
-- note: same monster can appear more than once in list
-- 1234	indices on the array are the positions around the player
-- 2..5 clockwise, from 1 to 12
-- 1..6 array index 0 says how many positions are filled (not how many different monsters)
-- 0987
function monsters_hitting_player(player)
	local mons = {0,0,0,0,0,0,0,0,0,0,0,0}
	local howmany = 0
	local grid = maps[current_map].monstergrid
	local gx = math.floor((player.x-1)/monster_steps)
	local gy = math.floor((player.y-1)/monster_steps)

	-- 1-4
	if grid[gy][gx] > 0 then
		mons[1] = grid[gy][gx]
		howmany = howmany + 1
	end
	if grid[gy][gx+1] > 0 then
		mons[2] = grid[gy][gx+1]
		howmany = howmany + 1
	end
	if grid[gy][gx+2] > 0 then
		mons[3] = grid[gy][gx+2]
		howmany = howmany + 1
	end
	if grid[gy][gx+3] > 0 then
		mons[4] = grid[gy][gx+3]
		howmany = howmany + 1
	end
	
	-- 5-6
	if grid[gy+1][gx+3] > 0 then
		mons[5] = grid[gy+1][gx+3]
		howmany = howmany + 1
	end
	if grid[gy+2][gx+3] > 0 then
		mons[6] = grid[gy+2][gx+3]
		howmany = howmany + 1
	end

	-- 7-10
	if grid[gy+3][gx+3] > 0 then
		mons[7] = grid[gy+3][gx+3]
		howmany = howmany + 1
	end
	if grid[gy+3][gx+2] > 0 then
		mons[8] = grid[gy+3][gx+2]
		howmany = howmany + 1
	end
	if grid[gy+3][gx+1] > 0 then
		mons[9] = grid[gy+3][gx+1]
		howmany = howmany + 1
	end
	if grid[gy+3][gx] > 0 then
		mons[10] = grid[gy+3][gx]
		howmany = howmany + 1
	end

	-- 11-12
	if grid[gy+2][gx] > 0 then
		mons[11] = grid[gy+2][gx]
		howmany = howmany + 1
	end
	if grid[gy+1][gx] > 0 then
		mons[12] = grid[gy+1][gx]
		howmany = howmany + 1
	end
	
	mons[0] = howmany
	
	return mons
end

-- mons is the array generated by monsters_hitting_player()
-- also, this version of the function applies melee damage to only one of the surrounding monsters
function apply_damage_player(player,mons)
	local monsters = {}
	local amonst
	local m
	
	if mons[0] == 0 then
		return
	end
	
	m = math.random(1,12)
	while mons[m] <= 0 or maps[current_map].monsters[mons[m]] == nil do
		m = math.random(1,12)
	end
	monster_hit(mons[m], pclasses[player.class].melee)
	
	for m = 1,12 do
		if mons[m] > 0 and monsters[m] == nil then
			amonst = maps[current_map].monsters[mons[m]]
			if amonst == nil then
				-- debug_text = "Got a nil monster? " .. mons[m]
			else
				if not player.invulnerable then
					player.hp = player.hp - monstertypes[ amonst.type ].damage
				end
			end
			monsters[m] = true
		end
	end
end


function shoot(player)
	 if player.shot_x == -1 and player.shot_y == -1 then
	    player.shot_x = player.x + ((player_w - pclasses[player.class].shot_size) / 2)
	    player.shot_y = player.y + ((player_h - pclasses[player.class].shot_size) / 2)
		--[[
	    if player.old_dx < 0 then
	       player.shot_dx = -pclasses[player.class].shot_speed
	    elseif player.old_dx > 0 then
	    	   player.shot_dx = pclasses[player.class].shot_speed
	    else
		player.shot_dx = 0
	    end
	    if player.old_dy < 0 then
	       player.shot_dy = -pclasses[player.class].shot_speed
	    elseif player.old_dy > 0 then
	    	   player.shot_dy = pclasses[player.class].shot_speed
	    else
		player.shot_dy = 0
	    end
	    ]]--
	end
end

-- Returns a monster number (just one) hit by the player shot
function monster_hit_by_shot(player)
	local grid = maps[current_map].monstergrid
	local gx = math.floor(player.shot_x/monster_steps)
	local gy = math.floor(player.shot_y/monster_steps)
	local gx2 = math.floor((player.shot_x + pclasses[player.class].shot_size)/monster_steps)
	local gy2 = math.floor((player.shot_y + pclasses[player.class].shot_size)/monster_steps)

	-- upper left quadrant
	if grid[gy][gx] ~= 0 then
		return grid[gy][gx]
	end

	-- upper right quadrant
	if grid[gy][gx2] ~= 0 then
		return grid[gy][gx2]
	end

	-- lower left quadrant
	if grid[gy2][gx] ~= 0 then
		return grid[gy2][gx]
	end

	-- lower right quadrant
	if grid[gy2][gx2] ~= 0 then
		return grid[gy2][gx2]
	end
	
	return 0
end