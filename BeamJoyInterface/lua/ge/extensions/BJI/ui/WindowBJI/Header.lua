local cache = {
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
    }
}

local function updateGravitySpeedLabel()
    if BJIContext.UI.gravity and not BJIContext.UI.gravity.default then
        cache.data.gravity = string.var("{1}: {2}", {
            BJILang.get("header.gravity"),
            BJIContext.UI.gravity.key and
            string.var("{1} ({2})", {
                BJILang.get(string.var("presets.gravity.{1}", { BJIContext.UI.gravity.key })),
                BJIContext.UI.gravity.value,
            }) or
            string.var("{1}", { BJIContext.UI.gravity.value }),
        })
    else
        cache.data.gravity = nil
    end
    if BJIContext.UI.speed and not BJIContext.UI.speed.default then
        cache.data.speed = string.var("{1}: {2}", {
            BJILang.get("header.speed"),
            BJIContext.UI.speed.key and
            string.var("{1} (x{2})", {
                BJILang.get(string.var("presets.speed.{1}", { BJIContext.UI.speed.key })),
                BJIContext.UI.speed.value,
            }) or
            string.var("x{1}", { BJIContext.UI.speed.value }),
        })
    else
        cache.data.speed = nil
    end
end

---@param ctxt TickContext
local function updateCacheData(ctxt)
    cache.data.nametagsVisible = not settings.getValue("hideNameTags", false)

    cache.data.showTime = BJICache.isFirstLoaded(BJICache.CACHES.ENVIRONMENT) and not not BJIEnv.getTime()
    cache.data.showTemp = BJICache.isFirstLoaded(BJICache.CACHES.ENVIRONMENT) and not not BJIEnv.getTemperature()
    if BJIEnv.Data.timePlay then
        -- moving time, not cached
        cache.data.time = nil
        cache.data.temp = nil
    elseif cache.data.showTimeAndTemp then
        -- static time, cached
        cache.data.time = PrettyTime(BJIEnv.getTime().time)
        local temp = BJIEnv.getTemperature()
        local tempUnit = settings.getValue("uiUnitTemperature")
        if tempUnit == "k" then
            cache.data.temp = string.var("{1}K", { math.round(math.round(temp, 2)) })
        elseif tempUnit == "c" then
            cache.data.temp = string.var("{1}°C", { math.round(math.round(math.kelvinToCelsius(temp) or 0, 2)) })
        elseif tempUnit == "f" then
            cache.data.temp = string.var("{1}°F", { math.round(math.round(math.kelvinToFahrenheit(temp) or 0, 2)) })
        end
    end
    cache.data.showCorePublic = BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) and BJIContext.Core

    updateGravitySpeedLabel()

    cache.data.showLevel = BJICache.isFirstLoaded(BJICache.CACHES.USER)

    cache.data.vehResetBypass = BJIPerm.isStaff()
end

local function updateWidths()
    cache.data.firstRowRightButtonsWidth = math.round(GetBtnIconSize() * 2)
    cache.data.secondRowRightButtonsWidth = math.round(GetBtnIconSize() *
        (BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) and 2 or 1))
end

local function updateLabels()
    cache.labels.vSeparator = BJILang.get("common.vSeparator")
    updateGravitySpeedLabel()
    cache.labels.resetCooldownLabel = string.var("{1}:", { BJILang.get("header.nextReset") })
    cache.labels.resetCooldownAvailable = BJILang.get("header.resetAvailable")
    cache.labels.teleportCooldownLabel = string.var("{1}:", { BJILang.get("header.nextTeleport") })
    cache.labels.teleportCooldownAvailable = BJILang.get("header.teleportAvailable")
    cache.labels.collisions.title = string.var("{1}:", { BJILang.get("header.collisions") })
    cache.labels.collisions.enabled = BJILang.get("common.enabled")
    cache.labels.collisions.disabled = BJILang.get("common.disabled")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()

    updateCacheData(ctxt)
    updateWidths()
    updateLabels()
end

