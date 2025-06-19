---@class BJIManagerVotes : BJIManager
local M = {
    _name = "Votes",
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
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.VOTE, function(cacheData)
        if cacheData.Kick then
            M.Kick.threshold = cacheData.Kick.threshold
            M.Kick.creatorID = cacheData.Kick.creatorID
            M.Kick.targetID = cacheData.Kick.targetID
            M.Kick.endsAt = BJI.Managers.Tick.applyTimeOffset(cacheData.Kick.endsAt)
            M.Kick.amountVotes = cacheData.Kick.voters and table.length(cacheData.Kick.voters) or 0
            M.Kick.selfVoted = cacheData.Kick.voters and
                table.includes(cacheData.Kick.voters, BJI.Managers.Context.User.playerID) or false
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VOTE_UPDATED)
        end
    end)
end

function M.Kick.started()
    return M.Kick.targetID ~= nil
end

function M.Kick.getTotalPlayers()
    return BJI.Managers.Context.Players
        :filter(function(_, pid) return not BJI.Managers.Perm.isStaff(pid) end)
        :length()
end

function M.Kick.canStartVote(targetID)
    return not M.Kick.started() and
        not BJI.Managers.Perm.isStaff() and
        not BJI.Managers.Context.isSelf(targetID) and
        not BJI.Managers.Perm.isStaff(targetID) and
        M.Kick.getTotalPlayers() > 2 and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_KICK)
end

function M.Kick.start(targetID)
    if M.Kick.canStartVote(targetID) then
        BJI.Tx.votekick.start(targetID)
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
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.VOTE, function(cacheData)
        if cacheData.Map then
            M.Map.threshold = cacheData.Map.threshold
            M.Map.creatorID = cacheData.Map.creatorID
            M.Map.mapLabel = cacheData.Map.mapLabel
            M.Map.mapCustom = cacheData.Map.mapCustom == true
            M.Map.endsAt = BJI.Managers.Tick.applyTimeOffset(cacheData.Map.endsAt)
            M.Map.amountVotes = cacheData.Map.voters and table.length(cacheData.Map.voters) or 0
            M.Map.selfVoted = cacheData.Map.voters and
                table.includes(cacheData.Map.voters, BJI.Managers.Context.User.playerID) or false
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VOTE_UPDATED)
        end
    end)
end

function M.Map.started()
    return M.Map.mapLabel ~= nil
end

function M.Map.getTotalPlayers()
    return BJI.Managers.Context.Players:filter(function(_, pid)
        return BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_MAP, pid)
    end):length()
end

function M.Map.canStartVote()
    return not M.Map.started() and
        BJI.Managers.Context.Maps and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_MAP) and
        BJI.Managers.Scenario.isFreeroam() and
        not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SWITCH_MAP)
end

function M.Map.start(mapName)
    if not M.Map.started() then
        BJI.Tx.votemap.start(mapName)
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
    collisions = true,
    amountVotes = 0,
    selfVoted = false,
}

function M.Race.onLoad()
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.VOTE, function(cacheData)
        if cacheData.Race then
            M.Race.threshold = cacheData.Race.threshold
            M.Race.creatorID = cacheData.Race.creatorID
            M.Race.endsAt = BJI.Managers.Tick.applyTimeOffset(cacheData.Race.endsAt)
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
            M.Race.collisions = cacheData.Race.collisions == true
            M.Race.amountVotes = cacheData.Race.voters and table.length(cacheData.Race.voters) or 0
            M.Race.selfVoted = cacheData.Race.voters and
                table.includes(cacheData.Race.voters, BJI.Managers.Context.User.playerID) or false
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VOTE_UPDATED)
        end
    end)
end

function M.Race.started()
    return M.Race.creatorID ~= nil
end

function M.Race.canStartVote()
    return not M.Race.started() and
        BJI.Managers.Scenario.isFreeroam() and
        (
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO)
        )
end

function M.Race.start(raceID, isVote, settings)
    if not M.Race.started() then
        BJI.Tx.voterace.start(raceID, isVote, settings)
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
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.VOTE, function(cacheData)
        if cacheData.Speed then
            M.Speed.creatorID = cacheData.Speed.creatorID
            M.Speed.isEvent = not cacheData.Speed.isVote
            M.Speed.endsAt = BJI.Managers.Tick.applyTimeOffset(cacheData.Speed.endsAt)
            M.Speed.participants = cacheData.Speed.participants
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VOTE_UPDATED)
        end
    end)
end

function M.Speed.started()
    return M.Speed.endsAt ~= nil
end

function M.Speed.canStartVote()
    return not M.Speed.started() and
        BJI.Managers.Scenario.isFreeroam() and
        (
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO)
        )
end

---@param ctxt TickContext
local function slowTick(ctxt)
    if M.Speed.started() then
        -- autojoin on event
        if M.Speed.isEvent and
            not M.Speed.participants[BJI.Managers.Context.User.playerID] and
            ctxt.isOwner then
            if BJI.Managers.Tournament.state and BJI.Managers.Tournament.whitelist and not BJI.Managers.Tournament.whitelistPlayers:includes(BJI.Managers.Context.User.playerName) then
                BJI.Managers.Veh.deleteAllOwnVehicles()
            else
                BJI.Tx.scenario.SpeedJoin(ctxt.veh.gameVehicleID)
            end
        end

        -- auto leave or update vehicle
        if M.Speed.participants[BJI.Managers.Context.User.playerID] then
            if not ctxt.isOwner then
                BJI.Tx.scenario.SpeedJoin()
            elseif ctxt.veh.gameVehicleID ~= M.Speed.participants[BJI.Managers.Context.User.playerID] then
                BJI.Tx.scenario.SpeedJoin(ctxt.veh.gameVehicleID)
            end
        end
    end
end

M.onLoad = function()
    table.forEach({ M.Kick, M.Map, M.Race, M.Speed }, function(el)
        if el.onLoad then
            el.onLoad()
        end
    end)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
end

return M
