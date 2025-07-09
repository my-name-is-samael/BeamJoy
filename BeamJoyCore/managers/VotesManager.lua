local M = {}

-- KICK
M.Kick = {
    ---@type integer? playerID
    creatorID = nil,
    ---@type integer? playerID
    targetID = nil,
    ---@type integer? time
    endsAt = nil,
    ---@type integer[] playerIDs
    voters = {},
}

local function kickStarted()
    return M.Kick.targetID ~= nil
end

local function getKickTotalPlayers()
    return BJCPlayers.getCount(BJCPerm.Data.VoteKick, true) - 1 -- minus target
end

local function getKickThreshold()
    if not kickStarted() then
        return 0
    end
    local thresholdRatio = BJCConfig.Data.VoteKick.ThresholdRatio
    return math.ceil(getKickTotalPlayers() * thresholdRatio)
end

function M.Kick.start(creatorID, targetID)
    if kickStarted() then
        error({ key = "rx.errors.invalidData" })
    elseif BJCPerm.isStaff(creatorID) then
        error({ key = "rx.errors.insufficientPermissions" })
    elseif getKickTotalPlayers() < 2 then
        error({ key = "rx.errors.invalidData" })
    end

    M.Kick.creatorID = creatorID
    M.Kick.targetID = targetID
    M.Kick.endsAt = GetCurrentTime() + BJCConfig.Data.VoteKick.Timeout
    M.Kick.voters = { creatorID }
    BJCAsync.programTask(M.Kick.endVote, M.Kick.endsAt, "BJCVoteKick")

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    BJCChat.sendChatEvent("chat.events.vote", {
        playerName = BJCPlayers.Players[creatorID].playerName,
        voteEvent = "chat.events.voteEvents.playerKick",
        suffix = BJCPlayers.Players[targetID].playerName
    })
end

local function kickReset()
    BJCAsync.removeTask("BJCVoteKick")
    M.Kick.creatorID = nil
    M.Kick.targetID = nil
    M.Kick.endsAt = nil
    M.Kick.voters = {}
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

