local cache = {
    name = "MainHeader",

    data = {
        nametagsVisible = false,

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
        reputation = "",
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
-- gc prevention
local style, value, nextValue, min, max, temperature, temperatureUnit, showReset,
showTeleport, resetDelay, teleportDelay, level, levelRep, rep, nextLevel, repTooltip

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
        cache.data.time = BJI.Utils.UI.PrettyTime(BJI.Managers.Env.getTime().time)
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

local function updateLabels()
    cache.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")
    updateGravitySpeedLabel()
    cache.labels.resetCooldownLabel = BJI.Managers.Lang.get("header.nextReset") .. " :"
    cache.labels.resetCooldownAvailable = BJI.Managers.Lang.get("header.resetAvailable")
    cache.labels.teleportCooldownLabel = BJI.Managers.Lang.get("header.nextTeleport") .. " :"
    cache.labels.teleportCooldownAvailable = BJI.Managers.Lang.get("header.teleportAvailable")
    cache.labels.collisions.title = BJI.Managers.Lang.get("header.collisions") .. " :"
    cache.labels.collisions.enabled = BJI.Managers.Lang.get("common.enabled")
    cache.labels.collisions.disabled = BJI.Managers.Lang.get("common.disabled")
    cache.labels.reputation = BJI.Managers.Lang.get("header.reputation") .. " :"

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
    updateLabels()
end

local listeners = Table()
local function onLoad()
    updateCache()

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, cache.name))
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
    -- LANG // UI Scale
    if BeginTable("MainHeaderRow1", {
            { label = "##main-header-row-1-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##main-header-row-1-right" }
        }) then
        TableNewRow()
        if BJI.Managers.Cache.areBaseCachesFirstLoaded() and #BJI.Managers.Lang.Langs > 1 then
            BJI.Managers.Lang.drawSelector({
                selected = ctxt.user.lang,
                onChange = function(newLang)
                    BJI.Tx.player.lang(newLang)
                end
            })
        end
        TableNextColumn()
        min, max = 0.85, 2
        value = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
        if IconButton("uiScaleZoomOut", BJI.Utils.Icon.ICONS.zoom_out, { disabled = value == min }) then
            nextValue = math.clamp(value - 0.05, min, max)
            if nextValue ~= value then
                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE, nextValue)
                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, { scale = nextValue })
            end
        end
        TooltipText(cache.labels.buttons.zoomOut)
        SameLine()
        if IconButton("uiScaleZoomIn", BJI.Utils.Icon.ICONS.zoom_in, { disabled = value == max }) then
            nextValue = math.clamp(value + 0.05, min, max)
            if nextValue ~= value then
                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE, nextValue)
                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, { scale = nextValue })
            end
        end
        TooltipText(cache.labels.buttons.zoomIn)

        EndTable()
    end

    -- Settings / VehSelector / Nametags // Debug / Server visibility
    if BeginTable("MainHeaderRow2", {
            { label = "##main-header-row-2-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##main-header-row-2-right" }
        }) then
        TableNewRow()
        style = table.clone(BJI.Utils.Style.BTN_PRESETS.INFO)
        if BJI.Windows.UserSettings.show then
            style[4] = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
        end
        if IconButton("toggleUserSettings", BJI.Utils.Icon.ICONS.settings, { btnStyle = style }) then
            BJI.Windows.UserSettings.show = not BJI.Windows.UserSettings.show
        end
        TooltipText(cache.labels.buttons.userSettings)
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.VEHICLE_SELECTOR) then
            SameLine()
            style = table.clone(BJI.Utils.Style.BTN_PRESETS.INFO)
            if BJI.Windows.VehSelector.show then
                style[4] = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
            end
            if IconButton("toggleVehicleSelector", BJI.Utils.Icon.ICONS.directions_car, { btnStyle = style }) then
                if BJI.Windows.VehSelector.show then
                    BJI.Windows.VehSelector.tryClose()
                else
                    BJI.Windows.VehSelector.open(true)
                end
            end
            TooltipText(cache.labels.buttons.vehicleSelector)
        end
        SameLine()
        if IconButton("toggleNametags", cache.data.nametagsVisible and BJI.Utils.Icon.ICONS.speaker_notes or
                BJI.Utils.Icon.ICONS.speaker_notes_off, { btnStyle = cache.data.nametagsVisible and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
            settings.setValue("hideNameTags", cache.data.nametagsVisible)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
        end
        TooltipText(cache.labels.buttons.toggleNametags)
        if BJI.Managers.GPS.isClearable() then
            SameLine()
            if IconButton("clearGPS", BJI.Utils.Icon.ICONS.location_off,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true, noSound = true }) then
                BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.BIGMAP_HOVER)
                BJI.Managers.GPS.clear()
            end
            TooltipText(cache.labels.buttons.clearGPS)
        end
        TableNextColumn()
        if IconButton("debugAction", BJI.Utils.Icon.ICONS.bug_report,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, bgLess = true }) then
            guihooks.trigger("app:waiting", false)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST)
        end
        TooltipText(cache.labels.buttons.debug)
        if cache.data.showCorePublic then
            SameLine()
            if IconButton("toggleCorePrivate", BJI.Managers.Context.Core.Private and
                    BJI.Utils.Icon.ICONS.visibility_off or BJI.Utils.Icon.ICONS.visibility,
                    { btnStyle = BJI.Managers.Context.Core.Private and
                        BJI.Utils.Style.BTN_PRESETS.ERROR or BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                BJI.Tx.config.core("Private", not BJI.Managers.Context.Core.Private)
            end
            TooltipText(cache.labels.buttons.serverVisibility)
        end

        EndTable()
    end

    -- MAP / TIME / TEMPERATURE // COLLISIONS INDICATOR
    if BeginTable("MainHeaderRow3", {
            { label = "##main-header-row-3-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##main-header-row-3-right" }
        }) then
        TableNewRow()
        Text(BJI.Managers.Context.UI.mapLabel, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
        if cache.data.showTime then
            SameLine()
            Text(cache.labels.vSeparator)
            SameLine()
            Text(cache.data.time or BJI.Utils.UI.PrettyTime(BJI.Managers.Env.getTime().time))
        end
        if cache.data.showTemp then
            if cache.data.temp then
                SameLine()
                Text(cache.labels.vSeparator)
                SameLine()
                Text(cache.data.temp)
            else
                temperature = BJI.Managers.Env.getTemperature()
                temperatureUnit = settings.getValue("uiUnitTemperature")
                if temperatureUnit == "k" then
                    SameLine()
                    Text(cache.labels.vSeparator)
                    SameLine()
                    Text(string.var("{1}K", { math.round(temperature, 2) }))
                elseif temperatureUnit == "c" then
                    SameLine()
                    Text(cache.labels.vSeparator)
                    SameLine()
                    Text(string.var("{1}°C", { math.round(math.kelvinToCelsius(temperature) or 0, 2) }))
                elseif temperatureUnit == "f" then
                    SameLine()
                    Text(cache.labels.vSeparator)
                    SameLine()
                    Text(string.var("{1}°F", { math.round(math.kelvinToFahrenheit(temperature) or 0, 2) }))
                end
            end
        end
        TableNextColumn()
        Text(cache.labels.collisions.title)
        SameLine()
        Text(BJI.Managers.Collisions.getState(ctxt) and cache.labels.collisions.enabled or
            cache.labels.collisions.disabled, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })

        EndTable()
    end

    -- GRAVITY / SPEED
    if cache.data.gravity or cache.data.speed then
        -- GRAVITY
        if cache.data.gravity then
            Text(cache.data.gravity)
        end

        -- COMMON
        if cache.data.gravity and cache.data.speed then
            SameLine()
            Text(cache.labels.vSeparator)
            SameLine()
        end

        -- SPEED
        if cache.data.speed then
            Text(cache.data.speed)
        end
    end

    -- TELEPORT DELAY / RESET DELAY
    if not cache.data.vehResetBypass and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.BJC) and
        BJI.Managers.Scenario.isFreeroam() and
        ctxt.isOwner then
        showReset = BJI.Managers.Context.BJC.Freeroam.ResetDelay > 0
        showTeleport = BJI.Managers.Context.BJC.Freeroam.TeleportDelay > 0
        if showReset or showTeleport then
            if showReset then
                resetDelay = BJI.Managers.Async.getRemainingDelay(BJI.Managers.Async.KEYS.RESTRICTIONS_RESET_TIMER)
                if resetDelay then
                    Text(cache.labels.resetCooldownLabel)
                    SameLine()
                    Text(BJI.Utils.UI.PrettyDelay(math.round(resetDelay / 1000)),
                        { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
                else
                    Text(cache.labels.resetCooldownAvailable)
                end
            end

            if showReset and showTeleport then
                SameLine()
                Text(cache.labels.vSeparator)
                SameLine()
            end

            if showTeleport then
                teleportDelay = BJI.Managers.Async.getRemainingDelay(BJI.Managers.Async.KEYS
                    .RESTRICTIONS_TELEPORT_TIMER)
                if teleportDelay then
                    Text(cache.labels.teleportCooldownLabel)
                    SameLine()
                    Text(BJI.Utils.UI.PrettyDelay(math.round(teleportDelay / 1000)),
                        { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
                else
                    Text(cache.labels.teleportCooldownAvailable)
                end
            end
        end
    end

    -- REPUTATION
    if cache.data.showLevel then
        level = BJI.Managers.Reputation.getReputationLevel()
        levelRep = BJI.Managers.Reputation.getReputationLevelAmount(level)
        rep = BJI.Managers.Reputation.reputation
        nextLevel = BJI.Managers.Reputation.getReputationLevelAmount(level + 1)

        repTooltip = string.var("{1}/{2}", { rep, nextLevel })
        Text(cache.labels.reputation)
        TooltipText(repTooltip)
        SameLine()
        Text(level, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
        TooltipText(repTooltip)

        ProgressBar((rep - levelRep) / (nextLevel - levelRep))
        TooltipText(repTooltip)
    end

    Separator()
end

return {
    onLoad = onLoad,
    onUnload = onUnload,
    draw = draw,
}
