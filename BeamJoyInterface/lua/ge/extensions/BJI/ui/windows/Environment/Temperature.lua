local W = {
    KEYS = Table({ "controlTemperature", "tempCurveNoon",
        "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }),

    ---@type table<string, string>
    labels = Table(),
    tempValues = {},
}
--- gc prevention
local nextValue, ranges

local function updateLabels()
    W.KEYS:forEach(function(k)
        W.labels[k] = string.var("{1} :", { BJI.Managers.Lang.get(string.var("environment.{1}", { k })) })
    end)

    W.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")
    W.labels.reset = BJI.Managers.Lang.get("common.buttons.reset")
end

---@param k string
local function updateDisplayValues(k)
    local kelvin = math.celsiusToKelvin(tonumber(BJI.Managers.Env.Data[k]) or 0)
    W.tempValues[k] = {
        BJI.Managers.Env.Data[k],
        math.kelvinToFahrenheit(kelvin or 0) or 0,
        kelvin
    }
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    ranges = require("ge/extensions/utils/EnvironmentUtils").numericData()
    Table({ "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }):forEach(updateDisplayValues)
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body()
    Icon(BJI.Utils.Icon.ICONS.whatshot, { big = true })

    if BeginTable("BJIEnvTemperature", {
            { label = "##env-temperature-labels" },
            { label = "##env-temperature-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.controlTemperature)
        TableNextColumn()
        if IconButton("controlTemperature", BJI.Managers.Env.Data.useTempCurve and
                BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { btnStyle = BJI.Managers.Env.Data.useTempCurve and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
            BJI.Managers.Env.Data.useTempCurve = not BJI.Managers.Env.Data.useTempCurve
        end

        Table({ "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }):forEach(function(k)
            TableNewRow()
            Text(W.labels[k])
            TableNextColumn()
            nextValue = SliderFloatPrecision(k, BJI.Managers.Env.Data[k], ranges.temperature.min, ranges.temperature.max,
                {
                    disabled = not BJI.Managers.Env.Data.useTempCurve,
                    step = ranges.temperature.step,
                    stepFast = ranges.temperature.stepFast,
                    precision = ranges.temperature.precision,
                    formatRender = string.format("(%.2f°C | %.2f°F | %.2fK)", W.tempValues[k][1],
                        W.tempValues[k][2], W.tempValues[k][3])
                })
            if nextValue then
                BJI.Managers.Env.Data[k] = nextValue
                BJI.Managers.Env.forceUpdate()
                updateDisplayValues(k)
            end
        end)

        EndTable()
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
