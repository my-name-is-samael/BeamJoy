---@class BJIWindowInfectedSettings : BJIWindow
local W = {
    name = "InfectedSettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
        BJI.Utils.Style.WINDOW_FLAGS.ALWAYS_AUTO_RESIZE,
    },

    show = false,
    labels = {
        title = "",
        endAfterLastSurvivorInfected = "",
        endAfterLastSurvivorInfectedTooltip = "",
        config = "",
        enableColors = "",
        survivorsColor = "",
        infectedColor = "",

        protectedVehicle = "",
        selfProtected = "",

        buttons = {
            spawn = "",
            replace = "",
            set = "",
            remove = "",
            add = "",
            reset = "",
            close = "",
            startVote = "",
            start = "",
        },
    },
    data = {
        endAfterLastSurvivorInfected = false,
        ---@type ClientVehicleConfig?
        config = nil,
        enableColors = false,
        survivorsColor = nil,
        infectedColor = nil,
        configLabel = "",

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
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

local function updateLabels()
    W.labels.endAfterLastSurvivorInfected = BJI.Managers.Lang.get("infected.settings.endAfterLastSurvivorInfected")
    W.labels.endAfterLastSurvivorInfectedTooltip = BJI.Managers.Lang.get(
        "infected.settings.endAfterLastSurvivorInfectedTooltip")
    W.labels.config = BJI.Managers.Lang.get("infected.settings.config")
    W.labels.enableColors = BJI.Managers.Lang.get("infected.settings.enableColors")
    W.labels.survivorsColor = BJI.Managers.Lang.get("infected.settings.survivorsColor")
    W.labels.infectedColor = BJI.Managers.Lang.get("infected.settings.infectedColor")

    W.labels.protectedVehicle = BJI.Managers.Lang.get("vehicleSelector.protectedVehicle")
    W.labels.selfProtected = BJI.Managers.Lang.get("vehicleSelector.selfProtected")

    W.labels.buttons.spawn = BJI.Managers.Lang.get("common.buttons.spawn")
    W.labels.buttons.replace = BJI.Managers.Lang.get("common.buttons.replace")
    W.labels.buttons.set = BJI.Managers.Lang.get("common.buttons.set")
    W.labels.buttons.remove = BJI.Managers.Lang.get("common.buttons.remove")
    W.labels.buttons.add = BJI.Managers.Lang.get("common.buttons.add")
    W.labels.buttons.reset = BJI.Managers.Lang.get("common.buttons.reset")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.startVote = BJI.Managers.Lang.get("common.buttons.startVote")
    W.labels.buttons.start = BJI.Managers.Lang.get("common.buttons.start")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.data.currentVehProtected = ctxt.veh and not ctxt.isOwner and ctxt.veh.protected
    W.data.selfProtected = ctxt.isOwner and settings.getValue("protectConfigFromClone", false) == true
    W.data.canSpawnNewVeh = BJI.Managers.Perm.canSpawnNewVehicle()

    W.data.showVoteBtn = not BJI.Managers.Tournament.state and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)
    W.data.showStartBtn = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO)

    if not W.data.survivorsColor or not W.data.survivorsColor.vec4 then
        W.data.survivorsColor = BJI.Utils.ShapeDrawer.Color(.33, 1, .33)
    end
    if not W.data.infectedColor or not W.data.infectedColor.vec4 then
        W.data.infectedColor = BJI.Utils.ShapeDrawer.Color(1, 0, 0)
    end
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.CONFIG_PROTECTION_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
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
                data.cache == BJI.Managers.Cache.CACHES.HUNTER_INFECTED_DATA
            ) then
            if BJI.Managers.Perm.getCountPlayersCanSpawnVehicle() <
                BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.INFECTED).MINIMUM_PARTICIPANTS then
                mustClose, msg = true, BJI.Managers.Lang.get("hunter.settings.notEnoughPlayers")
            elseif not BJI.Managers.Context.Scenario.Data.HunterInfected.enabledInfected then
                mustClose, msg = true, BJI.Managers.Lang.get("menu.scenario.infected.modeDisabled")
            end
        else
            if not BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.FREEROAM) or
                (not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
                    not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)) then
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
---@return ClientVehicleConfig?
local function getConfig(ctxt)
    if not ctxt.veh then return end
    return BJI.Managers.Veh.getFullConfig(ctxt.veh.veh.partConfig)
end

