---@class BJIWindowDeliveryMulti : BJIWindow
local W = {
    name = "DeliveryMulti",
    w = 350,
    h = 220,

    labels = {
        streak = "",
        resetted = "",
        distance = "",
        arrived = "",
        onTheWay = "",
        leave = "",
    },
    cache = {
        streakLabel = "",
        streakColor = nil,
        wpReached = false,
        playerNamesWidth = 0,
        playersList = Table(),
        disableButtons = false,
    },
    ---@type BJIScenarioDeliveryMulti
    scenario = nil,
}

local function updateLabels()
    W.labels.streak = BJI.Managers.Lang.get("deliveryTogether.streak")
    W.labels.resetted = BJI.Managers.Lang.get("deliveryTogether.resetted")
    W.labels.distance = string.var("{1} :", { BJI.Managers.Lang.get("deliveryTogether.distance") })
    W.labels.arrived = BJI.Managers.Lang.get("deliveryTogether.arrived")
    W.labels.onTheWay = BJI.Managers.Lang.get("deliveryTogether.onTheWay")
    W.labels.leave = BJI.Managers.Lang.get("common.buttons.leave")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.cache.disableButtons = false

    local self = W.scenario.participants[ctxt.user.playerID]
    if self then
        if self.nextTargetReward then
            W.cache.streakLabel = Table({ W.labels.streak, self.streak }):join(" : ")
            W.cache.streakColor = BJI.Utils.Style.TEXT_COLORS.DEFAULT
        else
            W.cache.streakLabel = W.labels.resetted
            W.cache.streakColor = BJI.Utils.Style.TEXT_COLORS.ERROR
        end
        W.cache.wpReached = self.reached
    end

    W.cache.playersList = Table(W.scenario.participants):map(function(p, playerID)
        local nameColor = BJI.Utils.Style.TEXT_COLORS.DEFAULT
        if playerID == ctxt.user.playerID then
            nameColor = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
        end
        return {
            playerName = BJI.Managers.Context.Players[playerID].playerName,
            nameColor = nameColor,
            statusLabel = p.reached and W.labels.arrived or W.labels.onTheWay,
            streakLabel = p.nextTargetReward and
                string.var("({1} : {2})", { W.labels.streak, p.streak }) or
                string.var("({1})", { W.labels.resetted }),
            streakColor = p.nextTargetReward and nameColor or
                BJI.Utils.Style.TEXT_COLORS.ERROR,
        }
    end)
    W.cache.playerNamesWidth = W.cache.playersList:reduce(function(acc, p)
        local w = BJI.Utils.UI.GetColumnTextWidth(p.playerName)
        return w > acc and w or acc
    end, 0)
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DELIVERY_MULTI)

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function header(ctxt)
    LineLabel(W.cache.streakLabel, W.cache.streakColor)
    if not W.cache.wpReached and W.scenario.distance then
        -- distance
        LineBuilder()
            :text(W.labels.distance)
            :text(BJI.Utils.UI.PrettyDistance(W.scenario.distance))
            :build()
        if W.scenario.baseDistance then
            ProgressBar({
                floatPercent = 1 - math.max(W.scenario.distance / W.scenario.baseDistance, 0),
                width = 250,
                style = BJI.Utils.Style.BTN_PRESETS.INFO[1],
            })
        end
    end
end

local function body(ctxt)
    Indent(1)
    W.cache.playersList:reduce(function(cols, p)
        return cols:addRow({
            cells = {
                function()
                    LineLabel(p.playerName, p.nameColor)
                end,
                function()
                    LineBuilder()
                        :text(p.statusLabel, p.nameColor)
                        :text(p.streakLabel, p.streakColor)
                        :build()
                end,
            }
        })
    end, ColumnsBuilder("BJIDeliveryMultiParticipants",
        { W.cache.playerNamesWidth, -1 }))
        :build()
    Indent(-1)
end

local function footer(ctxt)
    LineBuilder()
        :btnIcon({
            id = "deliveryMultiLeave",
            icon = BJI.Utils.Icon.ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = W.cache.disableButtons,
            tooltip = W.labels.leave,
            onClick = function()
                W.cache.disableButtons = true
                BJI.Tx.scenario.DeliveryMultiLeave()
            end,
        })
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.getState = function()
    return BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.DELIVERY_MULTI)
end

return W
