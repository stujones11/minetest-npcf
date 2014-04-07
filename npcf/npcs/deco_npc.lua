local WALKING_SPEED = 1
local RUNNING_SPEED = 2.5
local FOLLOW_RADIUS_MIN = 5
local FOLLOW_RADIUS_MAX = 30
local AVOIDED_NODES = {
	"ignore",
	"default:water_source",
	"default:water_flowing",
	"default:lava_source",
	"default:lava_flowing",
}
local ANIMATION = {
	["Stand"] = {id=1, state=NPCF_ANIM_STAND},
	["Sit"] = {id=2, state=NPCF_ANIM_SIT},
	["Lay"] = {id=3, state=NPCF_ANIM_LAY},
	["Mine"] = {id=4, state=NPCF_ANIM_MINE},
}

local function get_target_player(self)
	local target_player = nil
	local min_dist = FOLLOW_RADIUS_MAX
	for _,player in ipairs(minetest.get_connected_players()) do
		if player then
			local pos = player:getpos()
			if pos then
				local dist = vector.distance(pos, pos)
				if dist < min_dist then
					target_player = player
					min_dist = dist
				end
			end
		end
	end
	return target_player
end

npcf:register_npc("npcf:deco_npc" ,{
	description = "Decorative NPC",
	mesh = "npcf_deco.x",
	textures = {"npcf_skin_deco.png"},
	nametag_color = "magenta",
	animation_speed = 12,
	animation = {
		stand_START = 0,
		stand_END = 79,
		sit_START = 81,
		sit_END = 160,
		lay_START = 162,
		lay_END = 166,
		walk_START = 168,
		walk_END = 187,
		mine_START = 189,
		mine_END = 198,
		run_START = 221,
		run_END = 240,
	},
	metadata = {
		free_roaming = "false",
		follow_players = "false",
		anim_stop = "Stand",
	},
	var = {
		speed = 1,
		avoid_dir = 1,
		last_pos = {x=0,y=0,z=0},
		target = nil,
	},
	stepheight = 1,
	inventory_image = "npcf_inv_deco_npc.png",
	on_construct = function(self)
		self.object:setvelocity({x=0, y=0, z=0})
		self.object:setacceleration({x=0, y=-10, z=0})
		npcf:set_animation(self, ANIMATION[self.metadata.anim_stop].state)
	end,
	on_activate = function(self, staticdata, dtime_s)

		-- Deal with legacy errors where these fields sometimes had
		-- invalid values...
		if self.metadata.follow_players == true then
			self.metadata.follow_players = "true"
		elseif self.metadata.follow_players == false then
			self.metadata.follow_players = "false"
		end
		if self.metadata.free_roaming == true then
			self.metadata.free_roaming = "true"
		elseif self.metadata.free_roaming == false then
			self.metadata.free_roaming = "false"
		end

		if self.metadata.follow_players == "true" then
			self.var.target = get_target_player(self)
		end
	end,
	on_rightclick = function(self, clicker)
		local player_name = clicker:get_player_name()
		local message = "Hello, my name is "..self.npc_name
		if self.metadata.message then
			message = minetest.formspec_escape(self.metadata.message)
		end
		local formspec
		if player_name == self.owner then
			local selected_id = ANIMATION[self.metadata.anim_stop].id or ""
 			formspec = "size[8,4.0]"
				.."field[0.5,1.0;7.5,0.5;message;Message;"..message.."]"
				.."label[0.5,1.8;Stationary Animation\\:]"
				.."dropdown[4.0,1.8;3.5;anim_stop;Stand,Sit,Lay,Mine;"..selected_id.."]"
				.."checkbox[0.5,2.7;follow_players;Follow Players;"..self.metadata.follow_players.."]"
				.."button_exit[7.0,3.5;1.0,0.5;;Ok]"
			if NPCF_DECO_FREE_ROAMING == true then
				formspec = formspec.."checkbox[3.5,2.7;free_roaming;Wander Map;"..self.metadata.free_roaming.."]"
			end
		else
			formspec = "size[8,4]"
				.."label[0,0;"..message.."]"
		end
		self.var.speed = 0
		npcf:show_formspec(player_name, self.npc_name, formspec)
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
			local roaming = NPCF_DECO_FREE_ROAMING == true and self.metadata.free_roaming == "true"
			if roaming == true or self.metadata.follow_players == "true" then
				speed = self.var.speed
				if math.random(10) == 1 then
					if speed == 0 or speed == RUNNING_SPEED then
						speed = WALKING_SPEED
					elseif math.random(5) == 1 then
						speed = RUNNING_SPEED
					elseif math.random(5) == 1 then
						speed = 0
					end
				elseif math.random(30) == 1 then
					self.var.avoid_dir = self.var.avoid_dir * -1
				end
				if self.metadata.follow_players == "true" then
					local valid_target = false
					if self.var.target then
						local target = self.var.target:getpos()
						if target then
							valid_target = true
							yaw = npcf:get_face_direction(pos, target)
							if vector.distance(pos, target) < FOLLOW_RADIUS_MIN then
								speed = 0
							end
						end
					end
					if math.random(10) == 1 or valid_target == false then
						self.var.target = get_target_player(self)
					end
				end
				if speed ~= 0 then
					local node_pos = vector.add(npcf:get_walk_velocity(5, 0, yaw), pos)
					node_pos = vector.round(node_pos)
					local air_content = 0
					for i = 1,5 do
						local test_pos = {x=node_pos.x, y=node_pos.y-i, z=node_pos.z}
						local node = minetest.get_node(test_pos)
						if node.name == "air" then
							air_content = air_content + 1
						end
						for _,v in ipairs(AVOIDED_NODES) do
							if node.name == v then
								turn = true
								break
							end
						end
					end
					if turn == false then
						local objects = minetest.get_objects_inside_radius(node_pos, 2)
						if #objects > 0 then
							turn = true
						end
					end
					if turn == true or air_content == 5 then
						yaw = yaw + math.pi	* 0.5 * self.var.avoid_dir
						speed = WALKING_SPEED
					elseif pos.x == self.var.last_pos.x or pos.z == self.var.last_pos.z then
						yaw = yaw + math.pi	* 0.25 * self.var.avoid_dir
					end
					if roaming == true then
						if math.random(4) == 1 then
							yaw = yaw + (math.random(3) - 2) * 0.25
						end
					elseif self.var.target == nil then
						speed = 0
					end
				end
				self.var.speed = speed
				self.object:setyaw(yaw)
			end
			self.var.last_pos = pos
			if speed == 0 then
				npcf:set_animation(self, ANIMATION[self.metadata.anim_stop].state)
			elseif speed == RUNNING_SPEED then
				self.object:set_animation({x=self.animation.run_START, y=self.animation.run_END}, 20)
				self.state = 0
			else
				npcf:set_animation(self, NPCF_ANIM_WALK)
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
	on_receive_fields = function(self, fields, sender)
		if fields.free_roaming or fields.follow_players then
			self.var.speed = WALKING_SPEED
		end
	end,
})

