-- Copyright (c) 2016 rubenwardy
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included
-- in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.

npc_villager = {}

dofile(minetest.get_modpath("npc_villager") .. "/states.lua")

function npcf:create_state(name)
	if not name then
		error("[npcf] States must have a name, even if it's an empty name")
	end
	return {
		name = name,

		-- now in this state
		load = function(self) end,

		-- moving to another state
		unload = function(self) return true end,

		-- callbacks
		on_rightclick = function(self, npc, clicker) end,
		on_punch = function(self, npc, hitter) end,
		on_step = function(self, npc, dtime) end,
        on_activate = function(self, npc) end,
        on_destruct = function(self, npc) end,
        on_save = function(self, npc, to_save) end,
        on_update = function(self, npc) end,
		on_tell = function(self, npc, sender, message) end,
		on_receive_fields = function(self, npc, fields, sender) end,
	}
end

npcf.npc.npc_state = npcf:create_state("")

function npcf.npc:set_state(state)
	if not self.npc_state or self.npc_state.unload(self) then
		self.npc_state = state
		self.npc_state.load(self)
	end
end

npcf:register_npc("npc_villager:villager" ,{
    description = "Villager",
	textures = {"npcf_info_skin.png"},
    metadata = {
        infotext = "Infotext."
    },
    title = {
		text = "Villager",
		color = "#00aaff",
	},
	inventory_image = "npcf_info_inv.png",
    on_rightclick = function(self, clicker)
        print("[npc_villager] on_rightclick!")
        local npc = npcf.npcs[self.npc_id]
        local state = npc.npc_state
        return state and state.on_rightclick and state:on_rightclick(npc, clicker)
    end,
    on_punch = function(self, hitter)
        print("[npc_villager] on_punch!")
        local npc = npcf.npcs[self.npc_id]
        local state = npc.npc_state
        return state and state.on_punch and state:on_punch(npc, hitter)
    end,
    on_step = function(self, dtime)
        print("[npc_villager] on_step!")
        local npc = npcf.npcs[self.npc_id]
        local state = npc.npc_state
        return state and state.on_step and state:on_step(npc, dtime)
    end,
    on_activate = function(self)
        print("[npc_villager] on_activate!")
        if not self.set_state then
            print(" - no self.set_state")
        end
        local npc = npcf.npcs[self.npc_id]
        local state = npc.npc_state
        return state and state.on_activate and state:on_activate(npc)
    end,
    on_construct = function(npc)
        print("[npc_villager] on_construct!")
        if not npc.set_state then
            print(" - no npc.set_state")
        end
        local state = npc.npc_state
        return state and state.on_construct and state:on_construct(npc)
    end,
    on_destruct = function(npc)
        print("[npc_villager] on_destruct!")
        local state = npc.npc_state
        return state and state.on_destruct and state:on_destruct(npc)
    end,
    on_save = function(npc, to_save)
        print("[npc_villager] on_save!")
        local state = npc.npc_state
        return state and state.on_save and state:on_save(npc, to_save)
    end,
    on_update = function(npc)
        print("[npc_villager] on_update")
        local state = npc.npc_state
        return state and state.on_update and state:on_update(npc)
    end,
    on_tell = function(npc, sender, message)
        print("[npc_villager] on_tell")
        local state = npc.npc_state
        return state and state.on_tell and state:on_tell(npc, sender, message)
    end,
    on_receive_fields = function(self, fields, sender)
        print("[npc_villager] on_receive_fields")
        local npc = npcf.npcs[self.npc_id]
        local state = npc.npc_state
        return state and state.on_receive_fields and state:on_receive_fields(npc, fields, sender)
    end
})
