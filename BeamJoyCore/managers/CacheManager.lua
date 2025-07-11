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
        HUNTER_INFECTED_DATA = "hunterinfecteddata",
        HUNTER = "hunter",
        INFECTED = "infected",
        DERBY_DATA = "derbydata",
        DERBY = "derby",
        TAG_DUO = "tagduo",
        TOURNAMENT = "tournament",
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
        [M.CACHES.RACES] = { permission = nil, fn = BJCScenarioData.getCacheRaces },
        [M.CACHES.RACE] = { permission = nil, fn = BJCScenario.RaceManager.getCache },
        [M.CACHES.DELIVERIES] = { permission = BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO, fn = BJCScenarioData.getCacheDeliveries },
        [M.CACHES.DELIVERY_MULTI] = { permission = BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO, fn = BJCScenario.Hybrids.DeliveryMultiManager.getCache },
        [M.CACHES.STATIONS] = { permission = nil, fn = BJCScenarioData.getCacheStations },
        [M.CACHES.BUS_LINES] = { permission = BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO, fn = BJCScenarioData.getCacheBusLines },
        [M.CACHES.SPEED] = { permission = nil, fn = BJCScenario.SpeedManager.getCache },
        [M.CACHES.DATABASE_VEHICLES] = { permission = nil, fn = BJCVehicles.getCache },
        [M.CACHES.CORE] = { permission = BJCPerm.PERMISSIONS.SET_CORE, fn = BJCCore.getCache },
        [M.CACHES.MAPS] = { permission = BJCPerm.PERMISSIONS.VOTE_MAP, fn = BJCMaps.getCacheMaps },
        [M.CACHES.HUNTER_INFECTED_DATA] = { permission = nil, fn = BJCScenarioData.getCacheHunterInfected },
        [M.CACHES.HUNTER] = { permission = nil, fn = BJCScenario.HunterManager.getCache },
        [M.CACHES.INFECTED] = { permission = nil, fn = BJCScenario.InfectedManager.getCache },
        [M.CACHES.DERBY_DATA] = { permission = nil, fn = BJCScenarioData.getCacheDerby },
        [M.CACHES.DERBY] = { permission = nil, fn = BJCScenario.DerbyManager.getCache },
        [M.CACHES.TAG_DUO] = { permission = BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO, fn = BJCScenario.Hybrids.TagDuoManager.getCache },
        [M.CACHES.TOURNAMENT] = { permission = nil, fn = BJCTournament.getCache },
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
            [BJCCache.CACHES.RACES] = BJCScenarioData.getCacheRacesHash(),
            [BJCCache.CACHES.RACE] = BJCScenario.RaceManager.getCacheHash(),
            [BJCCache.CACHES.DELIVERIES] = BJCScenarioData.getCacheDeliveriesHash(),
            [BJCCache.CACHES.DELIVERY_MULTI] = BJCScenario.Hybrids.DeliveryMultiManager.getCacheHash(),
            [BJCCache.CACHES.STATIONS] = BJCScenarioData.getCacheStationsHash(),
            [BJCCache.CACHES.BUS_LINES] = BJCScenarioData.getCacheBusLinesHash(),
            [BJCCache.CACHES.SPEED] = BJCScenario.SpeedManager.getCacheHash(),
            [BJCCache.CACHES.DATABASE_VEHICLES] = BJCVehicles.getCacheHash(),
            [BJCCache.CACHES.CORE] = BJCCore.getCacheHash(),
            [BJCCache.CACHES.MAPS] = BJCMaps.getCacheMapsHash(),
            [BJCCache.CACHES.HUNTER_INFECTED_DATA] = BJCScenarioData.getCacheHunterInfectedHash(),
            [BJCCache.CACHES.HUNTER] = BJCScenario.HunterManager.getCacheHash(),
            [BJCCache.CACHES.INFECTED] = BJCScenario.InfectedManager.getCacheHash(),
            [BJCCache.CACHES.DERBY_DATA] = BJCScenarioData.getCacheDerbyHash(),
            [BJCCache.CACHES.DERBY] = BJCScenario.DerbyManager.getCacheHash(),
            [BJCCache.CACHES.TAG_DUO] = BJCScenario.Hybrids.TagDuoManager.getCacheHash(),
            [BJCCache.CACHES.TOURNAMENT] = BJCTournament.getCacheHash(),
        }
        serverTickData.serverTime = GetCurrentTime()
        for playerID in pairs(BJCPlayers.Players) do
            serverTickData.cachesHashes[BJCCache.CACHES.USER] = BJCPlayers.getCacheUserHash(playerID)
            BJCTx.player.tick(playerID, serverTickData)
        end
    end
end

M.getCache = getCache
BJCEvents.addListener(BJCEvents.EVENTS.SLOW_TICK, slowTick, "CacheManager")

return M
