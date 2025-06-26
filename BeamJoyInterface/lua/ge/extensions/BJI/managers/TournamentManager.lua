---@class BJIManagerTournament : BJIManager
local M = {
    _name = "Tournament",

    ACTIVITIES_TYPES = {
        RACE_SOLO = "raceSolo",
        RACE = "race",
        SPEED = "speed",
        HUNTER = "hunter",
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
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.TOURNAMENT, function(cacheData)
        local wasEnabled = M.state
        local wasRaceSolo = M.state and isSoloRaceInProgress()

        M.state = cacheData.state
        M.activities = Table(cacheData.activities)
        M.players = Table(cacheData.players)
        M.activities:forEach(function(activity)
            if activity.targetTime then
                activity.targetTime = BJI.Managers.Tick.applyTimeOffset(activity.targetTime)
            end
        end)
        M.whitelist = cacheData.whitelist == true
        M.whitelistPlayers = Table(cacheData.whitelistPlayers)

        if not wasEnabled and M.state then
            -- on activation
            if not BJI.Managers.Scenario.isFreeroam() then
                -- force stop scenario
                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
            end
        end
        if wasRaceSolo and BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_SOLO) then
            if not M.state or not isSoloRaceInProgress() then
                -- force stop race event
                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
            elseif M.whitelist and not M.whitelistPlayers:includes(BJI.Managers.Context.User.playerName) then
                -- got out of whitelist
                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
            end
        end

        BJI.Windows.Tournament.updateData()
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED)
    end)
end

---@return boolean
local function canJoinActivity()
    return not M.state or not M.whitelist or
        M.whitelistPlayers:includes(BJI.Managers.Context.User.playerName)
end

M.onLoad = onLoad

M.canJoinActivity = canJoinActivity

return M
