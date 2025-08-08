local M = {
    cache = {
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

local function menuTimePresets(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_ENVIRONMENT_PRESET) and
        BJI_Env.Data.controlSun then
        local elems = {
            {
                type = "custom",
                render = function()
                    BJI.Utils.UI.DrawTimePlayPauseButtons("menuTimePlay", true)
                end,
            }
        }
        require("ge/extensions/utils/EnvironmentUtils").timePresets():forEach(function(preset)
            local disabled = not BJI_Env.Data.timePlay and
                math.round(BJI_Env.Data.ToD, 3) == math.round(preset.ToD, 3)
            table.insert(elems, {
                type = "custom",
                render = function()
                    local onClick = function()
                        BJI_Tx_config.env("ToD", preset.ToD)
                    end
                    if IconButton(string.var("timePreset{1}Button", { preset.label }), preset.icon, {
                            btnStyle = disabled and BJI.Utils.Style.BTN_PRESETS.DISABLED or
                                BJI.Utils.Style.BTN_PRESETS.INFO,
                            disabled = disabled,
                        }) then
                        onClick()
                    end
                    SameLine()
                    if Button(string.var("timePreset{1}Label", { preset.label }),
                            BJI_Lang.get(string.var("presets.time.{1}", { preset.label })),
                            { disabled = disabled }) then
                        onClick()
                    end
                end,
            })
        end)
        table.insert(M.cache.elems, {
            type = "menu",
            label = BJI_Lang.get("menu.edit.time"),
            elems = elems,
        })
    end
end

local function menuWeatherPresets(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_ENVIRONMENT_PRESET) and
        BJI_Env.Data.controlWeather then
        local elems = {}
        local order = Table({ "clear", "cloud", "lightrain", "rain", "lightsnow", "snow" })
        Table(BJI_Env.Data.presets):map(function(icon, preset)
            return {
                key = preset,
                label = BJI_Lang.get(string.var("presets.weather.{1}", { preset }),
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
            local disabled = preset.key == BJI_Env.Data.preset
            local onClick = function()
                BJI_Tx_config.envPreset(preset.key)
            end
            table.insert(elems, {
                type = "custom",
                render = function()
                    if IconButton(string.var("weatherPreset{1}Button", { preset.key }), preset.icon, {
                            btnStyle = disabled and BJI.Utils.Style.BTN_PRESETS.DISABLED or
                                BJI.Utils.Style.BTN_PRESETS.INFO,
                            disabled = disabled,
                        }) then
                        onClick()
                    end
                    SameLine()
                    if Button(string.var("weatherPreset{1}Label", { preset.key }),
                            preset.label, { disabled = disabled }) then
                        onClick()
                    end
                end,
            })
        end)
        if #elems > 0 then
            table.insert(M.cache.elems, {
                type = "menu",
                label = BJI_Lang.get("menu.edit.weather"),
                elems = elems,
            })
        end
    end
end

local function menuGravityPresets(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_ENVIRONMENT) and BJI_Env.Data.controlGravity then
        local elems = {}
        require("ge/extensions/utils/EnvironmentUtils").gravityPresets():forEach(function(preset)
            local value = math.round(preset.value, 3)
            local disabled = value == math.round(BJI_Env.Data.gravityRate, 3)
            table.insert(elems, {
                type = "item",
                label = string.var("{1} ({2})", {
                    BJI_Lang.get(string.var("presets.gravity.{1}", { preset.key })),
                    value,
                }),
                disabled = disabled,
                active = disabled,
                checked = disabled,
                onClick = function()
                    BJI_Tx_config.env("gravityRate", value)
                end
            })
        end)
        table.insert(M.cache.elems, {
            type = "menu",
            label = BJI_Lang.get("menu.edit.gravity"),
            elems = elems,
        })
    end
end

local function menuSpeedPresets(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_ENVIRONMENT) then
        local elems = {}
        require("ge/extensions/utils/EnvironmentUtils").speedPresets():forEach(function(preset)
            local value = math.round(preset.value, 3)
            local disabled = value == math.round(BJI_Env.Data.simSpeed, 3)
            table.insert(elems, {
                type = "item",
                label = string.var("{1} (x{2})", {
                    BJI_Lang.get(string.var("presets.speed.{1}", { preset.key })),
                    value,
                }),
                disabled = disabled,
                active = disabled,
                checked = disabled,
                onClick = function()
                    BJI_Tx_config.env("simSpeed", value)
                end
            })
        end)
        table.insert(M.cache.elems, {
            type = "menu",
            label = BJI_Lang.get("menu.edit.speed"),
            elems = elems,
        })
    end
end

local function menuSwitchMap(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SWITCH_MAP) and
        BJI_Context.Maps then
        local customMapLabel = BJI_Lang.get("menu.edit.mapCustom")
        local rawMaps = Table(BJI_Context.Maps)
            :filter(function(map) return map.enabled end)

        if rawMaps:length() > 1 then
            if rawMaps:length() <= BJI_Win_Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub elems
                table.insert(M.cache.elems, {
                    type = "menu",
                    label = BJI_Lang.get("menu.edit.map"),
                    elems = rawMaps:map(function(map, mapName)
                        local disabled = mapName == BJI_Context.UI.mapName
                        return {
                            type = "item",
                            label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or map.label,
                            disabled = disabled,
                            active = disabled,
                            checked = disabled,
                            onClick = function()
                                BJI_Tx_config.switchMap(mapName)
                            end
                        }
                    end):sort(function(a, b) return a.label < b.label end)
                })
            else
                -- selection window
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.edit.map"),
                    onClick = function()
                        BJI_Win_Selection.open("menu.edit.map", rawMaps
                            :filter(function(_, mapName) return mapName ~= BJI_Context.UI.mapName end)
                            :map(function(map, mapName)
                                return {
                                    label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or
                                        map.label,
                                    value = mapName,
                                }
                            end):values():sort(function(a, b) return a.label < b.label end) or {}, nil,
                            function(mapName)
                                BJI_Tx_config.switchMap(mapName)
                            end, { BJI_Perm.PERMISSIONS.SWITCH_MAP })
                    end,
                })
            end
        end
    end
end

local function menuFreeroamSettings(ctxt)
    if BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.BJC) and
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CONFIG) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.edit.freeroamSettings"),
            active = BJI_Win_FreeroamSettings.show,
            onClick = function()
                if BJI_Win_FreeroamSettings.show then
                    BJI_Win_FreeroamSettings.onClose()
                else
                    BJI_Win_FreeroamSettings.open()
                end
            end,
        })
    end
