-- Monster steps (from each monster grid pos)
monster_steps = math.floor(tile_size/2)
global_monster_steps = monster_steps - 1


monstertypes = {
 [103] = {
	image_right = love.graphics.newImage("media/casper.png"),
	image_left = love.graphics.newImage("media/casper2.png"),
	damage = 10,
	hp = 1
	},
 [116] = {
	image_right = love.graphics.newImage("media/trollface.png"),
	image_left = love.graphics.newImage("media/trollface2.png"),
	damage = 20,
	hp = 2
	}
}
for i,m in pairs(monstertypes) do
	passable[i] = true
end

generatortypes = {
 [71] = {
	generates = 103,
	hp = 10,
	timer = 5	-- in seconds, in first level (quicker in later levels)
	},
 [84] = {
	generates = 116,
	hp = 20,
	timer = 5
	}
}
for i,g in pairs(generatortypes) do
	passable[i] = false
end

	
-- The monster x,y coordinates are its coordinates in the monster grid (left-top corner)
function create_monster(map, type, x, y, updategrid)
	-- monstertype doesn't exist, do nothing and return monster 0.
	if monstertypes[type] == nil then
		return 0
	end

	map.monsterindex = map.monsterindex + 1
	map.monsters[map.monsterindex] = { 
		type = type, x = x, y = y, dx = 0, dy = 0,
		hp = monstertypes[type].hp,
		-- if > 0, shows monster in a red tint (means it was hit by player)
		washit = 0
		}
		
	if updategrid then
		map.monstergrid2[y][x] = map.monsterindex
		map.monstergrid2[y+1][x] = map.monsterindex
		map.monstergrid2[y][x+1] = map.monsterindex
		map.monstergrid2[y+1][x+1] = map.monsterindex
	end
		
	return map.monsterindex
end


-- Creates monster grid based on map.
-- The monster grid have double the dimensions of the map grid, and the monsters occupy a size similar
-- to every map cell and every player. But for every map cell there is 4 (2x2) monster grid cells,
-- therefore, at every time a monster is occupying 4 (2x2) cells in this grid.
function create_monster_grid(map)
	local grid = create_empty_monster_grid(map)
	local monsternum, mx, my
	for y,line in pairs(map.cell) do
		for x = 1, #line do
			-- identifies a monster character
			for mc, mt in pairs(monstertypes) do
				if string.byte(map.cell[y], x) == mc then
					my = y*2-1
					mx = x*2-1
					monsternum = create_monster(map, mc, mx, my, false)
					--if not pcall(function ()
					grid[my][mx] = monsternum
					grid[my][mx+1] = monsternum
					grid[my+1][mx] = monsternum
					grid[my+1][mx+1] = monsternum
					--end) then debug.debug() end
				end
			end
		end
	end
	
	return grid
end


function create_empty_monster_grid(map)
	local grid = {}
	local mx, my
	
	for y = 1,map.height*2 do
		grid[y] = {}
		for x = 1,map.width*2 do
			grid[y][x] = 0
		end
	end
	
	return grid
end

function occupied_by_other_monster_FFFFUUUU(monsternum, x, y, grid)
	return (
		(grid[y][x] ~= monsternum		and grid[y][x] ~= 0) or
		(grid[y+1][x] ~= monsternum		and grid[y+1][x] ~= 0) or
		(grid[y][x+1] ~= monsternum		and grid[y][x+1] ~= 0) or
		(grid[y+1][x+1] ~= monsternum	and grid[y+1][x+1] ~= 0)
		)
end

function occupied_grid_pos(grid, x, y, monsternum)
	return (grid[y][x] ~= nil and grid[y][x] ~= monsternum and grid[y][x] ~= 0)
end

