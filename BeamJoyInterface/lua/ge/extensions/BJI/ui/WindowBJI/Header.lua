local function draw(ctxt)
    local vSeparator = BJILang.get("common.vSeparator")

    -- LANG / Settings / UIScale
    if BJICache.areBaseCachesFirstLoaded() and #BJILang.Langs > 1 then
        local buttonsWidth = GetBtnIconSize() * 2
        ColumnsBuilder("headerLangUIScale", { -1, Round(buttonsWidth) })
            :addRow({
                cells = {
                    function()
                        local line = LineBuilder()
                            :btnIcon({
                                id = "toggleUserSettings",
                                icon = ICONS.settings,
                                style = BTN_PRESETS.INFO,
                                active = BJIContext.UserSettings.open,
                                onClick = function()
                                    BJIContext.UserSettings.open = not BJIContext.UserSettings.open
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
                                        if tlength(models) > 0 then
                                            BJIVehSelector.open(models, true)
                                        end
                                    end
                                end
                            })
                        end
                        line:btnIconToggle({
                            id = "togleNametags",
                            icon = settings.getValue("hideNameTags", false) and ICONS.speaker_notes_off or ICONS.speaker_notes,
                            state = not settings.getValue("hideNameTags", false),
                            coloredIcon = true,
                            onClick = function()
                                settings.setValue("hideNameTags", not settings.getValue("hideNameTags", false))
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
                        LineBuilder()
                            :btnIcon({
                                id = "uiScaleZoomOut",
                                icon = ICONS.zoom_out,
                                onClick = function()
                                    local scale = Clamp(BJIContext.UserSettings.UIScale - 0.05, minScale, maxScale)
                                    if scale ~= BJIContext.UserSettings.UIScale then
                                        BJIContext.UserSettings.UIScale = scale
                                        BJITx.player.settings("UIScale", BJIContext.UserSettings.UIScale)
                                    end
                                end
                            })
                            :btnIcon({
                                id = "uiScaleZoomIn",
                                icon = ICONS.zoom_in,
                                onClick = function()
                                    local scale = Clamp(BJIContext.UserSettings.UIScale + 0.05, minScale, maxScale)
                                    if scale ~= BJIContext.UserSettings.UIScale then
                                        BJIContext.UserSettings.UIScale = scale
                                        BJITx.player.settings("UIScale", BJIContext.UserSettings.UIScale)
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
    local showMap = BJICache.isFirstLoaded(BJICache.CACHES.MAP)
    if showMap then
        local btnWidth = GetBtnIconSize()
        if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
            btnWidth = GetBtnIconSize() * 2
        end
        ColumnsBuilder("headerMapTimeTempPrivate", { -1, btnWidth })
            :addRow({
                cells = {
                    function()
                        -- MAP
                        local line = LineBuilder()
                            :text(BJIContext.UI.mapLabel, TEXT_COLORS.HIGHLIGHT)

                        -- TIME & TEMPERATURE
                        local time = BJICache.isFirstLoaded(BJICache.CACHES.ENVIRONMENT) and BJIEnv.getTime() and
                            BJIEnv.getTime().time
                        local timeLabel = time and PrettyTime(time)

                        local temp = BJICache.isFirstLoaded(BJICache.CACHES.ENVIRONMENT) and BJIEnv.getTemperature()
                        local celsius = temp and KelvinToCelsius(temp)
                        local tempLabel = temp and svar("{1}°C / {2}°F", {
                            Round(celsius, 2),
                            Round(CelsiusToFarenheit(celsius), 2)
                        })

                        if timeLabel or tempLabel then
                            local str = "("
                            if timeLabel then
                                str = svar("{1}{2}", { str, timeLabel })
                            end
                            if tempLabel then
                                if timeLabel then
                                    str = svar("{1} {2} ", { str, vSeparator })
                                end
                                str = svar("{1}{2}", { str, tempLabel })
                            end
                            str = svar("{1})", { str })
                            line:text(str)
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
                                end,
                            })
                        if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) and BJIContext.Core then
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
    local showGravity = BJIContext.UI.gravity.key and not BJIContext.UI.gravity.default
    local showSpeed = BJIContext.UI.speed and not BJIContext.UI.speed.default
    if showGravity or showSpeed then
        local line = LineBuilder()
        -- GRAVITY
        if showGravity then
            line:text(svar("{1}:", { BJILang.get("header.gravity") }))
            if BJIContext.UI.gravity.key then
                line:text(BJILang.get(svar("presets.gravity.{1}", { BJIContext.UI.gravity.key })))
                    :text(svar("({1})", { BJIContext.UI.gravity.value }))
            else
                line:text(svar("{1}", { BJIContext.UI.gravity.value }))
            end
        end

        -- SPEED
        if showSpeed then
            if showGravity then
                line:text(vSeparator)
            end
            line:text(svar("{1}:", { BJILang.get("header.speed") }))
            if BJIContext.UI.speed.key then
                line:text(BJILang.get(svar("presets.speed.{1}", { BJIContext.UI.speed.key })))
                    :text(svar("(x{1})", { BJIContext.UI.speed.value }))
            else
                line:text(svar("x{1}", { BJIContext.UI.speed.value }))
            end
        end
        line:build()
    end

    -- REPUTATION
    if BJICache.isFirstLoaded(BJICache.CACHES.USER) then
        local level = BJIReputation.getReputationLevel()
        local levelReputation = BJIReputation.getReputationLevelAmount(level)
        local reputation = BJIReputation.reputation
        local nextLevel = BJIReputation.getReputationLevelAmount(level + 1)

        LineBuilder()
            :text(svar("{1}:", { BJILang.get("header.reputation") }))
            :text(level, TEXT_COLORS.HIGHLIGHT)
            :helpMarker(svar("{1}/{2}", { reputation, nextLevel }))
            :build()

        ProgressBar({
            floatPercent = (reputation - levelReputation) / (nextLevel - levelReputation),
            width = 250,
        })
    end

    -- TELEPORT DELAY / RESET DELAY
    if BJICache.isFirstLoaded(BJICache.CACHES.BJC) and
        BJIScenario.isFreeroam() and
        ctxt.isOwner then
        local showReset = BJIContext.BJC.Freeroam.ResetDelay > 0
        local showTeleport = BJIContext.BJC.Freeroam.TeleportDelay > 0
        if showReset or showTeleport then
            local line = LineBuilder()

            if showReset then
                local resetDelay = BJIAsync.getRemainingDelay(BJIAsync.KEYS.RESTRICTIONS_RESET_TIMER)
                if resetDelay then
                    line:text(svar("{1}:", { BJILang.get("header.nextReset") }))
                        :text(PrettyDelay(Round(resetDelay / 1000)), TEXT_COLORS.HIGHLIGHT)
                else
                    line:text(BJILang.get("header.resetAvailable"))
                end
            end

            if showTeleport then
                if showReset then
                    line:text(vSeparator)
                end
                local teleportDelay = BJIAsync.getRemainingDelay(BJIAsync.KEYS.RESTRICTIONS_TELEPORT_TIMER)
                if teleportDelay then
                    line:text(svar("{1}:", { BJILang.get("header.nextTeleport") }))
                        :text(PrettyDelay(Round(teleportDelay / 1000)), TEXT_COLORS.HIGHLIGHT)
                else
                    line:text(BJILang.get("header.teleportAvailable"))
                end
            end

            line:build()
        end
    end

    Separator()
end

return draw
