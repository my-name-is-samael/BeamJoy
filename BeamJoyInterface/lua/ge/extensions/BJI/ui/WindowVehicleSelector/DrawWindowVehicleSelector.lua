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

local function waitUntil(fn)
    local targetTime = GetCurrentTimeMillis() + 1000
    guihooks.trigger("app:waiting", true)
    BJIAsync.delayTask(function()
        fn()
        if GetCurrentTimeMillis() < targetTime then
            BJIAsync.task(function(ctxt)
                return ctxt.now >= targetTime and
                        (ctxt.isOwner and BJIVeh.isVehReady(ctxt.veh:getID()))
            end, function()
                guihooks.trigger("app:waiting", false)
            end, "BJISpawnVehLoadingStop")
        else
            guihooks.trigger("app:waiting", false)
        end
    end, 300, "BJISpawnVehLoadingStart")
end

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
                background = BTN_PRESETS.INFO,
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

local function drawConfig(cols, modelKey, config)
    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(config.label,
                        config.custom and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
                    :build()
            end,
            function()
                local line
                if not limitReached then
                    if not line then
                        line = LineBuilder()
                    end
                    line:btnIcon({
                        id = svar("spawnNew-{1}-{2}", { modelKey, config.key }),
                        icon = ICONS.add,
                        background = BTN_PRESETS.SUCCESS,
                        onClick = function()
                            waitUntil(function()
                                BJIScenario.trySpawnNew(modelKey, config.key)
                            end)
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
                        background = BTN_PRESETS.WARNING,
                        onClick = function()
                            waitUntil(function()
                                BJIScenario.tryReplaceOrSpawn(modelKey, config.key)
                            end)
                        end
                    })
                end
                if line then
                    line:build()
                end
            end,
        }
    })
end

