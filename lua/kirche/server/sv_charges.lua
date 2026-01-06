local cfg = KIRCHEN_CFG

local function capDebt(amount)
    if cfg.DebtLimit and cfg.DebtLimit > 0 then
        return math.min(amount, cfg.DebtLimit)
    end
    return amount
end

local function processOnline(member)
    local ply = player.GetBySteamID64(member.steamid64 or "")
    if not IsValid(ply) then return false end

    local money = ply.getDarkRPVar and ply:getDarkRPVar("money") or 0
    local debt = tonumber(member.debt) or 0
    local contribution = tonumber(member.contribution) or cfg.DefaultContribution

    local payDebt = math.min(debt, money)
    local remaining = money - payDebt
    local payContribution = 0
    if remaining >= contribution then
        payContribution = contribution
    elseif cfg.PartialPayment then
        payContribution = math.max(0, remaining)
    end

    if payDebt > 0 then
        ply:addMoney(-payDebt)
        debt = debt - payDebt
    end
    if payContribution > 0 then
        ply:addMoney(-payContribution)
    end

    local newDebt = debt + math.max(0, contribution - payContribution)
    newDebt = capDebt(newDebt)

    KIRCHEN.Members[member.steamid64].debt = newDebt
    KIRCHEN.Members[member.steamid64].last_charge_at = os.date("%Y-%m-%d %H:%M:%S")

    KIRCHEN_DB.Query(string.format("UPDATE %s SET debt = ?, last_charge_at = NOW() WHERE steamid64 = ?", cfg.Schema.members), {
        newDebt,
        member.steamid64
    })

    if payContribution > 0 and cfg.NotifyOnCharge then
        KIRCHEN.Notify(ply, 0, "[Kirche] Kirchensteuer bezahlt: " .. payContribution .. "$")
    end

    if newDebt > 0 and cfg.NotifyOnDebt then
        KIRCHEN.Notify(ply, 1, "[Kirche] Neue Schulden: " .. newDebt .. "$")
    end

    KIRCHEN.LogAction(member.steamid64, "charge", contribution)
    if newDebt > debt then
        KIRCHEN.LogAction(member.steamid64, "debt_added", newDebt - debt)
    end
    return true
end

local function processOffline(member)
    if not cfg.ChargeOffline then return end
    local contribution = tonumber(member.contribution) or cfg.DefaultContribution
    local debt = tonumber(member.debt) or 0
    local newDebt = capDebt(debt + contribution)
    KIRCHEN.Members[member.steamid64].debt = newDebt
    KIRCHEN.Members[member.steamid64].last_charge_at = os.date("%Y-%m-%d %H:%M:%S")

    KIRCHEN_DB.Query(string.format("UPDATE %s SET debt = ?, last_charge_at = NOW() WHERE steamid64 = ?", cfg.Schema.members), {
        newDebt,
        member.steamid64
    })
    KIRCHEN.LogAction(member.steamid64, "charge_offline", contribution)
    if newDebt > debt then
        KIRCHEN.LogAction(member.steamid64, "debt_added", newDebt - debt)
    end
end

local function runChargeCycle()
    if not KIRCHEN_DB.IsConnected() then return end
    for _, member in pairs(KIRCHEN.Members) do
        if not processOnline(member) then
            processOffline(member)
        end
    end
end

local function syncSalaryPayment(ply)
    local member = KIRCHEN.GetMember(ply:SteamID64())
    if not member then return end
    processOnline(member)
end

timer.Create("Kirche_AutoCharge", cfg.ChargeIntervalSeconds, 0, runChargeCycle)

if cfg.SyncOnSalary then
    hook.Add("playerGetSalary", "Kirche_SalaryCharge", function(ply)
        syncSalaryPayment(ply)
    end)
end

hook.Add("PlayerInitialSpawn", "Kirche_ChargeOnJoin", function(ply)
    timer.Simple(5, function()
        if not IsValid(ply) then return end
        local member = KIRCHEN.GetMember(ply:SteamID64())
        if not member then return end
        processOnline(member)
    end)
end)
