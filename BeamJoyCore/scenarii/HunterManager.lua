local M = {
    MINIMUM_PARTICIPANTS = 3,
    STATES = {
        PREPARATION = 1,
        GAME = 2,
    },
    CLIENT_EVENTS = {
        JOIN = "join",
        READY = "ready",
        LEAVE = "leave",
        CHECKPOINT_REACHED = "checkpointReached",
        ELIMINATED = "eliminated",
    },

    state = nil,
    participants = {},
    preparationTimeout = nil,
    huntedConfig = nil,
    hunterConfigs = {},
    waypoints = 0,
    huntedStartTime = nil,
    hunterStartTime = nil,
}

local function stop()
    BJCAsync.removeTask("BJCHunterPreparation")
    M.state = nil
    M.participants = {}
    M.preparationTimeout = nil
    M.huntedConfig = nil
    M.hunterConfigs = {}
    M.waypoints = 0
    M.huntedStartTime = nil
    M.hunterStartTime = nil
end

local function getCache()
    return {
        minimumParticipants = M.MINIMUM_PARTICIPANTS,
        state = M.state,
        participants = M.participants,
        preparationTimeout = M.preparationTimeout,
        huntedConfig = M.huntedConfig,
        hunterConfigs = M.hunterConfigs,
        waypoints = M.waypoints,
        huntedStartTime = M.huntedStartTime,
        hunterStartTime = M.hunterStartTime,
        huntersRespawnDelay = BJCConfig.Data.Hunter.HuntersRespawnDelay,
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({
        M.state,
        M.participants,
        M.preparationTimeout,
        M.huntedConfig,
        M.hunterConfigs,
        M.waypoints,
        M.huntedStartTime,
        M.hunterStartTime,
        BJCConfig.Data.Hunter.HuntersRespawnDelay,
    })
end

local function onPreparationTimeout()
    -- remove no vehicle players from participants, and add vehIDs
    for playerID, participant in pairs(M.participants) do
        local p = BJCPlayers.Players[playerID]
        if tlength(p.vehicles) == 0 then
            M.participants[playerID] = nil
        else
            if not participant.gameVehID then
                for _, v in pairs(p.vehicles) do
                    participant.gameVehID = v.vid
                    break
                end
            end
            participant.ready = true
        end
    end

    -- check players amount
    if tlength(M.participants) < M.MINIMUM_PARTICIPANTS then
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.ERROR, "rx.errors.insufficientPlayers")
        stop()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
        return
    end

    local hunted, firstID = false, nil
    for playerID, p in pairs(M.participants) do
        if not firstID then
            firstID = playerID
        end
        if p.hunted then
            hunted = true
            break
        end
    end
    if not hunted then
        LogError("Hunted player not found")
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.ERROR, "hunter.invalidHunted")
        stop()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
        return
    end

    -- start game
    M.state = M.STATES.GAME
    M.huntedStartTime = GetCurrentTime() + BJCConfig.Data.Hunter.HuntedStartDelay
    M.hunterStartTime = GetCurrentTime() + BJCConfig.Data.Hunter.HuntersStartDelay
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function onStart(settings)
    if not BJCScenario.Hunter.enabled then
        error({ key = "rx.errors.invalidData" })
    elseif BJCPerm.getCountPlayersCanSpawnVehicle() < M.MINIMUM_PARTICIPANTS then
        error({ key = "rx.errors.insufficientPlayers" })
    elseif M.state then
        error({ key = "rx.errors.invalidData" })
    else
        -- validate settings
        settings.waypoints = tonumber(settings.waypoints)
        if not settings.hunterConfigs then
            error({ key = "rx.errors.invalidData" })
        elseif not settings.waypoints or settings.waypoints < 1 then
            error({ key = "rx.errors.invalidData" })
        end
    end

    BJCScenario.stopServerScenarii()
    M.participants = {}
    M.huntedConfig = settings.huntedConfig
    M.hunterConfigs = settings.hunterConfigs
    M.waypoints = settings.waypoints
    M.state = M.STATES.PREPARATION
    M.preparationTimeout = GetCurrentTime() + BJCConfig.Data.Hunter.PreparationTimeout
    BJCAsync.programTask(onPreparationTimeout, M.preparationTimeout, "BJCHunterPreparation")
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function sanitizePreparationHunted()
    if tlength(M.participants) > 0 then
        local hunted, firstID = false, nil
        for playerID, p in pairs(M.participants) do
            if not firstID then
                firstID = playerID
            end
            if p.hunted then
                hunted = true
                break
            end
        end
        if not hunted and firstID then
            M.participants[firstID].hunted = true
            M.participants[firstID].ready = false
            M.participants[firstID].waypoint = 0
            M.participants[firstID].eliminated = false
        end
    end
