local anim8 = require 'anim8' -- https://github.com/kikito/anim8
local inspect = require 'inspect'


local Grid = require ("jumper.grid") -- https://github.com/Yonaba/Jumper
local Pathfinder = require ("jumper.pathfinder")

local Camera = require("camera") -- https://github.com/vrld/hump

require "TEsound" -- https://dl.dropboxusercontent.com/u/3713769/web/Love/TLTools/TEsound.lua

debug_output = ""

function pick_random(tabl)
	newtabl = {}
	for key, value in pairs(tabl) do
		newtabl[#newtabl + 1] = value
	end
	return newtabl[math.floor(math.random() * #newtabl + 1)]
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function newImage(path)
	image = love.graphics.newImage(path)
	image:setFilter("linear","nearest")
	return image
end
function newMob(image) 
	local g = anim8.newGrid(image:getWidth() / 3, image:getHeight() / 4, image:getWidth(), image:getHeight())
	mob = {
		ANIMS = {
			DOWN = anim8.newAnimation(g('1-3',1), 0.2),
			DOWN_STILL = anim8.newAnimation(g('2-2',1), 1),

			LEFT = anim8.newAnimation(g('1-3',2), 0.2),
			LEFT_STILL = anim8.newAnimation(g('1-1',2), 1),

			RIGHT = anim8.newAnimation(g('1-3',3), 0.2),
			RIGHT_STILL = anim8.newAnimation(g('1-1',3), 1),

			UP = anim8.newAnimation(g('1-3',4), 0.2),
			UP_STILL = anim8.newAnimation(g('2-2',4), 1),
		}
	}
	return mob
end

IMAGE_TILE = newImage("tile.png")
IMAGE_GRASS = newImage("grass.png")
IMAGE_WALL_HOLE = newImage("wall_hole.png")
IMAGE_WALL = newImage("wall.png")
IMAGE_WALL_HORIZ = newImage("wall_horiz.png")
IMAGE_TILE_CLUB = newImage("tile_club.png")
IMAGE_CARPET = newImage("carpet.png")
IMAGE_CARPET_PATH = newImage("carpet_path.png")

IMAGE_DOOR = newImage("door.png")

IMAGE_COUNTER = newImage("counter.png")
IMAGE_FREEZER = newImage("freezer.png")
IMAGE_BURNER = newImage("burner.png")

IMAGE_TABLE_2X2 = newImage("table_2x2.png")

-- http://opengameart.org/content/rat-and-rat-king-overworld-antifarea-style
IMAGE_PLAYER = newImage("rat_player.png")
MOB_PLAYER = newMob(IMAGE_PLAYER)

IMAGE_INVENTORY_ICON = newImage("inventory_icon.png")
IMAGE_SPACE_TEXT = newImage("space_text.png")
IMAGE_ORDER_BUBBLE = newImage("order_bubble.png")

IMAGE_GAME_OVER = newImage("game_over.png")
g = anim8.newGrid(IMAGE_GAME_OVER:getWidth(), IMAGE_GAME_OVER:getHeight() / 9, IMAGE_GAME_OVER:getWidth(), IMAGE_GAME_OVER:getHeight())
ANIM_GAME_OVER = anim8.newAnimation(g(1,1,1,2,1,3,1,4,1,5,1,5,1,5,1,6,1,7,1,8,1,9,1,9,1,9,1,9,1,9,1,9,1,9,1,9,1,9), 0.175)

-- http://opengameart.org/content/food-items-from-crosstown-smash
IMAGE_FOOD = newImage("food.png")
g = anim8.newGrid(32, 32, IMAGE_FOOD:getWidth(), IMAGE_FOOD:getHeight())
FOOD = {
	MEAL = {
		DRUMSTICK = anim8.newAnimation(g("1-1", 1), 1),
		BURGER = anim8.newAnimation(g("2-2", 1), 1),
		ONION_RINGS = anim8.newAnimation(g("3-3", 1), 1),
		TACO = anim8.newAnimation(g("4-4", 1), 1),
	},
	INGREDIENT = { 
		ONION = anim8.newAnimation(g("1-1", 2), 1),
		POATATO = anim8.newAnimation(g("2-2", 2), 1),
		CARROT = anim8.newAnimation(g("3-3", 2), 1),
		TOMATO = anim8.newAnimation(g("4-4", 2), 1),
	},
}

IMAGE_CHEF_MALE = newImage("chef_male.png")
MOB_CHEF_MALE = newMob(IMAGE_CHEF_MALE)

IMAGE_CUSTOMER_1 = newImage("rat.png")
MOB_CUSTOMER_1 = newMob(IMAGE_CUSTOMER_1)

IMAGE_FROWN = newImage("frown.png")
IMAGE_SMILEY = newImage("smiley.png")
IMAGE_ALERTA = newImage("alerta.png")
IMAGE_LOST = newImage("lost.png")

LIST_COUNTERS = {{x=6, y=4}, {x=14, y=4}, {x=22, y=4}}
LIST_BURNERS  = {{x=6, y=8}, {x=14, y=8}, {x=6, y=16}}
LIST_FREEZERS = {{x=6, y=12}, {x=14, y=12}, {x=14, y=16}}

keysdown = {}
PLAYER = { x=31, y=15, anim=MOB_PLAYER.ANIMS.LEFT_STILL, speed = 5, inventory = nil }

LIST_CHEFS = {
	{ x=7, y=7, mob=MOB_CHEF_MALE, image=IMAGE_CHEF_MALE, anim=MOB_CHEF_MALE.ANIMS.DOWN_STILL, speed=3, alerted=false},
	{ x=10, y=16, mob=MOB_CHEF_MALE, image=IMAGE_CHEF_MALE, anim=MOB_CHEF_MALE.ANIMS.DOWN_STILL, speed=3, alerted=false},
	{ x=17, y=13, mob=MOB_CHEF_MALE, image=IMAGE_CHEF_MALE, anim=MOB_CHEF_MALE.ANIMS.DOWN_STILL, speed=3, alerted=false},
}
LIST_TABLES = {
	{ x = 33, y = 17 },
	{ x = 33, y = 12 },
	{ x = 38, y = 17 },
	{ x = 38, y = 12 },
}
LIST_CUSTOMERS = {
}

PATHFINDER = nil
PATHFINDER_GRID = nil
CAMERA = nil

score = 0

game_over = false
game_over_time = 0
played_slice_sound = false

function findPath(startX, startY, endX, endY) 
	local path = PATHFINDER:getPath(round(startY), round(startX), round(endY), round(endX))
	if path then
		--debug_output = ('Path found! Length: %.2f'):format(path:getLength())
		for node, count in path:nodes() do
			--debug_output = debug_output .. "\n" .. ('Step: %d - x: %d - y: %d'):format(count, node:getX(), node:getY())
			if count == 2 then
				return node:getY(), node:getX()
			end
		end
	end
end


function love.load()
	font = love.graphics.newImageFont("font.png",
	    " abcdefghijklmnopqrstuvwxyz" ..
	    "ABCDEFGHIJKLMNOPQRSTUVWXYZ0" ..
	    "123456789.,!?-+/():;%&`'*#=[]\"")
	love.graphics.setFont(font)
	TEsound.playLooping("Sevilla.wav", "music")
	CAMERA = Camera(PLAYER.x * 16, PLAYER.y * 16, 1)
	PATHFINDER_GRID = {}
	for x=0,50 do
		PATHFINDER_GRID[x] = {}
		for y=0,34 do
			PATHFINDER_GRID[x][y] = 0
    		if x >= 4 and x <= 30 and y >= 4 and y <= 20 then
    			PATHFINDER_GRID[x][y] = 0
    			for _,counter in ipairs(LIST_COUNTERS) do
    				if (y == counter.y or y == counter.y + 1) and x >= counter.x - 0 and x < counter.x + 6 then
    					PATHFINDER_GRID[x][y] = 1
    				end
    			end
    			for _,counter in ipairs(LIST_BURNERS) do
    				if (y == counter.y or y == counter.y + 1) and x >= counter.x - 0 and x < counter.x + 6 then
    					PATHFINDER_GRID[x][y] = 1
    				end
    			end
    			for _,counter in ipairs(LIST_FREEZERS) do
    				if (y == counter.y or y == counter.y + 1) and x >= counter.x - 0 and x < counter.x + 6 then
    					PATHFINDER_GRID[x][y] = 1
    				end
    			end
    		else
    			if x == 31 and y == 15 then
    				PATHFINDER_GRID[x][y] = 0
    			elseif x >= 32 and x <= 42 and y >= 8 and y <= 25 then
    				PATHFINDER_GRID[x][y] = 0
    			else
    				PATHFINDER_GRID[x][y] = 1
    			end
    		end
		end
	end
	grid = Grid(PATHFINDER_GRID) 
	PATHFINDER = Pathfinder(grid, 'ASTAR', 0)
end

function getClosestFoodItem()
	closestFoodItem = nil
	closestFoodDistance = 1.55
	closestFoodPosX = 0
	closestFoodPosY = 0
	closestFoodCounter = nil
	closestFoodPos = 0
	for _, counter in pairs(LIST_COUNTERS) do
		if counter.food ~= nil then
			for pos, food in pairs(counter.food) do
				realPosX = pos / 16 + counter.x + 1
				realPosY = counter.y - 6 / 16 + 1
				distance = math.sqrt(math.pow(realPosX - PLAYER.x, 2) + math.pow(realPosY - PLAYER.y, 2))
				if distance <= closestFoodDistance then
					closestFoodDistance = distance
					closestFoodItem = food
					closestFoodPosX = realPosX
					closestFoodPosY = realPosY
					closestFoodPos = pos
					closestFoodCounter = counter
				end
			end
		end
	end
	for _, counter in pairs(LIST_BURNERS) do
		if counter.food ~= nil then
			for pos, food in pairs(counter.food) do
				realPosX = pos / 16 + counter.x + 1
				realPosY = counter.y - 6 / 16 + 1
				distance = math.sqrt(math.pow(realPosX - PLAYER.x, 2) + math.pow(realPosY - PLAYER.y, 2))
				if distance <= closestFoodDistance then
					closestFoodDistance = distance
					closestFoodItem = food
					closestFoodPosX = realPosX
					closestFoodPosY = realPosY
					closestFoodPos = pos
					closestFoodCounter = counter
				end
			end
		end
	end
	for _, counter in pairs(LIST_FREEZERS) do
		if counter.food ~= nil then
			for pos, food in pairs(counter.food) do
				realPosX = pos / 16 + counter.x + 1
				realPosY = counter.y - 6 / 16 + 1
				distance = math.sqrt(math.pow(realPosX - PLAYER.x, 2) + math.pow(realPosY - PLAYER.y, 2))
				if distance <= closestFoodDistance then
					closestFoodDistance = distance
					closestFoodItem = food
					closestFoodPosX = realPosX
					closestFoodPosY = realPosY
					closestFoodPos = pos
					closestFoodCounter = counter
				end
			end
		end
	end
	return closestFoodPosX, closestFoodPosY, closestFoodItem, closestFoodCounter, closestFoodPos
end

local timeSinceCustomer = 10

function love.update(dt)
	TEsound.cleanup()
	if not game_over then
		for _, chef in pairs(LIST_CHEFS) do
			local targetX, targetY
			if chef.doThing == nil then chef.doThing = 0.25 end
			distance_to_player = math.sqrt(math.pow(PLAYER.x - chef.x, 2) + math.pow(PLAYER.y - chef.y, 2))
			if chef.notification_time == nil then chef.notification_time = 0 end
			if chef.notification_time > 0 then
				chef.notification_time = chef.notification_time - dt
				if chef.notification_time < 0 then
					chef.notification_time = nil
					chef.notification = nil
				end
			end
			if distance_to_player < 0.4 then
				game_over = true
				game_over_time = dt
				TEsound.play({"GameOver.wav"})
				TEsound.stop("music")
				chef.hidden = true
			end
			if PLAYER.x >= 31 then
				if chef.alerted then
					TEsound.play({"ChefLost1.wav", "ChefLost2.wav"})
					chef.target_counter = nil
					chef.target_food_position = nil
					chef.hasJob = false
					chef.doThing = 1.5 + math.random() / 2
					chef.notification = IMAGE_LOST
					chef.notification_time = 2
				end
				chef.alerted = false
			end
			if chef.doThing and PLAYER.x < 31 and distance_to_player < 6 then
				chef.doThing = 0
				chef.target_counter = nil
				chef.target_food_position = nil
			end
			if chef.alerted then
				chef.doThing = 0
			end
			if chef.doThing > 0 then
				chef.doThing = chef.doThing - dt
				chef.anim = chef.mob.ANIMS.UP_STILL
			else
				if chef.hasJob and chef.x == chef.targetX and chef.y == chef.targetY then
					chef.hasJob = false
					if chef.target_counter ~= nil and chef.target_food_position ~= nil then
						if chef.target_counter.food == nil then chef.target_counter.food = {} end
						chef.target_counter.food[chef.target_food_position] = pick_random(FOOD.INGREDIENT)
					end
					chef.doThing = 3 + math.random() * 3
				end
				if PLAYER.x < 31 and (distance_to_player < 6 or chef.alerted) then
					if not chef.alerted then
						TEsound.play({"ChefAlert1.wav", "ChefAlert2.wav"})
						chef.notification = IMAGE_ALERTA
						chef.notification_time = 1.5
					end
					chef.alerted = true
					chef.hasJob = false
					chef.doThing = 0
					targetX, targetY = findPath(chef.x, chef.y, PLAYER.x, PLAYER.y)
				elseif not chef.hasJob and not chef.alerted then
					target_counter_list = LIST_FREEZERS
					random_counter = math.random()
					if random_counter < 0.33 then
						target_counter_list = LIST_COUNTERS
					elseif random_counter < 0.66 then
						target_counter_list = LIST_BURNERS
					end
					target_counter = pick_random(target_counter_list)
					positions = {
						{x = target_counter.x + 6 / 4 * 1 - 6 / 4 * 0.5, y = target_counter.y + 2},
						{x = target_counter.x + 6 / 4 * 2 - 6 / 4 * 0.5, y = target_counter.y + 2},
						{x = target_counter.x + 6 / 4 * 2 - 6 / 4 * 0.5, y = target_counter.y + 2},
						{x = target_counter.x + 6 / 4 * 4 - 6 / 4 * 0.5, y = target_counter.y + 2},
					}
					position = positions[math.floor(math.random() * #positions) + 1]
					chef.target_counter = target_counter
					chef.target_food_position = (position.x - target_counter.x) * 16 - 18
					targetX, targetY = findPath(chef.x, chef.y, position.x, position.y)
					chef.targetX, chef.targetY = position.x, position.y
					chef.hasJob = true
				else 
					targetX, targetY = findPath(chef.x, chef.y, chef.targetX, chef.targetY)
				end
				if distance_to_player < 1 then
					targetX = PLAYER.x
					targetY = PLAYER.y
				end
				distance_to_target = math.sqrt(math.pow(chef.x - chef.targetX, 2) + math.pow(chef.y - chef.targetY, 2))
				if chef.hasJob and distance_to_target < 1 then
					targetX = chef.targetX
					targetY = chef.targetY
				end
				if distance_to_target < 0.15 then
					chef.x = chef.targetX
					chef.y = chef.targetY
				end
				if targetX ~= nil and targetY ~= nil then
					if chef.y > targetY then
						chef.y = chef.y - chef.speed * dt
						if chef.y < targetY then 
							chef.y = targetY
						end
						chef.anim = chef.mob.ANIMS.UP
					end
					if chef.y < targetY then
						chef.y = chef.y + chef.speed * dt
						if chef.y > targetY then 
							chef.y = targetY
						end
						chef.anim = chef.mob.ANIMS.DOWN
					end
					if chef.x > targetX then
						chef.x = chef.x - chef.speed * dt
						if chef.x < targetX then 
							chef.x = targetX
						end
						chef.anim = chef.mob.ANIMS.LEFT
					end
					if chef.x < targetX then
						chef.x = chef.x + chef.speed * dt
						if chef.x > targetX then 
							chef.x = targetX
						end
						chef.anim = chef.mob.ANIMS.RIGHT
					end
				end
			end
		end
		timeSinceCustomer = timeSinceCustomer + dt
		if 8 + math.random() * 150 + math.random() * 10 < timeSinceCustomer then
			customer_slot = math.floor(math.random() * 16) + 1

			if LIST_CUSTOMERS[customer_slot] == nil then
				customer_x = 0
				if customer_slot < 4 then 
					customer_x = 33
					target_x = 34
				elseif customer_slot < 12 then
					if customer_slot < 8 then
						target_x = 37
					else
						target_x = 39
					end
					customer_x = 38 
				else 
					customer_x = 43 
					target_x = 42
				end
				if customer_slot % 4 == 1 then 
					target_y = 19 
				elseif customer_slot % 4 == 2 then 
					target_y = 18 
				elseif customer_slot % 4 == 3 then 
					target_y = 14
				else 
					target_y = 13 
				end
				LIST_CUSTOMERS[customer_slot] = {
					mob = MOB_CUSTOMER_1,
					image = IMAGE_CUSTOMER_1,
					anim = MOB_CUSTOMER_1.ANIMS.UP,
					x = customer_x - 0.5,
					y = 44,
					path_x = customer_x - 0.5,
					target_y = target_y - 0.5,
					target_x = target_x - 0.5,
				}
				timeSinceCustomer = 0
			end
		end
		for _,anim in pairs(MOB_PLAYER.ANIMS) do
			anim:update(dt)
		end
		for _,anim in pairs(MOB_CHEF_MALE.ANIMS) do
			anim:update(dt)
		end
		for _,anim in pairs(MOB_CUSTOMER_1.ANIMS) do
			anim:update(dt)
		end
		for i, customer in pairs(LIST_CUSTOMERS) do
			if customer.notification_time == nil then customer.notification_time = 0 end
			if customer.notification_time > 0 then
				customer.notification_time = customer.notification_time - dt
				if customer.notification_time < 0 then
					customer.notification_time = nil
					customer.notification = nil
				end
			end
			if customer.order ~= nil then
				if customer.waitTime == nil then customer.waitTime = 0 end
				customer.waitTime = customer.waitTime + dt
				if customer.waitTime >= 60 then
					TEsound.play("LeaveAngry.wav")
					score = score - 15
					customer.eating = 0.001
					customer.order = nil
					customer.notification = IMAGE_FROWN
					customer.notification_time = 100
				end
			end
			if customer.y ~= customer.target_y then
				if customer.y < customer.target_y then
					customer.y = customer.y + dt * 6
					customer.anim = customer.mob.ANIMS.DOWN
					if customer.y > customer.target_y then 
						LIST_CUSTOMERS[i] = nil
					end
				else
					customer.y = customer.y - dt * 6
					customer.anim = customer.mob.ANIMS.UP
					if customer.y < customer.target_y then 
						customer.y = customer.target_y 
					end
				end
			elseif customer.x ~= customer.target_x then
				if customer.x > customer.target_x then 
					customer.anim = customer.mob.ANIMS.LEFT 
					customer.x = customer.x - dt * 6
					if customer.x < customer.target_x then 
						customer.x = customer.target_x
						if customer.leaving then
							customer.target_y = 44
						end
					end
				end
				if customer.x < customer.target_x then 
					customer.anim = customer.mob.ANIMS.RIGHT
					customer.x = customer.x + dt * 6 
					if customer.x > customer.target_x then 
						customer.x = customer.target_x
						if customer.leaving then
							customer.target_y = 44
						end
					end
				end
			else
				if customer.anim == customer.mob.ANIMS.LEFT then customer.anim = customer.mob.ANIMS.LEFT_STILL end
				if customer.anim == customer.mob.ANIMS.RIGHT then customer.anim = customer.mob.ANIMS.RIGHT_STILL end
				if customer.order == nil then
					customer.order = pick_random(FOOD.INGREDIENT)
				end
				if customer.eating == nil then customer.eating = 0 end
				if customer.eating > 0 then
					customer.eating = customer.eating - dt
					customer.order = nil
					if customer.eating <= 0 then
						customer.leaving = true
						customer.target_x = customer.path_x
					end
				end
				if PLAYER.inventory == customer.order and PLAYER.inventory ~= nil then
					distance = math.sqrt(math.pow(PLAYER.x - customer.x, 2) + math.pow(PLAYER.y - customer.y, 2))
					if distance < 1.5 then
						PLAYER.inventory = nil
						customer.eating = 5
						score = score + 10
						customer.notification = IMAGE_SMILEY
						customer.notification_time = 2
						TEsound.play({"Coin1.wav", "Coin2.wav", "Coin3.wav", "Coin4.wav", "Coin5.wav", "Coin6.wav"})
					end
				end
			end
		end
		if PLAYER.anim == MOB_PLAYER.ANIMS.UP then
			PLAYER.y = PLAYER.y - dt * PLAYER.speed
		elseif PLAYER.anim == MOB_PLAYER.ANIMS.DOWN then
			PLAYER.y = PLAYER.y + dt * PLAYER.speed
		elseif PLAYER.anim == MOB_PLAYER.ANIMS.LEFT then
			PLAYER.x = PLAYER.x - dt * PLAYER.speed
		elseif PLAYER.anim == MOB_PLAYER.ANIMS.RIGHT then
			PLAYER.x = PLAYER.x + dt * PLAYER.speed
		end
		while PATHFINDER_GRID[round(PLAYER.x)][round(PLAYER.y)] == 1 do
			if PLAYER.anim == MOB_PLAYER.ANIMS.UP then
				PLAYER.y = PLAYER.y - dt * PLAYER.speed / -10
			elseif PLAYER.anim == MOB_PLAYER.ANIMS.DOWN then
				PLAYER.y = PLAYER.y + dt * PLAYER.speed / -10
			elseif PLAYER.anim == MOB_PLAYER.ANIMS.LEFT then
				PLAYER.x = PLAYER.x - dt * PLAYER.speed / -10
			elseif PLAYER.anim == MOB_PLAYER.ANIMS.RIGHT then
				PLAYER.x = PLAYER.x + dt * PLAYER.speed / -10
			end
		end
	else
		game_over_time = game_over_time + dt
		if game_over_time >= 1.4 and not played_slice_sound then
			played_slice_sound = true
			TEsound.play("GameOverSlice.wav")
		end
		if game_over_time > 3.3 then
			love.event.push('quit')
		end
		ANIM_GAME_OVER:update(dt)
		if CAMERA.scale < 3 then
			CAMERA:zoomTo(CAMERA.scale + 0.07)
		end
	end
    local dx,dy = PLAYER.x * 16 - CAMERA.x, PLAYER.y * 16 - CAMERA.y
    CAMERA:move(dx/20, dy/20)
end

function love.keypressed(key)
	keysdown[key] = true
	if key == 'w' then
		PLAYER.anim=MOB_PLAYER.ANIMS.UP
	elseif key == "s" then
		PLAYER.anim=MOB_PLAYER.ANIMS.DOWN
	elseif key == "a" then
		PLAYER.anim=MOB_PLAYER.ANIMS.LEFT
	elseif key == "d" then
		PLAYER.anim=MOB_PLAYER.ANIMS.RIGHT
	end
	if key == "space" then
		_,_,closestFoodItem,closestFoodCounter,closestFoodPos = getClosestFoodItem()
		if closestFoodItem ~= nil then
			if PLAYER.inventory == nil then
				PLAYER.inventory = closestFoodItem
				closestFoodCounter.food[closestFoodPos] = nil
				TEsound.play({"Pickup1.wav", "Pickup2.wav"})
			end
		end
	end
end

function love.keyreleased(key)
	keysdown[key] = nil
	shouldStop = keysdown["w"] == nil and keysdown["a"] == nil and keysdown["s"] == nil and keysdown["d"] == nil
	if shouldStop then
		if key == 'w' then
			PLAYER.anim=MOB_PLAYER.ANIMS.UP_STILL
		elseif key == "s" then
			PLAYER.anim=MOB_PLAYER.ANIMS.DOWN_STILL
		elseif key == "a" then
			PLAYER.anim=MOB_PLAYER.ANIMS.LEFT_STILL
		elseif key == "d" then
			PLAYER.anim=MOB_PLAYER.ANIMS.RIGHT_STILL
		end
	elseif key == "w" or key == "s" or key == "a" or key == "d" then
		if keysdown["w"] ~= nil then
			PLAYER.anim=MOB_PLAYER.ANIMS.UP
		elseif keysdown["s"] ~= nil then
			PLAYER.anim=MOB_PLAYER.ANIMS.DOWN
		elseif keysdown["a"] ~= nil then
			PLAYER.anim=MOB_PLAYER.ANIMS.LEFT
		elseif keysdown["d"] ~= nil then
			PLAYER.anim=MOB_PLAYER.ANIMS.RIGHT
		end
	end
end

function love.draw()
	love.graphics.push()
	CAMERA:attach()
    for i=-20,80 do
    	for j=-20,60 do
    		love.graphics.setColor(255, 255, 255, 255)
    		if i >= 4 and i <= 30 and j >= 4 and j <= 20 then
    			love.graphics.draw(IMAGE_TILE, i * 16, j * 16)
    		elseif (i == 31 or i == 3) and j >= 3 and ((i == 3 and j <= 21) or (i == 31 and j <= 60)) then
    			if j == 15 and i == 31 then
    				love.graphics.draw(IMAGE_WALL_HOLE, i * 16, j * 16)
    			else
    				love.graphics.draw(IMAGE_WALL, i * 16, j * 16)
    			end
    		elseif i >= 4 and (((i <= 23 or i >= 26) and j == 21) or j == 3) and i <= 31 then
    			love.graphics.draw(IMAGE_WALL_HORIZ, i * 16, j * 16)
    		elseif i >= 32 and i <= 42 and j >= 8 and j <= 50 then
    			love.graphics.setColor(255, 255, 255, math.min(255, 255 - (j - 25) * 16))
    			love.graphics.draw(IMAGE_TILE_CLUB, i * 16, j * 16)
    		elseif i <= 31 then
    			if j > 21 then
    				love.graphics.draw(IMAGE_CARPET, i * 16, j * 16)
    			else
    				love.graphics.draw(IMAGE_GRASS, i * 16, j * 16)
    			end
    		end
    	end
    end
    for _, counter in ipairs(LIST_COUNTERS) do
    	love.graphics.draw(IMAGE_COUNTER, counter.x * 16, counter.y * 16)
    	if counter.food ~= nil then
	    	for pos,food in pairs(counter.food) do
	    		food:draw(IMAGE_FOOD, counter.x * 16 + pos, counter.y * 16 - 6)
	    	end
	    end
    end

    for _, counter in ipairs(LIST_FREEZERS) do
    	love.graphics.draw(IMAGE_FREEZER, counter.x * 16, counter.y * 16)
    	if counter.food ~= nil then
	    	for pos,food in pairs(counter.food) do
	    		food:draw(IMAGE_FOOD, counter.x * 16 + pos, counter.y * 16 - 6)
	    	end
	    end
    end

    for _, counter in ipairs(LIST_BURNERS) do
    	love.graphics.draw(IMAGE_BURNER, counter.x * 16, counter.y * 16)
    	if counter.food ~= nil then
	    	for pos,food in pairs(counter.food) do
	    		food:draw(IMAGE_FOOD, counter.x * 16 + pos, counter.y * 16 - 6)
	    	end
	    end
    end

    for _, table in ipairs(LIST_TABLES) do
    	love.graphics.draw(IMAGE_TABLE_2X2, table.x * 16, table.y * 16)
    end

    for _, customer in pairs(LIST_CUSTOMERS) do --25, 45
    	col = math.min(255, 255 - (customer.y - 25) * 255 / 20)
    	love.graphics.setColor(col, col, col, col)
    	customer.anim:draw(customer.image, customer.x * 16 - 8, customer.y * 16 - 8)
    end
    love.graphics.setColor(255, 255, 255)

    if not game_over then
   		PLAYER.anim:draw(IMAGE_PLAYER, PLAYER.x * 16, PLAYER.y * 16 - 4)
   	end
    
    for _,chef in pairs(LIST_CHEFS) do
    	if not chef.hidden then
    		chef.anim:draw(chef.image, chef.x * 16 - 16, chef.y * 16 - 60)
    	end
    end

    love.graphics.draw(IMAGE_DOOR, 24 * 16, 18 * 16)

    --[[
    for y,set in ipairs(PATHFINDER_GRID) do
    	for x, walkable in ipairs(set) do
    		love.graphics.print(walkable, y * 16, x * 16)
    	end
    end
    ]]
    

    local closestFoodPosX, closestFoodPosY, closestFoodItem,_,_ = getClosestFoodItem()
    if closestFoodItem ~= nil then
		if PLAYER.inventory == nil then
			love.graphics.draw(IMAGE_SPACE_TEXT, closestFoodPosX * 16 - 32, closestFoodPosY * 16 - 15)
		end
    end

    for _, customer in pairs(LIST_CUSTOMERS) do 
    	if customer.order ~= nil and customer.waitTime ~= nil then
    		love.graphics.setColor(255, 255 - math.max(0, customer.waitTime - 30) * 255 / 30, 255 - math.max(0, customer.waitTime - 30) * 255 / 30)
    		love.graphics.draw(IMAGE_ORDER_BUBBLE, customer.x * 16 + 1, customer.y * 16 - 42)
    	end
    end
    love.graphics.setColor(255, 255, 255)
    for _, customer in pairs(LIST_CUSTOMERS) do
    	if customer.order ~= nil then
    		customer.order:draw(IMAGE_FOOD, customer.x * 16 + 5, customer.y * 16 - 40)
    	end
    end

    for _,chef in pairs(LIST_CHEFS) do
    	if chef.notification and chef.notification_time > 0 then
    		love.graphics.draw(chef.notification, chef.x * 16 - 16, chef.y * 16 - 90)
    	end
    end

    for _,customer in pairs(LIST_CUSTOMERS) do
    	if customer.notification and customer.notification_time > 0 then
    		love.graphics.draw(customer.notification, customer.x * 16 - 16, customer.y * 16 - 40)
    	end
    end

    if game_over then
   		ANIM_GAME_OVER:draw(IMAGE_GAME_OVER, PLAYER.x * 16 - 52, PLAYER.y * 16 - 58)
   	end

    CAMERA:detach()

    if not game_over then
		love.graphics.draw(IMAGE_INVENTORY_ICON, 0, 0)
		if PLAYER.inventory ~= nil then
			PLAYER.inventory:draw(IMAGE_FOOD, 0, 0)
		end
	end
    
    love.graphics.print(debug_output, 0, 32)

    love.graphics.printf("Score: " .. score, 0, 0, 800, 'center')
    
    love.graphics.pop()
end