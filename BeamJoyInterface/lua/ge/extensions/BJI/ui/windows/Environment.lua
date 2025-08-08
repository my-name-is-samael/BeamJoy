---@class BJIWindowEnvironment : BJIWindow
local W = {
    name = "Environment",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    minSize = ImVec2(600, 660),
    maxSize = ImVec2(1000, 700),

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
    ---@type integer?
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
        close = "",
    },
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.sun = BJI_Lang.get("environment.sun")
    W.labels.weather = BJI_Lang.get("environment.weather")
    W.labels.gravity = BJI_Lang.get("environment.gravity")
    W.labels.temperature = BJI_Lang.get("environment.temperature")
    W.labels.speed = BJI_Lang.get("environment.speed")
    W.labels.close = BJI_Lang.get("common.buttons.close")
end

local function updateSharedCache()
    W.sharedCache = table.clone(BJI_Env.Data)
end

local function tickSave()
    if not table.compare(W.sharedCache, BJI_Env.Data, true) then
        local function checkAndSend(cached, data, prefix)
            prefix = prefix or ""
            Table(cached):forEach(function(v, k)
                if k == "fogColor" then
                    if not table.compare(v, data[k]) then
                        BJI_Tx_config.env("fogColor", data[k])
                    end
                elseif type(v) == "table" and type(data[k]) == "table" then
                    checkAndSend(v, data[k], string.var("{1}{2}.", { prefix, k }))
                elseif not table.includes({ "ToD", "shadowTexSizeInput" }, k) and v ~= data[k] then
                    BJI_Tx_config.env(prefix .. tostring(k), data[k])
                end
            end)
        end
        checkAndSend(W.sharedCache, BJI_Env.Data)
    end
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_ENVIRONMENT) then
            onClose()
        end
    end, W.name))

    updateSharedCache()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI_Cache.CACHES.ENVIRONMENT then
                updateSharedCache()
                BJI_Env.ToDEdit = false
            end
        end, W.name))

    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.SLOW_TICK, tickSave, W.name))

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
    listeners:forEach(BJI_Events.removeListener)
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
    if BeginTabBar("BJIEnvironmentTabs") then
        W.TABS:forEach(function(tab, i)
            if BeginTabItem(W.labels[tab.labelKey]) then
                updateTab(i)
                if W.TABS[W.tab] and W.TABS[W.tab].subWindow.header then
                    W.TABS[W.tab].subWindow.header(ctxt)
                end
                EndTabItem()
            end
        end)
        EndTabBar()
    end
end

---@param ctxt TickContext
local function body(ctxt)
    if W.TABS[W.tab] and W.TABS[W.tab].subWindow.body then
        W.TABS[W.tab].subWindow.body(ctxt)
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeEnvironment", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.close)
    if W.TABS[W.tab] and W.TABS[W.tab].subWindow.footer then
        SameLine()
        W.TABS[W.tab].subWindow.footer(ctxt)
    end
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