function occupied_by_other_monster(monsternum, grid)
	local m = maps[current_map].monsters[monsternum]
	local result = false
	
	if m == nil then
		debug_text = "Rá! Pegadinha do Mallandro!"
		return false
	end

	local x = m.x
	local y = m.y

	if m.dx == -1 then
		if m.dy == -1 then
			result = (
				occupied_grid_pos(grid, x-1, y-1, monsternum) or
				occupied_grid_pos(grid, x-1, y, monsternum) or
				occupied_grid_pos(grid, x, y-1, monsternum)
			)
		elseif m.dy == 0 then
			result = (
				occupied_grid_pos(grid, x-1, y, monsternum) or
				occupied_grid_pos(grid, x-1, y+1, monsternum)
			)
		elseif m.dy == 1 then
			result = (
				(grid[y+2][x-1] ~= monsternum	and grid[y+2][x-1] ~= 0) or
				(grid[y+1][x-1] ~= monsternum	and grid[y+1][x-1] ~= 0) or
				(grid[y+2][x] ~= monsternum		and grid[y+2][x] ~= 0)
			)
		end
	elseif m.dx == 0 then
		if m.dy == -1 then
			result = (
				(grid[y-1][x] ~= monsternum		and grid[y-1][x] ~= 0) or
				(grid[y-1][x+1] ~= monsternum	and grid[y-1][x+1] ~= 0)
			)
		elseif m.dy == 0 then
			-- Hm?
		elseif m.dy == 1 then
			result = (
				(grid[y+2][x] ~= monsternum		and grid[y+2][x] ~= 0) or
				(grid[y+2][x+1] ~= monsternum	and grid[y+2][x+1] ~= 0)
			)
		end
	elseif m.dx == 1 then
		if m.dy == -1 then
			result = (
				(grid[y-1][x+2] ~= monsternum	and grid[y-1][x+2] ~= 0) or
				(grid[y-1][x+1] ~= monsternum	and grid[y-1][x+1] ~= 0) or
				(grid[y][x+2] ~= monsternum		and grid[y][x+2] ~= 0)
			)
		elseif m.dy == 0 then
			result = (
				(grid[y][x+2] ~= monsternum		and grid[y][x+2] ~= 0) or
				(grid[y+1][x+2] ~= monsternum	and grid[y+1][x+2] ~= 0)
			)
		elseif m.dy == 1 then
			result = (
				(grid[y+2][x+2] ~= monsternum	and grid[y+2][x+2] ~= 0) or
				(grid[y+1][x+2] ~= monsternum	and grid[y+1][x+2] ~= 0) or
				(grid[y+2][x+1] ~= monsternum	and grid[y+2][x+1] ~= 0)
			)
		end
	end
	
	return result
end


-- Must be called only when global_monster_steps is 0
-- Update monsters objectives and their positions
function update_monsters_objectives(map)
	local goal
	local distx, disty

	-- swaps the "future" grid for the current one
	map.monstergrid, map.monstergrid2 = map.monstergrid2, map.monstergrid
	
	-- now cleans "future" grid
	for y = 1, map.width*2 do
		for x = 1, map.height*2 do
			map.monstergrid2[y][x] = 0
		end
	end
	
	-- for each monster, updates its position and checks goal
	for i,m in pairs(map.monsters) do
		if m ~= nil then
			m.x = m.x + m.dx
			m.y = m.y + m.dy

			if m.washit > 0 then
				m.washit = m.washit - 1
			end

			-- Where do you want to go today?
			goal = find_closest_player(m)
			distx = goal.x - m.x*monster_steps
			disty = goal.y - m.y*monster_steps
			if distx > 0 then
				m.dx = 1
			elseif distx < 0 then
				m.dx = -1
			else
				m.dx = 0
			end
			if disty > 0 then
				m.dy = 1
			elseif disty < 0 then
				m.dy = -1
			else
				m.dy = 0
			end
			if math.abs(distx) < math.abs(disty/2) then
				m.dx = 0
			elseif math.abs(disty) < math.abs(distx/2) then
				m.dy = 0
			end
			-- Lets see if you can go that way...
			if not monster_can_pass(m, map)
				or occupied_by_other_monster(i, map.monstergrid)
				or occupied_by_other_monster(i, map.monstergrid2)
				or monster_will_move_into_a_player(m) then
				
				m.dx = 0
				m.dy = 0
			end
		
			map.monstergrid2[m.y+m.dy][m.x+m.dx] = i
			map.monstergrid2[m.y+m.dy+1][m.x+m.dx] = i
			map.monstergrid2[m.y+m.dy][m.x+m.dx+1] = i
			map.monstergrid2[m.y+m.dy+1][m.x+m.dx+1] = i
		end
	end
