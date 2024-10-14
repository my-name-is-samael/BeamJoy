local numericData

local function drawGravityPresets(presets)
    -- 6 buttons per line
    local lineThresh = 6
    local i = 1
    while i < tlength(presets) do
        local line = LineBuilder()
        for offset = 0, lineThresh - 1 do
            if presets[i + offset] ~= nil then
                local preset = presets[i + offset]
                local style = BTN_PRESETS.INFO
                if Round(BJIEnv.Data.gravityRate, 3) == Round(preset.value, 3) then
                    style = BTN_PRESETS.DISABLED
                elseif Round(preset.value, 3) == -9.81 then
                    style = BTN_PRESETS.SUCCESS
                end
                line:btn({
                    id = preset.label,
                    label = preset.label,
                    style = style,
                    onClick = function()
                        BJITx.config.env("gravityRate", preset.value)
                    end
                })
            end
        end
        line:build()
        i = i + lineThresh
    end
end

local function drawSpeedPresets(presets)
    -- 5 buttons per line
    local lineThresh = 5
    local i = 1
    while i < tlength(presets) do
        local line = LineBuilder()
        for offset = 0, lineThresh - 1 do
            if presets[i + offset] ~= nil then
                local preset = presets[i + offset]
                local style = BTN_PRESETS.INFO
                if Round(BJIEnv.Data.simSpeed, 3) == Round(preset.value, 3) then
                    style = BTN_PRESETS.DISABLED
                elseif Round(preset.value, 3) == 1 then
                    style = BTN_PRESETS.SUCCESS
                end
                line:btn({
                    id = preset.label,
                    label = preset.label,
                    style = style,
                    onClick = function()
                        BJITx.config.env("simSpeed", preset.value)
                    end
                })
            end
        end
        line:build()
        i = i + lineThresh
    end
end

local function getEnvNumericType(key)
    if tincludes({ "dayLength", "shadowDistance", "shadowSplits", "visibleDistance", "fogAtmosphereHeight",
            "rainDrops", "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }, key) then
        return "int"
    end
    return "float"
end

local function drawNumericWithReset(cols, key, inputsCallback)
    if numericData[key] == nil or BJIEnv.Data[key] == nil then
        return
    end
    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(svar("{1}:", { numericData[key].label }))
                    :build()
            end,
            function()
                LineBuilder()
                    :inputNumeric({
                        id = key,
                        width = 120,
                        type = getEnvNumericType(key),
                        value = BJIEnv.Data[key],
                        step = numericData[key].step,
                        stepFast = numericData[key].stepFast,
                        min = numericData[key].min,
                        max = numericData[key].max,
                        onUpdate = function(val)
                            BJIEnv.Data[key] = val
                            BJITx.config.env(key, val)
                        end
                    })
                    :btn({
                        id = svar("reset{1}", { key }),
                        label = BJILang.get("common.buttons.reset"),
                        style = BTN_PRESETS.WARNING,
                        onClick = function()
                            BJITx.config.env(key)
                        end
                    })
                    :build()
                if type(inputsCallback) == "function" then
                    inputsCallback()
                end
            end
        }
    })
end