---@param ctxt TickContext
local function drawBody(ctxt)
    if BeginTable("BJIInfectedSettings", {
            { label = "##infected-settings-labels" },
            { label = "##infected-settings-actions", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
        }) then
        TableNewRow()
        Text(W.labels.endAfterLastSurvivorInfected)
        TooltipText(W.labels.endAfterLastSurvivorInfectedTooltip)
        TableNextColumn()
        if IconButton("endAfterLastSurvivorInfectedToggle", W.data.endAfterLastSurvivorInfected and
                BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel, { bgLess = true,
                    btnStyle = W.data.endAfterLastSurvivorInfected and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                        BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            W.data.endAfterLastSurvivorInfected = not W.data.endAfterLastSurvivorInfected
        end
        TooltipText(W.labels.endAfterLastSurvivorInfectedTooltip)

        TableNewRow()
        Text(W.labels.config)
        TableNextColumn()
        if W.data.config then
            if IconButton("showConfig", BJI.Utils.Icon.ICONS.visibility,
                    { btnStyle = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = not ctxt.isOwner and
                        not W.data.canSpawnNewVeh }) then
                BJI.Managers.Veh.replaceOrSpawnVehicle(W.data.config.model,
                    W.data.config.key or W.data.config)
            end
            TooltipText(ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn)
            SameLine()
            if IconButton("refreshConfig", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = not ctxt.veh }) then
                if BJI.Managers.Veh.isModelBlacklisted(ctxt.veh.jbeam) then
                    BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.toastModelBlacklisted"))
                else
                    W.data.config = getConfig(ctxt)
                end
            end
            TooltipText(W.labels.buttons.set)
            SameLine()
            if IconButton("removeConfig", BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                W.data.config = nil
            end
            TooltipText(W.labels.buttons.remove)
            if W.data.config then -- on remove safe
                SameLine()
                Text(W.data.config.label)
            end
        else
            if IconButton("addConfig", BJI.Utils.Icon.ICONS.add,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = not ctxt.veh or W.data.currentVehProtected or W.data.selfProtected }) then
                if BJI.Managers.Veh.isModelBlacklisted(ctxt.veh.jbeam) then
                    BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.toastModelBlacklisted"))
                else
                    W.data.config = getConfig(ctxt)
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
        Text(W.labels.enableColors)
        TableNextColumn()
        if IconButton("enableColorsToggle", W.data.enableColors and
                BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel, { bgLess = true,
                    btnStyle = W.data.enableColors and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                        BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            W.data.enableColors = not W.data.enableColors
        end

        if W.data.enableColors then
            TableNewRow()
            Indent()
            Text(W.labels.survivorsColor)
            Unindent()
            TableNextColumn()
            if IconButton("survivorsColorReset", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                W.data.survivorsColor = BJI.Utils.ShapeDrawer.Color(.33, 1, .33)
            end
            SameLine()
            nextValue = ColorPicker("survivorsColor", W.data.survivorsColor:vec4())
            if nextValue then W.data.survivorsColor = BJI.Utils.ShapeDrawer.Color():fromVec4(nextValue) end

            TableNewRow()
            Indent()
            Text(W.labels.infectedColor)
            Unindent()
            TableNextColumn()
            if IconButton("infectedColorReset", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                W.data.infectedColor = BJI.Utils.ShapeDrawer.Color(1, 0, 0)
            end
            SameLine()
            nextValue = ColorPicker("infectedColor", W.data.infectedColor:vec4())
            if nextValue then W.data.infectedColor = BJI.Utils.ShapeDrawer.Color():fromVec4(nextValue) end
        end

        EndTable()
    end
    EmptyLine()
end

---@param isVote boolean
local function start(isVote)
    BJI.Tx.vote.ScenarioStart(BJI.Managers.Votes.SCENARIO_TYPES.INFECTED, isVote, {
        endAfterLastSurvivorInfected = W.data.endAfterLastSurvivorInfected,
        config = W.data.config,
        enableColors = W.data.enableColors,
        survivorsColor = W.data.enableColors and W.data.survivorsColor or nil,
        infectedColor = W.data.enableColors and W.data.infectedColor or nil,
    })
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    if IconButton("closeInfectedSettings", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.data.showVoteBtn then
        SameLine()
        if IconButton("startVoteInfected", BJI.Utils.Icon.ICONS.event_available,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            start(true)
            onClose()
        end
        TooltipText(W.labels.buttons.startVote)
    end
    if W.data.showStartBtn then
        SameLine()
        if IconButton("startInfected", BJI.Utils.Icon.ICONS.videogame_asset,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            start(false)
            onClose()
        end
        TooltipText(W.labels.buttons.start)
    end
end

local function open()
    W.show = true
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = drawBody
W.footer = drawFooter
W.onClose = onClose
W.open = open
W.getState = function() return W.show end

return W
