-- NPC framework navigation control prototype
local control_proto = {
		is_mining = false,
		speed = 0,
		path = {},
		_npc = nil,
		_state = NPCF_ANIM_STAND,
		_step_timer = 0
}

-- navigation control framework
local control_framework = {
	control_proto = control_proto,
	getControl = function(npc)
		local control
		if npc._control then
			control = npc._control
		else
			control = npcf.deepcopy(control_proto)
			control._npc = npc
			npc._control = control
			control.walk_param = {
				find_path = true,
				direct_way = true,
				max_find_path_distance = 25
			}
		end
		if control._step_init_done ~= true then
			control.pos = npc.object:getpos()
			control._pos_bak = control.pos
			control.yaw = npc.object:getyaw()
			control._yaw_bak = control.yaw
			control.velocity = npc.object:getvelocity()
			control.acceleration = npc.object:getacceleration()
			control._acceleration_bak = control.acceleration
			control._velocity_bak = control.velocity
			control._state_bak = control.state
			control._speed_bak = control.speed
			control._dest_bak = control.path[1]
			control._step_init_done = true
		end
		return control
	end
}

-- Stop walking and stand up
function control_proto:stay()
	self.speed = 0
	self._state = NPCF_ANIM_STAND
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
function control_proto:walk(pos, speed)
	self.speed = speed
	if self.walk_param.find_path == true and vector.distance(self.pos, pos) < self.walk_param.max_find_path_distance then
		local startpos = vector.round(self.pos)
		startpos.y = startpos.y - 1

		local destpos = table.copy(pos)
		-- use the high of the first non-walkable node (air)
		for i = pos.y + 1, pos.y - 1, -1 do
			destpos.y = i
			local node = minetest.get_node(destpos)
			local nodedef = minetest.registered_nodes[node.name]
			if not (node.name == "air" or nodedef and (nodedef.walkable == false or nodedef.drawtype == "airlike")) then
				destpos.y = destpos.y +1
				break
			end
		end
		local path = minetest.find_path(startpos, destpos, 10, 1, 5, "Dijkstra")
		self.path = path
		if not self.path or not self.path[1] and self.walk_param.direct_way == true then
			self.path = { pos }
		end
	elseif self.walk_param.direct_way == true then
		self.path = { pos }
	end
	if not self.path then
		self:stay()
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
	if self._step_init_done == true then
		control_framework.getControl(self._npc)
		self._step_init_done = false
	end

	-- check path
	if self.speed > 0 then
		if not self.path or not self.path[1] then
			self:stay()
		else
			local a = table.copy(self.pos)
			a.y = 0
			local b = {x=self.path[1].x, y=0 ,z=self.path[1].z}
			print(minetest.pos_to_string(self.pos), minetest.pos_to_string(self.path[1]), vector.distance(a, b),minetest.pos_to_string(self._npc.object:getpos()))
			if self.path[2] then print(minetest.pos_to_string(self.path[2])) end

			if vector.distance(a, b) < 0.4
					or (self.path[2] and vector.distance(self.pos, self.path[2]) < vector.distance(self.path[1], self.path[2])) then
				local old_dest = self.path[1]
				table.remove(self.path, 1)
				if not self.path[1] then
					self:look_to(old_dest)
					self:stay()
				end
			end
		end
	end
	-- check/set yaw
	if self.path[1] then
		self.yaw = npcf:get_face_direction(self.pos, self.path[1])
	end
	if self.yaw  ~= self._yaw_bak then
		self._npc.object:setyaw(self.yaw)
	end
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
	if self._state ~= self._state_bak then
		npcf:set_animation(self._npc, self._state)
	end

	-- check for water
	local nodepos = table.copy(self.pos)
	local node = {}
	nodepos.y = nodepos.y - 0.5
	for i = -1, 1 do
		node[i] = minetest.get_node(nodepos)
		nodepos.y = nodepos.y + 1
	end
	if string.find(node[-1].name, "^default:water") then
		self.acceleration = {x=0, y=-4, z=0}
		-- we are walking in water
		if string.find(node[0].name, "^default:water") or
		   string.find(node[1].name, "^default:water") then
			-- we are under water. sink if target bellow the current position. otherwise swim up
			if not self.path[1] or self.path[1].y > self.pos.y then
				self.velocity.y = 3
			end
		end
	elseif minetest.find_node_near(self.pos, 2, {"group:water"}) then
		-- Light-footed near water
		self.acceleration = {x=0, y=-1, z=0}
	else
		-- walking - check for jump
		self.acceleration = {x=0, y=-10, z=0}
	end
	if self.acceleration.y ~= self._acceleration_bak.y then
		self._npc.object:setacceleration(self.acceleration)
	end

	--check/set velocity
	self.velocity = npcf:get_walk_velocity(self.speed, self.velocity.y, self.yaw)
	self._npc.object:setvelocity(self.velocity)
end

return control_framework
