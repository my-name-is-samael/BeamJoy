local common = require("ge/extensions/BJI/ui/WindowEnvironment/Common")

local function draw()
    LineBuilder()
        :icon({
            icon = ICONS.simobject_cloud_layer,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, key in ipairs({
        "controlWeather",
        "fogDensity",
        "fogDensityOffset",
        "fogAtmosphereHeight",
        "cloudHeight",
        "cloudHeightOne",
        "cloudCover",
        "cloudCoverOne",
        "cloudSpeed",
        "cloudSpeedOne",
        "cloudExposure",
        "cloudExposureOne",
        "rainDrops",
        "dropSize",
        "dropSizeRatio",
        "dropMinSpeed",
        "dropMaxSpeed",
        "precipType",
    }) do
        local label = BJILang.get(svar("environment.{1}", { key }))
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
                        :btnIconToggle({
                            id = "controlWeather",
                            state = BJIEnv.Data.controlWeather,
                            coloredIcon = true,
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
        common.drawNumericWithReset(cols, "fogDensity")
        common.drawNumericWithReset(cols, "fogDensityOffset")
        common.drawNumericWithReset(cols, "fogAtmosphereHeight")
        common.drawNumericWithReset(cols, "cloudHeight")
        common.drawNumericWithReset(cols, "cloudHeightOne")
        common.drawNumericWithReset(cols, "cloudCover")
        common.drawNumericWithReset(cols, "cloudCoverOne")
        common.drawNumericWithReset(cols, "cloudSpeed")
        common.drawNumericWithReset(cols, "cloudSpeedOne")
        common.drawNumericWithReset(cols, "cloudExposure")
        common.drawNumericWithReset(cols, "cloudExposureOne")
        common.drawNumericWithReset(cols, "rainDrops")
        common.drawNumericWithReset(cols, "dropSize")
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
                                BJITx.config.env("dropSizeRatio", val)
                                BJIContext.UI.dropSizeRatio = val
                            end
                        })
                        :btnIcon({
                            id = "resetdropSizeRatio",
                            icon = ICONS.refresh,
                            style = BTN_PRESETS.WARNING,
                            onClick = function()
                                BJITx.config.env("dropSizeRatio", 1)
                                BJIContext.UI.dropSizeRatio = 1
                            end
                        })
                        :build()
                end
            }
        })
        common.drawNumericWithReset(cols, "dropMinSpeed")
        common.drawNumericWithReset(cols, "dropMaxSpeed")

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

return draw
