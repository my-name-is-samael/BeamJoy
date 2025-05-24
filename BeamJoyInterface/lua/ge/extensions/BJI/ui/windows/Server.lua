---@class BJIWindowServer : BJIWindow
local W = {
    name = "Server",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 470,
    h = 450,

    ---@type tablelib<integer, {show: (fun(): boolean), labelKey: string, content: table}>
    TABS = Table({
        {
            show = function()
                return BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.BJC) and
                    BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CONFIG)
            end,
            labelKey = "bjc",
            content = require("ge/extensions/BJI/ui/windows/Server/BJC"),
        },
        {
            show = function()
                return BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_REPUTATION)
            end,
            labelKey = "reputation",
            content = require("ge/extensions/BJI/ui/windows/Server/Reputation"),
        },
        {
            show = function()
                return BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_PERMISSIONS)
            end,
            labelKey = "permissions",
            content = require("ge/extensions/BJI/ui/windows/Server/Permissions"),
        },
        {
            show = function()
                return BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_MAPS)
            end,
            labelKey = "maps",
            content = require("ge/extensions/BJI/ui/windows/Server/Maps"),
        },
        {
            show = function()
                return BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CORE) or
                    BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CEN)
            end,
            labelKey = "core",
            content = require("ge/extensions/BJI/ui/windows/Server/CoreCEN"),
        },
        {
            show = function()
                return BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CORE) and
                    BJI.Managers.Context.Core.Debug
            end,
            labelKey = "icons",
            content = require("ge/extensions/BJI/ui/windows/Server/Icons"),
        },
    }),

    show = false,
    ---@type {show: (fun(): boolean), labelKey: string, content: table}?
    tab = nil,
    labels = {
        bjc = "",
        reputation = "",
        permissions = "",
        maps = "",
        core = "",
        icons = "",
    },
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.bjc = BJI.Managers.Lang.get("serverConfig.bjc.title")
    W.labels.reputation = BJI.Managers.Lang.get("serverConfig.reputation.title")
    W.labels.permissions = BJI.Managers.Lang.get("serverConfig.permissions.title")
    W.labels.maps = BJI.Managers.Lang.get("serverConfig.maps.title")
    W.labels.core = BJI.Managers.Lang.get("serverConfig.core.title")
    W.labels.icons = BJI.Managers.Lang.get("serverConfig.icons.title")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels))

    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
    }, function(_, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            table.includes({
                BJI.Managers.Cache.CACHES.PERMISSIONS,
                BJI.Managers.Cache.CACHES.USER,
                BJI.Managers.Cache.CACHES.GROUPS,
            }, data.cache) then
            if not W.TABS:any(function(t) return t.show() end) then
                onClose()
            end
        end
    end))

    if not W.tab then
        W.TABS:find(function(t) return t.show() end, function(t)
            W.tab = t
            if t.content.onLoad then
                t.content.onLoad()
            end
        end)
    end
end

local function onUnload()
    if W.tab and W.tab.content.onUnload then
        W.tab.content.onUnload()
    end
    W.tab = nil
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param newTab {show: (fun(): boolean), labelKey: string, content: table}?
local function updateTab(newTab)
    if newTab and newTab ~= W.tab then
        if W.tab and W.tab.content.onUnload then
            W.tab.content.onUnload()
        end
        W.tab = newTab
        if W.tab and W.tab.content.onLoad then
            W.tab.content.onLoad()
        end
    end
end

---@param ctxt TickContext
local function header(ctxt)
    local t = TabBarBuilder("BJIEnvironmentTabs")
    W.TABS:filter(function(tab)
        return tab.show()
    end)
        :forEach(function(tab)
            t:addTab(W.labels[tab.labelKey], function()
                updateTab(tab)
            end)
        end)
    t:build()
end

---@param ctxt TickContext
local function body(ctxt)
    if W.tab and W.tab.content.body then
        W.tab.content.body(ctxt)
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeServer",
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
