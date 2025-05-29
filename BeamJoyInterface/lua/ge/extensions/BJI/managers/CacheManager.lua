---@class BJIManagerCache : BJIManager
local M = {
    _name = "Cache",

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

    ---@type table<string, tablelib<function>>
    CACHE_HANDLERS = {},
}

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
        return not M.CACHE_PERMISSIONS[cacheType] or BJI.Managers.Perm.hasPermission(M.CACHE_PERMISSIONS[cacheType])
    end)

    if finalCaches:length() > 0 then
        finalCaches:forEach(function(cacheType)
            M._states[cacheType] = M.CACHE_STATES.PROCESSING
        end)
        LogDebug(string.var("Requesting caches : {1}", { finalCaches:join(", ") }), M._name)
        BJI.Tx.cache.require(finalCaches)
    end
end

local function invalidate(cacheType)
    if M._states[cacheType] then
        M._states[cacheType] = M.CACHE_STATES.EMPTY
    end
end

local function handleRx(cacheType, cacheData, cacheHash)
    LogDebug(string.var("Received cache {1}", { cacheType }), M._name)

    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.CACHE_LOADED, {
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
    if not BJI.CLIENT_READY then
        return
    end

    local cachesToRequest = Table()
    if ctxt.cachesHashes then
        -- if a hash has changed
        cachesToRequest:addAll(Table(ctxt.cachesHashes):filter(function(hash, cacheType)
            return M.isCacheReady(cacheType) and M._hashes[cacheType] ~= hash
        end):keys())
    end

    -- base caches
    cachesToRequest:addAll(Table(M.BASE_CACHES):filter(function(cacheType)
        return M._states[cacheType] == M.CACHE_STATES.EMPTY
    end))

    if M.areBaseCachesFirstLoaded() then
        -- post base caches load, other caches
        cachesToRequest:addAll(Table(M.CACHES):filter(function(cacheType)
            return not table.includes(M.BASE_CACHES, cacheType) and
                M._states[cacheType] == M.CACHE_STATES.EMPTY
        end):values())
    end

    _tryRequestCaches(cachesToRequest)
end

M.addRxHandler = addRxHandler
M.isCacheReady = isCacheReady
M.isFirstLoaded = isFirstLoaded
M.areBaseCachesFirstLoaded = areBaseCachesFirstLoaded
M.invalidate = invalidate
M.handleRx = handleRx

M.onLoad = function()
    M.BASE_CACHES = {
        M.CACHES.USER,
        M.CACHES.GROUPS,
        M.CACHES.PERMISSIONS,
        M.CACHES.LANG
    }
    M.CACHE_PERMISSIONS = {
        [M.CACHES.DELIVERIES] = BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO,

        [M.CACHES.CORE] = BJI.Managers.Perm.PERMISSIONS.SET_CORE,
        [M.CACHES.MAPS] = BJI.Managers.Perm.PERMISSIONS.VOTE_MAP,
    }
    for _, cacheType in pairs(M.CACHES) do
        M._states[cacheType] = M.CACHE_STATES.EMPTY
    end

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
end

M.onUnload = function()
    M._hashes = {}
    M._states = {}
    M._firstLoaded = {}
    M._firstInit = false
    M.CACHE_HANDLERS = {}
end

return M
