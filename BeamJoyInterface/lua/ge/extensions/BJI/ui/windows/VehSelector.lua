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
        deleteCurrentBtn = "",
        deleteOtherPlayerVehicleBtn = "",
        deleteOthers = "",
        previousVeh = "",
        defaultVeh = "",
        cars = "",
        trucks = "",
        trailers = "",
        props = "",
        paints = "",
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
    W.labels.deleteCurrentBtn = BJI.Managers.Lang.get("vehicleSelector.deleteCurrent")
    W.labels.deleteOtherPlayerVehicleBtn = BJI.Managers.Lang.get("vehicleSelector.deleteOtherPlayerVehicle")
    W.labels.deleteOthers = BJI.Managers.Lang.get("vehicleSelector.deleteOthers")
    W.labels.previousVeh = string.var("{1}:", { BJI.Managers.Lang.get("vehicleSelector.previousVeh") })
    W.labels.defaultVeh = string.var("{1}:", { BJI.Managers.Lang.get("vehicleSelector.defaultVeh") })
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

---@param ctxt TickContext
local function drawHeader(ctxt)
    if #W.models.cars + #W.models.trucks +
        #W.models.trailers + #W.models.props > 0 then
        local line = LineBuilder()
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.VEHICLE_SELECTOR) then
            line:btnIcon({
                id = "openVehSelectorUI",
                icon = ICONS.open_in_new,
                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                onClick = function()
                    if W.onClose then
                        BJI.Windows.VehSelector.tryClose()
                    end
                    core_vehicles.openSelectorUI()
                end,
            })
        end
        line:icon({
            icon = ICONS.ab_filter_default,
        })
            :inputString({
                id = "vehFilter",
                value = W.vehFilter,
                onUpdate = function(val)
                    W.vehFilter = val
                    updateCacheVehicles()
                end
            })
            :build()
    end

    local showDeleteCurrent = ctxt.isOwner and BJI.Managers.Scenario.canDeleteVehicle()
    local showDeleteOtherPlayerVehicle = not ctxt.isOwner and ctxt.veh and
        BJI.Managers.Scenario.canDeleteOtherPlayersVehicle()
    local showDeleteOthers = BJI.Managers.Scenario.canDeleteOtherVehicles() and
        table.length(BJI.Managers.Context.User.vehicles) > (ctxt.isOwner and 1 or 0)

    if showDeleteCurrent or showDeleteOtherPlayerVehicle or showDeleteOthers then
        local line = LineBuilder()
        if showDeleteCurrent then
            line:btn({
                id = "deleteCurrent",
                label = W.labels.deleteCurrentBtn,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Managers.Veh.deleteCurrentOwnVehicle()
                end,
            })
        end
        if showDeleteOtherPlayerVehicle then
            line:btn({
                id = "deleteOtherPlayerVehicle",
                label = W.labels.deleteOtherPlayerVehicleBtn,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Managers.Veh.deleteOtherPlayerVehicle()
                end,
            })
        end
        if showDeleteOthers then
            line:btn({
                id = "deleteOthers",
                label = W.labels.deleteOthers,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Managers.Veh.deleteOtherOwnVehicles()
                end,
            })
        end
        line:build()
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
local function drawPreviousVeh(ctxt)
    local previousConfig = BJI.Managers.Context.User.previousVehConfig
    local previousIncluded = false
    if previousConfig then
        for _, model in ipairs(W.models.cars) do
            if model.key == previousConfig.model then
                previousIncluded = true
                break
            end
        end
        if not previousIncluded then
            for _, model in ipairs(W.models.trucks) do
                if model.key == previousConfig.model then
                    previousIncluded = true
                    break
                end
            end
        end
    end
    if previousConfig and previousIncluded then
        local modelLabel = BJI.Managers.Veh.getModelLabel(previousConfig.model)
        local line = LineBuilder()
        if not limitReached then
            line:btnIcon({
                id = string.var("spawnNewPrevious-{1}-{2}", { previousConfig.model, previousConfig }),
                icon = ICONS.add,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                onClick = function()
                    BJI.Managers.Scenario.trySpawnNew(previousConfig.model, previousConfig)
                end
            })
        end
        if ownVeh then
            line:btnIcon({
                id = string.var("replacePrevious-{1}-{2}", { previousConfig.model, previousConfig }),
                icon = ICONS.carSensors,
                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                onClick = function()
                    BJI.Managers.Scenario.tryReplaceOrSpawn(previousConfig.model, previousConfig)
                end
            })
        end
        line:text(W.labels.previousVeh):text(modelLabel):build()
    end
