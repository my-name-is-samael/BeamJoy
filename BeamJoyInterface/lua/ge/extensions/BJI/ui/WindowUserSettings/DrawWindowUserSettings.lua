local M = {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    show = false,
    cache = {
        labels = {
            vehicle = {
                automaticLights = "",
                automaticLightsTooltip = "",
            },
            nametags = {
                preview = "",
                hide = "",
                showDistance = "",
                fade = "",
                fadeIn = "",
                fadeOut = "",
                fadeDistance = "",
                fadeDistanceTooltip = "",
                invertFade = "",
                dontFullyHide = "",
                shorten = "",
                shortenTooltip = "",
                nametagLength = "",
                showSpecs = "",
                showSpecsTooltip = "",
                colorsPlayerText = "",
                colorsPlayerBg = "",
                colorsIdleText = "",
                colorsIdleBg = "",
                colorsSpecText = "",
                colorsSpecBg = "",
            },
            freecam = {
                smooth = "",
                fov = "",
            },
            stats = {
                delivery = "",
                race = "",
                bus = "",
            },
        },
        widths = {
            vehicleLabels = 0,
            nametagsLabels = 0,
            freecamLabels = 0,
            statsLabels = 0,
        },
    },
}

local function updateLabels()
    M.cache.labels.vehicle.automaticLights = string.var("{1}:", { BJILang.get("userSettings.vehicles.automaticLights") })
    M.cache.labels.vehicle.automaticLightsTooltip = BJILang.get("userSettings.vehicles.automaticLightsTooltip")

    M.cache.labels.nametags.preview = string.var("{1}:", { BJILang.get("userSettings.nametags.preview") })
    M.cache.labels.nametags.hide = string.var("{1}:", { MPTranslate("ui.options.multiplayer.nameTags") })
    M.cache.labels.nametags.showDistance = string.var("{1}:",
        { MPTranslate("ui.options.multiplayer.nameTagShowDistance") })
    M.cache.labels.nametags.fade = string.var("{1}:", { MPTranslate("ui.options.multiplayer.nametagFade") })
    M.cache.labels.nametags.fadeIn = MPTranslate("ui.options.multiplayer.nametagFadeIn")
    M.cache.labels.nametags.fadeOut = MPTranslate("ui.options.multiplayer.nametagFadeOut")
    M.cache.labels.nametags.fadeDistance = string.var("{1}:",
        { MPTranslate("ui.options.multiplayer.nametagFadeDistance") })
    M.cache.labels.nametags.fadeDistanceTooltip = MPTranslate("ui.options.multiplayer.nametagFadeDistance.tooltip")
    M.cache.labels.nametags.invertFade = string.var("{1}:", { MPTranslate("ui.options.multiplayer.nametagInvertFade") })
    M.cache.labels.nametags.dontFullyHide = string.var("{1}:",
        { MPTranslate("ui.options.multiplayer.nametagDontFullyHide") })
    M.cache.labels.nametags.shorten = string.var("{1}:", { MPTranslate("ui.options.multiplayer.shortenNametags") })
    M.cache.labels.nametags.shortenTooltip = MPTranslate("ui.options.multiplayer.shortenNametags.tooltip")
    M.cache.labels.nametags.nametagLength = string.var("{1}:", { MPTranslate("ui.options.multiplayer.nametagCharLimit") })
    M.cache.labels.nametags.nametagLengthTooltip = MPTranslate("ui.options.multiplayer.nametagCharLimit.tooltip")
    M.cache.labels.nametags.showSpecs = string.var("{1}:", { MPTranslate("ui.options.multiplayer.showSpectators") })
    M.cache.labels.nametags.showSpecsTooltip = MPTranslate("ui.options.multiplayer.showSpectators.tooltip")
    M.cache.labels.nametags.colorsPlayerText = string.var("{1}:",
        { BJILang.get("userSettings.nametags.colors.player.text") })
    M.cache.labels.nametags.colorsPlayerBg = string.var("{1}:", { BJILang.get("userSettings.nametags.colors.player.bg") })
    M.cache.labels.nametags.colorsIdleText = string.var("{1}:", { BJILang.get("userSettings.nametags.colors.idle.text") })
    M.cache.labels.nametags.colorsIdleBg = string.var("{1}:", { BJILang.get("userSettings.nametags.colors.idle.bg") })
    M.cache.labels.nametags.colorsSpecText = string.var("{1}:", { BJILang.get("userSettings.nametags.colors.spec.text") })
    M.cache.labels.nametags.colorsSpecBg = string.var("{1}:", { BJILang.get("userSettings.nametags.colors.spec.bg") })

    M.cache.labels.freecam.smooth = string.var("{1}:", { BJILang.get("userSettings.freecam.smoothed") })
    M.cache.labels.freecam.fov = string.var("{1}:", { BJILang.get("userSettings.freecam.fov") })

    M.cache.labels.stats.delivery = string.var("{1}:", { BJILang.get("userSettings.stats.delivery") })
    M.cache.labels.stats.race = string.var("{1}:", { BJILang.get("userSettings.stats.race") })
    M.cache.labels.stats.bus = string.var("{1}:", { BJILang.get("userSettings.stats.bus") })
