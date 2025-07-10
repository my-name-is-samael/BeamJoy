---@class BJIHunterParticipant
---@field hunted boolean
---@field ready boolean
---@field startPosition?integer
---@field waypoint? integer
---@field gameVehID? integer
---@field eliminated? boolean

---@class BJCScenarioHunter: BJCScenario
local M = {
    name = "Hunter",

    MINIMUM_PARTICIPANTS = function()
        if BJCCore.Data.Debug and
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
    ---@type tablelib<integer, integer> index 1-N, value playerID
    joinOrder = Table(),
    ---@type tablelib<integer, BJIHunterParticipant> index playerID
    participants = Table(),
    ---@type integer?
    preparationTimeout = nil,
    ---@type ClientVehicleConfig?
    huntedConfig = nil,
    ---@type ClientVehicleConfig[]
    hunterConfigs = {},
    waypoints = 0,
    lastWaypointGPS = false,
    huntedStartTime = nil,
    hunterStartTime = nil,
    finished = false,
}

local function cancelGridTimeout()
    BJCAsync.removeTask("BJCHunterGridTimeout")
    M.preparationTimeout = nil
end

local function stop()
    cancelGridTimeout()
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

    BJCScenario.CurrentScenario = nil
end

local function getCache()
    return {
        minimumParticipants = M.MINIMUM_PARTICIPANTS(),
        huntedResetRevealDuration = BJCConfig.Data.Hunter.HuntedResetRevealDuration,
        huntedRevealProximityDistance = BJCConfig.Data.Hunter.HuntedRevealProximityDistance,
        huntedResetDistanceThreshold = BJCConfig.Data.Hunter.HuntedResetDistanceThreshold,
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

local function updateTournamentScores()
    if BJCTournament.state then
        local activityIndex = #BJCTournament.activities
        local hunted, hunters, waypoint = nil, Table(), 0
        M.participants:forEach(function(p, pid)
            if p.hunted then
                hunted = pid
                waypoint = p.waypoint
            else
                hunters:insert(pid)
            end
        end)

        local huntedScore = math.round(math.scale(waypoint, 0, M.waypoints, M.participants:length() - 1, 1))
        local huntersScore = math.round(math.scale(waypoint, 0, M.waypoints, 1, M.participants:length()))
        if hunted and BJCPlayers.Players[hunted] then
            BJCTournament.editPlayerScore(BJCPlayers.Players[hunted].playerName, activityIndex, huntedScore)
        end
        hunters:forEach(function(pid)
            local player = BJCPlayers.Players[pid]
            if player then
                BJCTournament.editPlayerScore(player.playerName, activityIndex, huntersScore)
            end
        end)
    end
end

local function onGridTimeout()
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
        not BJCCore.Data.Debug then
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

    if BJCTournament.state then
        BJCTournament.addActivity(BJCTournament.ACTIVITIES_TYPES.HUNTER)
        updateTournamentScores()
    end
end

local function startGridTimeout()
    M.preparationTimeout = GetCurrentTime() + BJCConfig.Data.Hunter.GridTimeout
    BJCAsync.programTask(onGridTimeout, M.preparationTimeout, "BJCHunterGridTimeout")
end

local function start(settings)
    if not BJCScenarioData.HunterInfected.enabledHunter then
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
    startGridTimeout()

    BJCScenario.CurrentScenario = M
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
    BJCChat.sendChatEvent("chat.events.gamemodeStarted", {
        gamemode = "chat.events.gamemodes.hunter",
    })
end

---@param hunted boolean
---@return integer
local function findFreeStartPosition(hunted)
    if hunted then
        return math.random(1, #BJCScenarioData.HunterInfected.minorPositions)
    else
        return Range(1, #BJCScenarioData.HunterInfected.majorPositions)
            :filter(function(i)
                return not M.participants:any(function(p)
                    return not p.hunted and p.startPosition == i
                end)
            end):random()
    end
end

local function sanitizePreparationHunted()
    M.joinOrder = M.joinOrder:filter(function(playerID)
        return not not M.participants[playerID]
    end)
    if #M.joinOrder > 0 and M.participants[M.joinOrder[1]] then
        local wasHunted = M.participants[M.joinOrder[1]].hunted
        M.participants[M.joinOrder[1]].hunted = true
        M.participants[M.joinOrder[1]].waypoint = 0
        M.participants[M.joinOrder[1]].ready = false
        M.participants[M.joinOrder[1]].eliminated = false
        if not wasHunted then
            M.participants[M.joinOrder[1]].startPosition = findFreeStartPosition(true)
        end
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
        if BJCCore.Data.Debug and MP.GetPlayerCount() == 1 then
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
    cancelGridTimeout()
    M.participants[senderID].ready = true
    M.participants[senderID].gameVehID = gameVehID
    if M.participants:length() >= M.MINIMUM_PARTICIPANTS() then
        if M.participants:every(function(p) return p.ready end) then
            onGridTimeout()
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

local function onClientUpdate(senderID, event, data)
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

                BJCAsync.removeTask("BJCHunterUpdateTournamentScores")
                BJCAsync.delayTask(updateTournamentScores, 0, "BJCHunterUpdateTournamentScores")
            end
        elseif event == M.CLIENT_EVENTS.ELIMINATED then
            if participant and participant.hunted then
                -- hunters win
                onGameEnd(false)
            end
        end
    end
end

local function forceFugitive(playerName)
    if M.state ~= M.STATES.PREPARATION then
        error({ key = "rx.errors.invalidData" })
    end

    local target = Table(BJCPlayers.Players):find(function(p)
        return p.playerName == playerName
    end)
    local pos = target and M.joinOrder:indexOf(target.playerID) or nil
    if not target or not pos or pos == 1 then
        error({ key = "rx.errors.invalidPlayer", data = { playerName = playerName } })
    end

    local previousHunterPosition = M.participants[target.playerID].startPosition
    M.participants[target.playerID].hunted = true
    M.participants[target.playerID].waypoint = 0
    M.participants[target.playerID].ready = false
    M.participants[target.playerID].startPosition = nil -- clear start position to generate a clean one
    while not M.participants[target.playerID].startPosition or
        M.participants[target.playerID].startPosition == M.participants[M.joinOrder[1]].startPosition do
        -- only choose a new start pos to avoid swapped hunter getting spoiled
        M.participants[target.playerID].startPosition = findFreeStartPosition(true)
    end

    M.participants[M.joinOrder[1]].hunted = false
    M.participants[M.joinOrder[1]].waypoint = nil
    M.participants[M.joinOrder[1]].ready = false
    M.participants[M.joinOrder[1]].startPosition = nil -- clear start position to generate a clean one
    M.participants[M.joinOrder[1]].startPosition = findFreeStartPosition(false)

    M.joinOrder:remove(pos)
    M.joinOrder:insert(1, target.playerID)

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    if M.state and M.participants[player.playerID] then
        if M.state == M.STATES.GAME then
            if M.participants[player.playerID].hunted or
                M.participants:length() < M.MINIMUM_PARTICIPANTS() then
                BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                    gamemode = "chat.events.gamemodes.hunter",
                    reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
                })
                stop()
            end
        else
            M.joinOrder:remove(M.joinOrder:indexOf(player.playerID))
            sanitizePreparationHunted()
            if not M.participants:any(function(p) return p.ready end) and
                not BJCAsync.exists("BJCHunterGridTimeout") then
                startGridTimeout()
            end
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
        M.participants[player.playerID] = nil
    end
end

local function onVehicleDeleted(playerID, vehID)
    if M.state == M.STATES.GAME and M.participants[playerID] then
        local needStop = M.participants[playerID].hunted or
            table.length(M.participants) - 1 < M.MINIMUM_PARTICIPANTS()
        M.participants[playerID] = nil
        if needStop then
            BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                gamemode = "chat.events.gamemodes.hunter",
                reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
            })
            stop()
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
    end
