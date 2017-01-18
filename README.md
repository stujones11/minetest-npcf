Modpack - NPC Framework [0.2.0]
-------------------------------
This mod adds some, hopefully useful, non-player characters to the minetest game.
The mod also provides a framework for others to create and manage their own custom NPCs.

Features currently include overhead titles, formspec handling, ownership, chat command management
and file based back-ups. Some example NPC mods have been included as part of the modpack.

The example NPC's are not craftable although by default will be available in the creative mode menu.
Server operators would be advised to override this default behaviour and allocate the NPCs on /give basis.

### Info NPC [npcf_info]

The Info NPC is a simple information serving character. You could think of them as a
human book providing information about a particular server location, or whatever else you like.
Supports multiple pages of text. 12 lines per page, ~50 chars per line.

### Deco NPC [npcf_deco]

A purely decorative NPC, can be set to roam freely and/or follow random players it encounters.

### Guard NPC [npcf_guard]

Protect yourself and your property against other players and mobs. Features 3d weapon and armor.
Can be left to guard a certain area or set to follow their owner.

### Trader NPC [npcf_trader]

Provides a quantity based exchange system. The owner can set a given number of exchanges.
This would likely be best used in conjunction with one of the physical currency mods.

	Buy [default:mese] Qty [1] - Sell [default:gold_ingot] Qty [10]
	Buy [default:gold_ingot] Qty [20] - Sell [default:mese] Qty [1]

Note that the NPC's owner cannot trade with their own NPC, that would be rather pointless anyway.

### Builder NPC [npcf_builder]

Not really much point to this atm other than it's really fun to watch. By default, it be can only
build a basic hut, however this is compatible (or so it seems) with all the schematics provided by
Dan Duncombe's instabuild mod. These should be automatically available for selection if you have
the instabuild mod installed.

Usage
-----

Place an NPC spawner node on the ground at a chosen location, right-click on the spawner and
give the NPC a unique ID, maximum 16 alpha-numeric characters with no spaces. (underscore and/or hyphen permitted)
This ID will be used to address the NPC using chat command interface and as the NPC's back-up file name.
NPC owner's and server admins can view the ID of any loaded NPC by right-clicking on the NPC entity

Chat Commands
-------------

NPC chat commands are issued as follows.

	/npcf <command> [id] [args]

### list

List all registered NPCs and display online status.

### clearobjects

Clear all loaded NPCs. (requires server priv)

### getpos id

Display the position of the NPC.

### save id

Save current NPC state to file. (requires ownership or server priv)

### unload id

Unload a loaded NPC. (requires ownership or server priv)

### delete id

Permanently unload and delete the NPC.  (requires ownership or server priv)

### load id

Loads the NPC at the origin position. (requires ownership or server priv)

### setpos id pos | here

Set NPC location. (requires ownership or server priv)
Position x y z

	/npcf setpos npc_1 0, 1.5, 0

Use 'here' to locate the NPC at the player's current position.

	/npcf setpos npc_1 here

### setlook id direction | here

Set NPC face direction. (requires ownership or server priv)
Direction 0-360 degrees (0 = North)

	/npcf setlook npc_1 0

Use 'here' to face the NPC towards the player.

	/npcf setlook npc_1 here

### tell id message

Send message to NPC (requires ownership or server priv)

Customizable chat command callback for additional NPC interaction.
Has no effect unless overridden by the NPC's registration.

### setskin id skin_filename

Set the skin texture of the NPC. (requires ownership or server priv)

	/npcf setskin npc_1 character.png

### titletext id string

Set the NPC title string. (requires ownership or server priv)
maximum 12 alpha-numeric characters (may contain spaces underscore and hyphen)
Use an empty string or only spaces to remove a title.

### titlecolor id color

Set the NPC title color #RRGGBB format. (requires ownership or server priv)

	/npcf titlecolor npc_1 #FF0000

Also supports simple color names. (black, white, red, green, blue, cyan, yellow, magenta)
Not case sensitive.

	/npcf titlecolor npc_1 Red