end

local function updateWidths()
    M.cache.widths.vehicleLabels = GetColumnTextWidth(M.cache.labels.vehicle.automaticLights .. HELPMARKER_TEXT)

    M.cache.widths.nametagsLabels = 0
    table.forEach({ "hide", "showDistance", "fade", "fadeDistance", "invertFade",
        "dontFullyHide", "shorten", "nametagLength", "showSpecs",
        "colorsPlayerText", "colorsPlayerBg", "colorsIdleText",
        "colorsIdleBg", "colorsSpecText", "colorsSpecBg" }, function(k)
        local w = GetColumnTextWidth(M.cache.labels.nametags[k] .. (
            M.cache.labels.nametags[k .. "Tooltip"] and HELPMARKER_TEXT or ""
        ))
        if w > M.cache.widths.nametagsLabels then
            M.cache.widths.nametagsLabels = w
        end
    end)

    M.cache.widths.freecamLabels = 0
    table.forEach({ "smooth", "fov" }, function(k)
        local w = GetColumnTextWidth(M.cache.labels.freecam[k])
        if w > M.cache.widths.freecamLabels then
            M.cache.widths.freecamLabels = w
        end
    end)

    M.cache.widths.statsLabels = 0
    table.forEach({ "delivery", "race", "bus" }, function(k)
        local w = GetColumnTextWidth(M.cache.labels.stats[k])
        if w > M.cache.widths.statsLabels then
            M.cache.widths.statsLabels = w
        end
    end)
end

local listeners = {}
local function onLoad()
    updateLabels()
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end))

    updateWidths()
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, updateWidths))
end
local function onUnload()
    table.forEach(listeners, BJIEvents.removeListener)
end

