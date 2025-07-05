local W = {
    KEYS = Table({ "controlWeather", "fogDensity", "fogColor", "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight",
        "cloudCover", "cloudSpeed", "cloudExposure", "rainDrops", "dropSize", "dropMinSpeed",
        "dropMaxSpeed", "precipType" }),

    ---@type table<string, string>
    labels = Table(), -- auto-alimented
    cols = Table(),
}
--- gc prevention
local nextValue, ranges

local function updateLabels()
    W.KEYS:forEach(function(k)
        W.labels[k] = string.var("{1} :", { BJI.Managers.Lang.get(string.var("environment.{1}", { k })) })
        if k:startswith("cloud") then
            local k2 = k .. "One"
            W.labels[k2] = string.var("{1} :", { BJI.Managers.Lang.get(string.var("environment.{1}", { k2 })) })
        end
    end)

    Table(BJI.Managers.Env.PRECIP_TYPES):forEach(function(k)
        W.labels[k] = BJI.Managers.Lang.get(string.var("presets.precipType.{1}", { k }))
    end)

    W.labels.reset = BJI.Managers.Lang.get("common.buttons.reset")
    W.labels.resetAll = BJI.Managers.Lang.get("common.buttons.resetAll")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    ranges = require("ge/extensions/utils/EnvironmentUtils").numericData()
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body()
    Icon(BJI.Utils.Icon.ICONS.simobject_cloud_layer, { big = true })

    if BeginTable("BJIEnvWeather", {
            { label = "##env-weather-left-labels" },
            { label = "##env-weather-left-inputs",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##env-weather-right-labels" },
            { label = "##env-weather-right-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.controlWeather)
        TableNextColumn()
        if IconButton("controlWeather", BJI.Managers.Env.Data.controlWeather and
                BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { btnStyle = BJI.Managers.Env.Data.controlWeather and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
            BJI.Managers.Env.Data.controlWeather = not BJI.Managers.Env.Data.controlWeather
        end
        SameLine()
        if Button("resetWeather", W.labels.resetAll, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                disabled = not BJI.Managers.Env.Data.controlWeather }) then
            BJI.Tx.config.env("reset", BJI.CONSTANTS.ENV_TYPES.WEATHER)
        end

        TableNewRow()
        Text(W.labels.fogDensity)
        TableNextColumn()
        if IconButton("resetfogDensity", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlWeather }) then
            BJI.Tx.config.env("fogDensity")
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderFloatPrecision("fogDensity", BJI.Managers.Env.Data.fogDensity, ranges.fogDensity.min,
            ranges.fogDensity.max,
            {
                disabled = not BJI.Managers.Env.Data.controlWeather,
                precision = ranges.fogDensity.precision,
                step = ranges.fogDensity.step,
                stepFast = ranges.fogDensity.stepFast
            })
        if nextValue then
            BJI.Managers.Env.Data.fogDensity = nextValue
            BJI.Managers.Env.forceUpdate()
        end
        TableNextColumn()
        Text(W.labels.fogColor)
        TableNextColumn()
        if IconButton("resetfogColor", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlWeather }) then
            BJI.Tx.config.env("fogColor")
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = ColorPicker("fogColor", ImVec4(Table(BJI.Managers.Env.Data.fogColor):clone():addAll({ 1 }):unpack()),
            { disabled = not BJI.Managers.Env.Data.controlWeather })
        if nextValue then
            BJI.Managers.Env.Data.fogColor = math.vec4ColorToStorage(nextValue)
            BJI.Managers.Env.Data.fogColor[4] = nil
            BJI.Managers.Env.forceUpdate()
        end

        Table({ "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight", "cloudCover", "cloudSpeed",
            "cloudExposure", "rainDrops", "dropSize", "dropMinSpeed", "dropMaxSpeed" }):forEach(function(k)
            TableNewRow()
            Text(W.labels[k])
            TableNextColumn()
            if IconButton("reset" .. k, BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not BJI.Managers.Env.Data.controlWeather }) then
                BJI.Tx.config.env(k)
            end
            TooltipText(W.labels.reset)
            SameLine()
            if ranges[k].type == "int" then
                nextValue = SliderIntPrecision(k, tonumber(BJI.Managers.Env.Data[k]) or 0, ranges[k].min, ranges[k].max,
                    {
                        disabled = not BJI.Managers.Env.Data.controlWeather,
                        step = ranges[k].step,
                        stepFast = ranges[k].stepFast
                    })
            else
                nextValue = SliderFloatPrecision(k, tonumber(BJI.Managers.Env.Data[k]) or 0, ranges[k].min,
                    ranges[k].max,
                    {
                        disabled = not BJI.Managers.Env.Data.controlWeather,
                        precision = ranges[k].precision,
                        step = ranges[k].step,
                        stepFast = ranges[k].stepFast
                    })
            end
            if nextValue then
                BJI.Managers.Env.Data[k] = nextValue
                BJI.Managers.Env.forceUpdate()
            end
            if k:startswith("cloud") then
                TableNextColumn()
                Text(W.labels[k .. "One"])
                TableNextColumn()
                if IconButton("reset" .. k, BJI.Utils.Icon.ICONS.refresh,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = not BJI.Managers.Env.Data.controlWeather }) then
                    BJI.Tx.config.env(k .. "One")
                end
                TooltipText(W.labels.reset)
                SameLine()
                if ranges[k].type == "int" then
                    nextValue = SliderIntPrecision(k, tonumber(BJI.Managers.Env.Data[k .. "One"]) or 0, ranges[k].min,
                        ranges[k].max,
                        {
                            disabled = not BJI.Managers.Env.Data.controlWeather,
                            step = ranges[k].step,
                            stepFast = ranges[k].stepFast
                        })
                else
                    nextValue = SliderFloatPrecision(k, tonumber(BJI.Managers.Env.Data[k .. "One"]) or 0, ranges[k].min,
                        ranges[k].max,
                        {
                            disabled = not BJI.Managers.Env.Data.controlWeather,
                            precision = ranges[k].precision,
                            step = ranges[k].step,
                            stepFast = ranges[k].stepFast
                        })
                end
                if nextValue then
                    BJI.Managers.Env.Data[k .. "One"] = nextValue
                    BJI.Managers.Env.forceUpdate()
                end
            end
        end)

        EndTable()
    end

    Text(W.labels.precipType)
    Table(BJI.Managers.Env.PRECIP_TYPES):forEach(function(p)
        SameLine()
        if Button(p, W.labels[p], { disabled = not BJI.Managers.Env.Data.controlWeather or
                BJI.Managers.Env.Data.precipType == p }) then
            BJI.Managers.Env.Data.precipType = p
            BJI.Managers.Env.forceUpdate()
        end
    end)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
