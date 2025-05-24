---@class BJIWindowEnvironment : BJIWindow
local W = {
    name = "Environment",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 440,
    h = 640,

    TABS = Table({
        {
            labelKey = "sun",
            subWindow = require("ge/extensions/BJI/ui/windows/Environment/Sun"),
        },
        {
            labelKey = "weather",
            subWindow = require("ge/extensions/BJI/ui/windows/Environment/Weather"),
        },
        {
            labelKey = "gravity",
            subWindow = require("ge/extensions/BJI/ui/windows/Environment/Gravity"),
        },
        {
            labelKey = "temperature",
            subWindow = require("ge/extensions/BJI/ui/windows/Environment/Temperature"),
        },
        {
            labelKey = "speed",
            subWindow = require("ge/extensions/BJI/ui/windows/Environment/Speed"),
        }
    }),
    tab = nil,

    show = false,
    ---@type table<string, any>
    sharedCache = Table(),

    labels = {
        sun = "",
        weather = "",
        gravity = "",
        temperature = "",
        speed = "",
    },
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.sun = BJI.Managers.Lang.get("environment.sun")
    W.labels.weather = BJI.Managers.Lang.get("environment.weather")
    W.labels.gravity = BJI.Managers.Lang.get("environment.gravity")
    W.labels.temperature = BJI.Managers.Lang.get("environment.temperature")
    W.labels.speed = BJI.Managers.Lang.get("environment.speed")
end

local function updateSharedCache()
    W.sharedCache = table.clone(BJI.Managers.Env.Data)
end

local function tickSave()
    if not table.compare(W.sharedCache, BJI.Managers.Env.Data, true) then
        local function checkAndSend(cached, data, prefix)
            prefix = prefix or ""
            Table(cached):forEach(function(v, k)
                if k == "fogColor" then
                    if not table.compare(v, data[k]) then
                        BJI.Tx.config.env("fogColor", data[k])
                    end
                elseif type(v) == "table" and type(data[k]) == "table" then
                    checkAndSend(v, data[k], string.var("{1}{2}.", { prefix, k }))
                elseif not table.includes({ "ToD", "shadowTexSizeInput" }, k) and v ~= data[k] then
                    BJI.Tx.config.env(prefix .. tostring(k), data[k])
                end
            end)
        end
        checkAndSend(W.sharedCache, BJI.Managers.Env.Data)
    end
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
    }, function()
        if not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT) then
            onClose()
        end
    end))

    updateSharedCache()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI.Managers.Cache.CACHES.ENVIRONMENT then
                updateSharedCache()
                BJI.Managers.Env.ToDEdit = false
            end
        end))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, tickSave))

    if not W.tab or not W.TABS[W.tab] then
        W.tab = 1
        if W.TABS[W.tab].subWindow.onLoad then
            W.TABS[W.tab].subWindow.onLoad()
        end
    end
end

local function onUnload()
    if W.TABS[W.tab] and W.TABS[W.tab].subWindow.onUnload then
        W.TABS[W.tab].subWindow.onUnload()
    end
    listeners:forEach(BJI.Managers.Events.removeListener)
    W.sharedCache = Table()
end

local function updateTab(newIndex)
    if newIndex ~= W.tab and W.TABS[newIndex] then
        if W.TABS[W.tab] and W.TABS[W.tab].subWindow.onUnload then
            W.TABS[W.tab].subWindow.onUnload()
        end
        W.tab = newIndex
        if W.TABS[W.tab].subWindow.onLoad then
            W.TABS[W.tab].subWindow.onLoad()
        end
    end
end

---@param ctxt TickContext
local function header(ctxt)
    local t = TabBarBuilder("BJIEnvironmentTabs")
    W.TABS:forEach(function(tab, i)
        t:addTab(W.labels[tab.labelKey], function()
            updateTab(i)
        end)
    end)
    t:build()
end

---@param ctxt TickContext
local function body(ctxt)
    if W.TABS[W.tab] and W.TABS[W.tab].subWindow.body then
        W.TABS[W.tab].subWindow.body(ctxt)
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeEnvironment",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = onClose
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
W.open = function()
    W.show = true
end

return W
