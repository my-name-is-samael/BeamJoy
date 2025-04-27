local settings
local envUtils = require("ge/extensions/utils/EnvironmentUtils")

local function onClose()
    BJIContext.Scenario.RaceSettings = nil
    settings = nil
end

local function drawRespawnStrategies(cols)
    local comboRespawnStrategies = {}
    table.insert(comboRespawnStrategies, {
        value = nil,
        label = BJILang.get("races.settings.respawnStrategies.all"),
    })
    local selected
    for _, rs in ipairs(settings.respawnStrategies) do
        table.insert(comboRespawnStrategies, {
            value = rs,
            label = BJILang.get(string.var("races.settings.respawnStrategies.{1}", { rs })),
        })
        if rs == settings.respawnStrategy then
            selected = comboRespawnStrategies[#comboRespawnStrategies]
        end
    end

    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(BJILang.get("races.settings.respawnStrategies.title"))
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "respawnStrategies",
                        items = comboRespawnStrategies,
                        getLabelFn = function(v)
                            return v.label
                        end,
                        value = selected,
                        onChange = function(v)
                            settings.respawnStrategy = v.value
                        end,
                    })
                    :build()
            end
        }
    })
end

local function drawVehicleSelector(cols, ctxt)
    local comboVehicle = {}
    table.insert(comboVehicle, {
        value = nil,
        label = BJILang.get("races.settings.vehicles.all"),
    })
    local selected
    if ctxt.veh and not BJIVeh.isUnicycle(ctxt.veh:getID()) then
        table.insert(comboVehicle, {
            value = "model",
            label = BJILang.get("races.settings.vehicles.currentModel"),
        })
        table.insert(comboVehicle, {
            value = "config",
            label = BJILang.get("races.settings.vehicles.currentConfig"),
        })
        for _, v in ipairs(comboVehicle) do
            if v.value == settings.vehicle then
                selected = v
                break
            end
        end
    end
    if not selected then
        selected = comboVehicle[1]
    end
    if settings.vehicle ~= selected.value then
        settings.vehicle = selected.value
    end

    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(BJILang.get("races.settings.vehicles.playerVehicle"))
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "settingsVehicle",
                        items = comboVehicle,
                        getLabelFn = function(v)
                            return v.label
                        end,
                        value = selected,
                        onChange = function(v)
                            settings.vehicle = v.value
                            if settings.vehicle and ctxt.veh then
                                if BJIVeh.isModelBlacklisted(ctxt.veh.jbeam) then
                                    BJIToast.error(BJILang.get("errors.toastModelBlacklisted"))
                                else
                                    settings.vehicleModel = ctxt.veh.jbeam
                                    if settings.vehicle == "model" then
                                        settings.vehicleLabel = BJIVeh.getModelLabel(settings.vehicleModel)
                                    else
                                        settings.vehicleConfig = BJIVeh.getFullConfig(ctxt.veh.partConfig)
                                        settings.vehicleLabel = string.var("{1} {2}",
                                            { BJIVeh.getModelLabel(settings.vehicleModel), BJIVeh
                                                .getCurrentConfigLabel() })
                                    end
                                end
                            else
                                settings.vehicleLabel = nil
                                settings.vehicleConfig = nil
                            end
                        end,
                    })
                    :build()
            end,
            settings.vehicle and function()
                LineBuilder()
                    :btnIcon({
                        id = "raceSettingsVehicleRefresh",
                        icon = ICONS.refresh,
                        style = BTN_PRESETS.INFO,
                        disabled = not ctxt.veh,
                        onClick = function()
                            if BJIVeh.isModelBlacklisted(ctxt.veh.jbeam) then
                                BJIToast.error(BJILang.get("errors.toastModelBlacklisted"))
                                if settings.vehicle then
                                    settings.vehicle = nil
                                end
                            else
                                settings.vehicleModel = BJIVeh.getCurrentModel()
                                if settings.vehicle == "model" then
                                    settings.vehicleLabel = BJIVeh.getModelLabel(settings.vehicleModel)
                                else
                                    settings.vehicleConfig = BJIVeh.getFullConfig()
                                    settings.vehicleLabel = string.var("{1} {2}",
                                        { BJIVeh.getModelLabel(settings.vehicleModel), BJIVeh
                                            .getCurrentConfigLabel() })
                                end
                            end
                        end
                    })
                    :text(settings.vehicleLabel and settings.vehicleLabel or
                        BJILang.get("common.unknown"))
                    :build()
            end or nil
        }
    })
end

local function drawTimeOfDaySelector(cols)
    local presets = envUtils.timePresets()
    table.insert(presets, 1, { label = "currentTime" })

    local selected = presets[1]
    for _, p in ipairs(presets) do
        if p.label == settings.time.label then
            selected = p
            break
        end
    end

    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(BJILang.get("races.settings.time"))
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "timePreset",
                        items = presets,
                        getLabelFn = function(v)
                            return BJILang.get(string.var("presets.time.{1}", { v.label }))
                        end,
                        value = selected,
                        onChange = function(v)
                            settings.time = v
                        end,
                    })
                    :build()
            end
        }
    })
