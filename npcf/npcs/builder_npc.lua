local MAX_SPEED = 5
local MAX_POS = 1000
local DEFAULT_NODE = {name="air"}
local SCHEMS = {"basic_hut.we"}
local MODPATH = minetest.get_modpath("instabuild")
if MODPATH then
	for _,v in ipairs({"factory.we", "large_warehouse.we", "small_farm.we", "tall_tower.we",
		"large_farm.we", "mansion.we", "small_house.we", "large_house.we", "modern_house.we",
		"small_hut.we", "large_hut.we", "short_tower.we", "small_warehouse.we"}) do
		table.insert(SCHEMS, v)
	end
end

local function reset_build(self)
	self.var.nodedata = {}
	self.var.nodelist = {}
	self.metadata.index = nil
	self.metadata.schematic = nil
	self.metadata.build_pos = nil
	self.metadata.building = false
end

local function get_registered_nodename(name)
	if string.find(name, "^doors") then
		name = name:gsub("_[tb]_[12]", "") 
	elseif string.find(name, "^stairs") then
		name = name:gsub("upside_down", "")
	elseif string.find(name, "^farming") then
		name = name:gsub("_%d", "")
	end
	return name
end

local function load_schematic(self, filename)
	local input = nil
	if MODPATH then
		input = io.open(MODPATH.."/models/"..filename, "r")
	end
	if not input then
		input = io.open(NPCF_MODPATH.."/schems/"..filename, "r")
	end
	if input then
		local data = minetest.deserialize(input:read('*all'))
		io.close(input)
		table.sort(data, function(a,b)
			if a.y == b.y then
				if a.z == b.z then
					return a.x > b.x
				end
				return a.z > b.z
			end
			return a.y > b.y
		end)
		local sorted = {}
		local pos = {x=0, y=0, z=0}
		while #data > 0 do
			local index = 1
			local min_pos = {x=MAX_POS, y=MAX_POS, z=MAX_POS}
			for i,v in ipairs(data) do
				if v.y < min_pos.y or vector.distance(pos, v) < vector.distance(pos, min_pos) then
					min_pos = v
					index = i
				end
			end
			local node = data[index]
			table.insert(sorted, node)
			table.remove(data, index)
			pos = {x=node.x, y=node.y, z=node.z}
		end
		self.var.nodedata = {}
		self.var.nodelist = {}
		for i,v in ipairs(sorted) do
			if v.name and v.param1 and v.param2 and v.x and v.y and v.z then
				local node = {name=v.name, param1=v.param1, param2=v.param2}
				local pos = vector.add(self.metadata.build_pos, {x=v.x, y=v.y, z=v.z})
				local name = get_registered_nodename(v.name)
				if minetest.registered_items[name] then
					self.metadata.inventory[name] = self.metadata.inventory[name] or 0
					self.var.nodelist[name] = self.var.nodelist[name] or 0
					self.var.nodelist[name] = self.var.nodelist[name] + 1
				else
					node = DEFAULT_NODE
				end
				self.var.nodedata[i] = {pos=pos, node=node}
			end
		end
	end
end

local function show_build_form(self, player_name)
	local nodelist = {}
	for k,v in pairs(self.var.nodelist) do
		if string.find(k, "^doors") then
			v = v * 0.5
		end
		if self.metadata.inventory[k] then
			v = v - self.metadata.inventory[k]
		end
		if v < 0 then
			v = 0
		end
		if minetest.registered_items[k].description ~= "" then
			k = minetest.registered_items[k].description
		end
		table.insert(nodelist, k.." ("..v..")")
	end
	local materials = table.concat(nodelist, ",") or ""
	local title = self.metadata.schematic:gsub("%.we","")
	local button_build = "button_exit[5.0,1.0;3.0,0.5;build_start;Begin Build]"
	if self.metadata.index then
		button_build = "button_exit[5.0,1.0;3.0,0.5;build_resume;Resume Build]"
	end
	local formspec = "size[8,9]"
		.."label[3.0,0.0;Project: "..title.."]"
		.."textlist[0.0,1.0;4.0,3.5;inv_sel;"..materials..";"..self.var.selected..";]"
		.."list[current_player;main;0.0,5.0;8.0,4.0;]"
		..button_build
	if NPCF_BUILDER_REQ_MATERIALS == true then
		formspec = formspec.."list[detached:npcf_"..self.npc_name..";input;6.0,3.5;1,1;]"
	end
	if self.owner == player_name then
		formspec = formspec.."button_exit[5.0,2.0;3.0,0.5;build_cancel;Cancel Build]"
	end
	npcf:show_formspec(player_name, self.npc_name, formspec)
end

local function get_speed(distance)
	local speed = distance * 0.5
	if speed > MAX_SPEED then
		speed = MAX_SPEED
	end
	return speed
end

