---@class BJIWindowSpeed : BJIWindow
local W = {
    name = "Speed",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
        BJI.Utils.Style.WINDOW_FLAGS.ALWAYS_AUTO_RESIZE,
    },

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
--- gc prevention
local remaining, lb, color

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
    Text(W.labels.title)
    Text(W.cache.minSpeed)

    if W.scenario.processCheck and W.scenario.processCheck - ctxt.now >= 0 then
        remaining = math.round((W.scenario.processCheck - ctxt.now) / 1000)
        Text(W.labels.counterWarning:var({ seconds = remaining }), {
            color = remaining > 3 and
                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.ERROR
        })
    end
end

local function drawBody(ctxt)
    Text(W.labels.leaderboard)
    Indent()
    if BeginTable("BJISpeedGameLeaderboard", {
            { label = "##speedgame-positions" },
            { label = "##speedgame-scores" },
        }) then
        Range(1, table.length(W.scenario.participants)):forEach(function(i)
            lb = W.cache.leaderboard[i]
            color = (lb and lb.self) and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
            TableNewRow()
            Text(i, { color = color })
            TableNextColumn()
            Text("-", { color = color })
            if lb then
                SameLine()
                Text(string.var("{1} ({2}{3}, {4})", {
                    lb.player.playerName, lb.speed, W.labels.speedUnit,
                    BJI.Utils.UI.RaceDelay(lb.time) }), { color = color })
            end
        end)

        EndTable()
    end
    Unindent()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = drawHeader
W.body = drawBody
W.getState = function()
    return BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.SPEED)
end

return W