local function drawSun()
    LineBuilder()
        :icon({
            icon = ICONS.simobject_sun,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, label in ipairs({
        BJILang.get("environment.controlSun"),
        BJILang.get("environment.timePlay"),
        numericData.ToD.label,
        numericData.dayLength.label,
        numericData.dayScale.label,
        numericData.nightScale.label,
        numericData.sunAzimuthOverride.label,
        numericData.sunSize.label,
        numericData.skyBrightness.label,
        numericData.sunLightBrightness.label,
        numericData.rayleighScattering.label,
        numericData.flareScale.label,
        numericData.occlusionScale.label,
        numericData.exposure.label,
        numericData.shadowDistance.label,
        numericData.shadowSoftness.label,
        numericData.shadowSplits.label,
        numericData.shadowTexSize.label,
        numericData.shadowLogWeight.label,
        numericData.visibleDistance.label,
        numericData.moonAzimuth.label,
        numericData.moonElevation.label,
        numericData.moonScale.label,
    }) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("EnvSunSettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.controlSun") }))
                        :build()
                end,
                function()
                    local line = LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = "controlSun",
                            state = BJIEnv.Data.controlSun,
                            onClick = function()
                                BJITx.config.env("controlSun", not BJIEnv.Data.controlSun)
                                BJIEnv.Data.controlSun = not BJIEnv.Data.controlSun
                            end,
                        })
                    if BJIEnv.Data.controlSun then
                        line:btn({
                            id = "resetSun",
                            label = BJILang.get("common.buttons.resetAll"),
                            style = BTN_PRESETS.WARNING,
                            onClick = function()
                                BJITx.config.env("reset", BJI_ENV_TYPES.SUN)
                            end,
                        })
                    end
                    line:build()
                end,
            }
        })

    if BJIEnv.Data.controlSun then
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.timePlay") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitchPlayStop({
                            id = "timePlay",
                            state = BJIEnv.Data.timePlay,
                            onClick = function()
                                BJITx.config.env("timePlay", not BJIEnv.Data.timePlay)
                                BJIEnv.Data.timePlay = not BJIEnv.Data.timePlay
                            end,
                        })
                        :build()
                end,
            }
        })
        drawNumericWithReset(cols, "ToD")
        drawNumericWithReset(cols, "dayLength", function()
            LineBuilder(true)
                :btn({
                    id = "dayLengthRealtime",
                    label = BJILang.get("environment.realtime"),
                    onClick = function()
                        local scale = 0.0208333333
                        BJITx.config.env("dayLength")
                        BJITx.config.env("dayScale", scale)
                        BJITx.config.env("nightScale", scale)
                        BJIEnv.Data.dayLength = 1800
                        BJIEnv.Data.dayScale = scale
                        BJIEnv.Data.nightScale = scale
                    end,
                })
                :build()
        end)
        drawNumericWithReset(cols, "dayScale")
        drawNumericWithReset(cols, "nightScale")
        drawNumericWithReset(cols, "sunAzimuthOverride")
        drawNumericWithReset(cols, "sunSize")
        drawNumericWithReset(cols, "skyBrightness")
        drawNumericWithReset(cols, "sunLightBrightness")
        drawNumericWithReset(cols, "rayleighScattering")
        drawNumericWithReset(cols, "flareScale")
        drawNumericWithReset(cols, "occlusionScale")
        drawNumericWithReset(cols, "exposure")
        drawNumericWithReset(cols, "shadowDistance")
        drawNumericWithReset(cols, "shadowSoftness")
        drawNumericWithReset(cols, "shadowSplits")
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { numericData.shadowTexSize.label }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "shadowTexSize",
                            width = 120,
                            type = "int",
                            value = BJIEnv.Data.shadowTexSizeInput,
                            step = 1,
                            min = 1, -- 2 ^ (1 + 4) = 32
                            max = 7, -- 2 ^ (7 + 4) = 2048
                            onUpdate = function(val)
                                BJIEnv.Data.shadowTexSizeInput = val
                                val = 2 ^ (val + 4)
                                if val >= 32 and val <= 2048 then
                                    BJITx.config.env("shadowTexSize", val)
                                    BJIEnv.Data.shadowTexSize = val
                                end
                            end
                        })
                        :btn({
                            id = "resetshadowTexSize",
                            label = BJILang.get("common.buttons.reset"),
                            style = BTN_PRESETS.WARNING,
                            onClick = function()
                                BJITx.config.env("shadowTexSize")
                            end
                        })
                        :text(BJIEnv.Data.shadowTexSize)
                        :build()
                end
            }
        })
        drawNumericWithReset(cols, "shadowLogWeight")
        drawNumericWithReset(cols, "visibleDistance")
        drawNumericWithReset(cols, "moonAzimuth")
        drawNumericWithReset(cols, "moonElevation")
        drawNumericWithReset(cols, "moonScale")
    end
    cols:build()
end

