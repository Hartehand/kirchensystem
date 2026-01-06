SWEP.PrintName = KIRCHEN_CFG and KIRCHEN_CFG.SWEPName or "Kirchenbeitritt"
SWEP.Author = "Kirchensystem"
SWEP.Instructions = "Linksklick: Spieler einladen\nRechtsklick: Verwaltungsmenü"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "DarkRP Kirche"

SWEP.ViewModel = "models/weapons/c_bugbait.mdl"
SWEP.WorldModel = "models/weapons/w_bugbait.mdl"
SWEP.UseHands = true
SWEP.DrawAmmo = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:CanPrimaryAttack()
    return true
end

function SWEP:CanSecondaryAttack()
    return true
end

function SWEP:PrimaryAttack()
    if CLIENT then return end
    self:SetNextPrimaryFire(CurTime() + 1)
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local tr = owner:GetEyeTrace()
    if not tr or not tr.Entity or not tr.Entity:IsPlayer() then
        return
    end

    if tr.Entity:GetPos():DistToSqr(owner:GetPos()) > (150 * 150) then return end
    KIRCHEN.TryRequestInvite(owner, tr.Entity)
end

function SWEP:SecondaryAttack()
    if CLIENT then return end
    self:SetNextSecondaryFire(CurTime() + 1)
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end
    KIRCHEN.OpenBishopMenu(owner)
end
if not KIRCHEN_CFG then
    include("kirche/sh_config.lua")
end
