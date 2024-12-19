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
        label = "ui.options.multiplayer.nameTags",
        type = "boolean",
        preview = function()
            if settings.getValue("hideNameTags", false) then
                return
            end
            local nameColor = BJINametags.getNametagColor(1)
            local bgColor = BJINametags.getNametagBgColor(1)
            LineBuilder()
                :text(svar("{1}:", { BJILang.get("userSettings.nametags.preview") }))
                :bgText("UserSettingsNametagsBasePreview", " Joel123", nameColor, bgColor)
                :build()
        end
    },
    {
        setting = "nameTagShowDistance",
        label = "ui.options.multiplayer.nameTagShowDistance",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "boolean",
    },
    {
        setting = "nameTagFadeEnabled",
        label = "ui.options.multiplayer.nametagFade",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "boolean",
    },
    {
        setting = "nameTagFadeDistance",
        label = "ui.options.multiplayer.nametagFadeDistance",
        tooltip = "ui.options.multiplayer.nametagFadeDistance.tooltip",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("nameTagFadeEnabled", true) == true
        end,
        type = "int",
        default = 40,
        min = 0,
        max = 1500,
        step = 10,
        stepFast = 50,
    },
    {
        setting = "nameTagFadeInvert",
        label = "ui.options.multiplayer.nametagInvertFade",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("nameTagFadeEnabled", true) == true
        end,
        type = "boolean",
        labelTrue = "ui.options.multiplayer.nametagFadeIn",
        labelFalse = "ui.options.multiplayer.nametagFadeOut",
    },
    {
        setting = "nameTagDontFullyHide",
        label = "ui.options.multiplayer.nametagDontFullyHide",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("nameTagFadeEnabled", true) == true
        end,
        type = "boolean",
        preview = function()
            if not settings.getValue("nameTagDontFullyHide", false) then
                return
            end
            local alpha = .3
            local nameColor = BJINametags.getNametagColor(alpha)
            local bgColor = BJINametags.getNametagBgColor(alpha)
            LineBuilder()
                :text(svar("{1}:", { BJILang.get("userSettings.nametags.preview") }))
                :bgText("UserSettingsNametagsDontFullyHidePreview", " Joel123", nameColor, bgColor)
                :build()
        end
    },
    {
        setting = "shortenNametags",
        label = "ui.options.multiplayer.shortenNametags",
        tooltip = "ui.options.multiplayer.shortenNametags.tooltip",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "boolean",
        preview = function()
            local nameColor = BJINametags.getNametagColor(1)
            local bgColor = BJINametags.getNametagBgColor(1)

            local name = settings.getValue("shortenNametags", true) and "StarryNeb..." or "StarryNebulaSkyx0"
            LineBuilder()
                :text(svar("{1}:", { BJILang.get("userSettings.nametags.preview") }))
                :bgText("UserSettingsNametagsShortenBasePreview", svar(" {1}", { name }), nameColor, bgColor)
                :build()
        end
    },
    {
        setting = "nametagCharLimit",
        label = "ui.options.multiplayer.nametagCharLimit",
        tooltip = "ui.options.multiplayer.nametagCharLimit.tooltip",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("shortenNametags", true)
        end,
        type = "int",
        min = 1,
        max = 50,
        step = 1,
        stepFast = 5,
        preview = function()
            local nameColor = BJINametags.getNametagColor(1)
            local bgColor = BJINametags.getNametagBgColor(1)

            local name = "StarryNebulaSkyx0"
            local nameLength = settings.getValue("nametagCharLimit", 50)
            local short = name:sub(1, nameLength)
            if #short ~= #name then short = svar("{1}...", { short }) end
            name = short
            LineBuilder()
                :text(svar("{1}:", { BJILang.get("userSettings.nametags.preview") }))
                :bgText("UserSettingsNametagsShortenPrecisePreview", svar(" {1}", { name }), nameColor, bgColor)
                :build()
        end
    },
    {
        setting = "showSpectators",
        label = "ui.options.multiplayer.showSpectators",
        tooltip = "ui.options.multiplayer.showSpectators.tooltip",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "boolean",
    }
}
local nametagsBeamjoyFields = {
    {
        obj = BJINametags.COLORS.PLAYER.TEXT,
        label = "colors.player.text",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
        preview = function()
            local nameColor = BJINametags.getNametagColor(1)
            local bgColor = BJINametags.getNametagBgColor(1)
            LineBuilder()
                :text(svar("{1}:", { BJILang.get("userSettings.nametags.preview") }))
                :bgText("UserSettingsNametagsPlayerColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        obj = BJINametags.COLORS.PLAYER.BG,
        label = "colors.player.bg",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
    },
    {
        obj = BJINametags.COLORS.IDLE.TEXT,
        label = "colors.idle.text",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
        preview = function()
            local nameColor = BJINametags.getNametagColor(1, false, true)
            local bgColor = BJINametags.getNametagBgColor(1, false, true)
            LineBuilder()
                :text(svar("{1}:", { BJILang.get("userSettings.nametags.preview") }))
                :bgText("UserSettingsNametagsIdleColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        obj = BJINametags.COLORS.IDLE.BG,
        label = "colors.idle.bg",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
    },
    {
        obj = BJINametags.COLORS.SPEC.TEXT,
        label = "colors.spec.text",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("showSpectators", true)
        end,
        type = "color",
        preview = function()
            local nameColor = BJINametags.getNametagColor(1, true)
            local bgColor = BJINametags.getNametagBgColor(1, true)
            LineBuilder()
                :text(svar("{1}:", { BJILang.get("userSettings.nametags.preview") }))
                :bgText("UserSettingsNametagsSpecColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        obj = BJINametags.COLORS.SPEC.BG,
        label = "colors.spec.bg",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("showSpectators", true)
        end,
        type = "color",
    },
}
local function drawNametagsSettings(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.speaker_notes,
            big = true,
        })
        :build()
    Indent(2)
    -- setup
    local labelWidth = 0
    for _, sc in ipairs(nametagsFields) do
        local label = svar("{1}:", { MPTranslate(sc.label) })
        local tooltip
        tooltip = sc.tooltip and #MPTranslate(sc.tooltip, "") > 0
        local w = GetColumnTextWidth(label .. (tooltip and HELPMARKER_TEXT or ""))
        if w > labelWidth then
            labelWidth = w
        end
    end
    for _, bjf in ipairs(nametagsBeamjoyFields) do
        local label = BJILang.get(svar("userSettings.nametags.{1}", { bjf.label }))
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    -- BeamMP config
    local cols = ColumnsBuilder("UserSettingsNametags", { labelWidth, -1, -1 })
    for _, sc in ipairs(nametagsFields) do
        local disabled = sc.condition and not sc.condition()
        cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                    line:text(MPTranslate(sc.label), disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
                    local tooltip = sc.tooltip and MPTranslate(sc.tooltip, "")
                    if tooltip and #tooltip > 0 then
                        line:helpMarker(tooltip)
                    end
                    line:build()
                end,
                function()
                    local line = LineBuilder()
                    if sc.type == "boolean" then
                        line:btnIconToggle({
                            id = sc.setting,
                            state = settings.getValue(sc.setting) == true,
                            disabled = disabled,
                            coloredIcon = true,
                            onClick = function()
                                settings.setValue(sc.setting, not settings.getValue(sc.setting))
                            end
                        })
                        if sc.labelTrue and settings.getValue(sc.setting) == true then
                            line:text(MPTranslate(sc.labelTrue),
                                disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
                        elseif sc.labelFalse and settings.getValue(sc.setting) ~= true then
                            line:text(MPTranslate(sc.labelFalse),
                                disabled and TEXT_COLORS.DISABLED or TEXT_COLORS
                                .DEFAULT)
                        end
                    elseif sc.type == "int" then
                        line:inputNumeric({
                            id = sc.setting,
                            type = "int",
                            value = tonumber(settings.getValue(sc.setting, tonumber(sc.default) or 0)),
                            min = sc.min,
                            max = sc.max,
                            step = sc.step,
                            stepFast = sc.stepFast,
                            disabled = disabled,
                            onUpdate = function(val)
                                settings.setValue(sc.setting, val)
                            end,
                        })
                    end
                    line:build()
                end,
                not disabled and sc.preview,
            }
        })
    end

    -- BeamJoy config
    for _, bjf in ipairs(nametagsBeamjoyFields) do
        local disabled = bjf.condition and not bjf.condition()
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get(svar("userSettings.nametags.{1}", { bjf.label })) }),
                            disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
                        :build()
                end,
                function()
                    if bjf.type == "color" then
                        LineBuilder()
                            :colorPicker({
                                id = bjf.obj.key,
                                value = bjf.obj.value,
                                disabled = disabled,
                                onChange = function(newColor)
                                    local col = ShapeDrawer.Color(newColor[1], newColor[2], newColor[3])
                                    settings.setValue(bjf.obj.key, jsonEncode(col))
                                    bjf.obj.value = col
                                end
                            })
                            :btnIcon({
                                id = svar("{1}-reset", { bjf.obj.key }),
                                icon = ICONS.refresh,
                                style = BTN_PRESETS.WARNING,
                                disabled = disabled or tdeepcompare(bjf.obj.value, bjf.obj.default),
                                onClick = function()
                                    local col = tdeepcopy(bjf.obj.default)
                                    settings.setValue(bjf.obj.key, jsonEncode(col))
                                    bjf.obj.value = col
                                end
                            })
                            :build()
                    end
                end,
                not disabled and bjf.preview,
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
