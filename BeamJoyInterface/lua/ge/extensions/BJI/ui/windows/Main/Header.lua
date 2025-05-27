local cache = {
    name = "MainHeader",

    data = {
        firstRowRightButtonsWidth = 0,
        nametagsVisible = false,

        secondRowRightButtonsWidth = 0,
        showTime = false,
        showTemp = false,
        time = nil,
        temp = nil,
        showCorePublic = false,

        gravity = nil,
        speed = nil,

        showLevel = false,
        level = 1,

        vehResetBypass = false,
    },
    labels = {
        vSeparator = "",
        resetCooldownLabel = "",
        resetCooldownAvailable = "",
        teleportCooldownLabel = "",
        teleportCooldownAvailable = "",
        collisions = {
            title = "",
            enabled = "",
            disabled = "",
        },
        buttons = {
            userSettings = "",
            vehicleSelector = "",
            toggleNametags = "",
            clearGPS = "",
            zoomOut = "",
            zoomIn = "",
            debug = "",
            serverVisibility = "",
        },
    }
}

local function updateGravitySpeedLabel()
    if BJI.Managers.Context.UI.gravity and not BJI.Managers.Context.UI.gravity.default then
        cache.data.gravity = string.var("{1}: {2}", {
            BJI.Managers.Lang.get("header.gravity"),
            BJI.Managers.Context.UI.gravity.key and
            string.var("{1} ({2})", {
                BJI.Managers.Lang.get(string.var("presets.gravity.{1}", { BJI.Managers.Context.UI.gravity.key })),
                BJI.Managers.Context.UI.gravity.value,
            }) or
            string.var("{1}", { BJI.Managers.Context.UI.gravity.value }),
        })
    else
        cache.data.gravity = nil
    end
    if BJI.Managers.Context.UI.speed and not BJI.Managers.Context.UI.speed.default then
        cache.data.speed = string.var("{1}: {2}", {
            BJI.Managers.Lang.get("header.speed"),
            BJI.Managers.Context.UI.speed.key and
            string.var("{1} (x{2})", {
                BJI.Managers.Lang.get(string.var("presets.speed.{1}", { BJI.Managers.Context.UI.speed.key })),
                BJI.Managers.Context.UI.speed.value,
            }) or
            string.var("x{1}", { BJI.Managers.Context.UI.speed.value }),
        })
    else
        cache.data.speed = nil
    end
end

---@param ctxt TickContext
local function updateCacheData(ctxt)
    cache.data.nametagsVisible = not settings.getValue("hideNameTags", false)

    cache.data.showTime = BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.ENVIRONMENT) and
        not not BJI.Managers.Env.getTime()
    cache.data.showTemp = BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.ENVIRONMENT) and
        not not BJI.Managers.Env.getTemperature()
    if BJI.Managers.Env.Data.timePlay then
        -- moving time, not cached
        cache.data.time = nil
        cache.data.temp = nil
    elseif cache.data.showTimeAndTemp then
        -- static time, cached
        cache.data.time = BJI.Utils.Common.PrettyTime(BJI.Managers.Env.getTime().time)
        local temp = BJI.Managers.Env.getTemperature()
        local tempUnit = settings.getValue("uiUnitTemperature")
        if tempUnit == "k" then
            cache.data.temp = string.var("{1}K", { math.round(math.round(temp, 2)) })
        elseif tempUnit == "c" then
            cache.data.temp = string.var("{1}°C", { math.round(math.round(math.kelvinToCelsius(temp) or 0, 2)) })
        elseif tempUnit == "f" then
            cache.data.temp = string.var("{1}°F", { math.round(math.round(math.kelvinToFahrenheit(temp) or 0, 2)) })
        end
    end
    cache.data.showCorePublic = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CORE) and
        BJI.Managers.Context.Core

    updateGravitySpeedLabel()

    cache.data.showLevel = BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.USER)

    cache.data.vehResetBypass = BJI.Managers.Perm.isStaff()
end

local function updateWidths()
    cache.data.firstRowRightButtonsWidth = math.round(GetBtnIconSize() * 2)
    cache.data.secondRowRightButtonsWidth = math.round(GetBtnIconSize() *
        (BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CORE) and 2 or 1))
end

local function updateLabels()
    cache.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")
    updateGravitySpeedLabel()
    cache.labels.resetCooldownLabel = string.var("{1}:", { BJI.Managers.Lang.get("header.nextReset") })
    cache.labels.resetCooldownAvailable = BJI.Managers.Lang.get("header.resetAvailable")
    cache.labels.teleportCooldownLabel = string.var("{1}:", { BJI.Managers.Lang.get("header.nextTeleport") })
    cache.labels.teleportCooldownAvailable = BJI.Managers.Lang.get("header.teleportAvailable")
    cache.labels.collisions.title = string.var("{1}:", { BJI.Managers.Lang.get("header.collisions") })
    cache.labels.collisions.enabled = BJI.Managers.Lang.get("common.enabled")
    cache.labels.collisions.disabled = BJI.Managers.Lang.get("common.disabled")

    cache.labels.buttons.userSettings = BJI.Managers.Lang.get("menu.me.settings")
    cache.labels.buttons.vehicleSelector = BJI.Managers.Lang.get("menu.me.vehicleSelector")
    cache.labels.buttons.toggleNametags = BJI.Managers.Lang.get("header.buttons.toggleNametagsVisibility")
    cache.labels.buttons.clearGPS = BJI.Managers.Lang.get("menu.me.clearGPS")
    cache.labels.buttons.zoomOut = BJI.Managers.Lang.get("header.buttons.zoomOut")
    cache.labels.buttons.zoomIn = BJI.Managers.Lang.get("header.buttons.zoomIn")
    cache.labels.buttons.debug = BJI.Managers.Lang.get("header.buttons.debug")
    cache.labels.buttons.serverVisibility = BJI.Managers.Lang.get("header.buttons.serverVisibility")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    updateCacheData(ctxt)
    updateWidths()
    updateLabels()