end

---@param playerID integer
---@param vehID integer
---@param vehData ServerVehicleConfig
local function canSpawnOrEditVehicle(playerID, vehID, vehData)
    local participant = M.participants[playerID]
    if M.state == M.STATES.PREPARATION and participant and not participant.ready then
        if participant.hunted then
            -- fugitive
            if M.huntedConfig then
                local model = vehData.jbm or vehData.vcf.model or vehData.vcf.mainPartName
                return model == M.huntedConfig.model and
                    BJCScenario.isVehicleSpawnedMatchesRequired(vehData.vcf.parts, M.huntedConfig.parts)
            end
            -- no config restriction
            return true
        else
            -- hunter
            if #M.hunterConfigs > 0 then
                local model = vehData.jbm or vehData.vcf.model or vehData.vcf.mainPartName
                return Table(M.hunterConfigs):any(function(config)
                    return model == config.model and
                        BJCScenario.isVehicleSpawnedMatchesRequired(vehData.vcf.parts, config.parts)
                end)
            end
            -- no config restriction
            return true
        end
    end
    -- during game
    return false
end

local function onStop()
    if M.state then
        if M.state == M.STATES.GAME then
            BJCTx.player.flash(BJCTx.ALL_PLAYERS, "hunter.draw")
        end
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.hunter",
            reason = "chat.events.gamemodeStopReasons.moderation",
        })
        stop()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER)
    end
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.start = start
M.clientUpdate = onClientUpdate
M.forceFugitive = forceFugitive
M.stop = onStop
M.forceStop = onStop

M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle
M.onPlayerDisconnect = onPlayerDisconnect
M.onVehicleDeleted = onVehicleDeleted

return M
