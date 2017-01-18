local MODPATH = minetest.get_modpath(minetest.get_current_modname())
local BUILDER_REQ_MATERIALS = minetest.setting_getbool("creative_mode") == false
local MAX_SPEED = 5
local MAX_POS = 1000
local DEFAULT_NODE = {name="air"}
local SCHEMS = {"basic_hut.we"}
local INSTABUILD_PATH = minetest.get_modpath("instabuild")
local SCHEMLIB_PATH = minetest.get_modpath("schemlib")
if INSTABUILD_PATH then
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
	self.schemlib_plan = nil
end

local function get_registered_itemname(name)
	if string.find(name, "^doors") then
		name = name:gsub("_[tb]_[12]", "") 
	elseif string.find(name, "^stairs") then
		name = name:gsub("upside_down", "")
	elseif string.find(name, "^farming") then
		name = name:gsub("_%d", "")
	end
	return name
end

local function get_registered_nodename(name)
	if string.find(name, "^doors.*_[ab]_[12]$") then
		name = name:gsub("_[12]", "")
	elseif string.find(name, "^doors.*_t_[12]$") then
		name = "doors:hidden"
	end
	return name
end

local function load_schematic(self, filename)
	local input = nil
	local fullpath
	if INSTABUILD_PATH then
		fullpath = INSTABUILD_PATH.."/models/"..filename
	else
		fullpath = MODPATH.."/schems/"..filename
	end
	
	if SCHEMLIB_PATH then
		self.schemlib_plan = schemlib.plan.new()
		self.schemlib_plan:read_from_schem_file(fullpath)
		if not self.schemlib_plan.data then
			print("file could not be read")
			reset_build(self)
			return
		end
		self.schemlib_plan.anchor_pos = self.metadata.build_pos
		self.schemlib_plan:apply_flood_with_air(3, 0, 3)
		schemlib.mapping.do_mapping(self.schemlib_plan.data)
		for name_id, mappedinfo in pairs(self.schemlib_plan.data.mappedinfo) do
			if mappedinfo.cost_item ~= schemlib.mapping.c_free_item then
				self.var.nodelist[mappedinfo.cost_item] = self.schemlib_plan.data.nodeinfos[name_id].count
				self.metadata.inventory[mappedinfo.cost_item] = self.metadata.inventory[mappedinfo.cost_item] or 0
			end
		end

	else
		input = io.open(fullpath, "r")

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
					local item_name = get_registered_itemname(v.name)
					local node_name = get_registered_nodename(v.name)
					local node = {name=node_name, param1=v.param1, param2=v.param2}
					local pos = vector.add(self.metadata.build_pos, {x=v.x, y=v.y, z=v.z})
					if minetest.registered_items[item_name] then
						self.metadata.inventory[item_name] = self.metadata.inventory[item_name] or 0
						self.var.nodelist[item_name] = self.var.nodelist[item_name] or 0
						self.var.nodelist[item_name] = self.var.nodelist[item_name] + 1
					else
						node = DEFAULT_NODE
					end
					self.var.nodedata[i] = {pos=pos, node=node, item_name=item_name}
				end
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
	if BUILDER_REQ_MATERIALS == true then
		formspec = formspec.."list[detached:npcf_"..self.npc_id..";input;6.0,3.5;1,1;]"
	end
	if self.owner == player_name then
		formspec = formspec.."button_exit[5.0,2.0;3.0,0.5;build_cancel;Cancel Build]"
	end
	npcf:show_formspec(player_name, self.npc_id, formspec)
end

local function get_speed(distance)
	local speed = distance * 0.5
	if speed > MAX_SPEED then
		speed = MAX_SPEED
	end
	return speed
end

npcf:register_npc("npcf_builder:npc" ,{
	description = "Builder NPC",
	textures = {"npcf_builder_skin.png"},
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
	stepheight = 1.1,
	inventory_image = "npcf_builder_inv.png",
	on_activate = function(self)
		self.metadata.building = false
		if self.metadata.schematic and self.metadata.build_pos then
			load_schematic(self, self.metadata.schematic)
		end
		local inv = minetest.create_detached_inventory("npcf_"..self.npc_id, {
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
				npcf:show_formspec(player_name, self.npc_id, formspec)
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
		local control = npcf.control_framework.getControl(self)
		if self.timer > 1 then
			self.timer = 0
			if not self.owner then
				return
			end
			control:mine_stop()
			if self.metadata.building == true then
				local nodedata
				local schemlib_node
				local distance
				if not SCHEMLIB_PATH then
					nodedata = self.var.nodedata[self.metadata.index]
					distance = vector.distance(control.pos, nodedata.pos)
					control:walk(nodedata.pos, get_speed(distance), {teleport_on_stuck = true})
				else
					if not self.my_ai_data then
						self.my_ai_data = {}
					end
					schemlib_node = schemlib.npc_ai.plan_target_get({
						plan = self.schemlib_plan,
						npcpos = control.pos,
						savedata = self.my_ai_data})
					if not schemlib_node then --stuck in plan
						control:stop()
						if self.schemlib_plan.data.nodecount == 0 then
							reset_build(self)
						end
						return
					end
					distance = vector.distance(control.pos, schemlib_node.world_pos)
					control:walk(schemlib_node.world_pos, get_speed(distance), {teleport_on_stuck = true})
				end
				if distance < 4 then
					control:mine()
					control.speed = 1
					if SCHEMLIB_PATH then
						schemlib.npc_ai.place_node(schemlib_node, self.schemlib_plan)
						self.schemlib_plan:del_node(schemlib_node.plan_pos)
						if BUILDER_REQ_MATERIALS == true and schemlib_node.cost_item ~= schemlib.mapping.c_free_item  then
							if self.metadata.inventory[schemlib_node.cost_item] > 0 then
								self.metadata.inventory[schemlib_node.cost_item] = self.metadata.inventory[schemlib_node.cost_item] - 1
								self.var.selected = ""
							else
								self.metadata.building = false
								control:mine_stop()
								control:stop()
							end
						end
						if self.schemlib_plan.data.nodecount == 0 then
							reset_build(self)
						end
					else
						if minetest.registered_nodes[nodedata.node.name].sounds then
							local soundspec = minetest.registered_nodes[nodedata.node.name].sounds.place
							if soundspec then
								soundspec.pos = control.pos
								minetest.sound_play(soundspec.name, soundspec)
							end
						end
						minetest.add_node(nodedata.pos, nodedata.node)
						if BUILDER_REQ_MATERIALS == true and nodedata.node.name ~= "doors:hidden" then
							if self.metadata.inventory[nodedata.item_name] > 0 then
								self.metadata.inventory[nodedata.item_name] = self.metadata.inventory[nodedata.item_name] - 1
								self.var.selected = ""
							else
								self.metadata.building = false
								control:stop()
								control:mine_stop()
								local i = 0
								for k,v in pairs(self.var.nodelist) do
									i = i + 1
									if k == nodedata.item_name then
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
					end
				end
			elseif vector.equals(control.pos, self.origin.pos) == false then
				local distance = vector.distance(control.pos, self.origin.pos)
				if distance > 1 then
					control:walk(self.origin.pos, get_speed(distance), {teleport_on_stuck = true})
				else
					control.yaw = self.origin.yaw
				end
			end
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

