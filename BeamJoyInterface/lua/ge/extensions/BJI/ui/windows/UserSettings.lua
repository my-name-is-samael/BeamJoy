---@class BJIWindowUserSettings: BJIWindow
local W = {
    name = "UserSettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 330,
    h = 330,

    show = false,
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
}

local function updateLabels()
    W.labels.vehicle.automaticLights = string.var("{1}:",
        { BJI.Managers.Lang.get("userSettings.vehicles.automaticLights") })
    W.labels.vehicle.automaticLightsTooltip = BJI.Managers.Lang.get("userSettings.vehicles.automaticLightsTooltip")

    W.labels.nametags.preview = string.var("{1}:", { BJI.Managers.Lang.get("userSettings.nametags.preview") })
    W.labels.nametags.hide = string.var("{1}:", { MPTranslate("ui.options.multiplayer.nameTags") })
    W.labels.nametags.showDistance = string.var("{1}:",
        { MPTranslate("ui.options.multiplayer.nameTagShowDistance") })
    W.labels.nametags.fade = string.var("{1}:", { MPTranslate("ui.options.multiplayer.nametagFade") })
    W.labels.nametags.fadeIn = MPTranslate("ui.options.multiplayer.nametagFadeIn")
    W.labels.nametags.fadeOut = MPTranslate("ui.options.multiplayer.nametagFadeOut")
    W.labels.nametags.fadeDistance = string.var("{1}:",
        { MPTranslate("ui.options.multiplayer.nametagFadeDistance") })
    W.labels.nametags.fadeDistanceTooltip = MPTranslate("ui.options.multiplayer.nametagFadeDistance.tooltip")
    W.labels.nametags.invertFade = string.var("{1}:", { MPTranslate("ui.options.multiplayer.nametagInvertFade") })
    W.labels.nametags.dontFullyHide = string.var("{1}:",
        { MPTranslate("ui.options.multiplayer.nametagDontFullyHide") })
    W.labels.nametags.shorten = string.var("{1}:", { MPTranslate("ui.options.multiplayer.shortenNametags") })
    W.labels.nametags.shortenTooltip = MPTranslate("ui.options.multiplayer.shortenNametags.tooltip")
    W.labels.nametags.nametagLength = string.var("{1}:", { MPTranslate("ui.options.multiplayer.nametagCharLimit") })
    W.labels.nametags.nametagLengthTooltip = MPTranslate("ui.options.multiplayer.nametagCharLimit.tooltip")
    W.labels.nametags.showSpecs = string.var("{1}:", { MPTranslate("ui.options.multiplayer.showSpectators") })
    W.labels.nametags.showSpecsTooltip = MPTranslate("ui.options.multiplayer.showSpectators.tooltip")
    W.labels.nametags.colorsPlayerText = string.var("{1}:",
        { BJI.Managers.Lang.get("userSettings.nametags.colors.player.text") })
    W.labels.nametags.colorsPlayerBg = string.var("{1}:",
        { BJI.Managers.Lang.get("userSettings.nametags.colors.player.bg") })
    W.labels.nametags.colorsIdleText = string.var("{1}:",
        { BJI.Managers.Lang.get("userSettings.nametags.colors.idle.text") })
    W.labels.nametags.colorsIdleBg = string.var("{1}:",
        { BJI.Managers.Lang.get("userSettings.nametags.colors.idle.bg") })
    W.labels.nametags.colorsSpecText = string.var("{1}:",
        { BJI.Managers.Lang.get("userSettings.nametags.colors.spec.text") })
    W.labels.nametags.colorsSpecBg = string.var("{1}:",
        { BJI.Managers.Lang.get("userSettings.nametags.colors.spec.bg") })

    W.labels.freecam.smooth = string.var("{1}:", { BJI.Managers.Lang.get("userSettings.freecam.smoothed") })
    W.labels.freecam.fov = string.var("{1}:", { BJI.Managers.Lang.get("userSettings.freecam.fov") })

    W.labels.stats.delivery = string.var("{1}:", { BJI.Managers.Lang.get("userSettings.stats.delivery") })
    W.labels.stats.race = string.var("{1}:", { BJI.Managers.Lang.get("userSettings.stats.race") })
    W.labels.stats.bus = string.var("{1}:", { BJI.Managers.Lang.get("userSettings.stats.bus") })
end

