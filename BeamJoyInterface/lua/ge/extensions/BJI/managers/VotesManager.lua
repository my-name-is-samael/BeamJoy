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
    -- Rule in https://github.com/my-name-is-samael/BeamJoy/issues/14
    return not M.Map.started() and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_MAP) and
        (
            M.Map.getTotalPlayers() > 1 or
            not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SWITCH_MAP)
        )
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

function M.Race.started()
    return M.Race.creatorID ~= nil
end

function M.Race.canStartVote()
    return not BJIScenario.isServerScenarioInProgress() and
        not M.Race.started() and
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

function M.Speed.started()
    return M.Speed.endsAt ~= nil
end

local function getSpeedTotalPlayers()
    local total = 0
    for playerID in pairs(BJIContext.Players) do
        if BJIPerm.canSpawnVehicle(playerID) then
            total = total + 1
        end
    end
    return total
end

function M.Speed.canStartVote()
    return not M.Speed.started() and
        BJIScenario.isFreeroam() and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) and
        getSpeedTotalPlayers() > 1
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

M.slowTick = slowTick

RegisterBJIManager(M)
return M
