local function getMeEntry(ctxt)
    local meEntry = {
        label = BJILang.get("menu.me.title"),
        elems = {},
    }

    -- SETTINGS
    table.insert(meEntry.elems, {
        label = BJILang.get("menu.me.settings"),
        active = BJIContext.UserSettings.open,
        onClick = function()
            BJIContext.UserSettings.open = not BJIContext.UserSettings.open
        end
    })

    -- VEHICLE SELECTOR
    if BJIPerm.canSpawnVehicle() and
        BJIScenario.canSelectVehicle() then
        table.insert(meEntry.elems, {
            label = BJILang.get("menu.me.vehicleSelector"),
            active = BJIVehSelector.state,
            onClick = function()
                if BJIVehSelector.state then
                    BJIVehSelector.tryClose()
                else
                    local models = BJIScenario.getModelList()
                    if tlength(models) > 0 then
                        BJIVehSelector.open(models, true)
                    end
                end
            end
        })

        -- CLEAR GPS
        if BJIGPS.isClearable() then
            table.insert(meEntry.elems, {
                label = BJILang.get("menu.me.clearGPS"),
                onClick = BJIGPS.clear,
            })
        end
    end

    return #meEntry.elems > 0 and meEntry or nil
end

local function getVoteEntry(ctxt)
    local votesEntry = {
        label = BJILang.get("menu.vote.title"),
        elems = {}
    }

    -- VOTE MAP
    if BJIVote.Map.canStartVote() and
        BJIScenario.isFreeroam() and
        BJIContext.Maps then
        local maps = {}
        local customMapLabel = BJILang.get("menu.vote.mapCustom")
        for mapName, map in pairs(BJIContext.Maps.Data) do
            table.insert(maps, {
                label = map.custom and svar("{1} ({2})", { map.label, customMapLabel }) or map.label,
                onClick = function()
                    BJITx.votemap.start(mapName)
                end
            })
        end
        table.sort(maps, function(a, b)
            return a.label < b.label
        end)
        table.insert(votesEntry.elems, {
            label = BJILang.get("menu.vote.map"),
            elems = maps
        })
    end

    --VOTE RACE
    local function openRaceVote(raceID)
        local race
        for _, r in ipairs(BJIContext.Scenario.Data.Races) do
            if r.id == raceID then
                race = r
                break
            end
        end
        if not race then
            BJIToast.error(BJILang.get("races.edit.invalidRace"))
            return
        end

        local strategies = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).RESPAWN_STRATEGIES
        local respawnStrategies = {}
        for _, rs in pairs(strategies) do
            if race.hasStand or rs ~= strategies.STAND then
                table.insert(respawnStrategies, rs)
            end
        end

        BJIContext.Scenario.RaceSettings = {
            multi = true,
            raceID = race.id,
            raceName = race.name,
            loopable = race.loopable,
            laps = 1,
            respawnStrategy = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).RESPAWN_STRATEGIES.LAST_CHECKPOINT,
            respawnStrategies = respawnStrategies,
            vehicle = nil,
            vehicleModel = ctxt.veh and ctxt.veh.jbeam or nil,
            vehicleConfig = BJIVeh.getFullConfig(ctxt.veh and ctxt.veh.partConfig or nil),
            vehicleLabel = nil,
            time = {
                label = nil,
                ToD = nil,
            },
            weather = {
                label = nil,
                keys = nil,
            },
        }
    end
    local voteRacePerm = BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO)
    if voteRacePerm and
        BJIScenario.isFreeroam() and
        BJIVote.Race.canStartVote() and
        BJIContext.Scenario.Data.Races and
        #BJIContext.Scenario.Data.Races > 0 then
        local races = {}
        for _, race in ipairs(BJIContext.Scenario.Data.Races) do
            if race.places > 1 then
                local disabledSuffix = ""
                if race.enabled == false then
                    disabledSuffix = svar(", {1}", { BJILang.get("common.disabled") })
                end
                table.insert(races, {
                    label = svar("{1} ({2}{3})", {
                        race.name,
                        svar(BJILang.get("races.preparation.places"),
                            { places = race.places }),
                        disabledSuffix,
                    }),
                    onClick = function()
                        openRaceVote(race.id)
                    end
                })
            end
        end
        table.sort(races, function(a, b)
            return a.label < b.label
        end)
        table.insert(votesEntry.elems, {
            label = BJILang.get("menu.vote.race"),
            elems = races
        })
    end

    -- SPEED
    if not BJIScenario.isServerScenarioInProgress() and
        BJIVote.Speed.canStartVote() then
        table.insert(votesEntry.elems, {
            label = BJILang.get("menu.vote.voteSpeed"),
            onClick = function()
                BJITx.scenario.SpeedStart(true)
            end,
        })
    end

    return #votesEntry.elems > 0 and votesEntry or nil