local function drawVehicleSettings(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.directions_car,
            big = true,
        })
        :build()
    Indent(2)

    ColumnsBuilder("UserSettingsVehicle", { M.cache.widths.vehicleLabels, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(M.cache.labels.vehicle.automaticLights)
                        :helpMarker(M.cache.labels.vehicle.automaticLightsTooltip)
                        :build()
                end,
                function()
                    local state = BJILocalStorage.get(BJILocalStorage.VALUES.AUTOMATIC_LIGHTS)
                    LineBuilder()
                        :btnIconToggle({
                            id = "automaticLightsToggle",
                            icon = state and ICONS.brightness_high or
                                ICONS.brightness_low,
                            state = state,
                            onClick = function()
                                BJILocalStorage.set(BJILocalStorage.VALUES.AUTOMATIC_LIGHTS, not state)
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
        label = "hide",
        type = "boolean",
        preview = function()
            if settings.getValue("hideNameTags", false) then
                return
            end
            local nameColor = BJINametags.getNametagColor(1)
            local bgColor = BJINametags.getNametagBgColor(1)
            LineBuilder()
                :text(M.cache.labels.nametags.preview)
                :bgText("UserSettingsNametagsBasePreview", " Joel123", nameColor, bgColor)
                :build()
        end
    },
    {
        setting = "nameTagShowDistance",
        label = "showDistance",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "boolean",
    },
    {
        setting = "nameTagFadeEnabled",
        label = "fade",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "boolean",
    },
    {
        setting = "nameTagFadeDistance",
        label = "fadeDistance",
        tooltip = "fadeDistanceTooltip",
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
        label = "invertFade",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("nameTagFadeEnabled", true) == true
        end,
        type = "boolean",
        labelTrue = "fadeIn",
        labelFalse = "fadeOut",
    },
    {
        setting = "nameTagDontFullyHide",
        label = "dontFullyHide",
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
                :text(M.cache.labels.nametags.preview)
                :bgText("UserSettingsNametagsDontFullyHidePreview", " Joel123", nameColor, bgColor)
                :build()
        end
    },
    {
        setting = "shortenNametags",
        label = "shorten",
        tooltip = "shortenTooltip",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "boolean",
        preview = function()
            local nameColor = BJINametags.getNametagColor(1)
            local bgColor = BJINametags.getNametagBgColor(1)

            local name = settings.getValue("shortenNametags", true) and "StarryNeb..." or "StarryNebulaSkyx0"
            LineBuilder()
                :text(M.cache.labels.nametags.preview)
                :bgText("UserSettingsNametagsShortenBasePreview", string.var(" {1}", { name }), nameColor, bgColor)
                :build()
        end
    },
    {
        setting = "nametagCharLimit",
        label = "nametagLength",
        tooltip = "nametagLengthTooltip",
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
            if #short ~= #name then short = string.var("{1}...", { short }) end
            name = short
            LineBuilder()
                :text(M.cache.labels.nametags.preview)
                :bgText("UserSettingsNametagsShortenPrecisePreview", string.var(" {1}", { name }), nameColor, bgColor)
                :build()
        end
    },
    {
        setting = "showSpectators",
        label = "showSpecs",
        tooltip = "showSpecsTooltip",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "boolean",
    }
}
local nametagsBeamjoyFields = {
    {
        key = BJILocalStorage.VALUES.NAMETAGS_COLOR_PLAYER_TEXT,
        label = "colorsPlayerText",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
        preview = function()
            local nameColor = BJINametags.getNametagColor(1)
            local bgColor = BJINametags.getNametagBgColor(1)
            LineBuilder()
                :text(M.cache.labels.nametags.preview)
                :bgText("UserSettingsNametagsPlayerColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        key = BJILocalStorage.VALUES.NAMETAGS_COLOR_PLAYER_BG,
        label = "colorsPlayerBg",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
    },
    {
        key = BJILocalStorage.VALUES.NAMETAGS_COLOR_IDLE_TEXT,
        label = "colorsIdleText",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
        preview = function()
            local nameColor = BJINametags.getNametagColor(1, false, true)
            local bgColor = BJINametags.getNametagBgColor(1, false, true)
            LineBuilder()
                :text(M.cache.labels.nametags.preview)
                :bgText("UserSettingsNametagsIdleColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        key = BJILocalStorage.VALUES.NAMETAGS_COLOR_IDLE_BG,
        label = "colorsIdleBg",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
    },
    {
        key = BJILocalStorage.VALUES.NAMETAGS_COLOR_SPEC_TEXT,
        label = "colorsSpecText",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("showSpectators", true)
        end,
        type = "color",
        preview = function()
            local nameColor = BJINametags.getNametagColor(1, true)
            local bgColor = BJINametags.getNametagBgColor(1, true)
            LineBuilder()
                :text(M.cache.labels.nametags.preview)
                :bgText("UserSettingsNametagsSpecColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        key = BJILocalStorage.VALUES.NAMETAGS_COLOR_SPEC_BG,
        label = "colorsSpecBg",
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
    -- BeamMP configs
    local cols = ColumnsBuilder("UserSettingsNametags", { M.cache.widths.nametagsLabels, -1, -1 })
    for _, sc in ipairs(nametagsFields) do
        local disabled = sc.condition and not sc.condition()
        cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                    line:text(M.cache.labels.nametags[sc.label], disabled and TEXT_COLORS.DISABLED or TEXT_COLORS
                        .DEFAULT)
                    if sc.tooltip and #M.cache.labels.nametags[sc.tooltip] > 0 then
                        line:helpMarker(M.cache.labels.nametags[sc.tooltip])
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
                            line:text(M.cache.labels.nametags[sc.labelTrue],
                                disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
                        elseif sc.labelFalse and settings.getValue(sc.setting) ~= true then
                            line:text(M.cache.labels.nametags[sc.labelFalse],
                                disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
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

    -- BeamJoy configs
    for _, bjf in ipairs(nametagsBeamjoyFields) do
        local disabled = bjf.condition and not bjf.condition()
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(M.cache.labels.nametags[bjf.label],
                            disabled and TEXT_COLORS.DISABLED or TEXT_COLORS.DEFAULT)
                        :build()
                end,
                function()
                    if not bjf.value then
                        bjf.value = BJILocalStorage.get(bjf.key)
                    end
                    if bjf.type == "color" then
                        LineBuilder()
                            :colorPicker({
                                id = bjf.key.key,
                                value = bjf.value,
                                disabled = disabled,
                                onChange = function(newColor)
                                    local col = ShapeDrawer.Color(newColor[1], newColor[2], newColor[3])
                                    BJILocalStorage.set(bjf.key, col)
                                    bjf.value = col
                                end
                            })
                            :btnIcon({
                                id = string.var("{1}-reset", { bjf.key.key }),
                                icon = ICONS.refresh,
                                style = BTN_PRESETS.WARNING,
                                disabled = disabled or table.compare(bjf.value, bjf.key.default),
                                onClick = function()
                                    local col = table.clone(bjf.key.default)
                                    BJILocalStorage.set(bjf.key, col)
                                    bjf.value = col
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

    ColumnsBuilder("UserSettingsFreecam", { M.cache.widths.freecamLabels, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(M.cache.labels.freecam.smooth)
                        :build()
                end,
                function()
                    local state = BJILocalStorage.get(BJILocalStorage.VALUES.FREECAM_SMOOTH)
                    LineBuilder()
                        :btnIconToggle({
                            id = "toggleSmooth",
                            state = state,
                            coloredIcon = true,
                            onClick = function()
                                BJILocalStorage.set(BJILocalStorage.VALUES.FREECAM_SMOOTH, not state)
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
                        :text(M.cache.labels.freecam.fov)
                        :build()
                end,
                function()
                    local fov = BJILocalStorage.get(BJILocalStorage.VALUES.FREECAM_FOV)
                    LineBuilder()
                        :btnIcon({
                            id = "fovReset",
                            icon = ICONS.refresh,
                            style = BTN_PRESETS.WARNING,
                            disabled = fov == BJICam.DEFAULT_FREECAM_FOV,
                            onClick = function()
                                BJILocalStorage.set(BJILocalStorage.VALUES.FREECAM_FOV, BJICam.DEFAULT_FREECAM_FOV)
                                if ctxt.camera == BJICam.CAMERAS.FREE then
                                    BJICam.setFOV(BJICam.DEFAULT_FREECAM_FOV)
                                end
                            end
                        })
                        :inputNumeric({
                            id = "freecamFov",
                            type = "float",
                            value = fov,
                            min = 10,
                            max = 120,
                            step = 1,
                            stepFast = 5,
                            onUpdate = function(val)
                                BJILocalStorage.set(BJILocalStorage.VALUES.FREECAM_FOV, val)
                                if ctxt.camera == BJICam.CAMERAS.FREE then
                                    BJICam.setFOV(val)
                                end
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

    local cols = ColumnsBuilder("UserSettingsStats", { M.cache.widths.statsLabels, -1 })
    table.forEach({"delivery","race","bus"}, function (k)
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(M.cache.labels.stats[k])
                        :build()
                end,
                function()
                    LineBuilder()
                        :text(BJIContext.UserStats[k] or 0)
                        :build()
                end
            }
        })
    end)
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

local function onClose()
    M.show = false
end

M.onLoad = onLoad
M.onUnload = onUnload

M.body = drawBody
M.onClose = onClose

return M
