local function deepcopy(obj, seen)
	if type(obj) ~= 'table' then
		return obj
	end
	if seen and seen[obj] then
		return seen[obj]
	end
	local s = seen or {}
	local copy = setmetatable({}, getmetatable(obj))
	s[obj] = copy
	for k, v in pairs(obj) do
		copy[deepcopy(k, s)] = deepcopy(v, s)
	end
	return copy
end

npcf = {
	-- prototype for NPC objects
	npc = {
		autoload = true,
		timer = 0,
	},

	-- table of npc.id -> npc
	npcs = {},

	-- table of npc.id -> npc.owner
	index = {},

	default_npc = {
		-- conform to mob standards
		is_mob = true,
		is_npc = true,
		is_adult = function(self)
			return true
		end,
		get_owner = function(self)
			return npcf.index[self.npc_id]
		end,

		-- NPC framework specifics
		description = "Default NPC",
		inventory_image = "npcf_inv.png",
		title = {},
		properties = {},
		metadata = {},
		var = {},
		timer = 0,

		-- Lua Entity properties
		physical = true,
		collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"character.png"},
		makes_footstep_sound = true,
		register_spawner = true,
		armor_groups = {immortal=1},
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
			walk_mine_START = 200,
			walk_mine_END = 219,
		},
		animation_state = 0,
		animation_speed = 30,
	}
}

-- Create NPC object instance
--   when the NPC's entity is loaded, it is stored in self.object
--   otherwise self.object will be nil
function npcf.npc:new(ref)
	ref = ref or {}
	setmetatable(ref, self)
	self.__index = self
	return ref
end

-- Called every NPCF_UPDATE_TIME interval, even on unloaded NPCs
function npcf.npc:update()
	local def = minetest.registered_entities[self.name] or {}
	if type(def.on_update) == "function" then
		def.on_update(self)
	end

	local pos = self.object and self.object:getpos()
	local yaw = self.object and self.object:getyaw()
	if pos and yaw then
		self.pos = pos
		self.yaw = yaw
	else
		-- Object has been deactivated or deleted
		self.object = nil
		local objects = minetest.get_objects_inside_radius(self.pos, NPCF_RELOAD_DISTANCE)
		for _, object in pairs(objects) do
			if object:is_player() then
				local npc_object = npcf:add_entity(self)
				if npc_object then
					self.object = npc_object
					npcf:add_title(self)
				end
			end
		end
	end
end

-- Helper: creates the nametag for a NPC
function npcf:add_title(ref)
	if not ref.object then
		return
	end

	if ref.title.text then
		ref.object:set_nametag_attributes({
			color = ref.title.color or "white",
			text = ref.title.text
		})
	else
		ref.object:set_nametag_attributes({
			text = ""
		})
	end
end

-- Recreates the NPC's entity
--   Called from npcf.npc:update() when the entity is deleted
function npcf:add_entity(ref)
	local object = minetest.add_entity(ref.pos, ref.name)
	if object then
		local entity = object:get_luaentity()
		if entity then
			object:setyaw(ref.yaw)
			object:set_properties(ref.properties)
			entity.npc_id = ref.id
			entity.properties = ref.properties
			entity.metadata = ref.metadata
			entity.var = ref.var
			entity.owner = ref.owner
			entity.origin = ref.origin
			entity.initialized = true
			return object
		end
	end
end

-- Creates an NPC object instance
function npcf:add_npc(ref)
	if ref.id and ref.pos and ref.name then
		ref.name = NPCF_ALIAS[ref.name] or ref.name
		local def = deepcopy(minetest.registered_entities[ref.name])
		if def then
			ref.metadata = ref.metadata or {}
			if type(def.metadata) == "table" then
				for k, v in pairs(def.metadata) do
					if ref.metadata[k] == nil then
						ref.metadata[k] = v
					end
				end
			end
			ref.yaw = ref.yaw or {x=0, y=0, z=0}
			ref.title = ref.title or def.title
			ref.properties = {textures=ref.textures or def.textures}
			ref.var = ref.var or def.var
			if not ref.origin then
				ref.origin = {
					pos = deepcopy(ref.pos),
					yaw = deepcopy(ref.yaw),
				}
			end
			local npc = npcf.npc:new(ref)
			if type(def.on_construct) == "function" then
				def.on_construct(npc)
			end
			npcf.npcs[ref.id] = npc
			npcf.index[ref.id] = ref.owner
			return npc
		end
	end
