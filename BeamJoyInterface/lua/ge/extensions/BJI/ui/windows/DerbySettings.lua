---@class BJIWindowDerbySettings : BJIWindow
local W = {
    name = "DerbySettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    w = 300,
    h = 350,

    show = false,

    labels = {
        title = "",
        places = "",
        lives = "",
        configs = "",
        configsTooltip = "",
        specificConfig = "",
    },
    data = {
        arenaIndex = 0,
        arena = {},
        lives = 3,
        ---@type {label: string, model: string, key?: string, custom: boolean, config: table}[]|tablelib
        configs = Table(),

        places = "",
        headerWidth = 0,
        labelsWidth = 0,
    },

    presets = require("ge/extensions/utils/VehiclePresets").getDerbyPresets(),
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("derby.settings.title")
    W.labels.places = BJI.Managers.Lang.get("derby.settings.places")
    W.labels.lives = BJI.Managers.Lang.get("derby.settings.lives")
    W.labels.configs = BJI.Managers.Lang.get("derby.settings.configs")
    W.labels.configsTooltip = BJI.Managers.Lang.get("derby.settings.configsTooltip")
    W.labels.specificConfig = BJI.Managers.Lang.get("derby.settings.specificConfig")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.data.places = string.var("({1})", { W.labels.places:var({ places = #W.data.arena.startPositions }) })

    W.data.headerWidth = Table({
        W.labels.title,
        W.data.arena.name .. " " .. W.data.places
    }):reduce(function(acc, v)
        local w = BJI.Utils.Common.GetColumnTextWidth(v)
        return w > acc and w or acc
    end, 0)

    W.data.labelsWidth = Table({
        W.labels.lives,
        W.labels.configs,
    }):reduce(function(acc, label)
        local w = BJI.Utils.Common.GetColumnTextWidth(label)
        return w > acc and w or acc
    end, 0)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache))

    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
    }, function(_, data)
        if data.cache == BJI.Managers.Cache.CACHES.PLAYERS and
            BJI.Managers.Perm.getCountPlayersCanSpawnVehicle() < BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DERBY).MINIMUM_PARTICIPANTS then
            BJI.Managers.Toast.warning(BJI.Managers.Lang.get("derby.settings.notEnoughPlayers"))
            onClose()
        end
    end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param arenaIndex integer
local function open(arenaIndex)
    if not BJI.Managers.Context.Scenario.Data.Derby or
        not BJI.Managers.Context.Scenario.Data.Derby[arenaIndex] then
        return
    end

    W.data.arenaIndex = arenaIndex
    W.data.arena = BJI.Managers.Context.Scenario.Data.Derby[arenaIndex]
    if W.show then updateCache() end
    W.show = true
end

---@param ctxt TickContext
local function header(ctxt)
    ColumnsBuilder("BJIDerbyHeader", { W.data.headerWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineLabel(W.labels.title)
                    LineBuilder():text(W.data.arena.name):text(W.data.places):build()
                end,
                function()
                    LineLabel("Presets :")
                    local line = LineBuilder()
                    Table(W.presets):forEach(function(preset, i)
                        line:btn({
                            id = string.var("preset-{1}", { i }),
                            label = preset.label,
                            style = BJI.Utils.Style.BTN_PRESETS.INFO,
                            disabled = #W.data.configs == 5,
                            onClick = function()
                                W.data.configs:addAll(
                                    Range(1, 5 - #W.data.configs)
                                    :reduce(function(acc)
                                        local j
                                        while not j do
                                            j = math.random(#acc.configs)
                                            if W.data.configs:find(function(c)
                                                    return c.model == acc.configs[j].model and
                                                        c.key == acc.configs[j].key
                                                end) then
                                                acc.configs:remove(j)
                                                j = nil
                                            end
                                        end
                                        acc.gen:insert(acc.configs:remove(j))
                                        return acc
                                    end, { gen = Table(), configs = table.clone(preset.configs) }).gen
                                    :map(function(gen)
                                        return {
                                            model = gen.model,
                                            key = gen.key,

                                            label = string.var("{1} {2}", { BJI.Managers.Veh.getModelLabel(gen.model),
                                                BJI.Managers.Veh.getConfigLabel(gen.model, gen.key) }),
                                            config = BJI.Managers.Veh.getFullConfig(BJI.Managers.Veh
                                            .getConfigByModelAndKey(gen.model,
                                                gen.key)),
                                        }
                                    end)
                                )
                            end
                        })
                    end)
                    line:build()
                end
            }
        }):build()
end

---@param ctxt TickContext
local function addCurrentConfig(ctxt)
    local config = {
        model = ctxt.veh.jbeam,
        key = BJI.Managers.Veh.getCurrentConfigKey(),
        label = BJI.Managers.Veh.isConfigCustom(ctxt.veh.partConfig) and
            BJI.Managers.Lang.get("derby.settings.specificConfig"):var({ model = BJI.Managers.Veh.getModelLabel(ctxt.veh
            .jbeam) }) or
            string.var("{1} {2}",
                { BJI.Managers.Veh.getModelLabel(ctxt.veh.jbeam), BJI.Managers.Veh.getCurrentConfigLabel() }),
        config = BJI.Managers.Veh.getFullConfig(ctxt.veh.partConfig),
    }
    if W.data.configs:any(function(c)
            return table.compare(config.config.parts, c.config.parts)
        end) then
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("derby.settings.toastConfigAlreadySaved"))
    else
        W.data.configs:insert(config)
    end
end

---@param ctxt TickContext
local function body(ctxt)
    local cols = ColumnsBuilder("BJIDerbySettings", { W.data.labelsWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineLabel(W.labels.lives)
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "derbyLives",
                            type = "int",
                            value = W.data.lives,
                            min = 0,
                            max = 5,
                            step = 1,
                            onUpdate = function(val)
                                W.data.lives = val
                            end
                        })
                        :build()
                end,
            }
        })

    Range(1, math.min(#W.data.configs + 1, 5)):forEach(function(i)
        local config = W.data.configs[i]
        cols:addRow({
            cells = {
                function()
                    if i == 1 then
                        LineBuilder()
                            :text(W.labels.configs, nil, W.labels.configsTooltip)
                            :build()
                    end
                end,
                function()
                    if config then
                        LineBuilder()
                            :btnIcon({
                                id = string.var("showDerbyConfig{1}", { i }),
                                icon = ctxt.isOwner and ICONS.carSensors or ICONS.add,
                                style = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                                BJI.Utils.Style.BTN_PRESETS.INFO,
                                onClick = function()
                                    local fn = ctxt.isOwner and BJI.Managers.Veh.replaceOrSpawnVehicle or
                                    BJI.Managers.Veh.spawnNewVehicle
                                    fn(config.model, config.key or { parts = config.config })
                                end,
                            })
                            :btnIcon({
                                id = string.var("removeDerbyConfig{1}", { i }),
                                icon = ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                onClick = function()
                                    W.data.configs:remove(i)
                                end,
                            })
                            :text(config.label)
                            :build()
                    else
                        LineBuilder()
                            :btnIcon({
                                id = "addDerbyConfig",
                                icon = ICONS.addListItem,
                                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                                disabled = not ctxt.veh,
                                onClick = function()
                                    addCurrentConfig(ctxt)
                                end,
                            })
                            :build()
                    end
                end,
            }
        })
    end)
    cols:build()
end

---@param ctxt TickContext
local function footer(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeDerbySettings",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :btnIcon({
            id = "startDerby",
            icon = ICONS.check,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            onClick = function()
                BJI.Tx.scenario.DerbyStart(W.data.arenaIndex, W.data.lives, W.data.configs)
                onClose()
            end
        })
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.open = open
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.getState = function() return W.show end

return W
