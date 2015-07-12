local MAX_OBJECT_COUNT = 10
local WALKING_SPEED = 2.5
local RUNNING_SPEED = 4
local ENABLE_TNT = minetest.get_modpath("tnt") ~= nil
local ATTACK_RADIUS = NPCF_RELOAD_DISTANCE + 10
local TARGET_RADIUS = 20
local TARGET_CHANCE = 1000
local TARGET_TIME_MIN = 60
local TARGET_TIME_MAX = 300
local SPAWN_CHANCE = 3
local SPAWN_UPDATE_TIME = 4
local SPAWN_NODES = {
	"default:dirt_with_grass",
	"default:cobble",
	"default:sand",
	"default:desert_sand",
	"default:desert_stone",
}
local AVOIDED_NODES = {
	"ignore",
	"default:water_source",
	"default:water_flowing",
	"default:lava_source",
	"default:lava_flowing",
}

local spawn_timer = 0
local target_players = {}

local function get_target_player(pos)
	local target_player = nil
	local min_dist = ATTACK_RADIUS
	for _,player in ipairs(minetest.get_connected_players()) do
		if player then
			local player_pos = player:getpos()
			local hp = player:get_hp() or 0
			if player_pos and hp > 0 then
				local dist = vector.distance(pos, player_pos)
				if dist < min_dist then
					target_player = player
					min_dist = dist
				end
			end
		end
	end
	return target_player
end

local function spawn_mob(pos)
	if minetest.get_node_light(pos) < 10 then
		return
	end
	for i = 1, MAX_OBJECT_COUNT do
		local id = ":npcf_mob_"..i
		if not npcf.npcs[id] then
			local yaw = math.rad(math.random(360))
			local ref = {
				id = id,
				pos = pos,
				yaw = yaw,
				name = "npcf_mob:npc",
			}
			local npc = npcf:add_npc(ref)
			if npc then
				npc:update()
			end
			break
		end
	end
end

