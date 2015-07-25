local params = "<cmd> [id] [args]"
local help = {
	"Useage: /npcf "..params,
	"                                        ",
	"* setpos     <npc_id> <pos>             ",
	"* setlook    <npc_id> <angle> (0-360)   ",
	"* titletext  <npc_id> <text>            ",
	"* titlecolor <npc_id> <color> (#RRGGBB) ",
	"* tell       <npc_id> <args>            ",
	"* setskin    <npc_id> <filename>        ",
	"* delete     <npc_id>                   ",
	"* unload     <npc_id>                   ",
	"* load       <npc_id>                   ",
	"* save       <npc_id>                   ",
	"  getpos     <npc_id>                   ",
	"* clearobjects (admin only)             ",
	"  list                                  ",
	"  help (show this message)              ",
	"                                        ",
	"* Ownership or server priv required     ",
}

local palette = {
	["black"] = "#000000",
	["white"] = "#FFFFFF",
	["red"] = "#FF0000",
	["green"] = "#00FF00",
	["blue"] = "#0000FF",
	["cyan"] = "#00FFFF",
	["yellow"] = "FFFF00",
	["magenta"] = "#FF00FF",
}

local function update_title(npc)
	if npc.title.object then
		npc.title.object:remove()
		npc.title.object = nil
	end
	if npc.title.text then
		npcf:add_title(npc)
	end
	npcf:save(npc.id)
end

local function get_permission(name, id)
	local perm = minetest.check_player_privs(name, {server=true})
	if perm or name == npcf.index[id] then
		return true
	end
	minetest.chat_send_player(name, "Permission denied!")
	return false
end

