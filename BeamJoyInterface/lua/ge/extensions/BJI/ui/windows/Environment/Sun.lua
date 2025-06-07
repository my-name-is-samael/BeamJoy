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

        reset = "",
        resetAll = "",
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
    presets = require("ge/extensions/utils/EnvironmentUtils").timePresets(),

    cachedShared = {},
}

local function updateLabels()
    Table(W.labels):forEach(function(_, k)
        W.labels[k] = BJI.Managers.Lang.get(string.var("environment.{1}", { k }))
    end)
    Table(W.labelsPresets):forEach(function(_, k)
        W.labelsPresets[k] = BJI.Managers.Lang.get(string.var("presets.time.{1}", { k }))
    end)
    W.labels.reset = BJI.Managers.Lang.get("common.buttons.reset")
    W.labels.resetAll = BJI.Managers.Lang.get("common.buttons.resetAll")

    W.labelsCommonWidth = W.KEYS.common:reduce(function(acc, k)
        local l = W.labels[k]
        local w = BJI.Utils.UI.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)

    W.labelsDayWidth = W.KEYS.day:reduce(function(acc, k)
        local l = W.labels[k]
        local w = BJI.Utils.UI.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)

    W.labelsNightWidth = W.KEYS.night:reduce(function(acc, k)
        local l = W.labels[k]
        local w = BJI.Utils.UI.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body()
    LineBuilder()
        :icon({
            icon = BJI.Utils.Icon.ICONS.simobject_sun,
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
                    label = W.labels.resetAll,
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
                BJI.Utils.UI.DrawTimePlayPauseButtons("envSunTimePlay", true,
                    not BJI.Managers.Env.Data.controlSun)
                W.presets:reduce(function(line, p)
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

    local ranges = require("ge/extensions/utils/EnvironmentUtils").numericData()
    local function addSliderRow(rowData)
        local finalParent1 = BJI.Managers.Env.Data
        local finalKey1 = rowData[1]
        if finalKey1:find("%.") then
            local parts = tostring(finalKey1):split2(".")
            finalParent1 = finalParent1[parts[1]]
            finalKey1 = parts[2]
        end
        local finalParent2 = BJI.Managers.Env.Data
        local finalKey2 = rowData[2]
        if finalKey2 and finalKey2:find("%.") then
            local parts = tostring(finalKey2):split2(".")
            finalParent2 = finalParent2[parts[1]]
            finalKey2 = parts[2]
        end
        return {
            cells = {
                function() LineLabel(W.labels[finalKey1]) end,
                function()
                    LineBuilder():btnIcon({
                        id = "reset" .. rowData[1],
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        tooltip = W.labels.reset,
                        onClick = function()
                            BJI.Tx.config.env(rowData[1])
                        end
                    }):slider({
                        id = rowData[1],
                        type = ranges[finalKey1].type,
                        value = tonumber(finalParent1[finalKey1]) or 0,
                        min = ranges[finalKey1].min,
                        max = ranges[finalKey1].max,
                        precision = ranges[finalKey1].precision,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        onUpdate = function(val)
                            finalParent1[finalKey1] = val
                            BJI.Managers.Env.forceUpdate()
                        end,
                    }):build()
                end,
                finalKey2 and function() LineLabel(W.labels[finalKey2]) end or nil,
                finalKey2 and function()
                    LineBuilder():btnIcon({
                        id = "reset" .. rowData[2],
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        tooltip = W.labels.reset,
                        onClick = function()
                            BJI.Tx.config.env(rowData[2])
                        end
                    }):slider({
                        id = rowData[2],
                        type = ranges[finalKey2].type,
                        value = tonumber(finalParent2[finalKey2]) or 0,
                        min = ranges[finalKey2].min,
                        max = ranges[finalKey2].max,
                        precision = ranges[finalKey2].precision,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        onUpdate = function(val)
                            finalParent2[finalKey2] = val
                            BJI.Managers.Env.forceUpdate()
                        end,
                    }):build()
                end or nil,
            }
        }
    end
    ColumnsBuilder("EnvSunSettingsCommon", { W.labelsCommonWidth, -1, -1 })
        :addRow({
            cells = {
                function() LineLabel(W.labels.ToD) end,
                function()
                    LineBuilder():btnIcon({
                        id = "resetToD",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        tooltip = W.labels.reset,
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
                            local newToD = math.round((val + .5) % 1, 6)
                            BJI.Managers.Env.Data.ToD = newToD
                            BJI.Managers.Env.forceUpdate()
                            if BJI.Managers.Env.Data.timePlay then
                                BJI.Managers.Env.ToDEdit = true
                                BJI.Managers.Async.removeTask("EnvToDManualChange")
                                BJI.Managers.Async.delayTask(function()
                                    if newToD ~= BJI.Managers.Env.Data.ToD then
                                        BJI.Tx.config.env("ToD", newToD)
                                    end
                                end, 1000, "EnvToDManualChange")
                            else
                                BJI.Tx.config.env("ToD", newToD)
                            end
                        end
                    }):build()
                end,
                function()
                    LineLabel(BJI.Utils.UI.PrettyTime(BJI.Managers.Env.Data.ToD))
                end
            }
        })
        :addRow({
            cells = {
                function() LineLabel(W.labels.dayLength) end,
                function()
                    LineBuilder():btnIcon({
                        id = "resetdayLength",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        tooltip = W.labels.reset,
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
                            BJI.Managers.Env.Data.skyDay.dayScale = .5
                            BJI.Managers.Env.Data.skyNight.nightScale = .5
                        end,
                    }):btn({
                        id = "dayLength20min",
                        label = "20m",
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        onClick = function()
                            BJI.Managers.Env.Data.dayLength = 1200
                        end,
                    }):btn({
                        id = "dayLength1hour",
                        label = "1h",
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        onClick = function()
                            BJI.Managers.Env.Data.dayLength = 3600
                        end,
                    }):text(BJI.Utils.UI.PrettyDelay(BJI.Managers.Env.Data.dayLength))
                        :build()
                end
            }
        })
        :addRow(addSliderRow({ "visibleDistance" }))
        :addRow(addSliderRow({ "shadowDistance" }))
        :addRow(addSliderRow({ "shadowSoftness" }))
        :addRow(addSliderRow({ "shadowSplits" }))
        :addRow({
            cells = {
                function() LineLabel(W.labels.shadowTexSize) end,
                function()
                    LineBuilder():btnIcon({
                        id = "resetshadowTexSize",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        tooltip = W.labels.reset,
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
                                BJI.Managers.Env.forceUpdate()
                            end
                        end
                    }):build()
                end
            }
        })
        :addRow(addSliderRow({ "shadowLogWeight" }))
        :addSeparator():build()
    ColumnsBuilder("EnvSunSettingsDayNight", { W.labelsDayWidth, -1, W.labelsNightWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineLabel(W.labels.day)
                end,
                nil,
                function()
                    LineLabel(W.labels.night)
                end,
            }
        })
        :addRow({
            cells = {
                function()
                    LineLabel(W.labels.dayScale)
                end,
                function()
                    LineBuilder():btnIcon({
                        id = "resetskyDay.dayScale",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        tooltip = W.labels.reset,
                        onClick = function()
                            BJI.Tx.config.env("skyDay.dayScale")
                            BJI.Tx.config.env("skyNight.nightScale")
                        end
                    }):slider({
                        id = "skyDay.dayScale",
                        type = "int",
                        value = math.round(BJI.Managers.Env.Data.skyDay.dayScale * 100),
                        min = 1,
                        max = 99,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        renderFormat = string.var("%d%% ({1})",
                            { BJI.Utils.UI.PrettyDelay(BJI.Managers.Env.Data.dayLength *
                                BJI.Managers.Env.Data.skyDay.dayScale) }),
                        onUpdate = function(val)
                            BJI.Managers.Env.Data.skyDay.dayScale = math.round(val / 100, 2)
                            BJI.Managers.Env.Data.skyNight.nightScale = 1 - BJI.Managers.Env.Data.skyDay.dayScale
                        end
                    }):build()
                end,
                function()
                    LineLabel(W.labels.nightScale)
                end,
                function()
                    LineBuilder():btnIcon({
                        id = "resetnightScale",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        tooltip = W.labels.reset,
                        onClick = function()
                            BJI.Tx.config.env("skyNight.nightScale")
                            BJI.Tx.config.env("skyDay.dayScale")
                        end
                    }):slider({
                        id = "skyNight.nightScale",
                        type = "int",
                        value = math.round(BJI.Managers.Env.Data.skyNight.nightScale * 100),
                        min = 1,
                        max = 99,
                        disabled = not BJI.Managers.Env.Data.controlSun,
                        renderFormat = string.var("%d%% ({1})",
                            { BJI.Utils.UI.PrettyDelay(BJI.Managers.Env.Data.dayLength *
                                BJI.Managers.Env.Data.skyNight.nightScale) }),
                        onUpdate = function(val)
                            BJI.Managers.Env.Data.skyNight.nightScale = math.round(val / 100, 2)
                            BJI.Managers.Env.Data.skyDay.dayScale = 1 - BJI.Managers.Env.Data.skyNight.nightScale
                        end
                    }):build()
                end,
            }
        })
        :addRow(addSliderRow({ "skyDay.brightness", "skyNight.brightness" }))
        :addRow(addSliderRow({ "skyDay.sunAzimuthOverride", "skyNight.moonAzimuth" }))
        :addRow(addSliderRow({ "skyDay.sunSize", "skyNight.moonScale" }))
        :addRow(addSliderRow({ "skyDay.skyBrightness", "skyNight.moonElevation" }))
        :addRow(addSliderRow({ "skyDay.rayleighScattering" }))
        :addRow(addSliderRow({ "skyDay.exposure" }))
        :addRow(addSliderRow({ "skyDay.flareScale" }))
        :addRow(addSliderRow({ "skyDay.occlusionScale" }))
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
