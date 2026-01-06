AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function SWEP:Equip(ply)
    if not ply or not ply:IsPlayer() then return end
    if not KIRCHEN or not KIRCHEN.IsBishop then return end
    if not KIRCHEN.IsBishop(ply) then
        ply:StripWeapon(self:GetClass())
        ply:ChatPrint("[Kirche] Du bist kein Landesbischof.")
    end
end

function SWEP:ShouldDropOnDie()
    return false
end
