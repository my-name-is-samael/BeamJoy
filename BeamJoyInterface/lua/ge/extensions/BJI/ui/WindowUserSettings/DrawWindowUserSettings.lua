local function drawVehicleSettings(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.directions_car,
            big = true,
        })
        :build()
    Indent(2)

    local labelWidth = 0
    local labels = {
        BJILang.get("userSettings.vehicles.automaticLights") .. ":" .. HELPMARKER_TEXT,
        BJILang.get("userSettings.vehicles.driftFlashes") .. ":",
        BJILang.get("userSettings.vehicles.nametags") .. ":",
    }
    for _, key in ipairs(labels) do
        local w = GetColumnTextWidth(key)
        if w > labelWidth then
            labelWidth = w
        end
    end

    ColumnsBuilder("UserSettingsVehicle", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("userSettings.vehicles.automaticLights") }))
                        :helpMarker(BJILang.get("userSettings.vehicles.automaticLightsTooltip"))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIconSwitch({
                            id = "automaticLightsToggle",
                            iconEnabled = ICONS.brightness_high,
                            iconDisabled = ICONS.brightness_low,
                            state = BJIContext.UserSettings.automaticLights,
                            onClick = function()
                                BJIContext.UserSettings.automaticLights = not BJIContext.UserSettings.automaticLights
                                BJITx.player.settings("automaticLights", BJIContext.UserSettings.automaticLights)
                            end,
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("userSettings.vehicles.driftFlashes") }))
                        :build()
                end,
                function()
                    local line = LineBuilder()
                        :btnIconSwitch({
                            id = "driftFlashesToggle",
                            iconEnabled = ICONS.visibility,
                            iconDisabled = ICONS.visibility_off,
                            state = BJIContext.UserSettings.driftFlashes,
                            onClick = function()
                                BJIContext.UserSettings.driftFlashes = not BJIContext.UserSettings.driftFlashes
                                BJITx.player.settings("driftFlashes", BJIContext.UserSettings.driftFlashes)
                            end,
                        })
                        if BJIContext.UserSettings.driftFlashes then
                            line:helpMarker(BJILang.get("userSettings.vehicles.driftFlashesTooltip"))
                        end
                        line:build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("userSettings.vehicles.nametags") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIconSwitch({
                            id = "nametagsToggle",
                            iconEnabled = ICONS.speaker_notes,
                            iconDisabled = ICONS.speaker_notes_off,
                            state = BJIContext.UserSettings.nametags,
                            onClick = function()
                                BJIContext.UserSettings.nametags = not BJIContext.UserSettings.nametags
                                BJITx.player.settings("nametags", BJIContext.UserSettings.nametags)
                                BJINametags.tryUpdate()
                            end,
                        })
                        :build()
                end
            }
        })
        :build()
    Indent(-2)
end

local function drawFreecamSettings(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.simobject_camera,
            big = true,
        })
        :build()
    Indent(2)

    local labelWidth = 0
    local labelKeys = {
        "userSettings.freecam.smoothed",
        "userSettings.freecam.fov",
    }
    for _, key in ipairs(labelKeys) do
        local w = GetColumnTextWidth(BJILang.get(key) .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    ColumnsBuilder("UserSettingsFreecam", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("userSettings.freecam.smoothed") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = "toggleSmooth",
                            state = BJIContext.UserSettings.freecamSmooth,
                            onClick = function()
                                BJIContext.UserSettings.freecamSmooth = not BJIContext.UserSettings.freecamSmooth
                                BJITx.player.settings("freecamSmooth", BJIContext.UserSettings.freecamSmooth)
                            end
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("userSettings.freecam.fov") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btn({
                            id = "fovReset",
                            label = BJILang.get("common.buttons.reset"),
                            style = BTN_PRESETS.WARNING,
                            onClick = function()
                                BJIContext.UserSettings.freecamFov = BJICam.DEFAULT_FREECAM_FOV
                                if ctxt.camera == BJICam.CAMERAS.FREE then
                                    BJICam.setFOV(BJICam.DEFAULT_FREECAM_FOV)
                                end
                                BJITx.player.settings("freecamFov", BJIContext.UserSettings.freecamFov)
                            end
                        })
                        :inputNumeric({
                            id = "freecamFov",
                            type = "float",
                            value = BJIContext.UserSettings.freecamFov,
                            min = 10,
                            max = 120,
                            step = 1,
                            stepFast = 5,
                            onUpdate = function(val)
                                BJIContext.UserSettings.freecamFov = val
                                if ctxt.camera == BJICam.CAMERAS.FREE then
                                    BJICam.setFOV(val)
                                end
                                BJITx.player.settings("freecamFov", val)
                            end,
                        })
                        :build()
                end
            }
        })
        :build()

    Indent(-2)
end

local function drawUserStats(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.show_chart,
            big = true,
        })
        :build()
    Indent(2)
    local labelWidth = 0
    for k in pairs(BJIContext.UserStats) do
        local w = GetColumnTextWidth(BJILang.get(svar("userSettings.stats.{1}", { k })) .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    local cols = ColumnsBuilder("UserSettingsStats", { labelWidth, -1 })
    for k, v in pairs(BJIContext.UserStats) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", {
                            BJILang.get(svar("userSettings.stats.{1}", { k }))
                        }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :text(v)
                        :build()
                end
            }
        })
    end
    cols:build()
    Indent(-2)
end

local function drawBody(ctxt)
    drawVehicleSettings(ctxt)
    drawFreecamSettings(ctxt)

    Separator()

    drawUserStats(ctxt)
end

local function drawFooter(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeUserSettings",
            icon = ICONS.exit_to_app,
            background = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.UserSettings.open = false
            end
        })
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    body = drawBody,
    footer = drawFooter,
    onClose = function()
        BJIContext.UserSettings.open = false
    end,
}
