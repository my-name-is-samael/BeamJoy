local M = {
    cache = {
        elems = {},
    },
}

local function menuFreeroamSettings(ctxt)
    if BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.BJC) and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CONFIG) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.freeroamSettings"),
            active = BJI.Windows.FreeroamSettings.show,
            onClick = function()
                if BJI.Windows.FreeroamSettings.show then
                    BJI.Windows.FreeroamSettings.onClose()
                else
                    BJI.Windows.FreeroamSettings.open()
                end
            end,
        })
    end
end

local function menuTimePresets(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT_PRESET) and
        BJI.Managers.Env.Data.controlSun then
        local elems = {
            [1] = {
                render = function()
                    BJI.Utils.Common.DrawTimePlayPauseButtons("menuTimePlay", true)
                end,
            }
        }
        require("ge/extensions/utils/EnvironmentUtils").timePresets():forEach(function(preset)
            local disabled = not BJI.Managers.Env.Data.timePlay and
                math.round(BJI.Managers.Env.Data.ToD, 3) == math.round(preset.ToD, 3)
            table.insert(elems, {
                render = function()
                    local onClick = function()
                        if not disabled then
                            BJI.Tx.config.env("ToD", preset.ToD)
                        end
                    end
                    LineBuilder()
                        :btnIcon({
                            id = string.var("timePreset{1}Button", { preset.label }),
                            icon = preset.icon,
                            style = disabled and BJI.Utils.Style.BTN_PRESETS.DISABLED or BJI.Utils.Style.BTN_PRESETS
                                .INFO,
                            onClick = onClick,
                        })
                        :btn({
                            id = string.var("timePreset{1}Label", { preset.label }),
                            label = BJI.Managers.Lang.get(string.var("presets.time.{1}", { preset.label })),
                            disabled = disabled,
                            onClick = onClick,
                        })
                        :build()
                end,
            })
        end)
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.time"),
            elems = elems,
        })
    end
end

local function menuWeatherPresets(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT_PRESET) and
        BJI.Managers.Env.Data.controlWeather then
        local elems = {}
        local order = Table({ "clear", "cloud", "lightrain", "rain", "lightsnow", "snow" })
        Table(BJI.Managers.Env.Data.presets):map(function(icon, preset)
            return {
                key = preset,
                label = BJI.Managers.Lang.get(string.var("presets.weather.{1}", { preset }),
                    tostring(preset)),
                icon = icon,
            }
        end):sort(function(a, b) -- following function is correct but table.sort process both 2 lasts wrongly :shrug:
            local res
            order:forEach(function(k)
                if res == nil and (a.key == k or b.key == k) then
                    res = a.key == k
                end
            end)
            if res ~= nil then
                return res
            end
            return a.label < b.label
        end):forEach(function(preset)
            local disabled = preset.key == BJI.Managers.Env.Data.preset
            local onClick = function()
                if not disabled then
                    BJI.Tx.config.envPreset(preset.key)
                end
            end
            table.insert(elems, {
                render = function()
                    LineBuilder()
                        :btnIcon({
                            id = string.var("weatherPreset{1}Button", { preset.key }),
                            icon = preset.icon,
                            style = disabled and BJI.Utils.Style.BTN_PRESETS.DISABLED or
                                BJI.Utils.Style.BTN_PRESETS.INFO,
                            onClick = onClick,
                        })
                        :btn({
                            id = string.var("weatherPreset{1}Label", { preset.key }),
                            label = preset.label,
                            disabled = disabled,
                            onClick = onClick,
                        })
                        :build()
                end,
            })
        end)
        if #elems > 0 then
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.edit.weather"),
                elems = elems,
            })
        end
    end
end

local function menuGravityPresets(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT) and BJI.Managers.Env.Data.controlGravity then
        local elems = {}
        require("ge/extensions/utils/EnvironmentUtils").gravityPresets():forEach(function(preset)
            local value = math.round(preset.value, 3)
            local disabled = value == math.round(BJI.Managers.Env.Data.gravityRate, 3)
            table.insert(elems, {
                label = string.var("{1} ({2})", {
                    BJI.Managers.Lang.get(string.var("presets.gravity.{1}", { preset.key })),
                    value,
                }),
                disabled = disabled,
                active = disabled,
                onClick = function()
                    BJI.Tx.config.env("gravityRate", value)
                end
            })
        end)
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.gravity"),
            elems = elems,
        })
    end
end

