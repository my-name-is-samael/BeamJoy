local busScenario
local cache = {
    labels = {
        title = "",
        line = "",
        config = "",
    },
    data = {
        labelsWidth = 0,
        linesCombo = Table(),
        lineSelected = {},
        configsCombo = Table(),
        configSelected = {},
    },
}

local function updateLabels()
    busScenario = busScenario or BJIScenario.get(BJIScenario.TYPES.BUS_MISSION)

    cache.labels.title = BJILang.get("buslines.preparation.title")
    cache.labels.line = BJILang.get("buslines.preparation.line")
    cache.labels.config = BJILang.get("buslines.preparation.config")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()

    cache.data.labelsWidth = Table({
        cache.labels.line,
        cache.labels.config,
    }):reduce(function(acc, label)
        local w = GetColumnTextWidth(label)
        return w > acc and w or acc
    end, 0)

    cache.data.linesCombo = Table(BJIContext.Scenario.Data.BusLines)
        :map(function(line, i)
            return {
                id = i,
                label = string.var("{1} ({2})", { line.name, PrettyDistance(line.distance) }),
                loopable = line.loopable,
                stops = table.clone(line.stops),
            }
        end):sort(function(a, b)
            return a.label < b.label
        end)
    cache.data.linesCombo:insert(1, {
        label = "",
    })
    cache.data.lineSelected = cache.data.lineSelected and
        cache.data.linesCombo:find(function(line) return line.label == cache.data.lineSelected.label end) or
        cache.data.linesCombo[1]

    cache.data.configsCombo = Table()
    Table({
        busScenario.BASE_MODEL
    }):addAll({}) -- add custom buses in the future
        :forEach(function(model)
            local modelLabel = BJIVeh.getModelLabel(model)
            local configs = BJIVeh.getAllConfigsForModel(model)
            cache.data.configsCombo:addAll(Table(configs)
                :map(function(conf)
                    local label = string.var("{1} {2}", { modelLabel, conf.label })
                    if conf.custom then
                        label = string.var("{1} ({2})", { label, BJILang.get("buslines.preparation.customConfig") })
                    end
                    return {
                        config = conf.key,
                        model = model,
                        label = label,
                    }
                end):sort(function(a, b)
                    return a.label < b.label
                end) or {})
        end)
    cache.data.configsCombo:insert(1, {
        label = "",
    })
    cache.data.configSelected = cache.data.configSelected and
        cache.data.configsCombo:find(function(conf) return conf.config == cache.data.configSelected.config end) or
        cache.data.configsCombo[1]
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels))

    updateCache()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.CACHE_LOADED,
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt, data)
        if data._event ~= BJIEvents.EVENTS.CACHE_LOADED or
            data.cache == BJICache.CACHES.BUS_LINES then
            updateCache(ctxt)
        end
    end))
end

local function onUnload()
    listeners:forEach(BJIEvents.removeListener)
    cache.data.configsCombo = Table()
    cache.data.linesCombo = Table()
end

local function body(ctxt)
    busScenario = BJIScenario.get(BJIScenario.TYPES.BUS_MISSION)

    LineLabel(cache.labels.title)
    ColumnsBuilder("BJIBusMissionPreparation", { cache.data.labelsWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineLabel(cache.labels.line)
                end,
                function()
                    LineBuilder():inputCombo({
                        id = "busMissionLine",
                        items = cache.data.linesCombo,
                        value = cache.data.lineSelected,
                        getLabelFn = function(item)
                            return item.label
                        end,
                        onChange = function(item)
                            cache.data.lineSelected = item
                            dump(item.id, cache.data.linesCombo[1].id)
                            if item.id and not cache.data.linesCombo[1].id then
                                -- auto remove on switch
                                cache.data.linesCombo:remove(1)
                            end
                        end
                    }):build()
                end,
            }
        })
        :addRow({
            cells = {
                function()
                    LineLabel(cache.labels.config)
                end,
                function()
                    LineBuilder()
                        :inputCombo({
                            id = "busMissionVehicleConfig",
                            items = cache.data.configsCombo,
                            value = cache.data.configSelected,
                            getLabelFn = function(item)
                                return item.label
                            end,
                            onChange = function(item)
                                cache.data.configSelected = item
                                if item.config and not cache.data.configsCombo[1].config then
                                    -- auto remove on switch
                                    cache.data.configsCombo:remove(1)
                                end
                            end
                        })
                        :build()
                end,
            }
        })
        :build()
end

local function onClose()
    BJIContext.Scenario.BusSettings = nil
end

---@param ctxt TickContext
local function startMission(ctxt)
    busScenario.start(ctxt, {
        id = cache.data.lineSelected.id,
        name = cache.data.lineSelected.label,
        loopable = cache.data.lineSelected.loopable,
        stops = cache.data.lineSelected.stops,
    }, cache.data.configSelected.model, cache.data.configSelected.config)
    onClose()
end

---@param ctxt TickContext
local function footer(ctxt)
    LineBuilder()
        :btnIcon({
            id = "cancelBusMission",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :btnIcon({
            id = "startBusMission",
            icon = ICONS.videogame_asset,
            style = BTN_PRESETS.SUCCESS,
            disabled = not cache.data.lineSelected.id or not cache.data.configSelected.config,
            onClick = function()
                startMission(ctxt)
            end,
        })
        :build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    onLoad = onLoad,
    onUnload = onUnload,
    body = body,
    footer = footer,
    onClose = onClose,
}