npcf:register_npc("npcf:builder_npc" ,{
	description = "Builder NPC",
	textures = {"npcf_skin_builder.png"},
	nametag_color = "green",
	metadata = {
		schematic = nil,
		inventory = {},
		index = nil,
		build_pos = nil,
		building = false,
	},
	var = {
		selected = "",
		nodelist = {},
		nodedata = {},	
		last_pos = {},
	},
	stepheight = 1,
	inventory_image = "npcf_inv_builder_npc.png",
	on_construct = function(self)
		self.metadata.building = false
		self.object:setvelocity({x=0, y=0, z=0})
		self.object:setacceleration({x=0, y=-10, z=0})
		if self.metadata.schematic and self.metadata.build_pos then
			load_schematic(self, self.metadata.schematic)
		end
	end,
	on_activate = function(self, staticdata, dtime_s)
		local inv = minetest.create_detached_inventory("npcf_"..self.npc_name, {
			on_put = function(inv, listname, index, stack, player)
				local player_name = player:get_player_name()
				local item = stack:get_name()
				if player_name and self.metadata.inventory[item] then
					self.metadata.inventory[item] = self.metadata.inventory[item] + stack:get_count()
					inv:remove_item("input", stack)
					show_build_form(self, player_name)
				end	
			end,
		})
		inv:set_size("input", 1)
	end,
	on_rightclick = function(self, clicker)
		local player_name = clicker:get_player_name()
		if self.owner == player_name then
			if not self.metadata.schematic then
				local schemlist = table.concat(SCHEMS, ",") or ""
				local formspec = "size[6,5]"
					.."textlist[0.0,0.0;5.0,4.0;schemlist;"..schemlist..";;]"
					.."button_exit[5.0,4.5;1.0,0.5;;Ok]"
				npcf:show_formspec(player_name, self.npc_name, formspec)
				return
			elseif self.metadata.building == true then
				self.metadata.building = false
				return
			end
		end
		if self.metadata.schematic and self.metadata.building == false then
			show_build_form(self, player_name)
		end
	end,
	on_step = function(self, dtime)
		if self.timer > 1 then
			self.timer = 0
			if not self.owner then
				return
			end
			local pos = self.object:getpos()
			local yaw = self.object:getyaw()
			local state = NPCF_ANIM_STAND
			local speed = 0
			if self.metadata.building == true then
				local nodedata = self.var.nodedata[self.metadata.index]
				pos.y = math.floor(pos.y)
				local acceleration = {x=0, y=-10, z=0}
				if pos.y < nodedata.pos.y then
					if self.object:getacceleration().y > 0 and self.var.last_pos.y == pos.y then
						self.object:setpos({x=pos.x, y=nodedata.pos.y + 1.5, z=pos.z})
						acceleration = {x=0, y=0, z=0}
					else
						acceleration = {x=0, y=0.1, z=0}
					end
				end
				self.var.last_pos = pos
				self.object:setacceleration(acceleration)
				yaw = npcf:get_face_direction(pos, nodedata.pos)
				local distance = vector.distance(pos, nodedata.pos)
				if distance < 4 then
					if minetest.registered_items[nodedata.node.name].sounds then
						local soundspec = minetest.registered_items[nodedata.node.name].sounds.place
						if soundspec then
							soundspec.pos = pos
							minetest.sound_play(soundspec.name, soundspec)
						end
					end
					minetest.add_node(nodedata.pos, nodedata.node)
					local door_top = string.find(nodedata.node.name, "^doors+_t_[12]$")
					if NPCF_BUILDER_REQ_MATERIALS == true and not door_top then
						local name = get_registered_nodename(nodedata.node.name)
						if self.metadata.inventory[name] > 0 then
							self.metadata.inventory[name] = self.metadata.inventory[name] - 1
							self.var.selected = ""
						else
							self.metadata.building = false
							state = NPCF_ANIM_STAND
							speed = 0
							local i = 0
							for k,v in pairs(self.var.nodelist) do
								i = i + 1
								if k == name then
									self.var.selected = i
									break
								end
							end
						end
					end
					self.metadata.index = self.metadata.index + 1
					if self.metadata.index > #self.var.nodedata then
						reset_build(self)
					end
					state = NPCF_ANIM_WALK_MINE
					speed = 1
				else
					state = NPCF_ANIM_WALK
					speed = get_speed(distance)
				end
			elseif vector.equals(pos, self.origin.pos) == false then
				self.object:setacceleration({x=0, y=-10, z=0})
				yaw = npcf:get_face_direction(pos, self.origin.pos)
				local distance = vector.distance(pos, self.origin.pos)
				if distance > 1 then
					speed = get_speed(distance)
					state = NPCF_ANIM_WALK
				else
					self.object:setpos(self.origin.pos)
					yaw = self.origin.yaw
				end
			end
			self.object:setvelocity(npcf:get_walk_velocity(speed, self.object:getvelocity().y, yaw))
			self.object:setyaw(yaw)
			npcf:set_animation(self, state)
		end
	end,
	on_receive_fields = function(self, fields, sender)
		local player_name = sender:get_player_name()
		if self.owner == player_name then
			if fields.schemlist then
				local id = tonumber(string.match(fields.schemlist, "%d+"))
				if id then
					if SCHEMS[id] then
						local pos = {
							x=math.ceil(self.origin.pos.x) + 1,
							y=math.floor(self.origin.pos.y),
							z=math.ceil(self.origin.pos.z) + 1
						}
						self.metadata.schematic = SCHEMS[id]
						self.metadata.build_pos = pos
						load_schematic(self, self.metadata.schematic)
					end
				end
			elseif fields.build_cancel then
				reset_build(self)
			end
		end
		if fields.build_start then
			for i,v in ipairs(self.var.nodedata) do
				minetest.remove_node(v.pos)
			end
			self.metadata.index = 1
			self.metadata.building = true
		elseif fields.build_resume then
			self.metadata.building = true
		end
	end,
})

