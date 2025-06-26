---@class BJIHunterParticipant
---@field hunted boolean
---@field ready boolean
---@field startPosition?integer
---@field waypoint? integer
---@field gameVehID? integer
---@field eliminated? boolean

local M = {
    MINIMUM_PARTICIPANTS = function()
        if BJCCore.Data.General.Debug and
            MP.GetPlayerCount() == 1 then
            return 1
        end
        return 2
    end,
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
    -- keep track of players joined participant to have valid hunted everytime
    joinOrder = Table(),
    ---@type tablelib<integer, BJIHunterParticipant>
    participants = Table(),
    preparationTimeout = nil,
    huntedConfig = nil,
    hunterConfigs = {},
    waypoints = 0,
    lastWaypointGPS = false,
    huntedStartTime = nil,
    hunterStartTime = nil,
    finished = false,
}

local function stop()
    BJCAsync.removeTask("BJCHunterPreparation")
    M.state = nil
    M.joinOrder = Table()
    M.participants = Table()
    M.preparationTimeout = nil
    M.huntedConfig = nil
    M.hunterConfigs = {}
    M.waypoints = 0
    M.lastWaypointGPS = false
    M.huntedStartTime = nil
    M.hunterStartTime = nil
    M.finished = false
end

local function getCache()
    return {
        minimumParticipants = M.MINIMUM_PARTICIPANTS(),
        state = M.state,
        participants = M.participants,
        preparationTimeout = M.preparationTimeout,
        huntedConfig = M.huntedConfig,
        hunterConfigs = M.hunterConfigs,
        waypoints = M.waypoints,
        lastWaypointGPS = M.lastWaypointGPS,
        huntedStartTime = M.huntedStartTime,
        hunterStartTime = M.hunterStartTime,
        huntersRespawnDelay = BJCConfig.Data.Hunter.HuntersRespawnDelay,
        finished = M.finished,
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({
        M.MINIMUM_PARTICIPANTS(),
        M.state,
        M.participants,
        M.preparationTimeout,
        M.huntedConfig,
        M.hunterConfigs,
        M.waypoints,
        M.lastWaypointGPS,
        M.huntedStartTime,
        M.hunterStartTime,
        M.finished,
        BJCConfig.Data.Hunter.HuntersRespawnDelay,
    })
end

local function onPreparationTimeout()
    M.participants = M.participants:filter(function(p) return p.ready end)
    -- check players amount
    if M.participants:length() < M.MINIMUM_PARTICIPANTS() then
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.ERROR, "rx.errors.insufficientPlayers")
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.hunter",
            reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
        })
        stop()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
        return
    end

    if not M.participants:any(function(p) return p.hunted end) and
        not BJCCore.Data.General.Debug then
        LogError("Hunted player not found")
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.ERROR, "hunter.invalidHunted")
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.hunter",
            reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
        })
        stop()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
        return
    end

    if M.participants:any(function(p) return not p.ready end) then
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.ERROR, "rx.errors.insufficientPlayers")
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.hunter",
            reason = "chat.events.gamemodeStopReasons.timedout",
        })
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

local function start(settings)
    if not BJCScenario.Hunter.enabled then
        error({ key = "rx.errors.invalidData" })
    elseif BJCPerm.getCountPlayersCanSpawnVehicle() < M.MINIMUM_PARTICIPANTS() then
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
    M.joinOrder = Table()
    M.participants = Table()
    M.huntedConfig = settings.huntedConfig
    M.hunterConfigs = settings.hunterConfigs
    M.waypoints = settings.waypoints
    M.lastWaypointGPS = settings.lastWaypointGPS
    M.state = M.STATES.PREPARATION
    M.preparationTimeout = GetCurrentTime() + BJCConfig.Data.Hunter.PreparationTimeout
    BJCAsync.programTask(onPreparationTimeout, M.preparationTimeout, "BJCHunterPreparation")
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
    BJCChat.sendChatEvent("chat.events.gamemodeStarted", {
        gamemode = "chat.events.gamemodes.hunter",
    })
end

local function sanitizePreparationHunted()
    M.joinOrder = M.joinOrder:filter(function(playerID)
        return not not M.participants[playerID]
    end)
    if #M.joinOrder > 0 and M.participants[M.joinOrder[1]] then
        M.participants[M.joinOrder[1]].hunted = true
        M.participants[M.joinOrder[1]].waypoint = 0
        M.participants[M.joinOrder[1]].ready = false
        M.participants[M.joinOrder[1]].eliminated = false
    end
end

