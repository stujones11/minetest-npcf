local GUARD_ATTACK_PLAYERS
local TARGET_RADIUS = 20
local MAX_SPEED = 5
local PATROL_SPEED = 2

local function get_wield_image(item)
	local wield_image = "npcf_trans.png"
	if minetest.registered_items[item] then
		if minetest.registered_items[item].inventory_image ~= "" then
			wield_image = minetest.registered_items[item].inventory_image
		end
	end
	return wield_image
end

local function get_speed(distance)
	local speed = distance * 0.5
	if speed > MAX_SPEED then
		speed = MAX_SPEED
	end
	return speed
end

local function get_name_in_list(list, name)
	list = list:gsub(",", " ")
	for k,v in ipairs(list:split(" ")) do
		if k ~= "" and v == name then
			return name
		end
	end
end

local function get_armor_texture(self)
	if self.metadata.show_armor == "true" then
		return "npcf_guard_armor.png"
	end
	return "npcf_trans.png"
end

npcf:register_npc("npcf_guard:npc", {
	description = "Guard NPC",
	mesh = "npcf_guard.b3d",
	textures = {"character.png", "npcf_guard_armor.png", "npcf_trans.png"},
	inventory_image = "npcf_guard_inv.png",
	stepheight = 1.1,
	armor_groups = {fleshy=20},
	metadata = {
		wielditem = "default:sword_steel",
		blacklist = "npcf_mob:npc",
		whitelist = "",
		attack_players = "false",
		follow_owner = "false",
		patrol = "false",
		patrol_points = {},
		patrol_index = 0,
		patrol_rest = 2,
		show_armor = "true",
	},
	var = {
		rest_timer = 0,
	},
	get_formspec = function(self)
		local blacklist = minetest.formspec_escape(self.metadata.blacklist)
		local whitelist = minetest.formspec_escape(self.metadata.whitelist)
		local formspec = "size[8,8.5]"
			.."field[0.5,1.0;3.5,0.5;wielditem;Weapon;"..self.metadata.wielditem.."]"
			.."checkbox[4.0,0.5;show_armor;Show 3D Armor;"..self.metadata.show_armor.."]"
			.."field[0.5,2.5;7.5.0,0.5;blacklist;Blacklist (Mob Entities);"..blacklist.."]"
			.."field[0.5,4.0;7.5.0,0.5;whitelist;Whitelist (Player Names);"..whitelist.."]"
			.."checkbox[0.5,4.5;follow_owner;Follow;"..self.metadata.follow_owner.."]"
			.."checkbox[3.5,4.5;patrol;Patrol;"..self.metadata.patrol.."]"
			.."field[6.0,5.5;2.0.0,0.5;rest_time;Rest (sec);"..self.metadata.patrol_rest.."]"
			.."label[0.5,6.5;Patrol Points: "..#self.metadata.patrol_points.."]"
			.."button[5.5,6.5;2.5,0.5;add_patrol;Add Point]"
			.."button[3.5,6.5;2.0,0.5;clear_patrol;Clear]"
			.."button[0.0,8.0;2.0,0.5;origin;Set Origin]"
			.."button_exit[7.0,8.0;1.0,0.5;;Ok]"
		if GUARD_ATTACK_PLAYERS == true then
			formspec = formspec.."checkbox[4.0,4.5;attack_players;Attack Players;"
				..self.metadata.attack_players.."]"
		end
		return formspec
	end,
	on_destruct = function(self, hitter)
	   if self.npc_id then
		  npcf:unload(self.npc_id)
	   end
	end,
	on_activate = function(self)
		self.object:setvelocity({x=0, y=0, z=0})
		self.object:setacceleration({x=0, y=-10, z=0})
		local wield_image = get_wield_image(self.metadata.wielditem)
		local textures = {self.properties.textures[1], get_armor_texture(self), wield_image}
		self.properties = {textures = textures}
		self.object:set_properties(self.properties)
	end,
	on_rightclick = function(self, clicker)
		local name = clicker:get_player_name()
		if name == self.owner then
			npcf:show_formspec(name, self.npc_id, self:get_formspec())
		end
	end,
	on_step = function(self, dtime)
		local control = npcf.control_framework.getControl(self)
		if self.timer > 1 then
			local target = {object=nil, distance=0}
			local min_dist = 1000
			control:mine_stop()
			for _,object in ipairs(minetest.get_objects_inside_radius(control.pos, TARGET_RADIUS)) do
				local to_target = false
				if object:is_player() then
					if GUARD_ATTACK_PLAYERS == true and self.metadata.attack_players == "true" then
						local player_name = object:get_player_name()
						if player_name ~= self.owner then
							if not get_name_in_list(self.metadata.whitelist, player_name) then
								to_target = true
							end
						end
					end
				else 
					local luaentity = object:get_luaentity()
					if luaentity then
						if luaentity.name then
							if get_name_in_list(self.metadata.blacklist, luaentity.name) then
								to_target = true
							end
						end
					end
				end
				if to_target == true then
					local op = object:getpos()
					local dv = vector.subtract(control.pos, op)
					local dy = math.abs(dv.y - 1)
					if dy < math.abs(dv.x) or dy < math.abs(dv.z) then
						local dist = math.floor(vector.distance(control.pos, op))
						if dist < min_dist then
							target.object = object
							target.distance = dist
							min_dist = dist
						end
					end
				end
			end
			if target.object then
				if target.distance < 3 then
					control:mine()
					control:stay()
					control:look_to(target.object:getpos())
					local tool_caps = {full_punch_interval=1.0, damage_groups={fleshy=1}}
					local item = self.metadata.wielditem
					if item ~= "" and minetest.registered_items[item] then
						if minetest.registered_items[item].tool_capabilities then
							tool_caps = minetest.registered_items[item].tool_capabilities
						end
					end
					target.object:punch(self.object, self.var.timer, tool_caps)
				end
				if target.distance > 2 then
					local speed = get_speed(target.distance) * 1.1
					control:walk(target.object:getpos(), speed)
				end
			elseif self.metadata.follow_owner == "true" then
				local player = minetest.get_player_by_name(self.owner)
				if player then
					local p = player:getpos()
					local distance = vector.distance(control.pos, {x=p.x, y=control.pos.y, z=p.z})
					if distance > 3 then
						control:walk(p, get_speed(distance))
					else
						control:stay()
					end
					control:mine_stop()
				end
			elseif self.metadata.patrol == "true" then
				self.var.rest_timer = self.var.rest_timer + self.timer
				if self.var.rest_timer > self.metadata.patrol_rest then
					local index = self.metadata.patrol_index + 1
					if index > #self.metadata.patrol_points then
						index = 1
					end
					local patrol_pos = self.metadata.patrol_points[index]
					if patrol_pos then
						local distance = vector.distance(control.pos, patrol_pos)
						if distance > 1 then
							control:walk(patrol_pos, PATROL_SPEED)
						else
							self.object:setpos(patrol_pos)
							control:stay()
							self.metadata.patrol_index = index
							self.var.rest_timer = 0
						end
					end
				end
			elseif vector.equals(control.pos, self.origin.pos) == false then
				local distance = vector.distance(control.pos, self.origin.pos)
				if distance > 1 then
					control:walk(self.origin.pos, get_speed(distance))
				else
					self.object:setpos(self.origin.pos)
					control.look_to(self.origin.pos)
					control:stay()
				end
			end
			self.timer = 0
		end
	end,
	on_receive_fields = function(self, fields, sender)
		local name = sender:get_player_name()
		if self.owner == name then
			if fields.wielditem then
				local wield_image = get_wield_image(fields.wielditem)
				local textures = {self.properties.textures[1], get_armor_texture(self), wield_image}
				self.object:set_properties({textures = textures})
			end
			if fields.origin then
				self.origin.pos = self.object:getpos()
				self.origin.yaw = self.object:getyaw()
			end
			if fields.follow_owner then
				self.metadata.patrol = "false"
			elseif fields.patrol then
				if fields.patrol == "false" then
					self.metadata.patrol_index = 0
				end
				self.metadata.follow_owner = "false"
			elseif fields.add_patrol then
				local pos = self.object:getpos()
				if pos then
					table.insert(self.metadata.patrol_points, pos)
				end
			elseif fields.clear_patrol then
				self.metadata.patrol_points = {}
			else
				return
			end
			npcf:show_formspec(name, self.npc_id, self:get_formspec())
		end
	end,
})

