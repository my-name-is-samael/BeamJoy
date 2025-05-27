local ACCORDION_THRESHOLD = 2

---@class BJIWindowVehSelector : BJIWindow
---@field tryClose fun(force?: boolean)
local W = {
    name = "VehSelector",
    w = 320,
    h = 420,

    show = false,
    models = {
        cars = {},
        trucks = {},
        trailers = {},
        props = {},
    },
    vehFilter = "",
    cache = {
        vehicles = {},
        paints = {}
    },
    labels = {
        previousVeh = "",
        setAsDefault = "",
        loadDefault = "",
        cloneCurrent = "",
        resetAll = "",
        removeCurrent = "",
        removeOthers = "",
        noVeh = "",
        notAllowed = "",
        protectedVehicle = "",
        invalidVeh = "",

        openVehSelector = "",
        remove = "",
        show = "",
        spawn = "",
        replace = "",
        random = "",
        applyPaint = "",
        close = "",

        cars = "",
        trucks = "",
        trailers = "",
        props = "",
        paints = "",
    },
    headerBtns = {
        loadPreviousDisabled = true,
        loadPreviousTooltip = nil,
        setAsDefaultDisabled = true,
        setAsDefaultTooltip = nil,
        loadDefaultDisabled = true,
        loadDefaultTooltip = nil,
        cloneCurrentDisabled = true,
        cloneCurrentTooltip = nil,
        resetAllDisabled = true,
        resetAllTooltip = nil,
        removeCurrentDisabled = true,
        removeCurrentTooltip = nil,
        removeOthersDisabled = true,
        removeOthersTooltip = nil,
    },
}
local ownVeh, limitReached = false, false

local function updateCacheVehicles()
    W.cache.vehicles = {}
    if #W.vehFilter == 0 then
        W.cache.vehicles = W.models
    else
        for modelType, models in pairs(W.models) do
            W.cache.vehicles[modelType] = {}
            for _, model in ipairs(models) do
                if model.label:lower():find(W.vehFilter:lower()) then
                    table.insert(W.cache.vehicles[modelType], model)
                else
                    local configs = {}
                    for _, config in ipairs(model.configs) do
                        if config.label:lower():find(W.vehFilter:lower()) then
                            table.insert(configs, config)
                        end
                    end
                    if #configs > 0 then
                        local modelCopy = table.clone(model)
                        modelCopy.configs = configs
                        table.insert(W.cache.vehicles[modelType], modelCopy)
                    end
                end
            end
        end
    end
end

local function updateCacheLabels()
    W.labels.previousVeh = BJI.Managers.Lang.get("vehicleSelector.previousVeh")
    W.labels.setAsDefault = BJI.Managers.Lang.get("vehicleSelector.setAsDefault")
    W.labels.loadDefault = BJI.Managers.Lang.get("vehicleSelector.defaultVeh")
    W.labels.cloneCurrent = BJI.Managers.Lang.get("vehicleSelector.cloneCurrent")
    W.labels.resetAll = BJI.Managers.Lang.get("vehicleSelector.resetAll")
    W.labels.removeCurrent = BJI.Managers.Lang.get("vehicleSelector.deleteCurrent")
    W.labels.removeOthers = BJI.Managers.Lang.get("vehicleSelector.deleteOthers")
    W.labels.noVeh = BJI.Managers.Lang.get("vehicleSelector.noVeh")
    W.labels.notAllowed = BJI.Managers.Lang.get("vehicleSelector.notAllowed")
    W.labels.protectedVehicle = BJI.Managers.Lang.get("vehicleSelector.protectedVehicle")
    W.labels.invalidVeh = BJI.Managers.Lang.get("vehicleSelector.invalidVeh")

    W.labels.openVehSelector = BJI.Managers.Lang.get("vehicleSelector.openVehSelector")
    W.labels.remove = BJI.Managers.Lang.get("common.buttons.remove")
    W.labels.show = BJI.Managers.Lang.get("common.buttons.show")
    W.labels.spawn = BJI.Managers.Lang.get("common.buttons.spawn")
    W.labels.replace = BJI.Managers.Lang.get("common.buttons.replace")
    W.labels.random = BJI.Managers.Lang.get("common.random")
    W.labels.applyPaint = BJI.Managers.Lang.get("vehicleSelector.applyPaint")
    W.labels.close = BJI.Managers.Lang.get("common.buttons.close")

    W.labels.cars = BJI.Managers.Lang.get("vehicleSelector.cars")
    W.labels.trucks = BJI.Managers.Lang.get("vehicleSelector.trucks")
    W.labels.trailers = BJI.Managers.Lang.get("vehicleSelector.trailers")
    W.labels.props = BJI.Managers.Lang.get("vehicleSelector.props")
    W.labels.paints = BJI.Managers.Lang.get("vehicleSelector.paints")
