KIRCHEN = KIRCHEN or {}
KIRCHEN.Members = KIRCHEN.Members or {}
KIRCHEN.PendingRequests = KIRCHEN.PendingRequests or {}

local cfg = KIRCHEN_CFG
local netcfg = KIRCHEN_NET

local function isBishop(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Team() == cfg.BishopTeam
end

local function notify(ply, level, msg)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if DarkRP then
        DarkRP.notify(ply, level or 1, 5, msg)
    else
        ply:ChatPrint(msg)
    end
end

function KIRCHEN.Notify(ply, level, msg)
    notify(ply, level, msg)
end

local function clampContribution(val)
    return math.Clamp(math.floor(val), cfg.ContributionMin, cfg.ContributionMax)
end

function KIRCHEN.GetMember(steamid)
    return KIRCHEN.Members[steamid]
end

local function upsertMember(data, callback)
    KIRCHEN.Members[data.steamid64] = data
    KIRCHEN_DB.Query(string.format([[
        INSERT INTO %s (steamid64, rpname, joined_at, contribution, debt, last_charge_at)
        VALUES (?, ?, NOW(), ?, ?, NULL)
        ON DUPLICATE KEY UPDATE rpname = VALUES(rpname), contribution = VALUES(contribution), debt = VALUES(debt)
    ]], cfg.Schema.members), {
        data.steamid64,
        data.rpname,
        data.contribution,
        data.debt or 0
    }, callback)
end

local function updateMemberFields(steamid, fields, callback)
    local sets = {}
    local params = {}
    for k, v in pairs(fields) do
        table.insert(sets, k .. " = ?")
        table.insert(params, v)
        if KIRCHEN.Members[steamid] then
            KIRCHEN.Members[steamid][k] = v
        end
    end
    table.insert(params, steamid)
    KIRCHEN_DB.Query(string.format("UPDATE %s SET %s WHERE steamid64 = ?", cfg.Schema.members, table.concat(sets, ", ")), params, callback)
end

local function deleteMember(steamid, callback)
    KIRCHEN.Members[steamid] = nil
    KIRCHEN_DB.Query(string.format("DELETE FROM %s WHERE steamid64 = ?", cfg.Schema.members), {steamid}, callback)
end

function KIRCHEN.LogAction(steamid, action, amount)
    KIRCHEN_DB.Query(string.format("INSERT INTO %s (steamid64, action, amount, created_at) VALUES (?, ?, ?, NOW())", cfg.Schema.logs), {
        steamid,
        action,
        amount or 0
    })
end

local function addMember(ply)
    local sid = ply:SteamID64()
    local data = {
        steamid64 = sid,
        rpname = ply:Nick(),
        joined_at = os.date("%Y-%m-%d %H:%M:%S"),
        contribution = cfg.DefaultContribution,
        debt = 0,
        last_charge_at = nil
    }
    upsertMember(data, function()
        KIRCHEN.LogAction(sid, "joined", cfg.DefaultContribution)
        notify(ply, 0, "[Kirche] Du bist der Kirche beigetreten.")
    end)
end

local function refreshAllMembers()
    KIRCHEN_DB.Query(string.format("SELECT * FROM %s", cfg.Schema.members), nil, function(rows)
        KIRCHEN.Members = {}
        for _, row in ipairs(rows) do
            KIRCHEN.Members[row.steamid64] = row
        end
        KIRCHEN.LogAction("system", "cache_refresh", 0)
    end)
end

local function ensureConnectedCallback()
    if KIRCHEN_DB.IsConnected() then
        refreshAllMembers()
    end
end

hook.Add("KircheDatabaseConnected", "Kirche_LoadMembers", ensureConnectedCallback)

hook.Add("PlayerInitialSpawn", "Kirche_SyncRPName", function(ply)
    if not cfg.SyncRPNameOnSpawn then return end
    local m = KIRCHEN.GetMember(ply:SteamID64())
    if not m then return end
    updateMemberFields(ply:SteamID64(), {rpname = ply:Nick()})
end)

util.AddNetworkString(netcfg.RequestInvite)
util.AddNetworkString(netcfg.RequestResponse)
util.AddNetworkString(netcfg.BishopOpen)
util.AddNetworkString(netcfg.BishopData)
util.AddNetworkString(netcfg.BishopUpdateContribution)
util.AddNetworkString(netcfg.BishopRemoveMember)
util.AddNetworkString(netcfg.BishopResetDebt)

local requestSeq = 0
local requestCooldown = {}

local function canUseSWEP(ply)
    if not isBishop(ply) then
        notify(ply, 1, "[Kirche] Du bist kein Landesbischof.")
        return false
    end
    return true
end

function KIRCHEN.OpenBishopMenu(ply)
    if not canUseSWEP(ply) then return end
    net.Start(netcfg.BishopOpen)
    net.Send(ply)

    local payload = {}
    for _, data in pairs(KIRCHEN.Members) do
        table.insert(payload, data)
    end

    net.Start(netcfg.BishopData)
    net.WriteUInt(#payload, 16)
    for _, row in ipairs(payload) do
        net.WriteString(row.steamid64 or "")
        net.WriteString(row.rpname or "")
        net.WriteInt(tonumber(row.contribution) or cfg.DefaultContribution, 32)
        net.WriteInt(tonumber(row.debt) or 0, 32)
        net.WriteString(tostring(row.joined_at or ""))
        net.WriteString(tostring(row.last_charge_at or ""))
    end
    net.Send(ply)
end

local function sendAlreadyMember(ply, target, member)
    if not IsValid(ply) then return end
    local debtText = ""
    if cfg.ShowDebtToBishop and member.debt and member.debt > 0 then
        debtText = string.format(" | Schulden: %s$", member.debt)
    end
    notify(ply, 1, string.format("[Kirche] %s ist bereits Mitglied. Beitrag: %s$%s", target:Nick(), member.contribution, debtText))
end

function KIRCHEN.TryRequestInvite(ply, target)
    if not canUseSWEP(ply) or not IsValid(target) or not target:IsPlayer() then return end
    if ply == target then return end

    local sid = target:SteamID64()
    local member = KIRCHEN.GetMember(sid)
    if member then
        sendAlreadyMember(ply, target, member)
        return
    end

    requestCooldown[ply] = requestCooldown[ply] or {}
    local nextAllowed = requestCooldown[ply][sid] or 0
    if nextAllowed > CurTime() then
        notify(ply, 1, "[Kirche] Bitte warte vor einer neuen Anfrage.")
        return
    end

    requestSeq = requestSeq + 1
    KIRCHEN.PendingRequests[sid] = {
        inviter = ply:SteamID64(),
        expires = CurTime() + 30,
        seq = requestSeq
    }

    requestCooldown[ply][sid] = CurTime() + (cfg.RequestCooldownSeconds or 30)

    net.Start(netcfg.RequestInvite)
    net.WriteUInt(requestSeq, 16)
    net.WriteString(ply:Nick())
    net.WriteUInt(cfg.DefaultContribution, 16)
    net.WriteUInt(cfg.ChargeIntervalSeconds, 16)
    net.Send(target)
end

net.Receive(netcfg.RequestResponse, function(_, ply)
    local seq = net.ReadUInt(16)
    local accepted = net.ReadBool()
    local sid = ply:SteamID64()
    local pending = KIRCHEN.PendingRequests[sid]
    if not pending or pending.seq ~= seq or pending.expires < CurTime() then
        notify(ply, 1, "[Kirche] Anfrage abgelaufen.")
        return
    end
    KIRCHEN.PendingRequests[sid] = nil
    if not accepted then
        notify(ply, 1, "[Kirche] Du hast die Anfrage abgelehnt.")
        return
    end
    addMember(ply)
end)

net.Receive(netcfg.BishopUpdateContribution, function(_, ply)
    if not isBishop(ply) then return end
    local sid = net.ReadString()
    local contrib = clampContribution(net.ReadInt(32))
    if not sid or sid == "" then return end
    local member = KIRCHEN.GetMember(sid)
    if not member then return end
    updateMemberFields(sid, {contribution = contrib}, function()
        KIRCHEN.LogAction(sid, "contrib_changed", contrib)
        notify(ply, 0, "[Kirche] Beitrag aktualisiert.")
    end)
end)

net.Receive(netcfg.BishopRemoveMember, function(_, ply)
    if not isBishop(ply) then return end
    local sid = net.ReadString()
    if not sid or sid == "" then return end
    deleteMember(sid, function()
        KIRCHEN.LogAction(sid, "kicked", 0)
        notify(ply, 0, "[Kirche] Mitglied entfernt.")
    end)
end)

net.Receive(netcfg.BishopResetDebt, function(_, ply)
    if not isBishop(ply) or not cfg.AllowDebtReset then return end
    local sid = net.ReadString()
    if not sid or sid == "" then return end
    updateMemberFields(sid, {debt = 0}, function()
        KIRCHEN.LogAction(sid, "debt_reset", 0)
        notify(ply, 0, "[Kirche] Schulden wurden zurückgesetzt.")
    end)
end)

hook.Add("PlayerSay", "Kirche_OpenMenuChat", function(ply, text)
    if string.lower(text) == "/kirche" then
        KIRCHEN.OpenBishopMenu(ply)
        return ""
    end
end)
