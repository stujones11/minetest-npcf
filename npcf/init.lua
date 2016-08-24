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

NPCF_MODPATH = minetest.get_modpath(minetest.get_current_modname())
NPCF_DATADIR = minetest.get_worldpath().."/npc_data"
dofile(NPCF_MODPATH.."/npcf.lua")
dofile(NPCF_MODPATH.."/chatcommands.lua")

dofile(NPCF_MODPATH.."/npcs/info_npc.lua")
dofile(NPCF_MODPATH.."/npcs/deco_npc.lua")
dofile(NPCF_MODPATH.."/npcs/guard_npc.lua")
dofile(NPCF_MODPATH.."/npcs/trade_npc.lua")
dofile(NPCF_MODPATH.."/npcs/builder_npc.lua")