function M.Kick.endVote()
    if #M.Kick.voters >= getKickThreshold() then
        local ctxt = {}
        BJCInitContext(ctxt)
        local targetName = BJCPlayers.Players[M.Kick.targetID].playerName
        BJCChat.sendChatEvent("chat.events.voteAccepted", {
            voteEvent = "chat.events.voteEvents.playerKick",
            suffix = targetName
        })
        BJCPlayers.kick(ctxt, M.Kick.targetID,
            BJCLang.getServerMessage(M.Kick.targetID, "voteKick.beenVoteKick")
            :var({ votersAmount = #M.Kick.voters }))
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.INFO, "voteKick.playerKicked", { playerName = targetName })
    else
        BJCChat.sendChatEvent("chat.events.voteDenied", {
            voteEvent = "chat.events.voteEvents.playerKick",
            suffix = BJCPlayers.Players[M.Kick.targetID].playerName
        })
    end
    kickReset()
end

function M.Kick.vote(senderID)
    if not kickStarted() then
        error({ key = "rx.errors.invalidData" })
    elseif M.Kick.targetID == senderID then
        error({ key = "rx.errors.invalidData" })
    end

    local pos = table.indexOf(M.Kick.voters, senderID)
    if pos then
        table.remove(M.Kick.voters, pos)
    else
        table.insert(M.Kick.voters, senderID)
    end

    if #M.Kick.voters == 0 then
        BJCChat.sendChatEvent("chat.events.voteDenied", {
            voteEvent = "chat.events.voteEvents.playerKick",
            suffix = BJCPlayers.Players[M.Kick.targetID].playerName
        })
        kickReset()
    else
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    end
end

function M.Kick.stop()
    if kickStarted() then
        BJCChat.sendChatEvent("chat.events.voteCancelled", {
            voteEvent = "chat.events.voteEvents.playerKick",
            suffix = BJCPlayers.Players[M.Kick.targetID].playerName
        })
        kickReset()
    end
end

---@param player BJCPlayer
function M.Kick.onPlayerDisconnect(player)
    if not kickStarted() then
        return
    end

    if M.Kick.targetID == player.playerID or
        getKickTotalPlayers() < 2 then
        kickReset()
        return
    end

    local pos = table.indexOf(M.Kick.voters, player.playerID)
    if pos then
        table.remove(M.Kick.voters, pos)
        if #M.Kick.voters == 0 then
            kickReset()
        end
    end
end

-- MAP
M.Map = {
    ---@type integer? playerID
    creatorID = nil,
    ---@type string? techName
    targetMap = nil,
    ---@type integer? time
    endsAt = nil,

    ---@type integer[] playerIDs
    voters = {},
}

local function mapStarted()
    return M.Map.targetMap ~= nil
end

local function getMapThreshold()
    if not mapStarted() then
        return 0
    end
    local thresholdRatio = BJCConfig.Data.VoteMap.ThresholdRatio
    return math.max(math.ceil(table.length(BJCPlayers.Players) * thresholdRatio), 2)
end

function M.Map.start(senderID, mapName)
    if mapStarted() or M.Scenario.started() then
        error({ key = "rx.errors.invalidData" })
    end

    if not BJCMaps.Data[mapName] then
        error({ key = "rx.errors.invalidData" })
    elseif mapName == BJCCore.getMap() then
        error({ key = "rx.errors.invalidData" })
    end

    if table.length(BJCPlayers.Players) == 1 then
        -- only 1 player can vote, allowing direct map switch
        BJCCore.setMap(mapName)
    else
        M.Map.creatorID = senderID
        M.Map.targetMap = mapName
        M.Map.endsAt = GetCurrentTime() + BJCConfig.Data.VoteMap.Timeout
        M.Map.voters = { senderID }
        BJCAsync.programTask(M.Map.endVote, M.Map.endsAt, "BJCVoteMap")

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
        BJCChat.sendChatEvent("chat.events.vote", {
            playerName = BJCPlayers.Players[senderID].playerName,
            voteEvent = "chat.events.voteEvents.mapSwitch",
            suffix = BJCMaps.Data[mapName].label
        })
    end
end

local function mapReset()
    BJCAsync.removeTask("BJCVoteMap")
    M.Map.creatorID = nil
    M.Map.targetMap = nil
    M.Map.endsAt = nil
    M.Map.voters = {}
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

function M.Map.endVote()
    if #M.Map.voters >= getMapThreshold() then
        BJCChat.sendChatEvent("chat.events.voteAccepted", {
            voteEvent = "chat.events.voteEvents.mapSwitch",
            suffix = BJCMaps.Data[M.Map.targetMap].label
        })
        BJCCore.setMap(M.Map.targetMap)
    else
        BJCChat.sendChatEvent("chat.events.voteDenied", {
            voteEvent = "chat.events.voteEvents.mapSwitch",
            suffix = BJCMaps.Data[M.Map.targetMap].label
        })
    end
    mapReset()
end

function M.Map.vote(senderID)
    if not mapStarted() then
        error({ key = "rx.errors.invalidData" })
    end

    local pos = table.indexOf(M.Map.voters, senderID)
    if pos then
        table.remove(M.Map.voters, pos)
    else
        table.insert(M.Map.voters, senderID)
    end

    if #M.Map.voters == 0 then
        BJCChat.sendChatEvent("chat.events.voteDenied", {
            voteEvent = "chat.events.voteEvents.mapSwitch",
            suffix = BJCMaps.Data[M.Map.targetMap].label
        })
        mapReset()
    else
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    end
end

function M.Map.stop()
    if mapStarted() then
        BJCChat.sendChatEvent("chat.events.voteCancelled", {
            voteEvent = "chat.events.voteEvents.mapSwitch",
            suffix = BJCMaps.Data[M.Map.targetMap].label
        })
        mapReset()
    end
end

---@param player BJCPlayer
function M.Map.onPlayerDisconnect(player)
    if not mapStarted() then
        return
    end

    local pos = table.indexOf(M.Map.voters, player.playerID)
    if pos then
        table.remove(M.Map.voters, pos)
        if #M.Map.voters == 0 then
            mapReset()
        end
    end
end

-- SCENARIO
M.Scenario = {
    TYPES = {
        RACE = "race",
        SPEED = "speed",
        HUNTER = "hunter",
        DERBY = "derby",
        INFECTED = "infected",
    },
    ---@type string?
    type = nil,
    ---@type integer?
    creatorID = nil,
    isVote = false,
    ---@type integer?
    endsAt = nil,
    scenarioData = {},
    ---@type tablelib<integer, true|any> index playerIDs, value true or custom
    voters = Table(),
}

M.Scenario.started = function()
    return M.Scenario.endsAt ~= nil
end

M.Scenario.reset = function()
    BJCAsync.removeTask("BJCVoteScenarioTimeout")
    M.Scenario.type = nil
    M.Scenario.creatorID = nil
    M.Scenario.isVote = false
    M.Scenario.endsAt = nil
    M.Scenario.scenarioData = {}
    M.Scenario.voters = Table()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

M.Scenario.getThreshold = function()
    if not M.Scenario.type then return 0 end
    if M.Scenario.type == "race" then
        return math.ceil(BJCPerm.getCountPlayersCanSpawnVehicle() * BJCConfig.Data.Race.VoteThresholdRatio)
    elseif M.Scenario.type == "speed" then
        return BJCScenario.SpeedManager.MINIMUM_PARTICIPANTS()
    elseif M.Scenario.type == "hunter" then
        return math.ceil(BJCPerm.getCountPlayersCanSpawnVehicle() * BJCConfig.Data.Hunter.VoteThresholdRatio)
    elseif M.Scenario.type == "derby" then
        return math.ceil(BJCPerm.getCountPlayersCanSpawnVehicle() * BJCConfig.Data.Derby.VoteThresholdRatio)
    end
end

local function scenarioStartTimeout()
    if not M.Scenario.started() then return end
    if M.Scenario.type == "race" then
        if M.Scenario.isVote then
            if M.Scenario.voters:length() >= M.Scenario.getThreshold() then
                BJCChat.sendChatEvent("chat.events.voteAccepted", {
                    voteEvent = "chat.events.voteEvents.raceStart",
                    suffix = BJCScenarioData.getRace(M.Scenario.scenarioData.raceID).name
                })
                BJCScenario.RaceManager.start(M.Scenario.scenarioData.raceID, M.Scenario.scenarioData.settings)
                BJCChat.sendChatEvent("chat.events.gamemodeStarted", {
                    gamemode = "chat.events.gamemodes.race",
                })
            else
                BJCChat.sendChatEvent("chat.events.voteDenied", {
                    voteEvent = "chat.events.voteEvents.raceStart",
                    suffix = BJCScenarioData.getRace(M.Scenario.scenarioData.raceID).name
                })
            end
        else
            BJCScenario.RaceManager.start(M.Scenario.scenarioData.raceID, M.Scenario.scenarioData.settings)
        end
    elseif M.Scenario.type == "speed" then
        if M.Scenario.voters:length() >= M.Scenario.getThreshold() then
            if M.Scenario.isVote then
                BJCChat.sendChatEvent("chat.events.voteAccepted", {
                    voteEvent = "chat.events.voteEvents.speedStart",
                    suffix = ""
                })
            end
            BJCScenario.SpeedManager.start(M.Scenario.voters, M.Scenario.isVote)
        else
            if M.Scenario.isVote then
                BJCChat.sendChatEvent("chat.events.voteDenied", {
                    voteEvent = "chat.events.voteEvents.speedStart",
                    suffix = ""
                })
            else
                BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                    gamemode = "chat.events.gamemodes.speed",
                    reason = "chat.events.gamemodeStopReasons.notEnoughParticipants"
                })
            end
        end
    elseif M.Scenario.type == "hunter" then
        if M.Scenario.isVote then
            if M.Scenario.voters:length() >= M.Scenario.getThreshold() then
                BJCChat.sendChatEvent("chat.events.voteAccepted", {
                    voteEvent = "chat.events.voteEvents.hunterStart",
                    suffix = "",
                })
                BJCScenario.HunterManager.start(M.Scenario.scenarioData)
            else
                BJCChat.sendChatEvent("chat.events.voteDenied", {
                    voteEvent = "chat.events.voteEvents.hunterStart",
                    suffix = "",
                })
            end
        else
            BJCScenario.HunterManager.start(M.Scenario.scenarioData)
        end
    elseif M.Scenario.type == "derby" then
        if M.Scenario.isVote then
            if M.Scenario.voters:length() >= M.Scenario.getThreshold() then
                BJCChat.sendChatEvent("chat.events.voteAccepted", {
                    voteEvent = "chat.events.voteEvents.derbyStart",
                    suffix = BJCScenarioData.Derby[M.Scenario.scenarioData.arenaIndex].name
                })
                BJCScenario.DerbyManager.start(M.Scenario.scenarioData.arenaIndex,
                    M.Scenario.scenarioData.lives, M.Scenario.scenarioData.configs)
            else
                BJCChat.sendChatEvent("chat.events.voteDenied", {
                    voteEvent = "chat.events.voteEvents.derbyStart",
                    suffix = BJCScenarioData.Derby[M.Scenario.scenarioData.arenaIndex].name
                })
            end
        else
            BJCScenario.DerbyManager.start(M.Scenario.scenarioData.arenaIndex,
                M.Scenario.scenarioData.lives, M.Scenario.scenarioData.configs)
        end
    end
    M.Scenario.reset()