local function drawWeather()
    LineBuilder()
        :icon({
            icon = ICONS.simobject_cloud_layer,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, label in ipairs({
        BJILang.get("environment.controlWeather"),
        numericData.fogDensity.label,
        numericData.fogDensityOffset.label,
        numericData.fogAtmosphereHeight.label,
        numericData.cloudHeight.label,
        numericData.cloudHeightOne.label,
        numericData.cloudCover.label,
        numericData.cloudCoverOne.label,
        numericData.cloudSpeed.label,
        numericData.cloudSpeedOne.label,
        numericData.cloudExposure.label,
        numericData.cloudExposureOne.label,
        numericData.rainDrops.label,
        numericData.dropSize.label,
        BJILang.get("environment.dropSizeRatio"),
        numericData.dropMinSpeed.label,
        numericData.dropMaxSpeed.label,
        BJILang.get("environment.precipType")
    }) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("EnvWeatherSettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.controlWeather") }))
                        :build()
                end,
                function()
                    local line = LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = "controlWeather",
                            state = BJIEnv.Data.controlWeather,
                            onClick = function()
                                BJITx.config.env("controlWeather", not BJIEnv.Data.controlWeather)
                                BJIEnv.Data.controlWeather = not BJIEnv.Data.controlWeather
                            end,
                        })
                    if BJIEnv.Data.controlWeather then
                        line:btn({
                            id = "resetWeather",
                            label = BJILang.get("common.buttons.resetAll"),
                            style = BTN_PRESETS.WARNING,
                            onClick = function()
                                BJITx.config.env("reset", BJI_ENV_TYPES.WEATHER)
                            end,
                        })
                    end
                    line:build()
                end
            }
        })

    if BJIEnv.Data.controlWeather then
        drawNumericWithReset(cols, "fogDensity")
        drawNumericWithReset(cols, "fogDensityOffset")
        drawNumericWithReset(cols, "fogAtmosphereHeight")
        drawNumericWithReset(cols, "cloudHeight")
        drawNumericWithReset(cols, "cloudHeightOne")
        drawNumericWithReset(cols, "cloudCover")
        drawNumericWithReset(cols, "cloudCoverOne")
        drawNumericWithReset(cols, "cloudSpeed")
        drawNumericWithReset(cols, "cloudSpeedOne")
        drawNumericWithReset(cols, "cloudExposure")
        drawNumericWithReset(cols, "cloudExposureOne")
        drawNumericWithReset(cols, "rainDrops")
        drawNumericWithReset(cols, "dropSize")
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.dropSizeRatio") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "dropSizeRatio",
                            type = "float",
                            value = BJIContext.UI.dropSizeRatio and BJIContext.UI.dropSizeRatio or 1,
                            width = 120,
                            min = .001,
                            step = .001,
                            onUpdate = function(val)
                                if BJIContext.UI.dropSizeRatio then
                                    BJIContext.UI.dropSizeRatio = val
                                end
                                BJITx.config.env("dropSizeRatio", val)
                            end
                        })
                        :build()
                end
            }
        })
        drawNumericWithReset(cols, "dropMinSpeed")
        drawNumericWithReset(cols, "dropMaxSpeed")

        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("environment.precipType"))
                        :build()
                end,
                function()
                    local line = LineBuilder()
                    for _, p in ipairs(BJIEnv.PRECIP_TYPES) do
                        line:btn({
                            id = svar("{1}PrecipType", { p }),
                            label = BJILang.get("presets.precipType." .. p),
                            disabled = BJIEnv.Data.precipType == p,
                            onClick = function()
                                BJITx.config.env("precipType", p)
                                BJIEnv.Data.precipType = p
                            end
                        })
                    end
                    line:build()
                end,
            }
        })
    end
    cols:build()
end

local function drawGravity()
    LineBuilder()
        :icon({
            icon = ICONS.fitness_center,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, label in ipairs({
        BJILang.get("environment.controlGravity"),
        numericData.gravityRate.label,
    }) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("EnvGravitySettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.controlGravity") }))
                        :build()
                end,
                function()
                    local line = LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = "controlGravity",
                            state = BJIEnv.Data.controlGravity,
                            onClick = function()
                                BJITx.config.env("controlGravity", not BJIEnv.Data.controlGravity)
                                BJIEnv.Data.controlGravity = not BJIEnv.Data.controlGravity
                            end,
                        })
                    if BJIEnv.Data.controlGravity then
                        line:btn({
                            id = "resetGravity",
                            label = BJILang.get("common.buttons.resetAll"),
                            style = BTN_PRESETS.WARNING,
                            onClick = function()
                                BJITx.config.env("reset", BJI_ENV_TYPES.GRAVITY)
                            end,
                        })
                    end
                    line:build()
                end
            }
        })
    if BJIEnv.Data.controlGravity then
        drawNumericWithReset(cols, "gravityRate")
    end
    cols:build()
    if BJIEnv.Data.controlGravity then
        drawGravityPresets(require("ge/extensions/utils/EnvironmentUtils").gravityPresets())
    end
