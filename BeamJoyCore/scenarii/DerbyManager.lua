local M = {
    MINIMUM_PARTICIPANTS = function()
        if BJCCore.Data.General.Debug then
            return 1
        end
        return 3
    end,
    -- received events
    CLIENT_EVENTS = {
        JOIN = "Join",           -- preparation
        READY = "Ready",         -- preparation
        LEAVE = "Leave",         -- game
        DESTROYED = "Destroyed", -- game
    },
    STATES = {
        PREPARATION = 1, -- time when all players choose cars and mark ready
        GAME = 2,        -- time during game / spectate
    },

    state = nil,
    baseArena = nil,
    settings = {
        lives = 0,
        configs = nil,
    },

    participants = Table(),

    preparation = {
        timeout = nil,
    },
    game = {
        startTime = nil,
    },

    countInvalidVehicles = {}, -- count to detect invalid setting config
}

local function getParticipantPosition(playerID)
    for i, participant in ipairs(M.participants) do
        if participant.playerID == playerID then
            return i
        end
    end

    return nil
end

local function cancelPreparationTimeout()
    BJCAsync.removeTask("BJCDerbyPreparationTimeout")
end

-- ends the derby
local function stopDerby()
    cancelPreparationTimeout()
    M.state = nil
    M.baseArena = nil
    M.settings = {
        lives = 0,
    }
    M.participants = Table()
    M.preparation = {
        timeout = nil,
    }
    M.game = {
        startTime = nil,
    }

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
end

local function onClientStopDerby()
    if not M.state then
        error({ key = "rx.errors.invalidData" })
    end

    stopDerby()
end

local function startDerby()
    cancelPreparationTimeout()
    M.game.startTime = GetCurrentTime() + BJCConfig.Data.Derby.StartCountdown
    M.countInvalidVehicles = {}
    M.state = M.STATES.GAME

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
end

local function checkDerbyReady()
    if M.state == M.STATES.PREPARATION and
        #M.participants >= M.MINIMUM_PARTICIPANTS() then
        local everyoneReady = true
        for _, participant in ipairs(M.participants) do
            if not participant.ready then
                everyoneReady = false
                break
            end
        end
        if everyoneReady then
            startDerby()
        end
    end
end

local function onPreparationTimeout()
    -- remove no vehicle players from participants
    for iParticipant, participant in ipairs(M.participants) do
        if not participant.ready then
            local player = BJCPlayers.Players[participant.playerID]
            if table.length(player.vehicles) == 0 then
                table.remove(M.participants, iParticipant)
            else
                participant.ready = true
                if not participant.gameVehID then
                    for _, veh in pairs(player.vehicles) do
                        participant.gameVehID = veh.gameVehID
                        break
                    end
                end
            end
        end
    end

    if #M.participants < M.MINIMUM_PARTICIPANTS() then
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.derby",
            reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
        })
        stopDerby()
    else
        startDerby()
        local reward = BJCConfig.Data.Reputation.DerbyParticipationReward
        for _, participant in pairs(M.participants) do
            BJCPlayers.reward(participant.playerID, reward)
        end
    end
end

local function startPreparationTimeout(time)
    BJCAsync.programTask(onPreparationTimeout, time, "BJCDerbyPreparationTimeout")
end

local function start(derbyIndex, lives, configs)
    BJCScenario.stopServerScenarii()
    for _, player in pairs(BJCPlayers.Players) do
        player.scenario = nil
    end

    M.baseArena = table.deepcopy(BJCScenario.Derby[derbyIndex])
    M.settings.lives = lives
    M.settings.configs = configs and table.deepcopy(configs) or {}
    while #M.settings.configs >= 6 do -- limit to 5 configs max
        table.remove(M.settings.configs, 6)
    end

    M.participants = Table()
    M.preparation.timeout = GetCurrentTime() + BJCConfig.Data.Derby.PreparationTimeout

    M.state = M.STATES.PREPARATION
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
    BJCChat.sendChatEvent("chat.events.gamemodeStarted", {
        gamemode = "chat.events.gamemodes.derby",
    })
    startPreparationTimeout(M.preparation.timeout)
