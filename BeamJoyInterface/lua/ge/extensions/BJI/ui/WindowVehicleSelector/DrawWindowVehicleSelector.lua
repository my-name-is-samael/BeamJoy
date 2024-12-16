local ACCORDION_THRESHOLD = 2
local M = {
    state = false,
    models = {
        cars = {},
        trucks = {},
        trailers = {},
        props = {},
    },
    sumConfigs = 0,
    vehFilter = "",
    filtered = nil,
    paints = {},
}
local ownVeh, limitReached = false, false

local function updateFiltered()
    M.filtered = {}
    if #M.vehFilter == 0 then
        M.filtered = M.models
    else
        for modelType, models in pairs(M.models) do
            M.filtered[modelType] = {}
            for _, model in ipairs(models) do
                if model.label:lower():find(M.vehFilter:lower()) then
                    table.insert(M.filtered[modelType], model)
                else
                    local configs = {}
                    for _, config in ipairs(model.configs) do
                        if config.label:lower():find(M.vehFilter:lower()) then
                            table.insert(configs, config)
                        end
                    end
                    if #configs > 0 then
                        local modelCopy = tdeepcopy(model)
                        modelCopy.configs = configs
                        table.insert(M.filtered[modelType], modelCopy)
                    end
                end
            end
        end
    end
end

local function drawHeader(ctxt)
    if M.sumConfigs > 0 then
        local line = LineBuilder()
        if M.onClose then
            line:btnIcon({
                id = "openVehSelectorUI",
                icon = ICONS.open_in_new,
                style = BTN_PRESETS.INFO,
                onClick = function()
                    BJIVehSelector.tryClose()
                    core_vehicles.openSelectorUI()
                end,
            })
        end
        line:icon({
            icon = ICONS.ab_filter_default,
        })
            :inputString({
                id = "vehFilter",
                value = M.vehFilter,
                onUpdate = function(val)
                    M.vehFilter = val
                    updateFiltered()
                end
            })
            :build()
    end

    local showDeleteCurrent = ctxt.isOwner and BJIScenario.canDeleteVehicle()
    local showDeleteOtherPlayerVehicle = not ctxt.isOwner and ctxt.veh and
        BJIScenario.canDeleteOtherPlayersVehicle()
    local showDeleteOthers = BJIScenario.canDeleteOtherVehicles() and
        tlength(BJIContext.User.vehicles) > (ctxt.isOwner and 1 or 0)

    if showDeleteCurrent or showDeleteOtherPlayerVehicle or showDeleteOthers then
        local line = LineBuilder()
        if showDeleteCurrent then
            line:btn({
                id = "deleteCurrent",
                label = BJILang.get("vehicleSelector.deleteCurrent"),
                style = BTN_PRESETS.ERROR,
                onClick = function()
                    BJIVeh.deleteCurrentOwnVehicle()
                end,
            })
        end
        if showDeleteOtherPlayerVehicle then
            line:btn({
                id = "deleteOtherPlayerVehicle",
                label = BJILang.get("vehicleSelector.deleteOtherPlayerVehicle"),
                style = BTN_PRESETS.ERROR,
                onClick = function()
                    BJIVeh.deleteOtherPlayerVehicle()
                end,
            })
        end
        if showDeleteOthers then
            line:btn({
                id = "deleteOthers",
                label = BJILang.get("vehicleSelector.deleteOthers"),
                style = BTN_PRESETS.ERROR,
                onClick = function()
                    BJIVeh.deleteOtherOwnVehicles()
                end,
            })
        end
        line:build()
    end
end

