---@class BJIWindowHunterSettings : BJIWindow
local W = {
    name = "HunterSettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    w = 350,
    h = 350,

    show = false,
    labels = {
        title = "",
        huntedWaypoints = "",
        huntedWaypointsTooltip = "",
        huntedConfig = "",
        huntedConfigTooltip = "",
        hunterConfigs = "",
        hunterConfigsTooltip = "",
        specificConfig = "",
        lastWaypointGPS = "",
        lastWaypointGPSTooltip = "",

        protectedVehicle = "",
        selfProtected = "",

        buttons = {
            spawn = "",
            replace = "",
            set = "",
            remove = "",
            add = "",
            close = "",
            start = "",
        },
    },
    data = {
        waypoints = 3,
        huntedConfig = nil,
        ---@type tablelib<integer, {label: string, model: string, config: {parts: table<string,string>}}>
        hunterConfigs = Table(),
        lastWaypointGPS = true,

        currentVehProtected = false,
        selfProtected = false,
    },
    widths = {
        labels = 0,
    },
}

local function onClose()
    W.show = false
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("hunter.settings.title")
    W.labels.huntedWaypoints = BJI.Managers.Lang.get("hunter.settings.huntedWaypoints")
    W.labels.huntedWaypointsTooltip = BJI.Managers.Lang.get("hunter.settings.huntedWaypointsTooltip")
    W.labels.huntedConfig = BJI.Managers.Lang.get("hunter.settings.huntedConfig")
    W.labels.huntedConfigTooltip = BJI.Managers.Lang.get("hunter.settings.huntedConfigTooltip")
    W.labels.hunterConfigs = BJI.Managers.Lang.get("hunter.settings.hunterConfigs")
    W.labels.hunterConfigsTooltip = BJI.Managers.Lang.get("hunter.settings.hunterConfigsTooltip")
    W.labels.lastWaypointGPS = BJI.Managers.Lang.get("hunter.settings.lastWaypointGPS")
    W.labels.lastWaypointGPSTooltip = BJI.Managers.Lang.get("hunter.settings.lastWaypointGPSTooltip")
    W.labels.specificConfig = BJI.Managers.Lang.get("hunter.settings.specificConfig")

    W.labels.protectedVehicle = BJI.Managers.Lang.get("vehicleSelector.protectedVehicle")
    W.labels.selfProtected = BJI.Managers.Lang.get("vehicleSelector.selfProtected")

    W.labels.buttons.spawn = BJI.Managers.Lang.get("common.buttons.spawn")
    W.labels.buttons.replace = BJI.Managers.Lang.get("common.buttons.replace")
    W.labels.buttons.set = BJI.Managers.Lang.get("common.buttons.set")
    W.labels.buttons.remove = BJI.Managers.Lang.get("common.buttons.remove")
    W.labels.buttons.add = BJI.Managers.Lang.get("common.buttons.add")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.start = BJI.Managers.Lang.get("common.buttons.start")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.widths.labels = Table({
        W.labels.huntedWaypoints,
        W.labels.huntedConfig,
        W.labels.hunterConfigs,
        W.labels.lastWaypointGPS,
    }):reduce(function(acc, label)
        local w = BJI.Utils.UI.GetColumnTextWidth(label)
        return w > acc and w or acc
    end, 0)

    W.data.currentVehProtected = ctxt.veh and not ctxt.isOwner and ctxt.veh.protected
    W.data.selfProtected = ctxt.isOwner and settings.getValue("protectConfigFromClone", false) == true
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.CONFIG_PROTECTION_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))

    -- autoclose handler
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
    }, function(ctxt, data)
        local mustClose, msg = false, ""
        if data._event == BJI.Managers.Events.EVENTS.CACHE_LOADED and
            (
                data.cache == BJI.Managers.Cache.CACHES.PLAYERS or
                data.cache == BJI.Managers.Cache.CACHES.HUNTER_DATA
            ) then
            if BJI.Managers.Perm.getCountPlayersCanSpawnVehicle() < BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.HUNTER).MINIMUM_PARTICIPANTS then
                mustClose, msg = true, BJI.Managers.Lang.get("hunter.settings.notEnoughPlayers")
            elseif not BJI.Managers.Context.Scenario.Data.Hunter.enabled then
                mustClose, msg = true, BJI.Managers.Lang.get("menu.scenario.hunter.modeDisabled")
            end
        else
            if not BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.FREEROAM) or
                not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) then
                mustClose = true
            end
        end
        if mustClose then
            if msg then
                BJI.Managers.Toast.warning(msg)
            end
            onClose()
        end
    end, W.name .. "AutoClose"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param ctxt TickContext
