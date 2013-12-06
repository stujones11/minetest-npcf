local function show_formspec(self, player_name, selected_id)
	local inv = minetest.get_inventory({type="detached", name="npcf_"..self.npc_name})
	if not inv then
		return
	end
	local trades = {}
	for i,v in ipairs(self.metadata.trades) do
		local avail = self.metadata.inventory[v.item_sell] or 0
		local item_buy = minetest.registered_items[v.item_buy].description or v.item_buy
		local item_sell = minetest.registered_items[v.item_sell].description or v.item_sell
		if item_buy and item_sell then
			local str = item_buy.." ("..v.qty_buy..") - "..item_sell.." ("..v.qty_sell..") ["..avail.."]"
			trades[i] = minetest.formspec_escape(str)
		end
	end
	local tradelist = table.concat(trades, ",") or ""
	local select = ""
	local input = inv:get_stack("input", 1)
	local output = inv:get_stack("output", 1)
	output:clear()
	if selected_id == nil and input:get_count() > 0 then
		for i,v in ipairs(self.metadata.trades) do
			if v.item_buy == input:get_name() then
				selected_id = i
				break
			end
		end
	end
	if selected_id then
		local trade = self.metadata.trades[selected_id]
		if trade then
			if self.owner == player_name then
				local qty_sell = self.metadata.inventory[trade.item_sell] or 0
				local qty_buy = self.metadata.inventory[trade.item_buy] or 0
				output = ItemStack(trade.item_sell.." "..qty_sell)
				input = ItemStack(trade.item_buy.." "..qty_buy)
				inv:set_stack("input", 1, input)
			elseif input:get_name() == trade.item_buy then
				local avail = self.metadata.inventory[trade.item_sell] or 0
				local req = math.floor(input:get_count() / trade.qty_buy) * trade.qty_sell
				if req > avail then
					req = avail
				end
				output = ItemStack(trade.item_sell.." "..req)
			end
			select = selected_id
		end
	end
	inv:set_stack("output", 1, output)
	local formspec = "size[8,10]"
		.."list[detached:npcf_"..self.npc_name..";input;0.0,3.7;1,1;]"
		.."list[detached:npcf_"..self.npc_name..";output;7.0,3.7;1,1;]"
		.."list[current_player;main;0.0,5.0;8.0,4.0;]"
	if self.owner == player_name then
		formspec = formspec
			.."textlist[0.0,0.0;5.7,3.5;inv_select;"..tradelist..";"..select..";]"
			.."field[0.3,9.7;2.0,0.5;item_buy;Item Buy;]"
			.."field[2.3,9.7;1.0,0.5;qty_buy;Qty;]"
			.."field[3.3,9.7;2.0,0.5;item_sell;Item Sell;]"
			.."field[5.3,9.7;1.0,0.5;qty_sell;Qty;]"
			.."button[6.0,9.4;2.0,0.5;trade_add;Add Trade]"
			.."list[detached:npcf_"..self.npc_name..";stock;3.5,3.7;1,1;]"
		if select ~= "" then
			formspec = formspec.."button[6.0,0.0;2.0,0.5;trade_delete_"..select..";Del Trade]"
		end	
	else
		formspec = formspec
			.."textlist[0.0,0.0;7.5,3.5;inv_select;"..tradelist..";"..select..";]"
			.."button_exit[3.0,4.0;2.0,0.5;trade_accept;Accept]"
	end
	npcf:show_formspec(player_name, self.npc_name, formspec)
end

local function get_field_qty(str)
	if str then
		local qty = math.floor(tonumber(str) or 1)
		if qty > 0 then
			return qty
		end
	end
	return 1
end

local function is_valid_item(item)
	if item then
		if item ~= "" then
			return minetest.registered_items[item]
		end
	end
end

