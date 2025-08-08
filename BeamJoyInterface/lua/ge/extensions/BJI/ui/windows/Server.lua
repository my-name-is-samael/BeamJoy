---@class BJIWindowServer : BJIWindow
local W = {
    name = "Server",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    minSize = ImVec2(500, 600),
    maxSize = ImVec2(1500, 1500),

    ---@type tablelib<integer, {show: (fun(): boolean), labelKey: string, subWindow: table}>
    TABS = Table({
        {
            show = function()
                return BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CONFIG) or
                    BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.WHITELIST)
            end,
            labelKey = "bjc",
            subWindow = require("ge/extensions/BJI/ui/windows/Server/BJC"),
        },
        {
            show = function()
                return BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_REPUTATION)
            end,
            labelKey = "reputation",
            subWindow = require("ge/extensions/BJI/ui/windows/Server/Reputation"),
        },
        {
            show = function()
                return BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_PERMISSIONS)
            end,
            labelKey = "permissions",
            subWindow = require("ge/extensions/BJI/ui/windows/Server/Permissions"),
        },
        {
            show = function()
                return BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_MAPS)
            end,
            labelKey = "maps",
            subWindow = require("ge/extensions/BJI/ui/windows/Server/Maps"),
        },
        {
            show = function()
                return BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CORE) or
                    BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CEN)
            end,
            labelKey = "core",
            subWindow = require("ge/extensions/BJI/ui/windows/Server/CoreCEN"),
        },
        {
            show = function()
                return BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CORE) and
                    BJI_Context.Core.Debug
            end,
            labelKey = "icons",
            subWindow = require("ge/extensions/BJI/ui/windows/Server/Icons"),
        },
    }),

    show = false,
    ---@type {show: (fun(): boolean), labelKey: string, subWindow: table}?
    tab = nil,
    labels = {
        bjc = "",
        reputation = "",
        permissions = "",
        maps = "",
        core = "",
        icons = "",
        close = "",
    },
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.bjc = BJI_Lang.get("serverConfig.bjc.title")
    W.labels.reputation = BJI_Lang.get("serverConfig.reputation.title")
    W.labels.permissions = BJI_Lang.get("serverConfig.permissions.title")
    W.labels.maps = BJI_Lang.get("serverConfig.maps.title")
    W.labels.core = BJI_Lang.get("serverConfig.core.title")
    W.labels.icons = BJI_Lang.get("serverConfig.icons.title")
    W.labels.close = BJI_Lang.get("common.buttons.close")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not W.TABS:any(function(t) return t.show() end) then
            onClose()
        end
    end, W.name))

    if not W.tab then
        W.TABS:find(function(t) return t.show() end, function(t)
            W.tab = t
            if t.subWindow.onLoad then
                t.subWindow.onLoad()
            end
        end)
    end
end

local function onUnload()
    if W.tab and W.tab.subWindow.onUnload then
        W.tab.subWindow.onUnload()
    end
    W.tab = nil
    listeners:forEach(BJI_Events.removeListener)
end

---@param newTab {show: (fun(): boolean), labelKey: string, subWindow: table}?
local function updateTab(newTab)
    if newTab and newTab ~= W.tab then
        if W.tab and W.tab.subWindow.onUnload then
            W.tab.subWindow.onUnload()
        end
        W.tab = newTab
        if W.tab and W.tab.subWindow.onLoad then
            W.tab.subWindow.onLoad()
        end
    end
end

---@param ctxt TickContext
local function header(ctxt)
    if BeginTabBar("BJIServerTabs") then
        W.TABS:filter(function(tab)
            return tab.show()
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

---@param ctxt TickContext
local function body(ctxt)
    if W.tab and W.tab.subWindow.body then
        W.tab.subWindow.body(ctxt)
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeServer", BJI.Utils.Icon.ICONS.exit_to_app,
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
