local common = require("ge/extensions/BJI/ui/windows/Environment/Common")

local W = {
    KEYS = Table({ "controlWeather", "fogDensity", "fogDensityOffset",
        "fogAtmosphereHeight", "cloudHeight", "cloudHeightOne",
        "cloudCover", "cloudCoverOne", "cloudSpeed", "cloudSpeedOne",
        "cloudExposure", "cloudExposureOne", "rainDrops", "dropSize",
        "dropSizeRatio", "dropMinSpeed", "dropMaxSpeed", "precipType",
    }),

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

    Table(BJI.Managers.Env.PRECIP_TYPES):forEach(function(k)
        W.labels[k] = BJI.Managers.Lang.get(string.var("presets.precipType.{1}", { k }))
    end)
end

local function updateCols()
    W.cols = Table({
            {
                function() LineLabel(W.labels.controlWeather) end,
                function()
                    LineBuilder()
                        :btnIconToggle({
                            id = "controlWeather",
                            state = BJI.Managers.Env.Data.controlWeather,
                            coloredIcon = true,
                            onClick = function()
                                BJI.Tx.config.env("controlWeather", not BJI.Managers.Env.Data.controlWeather)
                                BJI.Managers.Env.Data.controlWeather = not BJI.Managers.Env.Data.controlWeather
                            end,
                        }):btn({
                        id = "resetWeather",
                        label = BJI.Managers.Lang.get("common.buttons.resetAll"),
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlWeather,
                        onClick = function()
                            BJI.Tx.config.env("reset", BJI.CONSTANTS.ENV_TYPES.WEATHER)
                        end,
                    }):build()
                end
            }
        }):addAll(
            Table({
                "fogDensity", "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight",
                "cloudHeightOne", "cloudCover", "cloudCoverOne", "cloudSpeed",
                "cloudSpeedOne", "cloudExposure", "cloudExposureOne", "rainDrops",
                "dropSize", "dropMinSpeed", "dropMaxSpeed", "dropSizeRatio"
            }):map(function(k)
                return {
                    function() LineLabel(W.labels[k]) end,
                    common.getNumericWithReset(k, not BJI.Managers.Env.Data.controlWeather),
                }
            end)
        )
        :addAll({
            {
                function() LineLabel(W.labels.precipType) end,
                function()
                    Table(BJI.Managers.Env.PRECIP_TYPES)
                        :reduce(function(line, p)
                            return line:btn({
                                id = p,
                                label = W.labels[p],
                                disabled = BJI.Managers.Env.Data.precipType == p,
                                onClick = function()
                                    BJI.Tx.config.env("precipType", p)
                                    BJI.Managers.Env.Data.precipType = p
                                end
                            })
                        end, LineBuilder()):build()
                end,
            }
        }):map(function(el) return { cells = el } end)
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
            icon = ICONS.simobject_cloud_layer,
            big = true,
        })
        :build()

    Table(W.cols):reduce(function(cols, col)
        cols:addRow(col)
        return cols
    end, ColumnsBuilder("EnvWeatherSettings", { W.labelsWidth, -1 }))
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