end

---@param ctxt? TickContext
local function updateCachePaints(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    W.cache.paints = Table()

    if ctxt.isOwner then
        W.cache.paints = type(ctxt.veh) == "userdata" and
            table.map(BJI.Managers.Veh.getAllPaintsForModel(ctxt.veh.jbeam),
                function(paintData, paintLabel)
                    return {
                        label = paintLabel,
                        paint = paintData,
                    }
                end):values() or Table()
        table.sort(W.cache.paints, function(a, b)
            return a.label < b.label
        end)
    end
end

local function isValidVeh(model)
    return not table.includes({ BJI.Managers.Veh.TYPES.TRAILER, BJI.Managers.Veh.TYPES.PROP },
        BJI.Managers.Veh.getType(model))
end

local function isVehicleInCache(model)
    return Table({ W.models.cars, W.models.trucks })
        :any(function(models)
            return Table(models):any(function(m) return m.key == model end)
        end)
end

---@param ctxt? TickContext
local function updateButtonsStates(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    local canSpawnOrReplace = BJI.Managers.Perm.canSpawnVehicle() and
        (ctxt.group.vehicleCap == -1 or (not ctxt.isOwner and table.length(ctxt.user.vehicles) < ctxt.group.vehicleCap)) and
        (ctxt.isOwner and BJI.Managers.Scenario.canReplaceVehicle() or BJI.Managers.Scenario.canSpawnNewVehicle())

    local currentVehIsProtected = ctxt.veh and not ctxt.isOwner and BJI.Managers.Veh.isVehProtected(ctxt.veh:getID())

    W.headerBtns.loadPreviousDisabled = not canSpawnOrReplace or not ctxt.user.previousVehConfig or
        not isVehicleInCache(ctxt.user.previousVehConfig.model)
    if W.headerBtns.loadPreviousDisabled then
        if not canSpawnOrReplace then
            W.headerBtns.loadPreviousTooltip = W.labels.notAllowed
        elseif not ctxt.user.previousVehConfig then
            W.headerBtns.loadPreviousTooltip = W.labels.noVeh
        else
            W.headerBtns.loadPreviousTooltip = W.labels.invalidVeh
        end
    else
        W.headerBtns.loadPreviousTooltip = nil
    end

    W.headerBtns.setAsDefaultDisabled = not ctxt.veh or currentVehIsProtected or not isValidVeh(ctxt.veh.jbeam)
    if W.headerBtns.setAsDefaultDisabled then
        if not ctxt.veh then
            W.headerBtns.setAsDefaultTooltip = W.labels.noVeh
        elseif currentVehIsProtected then
            W.headerBtns.setAsDefaultTooltip = W.labels.protectedVehicle
        else
            W.headerBtns.setAsDefaultTooltip = W.labels.invalidVeh
        end
    else
        W.headerBtns.setAsDefaultTooltip = nil
    end

    local defaultVeh = BJI.Managers.Veh.getDefaultModelAndConfig()
    W.headerBtns.loadDefaultDisabled = not defaultVeh or not canSpawnOrReplace or
        not isVehicleInCache(defaultVeh.model)
    if W.headerBtns.loadDefaultDisabled then
        if not defaultVeh then
            W.headerBtns.loadDefaultTooltip = W.labels.noVeh
        elseif not canSpawnOrReplace then
            W.headerBtns.loadDefaultTooltip = W.labels.notAllowed
        else
            W.headerBtns.loadDefaultTooltip = W.labels.invalidVeh
        end
    elseif defaultVeh then
        W.headerBtns.loadDefaultTooltip = BJI.Managers.Veh.getModelLabel(defaultVeh.model)
    end

    W.headerBtns.cloneCurrentDisabled = not ctxt.veh or not canSpawnOrReplace or currentVehIsProtected
    if W.headerBtns.cloneCurrentDisabled then
        if not ctxt.veh then
            W.headerBtns.cloneCurrentTooltip = W.labels.noVeh
        elseif not canSpawnOrReplace then
            W.headerBtns.cloneCurrentTooltip = W.labels.notAllowed
        else
            W.headerBtns.cloneCurrentTooltip = W.labels.protectedVehicle
        end
    else
        W.headerBtns.cloneCurrentTooltip = nil
    end

    W.headerBtns.resetAllDisabled = BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.RESET.HEAVY_RELOAD)
    if W.headerBtns.resetAllDisabled then
        W.headerBtns.resetAllTooltip = W.labels.notAllowed
    else
        W.headerBtns.resetAllTooltip = nil
    end

    if ctxt.isOwner then
        W.headerBtns.removeCurrentDisabled = not BJI.Managers.Scenario.canDeleteVehicle()
        if W.headerBtns.removeCurrentDisabled then
            W.headerBtns.removeCurrentTooltip = W.labels.notAllowed
        end
    else
        W.headerBtns.removeCurrentDisabled = not ctxt.veh or not BJI.Managers.Scenario.canDeleteOtherPlayersVehicle()
        if W.headerBtns.removeCurrentDisabled then
            if not ctxt.veh then
                W.headerBtns.removeCurrentTooltip = W.labels.noVeh
            else
                W.headerBtns.removeCurrentTooltip = W.labels.notAllowed
            end
        end
    end
    if not W.headerBtns.removeCurrentDisabled then
        W.headerBtns.removeCurrentTooltip = nil
    end

    W.headerBtns.removeOthersDisabled = table.length(ctxt.user.vehicles) <= (ctxt.isOwner and 1 or 0) or
        not BJI.Managers.Scenario.canDeleteOtherVehicles()
    if W.headerBtns.removeOthersDisabled then
        if not BJI.Managers.Scenario.canDeleteOtherVehicles() then
            W.headerBtns.removeOthersTooltip = W.labels.notAllowed
        else
            W.headerBtns.removeOthersTooltip = W.labels.noVeh
        end
    else
        W.headerBtns.removeOthersTooltip = nil
    end
end

---@param ctxt TickContext
local function drawHeader(ctxt)
    LineBuilder():btn({
        id = "loadPrevious",
        label = W.labels.previousVeh,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = W.headerBtns.loadPreviousDisabled,
        tooltip = W.headerBtns.loadPreviousTooltip,
        onClick = function()
            BJI.Managers.Scenario.tryReplaceOrSpawn(ctxt.user.previousVehConfig.model, ctxt.user.previousVehConfig)
            extensions.hook("trackNewVeh")
        end,
    }):build()

    LineBuilder():btn({
        id = "setAsDefault",
        label = W.labels.setAsDefault,
        disabled = W.headerBtns.setAsDefaultDisabled,
        tooltip = W.headerBtns.setAsDefaultTooltip,
        onClick = function()
            core_vehicle_partmgmt.savedefault();
            -- todo add listener on this game action
        end,
    }):btn({
        id = "loadDefault",
        label = W.labels.loadDefault,
        disabled = W.headerBtns.loadDefaultDisabled,
        tooltip = W.headerBtns.loadDefaultTooltip,
        onClick = function()
            local defaultVeh = BJI.Managers.Veh.getDefaultModelAndConfig()
            if defaultVeh then
                BJI.Managers.Scenario.tryReplaceOrSpawn(defaultVeh.model, defaultVeh.config)
                extensions.hook("trackNewVeh")
            end
        end,
    }):btn({
        id = "cloneCurrent",
        label = W.labels.cloneCurrent,
        disabled = W.headerBtns.cloneCurrentDisabled,
        tooltip = W.headerBtns.cloneCurrentTooltip,
        onClick = function()
            BJI.Managers.Scenario.trySpawnNew(ctxt.veh.jbeam, ctxt.veh.partConfig)
            extensions.hook("trackNewVeh")
        end,
    }):build()

    LineBuilder():btn({
        id = "resetAll",
        label = W.labels.resetAll,
        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
        disabled = W.headerBtns.resetAllDisabled,
        tooltip = W.headerBtns.resetAllTooltip,
        onClick = function()
            resetGameplay(-1)
        end,
    }):btn({
        id = "removeCurrent",
        label = W.labels.removeCurrent,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        disabled = W.headerBtns.removeCurrentDisabled,
        tooltip = W.headerBtns.removeCurrentTooltip,
        onClick = function()
            if ctxt.isOwner then
                BJI.Managers.Veh.deleteCurrentOwnVehicle()
            else
                BJI.Managers.Popup.createModal(BJI.Managers.Lang.get("vehicleSelector.deleteOtherPlayerVehicleModal"), {
                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"), function()
                        BJI.Managers.Veh.deleteOtherPlayerVehicle()
                        extensions.hook("trackNewVeh")
                    end),
                })
            end
        end,
    }):btn({
        id = "deleteOthers",
        label = W.labels.removeOthers,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        disabled = W.headerBtns.removeOthersDisabled,
        tooltip = W.headerBtns.removeOthersTooltip,
        onClick = function()
            BJI.Managers.Veh.deleteOtherOwnVehicles()
            extensions.hook("trackNewVeh")
        end,
    }):build()

    -- filter line
    if #W.models.cars + #W.models.trucks +
        #W.models.trailers + #W.models.props > 0 then
        Separator()
        local line = LineBuilder()
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.VEHICLE_SELECTOR) then
            line:btnIcon({
                id = "openVehSelectorUI",
                icon = ICONS.open_in_new,
                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                tooltip = W.labels.openVehSelector,
                onClick = function()
                    if W.onClose then
                        BJI.Windows.VehSelector.tryClose()
                    end
                    core_vehicles.openSelectorUI()
                end,
            })
        end
        if #W.vehFilter == 0 then
            line:icon({
                icon = ICONS.ab_filter_default,
            })
        else
            line:btnIcon({
                id = "removeVehFilter",
                icon = ICONS.ab_filter_default,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                coloredIcon = true,
                tooltip = W.labels.remove,
                onClick = function()
                    W.vehFilter = ""
                    updateCacheVehicles()
                end,
            })
        end
        line:inputString({
            id = "vehFilter",
            value = W.vehFilter,
            onUpdate = function(val)
                W.vehFilter = val
                updateCacheVehicles()
            end
        }):build()
    end
