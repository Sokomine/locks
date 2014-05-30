

          
--[[
    Shared locked objects (Mod for MineTest)
    Allows to restrict usage of blocks to a certain player or a group of
    players.
    Copyright (C) 2013 Sokomine

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

-- Version 1.20

-- Changelog: 
-- 08.05.2014 * Changed animation of shared locked furnace (removed pipeworks overlay on front, changed to new animation type)
-- 10.01.2013 * Added command to toggle for pipeworks output
--            * Added pipeworks support for chests and furnace.
-- 17.12.2013 * aborting input with ESC is possible again
-- 01.09.2013 * fixed bug in input sanitization
-- 31.08.2013 * changed receipe for key to avoid crafting conflickt with screwdriver
-- 10.07.2013 * removed a potential bug (now uses string:gmatch)
--            * added shared locked furnaces



locks = {};

minetest.register_privilege("openlocks", { description = "allows to open/use all locked objects", give_to_singleplayer = false});
minetest.register_privilege("diglocks",  { description = "allows to open/use and dig up all locked objects", give_to_singleplayer = false});


locks.pipeworks_enabled = false;

if( minetest.get_modpath("pipeworks") ~= nil ) then
   locks.pipeworks_enabled = true;
end

-- initializes a lock (that is: prepare the metadata so that it can store data)
--  default_formspec is the formspec that will be used on right click; the input field for the commands has to exist 
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
   -- this formspec is presented on right-click for every user
   meta:set_string("formspec",        default_formspec);
   -- by default, do not send output to pipework tubes
   meta:set_int(   "allow_pipeworks", 0 );
end


-- returns the information stored in the metadata strings (like owner etc.)
function locks:get_lockdata( pos )
   if( pos == nil ) then
      return;
   end
 
   local meta = minetest.env:get_meta(pos);
   if( meta == nil) then
      return;
   end

   return{ infotext      = (meta:get_string( "infotext" ) or ""),
           owner         = (meta:get_string( "owner"    ) or ""),
           allowed_users = (meta:get_string( "allowed_users" ) or ""),
           password      = (meta:get_string( "password"      ) or ""),
           pw_user       = (meta:get_string( "w_user"        ) or ""),
           formspec      = (meta:get_string( "formspec"      ) or "")
   };
end


-- sets all the metadata the look needs (used e.g. in doors)
function locks:set_lockdata( pos, data )
   if( pos == nil ) then
      return;
   end
 
   local meta = minetest.env:get_meta(pos);
   if( meta == nil) then
      return;
   end
   
   meta:set_string("infotext",     (data.infotext      or ""));
   meta:set_string("owner",        (data.owner         or ""));
   meta:set_string("allowed_users",(data.allowed_users or ""));
   meta:set_string("password",     (data.password      or ""));
   meta:set_string("pw_user",      (data.pw_user       or ""));
   meta:set_string("formspec",     (data.formspec      or ""));
end




-- Set the owner of the locked object.
-- Call this in after_place_node in register_node. Example:
--        after_place_node = function(pos, placer)
--                locks:lock_set_owner( pos, placer, "Shared locked object" );
--        end,
function locks:lock_set_owner( pos, player_or_name, description )

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
   -- add the name of the owner to the description
   meta:set_string("infotext", ( description or "Shared lockecd object" ).." (owned by "..meta:get_string("owner")..")");
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

   local name = player:get_player_name();
   local meta = minetest.env:get_meta(pos);

   -- pipeworks sends a special username
   if( name == ':pipeworks' ) then
      if( meta:get_int( 'allow_pipeworks' ) == 1 ) then
         return true;
      else
         return false;
      end
   end

   -- the player has to have a key or a keychain to open his own shared locked objects
   if( name == meta:get_string("owner")) then      

      if(     not( player:get_inventory():contains_item("main","locks:keychain 1"))
          and not( player:get_inventory():contains_item("main","locks:key 1"))) then
          minetest.chat_send_player( name, "You do not have a key or a keychain. Without that you can't use your shared locked objects!");
          return false;
      end

   -- the player has to have a keychain to open shared locked objects of other players
   else 

      if( not( player:get_inventory():contains_item("main","locks:keychain 1"))) then
         minetest.chat_send_player(name, "You do not have a keychain. Without that you can't open shared locked objects of other players!");
         return false;
      end
   end
      
   -- if the user would even be allowed to dig this node up, using the node is allowed as well 
   if( locks:lock_allow_dig( pos, player )) then
      return true;
   end


   if( meta == nil ) then
      minetest.chat_send_player( name, "Error: Could not access metadata of this shared locked object.");
      return false;
   end

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

      -- the player might member of a playergroup that is allowed to use this object
      if( liste[i]:sub(1,1) == ":"
        and playergroups ~= nil
        and playergroups:is_group_member( meta:get_string("owner"), liste[i]:sub(2), name )) then
         return true;
      end

   end


   -- the player may have entered the right password
   if( name == meta:get_string("pw_user")) then
      return true;
   end

   -- the lock may have a password set. If this is the case then ask the user for it
   if( meta:get_string( "password" ) and meta:get_string( "password" ) ~= "" ) then
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
   if(  ( not( fields.locks_sent_lock_command )
       or fields.locks_sent_lock_command == "" )
      and (fields.quit and (fields.quit==true or fields.quit=='true'))) then
--    or not( fields.locks_sent_input )
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
            "  /set <password> Sets a password. Everyone who types that in can use the object.\n"..
            "  /pipeworks      Toggles permission for pipeworks to take inventory out of the shared locked object.\n");

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

   -- sanitize player input
   if( fields.locks_sent_lock_command:match("[^%a%d%s_%- /%:]")) then
      minetest.chat_send_player(name, "Input contains unsupported characters. Allowed: a-z, A-Z, 0-9, _, -, :.");
      return;
   end
    
   if( #fields.locks_sent_lock_command > 60) then
      minetest.chat_send_player(name, "Input too long. Only up to 80 characters supported.");
      return;
   end
   

   -- other players can only try to input the correct password
   if( name ~= meta:get_string( "owner" )) then 

      -- no need to bother with trying other PWs if none is set...
      if( meta:get_string("password")=="" ) then
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

      if( not( minetest.get_modpath("pipeworks") )) then
         txt = txt.."\nThe pipeworks mod is not installed. Install it if you wish support for tubes.";
      elseif( meta:get_int( "allow_pipeworks" ) == 1 ) then
         txt = txt.."\nTubes from pipeworks may be used to extract items out of/add items to this shared locked object.";
      else
         txt = txt.."\nInput from tubes is accepted, but output to them is denied (default).";
      end

      minetest.chat_send_player(name, txt );
      return;
   end -- of /list


   -- toggle tube output on/off
   if( fields.locks_sent_lock_command == "/pipeworks" ) then

      if( meta:get_int('allow_pipeworks') == 1 ) then
         meta:set_int('allow_pipeworks', 0 );
         minetest.chat_send_player( name, 'Output to pipework tubes is now DISABLED (input is still acceped).');
         return;
      else
         meta:set_int('allow_pipeworks', 1 );
         minetest.chat_send_player( name, 'Output to pipework tubes is now ENABLED. Connected tubes may insert and remove items.');
         return;
      end
   end

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


   if( help[1]=="/add" ) then

      if( anz >= 6 ) then
         minetest.chat_send_player(name, "Sorry, no more players can be added. To save space, only up to 6 players can be added. For more players please use groups!");
         return;
      end

      if( name == help[2] ) then
         minetest.chat_send_player(name, "You are already owner of this object.");
         return;
      end
        
      -- the player might try to add a playergroup
      if( help[2]:sub(1,1) == ":" ) then
          
         if( not( playergroups )) then
            minetest.chat_send_player(name, "Sorry, this server does not support playergroups.");
            return;
         end

         if( #help[2]<2 ) then
            minetest.chat_send_player(name, "Please specify the name of the playergroup you want to add!");
            return;
         end

         if( not( playergroups:is_playergroup(meta:get_string("owner"), help[2]:sub(2) ))) then
            minetest.chat_send_player(name, "You do not have a playergroup named \""..tostring( help[2]:sub(2)).."\".");
            return;
         end
 
      else
            
         -- check if the player exists
         local privs = minetest.get_player_privs( help[2] );
         if( not( privs ) or not( privs.interact )) then
            minetest.chat_send_player(name, "Player \""..help[2].."\" not found or has no interact privs.");
            return;
         end
      end
        
      meta:set_string( "allowed_users", meta:get_string("allowed_users")..","..help[2] );

      if( help[2]:sub(1,1) == ":" ) then
         minetest.chat_send_player(name, "All members of your playergroup "..tostring(help[2]:sub(2)).." may now use/access this locked object.");
      else
         minetest.chat_send_player(name, help[2].." may now use/access this locked object.");
      end
      return;
   end


   if( help[1]=="/del" ) then

      userlist  = meta:get_string("allowed_users"):split( ","..help[2] );
      meta:set_string( "allowed_users", ( userlist[1] or "" )..(userlist[2] or "" ));
      
      minetest.chat_send_player(name, "Access for player \""..tostring(help[2]).."\" has been revoked.");
      return;
   end

   minetest.chat_send_player(name, "Error: Command \""..tostring(help[1]).."\" not understood.");
end



-- craftitem; that can be used to craft shared locked objects
minetest.register_craftitem("locks:lock", {
        description = "Lock to lock and share objects",
        image = "locks_lock16.png",
});


minetest.register_craft({
        output = "locks:lock 2",
        recipe = {
                 {'default:steel_ingot', 'default:steel_ingot','default:steel_ingot'},
                 {'default:steel_ingot', '',                   'default:steel_ingot'},
                 {'',                    'default:steel_ingot',''},
                }
        });


-- a key allowes to open your own shared locked objects
minetest.register_craftitem("locks:key", {
        description = "Key to open your own shared locked objects",
        image = "locks_key32.png",
});

minetest.register_craft({
        output = "locks:key",
        recipe = {
                 {'',                    'default:stick',      ''},
                 {'',                    'default:steel_ingot',''},
                }
        });



-- in order to open shared locked objects of other players, a keychain is needed (plus the owner has to admit it via /add playername or through /set password)
minetest.register_craftitem("locks:keychain", {
        description = "Keychain to open shared locked objects of others",
        image = "locks_keychain32.png",
});

minetest.register_craft({
        output = "locks:keychain",
        recipe = {
                 {'',                    'default:steel_ingot', '' },
                 {'locks:key',           'locks:key',           'locks:key'},
                }
        });

dofile(minetest.get_modpath("locks").."/shared_locked_chest.lua");
dofile(minetest.get_modpath("locks").."/shared_locked_sign_wall.lua");
dofile(minetest.get_modpath("locks").."/shared_locked_xdoors2.lua");
dofile(minetest.get_modpath("locks").."/shared_locked_furnace.lua");