end

local function stop()
    if M.state then
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.derby",
            reason = "chat.events.gamemodeStopReasons.manual",
        })
        stopDerby()
    end
end

local function sortParticipants()
    if #M.participants < 2 then
        return
    end
    -- sort players by eliminationTime existing first, then by most lives remainings
    table.sort(M.participants, function(a, b)
        if a.eliminationTime and b.eliminationTime then
            return a.eliminationTime < b.eliminationTime
        end
        if a.eliminationTime then
            return false
        end
        if b.eliminationTime then
            return true
        end
        return a.lives > b.lives
    end)
end

local function finishDerby()
    local winner = M.participants[1] and BJCPlayers.Players[M.participants[1].playerID] or nil
    local second = M.participants[2]
    if winner and (not second or second.eliminationTime) then
        BJCTx.player.flash(BJCTx.ALL_PLAYERS, "derby.winner", { playerName = winner.playerName }, 5)
        for i, participant in ipairs(M.participants) do
            local reward = math.round(BJCConfig.Data.Reputation.DerbyWinnerReward / i)
            BJCPlayers.reward(participant.playerID, reward)
        end
    else
        BJCTx.player.flash(BJCTx.ALL_PLAYERS, "derby.draw", {}, 5)
    end

    BJCAsync.delayTask(stopDerby, BJCConfig.Data.Derby.EndTimeout)
end

local function onClientDestroyed(playerID, time)
    local pos
    for i, lbData in ipairs(M.participants) do
        if lbData.playerID == playerID then
            pos = i
            break
        end
    end
    if not pos then
        -- not a participant
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local participant = M.participants[pos]
    if participant.lives > 0 then
        participant.lives = participant.lives - 1
    else
        participant.eliminationTime = time
    end

    sortParticipants()
    if participant.eliminationTime then
        local position = 1
        M.participants:find(function(p) return p.playerID == playerID end, function(_, pos)
            position = pos
        end)
        BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
            playerName = BJCPlayers.Players[playerID].playerName,
            gamemode = "chat.events.gamemodes.derby",
            position = position,
        })
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)

    if not M.participants[math.min(2, M.MINIMUM_PARTICIPANTS())] or
        M.participants[math.min(2, M.MINIMUM_PARTICIPANTS())].eliminationTime then
        BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
            playerName = BJCPlayers.Players[M.participants[1].playerID].playerName,
            gamemode = "chat.events.gamemodes.derby",
            gamemodePosition = 1,
        })
        finishDerby()
    end
end

local function onClientUpdate(senderID, event, data)
    if M.state == M.STATES.PREPARATION then
        if event == M.CLIENT_EVENTS.JOIN then
            local pos
            M.participants:find(function(p) return p.playerID == senderID end, function(_, position)
                pos = position
                table.remove(M.participants, pos)
                checkDerbyReady()
            end)
            if not pos then
                M.participants:insert({
                    playerID = senderID,
                    lives = M.settings.lives,
                    ready = false,
                    eliminationTime = nil,
                })
            end

            BJCChat.sendChatEvent(pos and "chat.events.gamemodeLeave" or "chat.events.gamemodeJoin", {
                playerName = BJCPlayers.Players[senderID].playerName,
                gamemode = "chat.events.gamemodes.derby",
            })
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
        elseif event == M.CLIENT_EVENTS.READY then
            M.participants:find(function(p) return p.playerID == senderID end, function(_, pos)
                M.participants[pos].gameVehID = data
                M.participants[pos].ready = true
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
                checkDerbyReady()
            end)
        end
    elseif M.state == M.STATES.GAME then
        if event == M.CLIENT_EVENTS.LEAVE then
            M.participants:find(function(p) return p.playerID == senderID end, function(p, pos)
                if not p.eliminationTime then
                    p.eliminationTime = data
                    sortParticipants()
                    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
                    if not M.participants[math.min(2, M.MINIMUM_PARTICIPANTS())] or
                        M.participants[math.min(2, M.MINIMUM_PARTICIPANTS())].eliminationTime then
                        finishDerby()
                    end
                end
            end)
        elseif event == M.CLIENT_EVENTS.DESTROYED then
            onClientDestroyed(senderID, data)
        end
    end
