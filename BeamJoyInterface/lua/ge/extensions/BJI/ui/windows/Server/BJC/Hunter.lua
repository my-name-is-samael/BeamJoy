local fields = Table({
    { key = "PreparationTimeout",  type = "int", step = 1, min = 5, max = 180 },
    { key = "HuntedStartDelay",    type = "int", step = 1, min = 0, max = 60 },
    { key = "HuntersStartDelay",   type = "int", step = 1, min = 0, max = 60 },
    { key = "HuntedStuckTimeout",  type = "int", step = 1, min = 3, max = 20 },
    { key = "HuntersRespawnDelay", type = "int", step = 1, min = 0, max = 60 },
})

return function(ctxt, labels, cache)
    fields:reduce(function(cols, v)
        return cols:addRow({
            cells = {
                function()
                    LineLabel(labels.hunter.keys[v.key], nil, false, labels.hunter.keys[v.key .. "Tooltip"])
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
    end, ColumnsBuilder("bjcHunter", { cache.hunter.labelsWidth, -1 })):build()
end
