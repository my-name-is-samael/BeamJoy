---@class RaceSettings
---@field multi boolean
---@field raceID integer
---@field raceName string
---@field loopable boolean
---@field laps integer
---@field defaultRespawnStrategy? string
---@field respawnStrategies string[]
---@field vehicleMode string|nil

---@class BJIWindowRaceSettings : BJIWindow
local W = {
    name = "RaceSettings",
    w = 390,
    h = 220,

    VEHICLE_MODES = {
        ALL = nil,
        MODEL = "model",
        CONFIG = "config",
    },
    show = false,

    ---@type RaceSettings
    settings = {
        multi = false,
        raceID = -1,
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
    W.cache.labels.unknown = BJI.Managers.Lang.get("common.unknown")

    W.cache.labels.title = W.settings.multi and
        BJI.Managers.Lang.get("races.preparation.multiplayer") or
        BJI.Managers.Lang.get("races.preparation.singleplayer")
    W.cache.labels.raceName = string.var("{1} \"{2}\"", { BJI.Managers.Lang.get("races.play.race"), W.settings.raceName })

    W.cache.labels.laps = BJI.Managers.Lang.get("races.edit.laps")
    W.cache.labels.manyLapsWarning = BJI.Managers.Lang.get("races.settings.manyLapsWarning")

    W.cache.labels.respawnStrategies.title = BJI.Managers.Lang.get("races.settings.respawnStrategies.title")
    W.cache.labels.respawnStrategies.all = BJI.Managers.Lang.get("races.settings.respawnStrategies.all")
    W.cache.labels.respawnStrategies.norespawn = BJI.Managers.Lang.get("races.settings.respawnStrategies.norespawn")
    W.cache.labels.respawnStrategies.lastcheckpoint = BJI.Managers.Lang.get(
    "races.settings.respawnStrategies.lastcheckpoint")
    W.cache.labels.respawnStrategies.stand = BJI.Managers.Lang.get("races.settings.respawnStrategies.stand")

    W.cache.labels.vehicle.title = BJI.Managers.Lang.get("races.settings.vehicles.playerVehicle")
    W.cache.labels.vehicle.all = BJI.Managers.Lang.get("races.settings.vehicles.all")
    W.cache.labels.vehicle.currentModel = BJI.Managers.Lang.get("races.settings.vehicles.currentModel")
    W.cache.labels.vehicle.currentConfig = BJI.Managers.Lang.get("races.settings.vehicles.currentConfig")
end

local function updateWidths()
    W.cache.widths.labels = 0
    table.forEach({
        W.cache.labels.laps,
        W.cache.labels.respawnStrategies.title,
        W.settings.multi and W.cache.labels.vehicle.title or nil,
    }, function(label)
        local w = BJI.Utils.Common.GetColumnTextWidth(label or "")
        if w > W.cache.widths.labels then
            W.cache.widths.labels = w
        end
    end)
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.cache.data.currentVeh.model = nil
    W.cache.data.currentVeh.modelLabel = nil
    W.cache.data.currentVeh.config = nil
    W.cache.data.comboRespawnStrategies = {}
    W.cache.data.comboVehicle = {}
    W.cache.data.showVoteBtn = false
    W.cache.data.showStartBtn = false

    -- autoclose checks
    if W.show and (not BJI.Managers.Scenario.isFreeroam() or (
            not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) and
            not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
            not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO)
        )) then
        W.onClose()
        return
    elseif not W.settings.multi and not ctxt.isOwner then
        W.onClose()
        return
    elseif W.settings.multi and BJI.Managers.Perm.getCountPlayersCanSpawnVehicle() < BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS then
        -- when a player leaves then there are not enough players to start
        BJI.Managers.Toast.warning(BJI.Managers.Lang.get("races.preparation.notEnoughPlayers"))
        W.onClose()
        return
    end

    -- respawn strategies
    for _, rs in ipairs(W.settings.respawnStrategies) do
        local comboElem = {
            value = rs,
            label = W.cache.labels.respawnStrategies[rs],
        }
        table.insert(W.cache.data.comboRespawnStrategies, comboElem)
        if not W.cache.data.respawnStrategySelected and rs == W.settings.defaultRespawnStrategy then
            W.cache.data.respawnStrategySelected = comboElem
        end
    end
    if not W.cache.data.respawnStrategySelected or not table.find(W.cache.data.comboRespawnStrategies, function(crs)
            return crs.value == W.cache.data.respawnStrategySelected.value
        end) then
        W.cache.data.respawnStrategySelected = W.cache.data.comboRespawnStrategies[1]
    end

    if W.settings.multi then
        -- vehicle combo
        table.insert(W.cache.data.comboVehicle, {
            value = W.VEHICLE_MODES.ALL,
            label = W.cache.labels.vehicle.all,
        })
        if ctxt.veh and not BJI.Managers.Veh.isUnicycle(ctxt.veh:getID()) and not BJI.Managers.Veh.isModelBlacklisted(ctxt.veh.jbeam) then
            table.insert(W.cache.data.comboVehicle, {
                value = W.VEHICLE_MODES.MODEL,
                label = W.cache.labels.vehicle.currentModel,
            })
            table.insert(W.cache.data.comboVehicle, {
                value = W.VEHICLE_MODES.CONFIG,
                label = W.cache.labels.vehicle.currentConfig,
            })
            if not W.cache.data.vehicleSelected then
                if W.settings.vehicleMode then
                    W.cache.data.vehicleSelected = table.find(W.cache.data.comboVehicle, function(v)
                        return v.value == W.settings.vehicleMode
                    end) or W.cache.data.comboVehicle[1]
                end
            elseif not table.find(W.cache.data.comboVehicle, function(v)
                    return v.value == W.cache.data.vehicleSelected.value
                end) then
                W.cache.data.vehicleSelected = W.cache.data.comboVehicle[1]
            end
        end
        if not W.cache.data.vehicleSelected or not table.find(W.cache.data.comboVehicle, function(vm)
                return vm.value == W.cache.data.vehicleSelected.value
            end) then
            W.cache.data.vehicleSelected = W.cache.data.comboVehicle[1]
        end
    end

    -- current veh
    if ctxt.veh then
        W.cache.data.currentVeh.model = ctxt.veh.jbeam
        W.cache.data.currentVeh.modelLabel = BJI.Managers.Veh.getModelLabel(W.cache.data.currentVeh.model) or
            W.cache.labels.unknown

        W.cache.data.currentVeh.config = BJI.Managers.Veh.getFullConfig(ctxt.veh.partConfig)
        local configLabel = BJI.Managers.Veh.getCurrentConfigLabel()
        W.cache.data.currentVeh.configLabel = configLabel and string.var("{1} {2}",
            { W.cache.data.currentVeh.modelLabel, configLabel }) or W.cache.labels.unknown
    else
        W.cache.data.currentVeh.model = nil
        W.cache.data.currentVeh.modelLabel = nil
        W.cache.data.currentVeh.config = nil
        W.cache.data.currentVeh.configLabel = nil
    end

    W.cache.data.showVoteBtn = W.settings.multi and
    BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)
    W.cache.data.showStartBtn = (W.settings.multi and BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO)) or
        (not W.settings.multi and BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO))
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateWidths()
    end))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateWidths))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.NG_VEHICLE_REPLACED,
        BJI.Managers.Events.EVENTS.VEHICLE_REMOVED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI.Managers.Cache.CACHES.RACES or data.cache == BJI.Managers.Cache.CACHES.PLAYERS then
            updateCache(ctxt)
        end
    end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function drawRespawnStrategies(cols)
    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(W.cache.labels.respawnStrategies.title)
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "respawnStrategies",
                        items = W.cache.data.comboRespawnStrategies,
                        getLabelFn = function(v)
                            return v.label
                        end,
                        value = W.cache.data.respawnStrategySelected,
                        onChange = function(v)
                            W.cache.data.respawnStrategySelected = v
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
                    :text(W.cache.labels.vehicle.title)
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "settingsVehicle",
                        items = W.cache.data.comboVehicle,
                        getLabelFn = function(v)
                            return v.label
                        end,
                        value = W.cache.data.vehicleSelected,
                        onChange = function(v)
                            W.cache.data.vehicleSelected = v
                        end,
                    })
                    :build()
            end
        }
    })
    if W.cache.data.vehicleSelected.value ~= W.VEHICLE_MODES.ALL then
        cols:addRow({
            cells = {
                nil,
                function()
                    LineBuilder()
                        :text(W.cache.data.vehicleSelected.value == W.VEHICLE_MODES.MODEL and
                            W.cache.data.currentVeh.modelLabel or
                            W.cache.data.currentVeh.configLabel)
                        :build()
                end
            }
        })
    end