end

-- Registers an NPC
function npcf:register_npc(name, def)
	local ref = deepcopy(def) or {}
	local default_npc = deepcopy(self.default_npc)
	for k, v in pairs(default_npc) do
		if ref[k] == nil then
			ref[k] = v
		end
	end
	ref.initialized = false
	ref.activated = false
	ref.on_activate = function(self, staticdata)
		if staticdata == "expired" then
			self.object:remove()
		elseif self.object then
			self.object:set_armor_groups(def.armor_groups)
		end
	end
	ref.on_rightclick = function(self, clicker)
		local id = self.npc_id
		local name = clicker:get_player_name()
		if id and name then
			local admin = minetest.check_player_privs(name, {server=true})
			if admin or name == npcf.index[id] then
				minetest.chat_send_player(name, "NPC ID: "..id)
			end
		end
		if type(def.on_rightclick) == "function" then
			def.on_rightclick(self, clicker)
		end
	end
	ref.on_punch = function(self, hitter)
		local hp = self.object:get_hp() or 0
		if hp <= 0 then
			local id = self.npc_id
			if id then
				npcf.npcs[id].title.object = nil
			end
			if type(ref.on_destruct) == "function" then
				ref.on_destruct(self, hitter)
			end
		end
		if type(def.on_punch) == "function" then
			def.on_punch(self, hitter)
		end
	end
	ref.on_step = function(self, dtime)
		if self.initialized == true then
			if self.activated == true then
				if type(def.on_step) == "function" then
					self.timer = self.timer + dtime
					def.on_step(self, dtime)
				end
			else
				if type(def.on_activate) == "function" then
					def.on_activate(self)
				end
				self.activated = true
			end
		end
	end
	ref.get_staticdata = function(self)
		return "expired"
	end
	minetest.register_entity(name, ref)
	if not ref.register_spawner then
		return
	end
	minetest.register_node(name.."_spawner", {
		description = ref.description,
		inventory_image = minetest.inventorycube("npcf_inv.png", ref.inventory_image, ref.inventory_image),
		tiles = {"npcf_inv.png", ref.inventory_image, ref.inventory_image},
		paramtype2 = "facedir",
		groups = {cracky=3, oddly_breakable_by_hand=3},
		sounds = default.node_sound_defaults(),
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("formspec", "size[8,3]"
				.."label[0,0;NPC ID, max 16 characters (A-Za-z0-9_-)]"
				.."field[0.5,1.5;7.5,0.5;id;ID;]"
				.."button_exit[5,2.5;2,0.5;cancel;Cancel]"
				.."button_exit[7,2.5;1,0.5;submit;Ok]"
			)
			meta:set_string("infotext", ref.description.." spawner")
		end,
		after_place_node = function(pos, placer, itemstack)
			local meta = minetest.get_meta(pos)
			meta:set_string("owner", placer:get_player_name())
			if minetest.setting_getbool("creative_mode") == false then
				itemstack:take_item()
			end
			return itemstack
		end,
		on_receive_fields = function(pos, formname, fields, sender)
			if fields.cancel then
				return
			end
			local meta = minetest.get_meta(pos)
			local owner = meta:get_string("owner")
			local sender_name = sender:get_player_name()
			local id = fields.id
			if id and sender_name == owner then
				if id:len() <= 16 and id:match("^[A-Za-z0-9%_%-]+$") then
					if npcf.index[id] then
						minetest.chat_send_player(sender_name, "Error: ID Already Taken!")
						return
					end
				else
					minetest.chat_send_player(sender_name, "Error: Invalid ID!")
					return
				end
				npcf.index[id] = owner
				local npc_pos = {x=pos.x, y=pos.y + 0.5, z=pos.z}
				local yaw = sender:get_look_yaw() + math.pi * 0.5
				local ref = {
					id = id,
					pos = npc_pos,
					yaw = yaw,
					name = name,
					owner = owner,
				}
				local npc = npcf:add_npc(ref)
				npcf:save(ref.id)
				if npc then
					npc:update()
				end
				minetest.remove_node(pos)
			end
		end,
	})
end

