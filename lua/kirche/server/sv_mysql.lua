KIRCHEN_DB = KIRCHEN_DB or {}

local cfg = KIRCHEN_CFG
local connected = false
local adapter = string.lower(cfg.Adapter or "mysqloo")
local dbObj
local pendingSchema = false

local function log(msg)
    MsgN("[Kirche][DB] " .. msg)
end

local function handleError(err)
    ErrorNoHalt("[Kirche][DB] " .. tostring(err) .. "\n")
end

function KIRCHEN_DB.IsConnected()
    return connected
end

function KIRCHEN_DB.EnsureSchema()
    if not connected then return end
    if pendingSchema then return end
    pendingSchema = true

    local members = string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            steamid64 VARCHAR(32) NOT NULL PRIMARY KEY,
            rpname VARCHAR(255) NOT NULL,
            joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            contribution INT NOT NULL DEFAULT 50,
            debt INT NOT NULL DEFAULT 0,
            last_charge_at DATETIME NULL,
            total_paid BIGINT NOT NULL DEFAULT 0
        )
    ]], cfg.Schema.members)

    local logs = string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            steamid64 VARCHAR(32) NOT NULL,
            action VARCHAR(64) NOT NULL,
            amount INT NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ]], cfg.Schema.logs)

    local account = string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            id TINYINT NOT NULL PRIMARY KEY,
            balance BIGINT NOT NULL DEFAULT 0
        )
    ]], cfg.Schema.account or "kirche_account")

    KIRCHEN_DB.Query(members, nil, function()
        KIRCHEN_DB.Query(logs, nil, function()
            KIRCHEN_DB.Query(account, nil, function()
                KIRCHEN_DB.Query(string.format("ALTER TABLE %s ADD COLUMN IF NOT EXISTS total_paid BIGINT NOT NULL DEFAULT 0", cfg.Schema.members))
                KIRCHEN_DB.Query(string.format("INSERT INTO %s (id, balance) VALUES (1, 0) ON DUPLICATE KEY UPDATE balance = balance", cfg.Schema.account or "kirche_account"))
                pendingSchema = false
                log("Schema geprüft/erstellt.")
                hook.Run("KircheSchemaReady")
            end)
        end)
    end)
end

local function connect_mysqloo()
    local mysqloo = mysqloo or require("mysqloo")
    dbObj = mysqloo.connect(cfg.Database.host, cfg.Database.user, cfg.Database.password, cfg.Database.database, cfg.Database.port)

    function dbObj:onConnected()
        connected = true
        log("Verbunden über mysqloo.")
        KIRCHEN_DB.EnsureSchema()
        hook.Run("KircheDatabaseConnected")
    end

    function dbObj:onConnectionFailed(err)
        connected = false
        handleError(err)
    end

    dbObj:connect()
end

local function connect_tmysql4()
    local tmysql = tmysql4 or require("tmysql4")
    local ok, db, err = pcall(tmysql.connect, cfg.Database.host, cfg.Database.user, cfg.Database.password, cfg.Database.database, cfg.Database.port)
    if not ok or not db then
        handleError(err or "Unbekannter Fehler")
        return
    end
    connected = true
    dbObj = db
    log("Verbunden über tmysql4.")
    KIRCHEN_DB.EnsureSchema()
    hook.Run("KircheDatabaseConnected")
end

function KIRCHEN_DB.Connect()
    if adapter == "tmysql4" then
        connect_tmysql4()
    else
        connect_mysqloo()
    end
end

local function escape(str)
    if adapter == "tmysql4" then
        return dbObj:Escape(str)
    end
    return dbObj:escape(str)
end

-- Einfaches Prepared-Statement-ähnliches System
local function prepare(query, params)
    if not params or #params == 0 then
        return query
    end
    local parts = {}
    local i = 1
    for part in string.gmatch(query, "([^?]+)") do
        table.insert(parts, part)
        local param = params[i]
        if param ~= nil then
            if isnumber(param) then
                table.insert(parts, tostring(math.floor(param)))
            else
                table.insert(parts, "'" .. escape(tostring(param)) .. "'")
            end
        end
        i = i + 1
    end
    return table.concat(parts)
end

local function onResult(success, data, err, callback)
    if not success then
        handleError(err or "DB Fehler")
        return
    end
    if callback then
        callback(data or {})
    end
end

function KIRCHEN_DB.Query(query, params, callback)
    if not connected then
        handleError("Keine DB-Verbindung")
        return
    end

    local finalQuery = prepare(query, params)

    if adapter == "tmysql4" then
        dbObj:Query(finalQuery, function(results)
            if not results or not results[1] then
                onResult(false, nil, "Leeres Result", callback)
                return
            end
            local res = results[1]
            local success = res.status == true
            onResult(success, res.data, res.error, callback)
        end)
        return
    end

    local q = dbObj:query(finalQuery)
    function q:onSuccess(data)
        onResult(true, data, nil, callback)
    end
    function q:onError(err)
        onResult(false, nil, err, callback)
    end
    q:start()
end

function KIRCHEN_DB.Escape(str)
    return escape(str)
end

hook.Add("Initialize", "Kirche_DB_Init", function()
    KIRCHEN_DB.Connect()
end)