end

local function validateRaceSettings(race, settings)
    if race.loopable and (type(settings.laps) ~= "number" or settings.laps <= 0) then
        error({ key = "rx.errors.invalidData" })
    end

    local RS = BJCScenario.RaceManager.RESPAWN_STRATEGIES

    if not race.hasStand and settings.respawnStrategy == RS.STAND then
        error({ key = "rx.errors.invalidData" })
    elseif not settings.respawnStrategy or not table.includes(RS, settings.respawnStrategy) then
        error({ key = "rx.errors.invalidData" })
    end

    if settings.config and not settings.model then
        error({ key = "rx.errors.invalidData" })
    end
end

M.Scenario.start = function(scenarioType, creatorID, isVote, scenarioData)
    if M.Scenario.started() or mapStarted() or BJCScenario.isServerScenarioInProgress() then
        error({ key = "rx.errors.invalidData" })
    end
    scenarioData = scenarioData or {}
    M.Scenario.type = scenarioType
    if scenarioType == "race" then
        if BJCPerm.getCountPlayersCanSpawnVehicle() < BJCScenario.RaceManager.MINIMUM_PARTICIPANTS() then
            error({ key = "rx.errors.insufficientPlayers" })
        end
        local race = BJCScenarioData.getRace(scenarioData.raceID)
        if not race then
            error({ key = "rx.errors.invalidData" })
        end
        validateRaceSettings(race, scenarioData)
        if isVote then
            M.Scenario.endsAt = GetCurrentTime() + BJCConfig.Data.Race.VoteTimeout
            BJCChat.sendChatEvent("chat.events.vote", {
                playerName = BJCPlayers.Players[creatorID].playerName,
                voteEvent = "chat.events.voteEvents.raceStart",
                suffix = race.name
            })
        else
            M.Scenario.endsAt = GetCurrentTime() + BJCConfig.Data.Race.PreparationTimeout
            BJCChat.sendChatEvent("chat.events.gamemodeStarted", {
                gamemode = "chat.events.gamemodes.race",
            })
        end
        M.Scenario.scenarioData = {
            raceID = scenarioData.raceID,
            raceName = race.name,
            places = #race.startPositions,
            record = race.record,
            settings = {
                laps = scenarioData.laps,
                model = scenarioData.model,
                config = scenarioData.config,
                respawnStrategy = scenarioData.respawnStrategy,
                collisions = scenarioData.collisions == true,
            }
        }
        if race.loopable then
            M.Scenario.scenarioData.settings.laps = M.Scenario.scenarioData.settings.laps or 1
        end
        M.Scenario.voters = Table({ [creatorID] = true })
    elseif M.Scenario.type == "speed" then
        if BJCPerm.getCountPlayersCanSpawnVehicle() < BJCScenario.SpeedManager.MINIMUM_PARTICIPANTS() then
            error({ key = "rx.errors.insufficientPlayers" })
        end
        if isVote then
            M.Scenario.endsAt = GetCurrentTime() + BJCConfig.Data.Speed.VoteTimeout
            BJCChat.sendChatEvent("chat.events.vote", {
                playerName = BJCPlayers.Players[creatorID].playerName,
                voteEvent = "chat.events.voteEvents.speedStart",
                suffix = ""
            })
        else
            M.Scenario.endsAt = GetCurrentTime() + BJCConfig.Data.Speed.PreparationTimeout
            BJCChat.sendChatEvent("chat.events.gamemodeStarted", {
                gamemode = "chat.events.gamemodes.speed",
            })
        end
    elseif M.Scenario.type == "hunter" then
        if BJCPerm.getCountPlayersCanSpawnVehicle() < BJCScenario.HunterManager.MINIMUM_PARTICIPANTS() then
            error({ key = "rx.errors.insufficientPlayers" })
        elseif not BJCScenarioData.Hunter.enabled then
            error({ key = "rx.errors.invalidData" })
        end
        if isVote then
            M.Scenario.endsAt = GetCurrentTime() + BJCConfig.Data.Hunter.VoteTimeout
        else
            M.Scenario.endsAt = GetCurrentTime() + BJCConfig.Data.Hunter.PreparationTimeout
        end
        scenarioData.waypoints = scenarioData.waypoints or 1
        if scenarioData.lastWaypointGPS == nil then
            scenarioData.lastWaypointGPS = true
        end
        M.Scenario.scenarioData = {
            places = #BJCScenarioData.Hunter.hunterPositions + 1,
            waypoints = scenarioData.waypoints,
            lastWaypointGPS = scenarioData.lastWaypointGPS,
            huntedConfig = scenarioData.huntedConfig,
            hunterConfigs = scenarioData.hunterConfigs or {},
        }
        M.Scenario.voters = Table({ [creatorID] = true })
    elseif M.Scenario.type == "derby" then
        if BJCPerm.getCountPlayersCanSpawnVehicle() < BJCScenario.DerbyManager.MINIMUM_PARTICIPANTS() then
            error({ key = "rx.errors.insufficientPlayers" })
        end
        if isVote then
            M.Scenario.endsAt = GetCurrentTime() + BJCConfig.Data.Derby.VoteTimeout
        else
            M.Scenario.endsAt = GetCurrentTime() + BJCConfig.Data.Derby.PreparationTimeout
        end
        ---@type BJArena
        local arena = BJCScenarioData.Derby[scenarioData.arenaIndex]
        if not arena or not arena.enabled then error({ key = "rx.errors.invalidData" }) end
        scenarioData.arenaIndex = scenarioData.arenaIndex or 1
        scenarioData.lives = scenarioData.lives or 0
        M.Scenario.scenarioData = {
            arenaIndex = scenarioData.arenaIndex,
            arenaName = arena.name,
            places = #arena.startPositions,
            lives = scenarioData.lives,
            configs = scenarioData.configs,
        }
        M.Scenario.voters = Table({ [creatorID] = true })
    else
        -- invalid type
        M.Scenario.type = nil
    end

    -- COMMON
    if M.Scenario.type then
        M.Scenario.creatorID = creatorID
        M.Scenario.isVote = isVote
        BJCAsync.programTask(scenarioStartTimeout, M.Scenario.endsAt, "BJCVoteScenarioTimeout")
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    end
end

