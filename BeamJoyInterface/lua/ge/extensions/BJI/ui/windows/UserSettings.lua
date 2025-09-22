---@class BJIWindowUserSettings: BJIWindow
local W = {
    name = "UserSettings",
    minSize = ImVec2(670, 500),
    maxSize = ImVec2(670, 820),

    show = false,
    labels = {
        reset = "",

        vehicle = {
            automaticLights = "",
            automaticLightsTooltip = "",
        },
        nametags = {
            preview = "",
            hide = "",
            showDistance = "",
            hideBehindObjects = "",
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
            speed = "",
        },
        stats = {
            delivery = "",
            race = "",
            bus = "",
        },
    },
}
-- gc prevention
local value, disabled, text, short, nextValue

local function updateLabels()
    W.labels.reset = BJI_Lang.get("common.buttons.reset")

    W.labels.vehicle.automaticLights = BJI_Lang.get("userSettings.vehicles.automaticLights") .. ":"
    W.labels.vehicle.automaticLightsTooltip = BJI_Lang.get("userSettings.vehicles.automaticLightsTooltip")

    W.labels.nametags.preview = BJI_Lang.get("userSettings.nametags.preview") .. ":"
    W.labels.nametags.hide = MPTranslate("ui.options.multiplayer.nameTags") .. ":"
    W.labels.nametags.showDistance = MPTranslate("ui.options.multiplayer.nameTagShowDistance") .. ":"
    W.labels.nametags.hideBehindObjects = MPTranslate("ui.options.multiplayer.nameTagsHideBehindObjects") .. ":"
    W.labels.nametags.fade = MPTranslate("ui.options.multiplayer.nametagFade") .. ":"
    W.labels.nametags.fadeIn = MPTranslate("ui.options.multiplayer.nametagFadeIn")
    W.labels.nametags.fadeOut = MPTranslate("ui.options.multiplayer.nametagFadeOut")
    W.labels.nametags.fadeDistance = MPTranslate("ui.options.multiplayer.nametagFadeDistance") .. ":"
    W.labels.nametags.fadeDistanceTooltip = MPTranslate("ui.options.multiplayer.nametagFadeDistance.tooltip")
    W.labels.nametags.invertFade = MPTranslate("ui.options.multiplayer.nametagInvertFade") .. ":"
    W.labels.nametags.dontFullyHide = MPTranslate("ui.options.multiplayer.nametagDontFullyHide") .. ":"
    W.labels.nametags.shorten = MPTranslate("ui.options.multiplayer.shortenNametags") .. ":"
    W.labels.nametags.shortenTooltip = MPTranslate("ui.options.multiplayer.shortenNametags.tooltip")
    W.labels.nametags.nametagLength = MPTranslate("ui.options.multiplayer.nametagCharLimit") .. ":"
    W.labels.nametags.nametagLengthTooltip = MPTranslate("ui.options.multiplayer.nametagCharLimit.tooltip")
    W.labels.nametags.showSpecs = MPTranslate("ui.options.multiplayer.showSpectators") .. ":"
    W.labels.nametags.showSpecsTooltip = MPTranslate("ui.options.multiplayer.showSpectators.tooltip")
    W.labels.nametags.colorsPlayerText = BJI_Lang.get("userSettings.nametags.colors.player.text") .. ":"
    W.labels.nametags.colorsPlayerBg = BJI_Lang.get("userSettings.nametags.colors.player.bg") .. ":"
    W.labels.nametags.colorsIdleText = BJI_Lang.get("userSettings.nametags.colors.idle.text") .. ":"
    W.labels.nametags.colorsIdleBg = BJI_Lang.get("userSettings.nametags.colors.idle.bg") .. ":"
    W.labels.nametags.colorsSpecText = BJI_Lang.get("userSettings.nametags.colors.spec.text") .. ":"
    W.labels.nametags.colorsSpecBg = BJI_Lang.get("userSettings.nametags.colors.spec.bg") .. ":"

    W.labels.freecam.smooth = BJI_Lang.get("userSettings.freecam.smoothed") .. ":"
    W.labels.freecam.fov = BJI_Lang.get("userSettings.freecam.fov") .. ":"
    W.labels.freecam.speed = BJI_Lang.get("userSettings.freecam.speed") .. ":"

    W.labels.stats.delivery = BJI_Lang.get("userSettings.stats.delivery") .. ":"
    W.labels.stats.race = BJI_Lang.get("userSettings.stats.race") .. ":"
    W.labels.stats.bus = BJI_Lang.get("userSettings.stats.bus") .. ":"
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(
        BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name .. "Labels")
    )
