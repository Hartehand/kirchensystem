KIRCHEN_DB = KIRCHEN_DB or {}

local cfg = KIRCHEN_CFG
local connected = false
local adapter = string.lower(cfg.Adapter or "mysqloo")
local dbObj

local function log(msg)
    MsgN("[Kirche][DB] " .. msg)
end

local function handleError(err)
    ErrorNoHalt("[Kirche][DB] " .. tostring(err) .. "\n")
end

function KIRCHEN_DB.IsConnected()
    return connected
end

local function connect_mysqloo()
    local mysqloo = mysqloo or require("mysqloo")
    dbObj = mysqloo.connect(cfg.Database.host, cfg.Database.user, cfg.Database.password, cfg.Database.database, cfg.Database.port)

    function dbObj:onConnected()
        connected = true
        log("Verbunden über mysqloo.")
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
