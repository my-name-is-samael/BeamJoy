local fields = Table({
    { key = "PreparationTimeout", type = "int", step = 1, min = 5,  max = 180 },
    { key = "StartCountdown",     type = "int", step = 1, min = 10, max = 60 },
    { key = "DestroyedTimeout",   type = "int", step = 1, min = 3,  max = 20 },
    { key = "EndTimeout",         type = "int", step = 1, min = 5,  max = 30 },
})

return function(ctxt, labels, cache)
    fields:reduce(function(cols, v)
        return cols:addRow({
            cells = {
                function()
                    LineLabel(labels.derby.keys[v.key], nil, false, labels.derby.keys[v.key .. "Tooltip"])
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = v.key,
                            type = v.type,
                            value = BJI.Managers.Context.BJC.Derby[v.key],
                            min = v.min,
                            max = v.max,
                            step = v.step,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.Derby[v.key] = val
                                BJI.Tx.config.bjc(string.var("Derby.{1}", { v.key }), val)
                            end
                        })
                        :build()
                end
            }
        })
    end, ColumnsBuilder("bjcDerby", { cache.derby.labelsWidth, -1 })):build()
end