end

local function canSpawnOrEditVehicle(playerID, vehID, vehData)
    if not M.state then
        return true
    elseif M.state == M.STATES.PREPARATION then
        local pos = getParticipantPosition(playerID)
        M.participants:find(function(p) return p.playerID == playerID end, function(_, position)
            pos = position
        end)
        if not pos or not vehData then
            return false
        end

        if type(M.settings.configs) == "table" then
            -- forced config
            local found = false
            for _, config in ipairs(M.settings.configs) do
                if vehData.vcf.model == config.model and
                    BJCScenario.isVehicleSpawnedMatchesRequired(vehData.vcf.parts, config.parts) then
                    found = true
                    break
                end
            end
            if not found then
                M.countInvalidVehicles[playerID] = true
                if table.length(M.countInvalidVehicles) > 1 then
                    -- 2 players tried to spawn an invalid vehicle => surely the config setting is broken
                    BJCAsync.delayTask(function()
                        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                            gamemode = "chat.events.gamemodes.derby",
                            reason = "chat.events.gamemodeStopReasons.invalidVehConfig",
                        })
                        stopDerby()
                    end, 0)
                end
            end
            return found
        end

        -- no model restriction
        return true
    end
    -- during game
    return false
end

local function onPlayerDisconnect(targetID)
    if M.state then
        local pos = getParticipantPosition(targetID)
        if M.state == M.STATES.PREPARATION then
            if pos then
                table.remove(M.participants, pos)
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
            end
        elseif M.state == M.STATES.GAME then
            if pos then
                table.remove(M.participants, pos)
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
                if not M.participants[2] or M.participants[2].eliminationTime and
                    M.participants[1] then
                    BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
                        playerName = BJCPlayers.Players[M.participants[1].playerID].playerName,
                        gamemode = "chat.events.gamemodes.derby",
                        position = 1,
                    })
                    finishDerby()
                end
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
            end
        end
    end
end

local function onVehicleDeleted(playerID, vehID)
    if M.state then
        local pos = getParticipantPosition(playerID)
        if M.state == M.STATES.PREPARATION and pos then
            table.remove(M.participants, pos)
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
            checkDerbyReady()
        elseif M.state == M.STATES.GAME and pos then
            M.participants[pos].eliminationTime = (GetCurrentTime() - M.game.startTime) * 1000
            sortParticipants()

            if not M.participants[2] or M.participants[2].eliminationTime then
                BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
                    playerName = BJCPlayers.Players[M.participants[1].playerID].playerName,
                    gamemode = "chat.events.gamemodes.derby",
                    position = 1,
                })
                finishDerby()
            end
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
        end
    end
end

local function getCache()
    return {
        -- common
        minimumParticipants = M.MINIMUM_PARTICIPANTS(),
        state = M.state,
        destroyedTimeout = BJCConfig.Data.Derby.DestroyedTimeout,
        -- settings
        configs = M.settings.configs or {},
        -- preparation
        baseArena = M.baseArena,
        participants = M.participants,
        preparationTimeout = M.preparation.timeout,
        -- game
        startTime = M.game.startTime,
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({
        M.MINIMUM_PARTICIPANTS(),
        M.state,
        M.baseArena,
        M.preparation,
        M.participants,
        M.game,
        BJCConfig.Data.Derby.DestroyedTimeout,
    })
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.onClientStopDerby = onClientStopDerby

M.start = start
M.stop = stop

M.onClientUpdate = onClientUpdate
M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle

BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_DISCONNECT, onPlayerDisconnect)
BJCEvents.addListener(BJCEvents.EVENTS.VEHICLE_DELETED, onVehicleDeleted)

return M
