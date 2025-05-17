---@class BJIWindowBusMissionPreparation : BJIWindow
local W = {
    name = "BusMissionPreparation",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 430,
    h = 150,

    show = false,

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
    ---@type BJIScenarioBusMission
    scenario = nil,
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("buslines.preparation.title")
    W.labels.line = BJI.Managers.Lang.get("buslines.preparation.line")
    W.labels.config = BJI.Managers.Lang.get("buslines.preparation.config")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.data.labelsWidth = Table({
        W.labels.line,
        W.labels.config,
    }):reduce(function(acc, label)
        local w = BJI.Utils.Common.GetColumnTextWidth(label)
        return w > acc and w or acc
    end, 0)

    W.data.linesCombo = Table(BJI.Managers.Context.Scenario.Data.BusLines)
        :map(function(line, i)
            return {
                id = i,
                label = string.var("{1} ({2})", { line.name, BJI.Utils.Common.PrettyDistance(line.distance) }),
                loopable = line.loopable,
                stops = table.clone(line.stops),
            }
        end):sort(function(a, b)
            return a.label < b.label
        end)
    W.data.linesCombo:insert(1, {
        label = "",
    })
    W.data.lineSelected = W.data.lineSelected and
        W.data.linesCombo:find(function(line) return line.label == W.data.lineSelected.label end) or
        W.data.linesCombo[1]

    W.data.configsCombo = Table()
    Table({
        W.scenario.BASE_MODEL
    }):addAll({}) -- add custom buses in the future
        :forEach(function(model)
            local modelLabel = BJI.Managers.Veh.getModelLabel(model)
            local configs = BJI.Managers.Veh.getAllConfigsForModel(model)
            W.data.configsCombo:addAll(Table(configs)
                :map(function(conf)
                    local label = string.var("{1} {2}", { modelLabel, conf.label })
                    if conf.custom then
                        label = string.var("{1} ({2})",
                            { label, BJI.Managers.Lang.get("buslines.preparation.customConfig") })
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
    W.data.configsCombo:insert(1, {
        label = "",
    })
    W.data.configSelected = W.data.configSelected and
        W.data.configsCombo:find(function(conf) return conf.config == W.data.configSelected.config end) or
        W.data.configsCombo[1]
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.BUS_MISSION)

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            data.cache == BJI.Managers.Cache.CACHES.BUS_LINES then
            updateCache(ctxt)
        end
    end))

    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, function()
        if not BJI.Managers.Perm.canSpawnVehicle() or
            not BJI.Managers.Scenario.isFreeroam() then
            onClose()
        end
    end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    W.data.configsCombo = Table()
    W.data.linesCombo = Table()
end

---@param ctxt TickContext
local function body(ctxt)
    LineLabel(W.labels.title)
    ColumnsBuilder("BJIBusMissionPreparation", { W.data.labelsWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineLabel(W.labels.line)
                end,
                function()
                    LineBuilder():inputCombo({
                        id = "busMissionLine",
                        items = W.data.linesCombo,
                        value = W.data.lineSelected,
                        getLabelFn = function(item)
                            return item.label
                        end,
                        onChange = function(item)
                            W.data.lineSelected = item
                            if item.id and not W.data.linesCombo[1].id then
                                -- auto remove on switch
                                W.data.linesCombo:remove(1)
                            end
                        end
                    }):build()
                end,
            }
        })
        :addRow({
            cells = {
                function()
                    LineLabel(W.labels.config)
                end,
                function()
                    LineBuilder()
                        :inputCombo({
                            id = "busMissionVehicleConfig",
                            items = W.data.configsCombo,
                            value = W.data.configSelected,
                            getLabelFn = function(item)
                                return item.label
                            end,
                            onChange = function(item)
                                W.data.configSelected = item
                                if item.config and not W.data.configsCombo[1].config then
                                    -- auto remove on switch
                                    W.data.configsCombo:remove(1)
                                end
                            end
                        })
                        :build()
                end,
            }
        })
        :build()
end

---@param ctxt TickContext
local function startMission(ctxt)
    W.scenario.start(ctxt, {
        id = W.data.lineSelected.id,
        name = W.data.lineSelected.label,
        loopable = W.data.lineSelected.loopable,
        stops = W.data.lineSelected.stops,
    }, W.data.configSelected.model, W.data.configSelected.config)
    onClose()
end

---@param ctxt TickContext
local function footer(ctxt)
    LineBuilder()
        :btnIcon({
            id = "cancelBusMission",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :btnIcon({
            id = "startBusMission",
            icon = ICONS.videogame_asset,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = not W.data.lineSelected.id or not W.data.configSelected.config,
            onClick = function()
                startMission(ctxt)
            end,
        })
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body
W.footer = footer
W.onClose = onClose
W.getState = function() return W.show end

return W
