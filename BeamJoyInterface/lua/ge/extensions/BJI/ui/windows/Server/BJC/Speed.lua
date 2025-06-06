local fields = {
    { key = "PreparationTimeout", type = "int", min = 5,  max = 120, renderFormat = "%ds",    default = 10 },
    { key = "VoteTimeout",        type = "int", min = 5,  max = 120, renderFormat = "%ds",    default = 30 },
    { key = "BaseSpeed",          type = "int", min = 20, max = 100, renderFormat = "%dkm/h", default = 30 },
    { key = "StepSpeed",          type = "int", min = 1,  max = 50,  renderFormat = "%dkm/h", default = 5 },
    { key = "StepDelay",          type = "int", min = 2,  max = 30,  renderFormat = "%ds",    default = 10 },
    { key = "EndTimeout",         type = "int", min = 5,  max = 30,  renderFormat = "%ds",    default = 10 },
}

return function(ctxt, labels, cache)
    local cols = ColumnsBuilder("bjcSpeed", { cache.speed.labelsWidth, -1 })
    for _, v in ipairs(fields) do
        cols = cols:addRow({
            cells = {
                function()
                    LineLabel(labels.speed.keys[v.key], nil, false, labels.speed.keys[v.key .. "Tooltip"])
                end,
                function()
                    LineBuilder():btnIcon({
                        id = v.key .. "reset",
                        icon = BJI.Utils.Icon.ICONS.refresh,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = BJI.Managers.Context.BJC.Speed[v.key] == v.default,
                        tooltip = labels.buttons.reset,
                        onClick = function()
                            BJI.Managers.Context.BJC.Speed[v.key] = v.default
                            BJI.Tx.config.bjc("Speed." .. v.key, v.default)
                        end
                    }):slider({
                        id = v.key,
                        type = v.type,
                        value = BJI.Managers.Context.BJC.Speed[v.key],
                        min = v.min,
                        max = v.max,
                        renderFormat = v.renderFormat,
                        onUpdate = function(val)
                            if BJI.Managers.Context.BJC.Speed[v.key] ~= val then
                                BJI.Managers.Context.BJC.Speed[v.key] = val
                                BJI.Tx.config.bjc("Speed." .. v.key, val)
                            end
                        end
                    }):build()
                end
            }
        })
    end
    cols:build()
end
