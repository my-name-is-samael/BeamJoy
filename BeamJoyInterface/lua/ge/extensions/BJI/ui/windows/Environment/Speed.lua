local common = require("ge/extensions/BJI/ui/windows/Environment/Common")

local W = {
    KEYS = Table({ "controlSpeed", "simSpeed" }),

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
            function() LineLabel(W.labels.controlSimSpeed) end,
            function()
                local line = LineBuilder()
                    :btnIconToggle({
                        id = "controlSimSpeed",
                        state = BJI.Managers.Env.Data.controlSimSpeed,
                        coloredIcon = true,
                        onClick = function()
                            BJI.Tx.config.env("controlSimSpeed", not BJI.Managers.Env.Data.controlSimSpeed)
                            BJI.Managers.Env.Data.controlSimSpeed = not BJI.Managers.Env.Data.controlSimSpeed
                        end,
                    })
                line:build()
            end
        },
        {
            function() LineLabel(W.labels.simSpeed) end,
            common.getNumericWithReset("simSpeed", not BJI.Managers.Env.Data.controlSimSpeed),
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

local function drawSpeedPresets(presets)
    for _, p in ipairs(presets) do
        local value = math.round(p.value, 2)
        local selected = math.round(BJI.Managers.Env.Data.simSpeed, 3) == value
        local style = BJI.Utils.Style.BTN_PRESETS.INFO
        if not selected and p.default then
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS
        end
        LineBuilder()
            :btn({
                id = p.key,
                label = string.var("{1} (x{2})", {
                    BJI.Managers.Lang.get(string.var("presets.speed.{1}", { p.key })),
                    value
                }),
                style = style,
                disabled = selected,
                onClick = function()
                    if not selected then
                        BJI.Tx.config.env("simSpeed", p.value)
                        -- no client assign to sync all players on change
                    end
                end
            })
            :build()
    end
end

local function body()
    LineBuilder()
        :icon({
            icon = ICONS.skip_next,
            big = true,
        })
        :build()

    Table(W.cols):reduce(function(cols, col)
        cols:addRow(col)
        return cols
    end, ColumnsBuilder("EnvSpeedSettings", { W.labelsWidth, -1 }))
        :build()

    if BJI.Managers.Env.Data.controlSimSpeed then
        drawSpeedPresets(require("ge/extensions/utils/EnvironmentUtils").speedPresets())
    end
end


W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
