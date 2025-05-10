---@class RaceSettings
---@field multi boolean
---@field raceID string
---@field raceName string
---@field loopable boolean
---@field laps integer
---@field defaultRespawnStrategy? string
---@field respawnStrategies string[]
---@field vehicleMode string|nil

local envUtils = require("ge/extensions/utils/EnvironmentUtils")
local M = {
    VEHICLE_MODES = {
        ALL = nil,
        MODEL = "model",
        CONFIG = "config",
    },
    show = false,

    ---@type RaceSettings
    settings = {
        multi = false,
        raceID = "",
        raceName = "",
        loopable = false,
        laps = 1,
        defaultRespawnStrategy = nil,
        respawnStrategies = {},
        vehicleMode = nil,
    },

    cache = {
        data = {
            currentVeh = {
                model = nil,
                modelLabel = nil,
                config = nil,
            },

            comboRespawnStrategies = {},
            respawnStrategySelected = nil,

            ---@type {value?: string, label: string}[]
            comboVehicle = {},
            ---@type {value?: string, label: string}?
            vehicleSelected = nil,

            showVoteBtn = false,
            showStartBtn = false,
        },
        labels = {
            unknown = "",
            title = "",
            raceName = "",
            laps = "",
            manyLapsWarning = "",
            respawnStrategies = {
                title = "",
                all = "",
                norespawn = "",
                lastcheckpoint = "",
                stand = "",
            },
            vehicle = {
                title = "",
                all = "",
                currentModel = "",
                currentConfig = "",
            },
        },
        widths = {
            labels = 0,
        },
    },
}

local function updateLabels()
    M.cache.labels.unknown = BJILang.get("common.unknown")

    M.cache.labels.title = M.settings.multi and
        BJILang.get("races.preparation.multiplayer") or
        BJILang.get("races.preparation.singleplayer")
    M.cache.labels.raceName = string.var("{1} \"{2}\"", { BJILang.get("races.play.race"), M.settings.raceName })

    M.cache.labels.laps = BJILang.get("races.edit.laps")
    M.cache.labels.manyLapsWarning = BJILang.get("races.settings.manyLapsWarning")

    M.cache.labels.respawnStrategies.title = BJILang.get("races.settings.respawnStrategies.title")
    M.cache.labels.respawnStrategies.all = BJILang.get("races.settings.respawnStrategies.all")
    M.cache.labels.respawnStrategies.norespawn = BJILang.get("races.settings.respawnStrategies.norespawn")
    M.cache.labels.respawnStrategies.lastcheckpoint = BJILang.get("races.settings.respawnStrategies.lastcheckpoint")
    M.cache.labels.respawnStrategies.stand = BJILang.get("races.settings.respawnStrategies.stand")

    M.cache.labels.vehicle.title = BJILang.get("races.settings.vehicles.playerVehicle")
    M.cache.labels.vehicle.all = BJILang.get("races.settings.vehicles.all")
    M.cache.labels.vehicle.currentModel = BJILang.get("races.settings.vehicles.currentModel")
    M.cache.labels.vehicle.currentConfig = BJILang.get("races.settings.vehicles.currentConfig")
end

