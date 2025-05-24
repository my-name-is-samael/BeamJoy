---@class BJIWindowScenarioEditor : BJIWindow
local W = {
    name = "ScenarioEditor",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    w = 450,
    h = 850,

    SCENARIOS = {
        STATIONS = require("ge/extensions/BJI/ui/windows/ScenarioEditor/Stations"),
        GARAGES = require("ge/extensions/BJI/ui/windows/ScenarioEditor/Garages"),
        DELIVERIES = require("ge/extensions/BJI/ui/windows/ScenarioEditor/Deliveries"),
        BUS_LINES = require("ge/extensions/BJI/ui/windows/ScenarioEditor/BusLines"),
        RACE = require("ge/extensions/BJI/ui/windows/ScenarioEditor/Race"),
        HUNTER = require("ge/extensions/BJI/ui/windows/ScenarioEditor/Hunter"),
        DERBY = require("ge/extensions/BJI/ui/windows/ScenarioEditor/Derby"),
    },

    ---@type BJIWindow
    view = nil,
}

W.onClose = function()
    if W.view and W.view.onClose then W.view.onClose() end
    if W.view and W.view.onUnload then W.view.onUnload() end
    W.view = nil
end
local listeners = Table()
W.onLoad = function()
    if W.view.onLoad then W.view.onLoad() end

    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not BJI.Managers.Scenario.isFreeroam() or
            not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO) then
            W.onClose()
        end
    end, W.name))
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_EDITOR_UPDATED)
end
W.onUnload = function()
    if W.view and W.view.onUnload then W.view.onUnload() end
    listeners:forEach(BJI.Managers.Events.removeListener)
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_EDITOR_UPDATED)
end
W.header = function(ctxt) if W.view.header then W.view.header(ctxt) end end
W.body = function(ctxt) W.view.body(ctxt) end
W.footer = function(ctxt) if W.view.footer then W.view.footer(ctxt) end end

W.footerLines = function(ctxt)
    return (W.view and type(W.view.footerLines) == "function") and W.view.footerLines(ctxt) or 1
end
W.getState = function() return W.view ~= nil and BJI.Managers.Scenario.isFreeroam() end

return W
