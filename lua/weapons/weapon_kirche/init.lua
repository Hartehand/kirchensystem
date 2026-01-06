AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function SWEP:Equip(ply)
    if not ply or not ply:IsPlayer() then return end
    local allowed = KIRCHEN_CFG.BishopTeam
    local allowedList = istable(allowed) and allowed or {allowed}
    local ok = false
    for _, t in ipairs(allowedList) do
        if isnumber(t) and ply:Team() == t then
            ok = true
            break
        end
    end
    if not ok then
        ply:StripWeapon(self:GetClass())
        ply:ChatPrint("[Kirche] Du bist kein Landesbischof.")
    end
end

function SWEP:ShouldDropOnDie()
    return false
end