end

local function drawWeatherSelector(cols)
    local presets = envUtils.weatherPresets()
    table.insert(presets, 1, { label = "currentWeather" })

    local selected = presets[1]
    for _, p in ipairs(presets) do
        if p.label == settings.weather.label then
            selected = p
            break
        end
    end

    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(BJILang.get("races.settings.weather"))
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "weatherPreset",
                        items = presets,
                        getLabelFn = function(v)
                            return BJILang.get(string.var("presets.weather.{1}", { v.label }))
                        end,
                        value = selected,
                        onChange = function(v)
                            settings.weather = v
                        end,
                    })
                    :build()
            end
        }
    })
end

local function getPayloadSettings()
    return {
        laps = settings.loopable and settings.laps or nil,
        model = settings.vehicle ~= nil and settings.vehicleModel or nil,
        config = settings.vehicle == "config" and settings.vehicleConfig or nil,
        time = table.clone(settings.time),
        weather = table.clone(settings.weather),
        respawnStrategy = settings.respawnStrategy,
    }
end

local function drawHeader(ctxt)
    settings = BJIContext.Scenario.RaceSettings or {}
    local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
    local minimumParticipants = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS
    if settings.multi and potentialPlayers < minimumParticipants then
        -- when a player leaves then there are not enough players to start
        BJIToast.warning(BJILang.get("races.preparation.notEnoughPlayers"))
        onClose()
    end

    LineBuilder()
        :text((settings and settings.multi) and
            BJILang.get("races.preparation.multiplayer") or
            BJILang.get("races.preparation.singleplayer"),
            TEXT_COLORS.HIGHLIGHT)
        :build()

    LineBuilder()
        :text(string.var("{1} \"{2}\"", { BJILang.get("races.play.race"), settings and settings.raceName }))
        :build()
end

local function drawBody(ctxt)
    if not settings then
        return
    end
    local labelWidth = 0
    local labels = {
        "races.edit.laps",
        "races.settings.respawnStrategies.title",
    }
    if settings.multi then
        table.insert(labels, "races.settings.vehicles.playerVehicle")
        table.insert(labels, "races.settings.time")
        table.insert(labels, "races.settings.weather")
    end
    for _, key in ipairs(labels) do
        local label = BJILang.get(key)
        local w = GetColumnTextWidth(label)
        if w > labelWidth then
            labelWidth = w
        end
    end

    local thirdColumnWidth = nil
    if settings.vehicle then
        thirdColumnWidth = -1
    elseif settings.laps >= 20 then
        thirdColumnWidth = GetColumnTextWidth(BJILang.get("races.settings.manyLapsWarning"))
    end

    local cols = ColumnsBuilder("BJIRaceSettings", { labelWidth, -1, thirdColumnWidth })

    if settings.loopable then
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("races.edit.laps"))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "raceSettingsLaps",
                            type = "int",
                            value = settings.laps,
                            min = 1,
                            max = 50,
                            step = 1,
                            onUpdate = function(val)
                                settings.laps = val
                            end,
                        })
                        :build()
                end,
                settings.laps >= 20 and function()
                    LineBuilder()
                        :text(BJILang.get("races.settings.manyLapsWarning"), TEXT_COLORS.HIGHLIGHT)
                        :build()
                end or nil
            }
        })
    end

    drawRespawnStrategies(cols)
    if settings.multi then
        drawVehicleSelector(cols, ctxt)
        drawTimeOfDaySelector(cols)
        drawWeatherSelector(cols)
    end

    cols:build()
end

local function drawFooter(ctxt)
    if not settings then
        return
    end
    local line = LineBuilder()
        :btnIcon({
            id = "cancelRaceStart",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.Scenario.RaceSettings = nil
            end
        })
    if settings.multi and BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) then
        line:btnIcon({
            id = "voteRaceStart",
            icon = ICONS.event_available,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                BJITx.voterace.start(settings.raceID, true, getPayloadSettings())
                BJIContext.Scenario.RaceSettings = nil
            end
        })
    end
    if (settings.multi and BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO)) or
        (not settings.multi and BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO)) then
        line:btnIcon({
            id = "raceStart",
            icon = ICONS.videogame_asset,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                if settings.multi then
                    BJITx.voterace.start(settings.raceID, false, getPayloadSettings())
                    BJIContext.Scenario.RaceSettings = nil
                else
                    BJITx.scenario.RaceDetails(settings.raceID)
                    BJIAsync.task(function()
                        return BJIContext.Scenario.RaceDetails ~= nil
                    end, function()
                        local raceData = BJIContext.Scenario.RaceDetails
                        if raceData then
                            if BJIScenario.isFreeroam() then
                                BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).initRace(
                                    ctxt,
                                    {
                                        laps = raceData.loopable and settings.laps or nil,
                                        respawnStrategy = settings.respawnStrategy,
                                    },
                                    raceData
                                )
                            end
                            BJIContext.Scenario.RaceDetails = nil
                            BJIContext.Scenario.RaceSettings = nil
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

return {
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
    onClose = onClose,
}
