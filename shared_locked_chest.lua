
minetest.register_node("locks:shared_locked_chest", {
       description = "Shared locked chest",
        tiles = {"default_chest_top.png", "default_chest_top.png", "default_chest_side.png",
                "default_chest_side.png", "default_chest_side.png", "default_chest_front.png"},
        paramtype2 = "facedir",
        groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
        legacy_facedir_simple = true,

        on_construct = function(pos)
                local meta = minetest.env:get_meta(pos)
                -- prepare the lock of the chest
                locks:lock_init( pos, 
                                "size[8,10]"..
--                                "field[0.5,0.2;8,1.0;locks_sent_lock_command;Locked chest. Type password, command or /help for help:;]"..
--                                "button_exit[3,0.8;2,1.0;locks_sent_input;Proceed]"..
                                "list[current_name;main;0,0;8,4;]"..
                                "list[current_player;main;0,5;8,4;]"..
                                "field[0.3,9.6;6,0.7;locks_sent_lock_command;Locked chest. Type /help for help:;]"..
                                "button_exit[6.3,9.2;1.7,0.7;locks_sent_input;Proceed]" );
--                                "size[8,9]"..
--                                "list[current_name;main;0,0;8,4;]"..
--                                "list[current_player;main;0,5;8,4;]");
                local inv = meta:get_inventory()
                inv:set_size("main", 8*4)
        end,

        after_place_node = function(pos, placer)
                locks:lock_set_owner( pos, placer, "Shared locked chest" );
        end,


        can_dig = function(pos,player)
               
                if( not(locks:lock_allow_dig( pos, player ))) then
                   return false;
                end
                local meta = minetest.env:get_meta(pos);
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


})

minetest.register_craft({
   output = 'locks:shared_locked_chest',
   recipe = {
      { 'default:chest', 'locks:lock', '' },
   },
})

print( "[Mod] locks: loading locks:shared_locked_chest");