end

local function drawHeader()
    LineBuilder():text(W.cache.labels.title, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT):build()
    LineBuilder():text(W.cache.labels.raceName):build()
end

local function drawBody(ctxt)
    local cols = ColumnsBuilder("BJIRaceSettings", { W.cache.widths.labels, -1 })

    if W.settings.loopable then
        cols:addRow({
            cells = {
                function()
                    LineBuilder():text(W.cache.labels.laps):build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "raceSettingsLaps",
                            type = "int",
                            value = W.settings.laps,
                            min = 1,
                            max = 50,
                            step = 1,
                            onUpdate = function(val)
                                W.settings.laps = val
                            end,
                        })
                        :build()
                end
            }
        })
        if W.settings.laps >= 20 then
            cols:addRow({
                cells = {
                    nil,
                    function()
                        LineBuilder():text(W.cache.labels.manyLapsWarning, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT):build()
                    end
                }
            })
        end
    end

    drawRespawnStrategies(cols)
    if W.settings.multi then
        drawVehicleSelector(cols, ctxt)
    end

    cols:build()
end

local function getPayloadSettings()
    return {
        laps = W.settings.loopable and W.settings.laps or nil,
        model = W.cache.data.vehicleSelected.value ~= W.VEHICLE_MODES.ALL and W.cache.data.currentVeh.model or nil,
        config = W.cache.data.vehicleSelected.value == W.VEHICLE_MODES.CONFIG and W.cache.data.currentVeh.config or nil,
        respawnStrategy = W.cache.data.respawnStrategySelected.value,
    }