local listeners = {}
local function onLoad()
    updateCache()

    table.insert(listeners, BJIEvents.addListener(BJIEvents.EVENTS.LANG_CHANGED, updateLabels))
    table.insert(listeners, BJIEvents.addListener(BJIEvents.EVENTS.UI_SCALE_CHANGED, updateWidths))
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.CACHE_LOADED,
        BJIEvents.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJIEvents.EVENTS.NAMETAGS_VISIBILITY_CHANGED,
        BJIEvents.EVENTS.ENV_CHANGED,
        BJIEvents.EVENTS.CORE_CHANGED,
        BJIEvents.EVENTS.LEVEL_UP,
        BJIEvents.EVENTS.SCENARIO_CHANGED,
        BJIEvents.EVENTS.PERMISSION_CHANGED,
    }, updateCacheData))
    table.insert(listeners, BJIEvents.addListener(BJIEvents.EVENTS.UI_UPDATE_REQUEST, updateCache))
end

local function onUnload()
    table.forEach(listeners, BJIEvents.removeListener)
end

local function draw(ctxt)
    -- LANG / Settings / UIScale
    if BJICache.areBaseCachesFirstLoaded() and #BJILang.Langs > 1 then
        ColumnsBuilder("headerLangUIScale", { -1, cache.data.firstRowRightButtonsWidth })
            :addRow({
                cells = {
                    function()
                        local line = LineBuilder()
                            :btnIcon({
                                id = "toggleUserSettings",
                                icon = ICONS.settings,
                                style = BTN_PRESETS.INFO,
                                active = BJIUserSettingsWindow.show,
                                onClick = function()
                                    BJIUserSettingsWindow.show = not BJIUserSettingsWindow.show
                                end
                            })
                        if BJIPerm.canSpawnVehicle() and
                            BJIScenario.canSelectVehicle() then
                            line:btnIcon({
                                id = "toggleVehicleSelector",
                                icon = ICONS.directions_car,
                                style = BTN_PRESETS.INFO,
                                active = BJIVehSelector.state,
                                onClick = function()
                                    if BJIVehSelector.state then
                                        BJIVehSelector.tryClose()
                                    else
                                        local models = BJIScenario.getModelList()
                                        if table.length(models) > 0 then
                                            BJIVehSelector.open(models, true)
                                        end
                                    end
                                end
                            })
                        end
                        line:btnIconToggle({
                            id = "togleNametags",
                            icon = cache.data.nametagsVisible and ICONS.speaker_notes or ICONS.speaker_notes_off,
                            state = cache.data.nametagsVisible,
                            coloredIcon = true,
                            onClick = function()
                                settings.setValue("hideNameTags", cache.data.nametagsVisible)
                                BJINametags.tryUpdate()
                            end,
                        })
                        if BJIGPS.isClearable() then
                            line:btnIcon({
                                id = "clearGPS",
                                icon = ICONS.location_off,
                                style = BTN_PRESETS.ERROR,
                                coloredIcon = true,
                                onClick = BJIGPS.clear,
                                sound = BTN_NO_SOUND,
                            })
                        end
                        line:build()
                        BJILang.drawSelector({
                            selected = ctxt.user.lang,
                            onChange = function(newLang)
                                BJITx.player.lang(newLang)
                            end
                        })
                    end,
                    function()
                        local minScale = 0.85
                        local maxScale = 2
                        local value = BJILocalStorage.get(BJILocalStorage.GLOBAL_VALUES.UI_SCALE)
                        LineBuilder()
                            :btnIcon({
                                id = "uiScaleZoomOut",
                                icon = ICONS.zoom_out,
                                onClick = function()
                                    local scale = math.clamp(value - 0.05, minScale, maxScale)
                                    if scale ~= value then
                                        BJILocalStorage.set(BJILocalStorage.GLOBAL_VALUES.UI_SCALE, scale)
                                        BJIEvents.trigger(BJIEvents.EVENTS.UI_SCALE_CHANGED, {
                                            scale = scale
                                        })
                                    end
                                end
                            })
                            :btnIcon({
                                id = "uiScaleZoomIn",
                                icon = ICONS.zoom_in,
                                onClick = function()
                                    local scale = math.clamp(value + 0.05, minScale, maxScale)
                                    if scale ~= value then
                                        BJILocalStorage.set(BJILocalStorage.GLOBAL_VALUES.UI_SCALE, scale)
                                        BJIEvents.trigger(BJIEvents.EVENTS.UI_SCALE_CHANGED, {
                                            scale = scale
                                        })
                                    end
                                end
                            })
                            :build()
                    end
                }
            })
            :build()
    end

    -- MAP / TIME / TEMPERATURE
    if BJICache.isFirstLoaded(BJICache.CACHES.MAP) then
        ColumnsBuilder("headerMapTimeTempPrivate", { -1, cache.data.secondRowRightButtonsWidth })
            :addRow({
                cells = {
                    function()
                        -- MAP
                        local line = LineBuilder()
                            :text(BJIContext.UI.mapLabel, TEXT_COLORS.HIGHLIGHT)

                        -- TIME & TEMPERATURE
                        local labels = {}
                        if cache.data.showTime then
                            table.insert(labels, cache.data.time or PrettyTime(BJIEnv.getTime().time))
                        end

                        if cache.data.showTemp then
                            if cache.data.temp then
                                table.insert(labels, cache.data.temp)
                            else
                                local temp = BJIEnv.getTemperature()
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
                        local line = LineBuilder()
                            :btnIcon({
                                id = "debugAppWaiting",
                                icon = ICONS.bug_report,
                                style = BTN_PRESETS.SUCCESS,
                                coloredIcon = true,
                                onClick = function()
                                    guihooks.trigger("app:waiting", false)
                                    BJIEvents.trigger(BJIEvents.EVENTS.UI_UPDATE_REQUEST)
                                end,
                            })
                        if cache.data.showCorePublic then
                            local state = BJIContext.Core.Private
                            line:btnIconToggle({
                                id = "toggleCorePrivate",
                                icon = state and ICONS.visibility_off or ICONS.visibility,
                                state = not state,
                                onClick = function()
                                    BJITx.config.core("Private", not BJIContext.Core.Private)
                                end,
                            })
                        end
                        line:build()
                    end
                }
            })
            :build()
    end

    -- GRAVITY / SPEED
    if cache.data.gravity or cache.data.speed then
        local labels = {}
        -- GRAVITY
        if cache.data.gravity then
            table.insert(labels, cache.data.gravity)
        end

        -- SPEED
        if cache.data.speed then
            table.insert(labels, cache.data.speed)
        end
        LineBuilder()
            :text(table.join(labels, string.var(" {1} ", { cache.labels.vSeparator })))
            :build()
    end

    -- TELEPORT DELAY / RESET DELAY
    if not cache.data.vehResetBypass and
        BJICache.isFirstLoaded(BJICache.CACHES.BJC) and
        BJIScenario.isFreeroam() and
        ctxt.isOwner then
        local showReset = BJIContext.BJC.Freeroam.ResetDelay > 0
        local showTeleport = BJIContext.BJC.Freeroam.TeleportDelay > 0
        if showReset or showTeleport then
            local line = LineBuilder()

            if showReset then
                local resetDelay = BJIAsync.getRemainingDelay(BJIAsync.KEYS.RESTRICTIONS_RESET_TIMER)
                if resetDelay then
                    line:text(cache.labels.resetCooldownLabel)
                        :text(PrettyDelay(math.round(resetDelay / 1000)), TEXT_COLORS.HIGHLIGHT)
                else
                    line:text(cache.labels.resetCooldownAvailable)
                end
            end

            if showTeleport then
                if showReset then
                    line:text(cache.labels.vSeparator)
                end
                local teleportDelay = BJIAsync.getRemainingDelay(BJIAsync.KEYS.RESTRICTIONS_TELEPORT_TIMER)
                if teleportDelay then
                    line:text(cache.labels.teleportCooldownLabel)
                        :text(PrettyDelay(math.round(teleportDelay / 1000)), TEXT_COLORS.HIGHLIGHT)
                else
                    line:text(cache.labels.teleportCooldownAvailable)
                end
            end

            line:build()
        end
    end

    -- COLLISIONS INDICATOR
    LineBuilder()
        :text(cache.labels.collisions.title)
        :text(BJICollisions.state and cache.labels.collisions.enabled or cache.labels.collisions.disabled,
            TEXT_COLORS.HIGHLIGHT)
        :build()

    -- REPUTATION
    if cache.data.showLevel then
        local level = BJIReputation.getReputationLevel()
        local levelReputation = BJIReputation.getReputationLevelAmount(level)
        local reputation = BJIReputation.reputation
        local nextLevel = BJIReputation.getReputationLevelAmount(level + 1)

        LineBuilder()
            :text(string.var("{1}:", { BJILang.get("header.reputation") }))
            :text(level, TEXT_COLORS.HIGHLIGHT)
            :helpMarker(string.var("{1}/{2}", { reputation, nextLevel }))
            :build()

        ProgressBar({
            floatPercent = (reputation - levelReputation) / (nextLevel - levelReputation),
            width = 250,
        })
    end

    Separator()
end

return {
    onLoad = onLoad,
    onUnload = onUnload,
    draw = draw,
}
