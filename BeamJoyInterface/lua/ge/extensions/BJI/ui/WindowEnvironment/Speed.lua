local common = require("ge/extensions/BJI/ui/WindowEnvironment/Common")

local function drawSpeedPresets(presets)
    for _, p in ipairs(presets) do
        local value = Round(p.value, 2)
        local selected = Round(BJIEnv.Data.simSpeed, 3) == value
        local style = BTN_PRESETS.INFO
        if not selected and p.default then
            style = BTN_PRESETS.SUCCESS
        end
        LineBuilder()
            :btn({
                id = p.key,
                label = svar("{1} (x{2})", {
                    BJILang.get(svar("presets.speed.{1}", { p.key })),
                    value
                }),
                style = style,
                disabled = selected,
                onClick = function()
                    if not selected then
                        BJITx.config.env("simSpeed", p.value)
                        -- no client assign to sync all players on change
                    end
                end
            })
            :build()
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
    for _, key in ipairs({
        "controlSpeed",
        "simSpeed",
    }) do
        local label = BJILang.get(svar("environment.{1}", { key }))
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
