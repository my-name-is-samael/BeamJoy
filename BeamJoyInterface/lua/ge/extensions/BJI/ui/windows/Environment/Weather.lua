local W = {
    KEYS = Table({ "controlWeather", "fogDensity", "fogColor", "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight",
        "cloudCover", "cloudSpeed", "cloudExposure", "rainDrops", "dropSize", "dropMinSpeed",
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
        local w = BJI.Utils.UI.GetColumnTextWidth(W.labels[k])
        if w > W.labelsWidth then
            W.labelsWidth = w
        end
        if k:startswith("cloud") then
            local k2 = k .. "One"
            W.labels[k2] = string.var("{1} :", { BJI.Managers.Lang.get(string.var("environment.{1}", { k2 })) })
            w = BJI.Utils.UI.GetColumnTextWidth(W.labels[k2])
            if w > W.labelsCloudWidth then
                W.labelsCloudWidth = w
            end
        end
    end)

    Table(BJI.Managers.Env.PRECIP_TYPES):forEach(function(k)
        W.labels[k] = BJI.Managers.Lang.get(string.var("presets.precipType.{1}", { k }))
    end)

    W.labels.reset = BJI.Managers.Lang.get("common.buttons.reset")
    W.labels.resetAll = BJI.Managers.Lang.get("common.buttons.resetAll")
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
                            BJI.Managers.Env.Data.controlWeather = not BJI.Managers.Env.Data.controlWeather
                        end,
                    }):btn({
                    id = "resetWeather",
                    label = W.labels.resetAll,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlWeather,
                    onClick = function()
                        BJI.Tx.config.env("reset", BJI.CONSTANTS.ENV_TYPES.WEATHER)
                    end,
                }):build()
            end
        }
    }):addAll({
        {
            function() LineLabel(W.labels.fogDensity) end,
            function()
                LineBuilder():btnIcon({
                    id = "resetfogDensity",
                    icon = BJI.Utils.Icon.ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlWeather,
                    tooltip = W.labels.reset,
                    onClick = function()
                        BJI.Tx.config.env("fogDensity")
                    end
                }):slider({
                    id = "fogDensity",
                    type = ranges.fogDensity.type,
                    value = BJI.Managers.Env.Data.fogDensity,
                    min = ranges.fogDensity.min,
                    max = ranges.fogDensity.max,
                    precision = ranges.fogDensity.precision,
                    disabled = not BJI.Managers.Env.Data.controlWeather,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.fogDensity = val
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
            function() LineLabel(W.labels.fogColor) end,
            function()
                local col = table.clone(BJI.Managers.Env.Data.fogColor)
                col[4] = 1
                LineBuilder():btnIcon({
                    id = "resetfogColor",
                    icon = BJI.Utils.Icon.ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlWeather,
                    tooltip = W.labels.reset,
                    onClick = function()
                        BJI.Tx.config.env("fogColor")
                    end
                }):colorPicker({
                    id = "fogColor",
                    value = col,
                    disabled = not BJI.Managers.Env.Data.controlWeather,
                    onChange = function(val)
                        val[4] = nil
                        BJI.Managers.Env.Data.fogColor = val
                        BJI.Managers.Env.forceUpdate()
                    end,
                }):build()
            end,
        }
    }):addAll(
        Table({ "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight", "cloudCover", "cloudSpeed",
            "cloudExposure", "rainDrops", "dropSize", "dropMinSpeed", "dropMaxSpeed" }):map(function(k)
            return {
                function() LineLabel(W.labels[k]) end,
                function()
                    LineBuilder():btnIcon({
                        id = "reset" .. k,
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlWeather,
                        tooltip = W.labels.reset,
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
                            BJI.Managers.Env.forceUpdate()
                        end
                    }):build()
                end,
                k:startswith("cloud") and function() LineLabel(W.labels[k .. "One"]) end or nil,
                k:startswith("cloud") and function()
                    local k2 = k .. "One"
                    LineBuilder():btnIcon({
                        id = "reset" .. k2,
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlWeather,
                        tooltip = W.labels.reset,
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
                            BJI.Managers.Env.forceUpdate()
                        end
                    }):build()
                end or nil
            }
        end)
    ):addAll({
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
    }, updateLabels, W.name))

    updateCols()
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body()
    LineBuilder()
        :icon({
            icon = BJI.Utils.Icon.ICONS.simobject_cloud_layer,
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
