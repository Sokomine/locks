This Mod for Minetest adds objects that can be locked and shared.

It is written so that other objects/mods can easily use the functions provided here.

Comes with modified chest, sign and xyz' xdoor2 as sample objects.
New: Furnaces added.
For the (unmodified) xdoors2, see http://minetest.net/forum/viewtopic.php?id=2757. Chest and sign take their textures out of default.
The textures (lock, key and keychain) have been provided by Addi. Please consult textures/licence.txt.
The code of the lock mod has been written by Sokomine.

A player may open/use a shared locked object if he/she is/has...
- the owner
- diglocks priv (may dig up shared locked objects)
- openlocks priv (object may only be used - i.e. take something out of a chest, open a door - not digged up!)
- has been added by the owner with the /add playername command
- member of a playergroup that has been added with /add :playergroupname command (provided the playergroups mod is installed)
- typed in the correct password that the owner did set with /set thisisthepassword

Adds lock, key and keychain.
- lock: craftitem to create shared locked objects (chests, signs, doors)
- key: needed to open your own shared locked objects (a keychain is ok as well)
- keychain: needed to open the shared locked objects of other players
The tools do not have to be wielded. They just have to be in the players' inventory.
Keys and keychains are not specific to a selected lock. They fit all locks - provided the player may open/use the object.
Thus it is sufficient to carry around only one keychain to open all shared locked objects the player has access to.

If you do not want any of the objects chest, sign and/or door, just remove the corresponding lines from the init.lua:
dofile(minetest.get_modpath("locks").."/shared_locked_chest.lua");
dofile(minetest.get_modpath("locks").."/shared_locked_sign_wall.lua");
dofile(minetest.get_modpath("locks").."/shared_locked_xdoors2.lua");
dofile(minetest.get_modpath("locks").."/shared_locked_furnace.lua");

I hope this mod will be helpful.

Sokomine

