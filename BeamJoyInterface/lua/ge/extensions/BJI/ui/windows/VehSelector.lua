local ACCORDION_THRESHOLD = 2

---@class BJIWindowVehSelector : BJIWindow
---@field tryClose fun(force?: boolean)
local W = {
    name = "VehSelector",
    minSize = ImVec2(350, 400),
    maxSize = ImVec2(600, 1200),

    show = false,
    models = {
        cars = {},
        trucks = {},
        trailers = {},
        props = {},
    },
    modelsCount = 0,
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
        filterTooltip = "",
        noMatch = "",

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
--- gc prevention
local width, nextValue, vehsDrew, opened, drawTitle, drawModels, drawModelTitle, drawModelButtons, drawModelConfigs, drawn

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
    W.labels.filterTooltip = BJI.Managers.Lang.get("vehicleSelector.filterTooltip")
    W.labels.noMatch = BJI.Managers.Lang.get("vehicleSelector.noMatch")

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

---@param baseColor number[]
local function paintToIconStyle(baseColor)
    local converted = ui_imgui.ImVec4(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1.2)
    local contrasted = baseColor[1] + baseColor[2] + baseColor[3] > 1.5 and 0 or 1
    return {
        converted,
        converted,
        converted,
        ui_imgui.ImVec4(contrasted, contrasted, contrasted, 1),
    }
end

local function updateCachePaints()
    local ctxt = BJI.Managers.Tick.getContext()
    W.cache.paints = Table()

    if ctxt.isOwner then
        W.cache.paints = ctxt.veh and table.map(BJI.Managers.Veh.getAllPaintsForModel(ctxt.veh.jbeam),
            function(paintData, paintLabel)
                return {
                    label = paintLabel,
                    paint = paintData,
                    style = paintToIconStyle(paintData.baseColor)
                }
            end):values():sort(function(a, b)
            return a.label < b.label
        end) or Table()
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

local function isVehTypeAllowed(vehType)
    if vehType == BJI.Managers.Veh.TYPES.TRAILER and
        not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SPAWN_TRAILERS) then
        return false
    end
    if vehType == BJI.Managers.Veh.TYPES.PROP and
        not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SPAWN_PROPS) then
        return false
    end
    return true
end

