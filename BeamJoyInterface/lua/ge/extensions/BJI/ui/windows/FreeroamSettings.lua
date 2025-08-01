local CONFIG = Table({
    {
        label = "vehicleSpawning",
        type = "boolean",
        keyData = "VehicleSpawning",
    },
    {
        label = "collisionsMode",
        type = "select",
        keyData = "CollisionsMode",
        options = {
            {
                value = "ghosts",
                key = "collisionsModesGhosts",
            },
            {
                value = "forced",
                key = "collisionsModesForced",
            },
            {
                value = "disabled",
                key = "collisionsModesDisabled",
            },
        }
    },
    {
        label = "quickTravel",
        type = "boolean",
        keyData = "QuickTravel",
    },
    {
        label = "nodeGrabber",
        type = "boolean",
        keyData = "Nodegrabber",
    },
    {
        label = "nametags",
        type = "boolean",
        keyData = "Nametags"
    },
    {
        label = "allowUnicycle",
        type = "boolean",
        keyData = "AllowUnicycle"
    },
    {
        label = "resetDelay",
        tooltip = "resetDelayTooltip",
        type = "number",
        keyData = "ResetDelay",
        min = 0,
        max = 120,
        formatRender = "%ds",
    },
    {
        label = "teleportDelay",
        tooltip = "teleportDelayTooltip",
        type = "number",
        keyData =
        "TeleportDelay",
        min = 0,
        max = 120,
        formatRender = "%ds",
    },
    {
        label = "driftGood",
        type = "number",
        keyData = "DriftGood",
        min = 100,
        max = function(data) return data.DriftBig - 1 end
    },
    {
        label = "driftBig",
        type = "number",
        keyData = "DriftBig",
        min = function(data) return data.DriftGood + 1 end,
        max = 50000
    },
    {
        label = "preserveEnergy",
        type = "boolean",
        keyData = "PreserveEnergy"
    },
    {
        label = "emergencyRefuelDuration",
        tooltip = "emergencyRefuelDurationTooltip",
        type = "number",
        keyData = "EmergencyRefuelDuration",
        min = 5,
        max = 60,
        formatRender = "%ds",
        disabled = function(data) return not data.PreserveEnergy end
    },
    {
        label = "emergencyRefuelPercent",
        tooltip = "emergencyRefuelPercentTooltip",
        type = "number",
        keyData = "EmergencyRefuelPercent",
        min = 5,
        max = 100,
        formatRender = "%d%%",
        disabled = function(data) return not data.PreserveEnergy end
    },
})

---@class BJIWindowFreeroamSettings : BJIWindow
local W = {
    name = "FreeroamSettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    minSize = ImVec2(460, 410),
    maxSize = ImVec2(800, 410),

    show = false,
    ---@type table<string, any>
    data = Table(),
    dirty = false,

    labels = {
        vehicleSpawning = "",
        collisionsMode = "",
        collisionsModesForced = "",
        collisionsModesDisabled = "",
        collisionsModesGhosts = "",
        quickTravel = "",
        nodeGrabber = "",
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
}
--- gc prevention
local nextValue

local function onClose()
    local function _close()
        W.data = Table()
        W.dirty = false
        W.show = false
    end
    if W.dirty then
        BJI_Popup.createModal(BJI_Lang.get("freeroamSettings.cancelModal"), {
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.cancel")),
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.confirm"), _close),
        })
    else
        _close()
    end
end

local function updateLabels()
    W.labels.vehicleSpawning = BJI_Lang.get("freeroamSettings.vehicleSpawning") .. " :"
    W.labels.collisionsMode = BJI_Lang.get("freeroamSettings.collisionsMode") .. " :"
    W.labels.collisionsModesForced = BJI_Lang.get("freeroamSettings.collisionsModes.forced")
    W.labels.collisionsModesDisabled = BJI_Lang.get("freeroamSettings.collisionsModes.disabled")
    W.labels.collisionsModesGhosts = BJI_Lang.get("freeroamSettings.collisionsModes.ghosts")
    W.labels.quickTravel = BJI_Lang.get("freeroamSettings.quickTravel") .. " :"
    W.labels.nodeGrabber = BJI_Lang.get("freeroamSettings.nodeGrabber") .. " :"
    W.labels.nametags = BJI_Lang.get("freeroamSettings.nametags") .. " :"
    W.labels.allowUnicycle = BJI_Lang.get("freeroamSettings.allowUnicycle") .. " :"
    W.labels.resetDelay = BJI_Lang.get("freeroamSettings.resetDelay") .. " :"
    W.labels.resetDelayTooltip = BJI_Lang.get("freeroamSettings.resetDelayTooltip")
    W.labels.teleportDelay = BJI_Lang.get("freeroamSettings.teleportDelay") .. " :"
    W.labels.teleportDelayTooltip = BJI_Lang.get("freeroamSettings.teleportDelayTooltip")
    W.labels.driftGood = BJI_Lang.get("freeroamSettings.driftGood") .. " :"
    W.labels.driftBig = BJI_Lang.get("freeroamSettings.driftBig") .. " :"
    W.labels.preserveEnergy = BJI_Lang.get("freeroamSettings.preserveEnergy") .. " :"
    W.labels.emergencyRefuelDuration = BJI_Lang.get("freeroamSettings.emergencyRefuelDuration") .. " :"
    W.labels.emergencyRefuelDurationTooltip = BJI_Lang.get("freeroamSettings.emergencyRefuelDurationTooltip")
    W.labels.emergencyRefuelPercent = BJI_Lang.get("freeroamSettings.emergencyRefuelPercent") .. " :"
    W.labels.emergencyRefuelPercentTooltip = BJI_Lang.get("freeroamSettings.emergencyRefuelPercentTooltip")

    W.labels.buttons.reset = BJI_Lang.get("common.buttons.reset")
    W.labels.buttons.resetAll = BJI_Lang.get("common.buttons.resetAll")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI_Lang.get("common.buttons.save")
end

local function updateChanged()
    W.dirty = not table.compare(W.data, BJI_Context.BJC.Freeroam)
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.UI_SCALE_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt, data)
        if data._event ~= BJI_Events.EVENTS.CACHE_LOADED or
            data.cache == BJI_Cache.CACHES.BJC then
            updateCache(ctxt)
        end
    end, W.name .. "Cache"))

    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CONFIG) then
            onClose()
        end
    end, W.name .. "AutoClose"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

