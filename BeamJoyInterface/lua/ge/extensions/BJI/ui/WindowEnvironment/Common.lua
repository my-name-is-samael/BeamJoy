local numericData = require("ge/extensions/utils/EnvironmentUtils").numericData()

local function getEnvNumericType(key)
    if tincludes({ "dayLength", "shadowDistance", "shadowSplits", "visibleDistance", "fogAtmosphereHeight",
            "rainDrops", "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }, key) then
        return "int"
    end
    return "float"
end

local function drawNumericWithReset(cols, key, inputsCallback)
    if BJIEnv.Data[key] == nil then
        return
    end
    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(svar("{1}:", { BJILang.get(svar("environment.{1}", { key })) }))
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
                    :btnIcon({
                        id = svar("reset{1}", { key }),
                        icon = ICONS.refresh,
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

return {
    numericData = numericData,
    drawNumericWithReset = drawNumericWithReset
}