---@param playerID integer
---@param data any
M.Scenario.vote = function(playerID, data)
    if not M.Scenario.started() then
        return
    elseif M.Scenario.type == "speed" and not M.Scenario.isVote and
        not BJCPerm.canSpawnVehicle(playerID) then
        return
    end

    if M.Scenario.type == "speed" then
        if M.Scenario.voters[playerID] then
            M.Scenario.voters[playerID] = nil
            BJCChat.sendChatEvent("chat.events.gamemodeLeave", {
                playerName = BJCPlayers.Players[M.Scenario.creatorID].playerName,
                gamemode = "chat.events.gamemodes.speed",
            })
        else
            M.Scenario.voters[playerID] = data
            BJCChat.sendChatEvent("chat.events.gamemodeJoin", {
                playerName = BJCPlayers.Players[M.Scenario.creatorID].playerName,
                gamemode = "chat.events.gamemodes.speed",
            })
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    elseif M.Scenario.isVote then
        if M.Scenario.voters[playerID] then
            M.Scenario.voters[playerID] = nil
            if M.Scenario.voters:length() == 0 then
                -- no more voters
                local voteEvent, suffix
                if M.Scenario.type == "race" then
                    voteEvent = "raceStart"
                    suffix = M.Scenario.scenarioData.raceName
                elseif M.Scenario.type == "hunter" then
                    voteEvent = "hunterStart"
                elseif M.Scenario.type == "derby" then
                    voteEvent = "derbyStart"
                    suffix = M.Scenario.scenarioData.arenaName
                end
                BJCChat.sendChatEvent("chat.events.voteDenied", {
                    voteEvent = "chat.events.voteEvents." .. voteEvent,
                    suffix = suffix and (" " .. suffix) or "",
                })
                M.Scenario.reset()
            else
                -- check enough players connected
                local shouldStop = false
                if M.Scenario.type == "race" then
                    if BJCPerm.getCountPlayersCanSpawnVehicle() < BJCScenario.RaceManager.MINIMUM_PARTICIPANTS() then
                        shouldStop = true
                    end
                elseif M.Scenario.type == "hunter" then
                    if BJCPerm.getCountPlayersCanSpawnVehicle() < BJCScenario.HunterManager.MINIMUM_PARTICIPANTS() then
                        shouldStop = true
                    end
                elseif M.Scenario.type == "derby" then
                    if BJCPerm.getCountPlayersCanSpawnVehicle() < BJCScenario.DerbyManager.MINIMUM_PARTICIPANTS() then
                        shouldStop = true
                    end
                end
                if shouldStop then
                    BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                        gamemode = "chat.events.gamemodes." .. M.Scenario.type,
                        reason = "chat.events.gamemodeStopReasons.notEnoughParticipants"
                    })
                    M.Scenario.reset()
                end
            end
        else
            M.Scenario.voters[playerID] = data or true
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    else
        error({ key = "rx.errors.insufficientPermissions" })
    end
