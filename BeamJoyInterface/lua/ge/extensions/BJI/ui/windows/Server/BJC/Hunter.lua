local fields = Table({
    { key = "PreparationTimeout",            type = "int", min = 5, max = 180, renderFormat = "%ds", default = 30 },
    { key = "HuntedStartDelay",              type = "int", min = 0, max = 60,  renderFormat = "%ds", default = 5 },
    { key = "HuntersStartDelay",             type = "int", min = 0, max = 60,  renderFormat = "%ds", default = 10 },
    { key = "HuntedStuckTimeout",            type = "int", min = 3, max = 20,  renderFormat = "%ds", default = 10 },
    { key = "HuntersRespawnDelay",           type = "int", min = 0, max = 60,  renderFormat = "%ds", default = 10 },
    { key = "HuntedResetRevealDuration",     type = "int", min = 0, max = 30,  renderFormat = "%ds", default = 5 },
    { key = "HuntedRevealProximityDistance", type = "int", min = 0, max = 500, renderFormat = "%dm", default = 50 },
    { key = "HuntedResetDistanceThreshold",  type = "int", min = 0, max = 500, renderFormat = "%dm", default = 150 },
    { key = "EndTimeout",                    type = "int", min = 5, max = 30,  renderFormat = "%ds", default = 10 },
})

return function(ctxt, labels, cache)
    fields:reduce(function(cols, v)
        return cols:addRow({
            cells = {
                function()
                    LineLabel(labels.hunter.keys[v.key], nil, false, labels.hunter.keys[v.key .. "Tooltip"])
                end,
                function()
                    LineBuilder():btnIcon({
                        id = v.key .. "reset",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = BJI.Managers.Context.BJC.Hunter[v.key] == v.default,
                        tooltip = labels.buttons.reset,
                        onClick = function()
                            BJI.Managers.Context.BJC.Hunter[v.key] = v.default
                            BJI.Tx.config.bjc("Hunter." .. v.key, v.default)
                        end
                    }):slider({
                        id = v.key,
                        type = v.type,
                        value = BJI.Managers.Context.BJC.Hunter[v.key],
                        min = v.min,
                        max = v.max,
                        step = v.step,
                        renderFormat = v.renderFormat,
                        onUpdate = function(val)
                            if BJI.Managers.Context.BJC.Hunter[v.key] ~= val then
                                BJI.Managers.Context.BJC.Hunter[v.key] = val
                                BJI.Tx.config.bjc("Hunter." .. v.key, val)
                            end
                        end
                    }):build()
                end
            }
        })
    end, ColumnsBuilder("bjcHunter", { cache.hunter.labelsWidth, -1 })):build()
end
