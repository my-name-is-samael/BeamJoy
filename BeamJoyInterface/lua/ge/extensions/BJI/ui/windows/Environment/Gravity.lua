local W = {
    KEYS = Table({ "controlGravity", "gravityRate" }),

    ---@type table<string, string>
    labels = Table(), -- auto-alimented
    presets = require("ge/extensions/utils/EnvironmentUtils").gravityPresets(),
}
--- gc prevention
local nextValue, ranges

local function updateLabels()
    W.KEYS:forEach(function(k)
        W.labels[k] = string.var("{1} :", { BJI.Managers.Lang.get(string.var("environment.{1}", { k })) })
    end)

    W.presets:forEach(function(p)
        W.labels[p.key] = string.var("{1} ({2})",
            { BJI.Managers.Lang.get(string.var("presets.gravity.{1}", { p.key })), p.value })
    end)

    W.labels.reset = BJI.Managers.Lang.get("common.buttons.reset")
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
    Icon(BJI.Utils.Icon.ICONS.fitness_center, { big = true })

    if BeginTable("BJIEnvGravity", {
            { label = "##env-gravity-labels" },
            { label = "##env-gravity-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.controlGravity)
        TableNextColumn()
        if IconButton("controlGravity", BJI.Managers.Env.Data.controlGravity and
                BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { btnStyle = BJI.Managers.Env.Data.controlGravity and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
            BJI.Managers.Env.Data.controlGravity = not BJI.Managers.Env.Data.controlGravity
        end

        TableNewRow()
        Text(W.labels.gravityRate)
        TableNextColumn()
        if IconButton("resetgravityRate", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlGravity }) then
            BJI.Tx.config.env("gravityRate")
        end
        TooltipText(W.labels.reset)
        SameLine()
        nextValue = SliderFloatPrecision("gravityRate", BJI.Managers.Env.Data.gravityRate, ranges.gravityRate.min,
            ranges.gravityRate.max, {
                disabled = not BJI.Managers.Env.Data.controlGravity,
                precision = ranges.gravityRate.precision,
                step = ranges.gravityRate.step,
                stepFast = ranges.gravityRate.stepFast
            })
        if nextValue then
            BJI.Managers.Env.Data.gravityRate = nextValue
            BJI.Managers.Env.forceUpdate()
        end

        EndTable()
    end

    if BJI.Managers.Env.Data.controlGravity then
        W.presets:forEach(function(p, i)
            if i % 4 ~= 1 then SameLine() end
            if Button(p.key, W.labels[p.key], { disabled = BJI.Managers.Env.Data.gravityRate == p.value,
                    btnStyle = p.default and BJI.Utils.Style.BTN_PRESETS.SUCCESS or nil }) then
                BJI.Tx.config.env("gravityRate", p.value) -- no client assign to sync all players on change
            end
        end)
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
