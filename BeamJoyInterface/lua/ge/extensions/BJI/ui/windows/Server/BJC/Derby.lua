local fields = Table({
    { key = "PreparationTimeout", type = "int", min = 5,  max = 180, renderFormat = "%ds", default = 60 },
    { key = "StartCountdown",     type = "int", min = 10, max = 60,  renderFormat = "%ds", default = 10 },
    { key = "DestroyedTimeout",   type = "int", min = 3,  max = 20,  renderFormat = "%ds", default = 5 },
    { key = "EndTimeout",         type = "int", min = 5,  max = 30,  renderFormat = "%ds", default = 10 },
})

return function(ctxt, labels, cache)
    fields:reduce(function(cols, v)
        return cols:addRow({
            cells = {
                function()
                    LineLabel(labels.derby.keys[v.key], nil, false, labels.derby.keys[v.key .. "Tooltip"])
                end,
                function()
                    LineBuilder():btnIcon({
                        id = v.key .. "reset",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = BJI.Managers.Context.BJC.Derby[v.key] == v.default,
                        tooltip = labels.buttons.reset,
                        onClick = function()
                            BJI.Managers.Context.BJC.Derby[v.key] = v.default
                            BJI.Tx.config.bjc("Derby." .. v.key, v.default)
                        end
                    }):slider({
                        id = v.key,
                        type = v.type,
                        value = BJI.Managers.Context.BJC.Derby[v.key],
                        min = v.min,
                        max = v.max,
                        renderFormat = v.renderFormat,
                        onUpdate = function(val)
                            if BJI.Managers.Context.BJC.Derby[v.key] ~= val then
                                BJI.Managers.Context.BJC.Derby[v.key] = val
                                BJI.Tx.config.bjc("Derby." .. v.key, val)
                            end
                        end
                    }):build()
                end
            }
        })
    end, ColumnsBuilder("bjcDerby", { cache.derby.labelsWidth, -1 })):build()
end
