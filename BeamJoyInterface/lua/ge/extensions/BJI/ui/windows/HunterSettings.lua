---@class BJIWindowHunterSettings : BJIWindow
local W = {
    name = "HunterSettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    minSize = ImVec2(550, 330),
    maxSize = ImVec2(800, 330),

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
            startVote = "",
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
        canSpawnNewVeh = false,

        showVoteBtn = false,
        showStartBtn = false,
    },
}
--- gc prevention
local nextValue, tooltip

local function onClose()
    W.show = false
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
end

local function updateLabels()
    W.labels.title = BJI_Lang.get("hunter.settings.title")
    W.labels.huntedWaypoints = BJI_Lang.get("hunter.settings.huntedWaypoints")
    W.labels.huntedWaypointsTooltip = BJI_Lang.get("hunter.settings.huntedWaypointsTooltip")
    W.labels.huntedConfig = BJI_Lang.get("hunter.settings.huntedConfig")
    W.labels.huntedConfigTooltip = BJI_Lang.get("hunter.settings.huntedConfigTooltip")
    W.labels.hunterConfigs = BJI_Lang.get("hunter.settings.hunterConfigs")
    W.labels.hunterConfigsTooltip = BJI_Lang.get("hunter.settings.hunterConfigsTooltip")
    W.labels.lastWaypointGPS = BJI_Lang.get("hunter.settings.lastWaypointGPS")
    W.labels.lastWaypointGPSTooltip = BJI_Lang.get("hunter.settings.lastWaypointGPSTooltip")
    W.labels.specificConfig = BJI_Lang.get("hunter.settings.specificConfig")

    W.labels.protectedVehicle = BJI_Lang.get("vehicleSelector.protectedVehicle")
    W.labels.selfProtected = BJI_Lang.get("vehicleSelector.selfProtected")

    W.labels.buttons.spawn = BJI_Lang.get("common.buttons.spawn")
    W.labels.buttons.replace = BJI_Lang.get("common.buttons.replace")
    W.labels.buttons.set = BJI_Lang.get("common.buttons.set")
    W.labels.buttons.remove = BJI_Lang.get("common.buttons.remove")
    W.labels.buttons.add = BJI_Lang.get("common.buttons.add")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.startVote = BJI_Lang.get("common.buttons.startVote")
    W.labels.buttons.start = BJI_Lang.get("common.buttons.start")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    W.data.currentVehProtected = ctxt.veh and not ctxt.isOwner and ctxt.veh.protected
    W.data.selfProtected = ctxt.isOwner and settings.getValue("protectConfigFromClone", false) == true
    W.data.canSpawnNewVeh = BJI_Perm.canSpawnNewVehicle()

    W.data.showVoteBtn = not BJI_Tournament.state and
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)
    W.data.showStartBtn = BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.UI_SCALE_CHANGED,
        BJI_Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI_Events.EVENTS.CONFIG_PROTECTION_UPDATED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.TOURNAMENT_UPDATED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))

    -- autoclose handler
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
    }, function(ctxt, data)
        local mustClose, msg = false, ""
        if data._event == BJI_Events.EVENTS.CACHE_LOADED and
            (
                data.cache == BJI_Cache.CACHES.PLAYERS or
                data.cache == BJI_Cache.CACHES.HUNTER_INFECTED_DATA
            ) then
            if BJI_Perm.getCountPlayersCanSpawnVehicle() < BJI_Scenario.get(BJI_Scenario.TYPES.HUNTER).MINIMUM_PARTICIPANTS then
                mustClose, msg = true, BJI_Lang.get("hunter.settings.notEnoughPlayers")
            elseif not BJI_Context.Scenario.Data.HunterInfected.enabledHunter then
                mustClose, msg = true, BJI_Lang.get("menu.scenario.hunter.modeDisabled")
            end
        else
            if not BJI_Scenario.is(BJI_Scenario.TYPES.FREEROAM) or
                (not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) and
                    not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)) then
                mustClose = true
            end
        end
        if mustClose then
            if msg then
                BJI_Toast.warning(msg)
            end
            onClose()
        end
    end, W.name .. "AutoClose"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

---@param ctxt TickContext
local function drawHeader(ctxt)
    Text(W.labels.title)
end

---@param ctxt TickContext
---@return ClientVehicleConfig?
local function getConfig(ctxt)
    if not ctxt.veh then return end
    return BJI_Veh.getFullConfig(ctxt.veh.veh.partConfig)
end

