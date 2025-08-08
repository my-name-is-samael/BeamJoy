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
    presets = require("ge/extensions/utils/EnvironmentUtils").timePresets(),

    cachedShared = {},
}
--- gc prevention
local nextValue, parent, child, ranges

local function updateLabels()
    Table(W.labels):forEach(function(_, k)
        W.labels[k] = BJI_Lang.get(string.var("environment.{1}", { k }))
    end)
    Table(W.labelsPresets):forEach(function(_, k)
        W.labelsPresets[k] = BJI_Lang.get(string.var("presets.time.{1}", { k }))
    end)
    W.labels.reset = BJI_Lang.get("common.buttons.reset")
    W.labels.resetAll = BJI_Lang.get("common.buttons.resetAll")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    ranges = require("ge/extensions/utils/EnvironmentUtils").numericData()
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function body()
    Icon(BJI.Utils.Icon.ICONS.simobject_sun, { big = true })

    if BeginTable("BJIEnvSunHead", {
            { label = "##env-sun-head-left-labels" },
            { label = "##env-sun-head-left-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.controlSun)
        TableNextColumn()
        if IconButton("controlSun", BJI_Env.Data.controlSun and
                BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { btnStyle = BJI_Env.Data.controlSun and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
            BJI_Env.Data.controlSun = not BJI_Env.Data.controlSun
            BJI_Tx_config.env("controlSun", BJI_Env.Data.controlSun)
        end
        SameLine()
        if Button("resetSun", W.labels.resetAll, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                disabled = not BJI_Env.Data.controlSun }) then
            BJI_Tx_config.env("reset", BJI.CONSTANTS.ENV_TYPES.SUN)
        end

        TableNewRow()
        Text(W.labels.timePlay)
        TableNextColumn()
        BJI.Utils.UI.DrawTimePlayPauseButtons("envSunTimePlay", true,
            not BJI_Env.Data.controlSun)
        W.presets:forEach(function(p)
            SameLine()
            if Button("timepreset-" .. p.label, W.labelsPresets[p.label],
                    { disabled = not BJI_Env.Data.controlSun }) then
                BJI_Env.Data.ToD = p.ToD
                BJI_Tx_config.env("ToD", p.ToD)
            end
        end)

        TableNewRow()
        TableNextColumn()

        EndTable()
    end

    if BeginTable("BJIEnvSunTime", {
            { label = "##env-sun-time-labels" },
            { label = "##env-sun-time-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##env-sun-time-third", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.ToD)
        TableNextColumn()
        if IconButton("resetToD", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI_Env.Data.controlSun }) then
            BJI_Tx_config.env("ToD")
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderFloatPrecision("ToD", (BJI_Env.Data.ToD + .5) % 1, 0, 1,
            { disabled = not BJI_Env.Data.controlSun, step = .01, stepFast = .05 })
        if nextValue then
            local newToD = math.round((nextValue + .5) % 1, 6)
            BJI_Env.Data.ToD = newToD
            BJI_Env.forceUpdate()
            if BJI_Env.Data.timePlay then
                BJI_Env.ToDEdit = true
                BJI_Async.removeTask("EnvToDManualChange")
                BJI_Async.delayTask(function()
                    if newToD ~= BJI_Env.Data.ToD then
                        BJI_Tx_config.env("ToD", newToD)
                    end
                end, 1000, "EnvToDManualChange")
            else
                BJI_Tx_config.env("ToD", newToD)
            end
        end
        TableNextColumn()
        Text(BJI.Utils.UI.PrettyTime(BJI_Env.Data.ToD))

        TableNewRow()
        Text(W.labels.dayLength)
        TableNextColumn()
        if IconButton("resetDayLength", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI_Env.Data.controlSun }) then
            BJI_Tx_config.env("dayLength")
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderIntPrecision("dayLength", BJI_Env.Data.dayLength, 60, 86400,
            { disabled = not BJI_Env.Data.controlSun, step = 60, stepFast = 600 })
        if nextValue then BJI_Env.Data.dayLength = nextValue end
        TableNextColumn()
        if Button("dayLengthRealtime", W.labels.realtime,
                { disabled = not BJI_Env.Data.controlSun }) then
            BJI_Env.Data.dayLength = 86400
            BJI_Env.Data.skyDay.dayScale = .5
            BJI_Env.Data.skyNight.nightScale = .5
        end
        SameLine()
        if Button("dayLength20min", "20m", { disabled = not BJI_Env.Data.controlSun }) then
            BJI_Env.Data.dayLength = 1200
        end
        SameLine()
        if Button("dayLength1hour", "1h", { disabled = not BJI_Env.Data.controlSun }) then
            BJI_Env.Data.dayLength = 3600
        end
        SameLine()
        Text(BJI.Utils.UI.PrettyDelay(BJI_Env.Data.dayLength))

        Table({ "visibleDistance", "shadowDistance", "shadowSoftness", "shadowSplits", "shadowLogWeight" }):forEach(function(
            k)
            TableNewRow()
            Text(W.labels[k])
            TableNextColumn()
            if IconButton("reset-" .. tostring(k), BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI_Env.Data.controlSun }) then
                BJI_Tx_config.env(k)
            end
            TooltipText(W.labels.reset)
            SameLine()
            if ranges[k].type == "int" then
                nextValue = SliderIntPrecision("env-" .. k, tonumber(BJI_Env.Data[k]) or 0, ranges[k].min,
                    ranges[k].max, {
                        disabled = not BJI_Env.Data.controlSun,
                        step = ranges[k].step,
                        stepFast = ranges[k].stepFast
                    })
            else
                nextValue = SliderFloatPrecision("env-" .. k, tonumber(BJI_Env.Data[k]) or 0, ranges[k].min,
                    ranges[k].max, {
                        disabled = not BJI_Env.Data.controlSun,
                        precision = ranges[k].precision,
                        step = ranges[k].step,
                        stepFast = ranges[k].stepFast
                    })
            end
            if nextValue then
                BJI_Env.Data[k] = nextValue
                BJI_Env.forceUpdate()
            end
        end)

        TableNewRow()
        Text(W.labels.shadowTexSize)
        TableNextColumn()
        if IconButton("resetShadowTexSize", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI_Env.Data.controlSun }) then
            BJI_Tx_config.env("shadowTexSize")
        end
        TooltipText()
        SameLine()
        nextValue = SliderInt("env-shadowTexSize", BJI_Env.Data.shadowTexSizeInput, 1, 7,
            {
                disabled = not BJI_Env.Data.controlSun,
                formatRender = string.var("%d (x{1})",
                    { BJI_Env.Data.shadowTexSize })
            })
        if nextValue then
            BJI_Env.Data.shadowTexSizeInput = nextValue
            nextValue = math.clamp(2 ^ (nextValue + 4), 32, 2048)
            if nextValue ~= BJI_Env.Data.shadowTexSize then
                BJI_Env.Data.shadowTexSize = nextValue
                BJI_Env.forceUpdate()
            end
        end

        EndTable()
    end
    Separator()

    if BeginTable("BJIEnvSunDayNight", {
            { label = "##env-sun-day-labels" },
            { label = "##env-sun-day-inputs",   flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##env-sun-night-labels" },
            { label = "##env-sun-night-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.day)
        TableNextColumn()
        TableNextColumn()
        Text(W.labels.night)

        TableNewRow()
        Text(W.labels.dayScale)
        TableNextColumn()
        if IconButton("resetskyDay.dayScale", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI_Env.Data.controlSun }) then
            BJI_Tx_config.env("skyDay.dayScale")
            BJI_Tx_config.env("skyNight.nightScale")
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderIntPrecision("skyDay.dayScale", math.round(BJI_Env.Data.skyDay.dayScale * 100), 1,
            99,
            {
                disabled = not BJI_Env.Data.controlSun,
                step = 1,
                stepFast = 5,
                formatRender = string.var("%d%% ({1})", { BJI.Utils.UI.PrettyDelay(BJI_Env.Data.dayLength *
                    BJI_Env.Data.skyDay.dayScale) })
            })
        if nextValue then
            BJI_Env.Data.skyDay.dayScale = math.round(nextValue / 100, 2)
            BJI_Env.Data.skyNight.nightScale = 1 - BJI_Env.Data.skyDay.dayScale
        end
        TableNextColumn()
        Text(W.labels.nightScale)
        TableNextColumn()
        if IconButton("resetnightScale", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI_Env.Data.controlSun }) then
            BJI_Tx_config.env("skyNight.nightScale")
            BJI_Tx_config.env("skyDay.dayScale")
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderIntPrecision("skyNight.nightScale", math.round(BJI_Env.Data.skyNight.nightScale * 100),
            1, 99,
            {
                disabled = not BJI_Env.Data.controlSun,
                step = 1,
                stepFast = 5,
                formatRender = string.var("%d%% ({1})", { BJI.Utils.UI.PrettyDelay(BJI_Env.Data.dayLength *
                    BJI_Env.Data.skyNight.nightScale) })
            })
        if nextValue then
            BJI_Env.Data.skyNight.nightScale = math.round(nextValue / 100, 2)
            BJI_Env.Data.skyDay.dayScale = 1 - BJI_Env.Data.skyNight.nightScale
        end

        Table({
            { "skyDay.brightness",         "skyNight.brightness" },
            { "skyDay.sunAzimuthOverride", "skyNight.moonAzimuth" },
            { "skyDay.sunSize",            "skyNight.moonScale" },
            { "skyDay.skyBrightness",      "skyNight.moonElevation" },
            { "skyDay.rayleighScattering" },
            { "skyDay.exposure" },
            { "skyDay.flareScale" },
            { "skyDay.occlusionScale" }
        }):forEach(function(el)
            for i = 1, 2 do
                if i == 1 or el[i] then
                    if i == 1 then
                        TableNewRow()
                    else
                        TableNextColumn()
                    end
                    parent = BJI_Env.Data[el[i]:split2(".")[1]]
                    child = el[i]:split2(".")[2]
                    Text(W.labels[child])
                    TableNextColumn()
                    if IconButton("reset" .. el[i], BJI.Utils.Icon.ICONS.refresh,
                            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = not BJI_Env.Data.controlSun }) then
                        BJI_Tx_config.env(el[i])
                    end
                    TooltipText(W.labels.reset)
                    SameLine()
                    if ranges[child].type == "int" then
                        nextValue = SliderIntPrecision(el[i], tonumber(parent[child]) or 0, ranges[child].min,
                            ranges[child].max, {
                                disabled = not BJI_Env.Data.controlSun,
                                step = ranges[child].step,
                                stepFast = ranges[child].stepFast
                            })
                    else
                        nextValue = SliderFloatPrecision(el[i], tonumber(parent[child]) or 0, ranges[child].min,
                            ranges[child].max,
                            {
                                disabled = not BJI_Env.Data.controlSun,
                                precision = ranges[child].precision,
                                step = ranges[child].step,
                                stepFast = ranges[child].stepFast
                            })
                    end
                    if nextValue then
                        parent[child] = nextValue
                        BJI_Env.forceUpdate()
                    end
                end
            end
        end)

        EndTable()
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
