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
                        :btnIconToggle({
                            id = "automaticLightsToggle",
                            icon = BJIContext.UserSettings.automaticLights and ICONS.brightness_high or
                                ICONS.brightness_low,
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
        :build()
    Indent(-2)
end

local nametagsFields = {
    {
        setting = "hideNameTags",
        label = "nameTags",
        type = "boolean"
    },
    {
        setting = "nameTagShowDistance",
        label = "nameTagShowDistance",
        type = "boolean"
    },
    {
        setting = "nameTagFadeEnabled",
        label = "nametagFade",
        type = "boolean"
    },
    {
        setting = "nameTagFadeDistance",
        label = "nametagFadeDistance",
        tooltip = "nametagFadeDistance.tooltip",
        condition = function()
            return settings.getValue("nameTagFadeEnabled", true) == true
        end,
        type = "int",
        default = 40,
        min = 0,
        max = 1500,
        step = 10,
        stepFast = 50
    },
    {
        setting = "nameTagFadeInvert",
        label = "nametagInvertFade",
        condition = function()
            return settings.getValue("nameTagFadeEnabled", true) == true
        end,
        type = "boolean",
        labelTrue = "nametagFadeIn",
        labelFalse = "nametagFadeOut"
    },
    {
        setting = "nameTagDontFullyHide",
        label = "nametagDontFullyHide",
        condition = function()
            return settings.getValue("nameTagFadeEnabled", true) == true
        end,
        type = "boolean",
    },
    {
        setting = "shortenNametags",
        label = "shortenNametags",
        type = "boolean",
        tooltip = "shortenNametags.tooltip"
    },
    {
        setting = "nametagCharLimit",
        label = "nametagCharLimit",
        tooltip = "nametagCharLimit.tooltip",
        condition = function()
            return settings.getValue("shortenNametags", true) == true
        end,
        type = "int",
        min = 0,
        max = 50,
        step = 1,
        stepFast = 5,
    },
    {
        setting = "showSpectators",
        label = "showSpectators",
        tooltip = "showSpectators.tooltip",
        type = "boolean",
    },
    {
        setting = "spectatorUnifiedColors",
        label = "spectatorUnifiedColors",
        condition = function()
            return settings.getValue("showSpectators", true) == true
        end,
        type = "boolean",
    }
}

local function drawNametagsSettings(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.speaker_notes,
            big = true,
        })
        :build()
    Indent(2)

    local labelWidth = 0
    for _, f in ipairs(nametagsFields) do
        local label = svar("{1}:", { MPTranslate(svar("ui.options.multiplayer.{1}", { f.label })) })
        local tooltip
        tooltip = f.tooltip and #MPTranslate(svar("ui.options.multiplayer.{1}", { f.tooltip }), "") > 0
        local w = GetColumnTextWidth(label .. (tooltip and HELPMARKER_TEXT or ""))
        if w > labelWidth then
            labelWidth = w
        end
    end
    local cols = ColumnsBuilder("UserSettingsNametags", { labelWidth, -1 })
    for _, f in ipairs(nametagsFields) do
        local disabled = f.condition and not f.condition()
        cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                        :text(MPTranslate(svar("ui.options.multiplayer.{1}", { f.label })),
                            disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
                    local tooltip = f.tooltip and MPTranslate(svar("ui.options.multiplayer.{1}", { f.label }), "")
                    if tooltip and #tooltip > 0 then
                        line:helpMarker(tooltip)
                    end
                    line:build()
                end,
                function()
                    if f.type == "boolean" then
                        local line = LineBuilder()
                            :btnIconToggle({
                                id = f.setting,
                                state = settings.getValue(f.setting) == true,
                                disabled = disabled,
                                coloredIcon = true,
                                onClick = function()
                                    settings.setValue(f.setting, not settings.getValue(f.setting))
                                end
                            })
                        if f.labelTrue and settings.getValue(f.setting) == true then
                            line:text(MPTranslate(svar("ui.options.multiplayer.{1}", { f.labelTrue })),
                                disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
                        elseif f.labelFalse and settings.getValue(f.setting) ~= true then
                            line:text(MPTranslate(svar("ui.options.multiplayer.{1}", { f.labelFalse })),
                                disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
                        end
                        line:build()
                    elseif f.type == "int" then
                        LineBuilder()
                            :inputNumeric({
                                id = f.setting,
                                type = "int",
                                value = tonumber(settings.getValue(f.setting, tonumber(f.default) or 0)),
                                min = f.min,
                                max = f.max,
                                step = f.step,
                                stepFast = f.stepFast,
                                disabled = disabled,
                                onUpdate = function(val)
                                    settings.setValue(f.setting, val)
                                end,
                            })
                            :build()
                    end
                end,
            }
        })
    end
    cols:build()
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
                        :btnIconToggle({
                            id = "toggleSmooth",
                            state = BJIContext.UserSettings.freecamSmooth,
                            coloredIcon = true,
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
                        :btnIcon({
                            id = "fovReset",
                            icon = ICONS.refresh,
                            style = BTN_PRESETS.WARNING,
                            disabled = BJIContext.UserSettings.freecamFov == BJICam.DEFAULT_FREECAM_FOV,
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
    drawNametagsSettings(ctxt)
    drawFreecamSettings(ctxt)

    Separator()

    drawUserStats(ctxt)
end

local function drawFooter(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeUserSettings",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
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
