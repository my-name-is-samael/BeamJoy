local common = require("ge/extensions/BJI/ui/WindowEnvironment/Common")

local function drawGravityPresets(presets)
    -- 6 buttons per line
    local lineThresh = 6
    local i = 1
    while i < tlength(presets) do
        local line = LineBuilder()
        for offset = 0, lineThresh - 1 do
            if presets[i + offset] ~= nil then
                local preset = presets[i + offset]
                local style = BTN_PRESETS.INFO
                if Round(BJIEnv.Data.gravityRate, 3) == Round(preset.value, 3) then
                    style = BTN_PRESETS.DISABLED
                elseif Round(preset.value, 3) == -9.81 then
                    style = BTN_PRESETS.SUCCESS
                end
                line:btn({
                    id = preset.label,
                    label = preset.label,
                    style = style,
                    onClick = function()
                        BJITx.config.env("gravityRate", preset.value)
                    end
                })
            end
        end
        line:build()
        i = i + lineThresh
    end
end

local function draw()
    LineBuilder()
        :icon({
            icon = ICONS.fitness_center,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, label in ipairs({
        BJILang.get("environment.controlGravity"),
        common.numericData.gravityRate.label,
    }) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("EnvGravitySettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.controlGravity") }))
                        :build()
                end,
                function()
                    local line = LineBuilder()
                        :btnIconToggle({
                            id = "controlGravity",
                            state = BJIEnv.Data.controlGravity,
                            coloredIcon = true,
                            onClick = function()
                                BJITx.config.env("controlGravity", not BJIEnv.Data.controlGravity)
                                BJIEnv.Data.controlGravity = not BJIEnv.Data.controlGravity
                            end,
                        })
                    if BJIEnv.Data.controlGravity then
                        line:btn({
                            id = "resetGravity",
                            label = BJILang.get("common.buttons.resetAll"),
                            style = BTN_PRESETS.WARNING,
                            onClick = function()
                                BJITx.config.env("reset", BJI_ENV_TYPES.GRAVITY)
                            end,
                        })
                    end
                    line:build()
                end
            }
        })
    if BJIEnv.Data.controlGravity then
        common.drawNumericWithReset(cols, "gravityRate")
    end
    cols:build()
    if BJIEnv.Data.controlGravity then
        drawGravityPresets(require("ge/extensions/utils/EnvironmentUtils").gravityPresets())
    end
end

return draw
