---@class BJIManagerVotes : BJIManager
local M = {
    _name = "Votes",
    
    SCENARIO_TYPES = {
        RACE = "race",
        SPEED = "speed",
        HUNTER = "hunter",
        INFECTED = "infected",
        DERBY = "derby",
    }
}

M.Kick = {
    threshold = 0,
    creatorID = nil,
    targetID = nil,
    endsAt = nil,
    amountVotes = 0,
    selfVoted = false,
}

function M.Kick.onLoad()
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.VOTE, function(cacheData)
        if cacheData.Kick then
            M.Kick.threshold = cacheData.Kick.threshold
            M.Kick.creatorID = cacheData.Kick.creatorID
            M.Kick.targetID = cacheData.Kick.targetID
            M.Kick.endsAt = BJI_Tick.applyTimeOffset(cacheData.Kick.endsAt)
            M.Kick.amountVotes = table.length(cacheData.Kick.voters)
            M.Kick.selfVoted = table.includes(cacheData.Kick.voters, BJI_Context.User.playerID)
            BJI_Events.trigger(BJI_Events.EVENTS.VOTE_UPDATED)
        end
    end)
end

function M.Kick.started()
    return M.Kick.targetID ~= nil
end

function M.Kick.getTotalPlayers()
    return BJI_Context.Players
        :filter(function(_, pid) return not BJI_Perm.isStaff(pid) end)
        :length()
end

function M.Kick.canStartVote(targetID)
    return not M.Kick.started() and
        not BJI_Perm.isStaff() and
        not BJI_Context.isSelf(targetID) and
        not BJI_Perm.isStaff(targetID) and
        M.Kick.getTotalPlayers() > 2 and
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_KICK)
end

function M.Kick.start(targetID)
    if M.Kick.canStartVote(targetID) then
        BJI_Tx_vote.KickStart(targetID)
    end
end

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
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.VOTE, function(cacheData)
        if cacheData.Map then
            M.Map.threshold = cacheData.Map.threshold
            M.Map.creatorID = cacheData.Map.creatorID
            M.Map.mapLabel = cacheData.Map.mapLabel
            M.Map.mapCustom = cacheData.Map.mapCustom == true
            M.Map.endsAt = BJI_Tick.applyTimeOffset(cacheData.Map.endsAt)
            M.Map.amountVotes = table.length(cacheData.Map.voters)
            M.Map.selfVoted = table.includes(cacheData.Map.voters, BJI_Context.User.playerID)
            BJI_Events.trigger(BJI_Events.EVENTS.VOTE_UPDATED)
        end
    end)
end

function M.Map.started()
    return M.Map.mapLabel ~= nil
end

function M.Map.getTotalPlayers()
    return BJI_Context.Players:filter(function(_, pid)
        return BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_MAP, pid)
    end):length()
end

function M.Map.canStartVote()
    return not M.Map.started() and
        BJI_Context.Maps and
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_MAP) and
        BJI_Scenario.isFreeroam() and
        not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SWITCH_MAP)
end

function M.Map.start(mapName)
    if not M.Map.started() then
        BJI_Tx_vote.MapStart(mapName)
    end
end

M.Scenario = {
    type = nil,
    creatorID = nil,
    isVote = false,
    threshold = 0,
    endsAt = nil,
    scenarioData = {},
    voters = {},
    amountVotes = 0,
    selfVoted = false,
}

function M.Scenario.onLoad()
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.VOTE, function(cacheData)
        if cacheData.Scenario then
            M.Scenario.type = cacheData.Scenario.type
            M.Scenario.creatorID = cacheData.Scenario.creatorID
            M.Scenario.isVote = cacheData.Scenario.isVote
            M.Scenario.threshold = cacheData.Scenario.threshold
            M.Scenario.endsAt = BJI_Tick.applyTimeOffset(cacheData.Scenario.endsAt)
            M.Scenario.scenarioData = cacheData.Scenario.scenarioData
            M.Scenario.voters = cacheData.Scenario.voters
            M.Scenario.amountVotes = table.length(cacheData.Scenario.voters or {})
            M.Scenario.selfVoted = cacheData.Scenario.voters and
                cacheData.Scenario.voters[BJI_Context.User.playerID] or false
            BJI_Events.trigger(BJI_Events.EVENTS.VOTE_UPDATED)
        end
    end)
end

function M.Scenario.started()
    return M.Scenario.creatorID ~= nil
end

function M.Scenario.canStartVote()
    return not M.Scenario.started() and not M.Map.started() and
        BJI_Scenario.isFreeroam() and
        (BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO))
end

---@param ctxt TickContext
local function slowTick(ctxt)
    if M.Scenario.started() and M.Scenario.type == M.SCENARIO_TYPES.SPEED then
        -- autojoin on event
        if not M.Scenario.isVote and
            not M.Scenario.voters[BJI_Context.User.playerID] and
            ctxt.isOwner then
            if BJI_Tournament.state and BJI_Tournament.whitelist and
                not BJI_Tournament.whitelistPlayers:includes(BJI_Context.User.playerName) then
                BJI_Veh.deleteAllOwnVehicles()
            else
                BJI_Tx_vote.ScenarioVote(ctxt.veh.gameVehicleID)
            end
        end

        -- auto leave or update vehicle
        if M.Scenario.voters[BJI_Context.User.playerID] then
            if not ctxt.isOwner then
                BJI_Tx_vote.ScenarioVote()
            elseif ctxt.veh.gameVehicleID ~= M.Scenario.voters[BJI_Context.User.playerID] then
                BJI_Tx_vote.ScenarioVote(ctxt.veh.gameVehicleID)
            end
        end
    end
end

M.onLoad = function()
    table.forEach({ M.Kick, M.Map, M.Scenario }, function(el)
        if el.onLoad then
            el.onLoad()
        end
    end)

    BJI_Events.addListener(BJI_Events.EVENTS.SLOW_TICK, slowTick, M._name)
end

return M
