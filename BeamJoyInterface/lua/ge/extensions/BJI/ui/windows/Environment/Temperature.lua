local W = {
    KEYS = Table({ "controlTemperature", "tempCurveNoon",
        "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }),

    ---@type table<string, string>
    labels = Table(), -- auto-alimented
    labelsWidth = 0,
    cols = Table(),
}

local function updateLabels()
    W.labelsWidth = 0
    W.KEYS:forEach(function(k)
        W.labels[k] = string.var("{1} :", { BJI.Managers.Lang.get(string.var("environment.{1}", { k })) })
        local w = BJI.Utils.Common.GetColumnTextWidth(W.labels[k])
        if w > W.labelsWidth then
            W.labelsWidth = w
        end
    end)

    W.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")
end

local function updateCols()
    local ranges = require("ge/extensions/utils/EnvironmentUtils").numericData()
    W.cols = Table({
        {
            function() LineLabel(W.labels.controlTemperature) end,
            function()
                local line = LineBuilder()
                    :btnIconToggle({
                        id = "useTempCurve",
                        state = BJI.Managers.Env.Data.useTempCurve,
                        coloredIcon = true,
                        onClick = function()
                            BJI.Managers.Env.Data.useTempCurve = not BJI.Managers.Env.Data.useTempCurve
                        end,
                    })
                line:build()
            end
        }
    }):addAll(
        Table({ "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" })
        :map(function(k)
            return {
                function() LineLabel(W.labels[k]) end,
                function()
                    local kelvin = math.celsiusToKelvin(BJI.Managers.Env.Data[k])
                    local renderFormat = string.var("({1}°C | {2}°F | {3}K)", {
                        math.round(BJI.Managers.Env.Data[k] or 0, 2),
                        math.round(math.kelvinToFahrenheit(kelvin or 0) or 0, 2),
                        math.round(kelvin or 0, 2)
                    })
                    LineBuilder():btnIcon({
                        id = "reset" .. k,
                        icon = ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.useTempCurve,
                        onClick = function()
                            BJI.Tx.config.env(k)
                        end
                    }):slider({
                        id = k,
                        type = ranges[k].type,
                        value = BJI.Managers.Env.Data[k],
                        min = ranges[k].min,
                        max = ranges[k].max,
                        precision = ranges[k].precision,
                        disabled = not BJI.Managers.Env.Data.useTempCurve,
                        renderFormat = renderFormat,
                        onUpdate = function(val)
                            BJI.Managers.Env.Data[k] = val
                            BJI.Managers.Env.forceUpdate()
                        end
                    }):build()
                end,
            }
        end)
    ):map(function(el) return { cells = el } end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels))

    updateCols()
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body()
    LineBuilder()
        :icon({
            icon = ICONS.whatshot,
            big = true,
        })
        :build()

    Table(W.cols):reduce(function(cols, col)
        cols:addRow(col)
        return cols
    end, ColumnsBuilder("EnvTemperatureSettings", { W.labelsWidth, -1 }))
        :build()
end


W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