end

---@param ctxt TickContext
local function drawDefaultVeh(ctxt)
    local defaultVeh = BJI.Managers.Veh.getDefaultModelAndConfig()
    local defaultIncluded = false
    if defaultVeh then
        for _, model in ipairs(W.models.cars) do
            if model.key == defaultVeh.model then
                defaultIncluded = true
                break
            end
        end
        if not defaultIncluded then
            for _, model in ipairs(W.models.trucks) do
                if model.key == defaultVeh.model then
                    defaultIncluded = true
                    break
                end
            end
        end
    end
    if defaultVeh and defaultIncluded then
        local modelLabel = BJI.Managers.Veh.getModelLabel(defaultVeh.model)
        local line = LineBuilder()
        if not limitReached then
            line:btnIcon({
                id = string.var("spawnNewDefault-{1}-{2}", { defaultVeh.model, defaultVeh.config }),
                icon = ICONS.add,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                onClick = function()
                    BJI.Managers.Scenario.trySpawnNew(defaultVeh.model, defaultVeh.config)
                end
            })
        end
        if ownVeh then
            line:btnIcon({
                id = string.var("replaceDefault-{1}-{2}", { defaultVeh.model, defaultVeh.config }),
                icon = ICONS.carSensors,
                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                onClick = function()
                    BJI.Managers.Scenario.tryReplaceOrSpawn(defaultVeh.model, defaultVeh.config)
                end
            })
        end
        line:text(W.labels.defaultVeh):text(modelLabel):build()
    end
end

---@param ctxt TickContext
local function drawBody(ctxt)
    ownVeh = ctxt.isOwner
    limitReached = ctxt.group.vehicleCap > -1 and ctxt.group.vehicleCap <= table.length(ctxt.user.vehicles)

    drawPreviousVeh(ctxt)
    drawDefaultVeh(ctxt)

    if W.cache.vehicles.cars then
        drawType(W.cache.vehicles.cars, W.labels.cars, "car", ICONS.fg_vehicle_suv)
    end

    if W.cache.vehicles.trucks then
        drawType(W.cache.vehicles.trucks, W.labels.trucks, "truck", ICONS.fg_vehicle_truck)
    end

    if W.cache.vehicles.trailers then
        drawType(W.cache.vehicles.trailers, W.labels.trailers, "trailer", ICONS.fg_vehicle_tanker_trailer)
    end

    if W.cache.vehicles.props then
        drawType(W.cache.vehicles.props, W.labels.props, "prop", ICONS.fg_traffic_cone)
    end

    local veh = BJI.Managers.Veh.getCurrentVehicleOwn()
    -- must get a new instance of current vehicle or else crash
    if #W.cache.paints > 0 then
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

---@param models table<string, table>
---@param canClose? boolean
local function open(models, canClose)
    if type(models) ~= "table" then
        LogError("Invalid data")
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

    updateOnClose(canClose)
    W.models.cars = cars
    W.models.trucks = trucks
    W.models.trailers = trailers
    W.models.props = props

    W.cache = {
        vehicles = {},
        paints = {},
    }
    updateCacheVehicles()

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

local listeners = Table()
local function onLoad()
    updateCacheLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCacheLabels))

    updateCachePaints()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.VEHICLE_REMOVED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
    }, updateCachePaints))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function()
            if not BJI.Managers.Perm.canSpawnVehicle() then
                tryClose(true)
            end
        end))
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
