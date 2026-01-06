-- Kirchensteuer-System Konfiguration
KIRCHEN_CFG = KIRCHEN_CFG or {}

KIRCHEN_CFG.BishopTeam = TEAM_LANDESBISCHOF or TEAM_MAYOR -- Stelle sicher, dass das korrekte DarkRP-Team hier steht
KIRCHEN_CFG.SWEPClass = "weapon_kirche"
KIRCHEN_CFG.SWEPName = "Kirchenbeitritt"

KIRCHEN_CFG.DefaultContribution = 50
KIRCHEN_CFG.ContributionMin = 20
KIRCHEN_CFG.ContributionMax = 150

KIRCHEN_CFG.ChargeIntervalSeconds = 600
KIRCHEN_CFG.ChargeOffline = true
KIRCHEN_CFG.PartialPayment = false
KIRCHEN_CFG.NotifyOnCharge = true
KIRCHEN_CFG.NotifyOnDebt = true
KIRCHEN_CFG.RequestCooldownSeconds = 30
KIRCHEN_CFG.ShowDebtToBishop = true
KIRCHEN_CFG.AllowDebtReset = false
KIRCHEN_CFG.DebtLimit = 0 -- 0 = unbegrenzt

KIRCHEN_CFG.Adapter = "mysqloo" -- "mysqloo" oder "tmysql4"
KIRCHEN_CFG.Database = {
    host = "127.0.0.1",
    user = "gmod",
    password = "password",
    database = "kirche",
    port = 3306
}

KIRCHEN_CFG.Schema = {
    members = "kirche_members",
    logs = "kirche_logs"
}

-- Optional: beim Spawn den RPName synchronisieren
KIRCHEN_CFG.SyncRPNameOnSpawn = true
KIRCHEN_CFG.SyncOnSalary = true

