local common = require("ge/extensions/BJI/ui/windows/Environment/Common")

local W = {
    KEYS = {
        common = Table({ "controlSun", "timePlay", "ToD", "dayLength", "visibleDistance", "shadowDistance",
            "shadowSoftness", "shadowSplits", "shadowLogWeight" }),
        day = Table({ "dayScale", "sunAzimuthOverride", "sunSize", "skyBrightness", "brightness", "rayleighScattering",
            "flareScale", "occlusionScale", "exposure" }),
        night = Table({ "nightScale", "moonAzimuth", "moonScale", "brightness", "moonElevation" }),
    },

    ---@type table<string, string>
    labels = {
        controlSun = "",
        timePlay = "",
        ToD = "",
        dayLength = "",
        visibleDistance = "",
        realtime = "",

        day = "",
        night = "",
        dayScale = "",
        nightScale = "",
        sunAzimuthOverride = "",
        sunSize = "",
        skyBrightness = "",
        brightness = "",
        rayleighScattering = "",
        flareScale = "",
        occlusionScale = "",
        exposure = "",
        shadowDistance = "",
        shadowSoftness = "",
        shadowSplits = "",
        shadowTexSize = "",
        shadowLogWeight = "",
        moonAzimuth = "",
        moonElevation = "",
        moonScale = "",
    },
    labelsPresets = {
        dawn = "",
        midday = "",
        dusk = "",
        midnight = "",
    },
    labelsCommonWidth = 0,
    labelsDayWidth = 0,
    labelsNightWidth = 0,
    timePresets = require("ge/extensions/utils/EnvironmentUtils").timePresets(),
}