API Reference
-------------
Use the global npcf api to create your own NPC.

	npcf:register_npc("my_mod:my_cool_npc" ,{
		description = "My Cool NPC",
	})

This is a minimal example, see the NPCs included for more elaborate usage examples.

Properties
----------
Additional properties included by the framework. (defaults)

	on_construct = function(self),
	on_destruct = function(self, hitter),
	on_save = function(npc, to_save),
	on_update = function(npc),
	on_tell = function(npc, sender, message),
	on_receive_fields = function(self, fields, sender),
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
	description = "Default NPC",
	inventory_image = "npcf_inv_top.png",
	title = {},
	metadata = {},
	var = {},
	timer = 0,

Special Properties
------------------
Properties used internally by the framework.

	initialized = false,
	activated = false,
	properties = {textures=textures},
	npcf_id = id,
	owner = owner,
	origin = {pos=pos, yaw=yaw},

These should be considered read-only, with the exception of origin
where it may be desireable update the statically saved position.

	self.origin.pos = self.object:getpos()
	self.origin.yaw = self.object:getyaw()

Callbacks
---------
Additional callbacks provided by the framework.
Note that 'npc' is a NPC object reference, not a LuaEntitySAO reference. The latter can be obtained from
npc.object but only when the LuaEntitySAO is loaded.

### on_construct = function(npc)
Called when the NPC object is first created, or loaded from save.
You should read things from npc.

### on_save = function(npc, to_save)
Called when the NPC is being saved to file. to_save is the table that is going to be serialized.

### on_destruct = function(self, hitter)
Called when an NPC is destroyed by punching. Can be used to unload the NPC when defeated by a player.
See the Guard NPC for an example.

### on_update = function(npc)
Called every time an NPC object is updated (NPCF_UPDATE_TIME) even when the LuaEntitySAO is not loaded.

### on_tell = function(npc, sender, message)
Called when the 'tell' chat command is issued. Note that this Behavior diverges from version 0.1.0,
however, it does now allow for interaction even when the associated LuaEntitySAO not loaded.

### on_receive_fields = function(self, fields, sender)
Called when a button is pressed in the NPC's formspec. text fields, dropdown,
list and checkbox selections are automatically stored in the metadata table.

npcf
----
The global NPC framework namespace.

### Global Constants

	NPCF_UPDATE_TIME = 4
	NPCF_RELOAD_DISTANCE = 32
	NPCF_ANIM_STAND = 1
	NPCF_ANIM_SIT = 2
	NPCF_ANIM_LAY = 3
	NPCF_ANIM_WALK = 4
	NPCF_ANIM_WALK_MINE = 5
	NPCF_ANIM_MINE = 6

All of the above can be overridden by including a npcf.conf file in the npcf directory.
See: npcf.conf.example

### npcf.index

Ownership table of all spawned NPCs (loaded or unloaded)

	npcf.index[id] = owner -- owner's name

### npcf.npcs

Table of loaded NPC object references.

### npcf.npc

NPC object prototype.

	autoload = true,
	timer = 0,
	object = nil -- LuaEntitySAO added as required

### npcf.npc:new(ref)

Create a new NPC object instance.

	local npc = npcf.npc:new({
		id = id,
		pos = pos,
		yaw = yaw,
		name = name,
		owner = owner,
		title = {},
		properties = {textures = textures},
		metadata = {},
		var = {},
		origin = {
			pos = pos,
			yaw = yaw,
		}
	})

If used directly then it is the caller's resposibilty to store the reference and update the index.
Use: npcf:add_npc(ref) instead to have this done automatically by the framework.

### npc:update()

Update the NPC object. Adds a LuaEntitySAO when in range of players (NPCF_RELOAD_DISTANCE)
Called automatically on global step (NPCF_UPDATE_TIME) for all loaded NPC objects.

### npcf:add_title(ref)

Adds a floating title above the NPC entity

### npcf:add_entity(ref)