---@param hunted boolean
---@return integer
local function findFreeStartPosition(hunted)
    if hunted then
        return math.random(1, #BJCScenario.Hunter.huntedPositions)
    else
        return Range(1, #BJCScenario.Hunter.hunterPositions)
            :filter(function(i)
                return not M.participants:any(function(p)
                    return not p.hunted and p.startPosition == i
                end)
            end):random()
    end
end

local function onJoin(senderID)
    if M.participants[senderID] then
        -- leave participants
        M.participants[senderID] = nil
        sanitizePreparationHunted()
    elseif M.participants:length() == 0 then
        -- first to join is hunted (or debug)
        local hunted = true
        if BJCCore.Data.General.Debug and MP.GetPlayerCount() == 1 then
            hunted = math.random() > 0.5
        end
        M.participants[senderID] = {
            hunted = hunted,
            ready = false,
            startPosition = findFreeStartPosition(hunted),
            waypoint = 0,
        }
        M.joinOrder:insert(senderID)
    else
        -- others are hunters
        M.participants[senderID] = {
            hunted = false,
            ready = false,
            startPosition = findFreeStartPosition(false),
        }
        M.joinOrder:insert(senderID)
    end
    if M.participants[senderID] then
        BJCChat.sendChatEvent("chat.events.gamemodeJoin", {
            playerName = BJCPlayers.Players[senderID].playerName,
            gamemode = "chat.events.gamemodes.hunter",
        })
    else
        BJCChat.sendChatEvent("chat.events.gamemodeLeave", {
            playerName = BJCPlayers.Players[senderID].playerName,
            gamemode = "chat.events.gamemodes.hunter",
        })
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function onReady(senderID, gameVehID)
    BJCAsync.removeTask("BJCHunterPreparation")
    M.participants[senderID].ready = true
    M.participants[senderID].gameVehID = gameVehID
    if M.participants:length() >= M.MINIMUM_PARTICIPANTS() then
        if M.participants:every(function(p) return p.ready end) then
            onPreparationTimeout()
        end
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function onLeave(senderID)
    local needStop = M.participants[senderID].hunted
    M.participants[senderID] = nil
    if needStop or M.participants:length() < M.MINIMUM_PARTICIPANTS() then
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.hunter",
            reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
        })
        stop()
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

local function onGameEnd(huntedWinner)
    local key = huntedWinner and "hunter.huntedWinner" or "hunter.huntersWinners"
    BJCTx.player.flash(BJCTx.ALL_PLAYERS, key)
    BJCChat.sendChatEvent("chat.events.gamemodeTeamWon", {
        teamName = "chat.events.gamemodeTeams." .. (huntedWinner and "hunted" or "hunters"),
        gamemode = "chat.events.gamemodes.hunter",
    })
    M.finished = true
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)

    BJCAsync.delayTask(stop, BJCConfig.Data.Hunter.EndTimeout)
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
            elseif table.length(M.participants) < M.MINIMUM_PARTICIPANTS() then
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
        if M.state == M.STATES.GAME then
            if M.participants[playerID].hunted or
                M.participants:length() < M.MINIMUM_PARTICIPANTS() then
                BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                    gamemode = "chat.events.gamemodes.hunter",
                    reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
                })
                stop()
            end
        else
            M.joinOrder:remove(M.joinOrder:indexOf(playerID))
            sanitizePreparationHunted()
            if not M.participants:any(function(p) return p.ready end) then
                -- relaunch preparation timeout
                M.preparationTimeout = GetCurrentTime() + BJCConfig.Data.Hunter.PreparationTimeout
                BJCAsync.programTask(onPreparationTimeout, M.preparationTimeout, "BJCHunterPreparation")
            end
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
        M.participants[playerID] = nil
    end
end

local function onVehicleDeleted(playerID, vehID)
    if M.state and M.participants[playerID] then
        local needStop = M.state == M.STATES.GAME and M.participants[playerID].hunted
        M.participants[playerID] = nil
        if needStop or table.length(M.participants) < M.MINIMUM_PARTICIPANTS() then
            BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                gamemode = "chat.events.gamemodes.hunter",
                reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
            })
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
    BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
        gamemode = "chat.events.gamemodes.hunter",
        reason = "chat.events.gamemodeStopReasons.manual",
    })
    stop()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.start = start
M.rx = onRx
M.stop = onStop

BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_DISCONNECT, onPlayerDisconnect)
BJCEvents.addListener(BJCEvents.EVENTS.VEHICLE_DELETED, onVehicleDeleted)
M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle

return M