local function menuSpeedPresets(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT) then
        local elems = {}
        require("ge/extensions/utils/EnvironmentUtils").speedPresets():forEach(function(preset)
            local value = math.round(preset.value, 3)
            local disabled = value == math.round(BJI.Managers.Env.Data.simSpeed, 3)
            table.insert(elems, {
                label = string.var("{1} (x{2})", {
                    BJI.Managers.Lang.get(string.var("presets.speed.{1}", { preset.key })),
                    value,
                }),
                disabled = disabled,
                active = disabled,
                onClick = function()
                    BJI.Tx.config.env("simSpeed", value)
                end
            })
        end)
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.speed"),
            elems = elems,
        })
    end
end

local function menuSwitchMap(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SWITCH_MAP) and
        BJI.Managers.Context.Maps then
        local customMapLabel = BJI.Managers.Lang.get("menu.edit.mapCustom")
        local rawMaps = Table(BJI.Managers.Context.Maps)
            :filter(function(map) return map.enabled end)

        if rawMaps:length() <= BJI.Windows.Selection.LIMIT_ELEMS_THRESHOLD then
            -- sub elems
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.edit.map"),
                elems = rawMaps:map(function(map, mapName)
                    return {
                        label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or map.label,
                        disabled = mapName == BJI.Managers.Context.UI.mapName,
                        active = mapName == BJI.Managers.Context.UI.mapName,
                        onClick = function()
                            BJI.Tx.config.switchMap(mapName)
                        end
                    }
                end):sort(function(a, b) return a.label < b.label end)
            })
        else
            -- selection window
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.edit.map"),
                onClick = function()
                    BJI.Windows.Selection.open("menu.edit.map", rawMaps
                        :filter(function(_, mapName) return mapName ~= BJI.Managers.Context.UI.mapName end)
                        :map(function(map, mapName)
                            return {
                                label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or
                                    map.label,
                                value = mapName,
                            }
                        end):values():sort(function(a, b) return a.label < b.label end) or {}, nil,
                        function(mapName)
                            BJI.Tx.config.switchMap(mapName)
                        end, { BJI.Managers.Perm.PERMISSIONS.SWITCH_MAP })
                end,
            })
        end
    end
end

local function menuEnergyStations(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO) and
        BJI.Managers.Context.Scenario.Data.EnergyStations then
        local editorOpen = BJI.Windows.ScenarioEditor.getState()
        local stationsEditorOpen = editorOpen and
            BJI.Windows.ScenarioEditor.view == BJI.Windows.ScenarioEditor.SCENARIOS.STATIONS
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.energyStations")
                :var({ amount = table.length(BJI.Managers.Context.Scenario.Data.EnergyStations) }),
            active = editorOpen and stationsEditorOpen,
            disabled = editorOpen and not stationsEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI.Windows.ScenarioEditor.onClose()
                else
                    BJI.Windows.ScenarioEditor.SCENARIOS.STATIONS.open()
                end
            end,
        })
    end
end

local function menuGarages(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO) and
        BJI.Managers.Context.Scenario.Data.Garages then
        local editorOpen = BJI.Windows.ScenarioEditor.getState()
        local garagesEditorOpen = editorOpen and
            BJI.Windows.ScenarioEditor.view == BJI.Windows.ScenarioEditor.SCENARIOS.GARAGES
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.garages")
                :var({ amount = #BJI.Managers.Context.Scenario.Data.Garages }),
            active = editorOpen and garagesEditorOpen,
            disabled = editorOpen and not garagesEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI.Windows.ScenarioEditor.onClose()
                else
                    BJI.Windows.ScenarioEditor.SCENARIOS.GARAGES.open()
                end
            end,
        })
    end
end

local function menuDeliveries(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO) and
        BJI.Managers.Context.Scenario.Data.Deliveries then
        local editorOpen = BJI.Windows.ScenarioEditor.getState()
        local deliveriesEditorOpen = editorOpen and
            BJI.Windows.ScenarioEditor.view == BJI.Windows.ScenarioEditor.SCENARIOS.DELIVERIES
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.deliveries")
                :var({ amount = #BJI.Managers.Context.Scenario.Data.Deliveries }),
            active = editorOpen and deliveriesEditorOpen,
            disabled = editorOpen and not deliveriesEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI.Windows.ScenarioEditor.onClose()
                else
                    BJI.Windows.ScenarioEditor.SCENARIOS.DELIVERIES.open()
                end
            end,
        })
    end
end

local function menuBusLines(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO) and
        BJI.Managers.Context.Scenario.Data.BusLines then
        local editorOpen = BJI.Windows.ScenarioEditor.getState()
        local busEditorOpen = editorOpen and
            BJI.Windows.ScenarioEditor.view == BJI.Windows.ScenarioEditor.SCENARIOS.BUS_LINES
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.buslines")
                :var({ amount = #BJI.Managers.Context.Scenario.Data.BusLines }),
            active = editorOpen and busEditorOpen,
            disabled = editorOpen and not busEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI.Windows.ScenarioEditor.onClose()
                else
                    BJI.Windows.ScenarioEditor.SCENARIOS.BUS_LINES.open()
                end
            end,
        })
    end
