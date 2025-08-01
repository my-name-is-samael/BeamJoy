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
    W.labels.title = BJI_Lang.get("speed.title")
    W.labels.speedUnit = BJI_Lang.get("speed.speedUnit")
    W.labels.minimumSpeed = BJI_Lang.get("speed.minimumSpeed")
    W.labels.counterWarning = BJI_Lang.get("speed.counterWarning")
    W.labels.leaderboard = BJI_Lang.get("speed.leaderboard")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    W.cache.minSpeed = W.labels.minimumSpeed:var({
        speed = string.var("{1}{2}", { W.scenario.minSpeed, W.labels.speedUnit }) })

    W.cache.leaderboard = Range(1, Table(W.scenario.participants):length())
        :reduce(function(acc, i)
            lb = W.scenario.leaderboard[i]
            if lb then
                acc[i] = {
                    player = BJI_Context.Players[lb.playerID],
                    self = lb.playerID == ctxt.user.playerID,
                    speed = lb.speed,
                    timeLabel = lb.time and BJI.Utils.UI.RaceDelay(lb.time) or nil,
                }
            end
            return acc
        end, Table())
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI_Scenario.get(BJI_Scenario.TYPES.SPEED)

    updateLabels()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.SCENARIO_UPDATED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
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
                Text(lb.player.playerName, { color = color })
                if lb.timeLabel then
                    SameLine()
                    Text(string.format("(%d%s, %s)",
                        lb.speed, W.labels.speedUnit, lb.timeLabel
                    ), { color = color })
                end
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
    return BJI_Scenario.is(BJI_Scenario.TYPES.SPEED)
end

return W
