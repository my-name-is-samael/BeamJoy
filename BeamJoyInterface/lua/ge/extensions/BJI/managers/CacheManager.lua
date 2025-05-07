local M = {
    _name = "BJICache",
    CACHES = {
        -- default
        LANG = "lang",
        USER = "user",
        GROUPS = "groups",
        PERMISSIONS = "permissions",
        -- player
        PLAYERS = "players",
        MAP = "map",
        ENVIRONMENT = "environment",
        BJC = "bjc",
        VOTE = "vote",
        RACES = "races",
        RACE = "race",
        DELIVERIES = "deliveries",
        DELIVERY_MULTI = "deliverymulti",
        STATIONS = "stations",
        BUS_LINES = "buslines",
        SPEED = "speed",
        HUNTER_DATA = "hunterdata",
        HUNTER = "hunter",
        DERBY_DATA = "derbydata",
        DERBY = "derby",
        TAG_DUO = "tagduo",
        -- admin
        DATABASE_PLAYERS = "databasePlayers",
        DATABASE_VEHICLES = "databaseVehicles",
        -- owner
        CORE = "core",
        MAPS = "maps",
    },
    CACHE_STATES = {
        EMPTY = 1,
        PROCESSING = 2,
        READY = 3,
    },
    _hashes = {},
    _states = {},
    _firstLoaded = {},
    _firstInit = false, -- true if all base caches are ready at least once
}
M.BASE_CACHES = {
    M.CACHES.USER,
    M.CACHES.GROUPS,
    M.CACHES.PERMISSIONS,
    M.CACHES.LANG
}
M.CACHE_PERMISSIONS = {
    [M.CACHES.DELIVERIES] = BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO,

    [M.CACHES.DATABASE_PLAYERS] = BJIPerm.PERMISSIONS.DATABASE_PLAYERS,

    [M.CACHES.CORE] = BJIPerm.PERMISSIONS.SET_CORE,
    [M.CACHES.MAPS] = BJIPerm.PERMISSIONS.VOTE_MAP,
}
for _, cacheType in pairs(M.CACHES) do
    M._states[cacheType] = M.CACHE_STATES.EMPTY
end

---@type table<string, tablelib<function>>
M.CACHE_HANDLERS = {}

local function addRxHandler(cacheType, callback)
    if not Table(M.CACHES):includes(cacheType) then
        error(string.var("Invalid cache type: {1}", { cacheType }))
    end
    if not M.CACHE_HANDLERS[cacheType] then
        M.CACHE_HANDLERS[cacheType] = Table()
    end
    M.CACHE_HANDLERS[cacheType]:insert(callback)
end

local function isCacheReady(cacheType)
    return M._states[cacheType] == M.CACHE_STATES.READY
end

local function isFirstLoaded(cacheType)
    return table.includes(M._firstLoaded, cacheType)
end

local function areBaseCachesFirstLoaded()
    if M._firstInit then
        return true
    end

    local loaded = true
    for _, cacheType in pairs(M.BASE_CACHES) do
        if not M.isCacheReady(cacheType) then
            loaded = false
        end
    end
    if loaded then
        M._firstInit = true
    end
    return loaded
end

---@param cachesToRequest tablelib<string>
local function _tryRequestCaches(cachesToRequest)
    ---@type tablelib<string>
    local finalCaches = cachesToRequest:filter(function(cacheType)
        return not M.CACHE_PERMISSIONS[cacheType] or BJIPerm.hasPermission(M.CACHE_PERMISSIONS[cacheType])
    end)

    if finalCaches:length() > 0 then
        finalCaches:forEach(function(cacheType)
            M._states[cacheType] = M.CACHE_STATES.PROCESSING
        end)
        LogDebug(string.var("Requesting caches : {1}", { finalCaches:join(", ") }), M._name)
        BJITx.cache.require(finalCaches)
    end
end

local function invalidate(cacheType)
    if M._states[cacheType] then
        M._states[cacheType] = M.CACHE_STATES.EMPTY
    end
end

local function handleRx(cacheType, cacheData, cacheHash)
    LogDebug(string.var("Received cache {1}", { cacheType }), M._name)

    BJIEvents.trigger(BJIEvents.EVENTS.CACHE_LOADED, {
        cache = cacheType,
        hash = cacheHash,
    })

    if M.CACHE_HANDLERS[cacheType] then
        M.CACHE_HANDLERS[cacheType]:forEach(function(handler)
            local status, err = pcall(handler, cacheData)
            if not status then
                LogError(string.var("Error handling cache {1} : {2}", { cacheType, err }))
            end
        end)
    end
    M._hashes[cacheType] = cacheHash
    M._states[cacheType] = M.CACHE_STATES.READY
    if not table.includes(M._firstLoaded, cacheType) then
        table.insert(M._firstLoaded, cacheType)
    end
end

---@param ctxt SlowTickContext
local function slowTick(ctxt)
    if not BJICONNECTED then
        return
    end

    -- Table:addAll doesn't work here for a mystical reason Ô_Ô

    local cachesToRequest = Table()
    if ctxt.cachesHashes then
        -- if a hash has changed
        Table(ctxt.cachesHashes):forEach(function(hash, cacheType)
            if M.isCacheReady(cacheType) and M._hashes[cacheType] ~= hash then
                cachesToRequest:insert(cacheType)
            end
        end)
    end

    -- base caches
    Table(M.BASE_CACHES):forEach(function(cacheType)
        if M._states[cacheType] == M.CACHE_STATES.EMPTY then
            cachesToRequest:insert(cacheType)
        end
    end)

    if M.areBaseCachesFirstLoaded() then
        -- post base caches load, other caches
        Table(M.CACHES):forEach(function(cacheType)
            if not table.includes(M.BASE_CACHES, cacheType) and
                M._states[cacheType] == M.CACHE_STATES.EMPTY then
                cachesToRequest:insert(cacheType)
            end
        end)
    end

    _tryRequestCaches(cachesToRequest)
end

M.addRxHandler = addRxHandler
M.isCacheReady = isCacheReady
M.isFirstLoaded = isFirstLoaded
M.areBaseCachesFirstLoaded = areBaseCachesFirstLoaded
M.invalidate = invalidate
M.handleRx = handleRx

M.slowTick = slowTick

RegisterBJIManager(M)
return M
