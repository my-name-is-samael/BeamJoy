local function menuFreeroamSettings(ctxt, editEntry)
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
end

local function menuTimePresets(ctxt, editEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_ENVIRONMENT_PRESET) and
        BJIEnv.Data.controlSun then
        local presets = require("ge/extensions/utils/EnvironmentUtils").timePresets()
        local elems = {
            [1] = {
                render = function()
                    DrawTimePlayPauseButtons("menuTimePlay", true)
                end,
            }
        }
        for _, preset in ipairs(presets) do
            local disabled = math.round(BJIEnv.Data.ToD, 3) == math.round(preset.ToD, 3)
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
                            id = string.var("timePreset{1}Button", { preset.label }),
                            icon = preset.icon,
                            style = disabled and BTN_PRESETS.DISABLED or BTN_PRESETS.INFO,
                            onClick = onClick,
                        })
                        :btn({
                            id = string.var("timePreset{1}Label", { preset.label }),
                            label = BJILang.get(string.var("presets.time.{1}", { preset.label })),
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
end

local function menuWeatherPresets(ctxt, editEntry)
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
                            id = string.var("weatherPreset{1}Button", { preset.label }),
                            icon = preset.icon,
                            style = disabled and BTN_PRESETS.DISABLED or BTN_PRESETS.INFO,
                            onClick = onClick,
                        })
                        :btn({
                            id = string.var("weatherPreset{1}Label", { preset.label }),
                            label = BJILang.get(string.var("presets.weather.{1}", { preset.label })),
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
end

local function menuSwitchMap(ctxt, editEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SWITCH_MAP) and
        BJIContext.Maps then
        local maps = {}
        local customMapLabel = BJILang.get("menu.edit.mapCustom")
        for mapName, map in pairs(BJIContext.Maps.Data) do
            if map.enabled then
                table.insert(maps, {
                    label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or map.label,
                    active = BJIContext.UI.mapName == mapName,
                    onClick = function()
                        if BJIContext.UI.mapName ~= mapName then
                            BJITx.config.switchMap(mapName)
                        end
                    end
                })
            end
        end
        table.sort(maps, function(a, b)
            return a.label < b.label
        end)
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.map"),
            elems = maps
        })
    end
end

local function isScenarioEditorDisabled(currentData)
    if currentData or not BJIScenario.isFreeroam() then
        return false
    end
    return BJIContext.Scenario.isEditorOpen()
end

local function menuEnergyStations(ctxt, editEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.EnergyStations then
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.energyStations")
                :var({ amount = table.length(BJIContext.Scenario.Data.EnergyStations) }),
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
                        stations = table.clone(BJIContext.Scenario.Data.EnergyStations)
                    }
                end
            end,
        })
    end
end

local function menuGarages(ctxt, editEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Garages then
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.garages")
                :var({ amount = #BJIContext.Scenario.Data.Garages }),
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
                        garages = table.clone(BJIContext.Scenario.Data.Garages)
                    }
                end
            end,
        })
    end
end

local function menuDeliveries(ctxt, editEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Deliveries then
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.deliveries")
                :var({ amount = #BJIContext.Scenario.Data.Deliveries }),
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
                            table.clone(BJIContext.Scenario.Data.Deliveries) or {}
                    }
                end
            end,
        })
    end
end

local function menuBusLines(ctxt, editEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.BusLines then
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.buslines")
                :var({ amount = #BJIContext.Scenario.Data.BusLines }),
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
                            table.clone(BJIContext.Scenario.Data.BusLines) or {}
                    }
                end
            end,
        })
    end
end

local function menuRaces(ctxt, editEntry)
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
        local label = BJILang.get("menu.edit.races")
            :var({ amount = #BJIContext.Scenario.Data.Races })
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
                                style = BTN_PRESETS.INFO,
                                onClick = function()
                                    createRaceEditData(race)
                                end
                            })
                            :btnIcon({
                                id = "copy" .. race.id,
                                icon = ICONS.content_copy,
                                style = BTN_PRESETS.INFO,
                                onClick = function()
                                    createRaceEditData(race, true)
                                end
                            })
                            :btnIcon({
                                id = string.var("delete{1}", { race.id }),
                                icon = ICONS.delete_forever,
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        BJILang.get("menu.edit.raceDeleteModal")
                                        :var({ raceName = race.name }),
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
                            :btnIconToggle({
                                id = string.var("toggleEnabled{1}", { race.id }),
                                icon = race.enabled and ICONS.visibility or ICONS.visibility_off,
                                state = race.enabled == true,
                                onClick = function()
                                    BJITx.scenario.RaceToggle(race.id, not race.enabled)
                                end
                            })
                            :text(string.var("{1}", { race.name }))
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
end

local function menuHunter(ctxt, editEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Hunter and
        BJIContext.Scenario.Data.Hunter.targets then
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.hunter")
                :var({
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
                    table.assign(BJIContext.Scenario.HunterEdit, BJIContext.Scenario.Data.Hunter)
                end
            end,
        })
    end
end

local function menuDerby(ctxt, editEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) and
        BJIContext.Scenario.Data.Derby then
        table.insert(editEntry.elems, {
            label = BJILang.get("menu.edit.derby")
                :var({ amount = #BJIContext.Scenario.Data.Derby }),
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
                        arenas = table.clone(BJIContext.Scenario.Data.Derby)
                    }
                end
            end
        })
    end
end

return function(ctxt)
    local editEntry = {
        label = BJILang.get("menu.edit.title"),
        elems = {},
    }

    menuFreeroamSettings(ctxt, editEntry)
    menuTimePresets(ctxt, editEntry)
    menuWeatherPresets(ctxt, editEntry)
    menuSwitchMap(ctxt, editEntry)

    -- scenario editors
    menuEnergyStations(ctxt, editEntry)
    menuGarages(ctxt, editEntry)
    menuDeliveries(ctxt, editEntry)
    menuBusLines(ctxt, editEntry)
    menuRaces(ctxt, editEntry)
    menuHunter(ctxt, editEntry)
    menuDerby(ctxt, editEntry)

    return #editEntry.elems > 0 and editEntry or nil
end