end

local function getScenarioEntry(ctxt)
    local scenarioEntry = {
        label = BJILang.get("menu.scenario.title"),
        elems = {},
    }

    -- SOLO RACE
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.RACE_SOLO) and
        BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).canChangeTo(ctxt) then
        local races = {}
        for _, race in ipairs(BJIContext.Scenario.Data.Races) do
            if race.enabled then
                local strategies = BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).RESPAWN_STRATEGIES
                local respawnStrategies = {}
                for _, rs in pairs(strategies) do
                    if race.hasStand or not tincludes({ strategies.STAND }, rs) then
                        table.insert(respawnStrategies, rs)
                    end
                end
                table.insert(races, {
                    label = race.name,
                    onClick = function()
                        BJIContext.Scenario.RaceSettings = {
                            multi = false,
                            raceID = race.id,
                            raceName = race.name,
                            loopable = race.loopable,
                            laps = 1,
                            respawnStrategy = BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).RESPAWN_STRATEGIES
                                .LAST_CHECKPOINT,
                            respawnStrategies = respawnStrategies,
                        }
                    end
                })
            end
        end
        table.sort(races, function(a, b)
            return a.label < b.label
        end)
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startSoloRace"),
            elems = races
        })
    elseif BJIScenario.is(BJIScenario.TYPES.RACE_SOLO) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopSoloRace"),
            onClick = function()
                BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
            end,
        })
    end

    -- VEHICLE DELIVERY
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY).canChangeTo(ctxt) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startVehicleDelivery"),
            onClick = function()
                BJIScenario.switchScenario(BJIScenario.TYPES.VEHICLE_DELIVERY, ctxt)
            end,
        })
    elseif BJIScenario.is(BJIScenario.TYPES.VEHICLE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopDelivery"),
            onClick = BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY).onStopDelivery,
        })
    end

    -- PACKAGE DELIVERY
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY).canChangeTo(ctxt) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startPackageDelivery"),
            onClick = function()
                BJIAsync.delayTask(function()
                    BJIScenario.switchScenario(BJIScenario.TYPES.PACKAGE_DELIVERY, ctxt)
                end, 0, "BJIPackageDeliveryStart")
            end,
        })
    elseif BJIScenario.is(BJIScenario.TYPES.PACKAGE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopDelivery"),
            onClick = BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY).onStopDelivery,
        })
    end

    -- DELIVERY MULTI
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI) and
        BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI).canChangeTo(ctxt) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.joinDeliveryMulti"),
            onClick = function()
                BJITx.scenario.DeliveryMultiJoin(ctxt.veh:getID(), ctxt.vehPosRot.pos)
            end,
        })
    elseif BJIScenario.is(BJIScenario.TYPES.DELIVERY_MULTI) and
        BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.leaveDeliveryMulti"),
            onClick = function()
                BJITx.scenario.DeliveryMultiLeave()
            end,
        })
    end

    -- BUS MISSION
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION) and
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).canChangeTo(ctxt) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startBusMission"),
            onClick = function()
                BJIAsync.delayTask(function()
                    BJIScenario.switchScenario(BJIScenario.TYPES.BUS_MISSION, ctxt)
                end, 0, "BJIBusMissionStart")
            end,
        })
    elseif BJIScenario.is(BJIScenario.TYPES.BUS_MISSION) and
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopBusMission"),
            onClick = BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).onStopBusMission,
        })
    end

    -- SPEED
    if not BJIScenario.isServerScenarioInProgress() and
        tlength(BJIContext.Players) >= 2 and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startSpeed"),
            onClick = function()
                BJITx.scenario.SpeedStart(false)
            end,
        })
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.SPEED) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopSpeed"),
            onClick = BJITx.scenario.SpeedStop,
        })
    end

    -- STOP MULTI RACE
    if BJIScenario.is(BJIScenario.TYPES.RACE_MULTI) and
        (BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) or
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO)) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.raceStop"),
            onClick = BJITx.scenario.RaceMultiStop,
        })
    end

    -- HUNTER
    if not BJIScenario.isServerScenarioInProgress() and
        tlength(BJIContext.Players) >= 3 and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIContext.Scenario.Data.Hunter and
        BJIContext.Scenario.Data.Hunter.enabled then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startHunter"),
            active = BJIContext.Scenario.HunterSettings,
            onClick = function()
                if BJIContext.Scenario.HunterSettings then
                    BJIContext.Scenario.HunterSettings = nil
                else
                    local scHunter = BJIScenario.get(BJIScenario.TYPES.HUNTER)
                    BJIContext.Scenario.HunterSettings = {
                        waypoints = scHunter.settings.waypoints,
                        huntedConfig = tdeepcopy(scHunter.settings.huntedConfig),
                        hunterConfigs = tdeepcopy(scHunter.settings.hunterConfigs),
                    }
                end
            end,
        })
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.HUNTER) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopHunter"),
            onClick = BJITx.scenario.HunterStop,
        })
    end

    -- DERBY
    local function openDerbySettings(indexArena)
        BJIContext.Scenario.DerbyEdit = nil
        local arena = BJIContext.Scenario.Data.Derby[indexArena]
        if not arena then
            return
        end

        local existing = BJIContext.Scenario.DerbySettings
        if not existing then
            BJIContext.Scenario.DerbySettings = {
                lives = 3,
                configs = BJIScenario.get(BJIScenario.TYPES.DERBY).configs or {}
            }
            existing = BJIContext.Scenario.DerbySettings
        end
        existing.arenaIndex = indexArena
        existing.arena = arena
    end
    if not BJIScenario.isServerScenarioInProgress() and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        tlength(BJIContext.Players) >= 3 and
        #BJIContext.Scenario.Data.Derby > 0 then
        local arenas = {}
        for i, arena in ipairs(BJIContext.Scenario.Data.Derby) do
            if arena.enabled then
                table.insert(arenas, {
                    label = svar("{1} ({2})", {
                        arena.name,
                        svar(BJILang.get("derby.settings.places"),
                            { places = #arena.startPositions }),
                    }),
                    onClick = function()
                        openDerbySettings(i)
                    end
                })
            end
        end
        table.sort(arenas, function(a, b)
            return a.label < b.label
        end)
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startDerby"),
            elems = arenas
        })
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.DERBY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopDerby"),
            onClick = BJITx.scenario.DerbyStop,
        })
    end

    return #scenarioEntry.elems > 0 and scenarioEntry or nil
