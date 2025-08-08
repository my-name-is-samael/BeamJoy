---@class BJIManagerTournament : BJIManager
local M = {
    _name = "Tournament",

    ACTIVITIES_TYPES = {
        RACE_SOLO = "raceSolo",
        RACE = "race",
        SPEED = "speed",
        HUNTER = "hunter",
        INFECTED = "infected",
        DERBY = "derby",
        TAG = "tag",
    },

    state = false,
    activities = Table(),
    players = Table(),
    whitelist = false,
    whitelistPlayers = Table(),
}

local function isSoloRaceInProgress()
    return M.activities[#M.activities] and
        M.activities[#M.activities].type == M.ACTIVITIES_TYPES.RACE_SOLO and
        M.activities[#M.activities].targetTime
end

local function onLoad()
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.TOURNAMENT, function(cacheData)
        local wasEnabled = M.state
        local wasRaceSolo = M.state and isSoloRaceInProgress()

        M.state = cacheData.state
        M.activities = Table(cacheData.activities)
        M.players = Table(cacheData.players)
        M.activities:forEach(function(activity)
            if activity.targetTime then
                activity.targetTime = BJI_Tick.applyTimeOffset(activity.targetTime)
            end
        end)
        M.whitelist = cacheData.whitelist == true
        M.whitelistPlayers = Table(cacheData.whitelistPlayers)

        if not wasEnabled and M.state then
            -- on activation
            if not BJI_Scenario.isFreeroam() then
                -- force stop scenario
                BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
            end
        end
        if wasRaceSolo and BJI_Scenario.is(BJI_Scenario.TYPES.RACE_SOLO) then
            if not M.state or not isSoloRaceInProgress() then
                -- force stop race event
                BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
            elseif M.whitelist and not M.whitelistPlayers:includes(BJI_Context.User.playerName) then
                -- got out of whitelist
                BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
            end
        end

        BJI_Win_Tournament.updateData()
        BJI_Events.trigger(BJI_Events.EVENTS.TOURNAMENT_UPDATED)
    end)
end

---@return boolean
local function canJoinActivity()
    return not M.state or not M.whitelist or
        M.whitelistPlayers:includes(BJI_Context.User.playerName)
end

M.onLoad = onLoad

M.canJoinActivity = canJoinActivity

return M