end

local function menuEnergyStations(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SCENARIO) and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.STATIONS) then
        local editorOpen = BJI_Win_ScenarioEditor.getState()
        local stationsEditorOpen = editorOpen and
            BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.STATIONS)
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.edit.energyStations")
                :var({ amount = table.length(BJI_Stations.Data.EnergyStations) }),
            active = editorOpen and stationsEditorOpen,
            disabled = editorOpen and not stationsEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI_Win_ScenarioEditor.onClose()
                else
                    BJI_Win_ScenarioEditor.SCENARIOS.STATIONS.open()
                end
            end,
        })
    end
end

local function menuGarages(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SCENARIO) and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.STATIONS) then
        local editorOpen = BJI_Win_ScenarioEditor.getState()
        local garagesEditorOpen = editorOpen and
            BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.GARAGES)
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.edit.garages")
                :var({ amount = #BJI_Stations.Data.Garages }),
            active = editorOpen and garagesEditorOpen,
            disabled = editorOpen and not garagesEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI_Win_ScenarioEditor.onClose()
                else
                    BJI_Win_ScenarioEditor.SCENARIOS.GARAGES.open()
                end
            end,
        })
    end
end

local function menuDeliveries(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SCENARIO) and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.DELIVERIES) then
        local editorOpen = BJI_Win_ScenarioEditor.getState()
        local deliveriesEditorOpen = editorOpen and
            BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.DELIVERIES)
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.edit.deliveries")
                :var({ amount = #BJI_Scenario.Data.Deliveries.Points }),
            active = editorOpen and deliveriesEditorOpen,
            disabled = editorOpen and not deliveriesEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI_Win_ScenarioEditor.onClose()
                else
                    BJI_Win_ScenarioEditor.SCENARIOS.DELIVERIES.open()
                end
            end,
        })
    end
end

local function menuBusLines(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SCENARIO) and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.BUS_LINES) then
        local editorOpen = BJI_Win_ScenarioEditor.getState()
        local busEditorOpen = editorOpen and
            BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.BUS_LINES)
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.edit.buslines")
                :var({ amount = #BJI_Scenario.Data.BusLines }),
            active = editorOpen and busEditorOpen,
            disabled = editorOpen and not busEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI_Win_ScenarioEditor.onClose()
                else
                    BJI_Win_ScenarioEditor.SCENARIOS.BUS_LINES.open()
                end
            end,
        })
    end
end