end

local function getEditEntry(ctxt)
    local editEntry = {
        label = BJILang.get("menu.edit.title"),
        elems = {},
    }

    -- FREEROAM SETTINGS
    if BJICache.isFirstLoaded(BJICache.CACHES.BJC) and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CONFIG) then
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.freeroamSettings"),
            active = BJIContext.Scenario.FreeroamSettingsOpen,
            onClick = function()
                BJIContext.Scenario.FreeroamSettingsOpen = not BJIContext.Scenario.FreeroamSettingsOpen
            end,
        })
    end

    -- TIME PRESETS
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_ENVIRONMENT_PRESET) and
        BJIEnv.Data.controlSun then
        local presets = require("ge/extensions/utils/EnvironmentUtils").timePresets()
        local elems = {
            [1] = {
                render = function()
                    local onClick = function()
                        BJITx.config.env("timePlay", not BJIEnv.Data.timePlay)
                        BJIEnv.Data.timePlay = not BJIEnv.Data.timePlay
                    end
                    LineBuilder()
                        :btnIcon({
                            id = "timePlayButton",
                            icon = ICONS.play_arrow,
                            style = TEXT_COLORS.DEFAULT,
                            background = BJIEnv.Data.timePlay and
                                BTN_PRESETS.SUCCESS or BTN_PRESETS.INFO,
                            onClick = onClick,
                        })
                        :btn({
                            id = "timePlayLabel",
                            label = BJILang.get("environment.timePlay"),
                            style = BJIEnv.Data.timePlay and
                                BTN_PRESETS.SUCCESS or BTN_PRESETS.INFO,
                            onClick = onClick,
                        })
                        :build()
                end,
            }
        }
        for _, preset in ipairs(presets) do
            local disabled = Round(BJIEnv.Data.ToD, 3) == Round(preset.ToD, 3)
            table.insert(elems, {
                render = function()
                    local onClick = function()
                        if not disabled then
                            BJITx.config.env("ToD", preset.ToD)
                            BJIEnv.Data.ToD = preset.ToD
                        end
                    end
                    LineBuilder()
                        :btnIcon({
                            id = svar("timePreset{1}Button", { preset.label }),
                            icon = preset.icon,
                            style = disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT,
                            background = disabled and BTN_PRESETS.DISABLED or BTN_PRESETS.INFO,
                            onClick = onClick,
                        })
                        :btn({
                            id = svar("timePreset{1}Label", { preset.label }),
                            label = BJILang.get(svar("presets.time.{1}", { preset.label })),
                            disabled = disabled,
                            onClick = onClick,
                        })
                        :build()
                end,
            })
        end
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.time"),
            elems = elems,
        })
    end

    -- WEATHER PRESETS
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_ENVIRONMENT_PRESET) and
        BJIEnv.Data.controlWeather then
        local presets = require("ge/extensions/utils/EnvironmentUtils").weatherPresets()
        local elems = {}
        for _, preset in ipairs(presets) do
            local disabled = preset.label == BJIEnv.currentWeatherPreset
            local onClick = function()
                if not disabled then
                    for k, v in pairs(preset.keys) do
                        BJIEnv.Data[k] = v
                        BJITx.config.env(k, v)
                    end
                end
            end
            table.insert(elems, {
                render = function()
                    LineBuilder()
                        :btnIcon({
                            id = svar("weatherPreset{1}Button", { preset.label }),
                            icon = preset.icon,
                            style = disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT,
                            background = disabled and BTN_PRESETS.DISABLED or BTN_PRESETS.INFO,
                            onClick = onClick,
                        })
                        :btn({
                            id = svar("weatherPreset{1}Label", { preset.label }),
                            label = BJILang.get(svar("presets.weather.{1}", { preset.label })),
                            disabled = disabled,
                            onClick = onClick,
                        })
                        :build()
                end,
            })
        end
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.weather"),
            elems = elems,
        })
    end

    -- SWITCH MAP
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SWITCH_MAP) and
        BJIContext.Maps then
        local maps = {}
        local customMapLabel = BJILang.get("menu.edit.mapCustom")
        for mapName, map in pairs(BJIContext.Maps.Data) do
            table.insert(maps, {
                label = map.custom and svar("{1} ({2})", { map.label, customMapLabel }) or map.label,
                onClick = function()
                    BJITx.config.switchMap(mapName)
                end
            })
        end
        table.sort(maps, function(a, b)
            return a.label < b.label
        end)
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.map"),
            elems = maps
        })
    end

    local function isScenarioEditorDisabled(currentData)
        if currentData or not BJIScenario.isFreeroam() then
            return false
        end
        return BJIContext.Scenario.isEditorOpen()
    end

    -- ENERGY STATIONS
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.EnergyStations then
        table.insert(editEntry.elems, {
            label = svar(BJILang.get("menu.edit.energyStations"),
                { amount = tlength(BJIContext.Scenario.Data.EnergyStations) }),
            active = BJIContext.Scenario.EnergyStationsEdit,
            disabled = isScenarioEditorDisabled(BJIContext.Scenario.EnergyStationsEdit),
            onClick = function()
                if BJIContext.Scenario.EnergyStationsEdit then
                    if not BJIContext.Scenario.EnergyStationsEdit.changed and
                        not BJIContext.Scenario.EnergyStationsEdit.processSave then
                        BJIContext.Scenario.EnergyStationsEdit = nil
                        BJIWaypointEdit.reset()
                    end
                else
                    BJIContext.Scenario.EnergyStationsEdit = {
                        changed = false,
                        stations = tdeepcopy(BJIContext.Scenario.Data.EnergyStations)
                    }
                end
            end,
        })
    end

    -- GARAGES
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Garages then
        table.insert(editEntry.elems, {
            label = svar(BJILang.get("menu.edit.garages"),
                { amount = #BJIContext.Scenario.Data.Garages }),
            active = BJIContext.Scenario.GaragesEdit,
            disabled = isScenarioEditorDisabled(BJIContext.Scenario.GaragesEdit),
            onClick = function()
                if BJIContext.Scenario.GaragesEdit then
                    if not BJIContext.Scenario.GaragesEdit.changed and
                        not BJIContext.Scenario.GaragesEdit.processSave then
                        BJIContext.Scenario.GaragesEdit = nil
                        BJIWaypointEdit.reset()
                    end
                else
                    BJIContext.Scenario.GaragesEdit = {
                        changed = false,
                        garages = tdeepcopy(BJIContext.Scenario.Data.Garages)
                    }
                end
            end,
        })
    end

    -- DELIVERIES
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Deliveries then
        table.insert(editEntry.elems, {
            label = svar(BJILang.get("menu.edit.deliveries"),
                { amount = #BJIContext.Scenario.Data.Deliveries }),
            active = BJIContext.Scenario.DeliveryEdit,
            disabled = isScenarioEditorDisabled(BJIContext.Scenario.DeliveryEdit),
            onClick = function()
                if BJIContext.Scenario.DeliveryEdit then
                    if not BJIContext.Scenario.DeliveryEdit.changed and
                        not BJIContext.Scenario.DeliveryEdit.processSave then
                        BJIContext.Scenario.DeliveryEdit = nil
                        BJIWaypointEdit.reset()
                    end
                else
                    BJIContext.Scenario.DeliveryEdit = {
                        changed = false,
                        positions = BJIContext.Scenario.Data.Deliveries and
                            tdeepcopy(BJIContext.Scenario.Data.Deliveries) or {}
                    }
                end
            end,
        })
    end

    -- BUS LINES
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.BusLines then
        table.insert(editEntry.elems, {
            label = svar(BJILang.get("menu.edit.buslines"),
                { amount = #BJIContext.Scenario.Data.BusLines }),
            active = BJIContext.Scenario.BusLinesEdit,
            disabled = isScenarioEditorDisabled(BJIContext.Scenario.BusLinesEdit),
            onClick = function()
                if BJIContext.Scenario.BusLinesEdit then
                    if not BJIContext.Scenario.BusLinesEdit.changed and
                        not BJIContext.Scenario.BusLinesEdit.processSave then
                        BJIContext.Scenario.BusLinesEdit = nil
                        BJIWaypointEdit.reset()
                    end
                else
                    BJIContext.Scenario.BusLinesEdit = {
                        changed = false,
                        lines = BJIContext.Scenario.Data.BusLines and
                            tdeepcopy(BJIContext.Scenario.Data.BusLines) or {}
                    }
                end
            end,
        })
    end

    -- RACES
    local function createRaceEditData(r, isCopy)
        -- creation
        local res = {
            changed = false,
            id = nil,
            author = BJIContext.User.playerName,
            name = "",
            previewPosition = nil,
            steps = {},
            startPositions = {},
            loopable = false,
            laps = nil,
            enabled = true,
            hasRecord = false,
            keepRecord = true,
        }

        if r then
            -- existant race
            BJITx.scenario.RaceDetails(r.id)
            BJIAsync.task(function()
                return BJIContext.Scenario.RaceDetails ~= nil
            end, function()
                local raceData = BJIContext.Scenario.RaceDetails
                if type(raceData) == "table" then
                    if not isCopy then
                        res.id = raceData.id
                        res.author = raceData.author
                        res.name = raceData.name
                        res.hasRecord = raceData.record ~= nil
                    else
                        res.keepRecord = false
                    end
                    res.previewPosition = TryParsePosRot(raceData.previewPosition)
                    res.steps = raceData.steps
                    for _, step in ipairs(res.steps) do
                        for iWp, wp in ipairs(step) do
                            step[iWp] = TryParsePosRot(wp)
                        end
                    end
                    res.startPositions = raceData.startPositions
                    for iSp, sp in ipairs(res.startPositions) do
                        res.startPositions[iSp] = TryParsePosRot(sp)
                    end
                    res.loopable = raceData.loopable == true
                    res.laps = raceData.loopable and 1 or nil
                    res.enabled = raceData.enabled == true

                    BJIContext.Scenario.RaceEdit = res
                end
                BJIContext.Scenario.RaceDetails = nil
            end, "BJIRaceGetDetails")
        else
            -- race creation
            BJIContext.Scenario.RaceEdit = res
        end
    end
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Races and
        not BJIScenario.isServerScenarioInProgress() then
        local label = svar(BJILang.get("menu.edit.races"),
            { amount = #BJIContext.Scenario.Data.Races })
        if isScenarioEditorDisabled(BJIContext.Scenario.RaceEdit) then
            -- another scenario editor is open
            table.insert(editEntry.elems, {
                label = label,
                disabled = true,
            })
        elseif BJIContext.Scenario.RaceEdit then
            -- already open
            table.insert(editEntry.elems, {
                label = label,
                active = true,
            })
        else
            -- can open or create
            local races = {}
            table.insert(races, {
                label = BJILang.get("menu.edit.raceCreate"),
                onClick = createRaceEditData,
            })
            for _, race in ipairs(BJIContext.Scenario.Data.Races) do
                table.insert(races, {
                    render = function()
                        LineBuilder()
                            :btnIcon({
                                id = "edit" .. race.id,
                                icon = ICONS.mode_edit,
                                background = BTN_PRESETS.INFO,
                                onClick = function()
                                    createRaceEditData(race)
                                end
                            })
                            :btnIcon({
                                id = "copy" .. race.id,
                                icon = ICONS.content_copy,
                                background = BTN_PRESETS.INFO,
                                onClick = function()
                                    createRaceEditData(race, true)
                                end
                            })
                            :btnIcon({
                                id = svar("delete{1}", { race.id }),
                                icon = ICONS.delete_forever,
                                background = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        svar(BJILang.get("menu.edit.raceDeleteModal"),
                                            { raceName = race.name }),
                                        {
                                            {
                                                label = BJILang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJILang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJITx.scenario.RaceDelete(race.id)
                                                end
                                            }
                                        }
                                    )
                                end
                            })
                            :btnIconSwitch({
                                id = svar("toggleEnabled{1}", { race.id }),
                                iconEnabled = ICONS.visibility,
                                iconDisabled = ICONS.visibility_off,
                                state = race.enabled == true,
                                onClick = function()
                                    BJITx.scenario.RaceToggle(race.id, not race.enabled)
                                end
                            })
                            :text(svar("{1}", { race.name }))
                            :build()
                    end,
                })
            end
            table.insert(editEntry.elems, {
                label = label,
                elems = races,
            })
        end
    end

    -- HUNTER
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Hunter and
        BJIContext.Scenario.Data.Hunter.targets then
        table.insert(editEntry.elems, {
            label = svar(BJILang.get("menu.edit.hunter"),
                {
                    visibility = BJILang.get(BJIContext.Scenario.Data.Hunter.enabled and
                        "common.enabled" or "common.disabled"),
                    amount = #BJIContext.Scenario.Data.Hunter.targets,
                }),
            active = BJIContext.Scenario.HunterEdit,
            disabled = isScenarioEditorDisabled(BJIContext.Scenario.HunterEdit),
            onClick = function()
                if BJIContext.Scenario.HunterEdit then
                    if not BJIContext.Scenario.HunterEdit.changed and
                        not BJIContext.Scenario.HunterEdit.processSave then
                        BJIContext.Scenario.HunterEdit = nil
                        BJIWaypointEdit.reset()
                    end
                else
                    BJIContext.Scenario.HunterEdit = {
                        changed = false,
                        processSave = nil,
                    }
                    tdeepassign(BJIContext.Scenario.HunterEdit, BJIContext.Scenario.Data.Hunter)
                end
            end,
        })
    end

    -- DERBY
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Derby then
        table.insert(editEntry.elems, {
            label = svar(BJILang.get("menu.edit.derby"),
                { amount = #BJIContext.Scenario.Data.Derby }),
            active = BJIContext.Scenario.DerbyEdit,
            disabled = isScenarioEditorDisabled(BJIContext.Scenario.DerbyEdit),
            onClick = function()
                if BJIContext.Scenario.DerbyEdit then
                    if not BJIContext.Scenario.DerbyEdit.changed and
                        not BJIContext.Scenario.DerbyEdit.processSave then
                        BJIContext.Scenario.DerbyEdit.onClose()
                    end
                else
                    BJIContext.Scenario.DerbySettings = nil
                    BJIContext.Scenario.DerbyEdit = {
                        changed = false,
                        processSave = nil,
                        arenas = tdeepcopy(BJIContext.Scenario.Data.Derby)
                    }
                end
            end
        })
    end

    return #editEntry.elems > 0 and editEntry or nil
end

local function getConfigEntry(ctxt)
    local configEntry = {
        label = BJILang.get("menu.config.title"),
        elems = {},
    }

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CONFIG) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CEN) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_MAPS) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_PERMISSIONS) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.server"),
            active = BJIContext.ServerEditorOpen,
            onClick = function()
                BJIContext.ServerEditorOpen = not BJIContext.ServerEditorOpen
            end
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_ENVIRONMENT) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.environment"),
            active = BJIContext.EnvironmentEditorOpen,
            onClick = function()
                BJIContext.EnvironmentEditorOpen = not BJIContext.EnvironmentEditorOpen
            end
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.theme"),
            active = BJIContext.ThemeEditor,
            onClick = function()
                if BJIContext.ThemeEditor then
                    if BJIContext.ThemeEditor.changed then
                        BJIPopup.createModal(BJILang.get("themeEditor.cancelModal"), {
                            {
                                label = BJILang.get("common.buttons.cancel"),
                            },
                            {
                                label = BJILang.get("common.buttons.confirm"),
                                onClick = function()
                                    LoadTheme(BJIContext.BJC.Server.Theme)
                                    BJIContext.ThemeEditor = nil
                                end
                            }
                        })
                    else
                        BJIContext.ThemeEditor = nil
                    end
                else
                    BJIContext.ThemeEditor = {
                        data = tdeepcopy(BJIContext.BJC.Server.Theme),
                        changed = false,
                    }
                end
            end
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DATABASE_PLAYERS) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DATABASE_VEHICLES) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.database"),
            active = BJIContext.DatabaseEditorOpen,
            onClick = function()
                BJIContext.DatabaseEditorOpen = not BJIContext.DatabaseEditorOpen
            end
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.stop"),
            onClick = function()
                BJIPopup.createModal(BJILang.get("menu.config.stopModal"), {
                    {
                        label = BJILang.get("common.buttons.cancel"),
                    },
                    {
                        label = BJILang.get("common.buttons.confirm"),
                        onClick = BJITx.config.stop,
                    }
                })
            end,
        })
    end

    return #configEntry.elems > 0 and configEntry or nil
