---@class BJIWindowDatabase : BJIWindow
local W = {
    name = "Database",
    minSize = ImVec2(400, 250),

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
        close = "",
    },
    cache = {},
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.players = BJI.Managers.Lang.get("database.players.title")
    W.labels.vehicles = BJI.Managers.Lang.get("database.vehicles.title")
    W.labels.close = BJI.Managers.Lang.get("common.buttons.close")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED, function()
        if not W.TABS:any(function(t)
                return not t.permission or BJI.Managers.Perm.hasPermission(t.permission)
            end) then
            onClose()
        end
    end, W.name))

    if not W.tab or (W.tab.permission and not BJI.Managers.Perm.hasPermission(W.tab.permission)) then
        if W.tab then
            W.tab.subWindow.onUnload()
        end
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
    if BeginTabBar("BJIDatabaseTabs") then
        W.TABS:filter(function(t)
            return BJI.Managers.Perm.hasPermission(t.permission)
        end):forEach(function(tab)
            if BeginTabItem(W.labels[tab.labelKey]) then
                updateTab(tab)
                if W.tab and W.tab.subWindow.header then
                    W.tab.subWindow.header(ctxt)
                end
                EndTabItem()
            end
        end)
        EndTabBar()
    end
end

local function body(ctxt)
    if W.tab and W.tab.subWindow.body then
        W.tab.subWindow.body(ctxt)
    end
end

local function footer(ctxt)
    if IconButton("databaseClose", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.close)
    if W.tab and W.tab.subWindow.footer then
        SameLine()
        W.tab.subWindow.footer(ctxt)
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.getState = function() return W.show end

return W