local function menuRaces(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SCENARIO) and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.RACES) then
        local rawRaces = Table(BJI_Scenario.Data.Races)
            :filter(function(r) return type(r) == "table" end):values()
        local label = string.var("{1} ({2})", { BJI_Lang.get("menu.edit.races"), #rawRaces })
        if BJI_Win_ScenarioEditor.getState() then
            -- editor already open
            local isEditorRace = BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.RACE)
            table.insert(M.cache.elems, {
                type = "item",
                label = label,
                active = isEditorRace,
                disabled = not isEditorRace,
                onClick = BJI_Win_ScenarioEditor.onClose,
            })
        else
            if #rawRaces + 1 <= BJI_Win_Selection.LIMIT_ELEMS_THRESHOLD then
                table.insert(M.cache.elems, {
                    type = "menu",
                    label = label,
                    elems = Table({
                        {
                            type = "item",
                            label = BJI_Lang.get("menu.edit.raceCreate"),
                            onClick = BJI_Win_ScenarioEditor.SCENARIOS.RACE.openWithID,
                        }
                    }):addAll(rawRaces:map(function(race)
                        return {
                            type = "custom",
                            render = function()
                                if IconButton("toggle-" .. tostring(race.id), race.enabled and BJI.Utils.Icon.ICONS.visibility or
                                        BJI.Utils.Icon.ICONS.visibility_off, { btnStyle = race.enabled and
                                            BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                                    BJI_Tx_scenario.RaceToggle(race.id, not race.enabled)
                                end
                                TooltipText(BJI_Lang.get("common.buttons.toggle"))

                                SameLine()
                                if IconButton("editRace-" .. tostring(race.id), BJI.Utils.Icon.ICONS.mode_edit,
                                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                                    BJI_Win_ScenarioEditor.SCENARIOS.RACE.openWithID(race.id)
                                end
                                TooltipText(BJI_Lang.get("common.buttons.edit"))

                                SameLine()
                                if IconButton("copyRace-" .. tostring(race.id), BJI.Utils.Icon.ICONS.content_copy,
                                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                                    BJI_Win_ScenarioEditor.SCENARIOS.RACE.openWithID(race.id, true)
                                end
                                TooltipText(BJI_Lang.get("common.buttons.duplicate"))

                                SameLine()
                                if IconButton("deleteRace-" .. tostring(race.id), BJI.Utils.Icon.ICONS.delete_forever,
                                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                                    BJI_Popup.createModal(
                                        BJI_Lang.get("menu.edit.raceDeleteModal")
                                        :var({ raceName = race.name }), {
                                            BJI_Popup.createButton(BJI_Lang.get(
                                                "common.buttons.cancel"
                                            )),
                                            BJI_Popup.createButton(BJI_Lang.get(
                                                    "common.buttons.confirm"
                                                ),
                                                function()
                                                    BJI_Tx_scenario.RaceDelete(race.id)
                                                end)
                                        })
                                end
                                TooltipText(BJI_Lang.get("common.buttons.delete"))

                                SameLine()
                                Text(race.name)
                            end,
                        }
                    end)),
                })
            else
                -- open selection window
                table.insert(M.cache.elems, {
                    type = "item",
                    label = label,
                    onClick = function()
                        BJI_Win_Selection.open("menu.edit.races", Table({ {
                            label = BJI_Lang.get("menu.edit.raceCreate"),
                            value = nil,
                        } }):addAll(rawRaces:map(function(r)
                            return {
                                label = r.name,
                                value = r.id,
                            }
                        end)), function(raceID, onClose)
                            if not raceID then
                                -- create race
                                SameLine()
                                if IconButton("createRace", BJI.Utils.Icon.ICONS.add,
                                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                                    BJI_Win_ScenarioEditor.SCENARIOS.RACE.openWithID()
                                    onClose()
                                end
                                TooltipText(BJI_Lang.get("common.buttons.create"))
                                return
                            end
                            rawRaces:find(function(r) return r.id == raceID end, function(race)
                                SameLine()
                                if IconButton("editRace-" .. tostring(raceID), BJI.Utils.Icon.ICONS.mode_edit,
                                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                                    BJI_Win_ScenarioEditor.SCENARIOS.RACE.openWithID(race.id)
                                    onClose()
                                end
                                TooltipText(BJI_Lang.get("common.buttons.edit"))

                                SameLine()
                                if IconButton("copyRace-" .. tostring(raceID), BJI.Utils.Icon.ICONS.content_copy,
                                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                                    BJI_Win_ScenarioEditor.SCENARIOS.RACE.openWithID(race.id, true)
                                    onClose()
                                end
                                TooltipText(BJI_Lang.get("common.buttons.duplicate"))

                                SameLine()
                                if IconButton("deleteRace-" .. tostring(raceID), BJI.Utils.Icon.ICONS.delete_forever,
                                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                                    BJI_Popup.createModal(
                                        BJI_Lang.get("menu.edit.raceDeleteModal")
                                        :var({ raceName = race.name }),
                                        {
                                            BJI_Popup.createButton(BJI_Lang.get(
                                                "common.buttons.cancel"
                                            )),
                                            BJI_Popup.createButton(BJI_Lang.get(
                                                "common.buttons.confirm"
                                            ), function()
                                                BJI_Tx_scenario.RaceDelete(race.id)
                                                onClose()
                                            end),
                                        })
                                end
                                TooltipText(BJI_Lang.get("common.buttons.delete"))
                            end)
                        end, nil, { BJI_Perm.PERMISSIONS.SCENARIO })
                    end,
                })
            end
        end
    end
end

local function menuHunterInfected(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SCENARIO) and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.HUNTER_INFECTED_DATA) then
        local editorOpen = BJI_Win_ScenarioEditor.getState()
        local hunterEditorOpen = editorOpen and
            BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.HUNTER_INFECTED)
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.edit.hunter"):var({
                state = BJI_Lang.get(BJI_Scenario.Data.HunterInfected
                    .enabledHunter and "common.enabled" or "common.disabled"),
            }),
            active = editorOpen and hunterEditorOpen,
            disabled = editorOpen and not hunterEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI_Win_ScenarioEditor.onClose()
                else
                    BJI_Win_ScenarioEditor.SCENARIOS.HUNTER_INFECTED.open(1)
                end
            end,
        })
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.edit.infected"):var({
                state = BJI_Lang.get(BJI_Scenario.Data.HunterInfected
                    .enabledInfected and "common.enabled" or "common.disabled"),
            }),
            active = editorOpen and hunterEditorOpen,
            disabled = editorOpen and not hunterEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI_Win_ScenarioEditor.onClose()
                else
                    BJI_Win_ScenarioEditor.SCENARIOS.HUNTER_INFECTED.open(2)
                end
            end,
        })
    end
