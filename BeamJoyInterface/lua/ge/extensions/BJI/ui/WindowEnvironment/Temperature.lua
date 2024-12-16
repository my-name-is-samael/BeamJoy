local common = require("ge/extensions/BJI/ui/WindowEnvironment/Common")

local function draw()
    LineBuilder()
        :icon({
            icon = ICONS.whatshot,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, label in ipairs({
        BJILang.get("environment.controlTemperature"),
        common.numericData.tempCurveNoon.label,
        common.numericData.tempCurveDusk.label,
        common.numericData.tempCurveMidnight.label,
        common.numericData.tempCurveDawn.label,
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
                        :btnIconToggle({
                            id = "useTempCurve",
                            state = BJIEnv.Data.useTempCurve,
                            coloredIcon = true,
                            onClick = function()
                                BJITx.config.env("useTempCurve", not BJIEnv.Data.useTempCurve)
                                BJIEnv.Data.useTempCurve = not BJIEnv.Data.useTempCurve
                            end,
                        })
                    if BJIEnv.Data.useTempCurve then
                        line:btnIcon({
                            id = "resetTemperature",
                            icon = ICONS.refresh,
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
        common.drawNumericWithReset(cols, "tempCurveNoon")
        common.drawNumericWithReset(cols, "tempCurveDusk")
        common.drawNumericWithReset(cols, "tempCurveMidnight")
        common.drawNumericWithReset(cols, "tempCurveDawn")
    end
    cols:build()
end

return draw
