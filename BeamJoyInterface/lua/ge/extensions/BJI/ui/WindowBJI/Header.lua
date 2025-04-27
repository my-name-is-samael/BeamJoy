local function draw(ctxt)
    local vSeparator = BJILang.get("common.vSeparator")

    -- LANG / Settings / UIScale
    if BJICache.areBaseCachesFirstLoaded() and #BJILang.Langs > 1 then
        local buttonsWidth = GetBtnIconSize() * 2
        ColumnsBuilder("headerLangUIScale", { -1, math.round(buttonsWidth) })
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
                                        if table.length(models) > 0 then
                                            BJIVehSelector.open(models, true)
                                        end
                                    end
                                end
                            })
                        end
                        line:btnIconToggle({
                            id = "togleNametags",
                            icon = settings.getValue("hideNameTags", false) and ICONS.speaker_notes_off or
                                ICONS.speaker_notes,
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
                                    local scale = math.clamp(BJIContext.UserSettings.UIScale - 0.05, minScale, maxScale)
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
                                    local scale = math.clamp(BJIContext.UserSettings.UIScale + 0.05, minScale, maxScale)
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
                        local labels = {}
                        local time = BJICache.isFirstLoaded(BJICache.CACHES.ENVIRONMENT) and BJIEnv.getTime() and
                            BJIEnv.getTime().time
                        if time then
                            table.insert(labels, PrettyTime(time))
                        end

                        local temp = BJICache.isFirstLoaded(BJICache.CACHES.ENVIRONMENT) and BJIEnv.getTemperature()
                        if temp then
                            local tempUnit = settings.getValue("uiUnitTemperature")
                            if tempUnit == "k" then
                                table.insert(labels, string.var("{1}K", { math.round(temp, 2) }))
                            elseif tempUnit == "c" then
                                table.insert(labels, string.var("{1}°C", { math.round(math.kelvinToCelsius(temp) or 0, 2) }))
                            elseif tempUnit == "f" then
                                table.insert(labels, string.var("{1}°F", { math.round(math.kelvinToFahrenheit(temp) or 0, 2) }))
                            end
                        end
                        if #labels > 0 then
                            line:text(string.var("{1}", { table.join(labels, string.var(" {1} ", { vSeparator })) }))
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
            line:text(string.var("{1}:", { BJILang.get("header.gravity") }))
            if BJIContext.UI.gravity.key then
                line:text(BJILang.get(string.var("presets.gravity.{1}", { BJIContext.UI.gravity.key })))
                    :text(string.var("({1})", { BJIContext.UI.gravity.value }))
            else
                line:text(string.var("{1}", { BJIContext.UI.gravity.value }))
            end
        end

        -- SPEED
        if showSpeed then
            if showGravity then
                line:text(vSeparator)
            end
            line:text(string.var("{1}:", { BJILang.get("header.speed") }))
            if BJIContext.UI.speed.key then
                line:text(BJILang.get(string.var("presets.speed.{1}", { BJIContext.UI.speed.key })))
                    :text(string.var("(x{1})", { BJIContext.UI.speed.value }))
            else
                line:text(string.var("x{1}", { BJIContext.UI.speed.value }))
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
            :text(string.var("{1}:", { BJILang.get("header.reputation") }))
            :text(level, TEXT_COLORS.HIGHLIGHT)
            :helpMarker(string.var("{1}/{2}", { reputation, nextLevel }))
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
                    line:text(string.var("{1}:", { BJILang.get("header.nextReset") }))
                        :text(PrettyDelay(math.round(resetDelay / 1000)), TEXT_COLORS.HIGHLIGHT)
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
                    line:text(string.var("{1}:", { BJILang.get("header.nextTeleport") }))
                        :text(PrettyDelay(math.round(teleportDelay / 1000)), TEXT_COLORS.HIGHLIGHT)
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
