local W = {
    KEYS = Table({ "controlWeather", "fogDensity", "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight",
        "cloudCover", "cloudSpeed", "cloudExposure", "rainDrops", "dropSize", "dropSizeRatio", "dropMinSpeed",
        "dropMaxSpeed", "precipType" }),

    ---@type table<string, string>
    labels = Table(), -- auto-alimented
    labelsWidth = 0,
    labelsCloudWidth = 0,
    cols = Table(),
}

local function updateLabels()
    W.labelsWidth, W.labelsCloudWidth = 0, 0
    W.KEYS:forEach(function(k)
        W.labels[k] = string.var("{1} :", { BJI.Managers.Lang.get(string.var("environment.{1}", { k })) })
        local w = BJI.Utils.Common.GetColumnTextWidth(W.labels[k])
        if w > W.labelsWidth then
            W.labelsWidth = w
        end
        if k:startswith("cloud") then
            local k2 = k .. "One"
            W.labels[k2] = string.var("{1} :", { BJI.Managers.Lang.get(string.var("environment.{1}", { k2 })) })
            w = BJI.Utils.Common.GetColumnTextWidth(W.labels[k2])
            if w > W.labelsCloudWidth then
                W.labelsCloudWidth = w
            end
        end
    end)

    Table(BJI.Managers.Env.PRECIP_TYPES):forEach(function(k)
        W.labels[k] = BJI.Managers.Lang.get(string.var("presets.precipType.{1}", { k }))
    end)
end

local function updateCols()
    local ranges = require("ge/extensions/utils/EnvironmentUtils").numericData()
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
        Table({ "fogDensity", "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight", "cloudCover", "cloudSpeed",
            "cloudExposure", "rainDrops", "dropSize", "dropMinSpeed", "dropMaxSpeed" }):map(function(k)
            return {
                function() LineLabel(W.labels[k]) end,
                function()
                    LineBuilder():btnIcon({
                        id = "reset" .. k,
                        icon = ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlWeather,
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
                        disabled = not BJI.Managers.Env.Data.controlWeather,
                        onUpdate = function(val)
                            BJI.Managers.Env.Data[k] = val
                            BJI.Tx.config.env(k, val)
                            BJI.Managers.Env.forceUpdate()
                        end
                    }):build()
                end,
                k:startswith("cloud") and function() LineLabel(W.labels[k .. "One"]) end or nil,
                k:startswith("cloud") and function()
                    local k2 = k .. "One"
                    LineBuilder():btnIcon({
                        id = "reset" .. k2,
                        icon = ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlWeather,
                        onClick = function()
                            BJI.Tx.config.env(k2)
                        end
                    }):slider({
                        id = k2,
                        type = ranges[k].type,
                        value = BJI.Managers.Env.Data[k2],
                        min = ranges[k].min,
                        max = ranges[k].max,
                        precision = ranges[k].precision,
                        disabled = not BJI.Managers.Env.Data.controlWeather,
                        onUpdate = function(val)
                            BJI.Managers.Env.Data[k2] = val
                            BJI.Tx.config.env(k2, val)
                            BJI.Managers.Env.forceUpdate()
                        end
                    }):build()
                end or nil
            }
        end)
    ):addAll({
        {
            function() LineLabel(W.labels.dropSizeRatio) end,
            function()
                LineBuilder():btnIcon({
                    id = "resetdropSizeRatio",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlWeather,
                    onClick = function()
                        BJI.Tx.config.env("dropSizeRatio")
                        BJI.Managers.Context.UI.dropSizeRatio = 1
                    end
                }):slider({
                    id = "dropSizeRatio",
                    type = ranges.dropSizeRatio.type,
                    value = BJI.Managers.Context.UI.dropSizeRatio or 1,
                    min = ranges.dropSizeRatio.min,
                    max = ranges.dropSizeRatio.max,
                    precision = ranges.dropSizeRatio.precision,
                    disabled = not BJI.Managers.Env.Data.controlWeather,
                    onUpdate = function(val)
                        BJI.Managers.Context.UI.dropSizeRatio = val ~= 1 and val or nil
                        BJI.Tx.config.env("dropSizeRatio", val)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        },
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
                                BJI.Managers.Env.Data.precipType = p
                                BJI.Tx.config.env("precipType", BJI.Managers.Env.Data.precipType)
                                BJI.Managers.Env.forceUpdate()
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
    end, ColumnsBuilder("EnvWeatherSettings", { W.labelsWidth, -1, W.labelsCloudWidth, -1 }))
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