local function updateWidths()
    W.widths.vehicleLabels = BJI.Utils.Common.GetColumnTextWidth(W.labels.vehicle.automaticLights ..
        HELPMARKER_TEXT)

    W.widths.nametagsLabels = 0
    table.forEach({ "hide", "showDistance", "fade", "fadeDistance", "invertFade",
        "dontFullyHide", "shorten", "nametagLength", "showSpecs",
        "colorsPlayerText", "colorsPlayerBg", "colorsIdleText",
        "colorsIdleBg", "colorsSpecText", "colorsSpecBg" }, function(k)
        local w = BJI.Utils.Common.GetColumnTextWidth(W.labels.nametags[k] .. (
            W.labels.nametags[k .. "Tooltip"] and HELPMARKER_TEXT or ""
        ))
        if w > W.widths.nametagsLabels then
            W.widths.nametagsLabels = w
        end
    end)

    W.widths.freecamLabels = 0
    table.forEach({ "smooth", "fov" }, function(k)
        local w = BJI.Utils.Common.GetColumnTextWidth(W.labels.freecam[k])
        if w > W.widths.freecamLabels then
            W.widths.freecamLabels = w
        end
    end)

    W.widths.statsLabels = 0
    table.forEach({ "delivery", "race", "bus" }, function(k)
        local w = BJI.Utils.Common.GetColumnTextWidth(W.labels.stats[k])
        if w > W.widths.statsLabels then
            W.widths.statsLabels = w
        end
    end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateWidths))