---@param ctxt? TickContext
local function updateButtonsStates(ctxt)
    ctxt = type(ctxt) == "table" and ctxt or BJI.Managers.Tick.getContext()

    local canSpawnOrReplace = BJI.Managers.Perm.canSpawnVehicle() and
        (ctxt.group.vehicleCap == -1 or (not ctxt.isOwner and
            BJI.Managers.Veh.getSelfVehiclesCount() < ctxt.group.vehicleCap)) and
        (ctxt.isOwner and BJI.Managers.Scenario.canReplaceVehicle() or BJI.Managers.Scenario.canSpawnNewVehicle())
    local currentVehTypeAllowed = ctxt.veh and isVehTypeAllowed(BJI.Managers.Veh.getType(ctxt.veh.jbeam))
    local currentVehBlacklisted = ctxt.veh and BJI.Managers.Veh.isModelBlacklisted(ctxt.veh.jbeam) and
        not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.BYPASS_MODEL_BLACKLIST)
    local vehCapNotReached = ctxt.group.vehicleCap == -1 or
        ctxt.group.vehicleCap > BJI.Managers.Veh.getSelfVehiclesCount()
    local canClone = ctxt.veh and BJI.Managers.Scenario.canSpawnNewVehicle() and vehCapNotReached and
        currentVehTypeAllowed and not currentVehBlacklisted

    local currentVehIsProtected = ctxt.veh and not ctxt.isOwner and ctxt.veh.protected

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

    W.headerBtns.cloneCurrentDisabled = not ctxt.veh or not canSpawnOrReplace or not canClone or currentVehIsProtected
    if W.headerBtns.cloneCurrentDisabled then
        if not ctxt.veh then
            W.headerBtns.cloneCurrentTooltip = W.labels.noVeh
        elseif currentVehIsProtected then
            W.headerBtns.cloneCurrentTooltip = W.labels.protectedVehicle
        else
            W.headerBtns.cloneCurrentTooltip = W.labels.notAllowed
        end
    else
        W.headerBtns.cloneCurrentTooltip = nil
    end

    W.headerBtns.resetAllDisabled = not BJI.Managers.Scenario.isFreeroam()
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
    if Button("loadPrevious", W.labels.previousVeh,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.headerBtns.loadPreviousDisabled }) then
        BJI.Managers.Scenario.tryReplaceOrSpawn(ctxt.user.previousVehConfig.model, ctxt.user.previousVehConfig)
        extensions.hook("trackNewVeh")
    end
    TooltipText(W.headerBtns.loadPreviousTooltip)

    width = GetWindowSize().x / 3 - GetStyle().CellPadding.x * 4
    if BeginTable("BJIVehSelectorHeaderButtons", {
            { label = "##left" },
            { label = "##middle" },
            { label = "##right" },
        }, { flags = { TABLE_FLAGS.SIZING_STRETCH_SAME } }) then
        TableNewRow()
        if Button("setAsDefault", W.labels.setAsDefault,
                { disabled = W.headerBtns.setAsDefaultDisabled,
                    width = width }) then
            core_vehicle_partmgmt.savedefault()
            updateButtonsStates(ctxt)
        end
        TooltipText(W.headerBtns.setAsDefaultTooltip)
        TableNextColumn()
        if Button("loadDefault", W.labels.loadDefault,
                { disabled = W.headerBtns.loadDefaultDisabled,
                    width = width }) then
            local defaultVeh = BJI.Managers.Veh.getDefaultModelAndConfig()
            if defaultVeh then
                BJI.Managers.Scenario.tryReplaceOrSpawn(defaultVeh.model, defaultVeh.config)
                extensions.hook("trackNewVeh")
            end
        end
        TooltipText(W.headerBtns.loadDefaultTooltip)
        TableNextColumn()
        if Button("cloneCurrent", W.labels.cloneCurrent,
                { disabled = W.headerBtns.cloneCurrentDisabled,
                    width = width }) then
            BJI.Managers.Scenario.trySpawnNew(ctxt.veh.jbeam, ctxt.veh.veh.partConfig)
            extensions.hook("trackNewVeh")
        end
        TooltipText(W.headerBtns.cloneCurrentTooltip)

        TableNewRow()
        if Button("resetAll", W.labels.resetAll,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = W.headerBtns.resetAllDisabled,
                    width = width }) then
            resetGameplay(-1)
        end
        TooltipText(W.headerBtns.resetAllTooltip)
        TableNextColumn()
        if Button("resetCurrent", W.labels.removeCurrent,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR,
                    disabled = W.headerBtns.removeCurrentDisabled,
                    width = width }) then
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
        end
        TooltipText(W.headerBtns.removeCurrentTooltip)
        TableNextColumn()
        if Button("deleteOthers", W.labels.removeOthers,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR,
                    disabled = W.headerBtns.removeOthersDisabled,
                    width = width }) then
            BJI.Managers.Veh.deleteOtherOwnVehicles()
            extensions.hook("trackNewVeh")
        end
        TooltipText(W.headerBtns.removeOthersTooltip)

        EndTable()
    end

    -- open basegame veh selector / filter
    if #W.models.cars + #W.models.trucks +
        #W.models.trailers + #W.models.props > 0 then
        Separator()
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.VEHICLE_SELECTOR) then
            if IconButton("openVehSelectorUI", BJI.Utils.Icon.ICONS.open_in_new) then
                if W.onClose then
                    BJI.Windows.VehSelector.tryClose()
                end
                core_vehicles.openSelectorUI()
            end
            TooltipText(W.labels.openVehSelector)
            SameLine()
        end
        if #W.vehFilter == 0 then
            Icon(BJI.Utils.Icon.ICONS.ab_filter_default)
        else
            if IconButton("removeVehFilter", BJI.Utils.Icon.ICONS.ab_filter_default,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
                W.vehFilter = ""
                updateCacheVehicles()
            end
            TooltipText(W.labels.remove)
        end
        SameLine()
        nextValue = InputText("vehFilter", W.vehFilter)
        TooltipText(W.labels.filterTooltip)
        if nextValue then
            W.vehFilter = nextValue
            updateCacheVehicles()
        end
    end
end

---@param modelKey string
---@param config { key: string, label: string, custom?: boolean }
local function drawConfig(modelKey, config)
    drawn = false
    TableNewRow()
    TableNextColumn()
    TableNextColumn()
    if not limitReached then
        if IconButton(string.var("spawnNew-{1}-{2}", { modelKey, config.key }),
                BJI.Utils.Icon.ICONS.add,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            BJI.Managers.Scenario.trySpawnNew(modelKey, config.key)
        end
        TooltipText(W.labels.spawn)
        drawn = true
    end
    if ownVeh then
        if drawn then
            SameLine()
        end
        if IconButton(string.var("replace-{1}-{2}", { modelKey, config.key }),
                BJI.Utils.Icon.ICONS.carSensors, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
            BJI.Managers.Scenario.tryReplaceOrSpawn(modelKey, config.key)
        end
        TooltipText(W.labels.replace)
    end
    TableNextColumn()
    Text(config.label, {
        color = config.custom and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    })
end

local imgs = {}
---@param modelPath string
---@return {texId: any}?
local function getModelImage(modelPath)
    if imgs[modelPath] then
        return imgs[modelPath]
    end

    local img = require('ui/imguiUtils').texObj(modelPath)
    if img.size.x > 0 and img.size.y > 0 then
        imgs[modelPath] = img
        return img
    else -- invalid image
        -- test if its a png file with a jpg extension
        -- https://github.com/my-name-is-samael/BeamJoy/issues/18#issuecomment-2508961479
        if modelPath:find(".jpg$") then
            local pngPath = modelPath:gsub(".jpg$", ".png")
            local file = io.open(pngPath, "r")
            if file then
                file:close()
            else
                local jpgFile = io.open(modelPath, "r")
                file = io.open(pngPath, "w")
                if jpgFile and file then
                    file:write(jpgFile:read("*all"))
                    jpgFile:close()
                    file:close()
                end
            end
            return getModelImage(pngPath)
        else -- already a png, no solution :(
            return
        end
    end
end

local previewSize = ImVec2(356, 200)
local scale, finalPreviewSize

---@param model { key: string, preview: string, label: string, custom?: boolean, configs: { key: string, label: string, custom?: boolean }[] }
local function drawModel(model)
    drawModelButtons = function(withSpawn, isAccordion)
        Icon(BJI.Utils.Icon.ICONS.ab_asset_image)
        if IsItemHovered() then
            local img = getModelImage(model.preview)
            if img then
                scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
                finalPreviewSize = ImVec2(previewSize.x * scale, previewSize.y * scale)
                BeginTooltip()
                Image(img.texId, finalPreviewSize)
                EndTooltip()
            else
                TooltipText("Invalid vehicle preview image :'(")
            end
        end
        TableNextColumn()
        drawn = false
        if withSpawn then
            if not limitReached then
                if IconButton(string.var("spawnNew-{1}", { model.key }), BJI.Utils.Icon.ICONS.add,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                    BJI.Managers.Scenario.trySpawnNew(model.key, #model.configs == 1 and
                        model.configs[1].key or nil)
                end
                TooltipText(W.labels.spawn)
                drawn = true
            end
            if ownVeh then
                if drawn then
                    SameLine()
                end
                if IconButton(string.var("replace-{1}", { model.key }), BJI.Utils.Icon.ICONS.carSensors,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                    BJI.Managers.Scenario.tryReplaceOrSpawn(model.key,
                        #model.configs == 1 and model.configs[1].key or nil)
                end
                TooltipText(W.labels.replace)
                drawn = true
            end
        end
        if #model.configs > 1 and (ownVeh or not limitReached) then
            if drawn then
                SameLine()
            end
            if IconButton(string.var("spawnRandom-{1}", { model.key }), BJI.Utils.Icon.ICONS.casino,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                local config = table.random(model.configs) or {}
                BJI.Managers.Scenario.tryReplaceOrSpawn(model.key, config.key)
            end
            TooltipText(W.labels.random)
        end
    end

    drawModelTitle = function()
        Text(model.label, {
            color = model.custom and
                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        })
    end

    drawModelConfigs = function()
        for _, config in ipairs(model.configs) do
            drawConfig(model.key, config)
        end
    end

    if #model.configs == 0 then
        return
    elseif #model.configs == 1 then
        -- compacted model-config (only 1 line)
        TableNewRow()
        TableNextColumn()
        drawModelButtons(true)
        TableNextColumn()
        drawModelTitle()
        SameLine()
        local config = model.configs[1]
        Text(string.var("({1})", { config.label }))
    elseif #model.configs < ACCORDION_THRESHOLD then
        TableNewRow()
        TableNextColumn()
        drawModelButtons(false)
        TableNextColumn()
        drawModelTitle()

        drawModelConfigs()
    else
        TableNewRow()
        opened = BeginTree(" ##tree-" .. model.key)
        if opened then EndTree() end
        TableNextColumn()
        drawModelButtons(not opened)
        TableNextColumn()
        drawModelTitle()

        if opened then
            drawModelConfigs()
        end
    end
end

---@param vehs table[]
---@param label string
---@param name string
---@param icon string
---@return boolean vehsRendered
local function drawType(vehs, label, name, icon)
    if #vehs > 0 then
        drawTitle = function(inAccordion)
            if not inAccordion then
                Text(label)
            end
            if icon then
                SameLine()
                Icon(icon)
            end
            if #vehs > 0 then
                SameLine()
                if IconButton("random-" .. name, BJI.Utils.Icon.ICONS.casino,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                    local model = table.random(vehs) or {}
                    local config = table.random(model.configs) or {}
                    if model.key and config.key then
                        BJI.Managers.Scenario.tryReplaceOrSpawn(model.key, config.key)
                    end
                end
                TooltipText(W.labels.random)
            end
        end

        drawModels = function()
            if BeginTable("##table-" .. name, {
                    { label = "##cell-tree-" .. name },
                    { label = "##cell-preview-" .. name },
                    { label = "##cell-actions-" .. name },
                    { label = "##cell-label-" .. name },
                }) then
                for _, m in ipairs(vehs) do
                    drawModel(m)
                end

                EndTable()
            end
        end

        if #vehs < ACCORDION_THRESHOLD then
            drawTitle(false)
            Indent(); Indent()
            drawModels()
            Unindent(); Unindent()
        else
            opened = BeginTree(label)
            drawTitle(true)
            if opened then
                drawModels()
                EndTree()
            end
        end
    end
    return #vehs > 0
end

---@param paints { label: string, paint: { baseColor: number[] }, style: vec4[] }[]
local function drawPaints(paints)
    if not BJI.Managers.Veh.isCurrentVehicleOwn() then
        return
    end

    if BeginTable("BJIVehSelectorPaints", {
            { label = "##vehselector-paint-labels" },
            { label = "##vehselector-paint-actions", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        for i, paintData in ipairs(paints) do
            TableNewRow()
            Text(paintData.label)
            TableNextColumn()
            Range(1, 3):forEach(function(j)
                if j > 1 then
                    SameLine()
                end
                if IconButton(string.var("applyPaint-{1}-{2}", { i, j }),
                        BJI.Utils.Icon.ICONS.format_color_fill, { btnStyle = paintData.style }) then
                    BJI.Managers.Scenario.tryPaint(j, paintData.paint)
                end
                TooltipText(W.labels.applyPaint:var({ position = j }))
            end)
        end

        EndTable()
    end
end

---@param ctxt TickContext
local function drawBody(ctxt)
    ownVeh = ctxt.isOwner
    limitReached = ctxt.group.vehicleCap > -1 and ctxt.group.vehicleCap <= BJI.Managers.Veh.getSelfVehiclesCount()

    vehsDrew = false

    if W.cache.vehicles.cars then
        vehsDrew = drawType(W.cache.vehicles.cars, W.labels.cars, "car", BJI.Utils.Icon.ICONS.fg_vehicle_suv) or vehsDrew
    end

    if W.cache.vehicles.trucks then
        vehsDrew = drawType(W.cache.vehicles.trucks, W.labels.trucks, "truck", BJI.Utils.Icon.ICONS.fg_vehicle_truck) or
            vehsDrew
    end

    if W.cache.vehicles.trailers then
        vehsDrew = drawType(W.cache.vehicles.trailers, W.labels.trailers, "trailer",
            BJI.Utils.Icon.ICONS.fg_vehicle_tanker_trailer) or vehsDrew
    end

    if W.cache.vehicles.props then
        vehsDrew = drawType(W.cache.vehicles.props, W.labels.props, "prop", BJI.Utils.Icon.ICONS.fg_traffic_cone) or
            vehsDrew
    end

    if W.modelsCount > 0 and not vehsDrew then
        Text(W.labels.noMatch)
    end

    -- must get a new instance of current vehicle or else crash
    if #W.cache.paints > 0 then
        if W.modelsCount > 0 then
            Separator()
        end

        opened = BeginTree(BJI.Managers.Lang.get("vehicleSelector.paints"))
        SameLine()
        Icon(BJI.Utils.Icon.ICONS.style)
        if opened then
            drawPaints(W.cache.paints)
            EndTree()
        end
    end
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    if W.onClose then
        if IconButton("closeVehicleSelector", BJI.Utils.Icon.ICONS.exit_to_app,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            W.onClose()
        end
        TooltipText(W.labels.close)
    end
end

local function getFooterLines()
    return W.onClose and 1 or 0
end

---@param state? boolean
local function updateOnClose(state)
    if state and not W.onClose then
        W.onClose = function()
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

    W.modelsCount = #W.models.cars + #W.models.trucks +
        #W.models.trailers + #W.models.props

    W.cache.vehicles = {}
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

    listeners:insert(BJI.Managers.Events.addListener({
            BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
            BJI.Managers.Events.EVENTS.PURSUIT_UPDATE,
        },
        function()
            if not BJI.Managers.Perm.canSpawnVehicle() or
                BJI.Managers.Pursuit.getState() then
                tryClose(true)
            end
        end, W.name .. "AutoClose"))

    updateButtonsStates()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.VEHICLE_REMOVED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.VEHICLES_UPDATED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.NG_VEHICLE_REPLACED,
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