end

M.Scenario.stop = function(playerID)
    if M.Scenario.started() then
        local voteEvent, modeEvent, suffix
        if M.Scenario.type == "race" then
            voteEvent, modeEvent, suffix = "raceStart", "race", M.Scenario.scenarioData.raceName
        elseif M.Scenario.type == "speed" then
            voteEvent, modeEvent = "speedStart", "speed"
        elseif M.Scenario.type == "hunter" then
            voteEvent, modeEvent = "hunterStart", "hunter"
        elseif M.Scenario.type == "derby" then
            voteEvent, modeEvent, suffix = "derbyStart", "derby", M.Scenario.scenarioData.arenaName
        end

        if M.Scenario.isVote and voteEvent then
            BJCChat.sendChatEvent(M.Scenario.creatorID == playerID and
                "chat.events.voteCancelledByCreator" or "chat.events.voteCancelled", {
                    playerName = BJCPlayers.Players[M.Scenario.creatorID].playerName,
                    voteEvent = "chat.events.voteEvents." .. voteEvent,
                    suffix = suffix and (" " .. suffix) or ""
                })
        elseif not M.Scenario.isVote and modeEvent then
            BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                gamemode = "chat.events.gamemodes." .. modeEvent,
                reason = M.Scenario.creatorID == playerID and
                    "chat.events.gamemodeStopReasons.creator" or
                    "chat.events.gamemodeStopReasons.moderation",
            })
        end
        M.Scenario.reset()
    end
