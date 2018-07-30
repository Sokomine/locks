
-- 25.02.16 Added new Locks config Buttons.
-- allow aborting with ESC in newer Versions of MT again

-- a sign
minetest.register_node("locks:shared_locked_sign_wall", {
        description = "Shared locked sign",
        drawtype = "signlike",
        tiles = {"locks_lock16.png^default_sign_wood.png"},
        inventory_image = "locks_lock16.png^default_sign_wood.png",
        wield_image = "locks_lock16.png^default_sign_wood.png",
        paramtype = "light",
        paramtype2 = "wallmounted",
        sunlight_propagates = true,
        walkable = false,
        selection_box = {
                type = "wallmounted",
                --wall_top = <default>
                --wall_bottom = <default>
                --wall_side = <default>
        },
        groups = {choppy=2,dig_immediate=2},
        legacy_wallmounted = true,


        on_construct = function(pos)
                local meta = minetest.get_meta(pos)
                -- prepare the lock of the sign
                locks:lock_init( pos, 
                                "size[8,4]"..
                                "field[0.3,0.6;6,0.7;text;Text:;${text}]"..
--                                "field[0.3,3.6;6,0.7;locks_sent_lock_command;Locked sign. Type /help for help:;]"..
--								"background[-0.5,-0.5;9,5;bg_shared_locked_sign.jpg]" );
                                "button_exit[6.3,3.2;1.7,0.7;locks_sent_input;Proceed]"..
								locks.uniform_background );
        end,

        after_place_node = function(pos, placer)
                locks:lock_set_owner( pos, placer, "Shared locked sign" );
        end,


        can_dig = function(pos,player)
                return locks:lock_allow_dig( pos, player );
        end,

        on_receive_fields = function(pos, formname, fields, sender)
	
                -- if locks can not  handle the input 
				if not locks:lock_handle_input( pos, formname, fields, sender ) then
					--then handle compatibility stuff or insert text
					if(     fields.text 
                    and ( not(fields.locks_sent_lock_command) --compatibility
                           or fields.locks_sent_lock_command=="") --compatibility
                    and locks:lock_allow_use( pos, sender )) then

                    --print("Sign at "..minetest.pos_to_string(pos).." got "..dump(fields))
                    local meta = minetest.get_meta(pos)
                    fields.text = fields.text or "";
                    print((sender:get_player_name() or "").." wrote \""..fields.text..
                                "\" to sign at "..minetest.pos_to_string(pos));
                    meta:set_string("text", fields.text);
                    meta:set_string("infotext", '"'..fields.text..'"'.." ["..sender:get_player_name().."]");
				end
			end
  
        end,
 });


minetest.register_craft({
   output = 'locks:shared_locked_sign_wall',
   recipe = {
      { 'default:sign_wall', 'locks:lock', '' },
   },
})

print( "[Mod] locks: loading locks:shared_locked_sign_wall");
