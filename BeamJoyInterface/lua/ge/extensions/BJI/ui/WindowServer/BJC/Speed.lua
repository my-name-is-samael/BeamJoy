return function(ctxt)
    local fields = {
        { key = "PreparationTimeout", type = "int", step = 1, stepFast = nil, min = 5,  max = 120, },
        { key = "VoteTimeout",        type = "int", step = 1, stepFast = nil, min = 5,  max = 120, },
        { key = "BaseSpeed",          type = "int", step = 1, stepFast = 5,   min = 20, max = 100, },
        { key = "StepSpeed",          type = "int", step = 1, stepFast = nil, min = 1,  max = 50, },
        { key = "StepDelay",          type = "int", step = 1, stepFast = nil, min = 2,  max = 30, },
        { key = "EndTimeout",         type = "int", step = 1, stepFast = nil, min = 5,  max = 30, },
    }

    local labelWidth = 0
    for _, v in ipairs(fields) do
        local w = GetColumnTextWidth(BJILang.get(string.var("serverConfig.bjc.speed.{1}",
            { v.key })) .. HELPMARKER_TEXT)
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("bjcSpeed", { labelWidth, -1 })
    for _, v in ipairs(fields) do
        cols = cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                        :text(BJILang.get(string.var("serverConfig.bjc.speed.{1}", { v.key })))
                    local tooltip = BJILang.get(string.var("serverConfig.bjc.speed.{1}Tooltip", { v.key }), "")
                    if #tooltip > 0 then
                        line:helpMarker(tooltip)
                    end
                    line:build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = v.key,
                            type = v.type,
                            value = BJIContext.BJC.Speed[v.key],
                            min = v.min,
                            max = v.max,
                            step = v.step,
                            stepFast = v.stepFast,
                            onUpdate = function(val)
                                BJIContext.BJC.Speed[v.key] = val
                                BJITx.config.bjc(string.var("Speed.{1}", { v.key }), val)
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
end
