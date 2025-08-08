local W = {
    KEYS = Table({ "controlSpeed", "simSpeed" }),

    ---@type table<string, string>
    labels = Table(), -- auto-alimented
    presets = require("ge/extensions/utils/EnvironmentUtils").speedPresets(),
}
--- gc prevention
local nextValue, ranges

local function updateLabels()
    W.KEYS:forEach(function(k)
        W.labels[k] = string.var("{1} :", { BJI_Lang.get(string.var("environment.{1}", { k })) })
    end)

    W.presets:forEach(function(p)
        W.labels[p.key] = string.var("{1} (x{2})",
            { BJI_Lang.get(string.var("presets.speed.{1}", { p.key })), p.value })
    end)

    W.labels.reset = BJI_Lang.get("common.buttons.reset")
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
    Icon(BJI.Utils.Icon.ICONS.skip_next, { big = true })

    if BeginTable("BJIEnvSpeed", {
            { label = "##env-speed-labels" },
            { label = "##env-speed-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.controlSpeed)
        TableNextColumn()
        if IconButton("controlSpeed", BJI_Env.Data.controlSimSpeed and
                BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { btnStyle = BJI_Env.Data.controlSimSpeed and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
            BJI_Env.Data.controlSimSpeed = not BJI_Env.Data.controlSimSpeed
        end

        TableNewRow()
        Text(W.labels.simSpeed)
        TableNextColumn()
        if IconButton("resetsimSpeed", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI_Env.Data.controlSimSpeed }) then
            BJI_Tx_config.env("simSpeed")
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderFloatPrecision("simSpeed", BJI_Env.Data.simSpeed, ranges.simSpeed.min,
            ranges.simSpeed.max,
            {
                disabled = not BJI_Env.Data.controlSimSpeed,
                precision = ranges.simSpeed.precision,
                step = ranges.simSpeed.step,
                stepFast = ranges.simSpeed.stepFast
            })
        if nextValue then
            BJI_Env.Data.simSpeed = nextValue
            BJI_Env.forceUpdate()
        end

        EndTable()
    end

    if BJI_Env.Data.controlSimSpeed then
        W.presets:forEach(function(p, i)
            if i % 3 ~= 1 then SameLine() end
            if Button(p.key, W.labels[p.key], { disabled = BJI_Env.Data.simSpeed == p.value,
                    btnStyle = p.default and BJI.Utils.Style.BTN_PRESETS.SUCCESS or nil }) then
                BJI_Tx_config.env("simSpeed", p.value) -- no client assign to sync all players on change
            end
        end)
    end
end


W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
