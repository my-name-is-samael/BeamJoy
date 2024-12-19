local common = require("ge/extensions/BJI/ui/WindowEnvironment/Common")

local function draw()
    LineBuilder()
        :icon({
            icon = ICONS.whatshot,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, key in ipairs({
        "controlTemperature",
        "tempCurveNoon",
        "tempCurveDusk",
        "tempCurveMidnight",
        "tempCurveDawn",
    }) do
        local label = BJILang.get(svar("environment.{1}", { key }))
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
                        :btnIconToggle({
                            id = "useTempCurve",
                            state = BJIEnv.Data.useTempCurve,
                            coloredIcon = true,
                            onClick = function()
                                BJITx.config.env("useTempCurve", not BJIEnv.Data.useTempCurve)
                                BJIEnv.Data.useTempCurve = not BJIEnv.Data.useTempCurve
                            end,
                        })
                    line:build()
                end
            }
        })
    LineBuilder():build()

    if BJIEnv.Data.useTempCurve then
        local vSeparator = BJILang.get("common.vSeparator")
        for _, k in ipairs({
            "tempCurveNoon",
            "tempCurveDusk",
            "tempCurveMidnight",
            "tempCurveDawn",
        }) do
            common.drawNumericWithReset(cols, k, function()
                local kelvin = CelsiusToKelvin(BJIEnv.Data[k])
                local labels = {
                    svar("{1}°C", { Round(BJIEnv.Data[k] or 0, 2) }),
                    svar("{1}°F", { Round(KelvinToFahrenheit(kelvin or 0) or 0, 2) }),
                    svar("{1}K", { Round(kelvin or 0, 2) }),
                }
                LineBuilder(true)
                    :text(tconcat(labels, svar(" {1} ", { vSeparator })))
                    :build()
            end)
        end
    end
    cols:build()
end

return draw