end

local function drawFooter(ctxt)
    if not W.settings then
        return
    end
    local line = LineBuilder()
        :btnIcon({
            id = "cancelRaceStart",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = function()
                W.onClose()
            end
        })
    if W.cache.data.showVoteBtn then
        line:btnIcon({
            id = "voteRaceStart",
            icon = ICONS.event_available,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            onClick = function()
                BJI.Tx.voterace.start(W.settings.raceID, true, getPayloadSettings())
                W.onClose()
            end
        })
    end
    if W.cache.data.showStartBtn then
        line:btnIcon({
            id = "raceStart",
            icon = ICONS.videogame_asset,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            onClick = function()
                if W.settings.multi then
                    BJI.Tx.voterace.start(W.settings.raceID, false, getPayloadSettings())
                    W.onClose()
                else
                    BJI.Tx.scenario.RaceDetails(W.settings.raceID, function(raceData)
                        if raceData then
                            if BJI.Managers.Scenario.isFreeroam() then
                                BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_SOLO).initRace(
                                    ctxt,
                                    {
                                        laps = raceData.loopable and W.settings.laps or nil,
                                        respawnStrategy = W.cache.data.respawnStrategySelected.value,
                                    },
                                    raceData
                                )
                            end
                            W.onClose()
                        else
                            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.invalidData"))
                        end
                    end)
                end
            end
        })
    end
    line:build()
end

local function onClose()
    W.show = false
end

---@param raceSettings RaceSettings
local function open(raceSettings)
    if #raceSettings.respawnStrategies == 0 then
        LogError("No respawn strategies found")
        return
    end

    W.settings = raceSettings

    if BJI.Managers.Scenario.isFreeroam() and
        (BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) or
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO)) then
        if W.show then
            --if already open, update data
            updateLabels()
            updateWidths()
            updateCache()
        end
        W.show = true
    else
        onClose()
    end
end

W.onLoad = onLoad
W.onUnload = onUnload

W.header = drawHeader
W.body = drawBody
W.footer = drawFooter

W.onClose = onClose
W.open = open
W.getState = function() return W.show end

return W
