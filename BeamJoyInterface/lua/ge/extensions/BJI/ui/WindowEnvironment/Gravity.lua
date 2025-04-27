local common = require("ge/extensions/BJI/ui/WindowEnvironment/Common")

local function drawGravityPresets(presets)
    for _, p in ipairs(presets) do
        local value = math.round(p.value, 3)
        local selected = math.round(BJIEnv.Data.gravityRate, 3) == value
        local style = BTN_PRESETS.INFO
        if not selected and p.default then
            style = BTN_PRESETS.SUCCESS
        end
        LineBuilder()
            :btn({
                id = p.key,
                label = string.var("{1} ({2})", {
                    BJILang.get(string.var("presets.gravity.{1}", { p.key })),
                    p.value,
                }),
                style = style,
                disabled = selected,
                onClick = function()
                    if BJIEnv.Data.gravityRate ~= value then
                        BJITx.config.env("gravityRate", p.value)
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
            icon = ICONS.fitness_center,
            big = true,
        })
        :build()

    local labelWidth = 0
    for _, key in ipairs({
        "controlGravity",
        "gravityRate",
    }) do
        local label = BJILang.get(string.var("environment.{1}", { key }))
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
                        :text(string.var("{1}:", { BJILang.get("environment.controlGravity") }))
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
