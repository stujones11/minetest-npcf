Mod - NPC Framework [npcf]
-------------------------------

License Source Code: 2013 Stuart Jones - LGPL v2.1

License Textures: WTFPL

Depends: default

This mod adds some, hopefully useful, non-player characters to the minetest game.
The mod also provides a framework for others to create and manage their own custom NPCs.

Features currently include overhead titles, formspec handling, ownership, chat command management
and file based back-ups. Some example NPC mods have been included as part of the modpack.

The example NPC's are not craftable although by default will be available in the creative mode menu.
Server operators would be advised to override this default behaviour and allocate the NPCs on /give basis.

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

* setpos     <npc_id> <pos>
* setlook    <npc_id> <angle> (0-360)
* titletext  <npc_id> <text>
* titlecolor <npc_id> <color> (#RRGGBB)
* tell       <npc_id> <args>
* setskin    <npc_id> <filename>
* delete     <npc_id>
* unload     <npc_id>
* load       <npc_id>
* save       <npc_id>
  getpos     <npc_id>
* clearobjects (admin only)
  list
  help (show this message)
  
* Ownership or server priv required

