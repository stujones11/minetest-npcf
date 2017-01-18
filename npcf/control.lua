-- NPC framework navigation control object prototype
local control_proto = {
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
local control_framework = {
	control_proto = control_proto,
	functions = {},
	getControl = function(npc)
		local control
		if npc._control then
			control = npc._control
		else
			control = npcf.deepcopy(control_proto)
			control._npc = npc
			npc._control = control
		end
		if npc.object and control._step_init_done ~= true then
			control.pos = npc.object:getpos()
			control.yaw = npc.object:getyaw()
			control.velocity = npc.object:getvelocity()
			control.acceleration = npc.object:getacceleration()
			control._step_init_done = true
		end
		return control
	end
}
local functions = control_framework.functions


-- Stop walking and stand up
function control_proto:stay()
	self.speed = 0
	self._state = NPCF_ANIM_STAND
end

-- Stay and forgot about the way
function control_proto:stop()
	self:stay()
	self._path = nil
	self._target_pos_bak = nil
	self.target_pos = nil
	self._last_distance = nil
end

--  look to position
function control_proto:look_to(pos)
	self.yaw = npcf:get_face_direction(self.pos, pos)
end

-- Stop walking and sitting down
function control_proto:sit()
	self.speed = 0
	self.is_mining = false
	self._state = NPCF_ANIM_SIT
end

-- Stop walking and lay
function control_proto:lay()
	self.speed = 0
	self.is_mining = false
	self._state = NPCF_ANIM_LAY
end

-- Start mining
function control_proto:mine()
	self.is_mining = true
end

-- Stop mining
function control_proto:mine_stop()
	self.is_mining = false
end

-- Change default parameters for walking
function control_proto:set_walk_parameter(param)
	for k,v in pairs(param) do
		self.walk_param[k] = v
	end
end

-- start walking to pos
function control_proto:walk(pos, speed, param)
	if param then
		self:set_walk_parameter(param)
	end
	self._target_pos_bak = self.target_pos
	self.target_pos = pos
	self.speed = speed
	if self.walk_param.find_path == true then
		self._path = functions.get_path(self, pos)
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
function control_proto:_do_control_step(dtime)
	-- step timing / initialization check
	self._step_timer = self._step_timer + dtime
	if self._step_timer < 0.1 then
		return
	end
	self._step_timer = 0
	control_framework.getControl(self._npc)
	self._step_init_done = false

	functions.check_for_stuck(self)

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
			if not self._path[1] or self._path[1].y > self.pos.y then
				self.velocity.y = 3
			end
		end
	elseif minetest.find_node_near(self.pos, 2, {"group:water"}) then
		-- Light-footed near water
		self.acceleration = {x=0, y=-1, z=0}
		self._npc.object:setacceleration(self.acceleration)
	elseif minetest.registered_nodes[node[-1].name].walkable ~= false and 
			minetest.registered_nodes[node[0].name].walkable ~= false then
		print("up!")
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

function functions.get_path(control, pos)
	local startpos = vector.round(control.pos)
	startpos.y = startpos.y - 1 -- NPC is to high
	local refpos
	if vector.distance(control.pos, pos) > control.walk_param.find_path_max_distance then
		refpos = vector.add(control.pos, vector.multiply(vector.direction(control.pos, pos), control.walk_param.find_path_max_distance))
	else
		refpos = pos
	end

	local destpos
	if control.walk_param.fuzzy_destination == true then
		destpos = functions.get_walkable_pos(refpos, control.walk_param.fuzzy_destination_distance)
	end
	if not destpos then
		destpos = control.pos
	end
	local path = minetest.find_path(startpos, destpos, 10, 1, 5, "Dijkstra")

	if not path and control.walk_param.find_path_fallback == true then
		path = { destpos, pos }
		control._path_used = false
		print("fallback path to", minetest.pos_to_string(pos))
	elseif path then
		print("calculated path to", minetest.pos_to_string(destpos), minetest.pos_to_string(pos))
		control._path_used = true
		table.insert(path, pos)
	end
	return path
end

function functions.check_for_stuck(control)

-- high difference stuck
	if control.walk_param.teleport_on_stuck == true and control.target_pos then
		local teleport_dest
		-- Big jump / teleport up- or downsite
		if	math.abs(control.pos.x - control.target_pos.x) <= 1 and
				math.abs(control.pos.z - control.target_pos.z) <= 1 and
				vector.distance(control.pos, control.target_pos) > 3 then
			teleport_dest = table.copy(control.target_pos)
			teleport_dest.y = teleport_dest.y + 1.5 -- teleport over the destination
			control.pos = teleport_dest
			control._npc.object:setpos(control.pos)
			control:stay()
			print("big-jump teleport to", minetest.pos_to_string(teleport_dest), "for", minetest.pos_to_string(control.target_pos))
		end
	end

	-- stuck check by distance and speed
	if (control._target_pos_bak and control.target_pos and control.speed > 0 and 
			 control._path_used ~= true and control._last_distance and
			control._target_pos_bak.x == control.target_pos.x and
			control._target_pos_bak.y == control.target_pos.y and
			control._target_pos_bak.z == control.target_pos.z and
			control._last_distance -0.01 <= vector.distance(control.pos, control.target_pos)) or
			( control._walk_started ~= true and control.speed > 0 and 
			math.sqrt( math.pow(control.velocity.x,2) + math.pow(control.velocity.z,2)) < (control.speed/3)) then
		print("Stuck")
		if control.walk_param.teleport_on_stuck == true then
			local teleport_dest
			if vector.distance(control.pos, control.target_pos)  > 5 then
				teleport_dest = vector.add(control.pos, vector.multiply(vector.direction(control.pos, control.target_pos), 5)) -- 5 nodes teleport step
			else
				teleport_dest = table.copy(control.target_pos)
				teleport_dest.y = teleport_dest.y + 1.5 -- teleport over the destination
			end
			control.pos = teleport_dest
			control._npc.object:setpos(control.pos)
			control:stay()
		else
			control:stay()
		end
	elseif control.target_pos then 
		control._last_distance = vector.distance(control.pos, control.target_pos)
	end
	control._walk_started = false
end
---------------------------------------------------------------
-- Return the framework to calling function
---------------------------------------------------------------
return control_framework
