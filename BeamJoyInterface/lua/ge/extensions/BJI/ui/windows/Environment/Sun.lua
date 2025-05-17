local common = require("ge/extensions/BJI/ui/windows/Environment/Common")

local W = {
    KEYS = Table({ "controlSun", "timePlay", "ToD", "dayLength",
        "dayScale", "nightScale", "sunAzimuthOverride", "sunSize",
        "skyBrightness", "sunLightBrightness", "rayleighScattering",
        "flareScale", "occlusionScale", "exposure", "shadowDistance",
        "shadowSoftness", "shadowSplits", "shadowTexSize", "shadowLogWeight",
        "visibleDistance", "moonAzimuth", "moonElevation", "moonScale",
        "realtime",
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
end

local function updateCols()
    W.cols = Table({
        {
            function()
                LineBuilder()
                    :text(W.labels.controlSun)
                    :build()
            end,
            function()
                LineBuilder()
                    :btnIconToggle({
                        id = "controlSun",
                        state = BJI.Managers.Env.Data.controlSun,
                        coloredIcon = true,
                        onClick = function()
                            BJI.Managers.Env.Data.controlSun = not BJI.Managers.Env.Data.controlSun
                            BJI.Tx.config.env("controlSun", BJI.Managers.Env.Data.controlSun)
                        end,
                    }):btn({
                    id = "resetSun",
                    label = BJI.Managers.Lang.get("common.buttons.resetAll"),
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("reset", BJI.CONSTANTS.ENV_TYPES.SUN)
                    end,
                }):build()
            end,
        },
        {
            function() LineLabel(W.labels.timePlay) end,
            function()
                BJI.Utils.Common.DrawTimePlayPauseButtons("envSunTimePlay", true,
                    not BJI.Managers.Env.Data.controlSun)
            end,
        },
        {
            function() LineLabel(W.labels.dayLength) end,
            common.getNumericWithReset("dayLength", not BJI.Managers.Env.Data.controlSun, function(line)
                line:btn({
                    id = "dayLengthRealtime",
                    label = W.labels.realtime,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        local scale = 0.0208333333
                        BJI.Tx.config.env("dayLength")
                        BJI.Tx.config.env("dayScale", scale)
                        BJI.Tx.config.env("nightScale", scale)
                        BJI.Managers.Env.Data.dayLength = 1800
                        BJI.Managers.Env.Data.dayScale = scale
                        BJI.Managers.Env.Data.nightScale = scale
                    end,
                })
            end),
        },
        {
            function() LineLabel(W.labels.shadowTexSize) end,
            function()
                LineBuilder()
                    :inputNumeric({
                        id = "shadowTexSize",
                        width = 120,
                        type = "int",
                        value = BJI.Managers.Env.Data.shadowTexSizeInput,
                        step = 1,
                        min = 1, -- 2 ^ (1 + 4) = 32
                        max = 7, -- 2 ^ (7 + 4) = 2048
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        onUpdate = function(val)
                            BJI.Managers.Env.Data.shadowTexSizeInput = val
                            val = 2 ^ (val + 4)
                            if val >= 32 and val <= 2048 then
                                BJI.Tx.config.env("shadowTexSize", val)
                                BJI.Managers.Env.Data.shadowTexSize = val
                            end
                        end
                    })
                    :btnIcon({
                        id = "resetshadowTexSize",
                        icon = ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        onClick = function()
                            BJI.Tx.config.env("shadowTexSize")
                        end
                    })
                    :text(BJI.Managers.Env.Data.shadowTexSize)
                    :build()
            end
        }
    }):addAll(
        Table({
            "ToD", "dayScale", "nightScale", "sunAzimuthOverride",
            "sunSize", "skyBrightness", "sunLightBrightness",
            "rayleighScattering", "flareScale", "occlusionScale",
            "exposure", "shadowDistance", "shadowSoftness", "shadowSplits",
            "shadowLogWeight", "visibleDistance", "moonAzimuth",
            "moonElevation", "moonScale"
        }):map(function(k)
            return {
                function() LineLabel(W.labels[k]) end,
                common.getNumericWithReset(k, not BJI.Managers.Env.Data.controlSun),
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
            icon = ICONS.simobject_sun,
            big = true,
        })
        :build()

    Table(W.cols):reduce(function(cols, col)
        cols:addRow(col)
        return cols
    end, ColumnsBuilder("EnvSunSettings", { W.labelsWidth, -1 }))
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