end

---@param modelKey string
---@param config { key: string, label: string, custom?: boolean }
local function drawConfig(modelKey, config)
    local line = LineBuilder()
    if not limitReached then
        line:btnIcon({
            id = string.var("spawnNew-{1}-{2}", { modelKey, config.key }),
            icon = ICONS.add,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            tooltip = W.labels.spawn,
            onClick = function()
                BJI.Managers.Scenario.trySpawnNew(modelKey, config.key)
            end
        })
    end
    if ownVeh then
        if not line then
            line = LineBuilder()
        end
        line:btnIcon({
            id = string.var("replace-{1}-{2}", { modelKey, config.key }),
            icon = ICONS.carSensors,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            tooltip = W.labels.replace,
            onClick = function()
                BJI.Managers.Scenario.tryReplaceOrSpawn(modelKey, config.key)
            end
        })
    end
    line:text(config.label,
        config.custom and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :build()
end

---@param model { key: string, preview: string, label: string, custom?: boolean, configs: { key: string, label: string, custom?: boolean }[] }
local function drawModel(model)
    local function drawModelButtons(line, withSpawn)
        line:btnIcon({
            id = string.var("preview-{1}", { model.key }),
            icon = ICONS.ab_asset_image,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            tooltip = W.labels.show,
            onClick = function()
                BJI.Windows.VehSelectorPreview.open(model.preview)
            end,
        })
        if withSpawn then
            if not limitReached then
                line:btnIcon({
                    id = string.var("spawnNew-{1}", { model.key }),
                    icon = ICONS.add,
                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    tooltip = W.labels.spawn,
                    onClick = function()
                        BJI.Managers.Scenario.trySpawnNew(model.key, #model.configs == 1 and model.configs[1].key or nil)
                    end
                })
            end
            if ownVeh then
                line:btnIcon({
                    id = string.var("replace-{1}", { model.key }),
                    icon = ICONS.carSensors,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    tooltip = W.labels.replace,
                    onClick = function()
                        BJI.Managers.Scenario.tryReplaceOrSpawn(model.key,
                            #model.configs == 1 and model.configs[1].key or nil)
                    end
                })
            end
        end
        if #model.configs > 1 and (ownVeh or not limitReached) then
            line:btnIcon({
                id = string.var("spawnRandom-{1}", { model.key }),
                icon = ICONS.casino,
                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                tooltip = W.labels.random,
                onClick = function()
                    local config = table.random(model.configs) or {}
                    BJI.Managers.Scenario.tryReplaceOrSpawn(model.key, config.key)
                end
            })
        end
    end

    local drawModelTitle = function(line)
        return line:text(model.label,
            model.custom and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
    end

    local function drawModelConfigs()
        for _, config in ipairs(model.configs) do
            drawConfig(model.key, config)
        end
    end

    if #model.configs == 0 then
        return
    elseif #model.configs == 1 then
        -- compacted model-config (only 1 line)
        Indent(1)
        local line = LineBuilder():text("")
        drawModelButtons(line, true)
        drawModelTitle(line):build()
        local config = model.configs[1]
        line:text(string.var("({1})", { config.label }))
            :build()
        Indent(-1)
    elseif #model.configs < ACCORDION_THRESHOLD then
        local line = LineBuilder()
        drawModelButtons(line, false)
        drawModelTitle(line):build()
        Indent(2)
        drawModelConfigs()
        Indent(-2)
    else
        AccordionBuilder()
            :label(string.var("##{1}", { model.key }))
            :openedBehavior(function()
                local line = LineBuilder(true)
                drawModelButtons(line, false)
                drawModelTitle(line):build()
                drawModelConfigs()
            end)
            :closedBehavior(function()
                local line = LineBuilder(true)
                drawModelButtons(line, true)
                drawModelTitle(line):build()
            end)
            :build()
    end
end

---@param vehs table[]
---@param label string
---@param name string
---@param icon string
local function drawType(vehs, label, name, icon)
    if #vehs > 0 then
        local function drawTitle(inAccordion)
            local line = LineBuilder(inAccordion)
            if not inAccordion then
                line:text(label)
            end
            if icon then
                line:icon({
                    icon = icon,
                })
            end
            if #vehs > 0 then
                line:btnIcon({
                    id = string.var("random-{1}", { name }),
                    icon = ICONS.casino,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    tooltip = W.labels.random,
                    onClick = function()
                        local model = table.random(vehs) or {}
                        local config = table.random(model.configs) or {}

                        if model.key and config.key then
                            BJI.Managers.Scenario.tryReplaceOrSpawn(model.key, config.key)
                        end
                    end
                })
            end
            line:build()
        end

        local function drawModels()
            for _, model in ipairs(vehs) do
                drawModel(model)
            end
        end

        if #vehs == 0 then
            drawTitle(false)
            LineBuilder(true)
                :text("No match ...")
                :build()
        elseif #vehs < ACCORDION_THRESHOLD then
            drawTitle(false)
            Indent(2)
            drawModels()
            Indent(-2)
        else
            AccordionBuilder()
                :label(label)
                :commonStart(function()
                    drawTitle(true)
                end)
                :openedBehavior(drawModels)
                :build()
        end
    end
end

---@param baseColor number[]
local function paintToIconStyle(baseColor)
    local im = ui_imgui
    local contrasted = baseColor[1] + baseColor[2] + baseColor[3] > 1.5 and 0 or 1
    local converted = im.ImVec4(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1.2)
    return {
        converted,
        converted,
        converted,
        im.ImVec4(contrasted, contrasted, contrasted, 1),
    }
end

---@param paints { label: string, paint: { baseColor: number[] } }[]
local function drawPaints(paints)
    if not BJI.Managers.Veh.isCurrentVehicleOwn() then
        return
    end

    for i, paintData in ipairs(paints) do
        local line = LineBuilder()
        for j = 1, 3 do
            local style = paintToIconStyle(paintData.paint.baseColor)
            line:btnIcon({
                id = string.var("applyPaint-{1}-{2}", { i, j }),
                icon = ICONS.format_color_fill,
                style = style,
                tooltip = W.labels.applyPaint:var({ position = j }),
                onClick = function()
                    BJI.Managers.Scenario.tryPaint(paintData.paint, j)
                end
            })
        end
        line:text(paintData.label)
            :build()
    end
end

---@param ctxt TickContext
local function drawBody(ctxt)
    ownVeh = ctxt.isOwner
    limitReached = ctxt.group.vehicleCap > -1 and ctxt.group.vehicleCap <= table.length(ctxt.user.vehicles)

    local vehsDrew = false

    if W.cache.vehicles.cars then
        drawType(W.cache.vehicles.cars, W.labels.cars, "car", ICONS.fg_vehicle_suv)
        vehsDrew = true
    end

    if W.cache.vehicles.trucks then
        drawType(W.cache.vehicles.trucks, W.labels.trucks, "truck", ICONS.fg_vehicle_truck)
        vehsDrew = true
    end

    if W.cache.vehicles.trailers then
        drawType(W.cache.vehicles.trailers, W.labels.trailers, "trailer", ICONS.fg_vehicle_tanker_trailer)
        vehsDrew = true
    end

    if W.cache.vehicles.props then
        drawType(W.cache.vehicles.props, W.labels.props, "prop", ICONS.fg_traffic_cone)
        vehsDrew = true
    end

    local veh = BJI.Managers.Veh.getCurrentVehicleOwn()
    -- must get a new instance of current vehicle or else crash
    if #W.cache.paints > 0 then
        if vehsDrew then
            Separator()
        end

        AccordionBuilder()
            :label(BJI.Managers.Lang.get("vehicleSelector.paints"))
            :commonStart(function()
                LineBuilder(true)
                    :icon({
                        icon = ICONS.style,
                    })
                    :build()
            end)
            :openedBehavior(
                function()
                    drawPaints(W.cache.paints)
                end)
            :build()
    end
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    if W.onClose then
        LineBuilder()
            :btnIcon({
                id = "closeVehicleSelector",
                icon = ICONS.exit_to_app,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                tooltip = W.labels.close,
                onClick = W.onClose,
            })
            :build()
    end
end

local function getFooterLines()
    return W.onClose and 1 or 0
end

---@param state? boolean
local function updateOnClose(state)
    if state and not W.onClose then
        W.onClose = function()
            BJI.Windows.VehSelectorPreview.onClose()
            W.show = false
            W.models = {
                cars = {},
                trucks = {},
                trailers = {},
                props = {},
            }
            W.cache = {
                vehicles = {},
                paints = {},
            }
        end
    elseif not state and W.onClose then
        W.onClose = nil
    end
end

---@param canClose? boolean
local function open(canClose)
    updateOnClose(canClose)
    W.show = true
end

local function tryClose(force)
    if W.onClose then
        W.onClose()
    elseif force then
        updateOnClose(true)
        W.onClose()
    end
end

local function updateBaseModels()
    ---@type table<string, table>
    local models = BJI.Managers.Scenario.getModelList()

    if type(models) ~= "table" then
        -- autoclose
        W.show = false
        return
    end

    local function sortByLabel(arr)
        table.sort(arr, function(a, b)
            return a.label < b.label
        end)
    end

    local function parseConfigs(arr, index)
        local res = {}
        for _, config in pairs(arr[index].configs) do
            table.insert(res, {
                key = config.key,
                label = config.label,
                custom = config.custom,
            })
        end
        sortByLabel(res)
        arr[index] = {
            key = arr[index].key,
            label = arr[index].label,
            custom = arr[index].custom,
            configs = res,
            preview = arr[index].preview,
        }
    end

    local cars, trucks, trailers, props = {}, {}, {}, {}
    for _, model in pairs(models) do
        if model.Type == "Truck" then
            table.insert(trucks, model)
            parseConfigs(trucks, #trucks)
        elseif model.Type == "Trailer" then
            table.insert(trailers, model)
            parseConfigs(trailers, #trailers)
        elseif model.Type == "Prop" then
            table.insert(props, model)
            parseConfigs(props, #props)
        else -- "Car" or other
            table.insert(cars, model)
            parseConfigs(cars, #cars)
        end
    end
    sortByLabel(cars)
    sortByLabel(trucks)
    sortByLabel(trailers)
    sortByLabel(props)

    W.models.cars = cars
    W.models.trucks = trucks
    W.models.trailers = trailers
    W.models.props = props

    W.cache = {
        vehicles = {},
        paints = {},
    }
    updateCacheVehicles()
end

local listeners = Table()
local function onLoad()
    updateBaseModels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CONFIG_SAVED,
        BJI.Managers.Events.EVENTS.CONFIG_REMOVED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateBaseModels, W.name .. "Models"))

    updateCacheLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateCacheLabels()
        updateButtonsStates(ctxt)
    end, W.name .. "Labels"))

    updateCachePaints()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.VEHICLE_REMOVED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCachePaints, W.name .. "Paints"))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function()
            if not BJI.Managers.Perm.canSpawnVehicle() then
                tryClose(true)
            end
        end, W.name .. "AutoClose"))

    updateButtonsStates()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.VEHICLE_REMOVED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateButtonsStates, W.name .. "ButtonsStates"))
end
local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

W.onLoad = onLoad
W.onUnload = onUnload

W.header = drawHeader
W.body = drawBody
W.footer = drawFooter
W.getFooterLines = getFooterLines
-- M.onClose -- dynamically generated
W.getState = function()
    return W.show and BJI.Managers.Perm.canSpawnVehicle()
end

W.open = open
W.tryClose = tryClose

return W
