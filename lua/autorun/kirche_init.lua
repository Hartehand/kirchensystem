AddCSLuaFile()

AddCSLuaFile("kirche/sh_config.lua")
AddCSLuaFile("kirche/sh_net.lua")
AddCSLuaFile("kirche/client/cl_request.lua")
AddCSLuaFile("kirche/client/cl_bishop_menu.lua")
AddCSLuaFile("weapons/weapon_kirche/shared.lua")
AddCSLuaFile("weapons/weapon_kirche/cl_init.lua")

include("kirche/sh_config.lua")
include("kirche/sh_net.lua")

if SERVER then
    include("kirche/server/sv_mysql.lua")
    include("kirche/server/sv_core.lua")
    include("kirche/server/sv_charges.lua")
else
    include("kirche/client/cl_request.lua")
    include("kirche/client/cl_bishop_menu.lua")
end