end

local function drawMenu(ctxt)
    local menu = MenuBarBuilder()

    -- ME
    local meEntry = getMeEntry(ctxt)
    if meEntry then
        menu:addEntry(meEntry.label, meEntry.elems)
    end

    -- VOTES
    local voteEntry = getVoteEntry(ctxt)
    if voteEntry then
        menu:addEntry(voteEntry.label, voteEntry.elems)
    end

    -- SCENARIO
    local scenarioEntry = getScenarioEntry(ctxt)
    if scenarioEntry then
        menu:addEntry(scenarioEntry.label, scenarioEntry.elems)
    end

    -- EDIT
    local editEntry = getEditEntry(ctxt)
    if editEntry then
        menu:addEntry(editEntry.label, editEntry.elems)
    end

    -- CONFIG
    local configEntry = getConfigEntry(ctxt)
    if configEntry then
        menu:addEntry(configEntry.label, configEntry.elems)
    end

    menu:addEntry(BJILang.get("menu.about.title"), {
        {
            label = svar("BeamJoy v{1}", { BJIVERSION }),
        },
        {
            label = svar(BJILang.get("menu.about.createdBy"), {author = "TontonSamael"}),
        },
        {
            label = svar("{1} : {2}", { BJILang.get("menu.about.computerTime"), math.floor(ctxt.now / 1000) })
        }
    })
        :build()
end
return drawMenu
