-- Copyright (C) 2013-2014 to stujones11
-- Copyright (C) 2016 to rubenwardy
--
-- This library is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
--
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

local function get_formspec(text, page)
	local lines = text:split("\n")
	local start = (page - 1) * 12
	local eof = false
	local formspec = "size[8,6.5]"
	for i = 1, 12 do
		if lines[start + i] then
			formspec = formspec.."label[0.5,"..(i*0.4)..";"..lines[start+i].."]"
		else
			eof = true
		end
	end
	if page > 1 then
		formspec = formspec.."button[0.0,6.0;1,0.5;page_"..(page-1)..";<<]"
	end
	if eof == false then
		formspec = formspec.."button[7.0,6.0;1,0.5;page_"..(page+1)..";>>]"
	end
	formspec = formspec.."button_exit[3.0,6.0;2,0.5;;Exit]"
	return formspec
end

npcf:register_npc("npcf:info_npc" ,{
	description = "Information NPC",
	textures = {"npcf_skin_info.png"},
	nametag_color = "cyan",
	metadata = {
		infotext = "Infotext."
	},
	inventory_image = "npcf_inv_info_npc.png",
	on_rightclick = function(self, clicker)
		local player_name = clicker:get_player_name()
		local infotext = minetest.formspec_escape(self.metadata.infotext)
		local formspec = get_formspec(infotext, 1)
		if player_name == self.owner then
			formspec = "size[8,6]"
				.."textarea[0.5,0.5;7.5,5.0;infotext;Infotext;"..infotext.."]"
				.."button[0.0,5.5;2.0,0.5;page_1;View]"
				.."button_exit[7.0,5.5;1.0,0.5;;Ok]"
		end
		npcf:show_formspec(player_name, self.npc_name, formspec)
	end,
	on_receive_fields = function(self, fields, sender)
		for k,_ in pairs(fields) do
			page = k:gsub("page_", "")
			if page ~= k then
				local formspec = get_formspec(self.metadata.infotext, tonumber(page))
				npcf:show_formspec(sender:get_player_name(), self.npc_name, formspec)
				break
			end
		end
	end,
})