end

local function drawTemperature()
    LineBuilder()
        :icon({
            icon = ICONS.whatshot,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, label in ipairs({
        BJILang.get("environment.controlTemperature"),
        numericData.tempCurveNoon.label,
        numericData.tempCurveDusk.label,
        numericData.tempCurveMidnight.label,
        numericData.tempCurveDawn.label,
    }) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("EnvTemperatureSettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.controlTemperature") }))
                        :build()
                end,
                function()
                    local line = LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = "useTempCurve",
                            state = BJIEnv.Data.useTempCurve,
                            onClick = function()
                                BJITx.config.env("useTempCurve", not BJIEnv.Data.useTempCurve)
                                BJIEnv.Data.useTempCurve = not BJIEnv.Data.useTempCurve
                            end,
                        })
                    if BJIEnv.Data.useTempCurve then
                        line:btn({
                            id = "resetTemperature",
                            label = BJILang.get("common.buttons.reset"),
                            style = BTN_PRESETS.WARNING,
                            onClick = function()
                                BJITx.config.env("reset", BJI_ENV_TYPES.TEMPERATURE)
                            end,
                        })
                    end
                    line:build()
                end
            }
        })
    LineBuilder():build()

    if BJIEnv.Data.useTempCurve then
        drawNumericWithReset(cols, "tempCurveNoon")
        drawNumericWithReset(cols, "tempCurveDusk")
        drawNumericWithReset(cols, "tempCurveMidnight")
        drawNumericWithReset(cols, "tempCurveDawn")
    end
    cols:build()
end

local function drawSpeed()
    LineBuilder()
        :icon({
            icon = ICONS.skip_next,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, label in ipairs({
        BJILang.get("environment.controlSpeed"),
        numericData.simSpeed.label,
    }) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("EnvSpeedSettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.controlSpeed") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = "controlSimSpeed",
                            state = BJIEnv.Data.controlSimSpeed,
                            onClick = function()
                                BJITx.config.env("controlSimSpeed", not BJIEnv.Data.controlSimSpeed)
                                BJIEnv.Data.controlSimSpeed = not BJIEnv.Data.controlSimSpeed
                            end,
                        })
                        :build()
                end
            }
        })

    if BJIEnv.Data.controlSimSpeed then
        drawNumericWithReset(cols, "simSpeed")
    end
    cols:build()
    if BJIEnv.Data.controlSimSpeed then
        drawSpeedPresets(require("ge/extensions/utils/EnvironmentUtils")
            .speedPresets())
    end
end

local tabs = {
    {
        labelKey = "environment.sun",
        draw = drawSun,
    },
    {
        labelKey = "environment.weather",
        draw = drawWeather,
    },
    {
        labelKey = "environment.gravity",
        draw = drawGravity,
    },
    {
        labelKey = "environment.temperature",
        draw = drawTemperature,
    },
    {
        labelKey = "environment.speed",
        draw = drawSpeed,
    }
}
local currentTab = 1

local function drawHeader(ctxt)
    numericData = require("ge/extensions/utils/EnvironmentUtils").numericData()

    local t = TabBarBuilder("BJIEnvironmentTabs")
    for i, tab in pairs(tabs) do
        t:addTab(BJILang.get(tab.labelKey), function()
            currentTab = i
        end)
    end
    t:build()
end

local function drawBody(ctxt)
    local tab = tabs[currentTab]
    if tab then
        tab.draw()
    end
end

local function drawFooter(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeEnvironment",
            icon = ICONS.exit_to_app,
            background = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.EnvironmentEditorOpen = false
            end
        })
        :build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
    onClose = function()
        BJIContext.EnvironmentEditorOpen = false
    end,
}
