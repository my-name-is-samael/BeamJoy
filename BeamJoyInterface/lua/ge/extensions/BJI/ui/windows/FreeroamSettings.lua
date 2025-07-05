---@class BJIWindowFreeroamSettings : BJIWindow
local W = {
    name = "FreeroamSettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    minSize = ImVec2(460, 350),
    maxSize = ImVec2(800, 350),

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
        buttons = {
            reset = "",
            resetAll = "",
            close = "",
            save = "",
        },
    },
    cache = {
        config = Table(),
    },
}
--- gc prevention
local nextValue

local function onClose()
    if W.changed then
        BJI.Managers.Popup.createModal(BJI.Managers.Lang.get("freeroamSettings.cancelModal"), {
            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"), function()
                W.data = Table()
                W.changed = false
                W.show = false
            end),
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

    W.labels.buttons.reset = BJI.Managers.Lang.get("common.buttons.reset")
    W.labels.buttons.resetAll = BJI.Managers.Lang.get("common.buttons.resetAll")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
end

local function updateChanged()
    W.changed = not table.compare(W.data, BJI.Managers.Context.BJC.Freeroam)
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.cache.config = Table({
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
            formatRender = "%ds",
        },
        {
            label = W.labels.teleportDelay,
            tooltip = W.labels.teleportDelayTooltip,
            type = "number",
            keyData =
            "TeleportDelay",
            min = 0,
            max = 120,
            formatRender = "%ds",
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
            formatRender = "%ds",
            disabled = function() return not W.data.PreserveEnergy end
        },
        {
            label = W.labels.emergencyRefuelPercent,
            tooltip = W.labels.emergencyRefuelPercentTooltip,
            type = "number",
            keyData = "EmergencyRefuelPercent",
            min = 5,
            max = 100,
            formatRender = "%d%%",
            disabled = function() return not W.data.PreserveEnergy end
        },
    })
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
    end, W.name .. "Labels"))

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
    end, W.name .. "Cache"))

    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CONFIG) then
            onClose()
        end
    end, W.name .. "AutoClose"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    W.data = Table()
    W.changed = false
end

---@param ctxt TickContext
local function body(ctxt)
    if BeginTable("freeroamSettings", {
            { label = "##freeroam-settings-label" },
            { label = "##freeroam-settings-input",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##freeroam-settings-buttons" },
        }) then
        W.cache.config:filter(function(conf)
            return not conf.minGroup or BJI.Managers.Perm.hasMinimumGroup(conf.minGroup)
        end):forEach(function(conf)
            TableNewRow()
            Text(conf.label)
            TooltipText(conf.tooltip)
            TableNextColumn()
            if conf.type == "boolean" then
                if IconButton(conf.keyData, W.data[conf.keyData] and BJI.Utils.Icon.ICONS.check_circle or
                        BJI.Utils.Icon.ICONS.cancel, { disabled = conf.disabled and conf.disabled(), bgLess = true,
                            btnStyle = W.data[conf.keyData] and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                                BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                    W.data[conf.keyData] = not W.data[conf.keyData]
                    updateChanged()
                end
                TooltipText(conf.tooltip)
            elseif conf.type == "number" then
                nextValue = SliderIntPrecision(conf.keyData, W.data[conf.keyData] or 0,
                    type(conf.min) == "function" and conf.min() or conf.min or 0,
                    type(conf.max) == "function" and conf.max() or conf.max or 0,
                    { formatRender = conf.formatRender, disabled = conf.disabled and conf.disabled() })
                TooltipText(conf.tooltip)
                if nextValue then
                    W.data[conf.keyData] = nextValue
                    updateChanged()
                end
            end
            TableNextColumn()
            if W.data[conf.keyData] ~= BJI.Managers.Context.BJC.Freeroam[conf.keyData] then
                if IconButton("reset" .. conf.keyData, BJI.Utils.Icon.ICONS.refresh,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                    W.data[conf.keyData] = BJI.Managers.Context.BJC.Freeroam[conf.keyData]
                    updateChanged()
                end
                TooltipText(W.labels.buttons.reset)
            end
        end)

        EndTable()
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeFreeroamSettings", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.changed then
        SameLine()
        if IconButton("reset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
            W.open()
            W.changed = false
        end
        TooltipText(W.labels.buttons.resetAll)
        SameLine()
        if IconButton("save", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            W.cache.config:reduce(function(acc, conf)
                acc[conf.keyData] = W.data[conf.keyData]
                return acc
            end, Table())
                :filter(function(v, k) return v ~= BJI.Managers.Context.BJC.Freeroam[k] end)
                :forEach(function(v, k) BJI.Tx.config.bjc(string.var("Freeroam.{1}", { k }), v) end)
            W.changed = false
        end
        TooltipText(W.labels.buttons.save)
    end
end

local function open()
    W.data = table.clone(BJI.Managers.Context.BJC.Freeroam)
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
