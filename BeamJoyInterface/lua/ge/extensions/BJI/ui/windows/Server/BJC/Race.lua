local fields = {
    { key = "RaceSoloTimeBroadcast", type = "bool", },
    { key = "PreparationTimeout",    type = "int",  min = 5,  max = 120, renderFormat = "%ds", default = 10 },
    { key = "VoteTimeout",           type = "int",  min = 10, max = 120, renderFormat = "%ds", default = 30 },
    {
        key = "VoteThresholdRatio",
        type = "float",
        min = .01,
        max = 1,
        precision = 2,
        renderFormat = function(val)
            return string
                .var("{1}%%", { math.round(val * 100) })
        end,
        default = .51,
    },
    {
        key = "GridReadyTimeout",
        type = "int",
        min = 5,
        max = function()
            return
                BJI.Managers.Context.BJC.Race.GridTimeout - 1
        end,
        renderFormat = "%ds",
        default = 10
    },
    {
        key = "GridTimeout",
        type = "int",
        min = function()
            return BJI.Managers
                .Context.BJC.Race.GridReadyTimeout + 1
        end,
        max = 300,
        renderFormat = "%ds",
        default = 60
    },
    { key = "RaceCountdown",  type = "int", min = 10, max = 60, renderFormat = "%ds", default = 10 },
    { key = "FinishTimeout",  type = "int", min = 5,  max = 30, renderFormat = "%ds", default = 5 },
    { key = "RaceEndTimeout", type = "int", min = 5,  max = 30, renderFormat = "%ds", default = 10 },
}

return function(ctxt, labels, cache)
    local cols = ColumnsBuilder("bjcRace", { cache.race.labelsWidth, -1 })
    for _, v in ipairs(fields) do
        cols = cols:addRow({
            cells = {
                function()
                    LineLabel(labels.race.keys[v.key], nil, false, labels.race.keys[v.key .. "Tooltip"])
                end,
                function()
                    if v.type == "bool" then
                        LineBuilder():btnIconToggle({
                            id = v.key,
                            state = not not BJI.Managers.Context.BJC.Race[v.key],
                            coloredIcon = true,
                            onClick = function()
                                BJI.Tx.config.bjc("Race." .. v.key,
                                    not BJI.Managers.Context.BJC.Race[v.key])
                                BJI.Managers.Context.BJC.Race[v.key] = not BJI.Managers.Context.BJC.Race[v.key]
                            end
                        }):build()
                    else
                        LineBuilder():btnIcon({
                            id = v.key .. "reset",
                            icon = ICONS.refresh,
                            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = BJI.Managers.Context.BJC.Race[v.key] == v.default,
                            tooltip = labels.buttons.reset,
                            onClick = function()
                                BJI.Managers.Context.BJC.Race[v.key] = v.default
                                BJI.Tx.config.bjc("Race." .. v.key, v.default)
                            end
                        }):slider({
                            id = v.key,
                            type = tostring(v.type),
                            precision = v.precision,
                            value = BJI.Managers.Context.BJC.Race[v.key],
                            min = type(v.min) == "function" and v.min() or v.min,
                            max = type(v.max) == "function" and v.max() or v.max,
                            renderFormat = type(v.renderFormat) == "function" and
                                v.renderFormat(BJI.Managers.Context.BJC.Race[v.key]) or v.renderFormat,
                            onUpdate = function(val)
                                if BJI.Managers.Context.BJC.Race[v.key] ~= val then
                                    BJI.Managers.Context.BJC.Race[v.key] = val
                                    BJI.Tx.config.bjc("Race." .. v.key, val)
                                end
                            end
                        }):build()
                    end
                end
            }
        })
    end
    cols:build()
end
