local numericData = require("ge/extensions/utils/EnvironmentUtils").numericData()

local function getEnvNumericType(key)
    if table.includes({ "dayLength", "shadowDistance", "shadowSplits", "visibleDistance", "fogAtmosphereHeight",
            "rainDrops", "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }, key) then
        return "int"
    end
    return "float"
end

---@param key string
---@param disabled? boolean
---@param inputsCallback? fun(lin: LineBuilder)
local function getNumericWithReset(key, disabled, inputsCallback)
    if BJI.Managers.Env.Data[key] == nil then
        return
    end
    return function()
        local value = 0
        if key == "dropSizeRatio" then
            value = BJI.Managers.Context.UI.dropSizeRatio
        else
            value = tonumber(BJI.Managers.Env.Data[key]) or 0
        end
        local line = LineBuilder()
            :inputNumeric({
                id = key,
                width = 120,
                type = getEnvNumericType(key),
                value = value,
                step = numericData[key].step,
                stepFast = numericData[key].stepFast,
                min = numericData[key].min,
                max = numericData[key].max,
                disabled = disabled,
                onUpdate = function(val)
                    if key == "dropSizeRatio" then
                        BJI.Managers.Context.UI.dropSizeRatio = val
                    else
                        BJI.Managers.Env.Data[key] = val
                    end
                    BJI.Tx.config.env(key, val)
                end
            })
            :btnIcon({
                id = string.var("reset{1}", { key }),
                icon = ICONS.refresh,
                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                onClick = function()
                    BJI.Tx.config.env(key)
                    if key == "dropSizeRatio" then
                        BJI.Managers.Context.UI.dropSizeRatio = 1
                    end
                end
            })
        if type(inputsCallback) == "function" then
            inputsCallback(line)
        end
        line:build()
    end
end

return {
    numericData = numericData,
    getNumericWithReset = getNumericWithReset
}
