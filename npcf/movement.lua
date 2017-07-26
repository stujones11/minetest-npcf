-- NPC framework navigation control object prototype
local mvobj_proto = {
		is_mining = false,
		speed = 0,
		target_pos = nil,
		_path = nil,
		_npc = nil,
		_state = NPCF_ANIM_STAND,
		_step_timer = 0,
		walk_param = {
			find_path = true,
			find_path_fallback = true,
			find_path_max_distance = 20,
			fuzzy_destination = true,
			fuzzy_destination_distance = 5,
			teleport_on_stuck = false,
		}
}

-- navigation control framework
local movement = {
	mvobj_proto = mvobj_proto,
	functions = {},
	getControl = function(npc)
		local mvobj
		if npc._mvobj then
			mvobj = npc._mvobj
		else
			mvobj = npcf.deepcopy(mvobj_proto)
			mvobj._npc = npc
			npc._mvobj = mvobj
		end
		if npc.object and mvobj._step_init_done ~= true then
			mvobj.pos = npc.object:getpos()
			mvobj.yaw = npc.object:getyaw()
			mvobj.velocity = npc.object:getvelocity()
			mvobj.acceleration = npc.object:getacceleration()
			mvobj._step_init_done = true
		end
		return mvobj
	end
}
local functions = movement.functions


-- Stop walking and stand up
function mvobj_proto:stay()
	self.speed = 0
	self._state = NPCF_ANIM_STAND
end

-- Stay and forgot about the way
function mvobj_proto:stop()
	self:stay()
	self._path = nil
	self._target_pos_bak = nil
	self.target_pos = nil
	self._last_distance = nil
end

--  look to position
function mvobj_proto:look_to(pos)
	self.yaw = npcf:get_face_direction(self.pos, pos)
end

-- Stop walking and sitting down
function mvobj_proto:sit()
	self.speed = 0
	self.is_mining = false
	self._state = NPCF_ANIM_SIT
end

-- Stop walking and lay
function mvobj_proto:lay()
	self.speed = 0
	self.is_mining = false
	self._state = NPCF_ANIM_LAY
end

-- Start mining
function mvobj_proto:mine()
	self.is_mining = true
end

-- Stop mining
function mvobj_proto:mine_stop()
	self.is_mining = false
end

--  teleport to position
function mvobj_proto:teleport(pos)
	self.pos = pos
	self._npc.object:setpos(pos)
	self:stay()
end

-- Change default parameters for walking
function mvobj_proto:set_walk_parameter(param)
	for k,v in pairs(param) do
		self.walk_param[k] = v
	end
end

-- start walking to pos
function mvobj_proto:walk(pos, speed, param)
	if param then
		self:set_walk_parameter(param)
	end
	self._target_pos_bak = self.target_pos
	self.target_pos = pos
	self.speed = speed
	if self.walk_param.find_path == true then
		self._path = self:get_path(pos)
	else
		self._path = { pos }
		self._path_used = false
	end

	if self._path == nil then
		self:stop()
		self:look_to(pos)
	else
		self._walk_started = true
	end
end

-- do a walking step
function mvobj_proto:_do_movement_step(dtime)
	-- step timing / initialization check
	self._step_timer = self._step_timer + dtime
	if self._step_timer < 0.1 then
		return
	end
	self._step_timer = 0
	movement.getControl(self._npc)
	self._step_init_done = false

	self:check_for_stuck()

	-- check path
	if self.speed > 0 then
		if not self._path or not self._path[1] then
			self:stop()
		else
			local a = table.copy(self.pos)
			a.y = 0
			local b = {x=self._path[1].x, y=0 ,z=self._path[1].z}
			--print(minetest.pos_to_string(self.pos), minetest.pos_to_string(self._path[1]), vector.distance(a, b),minetest.pos_to_string(self._npc.object:getpos()))
			--if self._path[2] then print(minetest.pos_to_string(self._path[2])) end

			if vector.distance(a, b) < 0.4
					or (self._path[2] and vector.distance(self.pos, self._path[2]) < vector.distance(self._path[1], self._path[2])) then
				if self._path[2] then
					table.remove(self._path, 1)
					self._walk_started = true
				else
					self:stop()
				end
			end
		end
	end
	-- check/set yaw
	if self._path and self._path[1] then
		self.yaw = npcf:get_face_direction(self.pos, self._path[1])
	end
	self._npc.object:setyaw(self.yaw)

	-- check/set animation
	if self.is_mining then
		if self.speed == 0 then
			self._state = NPCF_ANIM_MINE
		else
			self._state = NPCF_ANIM_WALK_MINE
		end
	else
		if self.speed == 0 then
			if self._state ~= NPCF_ANIM_SIT and
					self._state ~= NPCF_ANIM_LAY then
				self._state = NPCF_ANIM_STAND
			end
		else
			self._state = NPCF_ANIM_WALK
		end
	end
	npcf:set_animation(self._npc, self._state)

	-- check for current environment
	local nodepos = table.copy(self.pos)
	local node = {}
	nodepos.y = nodepos.y - 0.5
	for i = -1, 1 do
		node[i] = minetest.get_node(nodepos)
		nodepos.y = nodepos.y + 1
	end
	if string.find(node[-1].name, "^default:water") then
		self.acceleration = {x=0, y=-4, z=0}
		self._npc.object:setacceleration(self.acceleration)
		-- we are walking in water
		if string.find(node[0].name, "^default:water") or
		   string.find(node[1].name, "^default:water") then
			-- we are under water. sink if target bellow the current position. otherwise swim up
			if not self._path or not self._path[1] or self._path[1].y > self.pos.y then
				self.velocity.y = 3
			end
		end
	elseif minetest.find_node_near(self.pos, 2, {"group:water"}) then
		-- Light-footed near water
		self.acceleration = {x=0, y=-1, z=0}
		self._npc.object:setacceleration(self.acceleration)
	elseif minetest.registered_nodes[node[-1].name].walkable ~= false and 
			minetest.registered_nodes[node[0].name].walkable ~= false then
		-- jump if in catched in walkable node
		self.velocity.y = 3
	else
		-- walking
		self.acceleration = {x=0, y=-10, z=0}
		self._npc.object:setacceleration(self.acceleration)
	end

	--check/set velocity
	self.velocity = npcf:get_walk_velocity(self.speed, self.velocity.y, self.yaw)
	self._npc.object:setvelocity(self.velocity)