end

local listeners = Table()
local function onLoad()
    updateCache()

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, cache.name))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, updateWidths,
        cache.name))
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI.Managers.Events.EVENTS.NAMETAGS_VISIBILITY_CHANGED,
        BJI.Managers.Events.EVENTS.ENV_CHANGED,
        BJI.Managers.Events.EVENTS.CORE_CHANGED,
        BJI.Managers.Events.EVENTS.LEVEL_UP,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, updateCacheData, cache.name))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST, updateCache,
        cache.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function draw(ctxt)
    -- LANG / Settings / UIScale
    if BJI.Managers.Cache.areBaseCachesFirstLoaded() and #BJI.Managers.Lang.Langs > 1 then
        ColumnsBuilder("headerLangUIScale", { -1, cache.data.firstRowRightButtonsWidth }):addRow({
            cells = {
                function()
                    local line = LineBuilder():btnIcon({
                        id = "toggleUserSettings",
                        icon = ICONS.settings,
                        style = BJI.Utils.Style.BTN_PRESETS.INFO,
                        active = BJI.Windows.UserSettings.show,
                        tooltip = cache.labels.buttons.userSettings,
                        onClick = function()
                            BJI.Windows.UserSettings.show = not BJI.Windows.UserSettings.show
                        end
                    })
                    if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.VEHICLE_SELECTOR) then
                        line:btnIcon({
                            id = "toggleVehicleSelector",
                            icon = ICONS.directions_car,
                            style = BJI.Utils.Style.BTN_PRESETS.INFO,
                            active = BJI.Windows.VehSelector.show,
                            tooltip = cache.labels.buttons.vehicleSelector,
                            onClick = function()
                                if BJI.Windows.VehSelector.show then
                                    BJI.Windows.VehSelector.tryClose()
                                else
                                    BJI.Windows.VehSelector.open(true)
                                end
                            end
                        })
                    end
                    line:btnIconToggle({
                        id = "togleNametags",
                        icon = cache.data.nametagsVisible and ICONS.speaker_notes or ICONS.speaker_notes_off,
                        state = cache.data.nametagsVisible,
                        coloredIcon = true,
                        tooltip = cache.labels.buttons.toggleNametags,
                        onClick = function()
                            settings.setValue("hideNameTags", cache.data.nametagsVisible)
                            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
                        end,
                    })
                    if BJI.Managers.GPS.isClearable() then
                        line:btnIcon({
                            id = "clearGPS",
                            icon = ICONS.location_off,
                            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                            coloredIcon = true,
                            tooltip = cache.labels.buttons.clearGPS,
                            onClick = BJI.Managers.GPS.clear,
                            sound = BTN_NO_SOUND,
                        })
                    end
                    line:build()
                    BJI.Managers.Lang.drawSelector({
                        selected = ctxt.user.lang,
                        onChange = function(newLang)
                            BJI.Tx.player.lang(newLang)
                        end
                    })
                end,
                function()
                    local minScale = 0.85
                    local maxScale = 2
                    local value = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
                    LineBuilder():btnIcon({
                        id = "uiScaleZoomOut",
                        icon = ICONS.zoom_out,
                        tooltip = cache.labels.buttons.zoomOut,
                        onClick = function()
                            local scale = math.clamp(value - 0.05, minScale, maxScale)
                            if scale ~= value then
                                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE,
                                    scale)
                                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, {
                                    scale = scale
                                })
                            end
                        end
                    }):btnIcon({
                        id = "uiScaleZoomIn",
                        icon = ICONS.zoom_in,
                        tooltip = cache.labels.buttons.zoomIn,
                        onClick = function()
                            local scale = math.clamp(value + 0.05, minScale, maxScale)
                            if scale ~= value then
                                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE,
                                    scale)
                                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, {
                                    scale = scale
                                })
                            end
                        end
                    }):build()
                end
            }
        }):build()
    end

    -- MAP / TIME / TEMPERATURE
    if BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.MAP) then
        ColumnsBuilder("headerMapTimeTempPrivate", { -1, cache.data.secondRowRightButtonsWidth }):addRow({
            cells = {
                function()
                    -- MAP
                    local line = LineBuilder()
                        :text(BJI.Managers.Context.UI.mapLabel, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)

                    -- TIME & TEMPERATURE
                    local labels = {}
                    if cache.data.showTime then
                        table.insert(labels,
                            cache.data.time or BJI.Utils.Common.PrettyTime(BJI.Managers.Env.getTime().time))
                    end

                    if cache.data.showTemp then
                        if cache.data.temp then
                            table.insert(labels, cache.data.temp)
                        else
                            local temp = BJI.Managers.Env.getTemperature()
                            local tempUnit = settings.getValue("uiUnitTemperature")
                            if tempUnit == "k" then
                                table.insert(labels, string.var("{1}K", { math.round(temp, 2) }))
                            elseif tempUnit == "c" then
                                table.insert(labels,
                                    string.var("{1}°C", { math.round(math.kelvinToCelsius(temp) or 0, 2) }))
                            elseif tempUnit == "f" then
                                table.insert(labels,
                                    string.var("{1}°F", { math.round(math.kelvinToFahrenheit(temp) or 0, 2) }))
                            end
                        end
                    end
                    if #labels > 0 then
                        line:text(string.var("{1}",
                            { table.join(labels, string.var(" {1} ", { cache.labels.vSeparator })) }))
                    end
                    line:build()
                end,
                function()
                    local line = LineBuilder():btnIcon({
                        id = "debugAppWaiting",
                        icon = ICONS.bug_report,
                        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        coloredIcon = true,
                        tooltip = cache.labels.buttons.debug,
                        onClick = function()
                            guihooks.trigger("app:waiting", false)
                            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST)
                        end,
                    })
                    if cache.data.showCorePublic then
                        local state = BJI.Managers.Context.Core.Private
                        line:btnIconToggle({
                            id = "toggleCorePrivate",
                            icon = state and ICONS.visibility_off or ICONS.visibility,
                            state = not state,
                            tooltip = cache.labels.buttons.serverVisibility,
                            onClick = function()
                                BJI.Tx.config.core("Private", not BJI.Managers.Context.Core.Private)
                            end,
                        })
                    end
                    line:build()
                end
            }
        }):build()
    end

    -- GRAVITY / SPEED
    if cache.data.gravity or cache.data.speed then
        local labels = Table()
        -- GRAVITY
        if cache.data.gravity then
            labels:insert(cache.data.gravity)
        end

        -- SPEED
        if cache.data.speed then
            labels:insert(cache.data.speed)
        end
        LineLabel(labels:join(string.var(" {1} ", { cache.labels.vSeparator })))
    end

    -- TELEPORT DELAY / RESET DELAY
    if not cache.data.vehResetBypass and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.BJC) and
        BJI.Managers.Scenario.isFreeroam() and
        ctxt.isOwner then
        local showReset = BJI.Managers.Context.BJC.Freeroam.ResetDelay > 0
        local showTeleport = BJI.Managers.Context.BJC.Freeroam.TeleportDelay > 0
        if showReset or showTeleport then
            local line = LineBuilder()

            if showReset then
                local resetDelay = BJI.Managers.Async.getRemainingDelay(BJI.Managers.Async.KEYS.RESTRICTIONS_RESET_TIMER)
                if resetDelay then
                    line:text(cache.labels.resetCooldownLabel)
                        :text(BJI.Utils.Common.PrettyDelay(math.round(resetDelay / 1000)),
                            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
                else
                    line:text(cache.labels.resetCooldownAvailable)
                end
            end

            if showTeleport then
                if showReset then
                    line:text(cache.labels.vSeparator)
                end
                local teleportDelay = BJI.Managers.Async.getRemainingDelay(BJI.Managers.Async.KEYS
                    .RESTRICTIONS_TELEPORT_TIMER)
                if teleportDelay then
                    line:text(cache.labels.teleportCooldownLabel)
                        :text(BJI.Utils.Common.PrettyDelay(math.round(teleportDelay / 1000)),
                            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
                else
                    line:text(cache.labels.teleportCooldownAvailable)
                end
            end

            line:build()
        end
    end

    -- COLLISIONS INDICATOR
    LineBuilder():text(cache.labels.collisions.title):text(BJI.Managers.Collisions.state and
        cache.labels.collisions.enabled or cache.labels.collisions.disabled,
        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT):build()

    -- REPUTATION
    if cache.data.showLevel then
        local level = BJI.Managers.Reputation.getReputationLevel()
        local levelReputation = BJI.Managers.Reputation.getReputationLevelAmount(level)
        local reputation = BJI.Managers.Reputation.reputation
        local nextLevel = BJI.Managers.Reputation.getReputationLevelAmount(level + 1)

        local repTooltip = string.var("{1}/{2}", { reputation, nextLevel })
        LineBuilder()
            :text(string.var("{1}:", { BJI.Managers.Lang.get("header.reputation") }), nil, repTooltip)
            :text(level, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT, repTooltip)
            :build()

        ProgressBar({
            floatPercent = (reputation - levelReputation) / (nextLevel - levelReputation),
            width = "100%",
            tooltip = repTooltip,
        })
    end

    Separator()
end

return {
    onLoad = onLoad,
    onUnload = onUnload,
    draw = draw,
}
