local common = require("ge/extensions/BJI/ui/WindowEnvironment/Common")

local function draw()
    LineBuilder()
        :icon({
            icon = ICONS.simobject_sun,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, key in ipairs({
        "controlSun",
        "timePlay",
        "ToD",
        "dayLength",
        "dayScale",
        "nightScale",
        "sunAzimuthOverride",
        "sunSize",
        "skyBrightness",
        "sunLightBrightness",
        "rayleighScattering",
        "flareScale",
        "occlusionScale",
        "exposure",
        "shadowDistance",
        "shadowSoftness",
        "shadowSplits",
        "shadowTexSize",
        "shadowLogWeight",
        "visibleDistance",
        "moonAzimuth",
        "moonElevation",
        "moonScale",
    }) do
        local label = BJILang.get(svar("environment.{1}", { key }))
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
                        :btnIconToggle({
                            id = "controlSun",
                            state = BJIEnv.Data.controlSun,
                            coloredIcon = true,
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
                    DrawTimePlayPauseButtons("envSunTimePlay", true)
                end,
            }
        })
        common.drawNumericWithReset(cols, "ToD")
        common.drawNumericWithReset(cols, "dayLength", function()
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
        common.drawNumericWithReset(cols, "dayScale")
        common.drawNumericWithReset(cols, "nightScale")
        common.drawNumericWithReset(cols, "sunAzimuthOverride")
        common.drawNumericWithReset(cols, "sunSize")
        common.drawNumericWithReset(cols, "skyBrightness")
        common.drawNumericWithReset(cols, "sunLightBrightness")
        common.drawNumericWithReset(cols, "rayleighScattering")
        common.drawNumericWithReset(cols, "flareScale")
        common.drawNumericWithReset(cols, "occlusionScale")
        common.drawNumericWithReset(cols, "exposure")
        common.drawNumericWithReset(cols, "shadowDistance")
        common.drawNumericWithReset(cols, "shadowSoftness")
        common.drawNumericWithReset(cols, "shadowSplits")
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.shadowTexSize") }))
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
                        :btnIcon({
                            id = "resetshadowTexSize",
                            icon = ICONS.refresh,
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
        common.drawNumericWithReset(cols, "shadowLogWeight")
        common.drawNumericWithReset(cols, "visibleDistance")
        common.drawNumericWithReset(cols, "moonAzimuth")
        common.drawNumericWithReset(cols, "moonElevation")
        common.drawNumericWithReset(cols, "moonScale")
    end
    cols:build()
end

return draw