end

local function menuRaces(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO) and
        BJI.Managers.Context.Scenario.Data.Races then
        local rawRaces = Table(BJI.Managers.Context.Scenario.Data.Races)
            :filter(function(r) return type(r) == "table" end):values()
        local label = string.var("{1} ({2})", { BJI.Managers.Lang.get("menu.edit.races"), #rawRaces })
        if BJI.Windows.ScenarioEditor.getState() then
            -- editor already open
            local isEditorRace = BJI.Windows.ScenarioEditor.view == BJI.Windows.ScenarioEditor.SCENARIOS.RACE
            table.insert(M.cache.elems, {
                label = label,
                active = isEditorRace,
                disabled = not isEditorRace,
                onClick = BJI.Windows.ScenarioEditor.onClose,
            })
        else
            if #BJI.Managers.Context.Scenario.Data.Races + 1 <= BJI.Windows.Selection.LIMIT_ELEMS_THRESHOLD then
                table.insert(M.cache.elems, {
                    label = label,
                    elems = Table({
                        {
                            label = BJI.Managers.Lang.get("menu.edit.raceCreate"),
                            onClick = BJI.Windows.ScenarioEditor.SCENARIOS.RACE.openWithID,
                        }
                    }):addAll(rawRaces:map(function(race)
                        return {
                            render = function()
                                LineBuilder():btnIconToggle({
                                    id = "toggle-" .. tostring(race.id),
                                    icon = race.enabled and ICONS.visibility or ICONS.visibility_off,
                                    state = race.enabled == true,
                                    tooltip = BJI.Managers.Lang.get("common.buttons.toggle"),
                                    onClick = function()
                                        BJI.Tx.scenario.RaceToggle(race.id, not race.enabled)
                                    end
                                }):btnIcon({
                                    id = "editRace-" .. tostring(race.id),
                                    icon = ICONS.mode_edit,
                                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                    tooltip = BJI.Managers.Lang.get("common.buttons.edit"),
                                    onClick = function()
                                        BJI.Windows.ScenarioEditor.SCENARIOS.RACE.openWithID(race.id)
                                    end
                                }):btnIcon({
                                    id = "copyRace-" .. tostring(race.id),
                                    icon = ICONS.content_copy,
                                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                                    tooltip = BJI.Managers.Lang.get("common.buttons.duplicate"),
                                    onClick = function()
                                        BJI.Windows.ScenarioEditor.SCENARIOS.RACE.openWithID(race.id, true)
                                    end
                                }):btnIcon({
                                    id = "deleteRace-" .. tostring(race.id),
                                    icon = ICONS.delete_forever,
                                    style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                    tooltip = BJI.Managers.Lang.get("common.buttons.delete"),
                                    onClick = function()
                                        BJI.Managers.Popup.createModal(
                                            BJI.Managers.Lang.get("menu.edit.raceDeleteModal")
                                            :var({ raceName = race.name }), {
                                                BJI.Managers.Popup.createButton(BJI.Managers.Lang.get(
                                                    "common.buttons.cancel"
                                                )),
                                                BJI.Managers.Popup.createButton(BJI.Managers.Lang.get(
                                                        "common.buttons.confirm"
                                                    ),
                                                    function()
                                                        BJI.Tx.scenario.RaceDelete(race.id)
                                                    end)
                                            })
                                    end
                                }):text(race.name):build()
                            end,
                        }
                    end)),
                })
            else
                table.insert(M.cache.elems, {
                    label = label,
                    onClick = function()
                        BJI.Windows.Selection.open("menu.edit.races", Table({ {
                            label = BJI.Managers.Lang.get("menu.edit.raceCreate"),
                            value = nil,
                        } }):addAll(rawRaces:map(function(r)
                            return {
                                label = r.name,
                                value = r.id,
                            }
                        end)), function(line, raceID, onClose)
                            if not raceID then
                                -- create race
                                line:btnIcon({
                                    id = "createRace",
                                    icon = ICONS.add,
                                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                                    tooltip = BJI.Managers.Lang.get("common.buttons.create"),
                                    onClick = function()
                                        BJI.Windows.ScenarioEditor.SCENARIOS.RACE.openWithID()
                                        onClose()
                                    end
                                })
                                return
                            end
                            rawRaces:find(function(r) return r.id == raceID end, function(race)
                                line:btnIcon({
                                    id = "editRace-" .. tostring(raceID),
                                    icon = ICONS.mode_edit,
                                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                    tooltip = BJI.Managers.Lang.get("common.buttons.edit"),
                                    onClick = function()
                                        BJI.Windows.ScenarioEditor.SCENARIOS.RACE.openWithID(race.id)
                                        onClose()
                                    end
                                }):btnIcon({
                                    id = "copyRace-" .. tostring(race.id),
                                    icon = ICONS.content_copy,
                                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                                    tooltip = BJI.Managers.Lang.get("common.buttons.duplicate"),
                                    onClick = function()
                                        BJI.Windows.ScenarioEditor.SCENARIOS.RACE.openWithID(race.id, true)
                                        onClose()
                                    end
                                }):btnIcon({
                                    id = "deleteRace-" .. tostring(race.id),
                                    icon = ICONS.delete_forever,
                                    style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                    tooltip = BJI.Managers.Lang.get("common.buttons.delete"),
                                    onClick = function()
                                        BJI.Managers.Popup.createModal(
                                            BJI.Managers.Lang.get("menu.edit.raceDeleteModal")
                                            :var({ raceName = race.name }),
                                            {
                                                BJI.Managers.Popup.createButton(BJI.Managers.Lang.get(
                                                    "common.buttons.cancel"
                                                )),
                                                BJI.Managers.Popup.createButton(BJI.Managers.Lang.get(
                                                    "common.buttons.confirm"
                                                ), function()
                                                    BJI.Tx.scenario.RaceDelete(race.id)
                                                    onClose()
                                                end),
                                            })
                                    end
                                })
                            end)
                        end, nil, { BJI.Managers.Perm.PERMISSIONS.SCENARIO })
                    end,
                })
            end
        end
    end
end

local function menuHunter(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO) and
        BJI.Managers.Context.Scenario.Data.Hunter and
        BJI.Managers.Context.Scenario.Data.Hunter.targets then
        local editorOpen = BJI.Windows.ScenarioEditor.getState()
        local hunterEditorOpen = editorOpen and
            BJI.Windows.ScenarioEditor.view == BJI.Windows.ScenarioEditor.SCENARIOS.HUNTER
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.hunter")
                :var({
                    visibility = BJI.Managers.Lang.get(BJI.Managers.Context.Scenario.Data.Hunter.enabled and
                        "common.enabled" or "common.disabled"),
                    amount = #BJI.Managers.Context.Scenario.Data.Hunter.targets,
                }),
            active = editorOpen and hunterEditorOpen,
            disabled = editorOpen and not hunterEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI.Windows.ScenarioEditor.onClose()
                else
                    BJI.Windows.ScenarioEditor.SCENARIOS.HUNTER.open()
                end
            end,
        })
    end
