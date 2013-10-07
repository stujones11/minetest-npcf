NPCF_MODPATH = minetest.get_modpath(minetest.get_current_modname())
NPCF_DATADIR = minetest.get_worldpath().."/npc_data"
dofile(NPCF_MODPATH.."/npcf.lua")
dofile(NPCF_MODPATH.."/chatcommands.lua")

dofile(NPCF_MODPATH.."/npcs/info_npc.lua")
dofile(NPCF_MODPATH.."/npcs/deco_npc.lua")
dofile(NPCF_MODPATH.."/npcs/guard_npc.lua")
dofile(NPCF_MODPATH.."/npcs/trade_npc.lua")
dofile(NPCF_MODPATH.."/npcs/builder_npc.lua")