end

local function menuDerby(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SCENARIO) and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.DERBY_DATA) then
        local editorOpen = BJI_Win_ScenarioEditor.getState()
        local derbyEditorOpen = editorOpen and
            BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.DERBY)
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.edit.derby")
                :var({ amount = #BJI_Scenario.Data.Derby }),
            active = editorOpen and derbyEditorOpen,
            disabled = editorOpen and not derbyEditorOpen,
            onClick = function()
                if editorOpen then
                    BJI_Win_ScenarioEditor.onClose()
                else
                    BJI_Win_ScenarioEditor.SCENARIOS.DERBY.open()
                end
            end
        })
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()
    M.cache = {
        label = BJI_Lang.get("menu.edit.title"),
        elems = {},
    }

    menuTimePresets(ctxt)
    menuWeatherPresets(ctxt)
    menuGravityPresets(ctxt)
    menuSpeedPresets(ctxt)

    if BJI_Scenario.is(BJI_Scenario.TYPES.FREEROAM) then
        menuSwitchMap(ctxt)
    end

    table.insert(M.cache.elems, { type = "separator" })
    menuFreeroamSettings(ctxt)

    if BJI_Scenario.is(BJI_Scenario.TYPES.FREEROAM) then
        -- scenario editors
        menuEnergyStations(ctxt)
        menuGarages(ctxt)
        menuDeliveries(ctxt)
        menuBusLines(ctxt)
        menuRaces(ctxt)
        menuHunterInfected(ctxt)
        menuDerby(ctxt)
    end

    MenuDropdownSanitize(M.cache.elems)
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.SCENARIO_EDITOR_UPDATED,
        BJI_Events.EVENTS.ENV_CHANGED,
        BJI_Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache, "MainMenuEdit"))

    ---@param data {cache: string}
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({
                BJI_Cache.CACHES.BJC,
                BJI_Cache.CACHES.MAPS,
                BJI_Cache.CACHES.STATIONS,
                BJI_Cache.CACHES.RACES,
                BJI_Cache.CACHES.DELIVERIES,
                BJI_Cache.CACHES.BUS_LINES,
                BJI_Cache.CACHES.HUNTER_INFECTED_DATA,
                BJI_Cache.CACHES.DERBY_DATA,
            }, data.cache) then
            updateCache(ctxt)
        end
    end, "MainMenuEdit"))
end

function M.onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

---@param ctxt TickContext
function M.draw(ctxt)
    if #M.cache.elems > 0 then
        RenderMenuDropdown(M.cache.label, M.cache.elems)
    end
end

return M
