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
    },
    data = {
        waypoints = 3,
        huntedConfig = nil,
        ---@type tablelib<integer, {label: string, model: string, config: {parts: table<string,string>}}>
        hunterConfigs = Table(),
        lastWaypointGPS = true,
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
        local w = BJI.Utils.Common.GetColumnTextWidth(label .. HELPMARKER_TEXT)
        return w > acc and w or acc
    end, 0)
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
    end))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache))

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
            if not BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.FREEROAM) then
                mustClose, msg = true, "Scenario changed"     -- TODO i18n
            elseif not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) then
                mustClose, msg = true, "Permission decreased" -- TODO i18n
            end
        end
        if mustClose then
            BJI.Managers.Toast.warning(msg)
            onClose()
        end
    end))
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

    return {
        model = ctxt.veh.jbeam,
        label = BJI.Managers.Veh.isConfigCustom(ctxt.veh.partConfig) and W.labels.specificConfig
            :var({ model = BJI.Managers.Veh.getModelLabel(ctxt.veh.jbeam) }) or
            string.var("{1} {2}", { BJI.Managers.Veh.getModelLabel(ctxt.veh.jbeam),
                BJI.Managers.Veh.getCurrentConfigLabel() }),
        config = BJI.Managers.Veh.getFullConfig(ctxt.veh.partConfig),
    }
end

---@param ctxt TickContext
local function drawBody(ctxt)
    local cols = ColumnsBuilder("BJIHunterSettings", { W.widths.labels, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder():text(W.labels.huntedWaypoints)
                        :helpMarker(W.labels.huntedWaypointsTooltip):build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "huntedWaypoints",
                            type = "int",
                            value = W.data.waypoints,
                            min = 1,
                            max = 50,
                            step = 1,
                            onUpdate = function(val)
                                W.data.waypoints = val
                            end
                        })
                        :build()
                end,
            }
        })

    cols:addRow({
        cells = {
            function()
                LineBuilder():text(W.labels.huntedConfig)
                    :helpMarker(W.labels.huntedConfigTooltip):build()
            end,
            function()
                local line = LineBuilder()
                if W.data.huntedConfig then
                    line:btnIcon({
                        id = "showHuntedConfig",
                        icon = ctxt.isOwner and ICONS.carSensors or ICONS.visibility,
                        style = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                            BJI.Utils.Style.BTN_PRESETS.INFO,
                        onClick = function()
                            local fn = ctxt.isOwner and BJI.Managers.Veh.replaceOrSpawnVehicle or
                                BJI.Managers.Veh.spawnNewVehicle
                            fn(W.data.huntedConfig.model, W.data.huntedConfig.config)
                        end,
                    })
                        :btnIcon({
                            id = "refreshHuntedConfig",
                            icon = ICONS.refresh,
                            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = not ctxt.veh,
                            onClick = function()
                                if BJI.Managers.Veh.isModelBlacklisted(ctxt.veh.jbeam) then
                                    BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.toastModelBlacklisted"))
                                else
                                    W.data.huntedConfig = getConfig(ctxt)
                                end
                            end,
                        })
                        :btnIcon({
                            id = "removeHuntedConfig",
                            icon = ICONS.delete_forever,
                            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                            onClick = function()
                                W.data.huntedConfig = nil
                            end,
                        })
                        :text(W.data.huntedConfig.label)
                else
                    line:btnIcon({
                        id = "addHuntedConfig",
                        icon = ICONS.addListItem,
                        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = not ctxt.veh,
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
        local confData = W.data.hunterConfigs[i]
        cols:addRow({
            cells = {
                function()
                    if i == 1 then
                        LineBuilder()
                            :text(W.labels.hunterConfigs)
                            :helpMarker(W.labels.hunterConfigsTooltip)
                            :build()
                    end
                end,
                function()
                    if confData then
                        LineBuilder()
                            :btnIcon({
                                id = string.var("showHunterConfig{1}", { i }),
                                icon = ctxt.isOwner and ICONS.carSensors or ICONS.visibility,
                                style = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                                    BJI.Utils.Style.BTN_PRESETS.INFO,
                                disabled = not ctxt.isOwner,
                                onClick = function()
                                    local fn = ctxt.isOwner and BJI.Managers.Veh.replaceOrSpawnVehicle or
                                        BJI.Managers.Veh.spawnNewVehicle
                                    fn(confData.model, confData.config)
                                end,
                            })
                            :btnIcon({
                                id = string.var("removeHunterConfig{1}", { i }),
                                icon = ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                onClick = function()
                                    table.remove(W.data.hunterConfigs, i)
                                end,
                            })
                            :text(confData.label)
                            :build()
                    else
                        LineBuilder()
                            :btnIcon({
                                id = "addHunterConfig",
                                icon = ICONS.addListItem,
                                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                                disabled = not ctxt.veh,
                                onClick = function()
                                    local config = getConfig(ctxt) or {}
                                    if W.data.hunterConfigs:any(function(c)
                                            return config.model == c.model and
                                                table.compare(config.config, c.config)
                                        end) then
                                        BJI.Managers.Toast.error(BJI.Managers.Lang.get(
                                            "hunter.settings.toastConfigAlreadySaved"))
                                    else
                                        table.insert(W.data.hunterConfigs, config)
                                    end
                                end,
                            })
                            :build()
                    end
                end,
            }
        })
    end)

    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(W.labels.lastWaypointGPS)
                    :helpMarker(W.labels.lastWaypointGPSTooltip)
                    :build()
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
    LineBuilder()
        :btnIcon({
            id = "closeHunterSettings",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :btnIcon({
            id = "startHunter",
            icon = ICONS.videogame_asset,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            onClick = function()
                BJI.Tx.scenario.HunterStart({
                    waypoints = W.data.waypoints,
                    huntedConfig = W.data.huntedConfig,
                    hunterConfigs = W.data.hunterConfigs,
                    lastWaypointGPS = W.data.lastWaypointGPS,
                })
                onClose()
            end
        })
        :build()
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
