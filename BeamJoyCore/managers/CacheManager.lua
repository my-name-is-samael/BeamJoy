local M = {
    CACHES = {
        -- player
        LANG = "lang",
        USER = "user",
        GROUPS = "groups",
        PLAYERS = "players",
        MAP = "map",
        ENVIRONMENT = "environment",
        PERMISSIONS = "permissions",
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
    }
}

local function getTargetMap()
    return {
        [M.CACHES.LANG] = { permission = nil, fn = BJCLang.getCache },
        [M.CACHES.USER] = { permission = nil, fn = BJCPlayers.getCacheUser },
        [M.CACHES.GROUPS] = { permission = nil, fn = BJCGroups.getCache },
        [M.CACHES.PERMISSIONS] = { permission = nil, fn = BJCPerm.getCache },
        [M.CACHES.ENVIRONMENT] = { permission = nil, fn = BJCEnvironment.getCache },
        [M.CACHES.BJC] = { permission = nil, fn = BJCConfig.getCache },
        [M.CACHES.PLAYERS] = { permission = nil, fn = BJCPlayers.getCachePlayers },
        [M.CACHES.MAP] = { permission = nil, fn = BJCMaps.getCacheMap },
        [M.CACHES.VOTE] = { permission = nil, fn = BJCVote.getCache },
        [M.CACHES.RACES] = { permission = nil, fn = BJCScenario.getCacheRaces },
        [M.CACHES.RACE] = { permission = nil, fn = BJCScenario.RaceManager.getCache },
        [M.CACHES.DELIVERIES] = { permission = BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO, fn = BJCScenario.getCacheDeliveries },
        [M.CACHES.DELIVERY_MULTI] = { permission = BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO, fn = BJCScenario.DeliveryMultiManager.getCache },
        [M.CACHES.STATIONS] = { permission = nil, fn = BJCScenario.getCacheStations },
        [M.CACHES.BUS_LINES] = { permission = BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO, fn = BJCScenario.getCacheBusLines },
        [M.CACHES.SPEED] = { permission = nil, fn = BJCScenario.SpeedManager.getCache },
        [M.CACHES.DATABASE_VEHICLES] = { permission = nil, fn = BJCVehicles.getCache },
        [M.CACHES.CORE] = { permission = BJCPerm.PERMISSIONS.SET_CORE, fn = BJCCore.getCache },
        [M.CACHES.MAPS] = { permission = BJCPerm.PERMISSIONS.VOTE_MAP, fn = BJCMaps.getCacheMaps },
        [M.CACHES.HUNTER_DATA] = { permission = nil, fn = BJCScenario.getCacheHunter },
        [M.CACHES.HUNTER] = { permission = nil, fn = BJCScenario.HunterManager.getCache },
        [M.CACHES.DERBY_DATA] = { permission = nil, fn = BJCScenario.getCacheDerby },
        [M.CACHES.DERBY] = { permission = nil, fn = BJCScenario.DerbyManager.getCache },
        [M.CACHES.TAG_DUO] = { permission = BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO, fn = BJCScenario.TagDuoManager.getCache },
    }
end

local function getCache(ctxt, cacheType)
    local target = getTargetMap()[cacheType]
    if not target or (target.permission and not BJCPerm.hasPermission(ctxt.senderID, target.permission)) then
        return
    end

    local cache, hash = {}, tostring(GetCurrentTime())
    if target.fn then
        cache, hash = target.fn(ctxt.senderID)
    end

    BJCTx.cache.send(ctxt.senderID, cacheType, cache, hash)
end

local function slowTick()
    if MP.GetPlayerCount() > 0 then
        BJCEnvironment.tickTime()

        local serverTickData = {}
        local env = BJCEnvironment.Data
        if env and env.controlSun and env.timePlay then
            serverTickData.ToD = env.ToD
        end
        serverTickData.cachesHashes = {
            [BJCCache.CACHES.LANG] = BJCLang.getCacheHash(),
            [BJCCache.CACHES.GROUPS] = BJCGroups.getCacheHash(),
            [BJCCache.CACHES.PERMISSIONS] = BJCPerm.getCacheHash(),
            [BJCCache.CACHES.ENVIRONMENT] = BJCEnvironment.getCacheHash(),
            [BJCCache.CACHES.BJC] = BJCConfig.getCacheHash(),
            [BJCCache.CACHES.PLAYERS] = BJCPlayers.getCachePlayersHash(),
            [BJCCache.CACHES.MAP] = BJCMaps.getCacheMapHash(),
            [BJCCache.CACHES.VOTE] = BJCVote.getCacheHash(),
            [BJCCache.CACHES.RACES] = BJCScenario.getCacheRacesHash(),
            [BJCCache.CACHES.RACE] = BJCScenario.RaceManager.getCacheHash(),
            [BJCCache.CACHES.DELIVERIES] = BJCScenario.getCacheDeliveriesHash(),
            [BJCCache.CACHES.DELIVERY_MULTI] = BJCScenario.DeliveryMultiManager.getCacheHash(),
            [BJCCache.CACHES.STATIONS] = BJCScenario.getCacheStationsHash(),
            [BJCCache.CACHES.BUS_LINES] = BJCScenario.getCacheBusLinesHash(),
            [BJCCache.CACHES.SPEED] = BJCScenario.SpeedManager.getCacheHash(),
            [BJCCache.CACHES.DATABASE_VEHICLES] = BJCVehicles.getCacheHash(),
            [BJCCache.CACHES.CORE] = BJCCore.getCacheHash(),
            [BJCCache.CACHES.MAPS] = BJCMaps.getCacheMapsHash(),
            [BJCCache.CACHES.HUNTER_DATA] = BJCScenario.getCacheHunterHash(),
            [BJCCache.CACHES.HUNTER] = BJCScenario.HunterManager.getCacheHash(),
            [BJCCache.CACHES.DERBY_DATA] = BJCScenario.getCacheDerbyHash(),
            [BJCCache.CACHES.DERBY] = BJCScenario.DerbyManager.getCacheHash(),
        }
        serverTickData.serverTime = GetCurrentTime()
        for playerID in pairs(BJCPlayers.Players) do
            serverTickData.cachesHashes[BJCCache.CACHES.USER] = BJCPlayers.getCacheUserHash(playerID)
            BJCTx.player.tick(playerID, serverTickData)
        end
    end
end

M.getCache = getCache
BJCEvents.addListener(BJCEvents.EVENTS.SLOW_TICK, slowTick)

return M