local function updateWidths()
    M.cache.widths.labels = 0
    table.forEach({
        M.cache.labels.laps,
        M.cache.labels.respawnStrategies.title,
        M.settings.multi and M.cache.labels.vehicle.title or nil,
    }, function(label)
        local w = GetColumnTextWidth(label or "")
        if w > M.cache.widths.labels then
            M.cache.widths.labels = w
        end
    end)
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()

    M.cache.data.currentVeh.model = nil
    M.cache.data.currentVeh.modelLabel = nil
    M.cache.data.currentVeh.config = nil
    M.cache.data.comboRespawnStrategies = {}
    M.cache.data.comboVehicle = {}
    M.cache.data.showVoteBtn = false
    M.cache.data.showStartBtn = false

    -- autoclose checks
    if M.show and (not BJIScenario.isFreeroam() or (
            not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) and
            not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
            not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO)
        )) then
        M.onClose()
        return
    elseif not M.settings.multi and not ctxt.isOwner then
        M.onClose()
        return
    elseif M.settings.multi and BJIPerm.getCountPlayersCanSpawnVehicle() < BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS then
        -- when a player leaves then there are not enough players to start
        BJIToast.warning(BJILang.get("races.preparation.notEnoughPlayers"))
        M.onClose()
        return
    end

    -- respawn strategies
    for _, rs in ipairs(M.settings.respawnStrategies) do
        local comboElem = {
            value = rs,
            label = M.cache.labels.respawnStrategies[rs],
        }
        table.insert(M.cache.data.comboRespawnStrategies, comboElem)
        if not M.cache.data.respawnStrategySelected and rs == M.settings.defaultRespawnStrategy then
            M.cache.data.respawnStrategySelected = comboElem
        end
    end
    if not M.cache.data.respawnStrategySelected or not table.find(M.cache.data.comboRespawnStrategies, function(crs)
            return crs.value == M.cache.data.respawnStrategySelected.value
        end) then
        M.cache.data.respawnStrategySelected = M.cache.data.comboRespawnStrategies[1]
    end

    if M.settings.multi then
        -- vehicle combo
        table.insert(M.cache.data.comboVehicle, {
            value = M.VEHICLE_MODES.ALL,
            label = M.cache.labels.vehicle.all,
        })
        if ctxt.veh and not BJIVeh.isUnicycle(ctxt.veh:getID()) and not BJIVeh.isModelBlacklisted(ctxt.veh.jbeam) then
            table.insert(M.cache.data.comboVehicle, {
                value = M.VEHICLE_MODES.MODEL,
                label = M.cache.labels.vehicle.currentModel,
            })
            table.insert(M.cache.data.comboVehicle, {
                value = M.VEHICLE_MODES.CONFIG,
                label = M.cache.labels.vehicle.currentConfig,
            })
            if not M.cache.data.vehicleSelected then
                if M.settings.vehicleMode then
                    M.cache.data.vehicleSelected = table.find(M.cache.data.comboVehicle, function(v)
                        return v.value == M.settings.vehicleMode
                    end) or M.cache.data.comboVehicle[1]
                end
            elseif not table.find(M.cache.data.comboVehicle, function(v)
                    return v.value == M.cache.data.vehicleSelected.value
                end) then
                M.cache.data.vehicleSelected = M.cache.data.comboVehicle[1]
            end
        end
        if not M.cache.data.vehicleSelected or not table.find(M.cache.data.comboVehicle, function(vm)
                return vm.value == M.cache.data.vehicleSelected.value
            end) then
            M.cache.data.vehicleSelected = M.cache.data.comboVehicle[1]
        end
    end

    -- current veh
    if ctxt.veh then
        M.cache.data.currentVeh.model = ctxt.veh.jbeam
        M.cache.data.currentVeh.modelLabel = BJIVeh.getModelLabel(M.cache.data.currentVeh.model) or
            M.cache.labels.unknown

        M.cache.data.currentVeh.config = BJIVeh.getFullConfig(ctxt.veh.partConfig)
        local configLabel = BJIVeh.getCurrentConfigLabel()
        M.cache.data.currentVeh.configLabel = configLabel and string.var("{1} {2}",
            { M.cache.data.currentVeh.modelLabel, configLabel }) or M.cache.labels.unknown
    else
        M.cache.data.currentVeh.model = nil
        M.cache.data.currentVeh.modelLabel = nil
        M.cache.data.currentVeh.config = nil
        M.cache.data.currentVeh.configLabel = nil
    end

    M.cache.data.showVoteBtn = M.settings.multi and BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO)
    M.cache.data.showStartBtn = (M.settings.multi and BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO)) or
        (not M.settings.multi and BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO))
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateWidths()
    end))

    updateWidths()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, updateWidths))

    updateCache()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.VEHICLE_SPAWNED,
        BJIEvents.EVENTS.VEHICLE_UPDATED,
        BJIEvents.EVENTS.VEHICLE_REMOVED,
        BJIEvents.EVENTS.VEHICLE_SPEC_CHANGED,
        BJIEvents.EVENTS.PERMISSION_CHANGED,
        BJIEvents.EVENTS.SCENARIO_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache))
    listeners:insert(BJIEvents.addListener(BJIEvents.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJICache.CACHES.RACES or data.cache == BJICache.CACHES.PLAYERS then
            updateCache(ctxt)
        end
    end))
end

local function onUnload()
    listeners:forEach(BJIEvents.removeListener)
end

local function drawRespawnStrategies(cols)
    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(M.cache.labels.respawnStrategies.title)
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "respawnStrategies",
                        items = M.cache.data.comboRespawnStrategies,
                        getLabelFn = function(v)
                            return v.label
                        end,
                        value = M.cache.data.respawnStrategySelected,
                        onChange = function(v)
                            M.cache.data.respawnStrategySelected = v
                        end,
                    })
                    :build()
            end
        }
    })
end