npcf:register_npc("npcf:trade_npc" ,{
	description = "Trader NPC",
	mesh = "npcf_deco.x",
	textures = {"npcf_skin_trader.png"},
	nametag_color = "yellow",
	metadata = {
		trades = {},
		inventory = {},
	},
	inventory_image = "npcf_inv_trader_npc.png",
	on_activate = function(self, staticdata, dtime_s)
		local inv = minetest.create_detached_inventory("npcf_"..self.npc_name, {
			on_put = function(inv, listname, index, stack, player)
				local player_name = player:get_player_name()
				if listname == "stock" and self.owner == player_name then
					local item = stack:get_name()
					if self.metadata.inventory[item] then
						self.metadata.inventory[item] = self.metadata.inventory[item] + stack:get_count()
						inv:remove_item("stock", stack)
					end
				end
				show_formspec(self, player_name, nil)
			end,
			on_take = function(inv, listname, index, stack, player)
				if self.owner == player:get_player_name() and (listname == "input" or listname == "output") then
					local item = stack:get_name()
					if self.metadata.inventory[item] then
						self.metadata.inventory[item] = self.metadata.inventory[item] - stack:get_count()
					end
				end
				show_formspec(self, player:get_player_name(), nil)
			end,
			allow_put = function(inv, listname, index, stack, player)
				if listname == "stock" or (listname == "input" and self.owner ~= player:get_player_name()) then
					return stack:get_count()
				end
				return 0
			end,
			allow_take = function(inv, listname, index, stack, player)
				if listname == "input" or self.owner == player:get_player_name() then
					return stack:get_count()
				end
				return 0
			end,
		})
		inv:set_size("input", 1)
		inv:set_size("output", 1)
		inv:set_size("stock", 1)
	end,
	on_rightclick = function(self, clicker)
		show_formspec(self, clicker:get_player_name(), nil)
	end,
	on_receive_fields = function(self, fields, sender)
		local player_name = sender:get_player_name()
		if fields.trade_add and self.owner == player_name then
			if is_valid_item(fields.item_buy) and is_valid_item(fields.item_sell) then
				local trade = {}
				trade["item_buy"] = fields.item_buy
				trade["qty_buy"] = get_field_qty(fields.qty_buy)
				trade["item_sell"] = fields.item_sell
				trade["qty_sell"] = get_field_qty(fields.qty_sell)
				table.insert(self.metadata.trades, trade)
				self.metadata.inventory[fields.item_buy] = self.metadata.inventory[fields.item_buy] or 0
				self.metadata.inventory[fields.item_sell] = self.metadata.inventory[fields.item_sell] or 0
				show_formspec(self, player_name, nil)
			else
				minetest.chat_send_player(player_name, "Error: Invalid Item Name!")
			end
		elseif fields.inv_select then
			local id = tonumber(string.match(fields.inv_select, "%d+"))
			if id then
				show_formspec(self, player_name, id)
			end
		elseif fields.trade_accept then
			local inv = minetest.get_inventory({type="detached", name="npcf_"..self.npc_name})
			local input = inv:get_stack("input", 1)
			local output = inv:get_stack("output", 1)
			local item_buy = input:get_name()
			local item_sell = output:get_name()
			local qty_buy = input:get_count()
			local qty_sell = output:get_count()
			local max = output:get_stack_max()
			if qty_buy > 0 and qty_sell > 0 and max > 0 then
				self.metadata.inventory[item_buy] = self.metadata.inventory[item_buy] + qty_buy
				self.metadata.inventory[item_sell] = self.metadata.inventory[item_sell] - qty_sell
				while qty_sell > max do
					sender:get_inventory():add_item("main", item_sell.." "..max)
					qty_sell = qty_sell - max
				end
				if qty_sell > 0 then
					sender:get_inventory():add_item("main", item_sell.." "..qty_sell)
				end
				input:clear()
				inv:set_stack("input", 1, input)
			end
		elseif self.owner == player_name then
			for k,_ in pairs(fields) do
				selected_id = k:gsub("trade_delete_", "")
				if selected_id ~= k and self.metadata.trades[tonumber(selected_id)] then
					local inv = minetest.get_inventory({type="detached", name="npcf_"..self.npc_name})
					inv:set_stack("input", 1, ItemStack(""))
					table.remove(self.metadata.trades, selected_id)
					show_formspec(self, player_name, nil)
					break
				end
			end
		end
	end,
})

