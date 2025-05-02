local M = {
    _name = "BJIVotes",
}

-- KICK
M.Kick = {
    threshold = 0,
    creatorID = nil,
    targetID = nil,
    endsAt = nil,
    amountVotes = 0,
    selfVoted = false,
}

function M.Kick.onLoad()
    BJICache.addRxHandler(BJICache.CACHES.VOTE, function(cacheData)
        if cacheData.Kick then
            M.Kick.threshold = cacheData.Kick.threshold
            M.Kick.creatorID = cacheData.Kick.creatorID
            M.Kick.targetID = cacheData.Kick.targetID
            M.Kick.endsAt = BJITick.applyTimeOffset(cacheData.Kick.endsAt)
            M.Kick.amountVotes = cacheData.Kick.voters and table.length(cacheData.Kick.voters) or 0
            M.Kick.selfVoted = cacheData.Kick.voters and
                table.includes(cacheData.Kick.voters, BJIContext.User.playerID) or false
        end
    end)
end

function M.Kick.started()
    return M.Kick.targetID ~= nil
end

function M.Kick.getTotalPlayers()
    local totalPlayers = 0
    for playerID in pairs(BJIContext.Players) do
        if not BJIPerm.isStaff(playerID) then
            -- not counting staff in the total
            totalPlayers = totalPlayers + 1
        end
    end
    return totalPlayers
end

function M.Kick.canStartVote(targetID)
    return not M.Kick.started() and
        not BJIPerm.isStaff() and
        not BJIContext.isSelf(targetID) and
        not BJIPerm.isStaff(targetID) and
        M.Kick.getTotalPlayers() > 2 and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_KICK)
end

function M.Kick.start(targetID)
    if M.Kick.canStartVote(targetID) then
        BJITx.votekick.start(targetID)
    end
end

-- MAP
M.Map = {
    threshold = 0,
    creatorID = nil,
    mapLabel = nil,
    mapCustom = false,
    endsAt = nil,
    amountVotes = 0,
    selfVoted = false,
}

function M.Map.onLoad()
    BJICache.addRxHandler(BJICache.CACHES.VOTE, function(cacheData)
        if cacheData.Map then
            M.Map.threshold = cacheData.Map.threshold
            M.Map.creatorID = cacheData.Map.creatorID
            M.Map.mapLabel = cacheData.Map.mapLabel
            M.Map.mapCustom = cacheData.Map.mapCustom == true
            M.Map.endsAt = BJITick.applyTimeOffset(cacheData.Map.endsAt)
            M.Map.amountVotes = cacheData.Map.voters and table.length(cacheData.Map.voters) or 0
            M.Map.selfVoted = cacheData.Map.voters and
                table.includes(cacheData.Map.voters, BJIContext.User.playerID) or false
        end
    end)
end

function M.Map.started()
    return M.Map.mapLabel ~= nil
end

function M.Map.getTotalPlayers()
    local count = 0
    for playerID in pairs(BJIContext.Players) do
        if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_MAP, playerID) then
            count = count + 1
        end
    end
    return count
end

function M.Map.canStartVote()
    return not M.Map.started() and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_MAP) and
        BJIScenario.isFreeroam() and
        not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SWITCH_MAP)
end

function M.Map.start(mapName)
    if not M.Map.started() then
        BJITx.votemap.start(mapName)
    end
end

-- RACE (VOTE OR PREPARATION)
M.Race = {
    threshold = 0,
    creatorID = nil,
    endsAt = nil,
    isVote = false,
    raceName = nil,
    places = 0,
    record = nil,
    timeLabel = nil,
    weatherLabel = nil,
    laps = nil,
    model = nil,
    specificConfig = false,
    respawnStrategy = nil,
    amountVotes = 0,
    selfVoted = false,
}

function M.Race.onLoad()
    BJICache.addRxHandler(BJICache.CACHES.VOTE, function(cacheData)
        if cacheData.Race then
            M.Race.threshold = cacheData.Race.threshold
            M.Race.creatorID = cacheData.Race.creatorID
            M.Race.endsAt = BJITick.applyTimeOffset(cacheData.Race.endsAt)
            M.Race.isVote = cacheData.Race.isVote
            M.Race.raceName = cacheData.Race.raceName
            M.Race.places = cacheData.Race.places
            M.Race.record = cacheData.Race.record
            M.Race.timeLabel = cacheData.Race.timeLabel
            M.Race.weatherLabel = cacheData.Race.weatherLabel
            M.Race.laps = cacheData.Race.laps
            M.Race.model = cacheData.Race.model
            M.Race.specificConfig = cacheData.Race.specificConfig == true
            M.Race.respawnStrategy = cacheData.Race.respawnStrategy
            M.Race.amountVotes = cacheData.Race.voters and table.length(cacheData.Race.voters) or 0
            M.Race.selfVoted = cacheData.Race.voters and
                table.includes(cacheData.Race.voters, BJIContext.User.playerID) or false
        end
    end)
end

function M.Race.started()
    return M.Race.creatorID ~= nil
end

function M.Race.canStartVote()
    return not M.Race.started() and
        BJIScenario.isFreeroam() and
        (
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO)
        )
end

function M.Race.start(raceID, isVote, settings)
    if not M.Race.started() then
        BJITx.voterace.start(raceID, isVote, settings)
    end
end

-- SPEED
M.Speed = {
    creatorID = nil,
    isEvent = false,
    endsAt = nil,
    participants = {},
}

function M.Speed.onLoad()
    BJICache.addRxHandler(BJICache.CACHES.VOTE, function(cacheData)
        if cacheData.Speed then
            M.Speed.creatorID = cacheData.Speed.creatorID
            M.Speed.isEvent = not cacheData.Speed.isVote
            M.Speed.endsAt = cacheData.Speed.endsAt
            M.Speed.participants = cacheData.Speed.participants
        end
    end)
end

function M.Speed.started()
    return M.Speed.endsAt ~= nil
end

function M.Speed.canStartVote()
    return not M.Speed.started() and
        BJIScenario.isFreeroam() and
        (
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO)
        )
end

local function onLoad()
    table.forEach({ M.Kick, M.Map, M.Race, M.Speed }, function(el)
        if el.onLoad then
            el.onLoad()
        end
    end)
end

local function slowTick(ctxt)
    if M.Speed.started() then
        if M.Speed.isEvent and
            not M.Speed.participants[BJIContext.User.playerID] and
            ctxt.isOwner then
            -- autojoin on event
            BJITx.scenario.SpeedJoin(ctxt.veh:getID())
        end

        -- auto leave or update vehicle
        if M.Speed.participants[BJIContext.User.playerID] then
            if not ctxt.isOwner then
                BJITx.scenario.SpeedJoin()
            elseif ctxt.veh:getID() ~= M.Speed.participants[BJIContext.User.playerID] then
                BJITx.scenario.SpeedJoin(ctxt.veh:getID())
            end
        end
    end
end

M.onLoad = onLoad
M.slowTick = slowTick

RegisterBJIManager(M)
return M
