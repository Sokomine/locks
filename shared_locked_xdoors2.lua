-- xDoors² mod by xyz
-- modified by Sokomine to allow locked doors that can only be opened/closed/dig up by the player who placed them
-- a little bit modified by addi to allow someone with the priv "opendoors" to open/close/dig all locked doors. 
-- Sokomine: modified again so that it uses the new locks-mod

local door_bottom = {-0.5, -0.5, -0.5, 0.5, 0.5, -0.4}
local door_top = {
    {-0.5, -0.5, -0.5, -0.3, 0.5, -0.4},
    {0.3, -0.5, -0.5, 0.5, 0.5, -0.4},
    {-0.3, 0.3, -0.5, 0.3, 0.5, -0.4},
    {-0.3, -0.5, -0.5, 0.3, -0.4, -0.4},
    {-0.05, -0.4, -0.5, 0.05, 0.3, -0.4},
    {-0.3, -0.1, -0.5, -0.05, 0, -0.4},
    {0.05, -0.1, -0.5, 0.3, 0, -0.4}
}

local is_top = function(name)
    return name:sub(12, 12) == "t"
end


local xdoors2_transform = function(pos, node, puncher)

    if( not( locks:lock_allow_use( pos, puncher ))) then
      minetest.chat_send_player( puncher:get_player_name(), "This door is locked. It can only be opened by its owner or people with a key that fits.");
      return;
    end

    if is_top(node.name) then
        pos = {x = pos.x, y = pos.y - 1, z = pos.z}
    end
    local t = 3 - node.name:sub(-1)
    local p2 = 0
    if t == 2 then
        p2 = (node.param2 + 1) % 4
    else
        p2 = (node.param2 + 3) % 4
    end
	
    local olddata = locks:get_lockdata( pos );
    minetest.env:add_node(pos, {name = "locks:door_bottom_"..t, param2 = p2})
    minetest.env:add_node({x = pos.x, y = pos.y + 1, z = pos.z}, {name = "locks:door_top_"..t, param2 = p2})

    -- remember who owns the door, what passwords are set etc.
    locks:set_lockdata( pos, olddata );
    locks:set_lockdata( {x = pos.x, y = pos.y + 1, z = pos.z}, olddata );
end


local xdoors2_destruct = function(pos, oldnode)
    if is_top(oldnode.name) then
        pos = {x = pos.x, y = pos.y - 1, z = pos.z}
    end
    minetest.env:remove_node(pos)
    minetest.env:remove_node({x = pos.x, y = pos.y + 1, z = pos.z})
end

for i = 1, 2 do
    minetest.register_node("locks:door_top_"..i, {
        tile_images = {"xdoors2_side.png", "xdoors2_side.png", "xdoors2_top.png", "xdoors2_bottom.png", "xdoors2_top_"..(3 - i)..".png", "xdoors2_top_"..i..".png"},
        paramtype = "light",
        paramtype2 = "facedir",
        drawtype = "nodebox",
        drop = "locks:door",
        groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
        node_box = {
            type = "fixed",
            fixed = door_top
        },
        selection_box = {
            type = "fixed",
            fixed = door_bottom
        },
        on_punch = xdoors2_transform,
        after_dig_node = xdoors2_destruct,

        on_construct = function(pos)
                locks:lock_init( pos,
                               "size[8,2]"..
                               "field[0.3,0.6;6,0.7;locks_sent_lock_command;Locked door. Type /help for help:;]"..
                               "button_exit[6.3,1.2;1.7,0.7;locks_sent_input;Proceed]" );
        end,

        on_receive_fields = function(pos, formname, fields, sender)
                locks:lock_handle_input( pos, formname, fields, sender );
        end,

        can_dig = function(pos,player)
                return locks:lock_allow_dig( pos, player );
        end
    })
    minetest.register_node("locks:door_bottom_"..i, {
        tile_images = {"xdoors2_side.png", "xdoors2_side.png", "xdoors2_top.png", "xdoors2_bottom.png", "locks_xdoors2_bottom_"..(3 - i)..".png", "locks_xdoors2_bottom_"..i..".png"},
        paramtype = "light",
        paramtype2 = "facedir",
        drawtype = "nodebox",
        drop = "locks:door",
        groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
        node_box = {
            type = "fixed",
            fixed = door_bottom
        },
        selection_box = {
            type = "fixed",
            fixed = door_bottom
        },
        on_punch = xdoors2_transform,
        after_dig_node = xdoors2_destruct,

        on_construct = function(pos)
                locks:lock_init( pos,
                               "size[8,2]"..
                               "field[0.3,0.6;6,0.7;locks_sent_lock_command;Locked door. Type /help for help:;]"..
                               "button_exit[6.3,0.2;1.7,0.7;locks_sent_input;Proceed]" );
        end,

        on_receive_fields = function(pos, formname, fields, sender)
                locks:lock_handle_input( pos, formname, fields, sender );
        end,

        can_dig = function(pos,player)
                return locks:lock_allow_dig( pos, player );
        end
    })