end
local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function drawVehicleSettings(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.directions_car,
            big = true,
        })
        :build()
    Indent(2)

    ColumnsBuilder("UserSettingsVehicle", { W.widths.vehicleLabels, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(W.labels.vehicle.automaticLights)
                        :helpMarker(W.labels.vehicle.automaticLightsTooltip)
                        :build()
                end,
                function()
                    local state = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS)
                    LineBuilder()
                        :btnIconToggle({
                            id = "automaticLightsToggle",
                            icon = state and ICONS.brightness_high or
                                ICONS.brightness_low,
                            state = state,
                            onClick = function()
                                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS,
                                    not state)
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
            local nameColor = BJI.Managers.Nametags.getNametagColor(1)
            local bgColor = BJI.Managers.Nametags.getNametagBgColor(1)
            LineBuilder()
                :text(W.labels.nametags.preview)
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
            local nameColor = BJI.Managers.Nametags.getNametagColor(alpha)
            local bgColor = BJI.Managers.Nametags.getNametagBgColor(alpha)
            LineBuilder()
                :text(W.labels.nametags.preview)
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
            local nameColor = BJI.Managers.Nametags.getNametagColor(1)
            local bgColor = BJI.Managers.Nametags.getNametagBgColor(1)

            local name = settings.getValue("shortenNametags", true) and "StarryNeb..." or "StarryNebulaSkyx0"
            LineBuilder()
                :text(W.labels.nametags.preview)
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
            local nameColor = BJI.Managers.Nametags.getNametagColor(1)
            local bgColor = BJI.Managers.Nametags.getNametagBgColor(1)

            local name = "StarryNebulaSkyx0"
            local nameLength = settings.getValue("nametagCharLimit", 50)
            local short = name:sub(1, nameLength)
            if #short ~= #name then short = string.var("{1}...", { short }) end
            name = short
            LineBuilder()
                :text(W.labels.nametags.preview)
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
        key = BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_PLAYER_TEXT,
        label = "colorsPlayerText",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
        preview = function()
            local nameColor = BJI.Managers.Nametags.getNametagColor(1)
            local bgColor = BJI.Managers.Nametags.getNametagBgColor(1)
            LineBuilder()
                :text(W.labels.nametags.preview)
                :bgText("UserSettingsNametagsPlayerColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        key = BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_PLAYER_BG,
        label = "colorsPlayerBg",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
    },
    {
        key = BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_IDLE_TEXT,
        label = "colorsIdleText",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
        preview = function()
            local nameColor = BJI.Managers.Nametags.getNametagColor(1, false, true)
            local bgColor = BJI.Managers.Nametags.getNametagBgColor(1, false, true)
            LineBuilder()
                :text(W.labels.nametags.preview)
                :bgText("UserSettingsNametagsIdleColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        key = BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_IDLE_BG,
        label = "colorsIdleBg",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
    },
    {
        key = BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_SPEC_TEXT,
        label = "colorsSpecText",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("showSpectators", true)
        end,
        type = "color",
        preview = function()
            local nameColor = BJI.Managers.Nametags.getNametagColor(1, true)
            local bgColor = BJI.Managers.Nametags.getNametagBgColor(1, true)
            LineBuilder()
                :text(W.labels.nametags.preview)
                :bgText("UserSettingsNametagsSpecColors", " Joel123", nameColor, bgColor)
                :build()
        end,
    },
    {
        key = BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_SPEC_BG,
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
    local cols = ColumnsBuilder("UserSettingsNametags", { W.widths.nametagsLabels, -1, -1 })
    for _, sc in ipairs(nametagsFields) do
        local disabled = sc.condition and not sc.condition()
        cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                    line:text(W.labels.nametags[sc.label],
                        disabled and BJI.Utils.Style.TEXT_COLORS.DISABLED or BJI.Utils.Style.TEXT_COLORS
                        .DEFAULT)
                    if sc.tooltip and #W.labels.nametags[sc.tooltip] > 0 then
                        line:helpMarker(W.labels.nametags[sc.tooltip])
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
                            line:text(W.labels.nametags[sc.labelTrue],
                                disabled and BJI.Utils.Style.TEXT_COLORS.DISABLED or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                        elseif sc.labelFalse and settings.getValue(sc.setting) ~= true then
                            line:text(W.labels.nametags[sc.labelFalse],
                                disabled and BJI.Utils.Style.TEXT_COLORS.DISABLED or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                        end
                    elseif sc.type == "int" then
                        line:inputNumeric({
                            id = sc.setting,
                            type = "int",
                            value = tonumber(settings.getValue(sc.setting, tonumber(sc.default) or 0)) or 0,
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
                not disabled and sc.preview or nil,
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
                        :text(W.labels.nametags[bjf.label],
                            disabled and BJI.Utils.Style.TEXT_COLORS.DISABLED or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                        :build()
                end,
                function()
                    if not bjf.value then
                        bjf.value = BJI.Managers.LocalStorage.get(bjf.key)
                    end
                    if bjf.type == "color" then
                        LineBuilder()
                            :colorPicker({
                                id = bjf.key.key,
                                value = bjf.value,
                                disabled = disabled,
                                onChange = function(newColor)
                                    local col = BJI.Utils.ShapeDrawer.Color(newColor[1], newColor[2], newColor[3])
                                    BJI.Managers.LocalStorage.set(bjf.key, col)
                                    bjf.value = col
                                end
                            })
                            :btnIcon({
                                id = string.var("{1}-reset", { bjf.key.key }),
                                icon = ICONS.refresh,
                                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = disabled or table.compare(bjf.value, bjf.key.default),
                                onClick = function()
                                    local col = table.clone(bjf.key.default)
                                    BJI.Managers.LocalStorage.set(bjf.key, col)
                                    bjf.value = col
                                end
                            })
                            :build()
                    end
                end,
                not disabled and bjf.preview or nil,
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

    ColumnsBuilder("UserSettingsFreecam", { W.widths.freecamLabels, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(W.labels.freecam.smooth)
                        :build()
                end,
                function()
                    local state = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_SMOOTH)
                    LineBuilder()
                        :btnIconToggle({
                            id = "toggleSmooth",
                            state = state,
                            coloredIcon = true,
                            onClick = function()
                                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_SMOOTH,
                                    not state)
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
                        :text(W.labels.freecam.fov)
                        :build()
                end,
                function()
                    local fov = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_FOV)
                    LineBuilder()
                        :btnIcon({
                            id = "fovReset",
                            icon = ICONS.refresh,
                            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = fov == BJI.Managers.Cam.DEFAULT_FREECAM_FOV,
                            onClick = function()
                                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_FOV,
                                    BJI.Managers.Cam.DEFAULT_FREECAM_FOV)
                                if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                                    BJI.Managers.Cam.setFOV(BJI.Managers.Cam.DEFAULT_FREECAM_FOV)
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
                                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_FOV, val)
                                if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                                    BJI.Managers.Cam.setFOV(val)
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

    local cols = ColumnsBuilder("UserSettingsStats", { W.widths.statsLabels, -1 })
    table.forEach({ "delivery", "race", "bus" }, function(k)
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(W.labels.stats[k])
                        :build()
                end,
                function()
                    LineBuilder()
                        :text(BJI.Managers.Context.UserStats[k] or 0)
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

W.onLoad = onLoad
W.onUnload = onUnload
W.body = drawBody
W.onClose = function()
    W.show = false
end
W.getState = function() return W.show end

return W