local function drawModel(model)
    local function drawModelTitle(inAccordion, opened)
        local line = LineBuilder(inAccordion)
            :text(model.label,
                model.custom and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
        if not opened then
            if not limitReached then
                line:btnIcon({
                    id = svar("spawnNew-{1}", { model.key }),
                    icon = ICONS.add,
                    background = BTN_PRESETS.SUCCESS,
                    onClick = function()
                        waitUntil(function()
                            BJIScenario.trySpawnNew(model.key)
                        end)
                    end
                })
            end
            if ownVeh then
                line:btnIcon({
                    id = svar("replace-{1}", { model.key }),
                    icon = ICONS.carSensors,
                    background = BTN_PRESETS.WARNING,
                    onClick = function()
                        waitUntil(function()
                            BJIScenario.tryReplaceOrSpawn(model.key)
                        end)
                    end
                })
            end
        end
        if #model.configs > 1 and (ownVeh or not limitReached) then
            line:btnIcon({
                id = svar("spawnRandom-{1}", { model.key }),
                icon = ICONS.casino,
                background = BTN_PRESETS.WARNING,
                onClick = function()
                    local config = trandom(model.configs) or {}
                    waitUntil(function()
                        BJIScenario.tryReplaceOrSpawn(model.key, config.key)
                    end)
                end
            })
        end
        line:btnIcon({
            id = svar("preview-{1}", { model.key }),
            icon = ICONS.ab_asset_image,
            background = BTN_PRESETS.INFO,
            onClick = function()
                BJIVehSelectorPreview.open(model.preview)
            end,
        })
            :build()
    end

    local function drawModelConfigs()
        local labelWidth = 0
        for _, config in ipairs(model.configs) do
            local w = GetColumnTextWidth(config.label)
            if w > labelWidth then
                labelWidth = w
            end
        end
        local cols = ColumnsBuilder(svar("BJIVehSelectorConfigs-{1}", { model.key }), { labelWidth, -1 })
        for _, config in ipairs(model.configs) do
            drawConfig(cols, model.key, config)
        end
        cols:build()
    end

    if #model.configs == 0 then
        return
    elseif #model.configs == 1 then
        -- compacted model-config (only 1 line)
        drawModelTitle(false, true)
        local config = model.configs[1]
        local line = LineBuilder(true)
            :text(svar("({1})", { config.label }))
        if not limitReached then
            line:btnIcon({
                id = svar("spawnNew-{1}-{2}", { model.key, config.key }),
                icon = ICONS.add,
                background = BTN_PRESETS.SUCCESS,
                onClick = function()
                    waitUntil(function()
                        BJIScenario.trySpawnNew(model.key, config.key)
                    end)
                end
            })
        end
        if ownVeh then
            line:btnIcon({
                id = svar("replace-{1}-{2}", { model.key, config.key }),
                icon = ICONS.carSensors,
                background = BTN_PRESETS.WARNING,
                onClick = function()
                    waitUntil(function()
                        BJIScenario.tryReplaceOrSpawn(model.key, config.key)
                    end)
                end
            })
        end
        line:build()
    elseif #model.configs < ACCORDION_THRESHOLD then
        drawModelTitle(false, true)
        Indent(2)
        drawModelConfigs()
        Indent(-2)
    else
        AccordionBuilder()
            :label(svar("##{1}", { model.key }))
            :openedBehavior(function()
                drawModelTitle(true, true)
                drawModelConfigs()
            end)
            :closedBehavior(function()
                drawModelTitle(true, false)
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
                    background = BTN_PRESETS.WARNING,
                    onClick = function()
                        local model = trandom(vehs) or {}
                        local config = trandom(model.configs) or {}

                        if model.key and config.key then
                            waitUntil(function()
                                BJIScenario.tryReplaceOrSpawn(model.key, config.key)
                            end)
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

local function drawPaints(paints)
    if not BJIVeh.isCurrentVehicleOwn() then
        return
    end

    local labelWidth = 0
    for _, p in ipairs(paints) do
        local w = GetColumnTextWidth(p.label)
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("BJIVehSelectorPaints", { labelWidth, -1 })
    for _, paintData in ipairs(paints) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(paintData.label)
                        :build()
                end,
                function()
                    local line = LineBuilder()
                    for i = 1, 3 do
                        line:btn({
                            id = "applyPaint" .. paintData.label:gsub(" ", ""),
                            label = svar(BJILang.get("vehicleSelector.applyPaint"), { position = i }),
                            onClick = function()
                                waitUntil(function()
                                    BJIScenario.tryPaint(paintData.paint, i)
                                end)
                            end
                        })
                    end
                    line:build()
                end,
            }
        })
    end
    cols:build()
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
            :text(svar("{1}:", { BJILang.get("vehicleSelector.previousVeh") }))
            :text(modelLabel)
        if not limitReached then
            line:btnIcon({
                id = svar("spawnNewPrevious-{1}-{2}", { previousConfig.model, previousConfig }),
                icon = ICONS.add,
                background = BTN_PRESETS.SUCCESS,
                onClick = function()
                    waitUntil(function()
                        BJIScenario.trySpawnNew(previousConfig.model, previousConfig)
                    end)
                end
            })
        end
        if ownVeh then
            line:btnIcon({
                id = svar("replacePrevious-{1}-{2}", { previousConfig.model, previousConfig }),
                icon = ICONS.carSensors,
                background = BTN_PRESETS.WARNING,
                onClick = function()
                    waitUntil(function()
                        BJIScenario.tryReplaceOrSpawn(previousConfig.model, previousConfig)
                    end)
                end
            })
        end
        line:build()
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
            :text(svar("{1}:", { BJILang.get("vehicleSelector.defaultVeh") }))
            :text(modelLabel)
        if not limitReached then
            line:btnIcon({
                id = svar("spawnNewDefault-{1}-{2}", { defaultVeh.model, defaultVeh.config }),
                icon = ICONS.add,
                background = BTN_PRESETS.SUCCESS,
                onClick = function()
                    waitUntil(function()
                        BJIScenario.trySpawnNew(defaultVeh.model, defaultVeh.config)
                    end)
                end
            })
        end
        if ownVeh then
            line:btnIcon({
                id = svar("replaceDefault-{1}-{2}", { defaultVeh.model, defaultVeh.config }),
                icon = ICONS.carSensors,
                background = BTN_PRESETS.WARNING,
                onClick = function()
                    waitUntil(function()
                        BJIScenario.tryReplaceOrSpawn(defaultVeh.model, defaultVeh.config)
                    end)
                end
            })
        end
        line:build()
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
                background = BTN_PRESETS.ERROR,
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