end

---@param player BJCPlayer
M.Scenario.onPlayerDisconnect = function(player)
    if not M.Scenario.started() then return end
    if M.Scenario.creatorID == player.playerID then
        M.Scenario.reset()
    elseif M.Scenario.voters[player.playerID] then
        M.Scenario.vote(player.playerID)
    end
end

-- COMMON
function M.getCache()
    local map = M.Map.targetMap and BJCMaps.Data[M.Map.targetMap] or {}
    return {
        Kick = {
            threshold = getKickThreshold(),
            creatorID = M.Kick.creatorID,
            targetID = M.Kick.targetID,
            endsAt = M.Kick.endsAt,
            voters = M.Kick.voters,
        },
        Map = {
            threshold = getMapThreshold(),
            creatorID = M.Map.creatorID,
            mapLabel = map.label,
            mapCustom = map.custom,
            endsAt = M.Map.endsAt,
            voters = M.Map.voters,
        },
        Scenario = {
            type = M.Scenario.type,
            threshold = M.Scenario.getThreshold(),
            creatorID = M.Scenario.creatorID,
            endsAt = M.Scenario.endsAt,
            isVote = M.Scenario.isVote,
            voters = M.Scenario.voters,
            scenarioData = M.Scenario.scenarioData or {},
        },
    }, M.getCacheHash()
end

function M.getCacheHash()
    return Hash({
        M.Kick, M.Map, M.Race
    })
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    Table({ {
        cond = kickStarted,
        fn = M.Kick.onPlayerDisconnect,
    }, {
        cond = mapStarted,
        fn = M.Map.onPlayerDisconnect,
    }, {
        cond = M.Scenario.started,
        fn = M.Scenario.onPlayerDisconnect,
    } })
        :filter(function(el) return el.cond() end)
        :forEach(function(el) el.fn(player) end)
end
BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_DISCONNECTED, onPlayerDisconnect, "VotesManager")

return M
