local common = require("ge/extensions/BJI/ui/WindowEnvironment/Common")

local function drawSpeedPresets(presets)
    -- 5 buttons per line
    local lineThresh = 5
    local i = 1
    while i < tlength(presets) do
        local line = LineBuilder()
        for offset = 0, lineThresh - 1 do
            if presets[i + offset] ~= nil then
                local preset = presets[i + offset]
                local style = BTN_PRESETS.INFO
                if Round(BJIEnv.Data.simSpeed, 3) == Round(preset.value, 3) then
                    style = BTN_PRESETS.DISABLED
                elseif Round(preset.value, 3) == 1 then
                    style = BTN_PRESETS.SUCCESS
                end
                line:btn({
                    id = preset.label,
                    label = preset.label,
                    style = style,
                    onClick = function()
                        BJITx.config.env("simSpeed", preset.value)
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
            icon = ICONS.skip_next,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, label in ipairs({
        BJILang.get("environment.controlSpeed"),
        common.numericData.simSpeed.label,
    }) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("EnvSpeedSettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("environment.controlSpeed") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIconToggle({
                            id = "controlSimSpeed",
                            state = BJIEnv.Data.controlSimSpeed,
                            coloredIcon = true,
                            onClick = function()
                                BJITx.config.env("controlSimSpeed", not BJIEnv.Data.controlSimSpeed)
                                BJIEnv.Data.controlSimSpeed = not BJIEnv.Data.controlSimSpeed
                            end,
                        })
                        :build()
                end
            }
        })

    if BJIEnv.Data.controlSimSpeed then
        common.drawNumericWithReset(cols, "simSpeed")
    end
    cols:build()
    if BJIEnv.Data.controlSimSpeed then
        drawSpeedPresets(require("ge/extensions/utils/EnvironmentUtils")
            .speedPresets())
    end
end

return draw