local function updateLabels()
    Table(W.labels):forEach(function(_, k)
        W.labels[k] = BJI.Managers.Lang.get(string.var("environment.{1}", { k }))
    end)
    Table(W.labelsPresets):forEach(function(_, k)
        W.labelsPresets[k] = BJI.Managers.Lang.get(string.var("presets.time.{1}", { k }))
    end)

    W.labelsCommonWidth = W.KEYS.common:reduce(function(acc, k)
        local l = W.labels[k]
        local w = BJI.Utils.Common.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)

    W.labelsDayWidth = W.KEYS.day:reduce(function(acc, k)
        local l = W.labels[k]
        local w = BJI.Utils.Common.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)

    W.labelsNightWidth = W.KEYS.night:reduce(function(acc, k)
        local l = W.labels[k]
        local w = BJI.Utils.Common.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels))
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

    ColumnsBuilder("EnvSunSettingsBase", { W.labelsCommonWidth, -1 }):addRow({
        cells = {
            function() LineLabel(W.labels.controlSun) end,
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
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.timePlay) end,
            function()
                BJI.Utils.Common.DrawTimePlayPauseButtons("envSunTimePlay", true,
                    not BJI.Managers.Env.Data.controlSun)
                Table(W.timePresets):reduce(function(line, p)
                    return line:btn({
                        id = "timepreset" .. p.label,
                        label = W.labelsPresets[p.label],
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        onClick = function()
                            BJI.Managers.Env.Data.ToD = p.ToD
                            BJI.Tx.config.env("ToD", p.ToD)
                        end,
                    })
                end, LineBuilder(true)):build()
            end,
        }
    }):build()
    ColumnsBuilder("EnvSunSettingsCommon", { W.labelsCommonWidth, -1, -1 }):addRow({
        cells = {
            function() LineLabel(W.labels.ToD) end,
            function()
                LineBuilder():btnIcon({
                    id = "resetToD",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("ToD")
                    end
                }):slider({
                    id = "ToD",
                    type = "float",
                    value = (BJI.Managers.Env.Data.ToD + .5) % 1,
                    min = 0,
                    max = 1,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.ToD = (val + .5) % 1
                        BJI.Tx.config.env("ToD", BJI.Managers.Env.Data.ToD)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
            function()
                LineLabel(BJI.Utils.Common.PrettyTime(BJI.Managers.Env.Data.ToD))
            end
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.dayLength) end,
            function()
                LineBuilder():btnIcon({
                    id = "resetdayLength",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("dayLength")
                    end
                }):inputNumeric({
                    id = "dayLength",
                    type = "int",
                    value = BJI.Managers.Env.Data.dayLength,
                    step = 60,
                    stepFast = 600,
                    min = 60,
                    max = 86400,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.dayLength = val
                        BJI.Tx.config.env("dayLength", val)
                    end
                }):build()
            end,
            function()
                LineBuilder():btn({
                    id = "dayLengthRealtime",
                    label = W.labels.realtime,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Managers.Env.Data.dayLength = 86400
                        BJI.Tx.config.env("dayLength", BJI.Managers.Env.Data.dayLength)
                    end,
                }):btn({
                    id = "dayLength20min",
                    label = "20m",
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Managers.Env.Data.dayLength = 1200
                        BJI.Tx.config.env("dayLength", BJI.Managers.Env.Data.dayLength)
                    end,
                }):btn({
                    id = "dayLength1hour",
                    label = "1h",
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Managers.Env.Data.dayLength = 3600
                        BJI.Tx.config.env("dayLength", BJI.Managers.Env.Data.dayLength)
                    end,
                }):text(BJI.Utils.Common.PrettyDelay(BJI.Managers.Env.Data.dayLength))
                    :build()
            end
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.visibleDistance) end,
            function()
                LineBuilder():btnIcon({
                    id = "resetvisibleDistance",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("visibleDistance")
                    end
                }):slider({
                    id = "visibleDistance",
                    type = "int",
                    value = BJI.Managers.Env.Data.visibleDistance,
                    min = 1000,
                    max = 32000,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.visibleDistance = val
                        BJI.Tx.config.env("visibleDistance", val)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end, }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.shadowDistance)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetshadowDistance",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("shadowDistance")
                    end
                }):slider({
                    id = "shadowDistance",
                    type = "int",
                    value = BJI.Managers.Env.Data.shadowDistance,
                    min = 1000,
                    max = 12800,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.shadowDistance = val
                        BJI.Tx.config.env("shadowDistance", BJI.Managers.Env.Data.shadowDistance)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.shadowSoftness)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetshadowSoftness",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("shadowSoftness")
                    end
                }):slider({
                    id = "shadowSoftness",
                    type = "float",
                    value = BJI.Managers.Env.Data.shadowSoftness,
                    min = 0,
                    max = 50,
                    precision = 1,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.shadowSoftness = val
                        BJI.Tx.config.env("shadowSoftness", BJI.Managers.Env.Data.shadowSoftness)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.shadowSplits)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetshadowSplits",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("shadowSplits")
                    end
                }):slider({
                    id = "shadowSplits",
                    type = "int",
                    value = BJI.Managers.Env.Data.shadowSplits,
                    min = 1,
                    max = 4,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.shadowSplits = val
                        BJI.Tx.config.env("shadowSplits", BJI.Managers.Env.Data.shadowSplits)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.shadowTexSize) end,
            function()
                LineBuilder():btnIcon({
                    id = "resetshadowTexSize",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("shadowTexSize")
                    end
                }):slider({
                    id = "shadowTexSize",
                    type = "int",
                    value = BJI.Managers.Env.Data.shadowTexSizeInput,
                    min = 1, -- 2 ^ (1 + 4) = 32
                    max = 7, -- 2 ^ (7 + 4) = 2048
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    renderFormat = string.var("%d (x{1})", { BJI.Managers.Env.Data.shadowTexSize }),
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.shadowTexSizeInput = val
                        val = 2 ^ (val + 4)
                        if val >= 32 and val <= 2048 then
                            BJI.Managers.Env.Data.shadowTexSize = val
                            BJI.Tx.config.env("shadowTexSize", BJI.Managers.Env.Data.shadowTexSize)
                            BJI.Managers.Env.forceUpdate()
                        end
                    end
                }):build()
            end
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.shadowLogWeight)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetshadowLogWeight",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("shadowLogWeight")
                    end
                }):slider({
                    id = "shadowLogWeight",
                    type = "float",
                    value = BJI.Managers.Env.Data.shadowLogWeight,
                    min = 0,
                    max = .99,
                    precision = 2,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.shadowLogWeight = val
                        BJI.Tx.config.env("shadowLogWeight", BJI.Managers.Env.Data.shadowLogWeight)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addSeparator():build()
    ColumnsBuilder("EnvSunSettingsDayNight", { W.labelsDayWidth, -1, W.labelsNightWidth, -1 }):addRow({
        cells = {
            function()
                LineLabel(W.labels.day)
            end,
            nil,
            function()
                LineLabel(W.labels.night)
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.dayScale)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.dayScale",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.dayScale")
                        BJI.Tx.config.env("skyNight.nightScale")
                    end
                }):slider({
                    id = "skyDay.dayScale",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyDay.dayScale,
                    min = .01,
                    max = .99,
                    precision = 2,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    renderFormat = string.var("%.2f ({1})",
                        { BJI.Utils.Common.PrettyDelay(BJI.Managers.Env.Data.dayLength *
                            BJI.Managers.Env.Data.skyDay.dayScale) }),
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.dayScale = val
                        BJI.Managers.Env.Data.skyNight.nightScale = 1 - val
                        BJI.Tx.config.env("skyDay.dayScale", BJI.Managers.Env.Data.skyDay.dayScale)
                        BJI.Tx.config.env("skyNight.nightScale", BJI.Managers.Env.Data.skyNight.nightScale)
                    end
                }):build()
            end,
            function()
                LineLabel(W.labels.nightScale)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetnightScale",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyNight.nightScale")
                        BJI.Tx.config.env("skyDay.dayScale")
                    end
                }):slider({
                    id = "skyNight.nightScale",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyNight.nightScale,
                    min = .01,
                    max = .99,
                    precision = 2,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    renderFormat = string.var("%.2f ({1})",
                        { BJI.Utils.Common.PrettyDelay(BJI.Managers.Env.Data.dayLength *
                            BJI.Managers.Env.Data.skyNight.nightScale) }),
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyNight.nightScale = val
                        BJI.Managers.Env.Data.skyDay.dayScale = 1 - val
                        BJI.Tx.config.env("skyNight.nightScale", BJI.Managers.Env.Data.skyNight.nightScale)
                        BJI.Tx.config.env("skyDay.dayScale", BJI.Managers.Env.Data.skyDay.dayScale)
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.brightness)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.brightness",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.brightness")
                    end
                }):slider({
                    id = "skyDay.brightness",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyDay.brightness,
                    min = -1,
                    max = 100,
                    precision = 1,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.brightness = val
                        BJI.Tx.config.env("skyDay.brightness", BJI.Managers.Env.Data.skyDay.brightness)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
            function()
                LineLabel(W.labels.brightness)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyNight.brightness",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyNight.brightness")
                    end
                }):slider({
                    id = "skyNight.brightness",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyNight.brightness,
                    min = -1,
                    max = 100,
                    precision = 1,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyNight.brightness = val
                        BJI.Tx.config.env("skyNight.brightness", BJI.Managers.Env.Data.skyNight.brightness)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.sunAzimuthOverride)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.sunAzimuthOverride",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.sunAzimuthOverride")
                    end
                }):slider({
                    id = "skyDay.sunAzimuthOverride",
                    type = "int",
                    value = BJI.Managers.Env.Data.skyDay.sunAzimuthOverride,
                    min = 1,
                    max = 360,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.sunAzimuthOverride = val
                        BJI.Tx.config.env("skyDay.sunAzimuthOverride", BJI.Managers.Env.Data.skyDay.sunAzimuthOverride)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
            function()
                LineLabel(W.labels.moonAzimuth)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyNight.moonAzimuth",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyNight.moonAzimuth")
                    end
                }):slider({
                    id = "skyNight.moonAzimuth",
                    type = "int",
                    value = BJI.Managers.Env.Data.skyNight.moonAzimuth,
                    min = 0,
                    max = 360,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyNight.moonAzimuth = val
                        BJI.Tx.config.env("skyNight.moonAzimuth", BJI.Managers.Env.Data.skyNight.moonAzimuth)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.sunSize)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.sunSize",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.sunSize")
                    end
                }):slider({
                    id = "skyDay.sunSize",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyDay.sunSize,
                    min = 0,
                    max = 100,
                    pecision = 2,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.sunSize = val
                        BJI.Tx.config.env("skyDay.sunSize", BJI.Managers.Env.Data.skyDay.sunSize)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
            function()
                LineLabel(W.labels.moonScale)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyNight.moonScale",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyNight.moonScale")
                    end
                }):slider({
                    id = "skyNight.moonScale",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyNight.moonScale,
                    min = 0,
                    max = 2,
                    precision = 2,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyNight.moonScale = val
                        BJI.Tx.config.env("skyNight.moonScale", BJI.Managers.Env.Data.skyNight.moonScale)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.skyBrightness)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.skyBrightness",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.skyBrightness")
                    end
                }):slider({
                    id = "skyDay.skyBrightness",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyDay.skyBrightness,
                    min = 0,
                    max = 100,
                    precision = 1,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.skyBrightness = val
                        BJI.Tx.config.env("skyDay.skyBrightness", BJI.Managers.Env.Data.skyDay.skyBrightness)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
            function()
                LineLabel(W.labels.moonElevation)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyNight.moonElevation",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyNight.moonElevation")
                    end
                }):slider({
                    id = "skyNight.moonElevation",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyNight.moonElevation,
                    min = 10,
                    max = 80,
                    precision = 1,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyNight.moonElevation = val
                        BJI.Tx.config.env("skyNight.moonElevation", BJI.Managers.Env.Data.skyNight.moonElevation)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.rayleighScattering)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.rayleighScattering",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.rayleighScattering")
                    end
                }):slider({
                    id = "skyDay.rayleighScattering",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyDay.rayleighScattering,
                    min = -.002,
                    max = .3,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.rayleighScattering = val
                        BJI.Tx.config.env("skyDay.rayleighScattering", BJI.Managers.Env.Data.skyDay.rayleighScattering)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.exposure)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.exposure",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.exposure")
                    end
                }):slider({
                    id = "skyDay.exposure",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyDay.exposure,
                    min = .001,
                    max = 3,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.exposure = val
                        BJI.Tx.config.env("skyDay.exposure", BJI.Managers.Env.Data.skyDay.exposure)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.flareScale)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.flareScale",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.flareScale")
                    end
                }):slider({
                    id = "skyDay.flareScale",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyDay.flareScale,
                    min = 0,
                    max = 10,
                    precision = 1,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.flareScale = val
                        BJI.Tx.config.env("skyDay.flareScale", BJI.Managers.Env.Data.skyDay.flareScale)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.occlusionScale)
            end,
            function()
                LineBuilder():btnIcon({
                    id = "resetskyDay.occlusionScale",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onClick = function()
                        BJI.Tx.config.env("skyDay.occlusionScale")
                    end
                }):slider({
                    id = "skyDay.occlusionScale",
                    type = "float",
                    value = BJI.Managers.Env.Data.skyDay.occlusionScale,
                    min = 0,
                    max = 1.6,
                    precision = 1,
                    disabled = not BJI.Managers.Env.Data.controlSun,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.skyDay.occlusionScale = val
                        BJI.Tx.config.env("skyDay.occlusionScale", BJI.Managers.Env.Data.skyDay.occlusionScale)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end,
        }
    }):build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
