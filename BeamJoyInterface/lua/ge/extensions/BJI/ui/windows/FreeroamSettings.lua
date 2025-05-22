---@class BJIWindowFreeroamSettings : BJIWindow
local W = {
    name = "FreeroamSettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 460,
    h = 350,

    show = false,
    ---@type table<string, any>
    data = Table(),
    changed = false,

    labels = {
        vehicleSpawning = "",
        quickTravel = "",
        nametags = "",
        allowUnicycle = "",
        resetDelay = "",
        resetDelayTooltip = "",
        teleportDelay = "",
        teleportDelayTooltip = "",
        driftGood = "",
        driftBig = "",
        preserveEnergy = "",
        emergencyRefuelDuration = "",
        emergencyRefuelDurationTooltip = "",
        emergencyRefuelPercent = "",
        emergencyRefuelPercentTooltip = "",
    },
    cache = {
        labelsWidth = 0,
        buttonsWidth = 0,
        colsConfig = Table(),
        cols = Table(),
    },
}

local function onClose()
    if W.changed then
        BJI.Managers.Popup.createModal(BJI.Managers.Lang.get("freeroamSettings.cancelModal"), {
            {
                label = BJI.Managers.Lang.get("common.buttons.cancel"),
            },
            {
                label = BJI.Managers.Lang.get("common.buttons.confirm"),
                onClick = function()
                    W.data = Table()
                    W.changed = false
                    W.show = false
                end,
            }
        })
    else
        W.show = false
    end
end

local function updateLabels()
    W.labels.vehicleSpawning = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.vehicleSpawning") })
    W.labels.quickTravel = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.quickTravel") })
    W.labels.nametags = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.nametags") })
    W.labels.allowUnicycle = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.allowUnicycle") })
    W.labels.resetDelay = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.resetDelay") })
    W.labels.resetDelayTooltip = BJI.Managers.Lang.get("freeroamSettings.resetDelayTooltip")
    W.labels.teleportDelay = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.teleportDelay") })
    W.labels.teleportDelayTooltip = BJI.Managers.Lang.get("freeroamSettings.teleportDelayTooltip")
    W.labels.driftGood = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.driftGood") })
    W.labels.driftBig = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.driftBig") })
    W.labels.preserveEnergy = string.var("{1}:", { BJI.Managers.Lang.get("freeroamSettings.preserveEnergy") })
    W.labels.emergencyRefuelDuration = string.var("{1}:",
        { BJI.Managers.Lang.get("freeroamSettings.emergencyRefuelDuration") })
    W.labels.emergencyRefuelDurationTooltip = BJI.Managers.Lang.get("freeroamSettings.emergencyRefuelDurationTooltip")
    W.labels.emergencyRefuelPercent = string.var("{1}:",
        { BJI.Managers.Lang.get("freeroamSettings.emergencyRefuelPercent") })
    W.labels.emergencyRefuelPercentTooltip = BJI.Managers.Lang.get("freeroamSettings.emergencyRefuelPercentTooltip")
end

