---@class BJIWindowDatabase : BJIWindow
local W = {
    name = "Database",
    w = 400,
    h = 250,

    TABS = Table({
        {
            permission = BJI.Managers.Perm.PERMISSIONS.DATABASE_PLAYERS,
            labelKey = "players",
            subWindow = require("ge/extensions/BJI/ui/windows/Database/Players"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.DATABASE_VEHICLES,
            labelKey = "vehicles",
            subWindow = require("ge/extensions/BJI/ui/windows/Database/Vehicles"),
        },
    }),

    show = false,
    ---@type {permission: string, labelKey: string, subWindow: table}?
    tab = nil,
    labels = {
        players = "",
        vehicles = "",
    },
    cache = {},
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.players = BJI.Managers.Lang.get("database.players.title")
    W.labels.vehicles = BJI.Managers.Lang.get("database.vehicles.title")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name))

    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not W.TABS:any(function(t)
                return not t.permission or BJI.Managers.Perm.hasPermission(t.permission)
            end) then
            onClose()
        end
    end, W.name))

    if not W.tab or (W.tab.permission and not BJI.Managers.Perm.hasPermission(W.tab.permission)) then
        W.tab = W.TABS:find(function(t)
            return not t.permission or BJI.Managers.Perm.hasPermission(t.permission)
        end)
        if W.tab then
            W.tab.subWindow.onLoad()
        else
            onClose()
        end
    end
end

local function onUnload()
    if W.tab then
        W.tab.subWindow.onUnload()
    end
    W.tab = nil
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function updateTab(newTab)
    if newTab ~= W.tab and newTab then
        if W.tab then
            W.tab.subWindow.onUnload()
        end
        W.tab = newTab
        if W.tab then
            W.tab.subWindow.onLoad()
        end
    end
end

local function header(ctxt)
    W.TABS:filter(function(t)
        return BJI.Managers.Perm.hasPermission(t.permission)
    end):reduce(function(tabbar, t)
        return tabbar:addTab(W.labels[t.labelKey], function()
            updateTab(t)
        end)
    end, TabBarBuilder("BJIDatabaseTabs")):build()
    if W.tab and W.tab.subWindow.body then
        W.tab.subWindow.header(ctxt)
    end
end

local function body(ctxt)
    if W.tab and W.tab.subWindow.body then
        W.tab.subWindow.body(ctxt)
    end
end

local function footer(ctxt)
    LineBuilder()
        :btnIcon({
            id = "databaseEditorClose",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.getState = function() return W.show end

return W