end



function monster_will_move_into_a_player(monster)
	local px, py
	
	px = ((monster.x+monster.dx) * monster_steps) + (monster_steps / 2)
	py = ((monster.y+monster.dy) * monster_steps) + (monster_steps / 2)

	for i,p in pairs(players) do
		if px > p.x and px < p.x + player_w and
			py > p.y and py < p.y + player_h then
			return true
		end
	end
	
	return false
end


function find_closest_player(monster)
	local player = players[me]
	local mx = monster.x * monster_steps
	local my = monster.y * monster_steps
	
	for i,p in pairs(players) do
		if math.abs(p.x - mx) + math.abs(p.y - my)
			< math.abs(player.x - mx) + math.abs(player.y - my) then
			player = p
		end
	end
	
	return player
end


function monster_hit(mnum, damage)
	local monster = maps[current_map].monsters[mnum]
	
	if monster ~= nil then
		monster.washit = 1
		monster.hp = monster.hp - damage
		if monster.hp <= 0 then
			monster_delete(mnum)
		end
	end
end


function monster_delete(mnum)
	local grid

	grid = maps[current_map].monstergrid
	for y = 1,#grid do
		for x = 1,#(grid[y]) do
			if grid[y][x] == mnum then
				grid[y][x] = 0
			end
		end
	end
	grid = maps[current_map].monstergrid2
	for y = 1,#grid do
		for x = 1,#(grid[y]) do
			if grid[y][x] == mnum then
				grid[y][x] = 0
			end
		end
	end
	maps[current_map].monsters[mnum] = nil
end


function generate_monster(gen)
	-- transform tile coords into grid coords
	local gx = (gen.x * 2) - 2
	local gy = (gen.y * 2) - 2

	local map = maps[current_map]
	local grid = map.monstergrid2
	
	-- above
	if grid[gy-1][gx] == 0 and grid[gy-1][gx+1] == 0 and
		grid[gy-2][gx] == 0 and grid[gy-2][gx+1] == 0 and
		passable[map_cell(gen.x, gen.y-1)] then
		create_monster(map, generatortypes[gen.type].generates, gx, gy-2, true)
		return
	end

	-- below
	if grid[gy+2][gx] == 0 and grid[gy+2][gx+1] == 0 and
		grid[gy+3][gx] == 0 and grid[gy+3][gx+1] == 0 and
		passable[map_cell(gen.x, gen.y+1)] then
		create_monster(map, generatortypes[gen.type].generates, gx, gy+2, true)
		return
	end

	-- left
	if grid[gy][gx-1] == 0 and grid[gy+1][gx-1] == 0 and
		grid[gy][gx-2] == 0 and grid[gy+1][gx-2] == 0 and
		passable[map_cell(gen.x-1, gen.y)] then
		create_monster(map, generatortypes[gen.type].generates, gx-2, gy, true)
		return
	end

	-- right
	if grid[gy][gx+2] == 0 and grid[gy+1][gx+2] == 0 and
		grid[gy][gx+3] == 0 and grid[gy+1][gx+3] == 0 and
		passable[map_cell(gen.x+1, gen.y)] then
		create_monster(map, generatortypes[gen.type].generates, gx+2, gy, true)
		return
	end

	-- above & left
	if grid[gy-1][gx-2] == 0 and grid[gy-1][gx-1] == 0 and
		grid[gy-2][gx-2] == 0 and grid[gy-2][gx-1] == 0 and
		passable[map_cell(gen.x-1, gen.y-1)] then
		create_monster(map, generatortypes[gen.type].generates, gx-2, gy-2, true)
		return
	end

	-- below & right
	if grid[gy+2][gx+2] == 0 and grid[gy+2][gx+3] == 0 and
		grid[gy+3][gx+2] == 0 and grid[gy+3][gx+3] == 0 and
		passable[map_cell(gen.x+1, gen.y+1)] then
		create_monster(map, generatortypes[gen.type].generates, gx+2, gy+2, true)
		return
	end

	-- above & right
	if grid[gy-1][gx+2] == 0 and grid[gy-1][gx+3] == 0 and
		grid[gy-2][gx+2] == 0 and grid[gy-2][gx+3] == 0 and
		passable[map_cell(gen.x+1, gen.y-1)] then
		create_monster(map, generatortypes[gen.type].generates, gx+2, gy-2, true)
		return
	end