local function drawConfig(modelKey, config)
    local line = LineBuilder()
    if not limitReached then
        line:btnIcon({
            id = svar("spawnNew-{1}-{2}", { modelKey, config.key }),
            icon = ICONS.add,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                BJIScenario.trySpawnNew(modelKey, config.key)
            end
        })
    end
    if ownVeh then
        if not line then
            line = LineBuilder()
        end
        line:btnIcon({
            id = svar("replace-{1}-{2}", { modelKey, config.key }),
            icon = ICONS.carSensors,
            style = BTN_PRESETS.WARNING,
            onClick = function()
                BJIScenario.tryReplaceOrSpawn(modelKey, config.key)
            end
        })
    end
    line:text(config.label, config.custom and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
        :build()
end

local function drawModel(model)
    local function drawModelButtons(line, withSpawn)
        line:btnIcon({
            id = svar("preview-{1}", { model.key }),
            icon = ICONS.ab_asset_image,
            style = BTN_PRESETS.INFO,
            onClick = function()
                BJIVehSelectorPreview.open(model.preview)
            end,
        })
        if withSpawn then
            if not limitReached then
                line:btnIcon({
                    id = svar("spawnNew-{1}", { model.key }),
                    icon = ICONS.add,
                    style = BTN_PRESETS.SUCCESS,
                    onClick = function()
                        BJIScenario.trySpawnNew(model.key)
                    end
                })
            end
            if ownVeh then
                line:btnIcon({
                    id = svar("replace-{1}", { model.key }),
                    icon = ICONS.carSensors,
                    style = BTN_PRESETS.WARNING,
                    onClick = function()
                        BJIScenario.tryReplaceOrSpawn(model.key)
                    end
                })
            end
        end
        if #model.configs > 1 and (ownVeh or not limitReached) then
            line:btnIcon({
                id = svar("spawnRandom-{1}", { model.key }),
                icon = ICONS.casino,
                style = BTN_PRESETS.WARNING,
                onClick = function()
                    local config = trandom(model.configs) or {}
                    BJIScenario.tryReplaceOrSpawn(model.key, config.key)
                end
            })
        end
    end

    local drawModelTitle = function(line)
        return line:text(model.label, model.custom and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
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
        line:text(svar("({1})", { config.label }))
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
            :label(svar("##{1}", { model.key }))
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
                    id = svar("random-{1}", { name }),
                    icon = ICONS.casino,
                    style = BTN_PRESETS.WARNING,
                    onClick = function()
                        local model = trandom(vehs) or {}
                        local config = trandom(model.configs) or {}

                        if model.key and config.key then
                            BJIScenario.tryReplaceOrSpawn(model.key, config.key)
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

local function drawPaints(paints)
    if not BJIVeh.isCurrentVehicleOwn() then
        return
    end

    for i, paintData in ipairs(paints) do
        local line = LineBuilder()
        for j = 1, 3 do
            local style = paintToIconStyle(paintData.paint.baseColor)
            line:btnIcon({
                id = svar("applyPaint-{1}-{2}", { i, j }),
                icon = ICONS.format_color_fill,
                style = style,
                onClick = function()
                    BJIScenario.tryPaint(paintData.paint, i)
                end
            })
        end
        line:text(paintData.label)
            :build()
    end
end

local function drawPreviousVeh(ctxt)
    local previousConfig = BJIContext.User.previousVehConfig
    local previousIncluded = false
    if previousConfig then
        for _, model in ipairs(M.models.cars) do
            if model.key == previousConfig.model then
                previousIncluded = true
                break
            end
        end
        if not previousIncluded then
            for _, model in ipairs(M.models.trucks) do
                if model.key == previousConfig.model then
                    previousIncluded = true
                    break
                end
            end
        end
    end
    if previousConfig and previousIncluded then
        local modelLabel = BJIVeh.getModelLabel(previousConfig.model)
        local line = LineBuilder()
        if not limitReached then
            line:btnIcon({
                id = svar("spawnNewPrevious-{1}-{2}", { previousConfig.model, previousConfig }),
                icon = ICONS.add,
                style = BTN_PRESETS.SUCCESS,
                onClick = function()
                    BJIScenario.trySpawnNew(previousConfig.model, previousConfig)
                end
            })
        end
        if ownVeh then
            line:btnIcon({
                id = svar("replacePrevious-{1}-{2}", { previousConfig.model, previousConfig }),
                icon = ICONS.carSensors,
                style = BTN_PRESETS.WARNING,
                onClick = function()
                    BJIScenario.tryReplaceOrSpawn(previousConfig.model, previousConfig)
                end
            })
        end
        line:text(svar("{1}:", { BJILang.get("vehicleSelector.previousVeh") }))
            :text(modelLabel)
            :build()
    end
end

local function drawDefaultVeh(ctxt)
    local defaultVeh = BJIVeh.getDefaultModelAndConfig()
    local defaultIncluded = false
    if defaultVeh then
        for _, model in ipairs(M.models.cars) do
            if model.key == defaultVeh.model then
                defaultIncluded = true
                break
            end
        end
        if not defaultIncluded then
            for _, model in ipairs(M.models.trucks) do
                if model.key == defaultVeh.model then
                    defaultIncluded = true
                    break
                end
            end
        end
    end
    if defaultVeh and defaultIncluded then
        local modelLabel = BJIVeh.getModelLabel(defaultVeh.model)
        local line = LineBuilder()
        if not limitReached then
            line:btnIcon({
                id = svar("spawnNewDefault-{1}-{2}", { defaultVeh.model, defaultVeh.config }),
                icon = ICONS.add,
                style = BTN_PRESETS.SUCCESS,
                onClick = function()
                    BJIScenario.trySpawnNew(defaultVeh.model, defaultVeh.config)
                end
            })
        end
        if ownVeh then
            line:btnIcon({
                id = svar("replaceDefault-{1}-{2}", { defaultVeh.model, defaultVeh.config }),
                icon = ICONS.carSensors,
                style = BTN_PRESETS.WARNING,
                onClick = function()
                    BJIScenario.tryReplaceOrSpawn(defaultVeh.model, defaultVeh.config)
                end
            })
        end
        line:text(svar("{1}:", { BJILang.get("vehicleSelector.defaultVeh") }))
            :text(modelLabel)
            :build()
    end
end

local function drawBody(ctxt)
    ownVeh = ctxt.isOwner
    limitReached = ctxt.group.vehicleCap > -1 and ctxt.group.vehicleCap <= tlength(ctxt.user.vehicles)

    drawPreviousVeh(ctxt)
    drawDefaultVeh(ctxt)

    if M.filtered.cars then
        drawType(M.filtered.cars, "Cars", "car", ICONS.fg_vehicle_suv)
    end

    if M.filtered.trucks then
        drawType(M.filtered.trucks, "Trucks", "truck", ICONS.fg_vehicle_truck)
    end

    if M.filtered.trailers then
        drawType(M.filtered.trailers, "Trailers", "trailer", ICONS.fg_vehicle_tanker_trailer)
    end

    if M.filtered.props then
        drawType(M.filtered.props, "Props", "prop", ICONS.fg_traffic_cone)
    end

    local veh = BJIVeh.getCurrentVehicleOwn()
    -- must get a new instance of current vehicle or else crash
    if veh and veh.jbeam and
        M.paints[veh.jbeam] and
        #M.paints[veh.jbeam] > 0 then
        AccordionBuilder()
            :label(BJILang.get("vehicleSelector.paints"))
            :commonStart(function()
                LineBuilder(true)
                    :icon({
                        icon = ICONS.style,
                    })
                    :build()
            end)
            :openedBehavior(
                function()
                    drawPaints(M.paints[ctxt.veh.jbeam])
                end)
            :build()
    end
end

local function drawFooter(ctxt)
    if M.onClose then
        LineBuilder()
            :btnIcon({
                id = "closeVehicleSelector",
                icon = ICONS.exit_to_app,
                style = BTN_PRESETS.ERROR,
                onClick = M.onClose,
            })
            :build()
    end
end

local function getFooterLines()
    return M.onClose and 1 or 0
end

local function updateOnClose(state)
    if state and not M.onClose then
        M.onClose = function()
            BJIVehSelectorPreview.onClose()
            M.state = false
            M.models = {
                cars = {},
                trucks = {},
                trailers = {},
                props = {},
            }
            M.sumConfigs = 0
            M.vehFilter = ""
            M.filtered = nil
            M.paints = {}
        end
    elseif not state and M.onClose then
        M.onClose = nil
    end
end

--[[
<ul>
    <li>models: array</li>
    <li>canClose: boolean NULLABLE</li>
</ul>
]]
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
    M.models.cars = cars
    M.models.trucks = trucks
    M.models.trailers = trailers
    M.models.props = props

    for model, modelData in pairs(BJIVeh.getAllVehicleConfigs(true, true)) do
        M.paints[model] = {}
        for paintLabel, paintData in pairs(modelData.paints) do
            table.insert(M.paints[model], {
                label = paintLabel,
                paint = paintData,
            })
        end
        table.sort(M.paints[model], function(a, b)
            return a.label < b.label
        end)
    end

    M.sumConfigs = 0
    for _, typeModels in pairs(M.models) do
        for _, model in pairs(typeModels) do
            M.sumConfigs = M.sumConfigs + #model.configs
        end
    end

    M.filtered = {}
    updateFiltered()

    M.state = true
end

local function tryClose(force)
    if M.onClose then
        M.onClose()
    elseif force then
        updateOnClose(true)
        M.onClose()
    end
end

M.header = drawHeader
M.body = drawBody
M.footer = drawFooter
M.getFooterLines = getFooterLines
-- M.onClose -- dynamically generated

M.open = open
M.tryClose = tryClose

return M
