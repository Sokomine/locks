

locks = {};

minetest.register_privilege("openlocks", { description = "allows to open/use all locked objects", give_to_singleplayer = false});
minetest.register_privilege("diglocks",  { description = "allows to open/use and dig up all locked objects", give_to_singleplayer = false});

-- initializes a lock (that is: prepare the metadata so that it can store data)
--  default_formspec is the formspec that will be used on right click; the input field for the commands will be added
-- Call this in on_construct in register_node. Excample:
--        on_construct = function(pos)
--              locks:lock_init( pos, "" );
--        end;

function locks:lock_init( pos, default_formspec )

   if( pos == nil ) then
      print( "Error: [locks] lock_init: pos is nil");
      return;
   end

   local meta = minetest.env:get_meta(pos);
   if( meta == nil ) then
      print( "Error: [locks] lock_init: unable to get meta data");
      return;
   end

   -- this will be changed after the node is placed
   meta:set_string("infotext", "Locked object");
   -- prepare the field for the owner
   meta:set_string("owner", "");
   -- this is the list of players/groups that may unlock the lock even if they are not the owner
   meta:set_string("allowed_users","");
   -- objects can be unlocked by passwords as well (if it is set)
   meta:set_string("password","");
   -- the last player who entered the right password (to save space this is not a list)
   meta:set_string("pw_user","");
   -- this formspec is presented on right-click when the user has access
   meta:set_string("default_formspec",default_formspec);
   -- just to be sure...
   meta:set_string("formspec",        default_formspec);
end



-- Set the owner of the locked object.
-- Call this in after_place_node in register_node. Example:
--        after_place_node = function(pos, placer)
--                locks:lock_set_owner( pos, placer );
--        end,
function locks:lock_set_owner( pos, player_or_name )

   if( pos == nil or player_or_name == nil ) then
      print( "Error: [locks] Missing/wrong parameters to lock_set_owner");
      return false;
   end
   
   local meta = minetest.env:get_meta(pos);
   if( meta == nil ) then
      print( "Error: [locks] lock_set_owner: unable to get meta data");
      return;
   end

   -- accepts a name or a player object
   if( type( player_or_name )~="string") then
      player_or_name = player_or_name:get_player_name();
   end

   meta:set_string("owner", player_or_name or "");
   -- TODO: not very convincing...has to carry the name of the object
   meta:set_string("infotext", "Locked object (owned by "..meta:get_string("owner")..")");
end


  
-- The locked object can only be digged by the owner OR by people with the diglocks priv
-- Call this in can_dig in register_node. Example:
--        can_dig = function(pos,player)
--                return locks:lock_allow_dig( pos, player );
--        end
function locks:lock_allow_dig( pos, player )

   if( pos == nil or player == nil ) then
      print( "Error: [locks] Missing/wrong parameters to lock_allow_dig");
      return false;
   end

   local meta = minetest.env:get_meta(pos);
   local lock_owner = meta:get_string("owner");

   -- locks who lost their owner can be opened/digged by anyone
   if( meta == nil or lock_owner == nil or lock_owner == "") then
      return true;
   end

   -- the owner can dig up his own locked objects
   if( player:get_player_name() == meta:get_string("owner")) then
      return true;
   end
   
   -- players with diglocks priv can dig up locked objects as well
   if( minetest.check_player_privs(player:get_player_name(), {diglocks=true})) then
     return true;
   end

   return false; -- fallback
end
    