end


function mvobj_proto:get_path(pos)
	local startpos = vector.round(self.pos)
	startpos.y = startpos.y - 1 -- NPC is to high
	local refpos
	if vector.distance(self.pos, pos) > self.walk_param.find_path_max_distance then
		refpos = vector.add(self.pos, vector.multiply(vector.direction(self.pos, pos), self.walk_param.find_path_max_distance))
	else
		refpos = pos
	end

	local destpos
	if self.walk_param.fuzzy_destination == true then
		destpos = functions.get_walkable_pos(refpos, self.walk_param.fuzzy_destination_distance)
	end
	if not destpos then
		destpos = self.pos
	end
	local path = minetest.find_path(startpos, destpos, 10, 1, 5, "Dijkstra")

	if not path and self.walk_param.find_path_fallback == true then
		path = { destpos, pos }
		self._path_used = false
		--print("fallback path to "..minetest.pos_to_string(pos))
	elseif path then
		--print("calculated path to "..minetest.pos_to_string(destpos).."for destination"..minetest.pos_to_string(pos))
		self._path_used = true
		table.insert(path, pos)
	end
	return path
end

function mvobj_proto:check_for_stuck()

-- high difference stuck
	if self.walk_param.teleport_on_stuck == true and self.target_pos then
		local teleport_dest
		-- Big jump / teleport up- or downsite
		if	math.abs(self.pos.x - self.target_pos.x) <= 1 and
				math.abs(self.pos.z - self.target_pos.z) <= 1 and
				vector.distance(self.pos, self.target_pos) > 3 then
			teleport_dest = table.copy(self.target_pos)
			teleport_dest.y = teleport_dest.y + 1.5 -- teleport over the destination
			--print("big-jump teleport to "..minetest.pos_to_string(teleport_dest).." for target "..minetest.pos_to_string(self.target_pos))
			self:teleport(teleport_dest)
		end
	end

	-- stuck check by distance and speed
	if (self._target_pos_bak and self.target_pos and self.speed > 0 and
			 self._path_used ~= true and self._last_distance and
			self._target_pos_bak.x == self.target_pos.x and
			self._target_pos_bak.y == self.target_pos.y and
			self._target_pos_bak.z == self.target_pos.z and
			self._last_distance -0.01 <= vector.distance(self.pos, self.target_pos)) or
			( self._walk_started ~= true and self.speed > 0 and
			math.sqrt( math.pow(self.velocity.x,2) + math.pow(self.velocity.z,2)) < (self.speed/3)) then
		--print("Stuck")
		if self.walk_param.teleport_on_stuck == true then
			local teleport_dest
			if vector.distance(self.pos, self.target_pos)  > 5 then
				teleport_dest = vector.add(self.pos, vector.multiply(vector.direction(self.pos, self.target_pos), 5)) -- 5 nodes teleport step
			else
				teleport_dest = table.copy(self.target_pos)
				teleport_dest.y = teleport_dest.y + 1.5 -- teleport over the destination
			end
			self:teleport(teleport_dest)
		else
			self:stay()
		end
	elseif self.target_pos then
		self._last_distance = vector.distance(self.pos, self.target_pos)
	end
	self._walk_started = false
end

---------------------------------------------------------------
-- define framework functions internally used
---------------------------------------------------------------
function functions.get_walkable_pos(pos, dist)
	local destpos
	local rpos = vector.round(pos)
	for y = rpos.y+dist-1, rpos.y-dist-1, -1 do
		for x = rpos.x-dist, rpos.x+dist do
			for z = rpos.z-dist, rpos.z+dist do
				local p = {x=x, y=y, z=z}
				local node = minetest.get_node(p)
				local nodedef = minetest.registered_nodes[node.name]
				if not (node.name == "air" or nodedef and (nodedef.walkable == false or nodedef.drawtype == "airlike")) then
					p.y = p.y +1
					local node = minetest.get_node(p)
					local nodedef = minetest.registered_nodes[node.name]
					if node.name == "air" or nodedef and (nodedef.walkable == false or nodedef.drawtype == "airlike") then
						if destpos == nil or vector.distance(p, pos) < vector.distance(destpos, pos) then
							destpos = p
						end
					end
				end
			end
		end
	end
	return destpos
end

---------------------------------------------------------------
-- Return the framework to calling function
---------------------------------------------------------------
return movement
