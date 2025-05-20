local W = {
    KEYS = Table({ "controlGravity", "gravityRate" }),

    ---@type table<string, string>
    labels = Table(), -- auto-alimented
    labelsWidth = 0,
    cols = Table(),
    presets = require("ge/extensions/utils/EnvironmentUtils").gravityPresets(),
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

    W.presets:forEach(function(p)
        W.labels[p.key] = string.var("{1} ({2})",
            { BJI.Managers.Lang.get(string.var("presets.gravity.{1}", { p.key })), p.value })
    end)
end

local function updateCols()
    local ranges = require("ge/extensions/utils/EnvironmentUtils").numericData()
    W.cols = Table({
        {
            function() LineLabel(W.labels.controlGravity) end,
            function()
                local line = LineBuilder()
                    :btnIconToggle({
                        id = "controlGravity",
                        state = BJI.Managers.Env.Data.controlGravity,
                        coloredIcon = true,
                        onClick = function()
                            BJI.Tx.config.env("controlGravity", not BJI.Managers.Env.Data.controlGravity)
                            BJI.Managers.Env.Data.controlGravity = not BJI.Managers.Env.Data.controlGravity
                        end,
                    })
                line:build()
            end
        },
        {
            function() LineLabel(W.labels.gravityRate) end,
            function()
                LineBuilder():btnIcon({
                    id = "resetgravityRate",
                    icon = ICONS.refresh,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = not BJI.Managers.Env.Data.controlGravity,
                    onClick = function()
                        BJI.Tx.config.env("gravityRate")
                    end
                }):slider({
                    id = "gravityRate",
                    type = ranges.gravityRate.type,
                    value = BJI.Managers.Env.Data.gravityRate,
                    min = ranges.gravityRate.min,
                    max = ranges.gravityRate.max,
                    precision = ranges.gravityRate.precision,
                    disabled = not BJI.Managers.Env.Data.controlGravity,
                    onUpdate = function(val)
                        BJI.Managers.Env.Data.gravityRate = val
                        BJI.Tx.config.env("gravityRate", val)
                        BJI.Managers.Env.forceUpdate()
                    end
                }):build()
            end
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

local function drawGravityPresets()
    W.presets:forEach(function(p)
        local value = math.round(p.value, 3)
        local selected = math.round(BJI.Managers.Env.Data.gravityRate, 3) == value
        local style = BJI.Utils.Style.BTN_PRESETS.INFO
        if not selected and p.default then
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS
        end
        LineBuilder()
            :btn({
                id = p.key,
                label = W.labels[p.key],
                style = style,
                disabled = selected,
                onClick = function()
                    if BJI.Managers.Env.Data.gravityRate ~= value then
                        BJI.Tx.config.env("gravityRate", p.value)
                        -- no client assign to sync all players on change
                    end
                end
            })
            :build()
    end)
end

local function body()
    LineBuilder()
        :icon({
            icon = ICONS.fitness_center,
            big = true,
        })
        :build()

    Table(W.cols):reduce(function(cols, col)
        cols:addRow(col)
        return cols
    end, ColumnsBuilder("EnvGravitySettings", { W.labelsWidth, -1 }))
        :build()

    if BJI.Managers.Env.Data.controlGravity then
        drawGravityPresets()
    end
end


W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