-- The locked object can only be used (i.e. opened, stuff taken out, changed, ... - depends on object) if this
-- function returns true. Call it wherever appropriate (usually in on_punch in register_node). Example:
--        on_punch = function(pos,player)
--               if( !locks:lock_allow_use( pos, player ) then
--                  print( "Sorry, you have no access here.");
--               else
--                  do_what_this_object_is_good_for( pos, puncher );
--               end
--        end

function locks:lock_allow_use( pos, player )

   if( pos == nil or player == nil ) then
      print( "Error: [locks] Missing/wrong parameters to lock_allow_use");
      return false;
   end

   -- TODO: the player has to have a key (when allowed to dig) or else a keychain for this to be actually allowed

   -- if the user would even be allowed to dig this node up, using the node is allowed as well 
   if( locks:lock_allow_dig( pos, player )) then
      return true;
   end

   local name = player:get_player_name();

   -- players with openlocks priv can open locked objects 
   if( minetest.check_player_privs(name, {openlocks=true})) then
     return true;
   end

   -- the player might be specificly allowed to use this object through allowed_users
   local liste = meta:get_string("allowed_users"):split( "," );
   for i in ipairs( liste ) do
      if( liste[i] == name ) then
         return true;
      end
   end

   -- TODO: the player might be in a group of players allowed to use this (also listed in allowed_users)

   -- the player may have entered the right password
   if( name == meta:get_string("pw_user")) then
      return true;
   end

   -- the lock may have a password set. If this is the case then ask the user for it
   if( meta:get_string( "password" ) and meta:get_sring( "password" ) ~= "" ) then
      minetest.chat_send_player(name, "Access denied. Right-click and enter password first!");
      return false;
   end

   return false; -- fallback

end



-- Method for the lock to get password and configuration data
-- Call in on_receive_fields in register_node. Example:
--        on_receive_fields = function(pos, formname, fields, sender)
--                locks:lock_handle_input( pos, formname, fields, sender );
--        end,
function locks:lock_handle_input( pos, formname, fields, player )

   if( pos == nil or player == nil ) then
      print( "Error: [locks] Missing/wrong parameters to lock_handle_input");
      return false;
   end

   local meta = minetest.env:get_meta(pos);
   if( meta == nil ) then
      print( "Error: [locks] lock_handle_input: unable to get meta data");
      return;
   end

   -- is this input the lock is supposed to handle?
   if(   not( fields.locks_sent_input )
      or not( fields.locks_sent_lock_command )
      or fields.locks_sent_lock_command == "" ) then
     return;
   end

   name = player:get_player_name();

   if( fields.locks_sent_lock_command == "/help" ) then

      if( name == meta:get_string( "owner" )) then
         minetest.chat_send_player(name, "The following commands are available to you, the owner of this object, only:\n"..
            "  /help           Shows this help text.\n"..
            "  /add <name>     Player <name> can now unlock this object with any key.\n"..
            "  /del <name>     Player <name> can no longer use this object.\n"..
            "  /list           Shows a list of players who can use this object.\n"..
            "  /set <password> Sets a password. Everyone who types that in can use the object.");

      else if( locks:lock_allow_use( pos, player )) then
         minetest.chat_send_player(name, "This locked object is owned by "..tostring( meta:get_string( "owner" ))..".\n"..
            "You do have access to it.\n");

      else if( meta:get_string( "password" ) ~= "" ) then
         minetest.chat_send_player(name, "This locked object is owned by "..tostring( meta:get_string( "owner" ))..".\n"..
            "Enter the correct password to gain access.\n");

      else
         minetest.chat_send_player(name, "This locked object is owned by "..tostring( meta:get_string( "owner" ))..".\n"..
            "There is no password set. You can only gain access if the owner grants it to you.");

      end end end -- lua is not the most intuitive language here....
      return;
   end -- of /help


   -- other players can only try to input the correct password
   if( name ~= meta:get_string( "owner" )) then 

      -- no need to bother with trying other PWs if none is set...
      if( meta.get_string("password")=="" ) then
          minetest.chat_send_player(name, "There is no password set. Access denied.");
          return;
      end

      -- the player may have entered the right password already
      if( name == meta:get_string("pw_user")) then
         -- nothing to do - the player entered the right pw alredy
          minetest.chat_send_player(name, "You have entered the right password already. Access granted.");
         return;
      end

      if( fields.locks_sent_lock_command ~= meta:get_string("password")) then
          minetest.chat_send_player(name, "Wrong password. Access denied.");
         return;
      end

      -- store the last user (this one) who entered the right pw
      meta:set_string( "pw_user", name );

      minetest.chat_send_player(name, "Password confirmed. Access granted.");
      return;
   end
 
   local txt = "";


   if( fields.locks_sent_lock_command == "/list" ) then

      if( meta:get_string("allowed_users")=="" ) then
         txt = "No other users are allowed to use this object (except those with global privs like moderators/admins).";
      else
         txt = "You granted the following users/groups of users access to this object:\n";
         local liste = meta:get_string("allowed_users"):split( "," );
         for i in ipairs( liste ) do
            txt = txt.."   "..tostring(liste[i]);
         end
      end

      if( meta:get_string( "password" ) == "" ) then
         txt = txt.."\nThere is no password set. That means no one can get access through a password.";  
      else
         txt = txt.."\nThe password for this lock is: \""..tostring( meta:get_string( "password" ).."\"");
      end

      minetest.chat_send_player(name, txt );
      return;
   end -- of /list

--   -- all other commands take exactly one parameter
   local help = fields.locks_sent_lock_command:split( " " );
   
   print( tostring( help[1] ));
   print( tostring( help[2] ));

     
   -- set/change a password
   if( help[1]=="/set" ) then

      -- if empty password then delete it
      if( help[2]==nil ) then
         help[2] = "";
      end

      minetest.chat_send_player(name, "Old password: \""..tostring( meta:get_string( "password" ))..
                      "\"\n Changed to new password: \""..tostring( help[2]).."\".");


      meta:set_string( "password", help[2]); 
      -- reset the list of users who typed the right password
      meta:set_string("pw_users","");

      if( help[2]=="") then
         minetest.chat_send_player(name, "The password is empty and thus will be disabled.");
      end
      return;
   end

   if( help[2]==nil or help[2]=="") then
      minetest.chat_send_player(name, "Error: Missing parameter (player name) for command \""..tostring( help[1] ).."\"." );
      return;
   end

   -- for add and del: check if the player is already in the list

   local found = false;
   local anz   = 0;
   local liste = meta:get_string("allowed_users"):split( "," );
   for i in ipairs( liste ) do

      anz = anz + 1; -- count players 
      if( tostring( liste[i] ) == help[2] ) then
          found = true;
      end

   end

   if( help[1]=="/add" and found==true ) then
      minetest.chat_send_player(name, "Player \""..tostring( help[2] ).."\" is already allowed to use this locked object. Nothing to do.");
      return;
   end
      
   if( help[1]=="/del" and found==false) then
      minetest.chat_send_player(name, "Player \""..tostring( help[2] ).."\" is not amongst the players allowed to use this locked object. Nothing to do.");
      return;
   end

   -- TODO: check if the player exists....

   if( help[1]=="/add" ) then

      if( anz >= 6 ) then
         minetest.chat_send_player(name, "Sorry, no more players can be added. To save space, only up to 6 players can be added. For more players please use groups!");
         return;
      end

      meta:set_string( "allowed_users", meta:get_string("allowed_users")..","..help[2] );

      minetest.chat_send_player(name, help[2].." may now use/access this locked object.");
      return;
   end


   if( help[1]=="/del" ) then

      userlist  = meta:get_string("allowed_users"):split( ","..help[2] );
      if( userlist[2]==nil ) then
         userlist[2]="";
      end 
      meta:set_string( "allowed_users", userlist[1]..userlist[2] );
      
      minetest.chat_send_player(name, "Access for player \""..tostring(help[2]).."\" has been revoked.");
      return;
   end

   minetest.chat_send_player(name, "Error: Command \""..tostring(help[1]).."\" not understood.");
end



-- a chest
minetest.register_node("locks:locked_shared_chest", {
       description = "Locked shared chest",
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
                locks:lock_set_owner( pos, placer );
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


-- a sign
minetest.register_node("locks:locked_shared_sign_wall", {
        description = "Locked shared sign",
        drawtype = "signlike",
        tiles = {"default_sign_wall.png"},
        inventory_image = "default_sign_wall.png",
        wield_image = "default_sign_wall.png",
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
                local meta = minetest.env:get_meta(pos)
                -- prepare the lock of the sign
                locks:lock_init( pos, 
                                "size[8,4]"..
                                "field[0.3,0.6;6,0.7;text;Text:;]"..
                                "field[0.3,3.6;6,0.7;locks_sent_lock_command;Locked sign. Type /help for help:;]"..
                                "button_exit[6.3,3.2;1.7,0.7;locks_sent_input;Proceed]" );
        end,

        after_place_node = function(pos, placer)
                locks:lock_set_owner( pos, placer );
        end,


        can_dig = function(pos,player)
                return locks:lock_allow_dig( pos, player );
        end,

        on_receive_fields = function(pos, formname, fields, sender)

                -- if the user already has the right to use this and did input text
                if( fields.text and locks:lock_allow_use( pos, sender )) then

                    --print("Sign at "..minetest.pos_to_string(pos).." got "..dump(fields))
                    local meta = minetest.env:get_meta(pos)
                    fields.text = fields.text or "";
                    print((sender:get_player_name() or "").." wrote \""..fields.text..
                                "\" to sign at "..minetest.pos_to_string(pos));
                    meta:set_string("text", fields.text.." ["..sender:get_player_name().."]");
                    meta:set_string("infotext", '"'..fields.text..'"'.." ["..sender:get_player_name().."]");

                -- a command for the lock?
                else
                   locks:lock_handle_input( pos, formname, fields, sender );
                end
  
        end,
 });
