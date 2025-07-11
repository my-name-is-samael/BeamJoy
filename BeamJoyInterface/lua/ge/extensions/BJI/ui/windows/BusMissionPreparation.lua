---@class BJIWindowBusMissionPreparation : BJIWindow
local W = {
    name = "BusMissionPreparation",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    size = ImVec2(430, 150),

    show = false,

    labels = {
        title = "",
        line = "",
        config = "",
        cancel = "",
        start = "",
    },
    data = {
        linesCombo = Table(),
        lineSelected = nil,
        configsCombo = Table(),
        configSelected = nil,
    },
    ---@type BJIScenarioBusMission
    scenario = nil,
}
--- gc prevention
local nextValue

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.title = BJI_Lang.get("buslines.preparation.title")
    W.labels.line = BJI_Lang.get("buslines.preparation.line")
    W.labels.config = BJI_Lang.get("buslines.preparation.config")
    W.labels.cancel = BJI_Lang.get("common.buttons.cancel")
    W.labels.start = BJI_Lang.get("common.buttons.start")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    W.data.linesCombo = Table(BJI_Context.Scenario.Data.BusLines)
        :map(function(line, i)
            return {
                value = i,
                label = string.var("{1} ({2})", { line.name, BJI.Utils.UI.PrettyDistance(line.distance) }),
            }
        end):sort(function(a, b)
            return a.label < b.label
        end)
    W.data.linesCombo:insert(1, {
        label = "",
    })
    W.data.lineSelected = W.data.linesCombo:find(function(line) return line.value == W.data.lineSelected end) and
        W.data.lineSelected or W.data.linesCombo[1].value

    W.data.configsCombo = Table({
            W.scenario.BASE_MODEL
        }):addAll({}) -- add custom buses in the future
        :reduce(function(res, model)
            res:addAll(Table(BJI_Veh.getAllConfigsForModel(model))
                :map(function(conf)
                    local label = string.var("{1} {2}", { BJI_Veh.getModelLabel(model), conf.label })
                    if conf.custom then
                        label = string.var("{1} ({2})",
                            { label, BJI_Lang.get("buslines.preparation.customConfig") })
                    end
                    return {
                        value = model .. ";" .. conf.key,
                        label = label,
                    }
                end):values())
            return res
        end, Table()):sort(function(a, b)
            return a.label < b.label
        end)
    W.data.configsCombo:insert(1, {
        label = "",
    })
    W.data.configSelected = W.data.configsCombo:any(function(conf) return conf.value == W.data.configSelected end) and
        W.data.configSelected or W.data.configsCombo[1].value
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI_Scenario.get(BJI_Scenario.TYPES.BUS_MISSION)

    updateLabels()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt, data)
        if data._event ~= BJI_Events.EVENTS.CACHE_LOADED or
            data.cache == BJI_Cache.CACHES.BUS_LINES then
            updateCache(ctxt)
        end
    end, W.name .. "Cache"))

    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not BJI_Perm.canSpawnVehicle() or
            not BJI_Scenario.isFreeroam() then
            onClose()
        end
    end, W.name .. "AutoClose"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
    W.data.configsCombo = Table()
    W.data.linesCombo = Table()
end

---@param ctxt TickContext
local function body(ctxt)
    Text(W.labels.title)
    if BeginTable("BJIBusMissionPreparation", {
            { label = "##bus-preparation-labels" },
            { label = "##bus-preparation-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.line)
        TableNextColumn()
        nextValue = Combo("busMissionLine", W.data.lineSelected, W.data.linesCombo, { width = -1 })
        if nextValue then
            W.data.lineSelected = nextValue
            if not W.data.linesCombo[1].value then
                -- auto remove empty option on switch
                W.data.linesCombo:remove(1)
            end
        end

        TableNewRow()
        Text(W.labels.config)
        TableNextColumn()
        nextValue = Combo("busMissionVehicleConfig", W.data.configSelected, W.data.configsCombo, { width = -1 })
        if nextValue then
            W.data.configSelected = nextValue
            if not W.data.configsCombo[1].value then
                -- auto remove empty option on switch
                W.data.configsCombo:remove(1)
            end
        end

        EndTable()
    end
end

---@param ctxt TickContext
local function startMission(ctxt)
    local line = BJI_Context.Scenario.Data.BusLines[W.data.lineSelected]
    local model, config = table.unpack(tostring(W.data.configSelected):split2(";"))
    W.scenario.start(ctxt, {
        id = W.data.lineSelected,
        name = line.name,
        loopable = line.loopable,
        stops = line.stops,
    }, model, config)
    onClose()
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("cancelBusMission", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.cancel)
    SameLine()
    if IconButton("startBusMission", BJI.Utils.Icon.ICONS.videogame_asset,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = not W.data.lineSelected or not W.data.configSelected }) then
        startMission(ctxt)
    end
    TooltipText(W.labels.start)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body
W.footer = footer
W.onClose = onClose
W.getState = function() return W.show end

return W