-- Deactivate an NPC but don't delete it
function npcf:unload(id)
	local npc = self.npcs[id]
	if npc then
		if npc.object then
			npc.object:remove()
		end
		npc.autoload = false
		npcf:save(id)
		self.npcs[id] = nil
	end
end

-- Delete an NPC
function npcf:delete(id)
	npcf:unload(id)
	local output = io.open(NPCF_DATADIR.."/"..id..".npc", "w")
	if input then
		output:write("")
		io.close(output)
	end
	npcf.index[id] = nil
end

-- Load saved NPCs
function npcf:load(id)
	local input = io.open(NPCF_DATADIR.."/"..id..".npc", 'r')
	if input then
		local ref = minetest.deserialize(input:read('*all'))
		io.close(input)
		ref.id = id
		ref.pos = ref.pos or deepcopy(ref.origin.pos)
		ref.yaw = ref.yaw or deepcopy(ref.origin.yaw)
		return npcf:add_npc(ref)
	end
	minetest.log("error", "Failed to laod NPC: "..id)
end

-- Save NPC
function npcf:save(id)
	local npc = self.npcs[id]
	if npc then
		local ref = {
			pos = npc.pos,
			yaw = npc.yaw,
			name = npc.name,
			owner = npc.owner,
			title = {
				text = npc.title.text,
				color = npc.title.color,
			},
			origin = npc.origin,
			metadata = npc.metadata,
			properties = npc.properties,
			autoload = npc.autoload,
		}

		local output = io.open(NPCF_DATADIR.."/"..id..".npc", 'w')
		if output then
			output:write(minetest.serialize(ref))
			io.close(output)
			return
		end
	end
	minetest.log("error", "Failed to save NPC: "..id)
end

-- Helper: set the animation for an NPC from its state
function npcf:set_animation(entity, state)
	if entity and state and state ~= entity.animation_state then
		local speed = entity.animation_speed
		local anim = entity.animation
		if speed and anim then
			if state == NPCF_ANIM_STAND and anim.stand_START and anim.stand_END then
				entity.object:set_animation({x=anim.stand_START, y=anim.stand_END}, speed)
			elseif state == NPCF_ANIM_SIT and anim.sit_START and anim.sit_END then
				entity.object:set_animation({x=anim.sit_START, y=anim.sit_END}, speed)
			elseif state == NPCF_ANIM_LAY and anim.lay_START and anim.lay_END then
				entity.object:set_animation({x=anim.lay_START, y=anim.lay_END}, speed)
			elseif state == NPCF_ANIM_WALK and anim.walk_START and anim.walk_END then
				entity.object:set_animation({x=anim.walk_START, y=anim.walk_END}, speed)
			elseif state == NPCF_ANIM_WALK_MINE and anim.walk_mine_START and anim.walk_mine_END then
				entity.object:set_animation({x=anim.walk_mine_START, y=anim.walk_mine_END}, speed)
			elseif state == NPCF_ANIM_MINE and anim.mine_START and anim.mine_END then
				entity.object:set_animation({x=anim.mine_START, y=anim.mine_END}, speed)
			end
			entity.animation_state = state
		end
	end
end

-- Helper: get luaentity for an NPC or nil
function npcf:get_luaentity(id)
	local npc = self.npcs[id] or {}
	if npc.object then
		return npc.object:get_luaentity()
	end
end

-- Helper: get angle between positions
function npcf:get_face_direction(p1, p2)
	if p1 and p2 and p1.x and p2.x and p1.z and p2.z then
		local px = p1.x - p2.x
		local pz = p2.z - p1.z
		return math.atan2(px, pz)
	end
end

-- Helper: walk `speed` in direction `yaw` with vertical velocity `y`
function npcf:get_walk_velocity(speed, y, yaw)
	if speed and y and yaw then
		if speed > 0 then
			yaw = yaw + math.pi * 0.5
			local x = math.cos(yaw) * speed
			local z = math.sin(yaw) * speed
			return {x=x, y=y, z=z}
		end
		return {x=0, y=y, z=0}
	end
end

-- Helper: calls minetest.show_formspec with a formname of "npcf_" .. id
function npcf:show_formspec(name, id, formspec)
	if name and id and formspec then
		minetest.show_formspec(name, "npcf_"..id, formspec)
	end
end
