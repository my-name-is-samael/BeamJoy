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
        common.drawNumericWithReset(cols, "tempCurveNoon")
        common.drawNumericWithReset(cols, "tempCurveDusk")
        common.drawNumericWithReset(cols, "tempCurveMidnight")
        common.drawNumericWithReset(cols, "tempCurveDawn")
    end
    cols:build()
end

return draw