end




function monster_can_pass(monster,map)
	-- offset?
	local ox = 1
	local oy = 1

	if monster.dx == 0 and monster.dy == 0 then
		return false
	end

	-- must check these 3 new grid cells
	local g = { [1] = nil, [2] = nil, [3] = nil }

	if monster.dy == -1 then
		if monster.dx == -1 then
			g[1] = { x = ox+monster.x - 1,	y = oy+monster.y - 1 }
			g[2] = { x = ox+monster.x,		y = oy+monster.y - 1 }
			g[3] = { x = ox+monster.x - 1,	y = oy+monster.y }
		elseif monster.dx == 0 then
			g[1] = { x = ox+monster.x,		y = oy+monster.y - 1 }
			g[2] = { x = ox+monster.x + 1,	y = oy+monster.y - 1 }
		elseif monster.dx == 1 then
			g[1] = { x = ox+monster.x + 2,	y = oy+monster.y - 1 }
			g[2] = { x = ox+monster.x + 1,	y = oy+monster.y - 1 }
			g[3] = { x = ox+monster.x + 2,	y = oy+monster.y }
		end
	elseif monster.dy == 0 then
		if monster.dx == -1 then
			g[1] = { x = ox+monster.x - 1,	y = oy+monster.y }
			g[2] = { x = ox+monster.x - 1,	y = oy+monster.y + 1 }
		elseif monster.dx == 0 then
			-- Hm?
		elseif monster.dx == 1 then
			g[1] = { x = ox+monster.x + 2,	y = oy+monster.y }
			g[2] = { x = ox+monster.x + 2,	y = oy+monster.y + 1 }
		end
	elseif monster.dy == 1 then
		if monster.dx == -1 then
			g[1] = { x = ox+monster.x - 1,	y = oy+monster.y + 2 }
			g[2] = { x = ox+monster.x - 1,	y = oy+monster.y + 1 }
			g[3] = { x = ox+monster.x,		y = oy+monster.y + 2 }
		elseif monster.dx == 0 then
			g[1] = { x = ox+monster.x,		y = oy+monster.y + 2 }
			g[2] = { x = ox+monster.x + 1,	y = oy+monster.y + 2 }
		elseif monster.dx == 1 then
			g[1] = { x = ox+monster.x + 2,	y = oy+monster.y + 2 }
			g[2] = { x = ox+monster.x + 2,	y = oy+monster.y + 1 }
			g[3] = { x = ox+monster.x + 1,	y = oy+monster.y + 2 }
		end
	end

	-- now we need to know the tiles every one of those grid cells fall in.
	local t = { [1] = nil, [2] = nil, [3] = nil }

	for i = 1,3 do
		if g[i] ~= nil then
			t[i] = {
				x = math.ceil( g[i].x / 2 ),
				y = math.ceil( g[i].y / 2 )
				}
		end
	end
	
	-- finally, we check if each of these tiles is passable.
	local result = true
	for i = 1,3 do
		if t[i] ~= nil then
			result = result and passable[ string.byte(map.cell[t[i].y], t[i].x) ]
		end
	end

	return result
end