npcf:register_npc("npcf_mob:npc", {
	description = "Mob NPC",
	mesh = "npcf_mob.b3d",
	textures = {"npcf_mob_skin.png"},
	collisionbox = {-0.35,-1.0,-0.35, 0.35,0.5,0.35},
	animation_speed = 25,
	metadata = {
		anim_stop = "Stand",
	},
	var = {
		speed = WALKING_SPEED,
		avoid_dir = 1,
		last_pos = {x=0,y=0,z=0},
		target = nil,
	},
	stepheight = 1.1,
	register_spawner = false,
	armor_groups = {fleshy=100},
	on_update = function(npc)
		if math.random(5) == 1 then
			if not get_target_player(npc.pos) then
				if npc.object then
					npc.object:remove()
				end
				npcf.npcs[npc.id] = nil
			end
		end
	end,
	on_construct = function(self)
		self.object:setvelocity({x=0, y=0, z=0})
		self.object:setacceleration({x=0, y=-10, z=0})
	end,
	on_destruct = function(self, hitter)
		local id = self.npc_id
		if id then
			npcf.npcs[id] = nil
		end
		local pos = self.object:getpos()
		if pos then
			minetest.add_particlespawner(
				50, 1, pos, pos,
				{x=-3, y=3, z=-3}, {x=3, y=3, z=3},
				{x=-2, y=-2, z=-2}, {x=2, y=-2, z=2},
				0.1, 0.75, 2, 8, false, "npcf_mob_particle.png"
			)
			if ENABLE_TNT == true then
				pos.y = pos.y - 1
				minetest.add_node(pos, {name="tnt:tnt_burning"})
				minetest.get_node_timer(pos):start(1)
			else
				local player_pos = hitter:getpos()
				if player_pos then
					local dist = vector.distance(pos, player_pos)
					local damage = (50 * 0.5 ^ dist) * 2
					hitter:punch(self.object, 1.0, {
						full_punch_interval = 1.0,
						damage_groups = {fleshy=damage},
					})
				end
			end
		end
	end,
	on_step = function(self, dtime)
		if self.timer > 1 then
			self.timer = 0
			local speed = 0
			local pos = self.object:getpos()
			local yaw = self.object:getyaw()
			local turn = pos.x == self.var.last_pos.x and pos.z == self.var.last_pos.z
			local acceleration = {x=0, y=-10, z=0}
			local velocity = self.object:getvelocity()
			speed = self.var.speed
			if math.random(5) == 1 then
				if speed == 0 or speed == RUNNING_SPEED then
					speed = WALKING_SPEED
				elseif math.random(3) == 1 then
					speed = RUNNING_SPEED
				elseif math.random(10) == 1 then
					speed = 0
				end
			elseif math.random(30) == 1 then
				self.var.avoid_dir = self.var.avoid_dir * -1
			end
			local valid_target = false
			if self.var.target then
				local target = self.var.target:getpos()
				if target then
					valid_target = true
					yaw = npcf:get_face_direction(pos, target)
					if vector.distance(pos, target) < 2 then
						speed = 0
						self.object:punch(self.var.target, 1.0, {
							full_punch_interval = 1.0,
							damage_groups = {fleshy=20},
						})
					end
				end
			end
			if math.random(10) == 1 or valid_target == false then
				self.var.target = get_target_player(pos)
			end
			if speed ~= 0 then
				local node_pos = vector.add(npcf:get_walk_velocity(5, 0, yaw), pos)
				node_pos = vector.round(node_pos)
				local air_content = 0
				for i = 1, 5 do
					local test_pos = {x=node_pos.x, y=node_pos.y - i, z=node_pos.z}
					local node = minetest.get_node(test_pos)
					if node.name == "air" then
						air_content = air_content + 1
					end
					for _, v in ipairs(AVOIDED_NODES) do
						if node.name == v then
							turn = true
							break
						end
					end
				end
				if turn == false then
					local objects = minetest.get_objects_inside_radius(node_pos, 1)
					if #objects > 0 then
						turn = true
					end
				end
				if turn == true or air_content == 5 then
					yaw = yaw + math.pi * 0.5 * self.var.avoid_dir
					speed = WALKING_SPEED
				elseif pos.x == self.var.last_pos.x or pos.z == self.var.last_pos.z then
					yaw = yaw + math.pi * 0.25 * self.var.avoid_dir
				end
				if self.var.target == nil then
					speed = 0
				end
				self.var.speed = speed
				self.object:setyaw(yaw)
			end
			self.var.last_pos = pos
			if speed > 0 then
				npcf:set_animation(self, NPCF_ANIM_WALK)
			else
				npcf:set_animation(self, NPCF_ANIM_STAND)
			end
			local node = minetest.get_node(pos)
			if string.find(node.name, "^default:water") then
				acceleration = {x=0, y=-4, z=0}
				velocity = {x=0, y=3, z=0}
			elseif minetest.find_node_near(pos, 2, {"group:water"}) then
				acceleration = {x=0, y=-1, z=0}
			end
			self.object:setvelocity(npcf:get_walk_velocity(speed, velocity.y, yaw))
			self.object:setacceleration(acceleration)
		end
	end,
})

minetest.register_globalstep(function(dtime)
	spawn_timer = spawn_timer + dtime
	if spawn_timer > SPAWN_UPDATE_TIME then
		for _,player in ipairs(minetest.get_connected_players()) do
			if player then
				local name = player:get_player_name()
				local hp = player:get_hp() or 0
				if name and hp > 0 then
					if not target_players[name] then
						if math.random(TARGET_CHANCE) == 1 then
							local time = TARGET_TIME_MAX - TARGET_TIME_MIN
							target_players[name] = math.random(time) + TARGET_TIME_MIN
						end
					end
				end
				if target_players[name] and math.random(SPAWN_CHANCE) == 1 then
					local pos = player:getpos()
					if pos then
						local angle = math.rad(math.random(360))
						local x = pos.x + math.cos(angle) * TARGET_RADIUS
						local z = pos.z + math.sin(angle) * TARGET_RADIUS
						local p1 = {x=x, y=pos.y + TARGET_RADIUS, z=z}
						local p2 = {x=x, y=pos.y - TARGET_RADIUS, z=z}
						local res, spawn_pos = minetest.line_of_sight(p1, p2, 1)
						if spawn_pos then
							local node = minetest.get_node(spawn_pos)
							for _, v in ipairs(SPAWN_NODES) do
								if node.name == v then
									spawn_pos.y = spawn_pos.y + 1.5
									spawn_mob(spawn_pos)
									break
								end
							end
						end
					end
					target_players[name] = target_players[name] - dtime
					if target_players[name] <= 0 then
						target_players[name] = nil
					end
				end
			end
		end
		spawn_timer = 0
	end
end)

minetest.register_on_dieplayer(function(player)
	for _, npc in pairs(npcf.npcs) do
		if npc.object and npc.name == "npcf_mob:npc" then
			npc.var.target = get_target_player(npc.pos)
		end
	end
end)