end

local function menuDerby(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO) and
        BJI.Managers.Context.Scenario.Data.Derby then
        local editorOpen = BJI.Windows.ScenarioEditor.getState()
        local derbyEditorOpen = editorOpen and
            BJI.Windows.ScenarioEditor.view == BJI.Windows.ScenarioEditor.SCENARIOS.DERBY
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.edit.derby")
                :var({ amount = #BJI.Managers.Context.Scenario.Data.Derby }),
            active = editorOpen and derbyEditorOpen,
            disabled = editorOpen and not derbyEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI.Windows.ScenarioEditor.onClose()
                else
                    BJI.Windows.ScenarioEditor.SCENARIOS.DERBY.open()
                end
            end
        })
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    M.cache = {
        label = BJI.Managers.Lang.get("menu.edit.title"),
        elems = {},
    }

    menuFreeroamSettings(ctxt)
    menuTimePresets(ctxt)
    menuWeatherPresets(ctxt)
    menuGravityPresets(ctxt)
    menuSpeedPresets(ctxt)

    if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.FREEROAM) then
        menuSwitchMap(ctxt)

        -- scenario editors
        menuEnergyStations(ctxt)
        menuGarages(ctxt)
        menuDeliveries(ctxt)
        menuBusLines(ctxt)
        menuRaces(ctxt)
        menuHunter(ctxt)
        menuDerby(ctxt)
    end
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_EDITOR_UPDATED,
        BJI.Managers.Events.EVENTS.ENV_CHANGED,
        BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache))

    ---@param data {cache: string}
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({
                BJI.Managers.Cache.CACHES.BJC,
                BJI.Managers.Cache.CACHES.MAPS,
                BJI.Managers.Cache.CACHES.STATIONS,
                BJI.Managers.Cache.CACHES.RACES,
                BJI.Managers.Cache.CACHES.DELIVERIES,
                BJI.Managers.Cache.CACHES.BUS_LINES,
                BJI.Managers.Cache.CACHES.HUNTER_DATA,
                BJI.Managers.Cache.CACHES.DERBY_DATA,
            }, data.cache) then
            updateCache(ctxt)
        end
    end))
end

function M.onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

return M
