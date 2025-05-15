local fields = {
    { key = "PreparationTimeout",  type = "int", step = 1, min = 5, max = 120, },
    { key = "HuntedStartDelay",    type = "int", step = 1, min = 0, max = 30, },
    { key = "HuntersStartDelay",   type = "int", step = 1, min = 0, max = 60, },
    { key = "HuntedStuckTimeout",  type = "int", step = 1, min = 3, max = 30, },
    { key = "HuntersRespawnDelay", type = "int", step = 1, min = 0, max = 300, },
}

return function(ctxt, labels, cache)
    local cols = ColumnsBuilder("bjcHunter", { cache.hunter.labelsWidth, -1 })
    for _, v in ipairs(fields) do
        cols = cols:addRow({
            cells = {
                function()
                    local line = LineBuilder():text(labels.hunter.keys[v.key])
                    if labels.hunter.keys[v.key .. "Tooltip"] then
                        line:helpMarker(labels.hunter.keys[v.key .. "Tooltip"])
                    end
                    line:build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = v.key,
                            type = v.type,
                            value = BJI.Managers.Context.BJC.Hunter[v.key],
                            min = v.min,
                            max = v.max,
                            step = v.step,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.Hunter[v.key] = val
                                BJI.Tx.config.bjc(string.var("Hunter.{1}", { v.key }), val)
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
end