---@param ctxt TickContext
local function drawBody(ctxt)
    if BeginTable("BJIHunterSettings", {
            { label = "##hunter-settings-labels" },
            { label = "##hunter-settings-actions", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
        }) then
        TableNewRow()
        Text(W.labels.huntedWaypoints)
        TooltipText(W.labels.huntedWaypointsTooltip)
        TableNextColumn()
        nextValue = SliderInt("huntedWaypoints", W.data.waypoints, 1, 50)
        TooltipText(W.labels.huntedWaypointsTooltip)
        if nextValue then W.data.waypoints = nextValue end

        TableNewRow()
        Text(W.labels.huntedConfig)
        TooltipText(W.labels.huntedConfigTooltip)
        TableNextColumn()
        if W.data.huntedConfig then
            if IconButton("showHuntedConfig", BJI.Utils.Icon.ICONS.visibility,
                    { btnStyle = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = not ctxt.isOwner and
                        not W.data.canSpawnNewVeh }) then
                BJI_Veh.replaceOrSpawnVehicle(W.data.huntedConfig.model,
                    W.data.huntedConfig.key or W.data.huntedConfig)
            end
            TooltipText(ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn)
            SameLine()
            if IconButton("refreshHuntedConfig", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = not ctxt.veh }) then
                if BJI_Veh.isModelBlacklisted(ctxt.veh.jbeam) then
                    BJI_Toast.error(BJI_Lang.get("errors.toastModelBlacklisted"))
                else
                    W.data.huntedConfig = getConfig(ctxt)
                end
            end
            TooltipText(W.labels.buttons.set)
            SameLine()
            if IconButton("removeHuntedConfig", BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                W.data.huntedConfig = nil
            end
            TooltipText(W.labels.buttons.remove)
            if W.data.huntedConfig then -- on remove safe
                SameLine()
                Text(W.data.huntedConfig.label)
            end
        else
            if IconButton("addHuntedConfig", BJI.Utils.Icon.ICONS.add,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = not ctxt.veh or W.data.currentVehProtected or W.data.selfProtected }) then
                if BJI_Veh.isModelBlacklisted(ctxt.veh.jbeam) then
                    BJI_Toast.error(BJI_Lang.get("errors.toastModelBlacklisted"))
                else
                    W.data.huntedConfig = getConfig(ctxt)
                end
            end
            if W.data.currentVehProtected then
                tooltip = W.labels.protectedVehicle
            elseif W.data.selfProtected then
                tooltip = W.labels.selfProtected
            else
                tooltip = W.labels.buttons.add
            end
            TooltipText(tooltip)
        end

        TableNewRow()
        Text(W.labels.hunterConfigs)
        TooltipText(W.labels.hunterConfigsTooltip)
        TableNextColumn()
        W.data.hunterConfigs:forEach(function(config, i)
            if IconButton("showHunterConfig" .. tostring(i), BJI.Utils.Icon.ICONS.visibility,
                    { btnStyle = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = not ctxt.isOwner and
                        not W.data.canSpawnNewVeh }) then
                BJI_Veh.replaceOrSpawnVehicle(config.model, config.key or config)
            end
            TooltipText(ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn)
            SameLine()
            if IconButton("removeHunterConfig" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                W.data.hunterConfigs:remove(i)
            end
            TooltipText(W.labels.buttons.remove)
            SameLine()
            Text(config.label)
        end)
        if #W.data.hunterConfigs < 5 then
            if IconButton("addHunterConfig", BJI.Utils.Icon.ICONS.add,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = not ctxt.veh or W.data.currentVehProtected or W.data.selfProtected }) then
                local newConf = getConfig(ctxt) or {}
                if W.data.hunterConfigs:any(function(c)
                        return newConf.model == c.model and
                            table.compare(newConf.parts, c.parts)
                    end) then
                    BJI_Toast.error(BJI_Lang.get(
                        "hunter.settings.toastConfigAlreadySaved"))
                else
                    W.data.hunterConfigs:insert(newConf)
                end
            end
            if W.data.currentVehProtected then
                tooltip = W.labels.protectedVehicle
            elseif W.data.selfProtected then
                tooltip = W.labels.selfProtected
            else
                tooltip = W.labels.buttons.add
            end
            TooltipText(tooltip)
        end

        TableNewRow()
        Text(W.labels.lastWaypointGPS)
        TooltipText(W.labels.lastWaypointGPSTooltip)
        TableNextColumn()
        if IconButton("lastWaypointGPS", W.data.lastWaypointGPS and BJI.Utils.Icon.ICONS.check_circle or
                BJI.Utils.Icon.ICONS.cancel, { bgLess = true, btnStyle = W.data.lastWaypointGPS and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            W.data.lastWaypointGPS = not W.data.lastWaypointGPS
        end

        EndTable()
    end
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    if IconButton("closeHunterSettings", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.data.showVoteBtn then
        SameLine()
        if IconButton("startVoteHunter", BJI.Utils.Icon.ICONS.event_available,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            BJI_Tx_vote.ScenarioStart(BJI_Votes.SCENARIO_TYPES.HUNTER, true, {
                waypoints = W.data.waypoints,
                huntedConfig = W.data.huntedConfig,
                hunterConfigs = W.data.hunterConfigs,
                lastWaypointGPS = W.data.lastWaypointGPS,
            })
            onClose()
        end
        TooltipText(W.labels.buttons.startVote)
    end
    if W.data.showStartBtn then
        SameLine()
        if IconButton("startHunter", BJI.Utils.Icon.ICONS.videogame_asset,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            BJI_Tx_vote.ScenarioStart(BJI_Votes.SCENARIO_TYPES.HUNTER, false, {
                waypoints = W.data.waypoints,
                huntedConfig = W.data.huntedConfig,
                hunterConfigs = W.data.hunterConfigs,
                lastWaypointGPS = W.data.lastWaypointGPS,
            })
            onClose()
        end
        TooltipText(W.labels.buttons.start)
    end
end

local function open()
    W.show = true
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
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