local function drawHeader(ctxt)
    LineLabel(W.labels.title)
end

---@param ctxt TickContext
local function getConfig(ctxt)
    if not ctxt.veh then
        return
    end
    return BJI.Managers.Veh.getFullConfig(ctxt.veh.veh.partConfig)
end

---@param ctxt TickContext
local function drawBody(ctxt)
    local cols = ColumnsBuilder("BJIHunterSettings", { W.widths.labels, -1 })
        :addRow({
            cells = {
                function()
                    LineLabel(W.labels.huntedWaypoints, nil, false, W.labels.huntedWaypointsTooltip)
                end,
                function()
                    LineBuilder():inputNumeric({
                        id = "huntedWaypoints",
                        type = "int",
                        value = W.data.waypoints,
                        min = 1,
                        max = 50,
                        step = 1,
                        onUpdate = function(val)
                            W.data.waypoints = val
                        end
                    }):build()
                end,
            }
        })

    cols:addRow({
        cells = {
            function()
                LineLabel(W.labels.huntedConfig, nil, false, W.labels.huntedConfigTooltip)
            end,
            function()
                local line = LineBuilder()
                if W.data.huntedConfig then
                    line:btnIcon({
                        id = "showHuntedConfig",
                        icon = ctxt.isOwner and BJI.Utils.Icon.ICONS.carSensors or BJI.Utils.Icon.ICONS.visibility,
                        style = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                            BJI.Utils.Style.BTN_PRESETS.INFO,
                        tooltip = ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn,
                        onClick = function()
                            local fn = ctxt.isOwner and BJI.Managers.Veh.replaceOrSpawnVehicle or
                                BJI.Managers.Veh.spawnNewVehicle
                            fn(W.data.huntedConfig.model, W.data.huntedConfig)
                        end,
                    }):btnIcon({
                        id = "refreshHuntedConfig",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not ctxt.veh,
                        tooltip = W.labels.buttons.set,
                        onClick = function()
                            if BJI.Managers.Veh.isModelBlacklisted(ctxt.veh.jbeam) then
                                BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.toastModelBlacklisted"))
                            else
                                W.data.huntedConfig = getConfig(ctxt)
                            end
                        end,
                    }):btnIcon({
                        id = "removeHuntedConfig",
                        icon = BJI.Utils.Icon.ICONS.delete_forever,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        tooltip = W.labels.buttons.remove,
                        onClick = function()
                            W.data.huntedConfig = nil
                        end,
                    }):text(W.data.huntedConfig.label)
                else
                    local tooltip
                    if W.data.currentVehProtected then
                        tooltip = W.labels.protectedVehicle
                    elseif W.data.selfProtected then
                        tooltip = W.labels.selfProtected
                    else
                        tooltip = W.labels.buttons.add
                    end
                    line:btnIcon({
                        id = "addHuntedConfig",
                        icon = BJI.Utils.Icon.ICONS.add,
                        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = not ctxt.veh or W.data.currentVehProtected or W.data.selfProtected,
                        tooltip = tooltip,
                        onClick = function()
                            if BJI.Managers.Veh.isModelBlacklisted(ctxt.veh.jbeam) then
                                BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.toastModelBlacklisted"))
                            else
                                W.data.huntedConfig = getConfig(ctxt)
                            end
                        end,
                    })
                end
                line:build()
            end,
        }
    })

    Range(1, math.min(#W.data.hunterConfigs + 1, 5)):forEach(function(i)
        local config = W.data.hunterConfigs[i]
        cols:addRow({
            cells = {
                function()
                    if i == 1 then
                        LineLabel(W.labels.hunterConfigs, nil, false, W.labels.hunterConfigsTooltip)
                    end
                end,
                function()
                    if config then
                        LineBuilder():btnIcon({
                            id = string.var("showHunterConfig{1}", { i }),
                            icon = ctxt.isOwner and BJI.Utils.Icon.ICONS.carSensors or BJI.Utils.Icon.ICONS.visibility,
                            style = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                                BJI.Utils.Style.BTN_PRESETS.INFO,
                            tooltip = ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn,
                            onClick = function()
                                local fn = ctxt.isOwner and BJI.Managers.Veh.replaceOrSpawnVehicle or
                                    BJI.Managers.Veh.spawnNewVehicle
                                fn(config.model, config.key or config)
                            end,
                        }):btnIcon({
                            id = string.var("removeHunterConfig{1}", { i }),
                            icon = BJI.Utils.Icon.ICONS.delete_forever,
                            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                            tooltip = W.labels.buttons.remove,
                            onClick = function()
                                table.remove(W.data.hunterConfigs, i)
                            end,
                        }):text(config.label):build()
                    else
                        local tooltip
                        if W.data.currentVehProtected then
                            tooltip = W.labels.protectedVehicle
                        elseif W.data.selfProtected then
                            tooltip = W.labels.selfProtected
                        else
                            tooltip = W.labels.buttons.add
                        end
                        LineBuilder():btnIcon({
                            id = "addHunterConfig",
                            icon = BJI.Utils.Icon.ICONS.add,
                            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                            disabled = not ctxt.veh or W.data.currentVehProtected or W.data.selfProtected,
                            tooltip = tooltip,
                            onClick = function()
                                local newConf = getConfig(ctxt) or {}
                                if W.data.hunterConfigs:any(function(c)
                                        return newConf.model == c.model and
                                            table.compare(newConf.parts, c.parts)
                                    end) then
                                    BJI.Managers.Toast.error(BJI.Managers.Lang.get(
                                        "hunter.settings.toastConfigAlreadySaved"))
                                else
                                    table.insert(W.data.hunterConfigs, newConf)
                                end
                            end,
                        }):build()
                    end
                end,
            }
        })
    end)

    cols:addRow({
        cells = {
            function()
                LineLabel(W.labels.lastWaypointGPS, nil, false, W.labels.lastWaypointGPSTooltip)
            end,
            function()
                LineBuilder()
                    :btnIconToggle({
                        id = "lastWaypointGPS",
                        state = W.data.lastWaypointGPS,
                        coloredIcon = true,
                        onClick = function()
                            W.data.lastWaypointGPS = not W.data.lastWaypointGPS
                        end,
                    })
                    :build()
            end
        }
    })
    cols:build()
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    LineBuilder():btnIcon({
        id = "closeHunterSettings",
        icon = BJI.Utils.Icon.ICONS.exit_to_app,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = W.labels.buttons.close,
        onClick = onClose,
    }):btnIcon({
        id = "startHunter",
        icon = BJI.Utils.Icon.ICONS.videogame_asset,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        tooltip = W.labels.buttons.start,
        onClick = function()
            BJI.Tx.scenario.HunterStart({
                waypoints = W.data.waypoints,
                huntedConfig = W.data.huntedConfig,
                hunterConfigs = W.data.hunterConfigs,
                lastWaypointGPS = W.data.lastWaypointGPS,
            })
            onClose()
        end
    }):build()
end

local function open()
    W.show = true
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
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