Adds a LuaEntitySAO based on the NPC reference, returns a minetest ObjectRef on success.
Care should be taken to avoid entity duplication when called externally.

### npcf:add_npc(ref)

Adds a new NPC based on the reference.

	local ref = {
		id = id,
		pos = pos,
		yaw = yaw,
		name = "my_mod_name:npc",
		owner = "owner_name", --optional
	}
	local npc = npcf:add_npc(ref)

If owner is nil then the NPC will be omitted from npcf.index.
Chat commands for such NPCs will only be available to admins (server priv).

### npcf:register_npc(name, def)

Register a non-player character. Used as a wrapper for minetest.register_entity, it includes
all the callbacks and properties available there with the exception of get_staticdata which is used internally. The framework provides 'metadata' and 'var' tables for data storage, where the metadata table is persistent following a reload and automatically stores submitted form data.
The var table should be used for semi-persistent data storage only. Note that self.timer is
automatically incremented by the framework but should be reset externally.

### npcf:unload(id)

Remove the NPC object instance and all associated entities.

### npcf:delete(id)

Permanently erase thw NPC object and associated back-up file.

### npcf:load(id)

Loads the NPC at the origin position.

### npcf:save(id)

Save current NPC state to file.

	on_receive_fields = function(self, fields, sender)
		if fields.save then
			npcf:save(self.npc_id)
		end
	end,

### npcf:set_animation(luaentity, state)

Sets the NPC's animation state.

	on_activate = function(self, staticdata, dtime_s)
		npcf:set_animation(self, NPCF_ANIM_STAND)
	end,

### npcf:get_luaentity(id)

Returns a LuaEntitySAO if the NPC object is loaded.

### npcf:get_face_direction(p1, p2)

Helper routine used internally and by some of the example NPCs.
Returns a yaw value in radians for position p1 facing position p2.

### npcf:get_walk_velocity(speed, y, yaw)

Returns a velocity vector for the given speed, y velocity and yaw.

### npcf:show_formspec(player_name, id, formspec)

Shows a formspec, similar to minetest.show_formspec() but with the NPC's id included.
Submitted data can then be captured in the NPC's own 'on_receive_fields' callback.

Note that form text fields, dropdown, list and checkbox selections are automatically
stored in the NPC's metadata table. Image/Button clicks, however, are not.

Control Framework
----
## Methods
### npcf.control_framework.getControl(npc_ref)

Constructor for the control object. Returns the reference.
Note, the framework will be activated for NPC on first usage.

### control:stay()
Stop walking, stand up

### control:look_to(pos)
Look (set yaw) to direction of position pos

### control:sit()
Stop walking and sit down

### control:lay()
Stop walking and lay down

### control:mine()
Begin the mining / digging / attacking animation

### control:mine_stop()
Stop the mining / digging / attacking animation

### control:walk(pos, speed, parameter)
Find the way and walk to position pos with given speed.
For parameter check the set_walk_parameter documentation

###control_proto:stop()
Stay and forgot about the destination

### control:set_walk_parameter(parameter)
key-value table to change the walking path determination parameter

  - find_path
    - true (default): the minetest.find_path is used to find the way
    - false: directly way to destination is used

  - find_path_fallback
    - true (default): use directly way if no path found

  - fuzzy_destination
    - true (default): try to find a walkable place nearly destination to get beter results with strict minetest.find_path

  - fuzzy_destination_distance
    - if fuzzy_destination is enabled the fuzzy tolerance in nodes. Default 2 (higher value => more nodes read)

  - find_path_max_distance
    technically setting to limit minetest.find_path distances (save performance) default is 20

  - teleport_on_stuck
    true: if enabled the NPC uses small teleports if stuck detected (destination not reachable).
    Using this option the NPC is able to reach any place
    false: forgot about the destination in case of stuck

## Attributes (should be used read-only)
control.is_mining	- mining animation is active
control.speed		- walking speed
control.real_speed	- The "real" speed calculated on velocity
target_pos - Position vector that the NPC try to reach
