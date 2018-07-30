
-- this is a (slightly!) modified copy of minetest_game/mods/default/nodes.lua,
-- containing only the furnace and adopted slightly for my locks mod


-- 25.02.16 Added new Locks config Buttons.
-- 09.01.13 Added support for pipeworks.


locks.furnace_add = {};
locks.furnace_add.tiles_normal = {"default_furnace_top.png", "default_furnace_bottom.png", "default_furnace_side.png",
		"default_furnace_side.png", "default_furnace_side.png", "default_furnace_front.png"};
locks.furnace_add.tiles_active = {"default_furnace_top.png", "default_furnace_bottom.png", "default_furnace_side.png",
		"default_furnace_side.png", "default_furnace_side.png", --"default_furnace_front_active.png"};
		{
			image = "default_furnace_front_active.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1.5
			},
		}};
locks.furnace_add.groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2};
locks.furnace_add.tube   = {};

-- additional/changed definitions for pipeworks;
-- taken from pipeworks/compat.lua
if( locks.pipeworks_enabled ) then

   locks.furnace_add.tiles_normal = {
	"default_furnace_top.png^pipeworks_tube_connection_stony.png",
	"default_furnace_bottom.png^pipeworks_tube_connection_stony.png",
	"default_furnace_side.png^pipeworks_tube_connection_stony.png",
	"default_furnace_side.png^pipeworks_tube_connection_stony.png",
	"default_furnace_side.png^pipeworks_tube_connection_stony.png",
	"default_furnace_front.png" };


   locks.furnace_add.tiles_active = {
	"default_furnace_top.png^pipeworks_tube_connection_stony.png",
	"default_furnace_bottom.png^pipeworks_tube_connection_stony.png",
	"default_furnace_side.png^pipeworks_tube_connection_stony.png",
	"default_furnace_side.png^pipeworks_tube_connection_stony.png",
	"default_furnace_side.png^pipeworks_tube_connection_stony.png",
	{
		image = "default_furnace_front_active.png",
		backface_culling = false,
		animation = {
			type = "vertical_frames",
			aspect_w = 16,
			aspect_h = 16,
			length = 1.5
		},
	}};
--	"default_furnace_front_active.png" };


   locks.furnace_add.groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2,
	tubedevice = 1, tubedevice_receiver = 1 };
   locks.furnace_add.tube = {
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if direction.y == 1 then
				return inv:add_item("fuel",stack)
			else
				return inv:add_item("src",stack)
			end
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if direction.y == 1 then
				return inv:room_for_item("fuel", stack)
			else
				return inv:room_for_item("src", stack)
			end
		end,
		input_inventory = "dst",
		connect_sides = {left=1, right=1, back=1, front=1, bottom=1, top=1}
	};
end


function locks.get_furnace_active_formspec(pos, percent)
	local formspec =
		"size[8,9]"..
		"image[2,1.5;1,1;default_furnace_fire_bg.png^[lowpart:"..
		(100-percent)..":default_furnace_fire_fg.png]"..
		"list[current_name;fuel;2,2.5;1,1;]"..
		"list[current_name;src;2,0.5;1,1;]"..
		"list[current_name;dst;5,1;2,2;]"..
		"list[current_player;main;0,5;8,4;]"..
		locks.uniform_background..
		locks.get_authorize_button(6,0)..
		locks.get_config_button(7,0)
		
	return formspec
end

locks.furnace_inactive_formspec =
	"size[8,9]"..
	"image[2,1.5;1,1;default_furnace_fire_bg.png]"..
	"list[current_name;fuel;2,2.5;1,1;]"..
	"list[current_name;src;2,0.5;1,1;]"..
	"list[current_name;dst;5,1;2,2;]"..
	"list[current_player;main;0,5;8,4;]"..
	locks.uniform_background..
	locks.get_authorize_button(6,0)..
	locks.get_config_button(7,0)