local function updateChanged()
    W.changed = not table.compare(W.data, BJI.Managers.Context.BJC.Freeroam)
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.cache.labelsWidth = Table(W.labels)
        :filter(function(_, k) return not tostring(k):endswith("Tooltip") end)
        :reduce(function(acc, label)
            local w = BJI.Utils.Common.GetColumnTextWidth(label)
            return w > acc and w or acc
        end, 0)
    W.cache.buttonsWidth = GetBtnIconSize()

    W.cache.colsConfig = Table({
        {
            label = W.labels.vehicleSpawning,
            type = "boolean",
            keyData = "VehicleSpawning",
            minGroup = BJI.CONSTANTS.GROUP_NAMES.ADMIN
        },
        {
            label = W.labels.quickTravel,
            type = "boolean",
            keyData = "QuickTravel",
            minGroup = BJI.CONSTANTS.GROUP_NAMES.ADMIN
        },
        {
            label = W.labels.nametags,
            type = "boolean",
            keyData = "Nametags"
        },
        {
            label = W.labels.allowUnicycle,
            type = "boolean",
            keyData = "AllowUnicycle"
        },
        {
            label = W.labels.resetDelay,
            tooltip = W.labels.resetDelayTooltip,
            type = "number",
            keyData = "ResetDelay",
            min = 0,
            max = 120,
            renderFormat = "%ds",
        },
        {
            label = W.labels.teleportDelay,
            tooltip = W.labels.teleportDelayTooltip,
            type = "number",
            keyData =
            "TeleportDelay",
            min = 0,
            max = 120,
            renderFormat = "%ds",
        },
        {
            label = W.labels.driftGood,
            type = "number",
            keyData = "DriftGood",
            min = 100,
            max = function() return W.data.DriftBig - 1 end
        },
        {
            label = W.labels.driftBig,
            type = "number",
            keyData = "DriftBig",
            min = function() return W.data.DriftGood + 1 end,
            max = 50000
        },
        {
            label = W.labels.preserveEnergy,
            type = "boolean",
            keyData = "PreserveEnergy"
        },
        {
            label = W.labels.emergencyRefuelDuration,
            tooltip = W.labels.emergencyRefuelDurationTooltip,
            type = "number",
            keyData = "EmergencyRefuelDuration",
            min = 5,
            max = 60,
            renderFormat = "%ds",
            disabled = function() return not W.data.PreserveEnergy end
        },
        {
            label = W.labels.emergencyRefuelPercent,
            tooltip = W.labels.emergencyRefuelPercentTooltip,
            type = "number",
            keyData = "EmergencyRefuelPercent",
            min = 5,
            max = 100,
            renderFormat = "%d%%",
            disabled = function() return not W.data.PreserveEnergy end
        },
    })

    W.cache.cols = W.cache.colsConfig
        :filter(function(conf)
            return not conf.minGroup or BJI.Managers.Perm.hasMinimumGroup(conf.minGroup)
        end):map(function(conf)
            return {
                cells = {
                    function()
                        local line = LineBuilder():text(conf.label, nil, conf.tooltip)
                        line:build()
                    end,
                    function()
                        if conf.type == "boolean" then
                            LineBuilder():btnIconToggle({
                                id = conf.keyData,
                                state = W.data[conf.keyData],
                                coloredIcon = true,
                                onClick = function()
                                    W.data[conf.keyData] = not W.data[conf.keyData]
                                    updateChanged()
                                end,
                            }):build()
                        elseif conf.type == "number" then
                            local min = conf.min and
                                (type(conf.min) == "function" and conf.min() or conf.min) or
                                nil
                            local max = conf.max and
                                (type(conf.max) == "function" and conf.max() or conf.max) or
                                nil
                            LineBuilder():slider({
                                id = conf.keyData,
                                type = "int",
                                value = W.data[conf.keyData] or 0,
                                min = min or 0,
                                max = max or 0,
                                renderFormat = conf.renderFormat,
                                disabled = type(conf.disabled) == "function" and conf.disabled() or false,
                                onUpdate = function(val)
                                    W.data[conf.keyData] = val
                                    updateChanged()
                                end,
                            }):build()
                        end
                    end,
                    function()
                        if W.data[conf.keyData] ~= BJI.Managers.Context.BJC.Freeroam[conf.keyData] then
                            LineBuilder()
                                :btnIcon({
                                    id = conf.keyData,
                                    icon = ICONS.refresh,
                                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                    onClick = function()
                                        W.data[conf.keyData] = BJI.Managers.Context.BJC.Freeroam[conf.keyData]
                                        updateChanged()
                                    end,
                                }):build()
                        end
                    end,
                }
            }
        end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            data.cache == BJI.Managers.Cache.CACHES.BJC then
            updateCache(ctxt)
        end
    end))

    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CONFIG) then
            onClose()
        end
    end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    W.data = Table()
    W.changed = false
end

---@param ctxt TickContext
local function body(ctxt)
    local cols = ColumnsBuilder("freeroamSettings", { W.cache.labelsWidth, -1, W.cache.buttonsWidth })
    W.cache.cols:forEach(function(col)
        cols:addRow(col)
    end)
    cols:build()
end

---@param ctxt TickContext
local function footer(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "closeFreeroamSettings",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = function()
                onClose()
            end
        })
    if W.changed then
        line:btnIcon({
            id = "reset",
            icon = ICONS.refresh,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            onClick = function()
                W.data = table.clone(BJI.Managers.Context.BJC.Freeroam)
                W.changed = false
            end,
        })
            :btnIcon({
                id = "save",
                icon = ICONS.save,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                onClick = function()
                    W.cache.colsConfig:reduce(function(acc, conf)
                        acc[conf.keyData] = W.data[conf.keyData]
                        return acc
                    end, Table())
                        :filter(function(v, k) return v ~= BJI.Managers.Context.BJC.Freeroam[k] end)
                        :forEach(function(v, k) BJI.Tx.config.bjc(string.var("Freeroam.{1}", { k }), v) end)
                    W.changed = false
                end
            })
    end
    line:build()
end

local function open()
    W.data = Table(BJI.Managers.Context.BJC.Freeroam):clone()
    W.show = true
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body
W.footer = footer
W.onClose = onClose
W.open = open
W.getState = function() return W.show end

return W