end

local function onJoin(senderID)
    if M.participants[senderID] then
        -- leave participants
        M.participants[senderID] = nil
        sanitizePreparationHunted()
    elseif tlength(M.participants) == 0 then
        -- first to join is hunted
        M.participants[senderID] = {
            hunted = true,
            ready = false,
            waypoint = 0,
        }
    else
        -- others are hunters
        M.participants[senderID] = {
            hunted = false,
            ready = false,
        }
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function onReady(senderID, gameVehID)
    M.participants[senderID].ready = true
    M.participants[senderID].gameVehID = gameVehID
    if tlength(M.participants) >= M.MINIMUM_PARTICIPANTS then
        local allReady = true
        for _, p in pairs(M.participants) do
            if not p.ready then
                allReady = false
                break
            end
        end
        if allReady then
            BJCAsync.removeTask("BJCHunterPreparation")
            onPreparationTimeout()
        end
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function onLeave(senderID)
    local needStop = M.participants[senderID].hunted
    M.participants[senderID] = nil
    if needStop or tlength(M.participants) < 3 then
        stop()
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function onGameEnd(huntedWinner)
    local key = huntedWinner and "hunter.huntedWinner" or "hunter.huntersWinners"
    BJCTx.player.flash(BJCTx.ALL_PLAYERS, key)
    stop()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function onRx(senderID, event, data)
    if M.state == M.STATES.PREPARATION then
        if event == M.CLIENT_EVENTS.JOIN then
            onJoin(senderID)
        elseif event == M.CLIENT_EVENTS.READY then
            if M.participants[senderID] then
                onReady(senderID, data)
            end
        end
    elseif M.state == M.STATES.GAME then
        local participant = M.participants[senderID]
        if event == M.CLIENT_EVENTS.LEAVE and participant then
            if participant.hunted then
                -- hunters win
                onGameEnd(false)
            elseif tlength(M.participants) < 3 then
                -- hunted win
                onGameEnd(true)
            else
                onLeave(senderID)
            end
        elseif event == M.CLIENT_EVENTS.CHECKPOINT_REACHED then
            if participant and participant.hunted then
                participant.waypoint = participant.waypoint + 1
                if participant.waypoint >= M.waypoints then
                    onGameEnd(true)
                else
                    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
                end
            end
        elseif event == M.CLIENT_EVENTS.ELIMINATED then
            if participant and participant.hunted then
                -- hunters win
                onGameEnd(false)
            end
        end
    end
end

local function onPlayerDisconnect(playerID)
    if M.state and M.participants[playerID] then
        local needStop = M.state == M.STATES.GAME and M.participants[playerID].hunted
        M.participants[playerID] = nil
        if M.state == M.STATES.GAME then
            if needStop or tlength(M.participants) < 3 then
                stop()
            end
        else
            sanitizePreparationHunted()
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
    end
end

local function postVehicleDeleted(playerID, vehID)
    if M.state and M.participants[playerID] then
        local needStop = M.state == M.STATES.GAME and M.participants[playerID].hunted
        M.participants[playerID] = nil
        if needStop or tlength(M.participants) < 3 then
            stop()
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
    end
end

local function canSpawnOrEditVehicle(playerID, vehID, vehData)
    local participant = M.participants[playerID]
    return M.state == M.STATES.PREPARATION and participant and not participant.ready
end

local function onStop()
    if M.state == M.STATES.GAME then
        BJCTx.player.flash(BJCTx.ALL_PLAYERS, "hunter.draw")
    end
    stop()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.start = onStart
M.rx = onRx
M.stop = onStop

M.onPlayerDisconnect = onPlayerDisconnect
M.postVehicleDeleted = postVehicleDeleted
M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle

RegisterBJCManager(M)
return M