local function drawVehicleSelector(cols, ctxt)
    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(M.cache.labels.vehicle.title)
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "settingsVehicle",
                        items = M.cache.data.comboVehicle,
                        getLabelFn = function(v)
                            return v.label
                        end,
                        value = M.cache.data.vehicleSelected,
                        onChange = function(v)
                            M.cache.data.vehicleSelected = v
                        end,
                    })
                    :build()
            end
        }
    })
    if M.cache.data.vehicleSelected.value ~= M.VEHICLE_MODES.ALL then
        cols:addRow({
            cells = {
                nil,
                function()
                    LineBuilder()
                        :text(M.cache.data.vehicleSelected.value == M.VEHICLE_MODES.MODEL and
                            M.cache.data.currentVeh.modelLabel or
                            M.cache.data.currentVeh.configLabel)
                        :build()
                end
            }
        })
    end
end

local function drawHeader()
    LineBuilder():text(M.cache.labels.title, TEXT_COLORS.HIGHLIGHT):build()
    LineBuilder():text(M.cache.labels.raceName):build()
end

local function drawBody(ctxt)
    local cols = ColumnsBuilder("BJIRaceSettings", { M.cache.widths.labels, -1 })

    if M.settings.loopable then
        cols:addRow({
            cells = {
                function()
                    LineBuilder():text(M.cache.labels.laps):build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "raceSettingsLaps",
                            type = "int",
                            value = M.settings.laps,
                            min = 1,
                            max = 50,
                            step = 1,
                            onUpdate = function(val)
                                M.settings.laps = val
                            end,
                        })
                        :build()
                end
            }
        })
        if M.settings.laps >= 20 then
            cols:addRow({
                cells = {
                    nil,
                    function()
                        LineBuilder():text(M.cache.labels.manyLapsWarning, TEXT_COLORS.HIGHLIGHT):build()
                    end
                }
            })
        end
    end

    drawRespawnStrategies(cols)
    if M.settings.multi then
        drawVehicleSelector(cols, ctxt)
    end

    cols:build()
end

local function getPayloadSettings()
    return {
        laps = M.settings.loopable and M.settings.laps or nil,
        model = M.cache.data.vehicleSelected.value ~= M.VEHICLE_MODES.ALL and M.cache.data.currentVeh.model or nil,
        config = M.cache.data.vehicleSelected.value == M.VEHICLE_MODES.CONFIG and M.cache.data.currentVeh.config or nil,
        respawnStrategy = M.cache.data.respawnStrategySelected.value,
    }
end

local function drawFooter(ctxt)
    if not M.settings then
        return
    end
    local line = LineBuilder()
        :btnIcon({
            id = "cancelRaceStart",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                M.onClose()
            end
        })
    if M.cache.data.showVoteBtn then
        line:btnIcon({
            id = "voteRaceStart",
            icon = ICONS.event_available,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                BJITx.voterace.start(M.settings.raceID, true, getPayloadSettings())
                M.onClose()
            end
        })
    end
    if M.cache.data.showStartBtn then
        line:btnIcon({
            id = "raceStart",
            icon = ICONS.videogame_asset,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                if M.settings.multi then
                    BJITx.voterace.start(M.settings.raceID, false, getPayloadSettings())
                    M.onClose()
                else
                    BJITx.scenario.RaceDetails(M.settings.raceID)
                    BJIAsync.task(function()
                        return BJIContext.Scenario.RaceDetails ~= nil
                    end, function()
                        local raceData = BJIContext.Scenario.RaceDetails
                        if raceData then
                            if BJIScenario.isFreeroam() then
                                BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).initRace(
                                    ctxt,
                                    {
                                        laps = raceData.loopable and M.settings.laps or nil,
                                        respawnStrategy = M.cache.data.respawnStrategySelected.value,
                                    },
                                    raceData
                                )
                            end
                            BJIContext.Scenario.RaceDetails = nil
                            M.onClose()
                        else
                            BJIToast.error(BJILang.get("errors.invalidData"))
                        end
                    end, "BJIRaceGetDetails")
                end
            end
        })
    end
    line:build()
end

local function onClose()
    M.show = false
end

---@param raceSettings RaceSettings
local function open(raceSettings)
    if #raceSettings.respawnStrategies == 0 then
        LogError("No respawn strategies found")
        return
    end

    M.settings = raceSettings

    if BJIScenario.isFreeroam() and
        (BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) or
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO)) then
        if M.show then
            --if already open, update data
            updateLabels()
            updateWidths()
            updateCache()
        end
        M.show = true
    else
        onClose()
    end
end

M.onLoad = onLoad
M.onUnload = onUnload

M.header = drawHeader
M.body = drawBody
M.footer = drawFooter

M.onClose = onClose
M.open = open

return M
