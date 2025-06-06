---@class BJIWindowSpeed : BJIWindow
local W = {
    name = "Speed",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 350,
    h = 250,

    labels = {
        title = "",
        speedUnit = "",
        minimumSpeed = "",
        counterWarning = "",
        leaderboard = "",
    },
    cache = {
        minSpeed = "",
        leaderboard = Table(),
    },
    ---@type BJIScenarioSpeed
    scenario = nil,
}

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("speed.title")
    W.labels.speedUnit = BJI.Managers.Lang.get("speed.speedUnit")
    W.labels.minimumSpeed = BJI.Managers.Lang.get("speed.minimumSpeed")
    W.labels.counterWarning = BJI.Managers.Lang.get("speed.counterWarning")
    W.labels.leaderboard = BJI.Managers.Lang.get("speed.leaderboard")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.cache.minSpeed = W.labels.minimumSpeed:var({
        speed = string.var("{1}{2}", { W.scenario.minSpeed, W.labels.speedUnit }) })

    W.cache.leaderboard = Range(1, Table(W.scenario.participants):length())
        :reduce(function(acc, i)
            local lb = W.scenario.leaderboard[i]
            if lb then
                acc[i] = {
                    player = BJI.Managers.Context.Players[lb.playerID],
                    self = lb.playerID == ctxt.user.playerID,
                    speed = lb.speed,
                    time = lb.time
                }
            end
            return acc
        end, Table())
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.SPEED)

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function drawHeader(ctxt)
    LineLabel(W.labels.title)

    LineLabel(W.cache.minSpeed)

    local now = GetCurrentTimeMillis()
    if W.scenario.processCheck and W.scenario.processCheck - ctxt.now >= 0 then
        local remaining = math.round((W.scenario.processCheck - now) / 1000)
        LineLabel(W.labels.counterWarning:var({ seconds = remaining }), remaining > 3 and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.ERROR)
    end
end

local function drawBody(ctxt)
    LineLabel(W.labels.leaderboard)
    Indent(1)
    Range(1, table.length(W.scenario.participants)):forEach(function(i)
        local lb = W.cache.leaderboard[i]
        local color = (lb and lb.self) and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        local line = LineBuilder()
            :text(i, color)
            :text("-", color)
        if lb then
            line:text(lb.player.playerName, color)
                :text(string.var("({1}{2}, {3})", { lb.speed, W.labels.speedUnit, BJI.Utils.UI.RaceDelay(lb.time) }),
                    color)
        end
        line:build()
    end)
    Indent(-1)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = drawHeader
W.body = drawBody
W.getState = function()
    return BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.SPEED)
end

return W
