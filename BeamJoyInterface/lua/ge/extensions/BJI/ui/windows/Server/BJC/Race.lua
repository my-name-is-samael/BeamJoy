local fields = {
    { key = "RaceSoloTimeBroadcast", type = "bool", },
    { key = "PreparationTimeout",    type = "int",   step = 1,   stepFast = 5,  min = 5,   max = 120, },
    { key = "VoteTimeout",           type = "int",   step = 1,   stepFast = 5,  min = 10,  max = 120, },
    { key = "VoteThresholdRatio",    type = "float", step = .05, stepFast = .1, min = .01, max = 1,   precision = 2 },
    {
        key = "GridReadyTimeout",
        type = "int",
        step = 1,
        stepFast = 5,
        min = 5,
        max = function()
            return
                BJI.Managers.Context.BJC.Race.GridTimeout - 1
        end,
    },
    {
        key = "GridTimeout",
        type = "int",
        step = 1,
        stepFast = 5,
        min = function()
            return BJI.Managers
                .Context.BJC.Race.GridReadyTimeout + 1
        end,
        max = nil,
    },
    { key = "RaceCountdown",  type = "int", step = 1, stepFast = 5, min = 10, max = nil, },
    { key = "FinishTimeout",  type = "int", step = 1, stepFast = 5, min = 5,  max = nil, },
    { key = "RaceEndTimeout", type = "int", step = 1, stepFast = 5, min = 5,  max = nil, },
}

return function(ctxt, labels, cache)
    local cols = ColumnsBuilder("bjcRace", { cache.race.labelsWidth, -1 })
    for _, v in ipairs(fields) do
        cols = cols:addRow({
            cells = {
                function()
                    local line = LineBuilder():text(labels.race.keys[v.key])
                    if labels.race.keys[v.key .. "Tooltip"] then
                        line:helpMarker(labels.race.keys[v.key .. "Tooltip"])
                    end
                    line:build()
                end,
                function()
                    if v.type == "bool" then
                        LineBuilder()
                            :btnIconToggle({
                                id = v.key,
                                state = not not BJI.Managers.Context.BJC.Race[v.key],
                                coloredIcon = true,
                                onClick = function()
                                    BJI.Tx.config.bjc("Race." .. v.key,
                                        not BJI.Managers.Context.BJC.Race[v.key])
                                    BJI.Managers.Context.BJC.Race[v.key] = not BJI.Managers.Context.BJC.Race[v.key]
                                end
                            })
                            :build()
                    else
                        LineBuilder()
                            :inputNumeric({
                                id = v.key,
                                type = tostring(v.type),
                                precision = v.precision,
                                value = BJI.Managers.Context.BJC.Race[v.key],
                                min = type(v.min) == "function" and v.min() or v.min,
                                max = type(v.max) == "function" and v.max() or v.max,
                                step = v.step,
                                stepFast = v.stepFast,
                                onUpdate = function(val)
                                    BJI.Managers.Context.BJC.Race[v.key] = val
                                    BJI.Tx.config.bjc("Race." .. v.key, val)
                                end
                            })
                            :build()
                    end
                end
            }
        })
    end
    cols:build()
end
