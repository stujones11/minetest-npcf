NPCF_MODPATH = minetest.get_modpath(minetest.get_current_modname())
NPCF_DATADIR = minetest.get_worldpath().."/npc_data"
NPCF_UPDATE_TIME = 4
NPCF_RELOAD_DISTANCE = 32
NPCF_ANIM_STAND = 1
NPCF_ANIM_SIT = 2
NPCF_ANIM_LAY = 3
NPCF_ANIM_WALK = 4
NPCF_ANIM_WALK_MINE = 5
NPCF_ANIM_MINE = 6

NPCF_ALIAS = {
	["npcf:info_npc"] = "npcf_info:npc",
	["npcf:deco_npc"] = "npcf_deco:npc",
	["npcf:builder_npc"] = "npcf_builder:npc",
	["npcf:guard_npc"] = "npcf_guard:npc",
	["npcf:trade_npc"] = "npcf_trader:npc",
}

local input = io.open(NPCF_MODPATH.."/npcf.conf", "r")
if input then
	dofile(NPCF_MODPATH.."/npcf.conf")
	io.close(input)
end

if not minetest.mkdir(NPCF_DATADIR) then
	minetest.log("error", "Unable to create the npc_data directory.\n"
		.."All NPC data will be lost on server shutdowm!")
	return
end

dofile(NPCF_MODPATH.."/npcf.lua")
dofile(NPCF_MODPATH.."/chatcommands.lua")

minetest.after(0, function()
	local dirlist = minetest.get_dir_list(NPCF_DATADIR) or {}
	for _, fn in pairs(dirlist) do
		local id = string.match(fn, "^(.+)%.npc$")
		if id then
			local input = io.open(NPCF_DATADIR.."/"..fn, "r")
			if input then
				local ref = minetest.deserialize(input:read('*all'))
				if ref then
					if ref.name then
						npcf.index[id] = ref.owner
						if ref.autoload == nil or ref.autoload == true then
							npcf:load(id)
						end
					end
				end
			end
		end
	end
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname then
		local id = formname:gsub("npcf_", "")
		if id == formname then
			return
		end
		local npc = npcf.npcs[id]
		if npc then
			local entity = npcf:get_luaentity(id)
			if entity then
				for k, v in pairs(fields) do
					if k ~= "" then
						v = string.gsub(v, "^CHG:", "")
						npc.metadata[k] = v
					end
				end
				if type(entity.on_receive_fields) == "function" then
					entity:on_receive_fields(fields, player)
				end
				npcf:save(id)
			end
		end
	end
end)

minetest.register_entity("npcf:title", {
	physical = false,
	collisionbox = {x=0, y=0, z=0},
	visual = "sprite",
	textures = {"npcf_tag_bg.png"},
	visual_size = {x=0.72, y=0.12, z=0.72},
	on_activate = function(self, staticdata, dtime_s)
		if staticdata == "expired" then
			self.object:remove()
		end
	end,
	get_staticdata = function(self)
		return "expired"
	end,
})

minetest.register_globalstep(function(dtime)
	for _, npc in pairs(npcf.npcs) do
		npc.timer = npc.timer + dtime
		if npc.timer > NPCF_UPDATE_TIME then
			npc:update()
			npc.timer = 0
		end
	end
end)

