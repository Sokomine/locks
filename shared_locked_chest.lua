-- 25.02.16 Added new Locks config Buttons.
-- 09.01.13 Added support for pipeworks.


locks.chest_add = {};
locks.chest_add.tiles  = {"default_chest_top.png", "default_chest_top.png", "default_chest_side.png",
                "default_chest_side.png", "default_chest_side.png", "default_chest_front.png^locks_lock16.png"};
locks.chest_add.groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2};
locks.chest_add.tube   = {};

-- additional/changed definitions for pipeworks;
-- taken from pipeworks/compat.lua
if( locks.pipeworks_enabled ) then
   locks.chest_add.tiles = {
	"default_chest_top.png^pipeworks_tube_connection_wooden.png",
	"default_chest_top.png^pipeworks_tube_connection_wooden.png",
	"default_chest_side.png^pipeworks_tube_connection_wooden.png",
	"default_chest_side.png^pipeworks_tube_connection_wooden.png",
	"default_chest_side.png^pipeworks_tube_connection_wooden.png",
	"default_chest_front.png^locks_lock16.png"};
   locks.chest_add.groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2,
	tubedevice = 1, tubedevice_receiver = 1 };
   locks.chest_add.tube = {
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("main", stack)
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:room_for_item("main", stack)
		end,
		input_inventory = "main",
		connect_sides = {left=1, right=1, back=1, front=1, bottom=1, top=1}
	};
end


minetest.register_node("locks:shared_locked_chest", {
       description = "Shared locked chest",
	tiles      = locks.chest_add.tiles,
        paramtype2 = "facedir",
        groups     = locks.chest_add.groups,
	tube       = locks.chest_add.tube,
        legacy_facedir_simple = true,

        on_construct = function(pos)
                local meta = minetest.get_meta(pos)
                -- prepare the lock of the chest
                locks:lock_init( pos, 
                                "size[8,10]"..
----                                "field[0.5,0.2;8,1.0;locks_sent_lock_command;Locked chest. Type password, command or /help for help:;]"..
----                                "button_exit[3,0.8;2,1.0;locks_sent_input;Proceed]"..
--                                "list[current_name;main;0,0;8,4;]"..
--                                "list[current_player;main;0,5;8,4;]"..
--                                "field[0.3,9.6;6,0.7;locks_sent_lock_command;Locked chest. Type /help for help:;]"..
--								"background[-0.5,-0.65;9,11.2;bg_shared_locked_chest.jpg]"..
--                                "button_exit[6.3,9.2;1.7,0.7;locks_sent_input;Proceed]" );
----                                "size[8,9]"..
----                                "list[current_name;main;0,0;8,4;]"..
----                                "list[current_player;main;0,5;8,4;]");
				locks.uniform_background ..
				"list[current_name;main;0,1;8,4;]"..
				"list[current_player;main;0,5.85;8,1;]" ..
				"list[current_player;main;0,7.08;8,3;8]" ..
				"listring[current_name;main]" ..
				"listring[current_player;main]" ..
				default.get_hotbar_bg(0,5.85) );

                local inv = meta:get_inventory()
                inv:set_size("main", 8*4)
        end,

        after_place_node = function(pos, placer)

                if( locks.pipeworks_enabled ) then
		   pipeworks.scan_for_tube_objects( pos );
                end

                locks:lock_set_owner( pos, placer, "Shared locked chest" );
        end,


        can_dig = function(pos,player)
               
                if( not(locks:lock_allow_dig( pos, player ))) then
                   return false;
                end
                local meta = minetest.get_meta(pos);
                local inv = meta:get_inventory()
                return inv:is_empty("main")
        end,

        on_receive_fields = function(pos, formname, fields, sender)
                locks:lock_handle_input( pos, formname, fields, sender );
        end,
 
 

        allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
                return count;
        end,
        allow_metadata_inventory_put = function(pos, listname, index, stack, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
                return stack:get_count()
        end,
        allow_metadata_inventory_take = function(pos, listname, index, stack, player)
                if( not( locks:lock_allow_use( pos, player ))) then
                   return 0;
                end
                return stack:get_count()
        end,
        on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
                minetest.log("action", player:get_player_name()..
                                " moves stuff in locked shared chest at "..minetest.pos_to_string(pos))
        end,
        on_metadata_inventory_put = function(pos, listname, index, stack, player)
                minetest.log("action", player:get_player_name()..
                                " moves stuff to locked shared chest at "..minetest.pos_to_string(pos))
        end,
        on_metadata_inventory_take = function(pos, listname, index, stack, player)
                minetest.log("action", player:get_player_name()..
                                " takes stuff from locked shared chest at "..minetest.pos_to_string(pos))
        end,


	after_dig_node = function( pos )
                if( locks.pipeworks_enabled ) then              
		   pipeworks.scan_for_tube_objects(pos)
                end
	end
})

minetest.register_craft({
   output = 'locks:shared_locked_chest',
   recipe = {
      { 'default:chest', 'locks:lock', '' },
   },
})

print( "[Mod] locks: loading locks:shared_locked_chest");
