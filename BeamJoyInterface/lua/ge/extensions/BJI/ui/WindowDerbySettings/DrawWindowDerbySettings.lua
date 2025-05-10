local M = {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE,
    },
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
    M.show = false
end

local function updateLabels()
    M.labels.title = BJILang.get("derby.settings.title")
    M.labels.places = BJILang.get("derby.settings.places")
    M.labels.lives = BJILang.get("derby.settings.lives")
    M.labels.configs = BJILang.get("derby.settings.configs")
    M.labels.configsTooltip = BJILang.get("derby.settings.configsTooltip")
    M.labels.specificConfig = BJILang.get("derby.settings.specificConfig")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()

    M.data.places = string.var("({1})", { M.labels.places:var({ places = #M.data.arena.startPositions }) })

    M.data.headerWidth = Table({
        M.labels.title,
        M.data.arena.name .. " " .. M.data.places
    }):reduce(function(acc, v)
        local w = GetColumnTextWidth(v)
        return w > acc and w or acc
    end, 0)

    M.data.labelsWidth = Table({
        M.labels.lives,
        M.labels.configs .. HELPMARKER_TEXT,
    }):reduce(function(acc, label)
        local w = GetColumnTextWidth(label)
        return w > acc and w or acc
    end, 0)
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
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache))

    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.CACHE_LOADED,
    }, function(_, data)
        if data.cache == BJICache.CACHES.PLAYERS and
            BJIPerm.getCountPlayersCanSpawnVehicle() < BJIScenario.get(BJIScenario.TYPES.DERBY).MINIMUM_PARTICIPANTS then
            BJIToast.warning(BJILang.get("derby.settings.notEnoughPlayers"))
            onClose()
        end
    end))
end

local function onUnload()
    listeners:forEach(BJIEvents.removeListener)
end

local function open(arenaIndex)
    if not BJIContext.Scenario.Data.Derby or
        not BJIContext.Scenario.Data.Derby[arenaIndex] then
        return
    end

    M.data.arenaIndex = arenaIndex
    M.data.arena = BJIContext.Scenario.Data.Derby[arenaIndex]
    if M.show then updateCache() end
    M.show = true
end

local function header(ctxt)
    ColumnsBuilder("BJIDerbyHeader", { M.data.headerWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineLabel(M.labels.title)
                    LineBuilder():text(M.data.arena.name):text(M.data.places):build()
                end,
                function()
                    LineLabel("Presets :")
                    local line = LineBuilder()
                    Table(M.presets):forEach(function(preset, i)
                        line:btn({
                            id = string.var("preset-{1}", { i }),
                            label = preset.label,
                            style = BTN_PRESETS.INFO,
                            disabled = #M.data.configs == 5,
                            onClick = function()
                                M.data.configs:addAll(
                                    Range(1, 5 - #M.data.configs)
                                    :reduce(function(acc)
                                        local j
                                        while not j do
                                            j = math.random(#acc.configs)
                                            if M.data.configs:find(function(c)
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

                                            label = string.var("{1} {2}", { BJIVeh.getModelLabel(gen.model),
                                                BJIVeh.getConfigLabel(gen.model, gen.key) }),
                                            config = BJIVeh.getFullConfig(BJIVeh.getConfigByModelAndKey(gen.model,
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
        key = BJIVeh.getCurrentConfigKey(),
        label = BJIVeh.isConfigCustom(ctxt.veh.partConfig) and
            BJILang.get("derby.settings.specificConfig"):var({ model = BJIVeh.getModelLabel(ctxt.veh.jbeam) }) or
            string.var("{1} {2}", { BJIVeh.getModelLabel(ctxt.veh.jbeam), BJIVeh.getCurrentConfigLabel() }),
        config = BJIVeh.getFullConfig(ctxt.veh.partConfig),
    }
    if M.data.configs:any(function(c)
            return table.compare(config.config.parts, c.config.parts)
        end) then
        BJIToast.error(BJILang.get("derby.settings.toastConfigAlreadySaved"))
    else
        M.data.configs:insert(config)
    end
end

local function body(ctxt)
    local cols = ColumnsBuilder("BJIDerbySettings", { M.data.labelsWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineLabel(M.labels.lives)
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "derbyLives",
                            type = "int",
                            value = M.data.lives,
                            min = 0,
                            max = 5,
                            step = 1,
                            onUpdate = function(val)
                                M.data.lives = val
                            end
                        })
                        :build()
                end,
            }
        })

    Range(1, math.min(#M.data.configs + 1, 5)):forEach(function(i)
        local config = M.data.configs[i]
        cols:addRow({
            cells = {
                function()
                    if i == 1 then
                        LineBuilder()
                            :text(M.labels.configs)
                            :helpMarker(M.labels.configsTooltip)
                            :build()
                    end
                end,
                function()
                    if config then
                        LineBuilder()
                            :btnIcon({
                                id = string.var("showDerbyConfig{1}", { i }),
                                icon = ctxt.isOwner and ICONS.carSensors or ICONS.add,
                                style = ctxt.isOwner and BTN_PRESETS.WARNING or BTN_PRESETS.INFO,
                                onClick = function()
                                    local fn = ctxt.isOwner and BJIVeh.replaceOrSpawnVehicle or BJIVeh.spawnNewVehicle
                                    fn(config.model, config.key or { parts = config.config })
                                end,
                            })
                            :btnIcon({
                                id = string.var("removeDerbyConfig{1}", { i }),
                                icon = ICONS.delete_forever,
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    M.data.configs:remove(i)
                                end,
                            })
                            :text(config.label)
                            :build()
                    else
                        LineBuilder()
                            :btnIcon({
                                id = "addDerbyConfig",
                                icon = ICONS.addListItem,
                                style = BTN_PRESETS.SUCCESS,
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

local function footer(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeDerbySettings",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :btnIcon({
            id = "startDerby",
            icon = ICONS.check,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                BJITx.scenario.DerbyStart(M.data.arenaIndex, M.data.lives, M.data.configs)
                onClose()
            end
        })
        :build()
end

M.onLoad = onLoad
M.onUnload = onUnload
M.open = open
M.header = header
M.body = body
M.footer = footer
M.onClose = onClose

return M