---@param ctxt TickContext
local function body(ctxt)
    if BeginTable("freeroamSettings", {
            { label = "##freeroam-settings-label" },
            { label = "##freeroam-settings-input",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##freeroam-settings-buttons" },
        }) then
        CONFIG:forEach(function(conf)
            TableNewRow()
            Text(W.labels[conf.label])
            TooltipText(conf.tooltip and W.labels[conf.tooltip] or nil)
            TableNextColumn()
            if conf.type == "boolean" then
                if IconButton(conf.keyData, W.data[conf.keyData] and BJI.Utils.Icon.ICONS.check_circle or
                        BJI.Utils.Icon.ICONS.cancel, { disabled = conf.disabled and conf.disabled(W.data), bgLess = true,
                            btnStyle = W.data[conf.keyData] and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                                BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                    W.data[conf.keyData] = not W.data[conf.keyData]
                    updateChanged()
                end
                TooltipText(conf.tooltip and W.labels[conf.tooltip] or nil)
            elseif conf.type == "number" then
                nextValue = SliderIntPrecision(conf.keyData, W.data[conf.keyData] or 0,
                    type(conf.min) == "function" and conf.min(W.data) or conf.min or 0,
                    type(conf.max) == "function" and conf.max(W.data) or conf.max or 0,
                    { formatRender = conf.formatRender, disabled = conf.disabled and conf.disabled(W.data) })
                TooltipText(conf.tooltip and W.labels[conf.tooltip] or nil)
                if nextValue then
                    W.data[conf.keyData] = nextValue
                    updateChanged()
                end
            elseif conf.type == "select" then
                nextValue = Combo(conf.keyData, W.data[conf.keyData], table.map(conf.options, function(o)
                    return {
                        value = o.value,
                        label = W.labels[o.key]
                    }
                end))
                if nextValue then
                    W.data[conf.keyData] = nextValue
                    updateChanged()
                end
            end
            TableNextColumn()
            if W.data[conf.keyData] ~= BJI_Context.BJC.Freeroam[conf.keyData] then
                if IconButton("reset" .. conf.keyData, BJI.Utils.Icon.ICONS.refresh,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                    W.data[conf.keyData] = BJI_Context.BJC.Freeroam[conf.keyData]
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
    if W.dirty then
        SameLine()
        if IconButton("reset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
            W.open()
            W.dirty = false
        end
        TooltipText(W.labels.buttons.resetAll)
        SameLine()
        if IconButton("save", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            CONFIG:reduce(function(acc, conf)
                acc[conf.keyData] = W.data[conf.keyData]
                return acc
            end, Table())
                :filter(function(v, k) return v ~= BJI_Context.BJC.Freeroam[k] end)
                :forEach(function(v, k) BJI_Tx_config.bjc(string.var("Freeroam.{1}", { k }), v) end)
            W.dirty = false
        end
        TooltipText(W.labels.buttons.save)
    end
end

local function open()
    W.data = table.clone(BJI_Context.BJC.Freeroam)
    W.dirty = false
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