end

local delta = {
    {x = -1, z = 0},
    {x = 0, z = 1},
    {x = 1, z = 0},
    {x = 0, z = -1}
}

minetest.register_node("locks:door", {
    description = "Shared locked Wooden Door",
    node_placement_prediction = "",
    inventory_image = 'locks_xdoors2_door.png',
    wield_image = 'xdoors2_door.png',
    stack_max = 1,
    on_place = function(itemstack, placer, pointed_thing)
        local above = pointed_thing.above

        -- there should be 2 empty nodes
        if minetest.env:get_node({x = above.x, y = above.y + 1, z = above.z}).name ~= "air" then
            return itemstack
        end
        
        local fdir = 0
        local placer_pos = placer:getpos()
        if placer_pos then
            dir = {
                x = above.x - placer_pos.x,
                y = above.y - placer_pos.y,
                z = above.z - placer_pos.z
            }
            fdir = minetest.dir_to_facedir(dir)
        end

        local t = 1
        local another_door = minetest.env:get_node({x = above.x + delta[fdir + 1].x, y = above.y, z = above.z + delta[fdir + 1].z})
        if (another_door.name:sub(-1) == "1" and another_door.param2 == fdir)
            or (another_door.name:sub(-1) == "2" and another_door.param2 == (fdir + 1) % 4) then
            t = 2
        end

        minetest.env:add_node(above, {name = "locks:door_bottom_"..t, param2 = fdir})
        minetest.env:add_node({x = above.x, y = above.y + 1, z = above.z}, {name = "locks:door_top_"..t, param2 = fdir})

        -- store who owns the door; the other data can be default for now
        locks:lock_set_owner( above, placer:get_player_name() or "", "Shared locked door");
        locks:lock_set_owner( {x = above.x, y = above.y + 1, z = above.z}, placer:get_player_name() or "", "Shared locked door");

        return ItemStack("")
    end
})


-- if xdoors2 is installed
if( minetest.get_modpath("xdoors2") ~= nil ) then
   minetest.register_craft({
      output = 'locks:door',
      recipe = {
         { 'xdoors2:door', 'locks:lock', '' },
      },
   });

-- if the normal doors are installed
else if( minetest.get_modpath("doors") ~= nil ) then

   minetest.register_craft({
      output = 'locks:door',
      recipe = {
         { 'doors:door_wood', 'locks:lock', '' },
      },
   })

-- fallback if no doors can be found
else
   minetest.register_craft({
      output = 'locks:door',
      recipe = {
         { 'default:wood', 'default:wood', '' },
         { 'default:wood', 'default:wood', 'locks:lock' },
         { 'default:wood', 'default:wood', '' },
      },
   });
end
end -- of previous else



print( "[Mod] locks: loading locks:door");
