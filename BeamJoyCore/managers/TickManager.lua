local M = {
    _ageTimer = MP.CreateTimer(),
    _autosaveTimer = 0
}

function _BJCSlowTick()
    --local age = M._ageTimer:GetCurrent() * 1000

    if MP.GetPlayerCount() > 0 then
        BJCEnvironment.tickTime()

        local serverTickData = {}
        local env = BJCEnvironment.Data
        if env.controlSun and env.timePlay then
            serverTickData.ToD = env.ToD
        end
        serverTickData.cachesHashes = {
            [BJCCache.CACHES.PLAYERS] = BJCPlayers.getCachePlayersHash(),
            [BJCCache.CACHES.DATABASE_PLAYERS] = BJCPlayers.getCacheDatabasePlayersHash(),
            [BJCCache.CACHES.GROUPS] = BJCGroups.getCacheHash(),
            [BJCCache.CACHES.PERMISSIONS] = BJCPerm.getCacheHash(),
            [BJCCache.CACHES.ENVIRONMENT] = BJCEnvironment.getCacheHash(),
            [BJCCache.CACHES.DATABASE_VEHICLES] = BJCVehicles.getCacheHash(),
            [BJCCache.CACHES.RACES] = BJCScenario.getCacheRacesHash(),
            [BJCCache.CACHES.DELIVERIES] = BJCScenario.getCacheDeliveriesHash(),
            [BJCCache.CACHES.STATIONS] = BJCScenario.getCacheStationsHash(),
            [BJCCache.CACHES.BJC] = BJCConfig.getCacheHash(),
            [BJCCache.CACHES.CORE] = BJCCore.getCacheHash(),
            [BJCCache.CACHES.MAPS] = BJCMaps.getCacheMapsHash(),
            [BJCCache.CACHES.MAP] = BJCMaps.getCacheMapHash(),
            [BJCCache.CACHES.VOTE] = BJCVote.getCacheHash(),
            [BJCCache.CACHES.LANG] = BJCLang.getCacheHash(),
        }
        serverTickData.serverTime = GetCurrentTime()
        for playerID in pairs(BJCPlayers.Players) do
            serverTickData.cachesHashes[BJCCache.CACHES.USER] = BJCPlayers.getCacheUserHash(playerID)
            BJCTx.player.tick(playerID, serverTickData)
        end

        BJCChat.broadcastTick()
    end

    TriggerBJCManagers("slowTick")
end
MP.RegisterEvent("slowTick", "_BJCSlowTick")
MP.CreateEventTimer("slowTick", 1000)

function _BJCFastTick()
    BJCAsync.renderTick()
end
MP.RegisterEvent("fastTick", "_BJCFastTick")
MP.CreateEventTimer("fastTick", 100)

return M