end
local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end


---@param ctxt TickContext
local function drawVehicleSettings(ctxt)
    Icon(BJI.Utils.Icon.ICONS.directions_car, { big = true })
    if BeginTable("UserSettingsVehicle", { { label = "##vehicle-labels" },
            { label = "##vehicle-actions", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } } }) then
        TableNewRow()
        Text(W.labels.vehicle.automaticLights)
        TooltipText(W.labels.vehicle.automaticLightsTooltip)
        TableNextColumn()
        value = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS)
        if IconButton("automaticLightsToggle", value and BJI.Utils.Icon.ICONS.brightness_high or BJI.Utils.Icon.ICONS.brightness_low,
                { btnStyle = value and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            BJI_LocalStorage.set(BJI_LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS, not value)
        end

        EndTable()
    end
end


local nametagsFields = {
    {
        setting = "hideNameTags",
        label = "hide",
        type = "boolean",
        preview = function()
            if value then return end
            Text(W.labels.nametags.preview)
            SameLine()
            text = " Joel123"
            if BeginChild("UserSettingsNametagsBasePreview", { size = CalcTextSize(text),
                    bgColor = BJI_Nametags.getNametagBgColor(1):vec4() }) then
                Text(text, { color = BJI_Nametags.getNametagColor(1):vec4() })
            end
            EndChild()
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
        setting = "nameTagsHideBehindObjects",
        label = "hideBehindObjects",
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
            if disabled then return end
            Text(W.labels.nametags.preview)
            SameLine()
            text = " Joel123"
            if BeginChild("UserSettingsNametagsDontFullyHidePreview", { size = CalcTextSize(text),
                    bgColor = BJI_Nametags.getNametagBgColor(value and .3 or 1):vec4() }) then
                Text(text, { color = BJI_Nametags.getNametagColor(value and .3 or 1):vec4() })
            end
            EndChild()
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
            if disabled then return end
            Text(W.labels.nametags.preview)
            SameLine()
            text = value and " StarryNeb..." or " StarryNebulaSkyx0"
            if BeginChild("UserSettingsNametagsShortenBasePreview", { size = CalcTextSize(text),
                    bgColor = BJI_Nametags.getNametagBgColor(1):vec4() }) then
                Text(text, { color = BJI_Nametags.getNametagColor(1):vec4() })
            end
            EndChild()
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
            if disabled then return end
            Text(W.labels.nametags.preview)
            SameLine()
            text = "StarryNebulaSkyx0"
            short = text:sub(1, tonumber(value))
            if #short < #text then short = string.var("{1}...", { short }) end
            text = " " .. short
            if BeginChild("UserSettingsNametagsShortenPrecisePreview", { size = CalcTextSize(text),
                    bgColor = BJI_Nametags.getNametagBgColor(1):vec4() }) then
                Text(text, { color = BJI_Nametags.getNametagColor(1):vec4() })
            end
            EndChild()
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
        key = BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_PLAYER_TEXT,
        label = "colorsPlayerText",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
        preview = function()
            if disabled then return end
            Text(W.labels.nametags.preview)
            SameLine()
            text = " Joel123"
            if BeginChild("UserSettingsNametagsPlayerColors", { size = CalcTextSize(text),
                    bgColor = BJI_Nametags.getNametagBgColor(1):vec4() }) then
                Text(text, { color = BJI_Nametags.getNametagColor(1):vec4() })
            end
            EndChild()
        end,
    },
    {
        key = BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_PLAYER_BG,
        label = "colorsPlayerBg",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
    },
    {
        key = BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_IDLE_TEXT,
        label = "colorsIdleText",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
        preview = function()
            if disabled then return end
            Text(W.labels.nametags.preview)
            SameLine()
            text = " Joel123"
            if BeginChild("UserSettingsNametagsIdleColors", { size = CalcTextSize(text),
                    bgColor = BJI_Nametags.getNametagBgColor(1, false, true):vec4() }) then
                Text(text, { color = BJI_Nametags.getNametagColor(1, false, true):vec4() })
            end
            EndChild()
        end,
    },
    {
        key = BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_IDLE_BG,
        label = "colorsIdleBg",
        condition = function()
            return not settings.getValue("hideNameTags", false)
        end,
        type = "color",
    },
    {
        key = BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_SPEC_TEXT,
        label = "colorsSpecText",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("showSpectators", true)
        end,
        type = "color",
        preview = function()
            if disabled then return end
            Text(W.labels.nametags.preview)
            SameLine()
            text = " Joel123"
            if BeginChild("UserSettingsNametagsSpecColors", { size = CalcTextSize(text),
                    bgColor = BJI_Nametags.getNametagBgColor(1, true):vec4() }) then
                Text(text, { color = BJI_Nametags.getNametagColor(1, true):vec4() })
            end
            EndChild()
        end,
    },
    {
        key = BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_SPEC_BG,
        label = "colorsSpecBg",
        condition = function()
            return not settings.getValue("hideNameTags", false) and
                settings.getValue("showSpectators", true)
        end,
        type = "color",
    },
}

---@param ctxt TickContext
local function drawNametagsSettings(ctxt)
    Icon(BJI.Utils.Icon.ICONS.speaker_notes, { big = true })
    if BeginTable("UserSettingsNametags", {
            { label = "##nametags-labels" },
            { label = "##nametags-actions", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##nametags-preview" }
        }) then
        for _, nf in ipairs(nametagsFields) do
            value = settings.getValue(nf.setting)
            disabled = nf.condition ~= nil and not nf.condition()
            TableNewRow()
            -- label
            Text(W.labels.nametags[nf.label], {
                color = disabled and
                    BJI.Utils.Style.TEXT_COLORS.DISABLED or BJI.Utils.Style.TEXT_COLORS.DEFAULT
            })
            if nf.tooltip then
                TooltipText(W.labels.nametags[nf.tooltip])
            end
            TableNextColumn()
            -- action
            if nf.type == "boolean" then
                -- Toggle button
                if IconButton(nf.setting, value and BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel, {
                        disabled = disabled,
                        btnStyle = value and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                        bgLess   = true
                    }) then
                    value = not value
                    settings.setValue(nf.setting, value)
                end
                SameLine()
                if value and nf.labelTrue then
                    Text(W.labels.nametags[nf.labelTrue], {
                        color = disabled and
                            BJI.Utils.Style.TEXT_COLORS.DISABLED or BJI.Utils.Style.TEXT_COLORS.DEFAULT
                    })
                elseif not value and nf.labelFalse then
                    Text(W.labels.nametags[nf.labelFalse], {
                        color = disabled and
                            BJI.Utils.Style.TEXT_COLORS.DISABLED or BJI.Utils.Style.TEXT_COLORS.DEFAULT
                    })
                end
            elseif nf.type == "int" then
                -- Integer input
                if nf.default then
                    if IconButton(nf.setting .. "-reset", BJI.Utils.Icon.ICONS.refresh, {
                            disabled = disabled, btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                        value = nf.default
                        settings.setValue(nf.setting, value)
                    end
                    SameLine()
                end
                nextValue = SliderIntPrecision(nf.setting, value or nf.default or nf.min, nf.min, nf.max, {
                    disabled = disabled, step = nf.step, stepFast = nf.stepFast
                })
                if nextValue then
                    value = nextValue
                    settings.setValue(nf.setting, value)
                end
            end
            TableNextColumn()
            -- preview
            if nf.preview then
                nf.preview()
            end
        end

        for _, nbf in ipairs(nametagsBeamjoyFields) do
            value = BJI_LocalStorage.get(nbf.key)
            disabled = nbf.condition ~= nil and not nbf.condition()
            TableNewRow()
            Text(W.labels.nametags[nbf.label], {
                color = disabled and
                    BJI.Utils.Style.TEXT_COLORS.DISABLED or BJI.Utils.Style.TEXT_COLORS.DEFAULT
            })
            if nbf.tooltip then
                TooltipText(W.labels.nametags[nbf.tooltip])
            end
            TableNextColumn()
            if nbf.type == "color" then
                value = BJI.Utils.ShapeDrawer.Color():fromRaw(value)
                if IconButton(nbf.label .. "-reset", BJI.Utils.Icon.ICONS.refresh, {
                        disabled = disabled, btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                    value = BJI.Utils.ShapeDrawer.Color(
                        nbf.key.default.r, nbf.key.default.g,
                        nbf.key.default.b, nbf.key.default.a)
                    BJI_LocalStorage.set(nbf.key, value)
                end
                SameLine()
                nextValue = ColorPicker(nbf.label, value:vec4(), { disabled = disabled })
                if nextValue then
                    value = BJI.Utils.ShapeDrawer.Color():fromVec4(nextValue)
                    BJI_LocalStorage.set(nbf.key, value)
                end
            end
            TableNextColumn()
            if nbf.preview then
                nbf.preview()
            end
        end

        EndTable()
    end
end

---@param ctxt TickContext
local function drawFreecamSettings(ctxt)
    Icon(BJI.Utils.Icon.ICONS.simobject_camera, { big = true })
    if BeginTable("UserSettingsFreecam", { { label = "labels" }, { label = "actions", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } } }) then
        -- smooth
        TableNewRow()
        Text(W.labels.freecam.smooth)
        TableNextColumn()
        value = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.FREECAM_SMOOTH)
        if IconButton("toggleSmooth", value and BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel, {
                btnStyle = value and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                bgLess = true,
            }) then
            BJI_LocalStorage.set(BJI_LocalStorage.GLOBAL_VALUES.FREECAM_SMOOTH, not value)
        end

        -- fov
        TableNewRow()
        Text(W.labels.freecam.fov)
        TableNextColumn()
        value = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.FREECAM_FOV)
        disabled = value == BJI_Cam.DEFAULT_FREECAM_FOV
        if IconButton("camfovReset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = disabled }) then
            value = BJI_Cam.DEFAULT_FREECAM_FOV
            BJI_LocalStorage.set(BJI_LocalStorage.GLOBAL_VALUES.FREECAM_FOV, value)
            if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                BJI_Cam.setFOV(value)
                ui_message({ txt = "ui.camera.fov", context = { degrees = value } }, 2, "cameramode")
            end
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderFloatPrecision("camfov", value, 10, 120, {
            formatRender = "%.1f°",
            step = .5,
            stepFast = 1,
            precision = 1
        })
        if nextValue then
            value = nextValue
            BJI_LocalStorage.set(BJI_LocalStorage.GLOBAL_VALUES.FREECAM_FOV, value)
            if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                BJI_Cam.setFOV(value)
                ui_message({ txt = "ui.camera.fov", context = { degrees = value } }, 2, "cameramode")
            end
        end

        -- speed
        TableNewRow()
        Text(W.labels.freecam.speed)
        TableNextColumn()
        value = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.FREECAM_SPEED)
        disabled = value == BJI_Cam.DEFAULT_FREECAM_SPEED
        if IconButton("camspeedReset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = disabled }) then
            value = BJI_Cam.DEFAULT_FREECAM_SPEED
            BJI_LocalStorage.set(BJI_LocalStorage.GLOBAL_VALUES.FREECAM_SPEED, value)
            if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                BJI_Cam.setSpeed(value)
                ui_message({ txt = "ui.camera.speed", context = { speed = value } }, 1, "cameraspeed")
            end
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderFloatPrecision("camspeed", value, 2, 100, { step = .5, stepFast = 5, precision = 1 })
        if nextValue then
            value = nextValue
            BJI_LocalStorage.set(BJI_LocalStorage.GLOBAL_VALUES.FREECAM_SPEED, value)
            if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                BJI_Cam.setSpeed(value)
                ui_message({ txt = "ui.camera.speed", context = { speed = value } }, 1, "cameraspeed")
            end
        end

        EndTable()
    end
end

---@param ctxt TickContext
local function drawUserStats(ctxt)
    Icon(BJI.Utils.Icon.ICONS.show_chart, { big = true })
    if BeginTable("UserSettingsStats", { { label = "##stats-labels" }, { label = "##stats-actions", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } } }) then
        for _, k in ipairs({ "delivery", "race", "bus" }) do
            if BJI_Context.UserStats[k] then
                TableNewRow()
                Text(W.labels.stats[k])
                TableNextColumn()
                Text(tostring(BJI_Context.UserStats[k] or 0))
            end
        end

        EndTable()
    end
end

---@param ctxt TickContext
local function drawBody(ctxt)
    drawVehicleSettings(ctxt)
    Separator()
    drawNametagsSettings(ctxt)
    Separator()
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