minetest.register_chatcommand("npcf", {
	params = params,
	description = "NPC Management",
	func = function(name, param)
		local npc = nil
		local admin = minetest.check_player_privs(name, {server=true})
		local cmd, npc_id, args = string.match(param, "^([^ ]+) (.-) (.+)$")
		if not args then
			cmd, npc_id = string.match(param, "([^ ]+) (.+)")
		end
		if npc_id then
			if not npcf.index[npc_id] then
				minetest.chat_send_player(name, "Invalid NPC ID "..npc_id)
				return
			end
			npc = npcf.npcs[npc_id]
			if not npc and cmd ~= "load" then
				minetest.chat_send_player(name, "NPC "..npc_id.." is not currently loaded")	
				return
			end
			admin = name == npcf.index[npc_id] or admin
		else
			cmd = string.match(param, "([^ ]+)")
		end
		if cmd and npc_id and args then
			if cmd == "setpos" then
				if not get_permission(name, npc_id) then
					return
				end
				local pos = minetest.string_to_pos(args)
				if args == "here" then
					local player = minetest.get_player_by_name(name)
					if player then
						pos = player:getpos()
					end
				end
				if pos then
					pos.y = pos.y + 1
					npc.pos = pos
					npc.origin.pos = pos
					npcf:save(npc_id)
					if npc.object then
						npc.object:setpos(pos)						
					end
					pos = minetest.pos_to_string(pos)
					minetest.log("action", name.." moves NPC "..npc_id.." to "..pos)
				else
					minetest.chat_send_player(name, "Invalid position "..args)
				end
			elseif cmd == "setlook" then
				if not get_permission(name, npc_id) then
					return
				end
				local yaw = nil
				if args == "here" then
					local player = minetest.get_player_by_name(name)
					if player then
						pos = player:getpos()
						if pos then
							yaw = npcf:get_face_direction(npc.pos, pos)
						end
					end
				else
					local deg = tonumber(args)
					if deg then
						deg = 360 - deg % 360
						yaw = math.rad(deg)
					end
				end
				if yaw then
					npc.yaw = yaw
					npc.origin.yaw = yaw
					npcf:save(npc_id)
					if npc.object then
						npc.object:setyaw(yaw)
					end
				end
			elseif cmd == "titletext" then
				if not get_permission(name, npc_id) then
					return
				end
				if string.len(args) > 12 then
					minetest.chat_send_player(name, "Title too long, max 12 characters")
					return
				elseif string.match(args, "^ +$") then
					npc.title.text = nil
				elseif string.match(args, "^[A-Za-z0-9%_%- ]+$") then
					npc.title.text = args							
				else
					minetest.chat_send_player(name, "Invalid title string "..args)
					return
				end		
				update_title(npc)
			elseif cmd == "titlecolor" then
				if not get_permission(name, npc_id) then
					return
				end
				local color = palette[string.lower(args)] or args
				if string.len(color) == 7 and string.match(color, "^#[A-Fa-f0-9]") then
					npc.title.color = color
				else
					minetest.chat_send_player(name, "Invalid color string "..color)
					return
				end						
				update_title(npc)
			elseif cmd == "tell" then
				if not get_permission(name, npc_id) then
					return
				end
				if npc.name then
					local def = minetest.registered_entities[npc.name]
					if type(def.on_tell) == "function" then
						def.on_tell(npc, name, args)
					end
				end
			elseif cmd == "setskin" then
				if not get_permission(name, npc_id) then
					return
				end
				npc.properties.textures[1] = args
				npcf:save(npc_id)
				if npc.object then
					npc.object:set_properties(npc.properties)
				end
				minetest.log("action", name.." changes NPC "..npc_id.." skin to "..args)
			else
				minetest.chat_send_player(name, "Invalid command "..cmd)
			end
			return
		elseif cmd and npc_id then
			if cmd == "titletext" then
				if not get_permission(name, npc_id) then
					return
				end
				npc.title.text = nil
				update_title(npc)
			elseif cmd == "delete" then
				if not get_permission(name, npc_id) then
					return
				end
				npcf:delete(npc_id)
				minetest.log("action", name.." deletes NPC "..npc_id)
			elseif cmd == "unload" then
				if not get_permission(name, npc_id) then
					return
				end
				npcf:unload(npc_id)
				minetest.log("action", name.." unloads NPC "..npc_id)
			elseif cmd == "load" then
				if not get_permission(name, npc_id) then
					return
				end
				local npc = npcf:load(npc_id)
				if npc then
					npc.autoload = true
					npc:update()
					npcf:save(npc_id)
					minetest.log("action", name.." loads NPC "..npc_id)
				end
			elseif cmd == "save" then
				if not get_permission(name, npc_id) then
					return
				end
				if npc then
					npcf:save(npc_id)
					minetest.chat_send_player(name, "NPC "..npc_id.." has been saved")
				end
			elseif cmd == "getpos" then
				local msg = "NPC "..npc_id
				if npc and npcf.index[npc_id] then
					local pos = {
						x = math.floor(npc.pos.x * 10) * 0.1,
						y = math.floor(npc.pos.y * 10) * 0.1 - 1,
						z = math.floor(npc.pos.z * 10) * 0.1
					}
					msg = msg.." located at "..minetest.pos_to_string(pos)
				else
					msg = msg.." position unavilable"
				end
				minetest.chat_send_player(name, msg)
			else
				minetest.chat_send_player(name, "Invalid command "..cmd)
			end
			return
		elseif cmd then
			if cmd == "help" then
				minetest.chat_send_player(name, table.concat(help, "\n"))
			elseif cmd == "list" then
				local msg = "None"
				local npclist = {}
				for id, _ in pairs(npcf.index) do
					local loaded = id
					if npcf.npcs[id] then
						loaded = loaded.." [loaded]"
					end
					table.insert(npclist, loaded)
				end
				if #npclist > 0 then
					msg = table.concat(npclist, "\n")
				end
				minetest.chat_send_player(name, "NPC List: \n\n"..msg)
			elseif cmd == "clearobjects" then
				if admin then
					for id, npc in pairs(npcf.npcs) do
						npcf:unload(id)
					end
				end
			else
				minetest.chat_send_player(name, "Invalid command "..cmd)
			end
			return
		end
		local msg = "Usage: /npcf "..params.."\n\nenter /npcf help for available commands"
		minetest.chat_send_player(name, msg)
	end,
})