minetest.register_node("locks:shared_locked_furnace", {
	description = "Shared locked furnace",
	paramtype2 = "facedir",
	groups = {cracky=2},
	legacy_facedir_simple = true,

	tiles      = locks.furnace_add.tiles_normal,
        groups     = locks.furnace_add.groups,
	tube       = locks.furnace_add.tube,

--	sounds = default.node_sound_stone_defaults(),
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
                locks:lock_init( pos, locks.furnace_inactive_formspec)
		meta:set_string("infotext", "Shared locked furnace")
		local inv = meta:get_inventory()
		inv:set_size("fuel", 1)
		inv:set_size("src", 1)
		inv:set_size("dst", 4)
	end,

	after_place_node = function(pos, placer)
                if( locks.pipeworks_enabled ) then              
		   pipeworks.scan_for_tube_objects(pos)
                end
                locks:lock_set_owner( pos, placer, "Shared locked furnace" );
	end,
	after_dig_node = function(pos)
                if( locks.pipeworks_enabled ) then              
		   pipeworks.scan_for_tube_objects(pos)
                end
	end,

	can_dig = function(pos,player)
                if( not(locks:lock_allow_dig( pos, player ))) then
                   return false;
                end
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		if not inv:is_empty("fuel") then
			return false
		elseif not inv:is_empty("dst") then
			return false
		elseif not inv:is_empty("src") then
			return false
		end
		return true
	end,
        on_receive_fields = function(pos, formname, fields, sender)
                locks:lock_handle_input( pos, formname, fields, sender );
        end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if listname == "fuel" then
			if minetest.get_craft_result({method="fuel",width=1,items={stack}}).time ~= 0 then
				if inv:is_empty("src") then
					meta:set_string("infotext","Furnace is empty")
				end
				return stack:get_count()
			else
				return 0
			end
		elseif listname == "src" then
			return stack:get_count()
		elseif listname == "dst" then
			return 0
		end
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local stack = inv:get_stack(from_list, from_index)
		if to_list == "fuel" then
			if minetest.get_craft_result({method="fuel",width=1,items={stack}}).time ~= 0 then
				if inv:is_empty("src") then
					meta:set_string("infotext","Furnace is empty")
				end
				return count
			else
				return 0
			end
		elseif to_list == "src" then
			return count
		elseif to_list == "dst" then
			return 0
		end
        end,
        allow_metadata_inventory_take = function(pos, listname, index, stack, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
                return stack:get_count()
	end,
})

minetest.register_node("locks:shared_locked_furnace_active", {
	description = "Furnace",
	paramtype2 = "facedir",
	light_source = 8,
	drop = "locks:shared_locked_furnace",
	groups = {cracky=2, not_in_creative_inventory=1},
	legacy_facedir_simple = true,

	tiles      = locks.furnace_add.tiles_active,
        groups     = locks.furnace_add.groups,
	tube       = locks.furnace_add.tube,

--	sounds = default.node_sound_stone_defaults(),
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
                locks:lock_init( pos, locks.furnace_inactive_formspec)
		meta:set_string("infotext", "Shared locked furnace");
		local inv = meta:get_inventory()
		inv:set_size("fuel", 1)
		inv:set_size("src", 1)
		inv:set_size("dst", 4)
	end,
	can_dig = function(pos,player)
                if( not(locks:lock_allow_dig( pos, player ))) then
                   return false;
                end
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		if not inv:is_empty("fuel") then
			return false
		elseif not inv:is_empty("dst") then
			return false
		elseif not inv:is_empty("src") then
			return false
		end
		return true
	end,

	after_place_node = function(pos, placer)
                if( locks.pipeworks_enabled ) then              
		   pipeworks.scan_for_tube_objects(pos)
                end
                locks:lock_set_owner( pos, placer, "Shared locked furnace (active)" );
	end,
	after_dig_node = function(pos)
                if( locks.pipeworks_enabled ) then              
		   pipeworks.scan_for_tube_objects(pos)
                end
        end,

        on_receive_fields = function(pos, formname, fields, sender)
                locks:lock_handle_input( pos, formname, fields, sender );
        end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if listname == "fuel" then
			if minetest.get_craft_result({method="fuel",width=1,items={stack}}).time ~= 0 then
				if inv:is_empty("src") then
					meta:set_string("infotext","Shared locked furnace (empty)")
				end
				return stack:get_count()
			else
				return 0
			end
		elseif listname == "src" then
			return stack:get_count()
		elseif listname == "dst" then
			return 0
		end
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local stack = inv:get_stack(from_list, from_index)
		if to_list == "fuel" then
			if minetest.get_craft_result({method="fuel",width=1,items={stack}}).time ~= 0 then
				if inv:is_empty("src") then
					meta:set_string("infotext","Shared locked furnace (empty)")
				end
				return count
			else
				return 0
			end
		elseif to_list == "src" then
			return count
		elseif to_list == "dst" then
			return 0
		end
	end,
        allow_metadata_inventory_take = function(pos, listname, index, stack, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
                return stack:get_count()
        end,
})

-- better make this a function specific to this mod to avoid trouble with the same function in default
locks.hacky_swap_node = function(pos,name)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local meta0 = meta:to_table()
	if node.name == name then
		return
	end
	node.name = name
	local meta0 = meta:to_table()
	minetest.set_node(pos,node)
	meta = minetest.get_meta(pos)
	meta:from_table(meta0)
end

minetest.register_abm({
	nodenames = {"locks:shared_locked_furnace","locks:shared_locked_furnace_active"},
	interval = 1.0,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.get_meta(pos)
		for i, name in ipairs({
				"fuel_totaltime",
				"fuel_time",
				"src_totaltime",
				"src_time"
		}) do
			if meta:get_string(name) == "" then
				meta:set_float(name, 0.0)
			end
		end

		local inv = meta:get_inventory()

		local srclist = inv:get_list("src")
		local cooked = nil
		local aftercooked
		
		if srclist then
			cooked, aftercooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
		end
		
		local was_active = false
		
		if meta:get_float("fuel_time") < meta:get_float("fuel_totaltime") then
			was_active = true
			meta:set_float("fuel_time", meta:get_float("fuel_time") + 1)
			meta:set_float("src_time", meta:get_float("src_time") + 1)
			if cooked and cooked.item and meta:get_float("src_time") >= cooked.time then
				-- check if there's room for output in "dst" list
				if inv:room_for_item("dst",cooked.item) then
					-- Put result in "dst" list
					inv:add_item("dst", cooked.item)
					-- take stuff from "src" list
					inv:set_stack("src", 1, aftercooked.items[1])
				else
					print("Could not insert '"..cooked.item:to_string().."'")
				end
				meta:set_string("src_time", 0)
			end
		end
		
		if meta:get_float("fuel_time") < meta:get_float("fuel_totaltime") then
			local percent = math.floor(meta:get_float("fuel_time") /
					meta:get_float("fuel_totaltime") * 100)
			meta:set_string("infotext","Shared locked furnace active: "..percent.."%")
			locks.hacky_swap_node(pos,"locks:shared_locked_furnace_active")
			meta:set_string("formspec",locks.get_furnace_active_formspec(pos, percent))
			return
		end

		local fuel = nil
		local afterfuel
		local cooked = nil
		local fuellist = inv:get_list("fuel")
		local srclist = inv:get_list("src")
		
		if srclist then
			cooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
		end
		if fuellist then
			fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist})
		end

		if not( fuel) or fuel.time <= 0 then
			meta:set_string("infotext","Shared locked furnace out of fuel")
			locks.hacky_swap_node(pos,"locks:shared_locked_furnace")
			meta:set_string("formspec", locks.furnace_inactive_formspec)
			return
		end

		if cooked.item:is_empty() then
			if was_active then
				meta:set_string("infotext","Shared locked furnace is empty")
				locks.hacky_swap_node(pos,"locks:shared_locked_furnace")
				meta:set_string("formspec", locks.furnace_inactive_formspec)
			end
			return
		end

		meta:set_string("fuel_totaltime", fuel.time)
		meta:set_string("fuel_time", 0)
		
		inv:set_stack("fuel", 1, afterfuel.items[1])
	end,
})


minetest.register_craft({
   output = 'locks:shared_locked_furnace',
   recipe = {
      { 'default:furnace', 'locks:lock', '' },
   },
})

print( "[Mod] locks: loading locks:shared_locked_furnace");


