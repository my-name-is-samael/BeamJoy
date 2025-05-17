local fields = {
    { key = "PreparationTimeout", type = "int", step = 1, stepFast = nil, min = 5,  max = 120, },
    { key = "VoteTimeout",        type = "int", step = 1, stepFast = nil, min = 5,  max = 120, },
    { key = "BaseSpeed",          type = "int", step = 1, stepFast = 5,   min = 20, max = 100, },
    { key = "StepSpeed",          type = "int", step = 1, stepFast = nil, min = 1,  max = 50, },
    { key = "StepDelay",          type = "int", step = 1, stepFast = nil, min = 2,  max = 30, },
    { key = "EndTimeout",         type = "int", step = 1, stepFast = nil, min = 5,  max = 30, },
}

return function(ctxt, labels, cache)
    local cols = ColumnsBuilder("bjcSpeed", { cache.speed.labelsWidth, -1 })
    for _, v in ipairs(fields) do
        cols = cols:addRow({
            cells = {
                function()
                    local line = LineBuilder():text(labels.speed.keys[v.key])
                    if labels.speed.keys[v.key .. "Tooltip"] then
                        line:helpMarker(labels.speed.keys[v.key .. "Tooltip"])
                    end
                    line:build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = v.key,
                            type = v.type,
                            value = BJI.Managers.Context.BJC.Speed[v.key],
                            min = v.min,
                            max = v.max,
                            step = v.step,
                            stepFast = v.stepFast,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.Speed[v.key] = val
                                BJI.Tx.config.bjc("Speed." .. v.key, val)
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
end
