return function(ctxt)
    local fields = {
        { key = "RaceSoloTimeBroadcast", type = "bool", },
        { key = "PreparationTimeout",    type = "int",   step = 1,   stepFast = 5,  min = 5,                                        max = 120, },
        { key = "VoteTimeout",           type = "int",   step = 1,   stepFast = 5,  min = 10,                                       max = 120, },
        { key = "VoteThresholdRatio",    type = "float", step = .05, stepFast = .1, min = .01,                                      max = 1,                                   precision = 2 },
        { key = "GridReadyTimeout",      type = "int",   step = 1,   stepFast = 5,  min = 5,                                        max = BJIContext.BJC.Race.GridTimeout - 1, },
        { key = "GridTimeout",           type = "int",   step = 1,   stepFast = 5,  min = BJIContext.BJC.Race.GridReadyTimeout + 1, max = nil, },
        { key = "RaceCountdown",         type = "int",   step = 1,   stepFast = 5,  min = 10,                                       max = nil, },
        { key = "FinishTimeout",         type = "int",   step = 1,   stepFast = 5,  min = 5,                                        max = nil, },
        { key = "RaceEndTimeout",        type = "int",   step = 1,   stepFast = 5,  min = 5,                                        max = nil, },
    }

    local labelWidth = 0
    for _, v in ipairs(fields) do
        local w = GetColumnTextWidth(BJILang.get(string.var("serverConfig.bjc.race.{1}",
            { v.key })) .. HELPMARKER_TEXT)
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("bjcRace", { labelWidth, -1 })
    for _, v in ipairs(fields) do
        cols = cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                        :text(BJILang.get(string.var("serverConfig.bjc.race.{1}", { v.key })))
                    local tooltip = BJILang.get(string.var("serverConfig.bjc.race.{1}Tooltip", { v.key }), "")
                    if #tooltip > 0 then
                        line:helpMarker(tooltip)
                    end
                    line:build()
                end,
                function()
                    if v.type == "bool" then
                        LineBuilder()
                            :btnIconToggle({
                                id = v.key,
                                state = not not BJIContext.BJC.Race[v.key],
                                coloredIcon = true,
                                onClick = function()
                                    BJITx.config.bjc(string.var("Race.{1}", { v.key }), not BJIContext.BJC.Race[v.key])
                                    BJIContext.BJC.Race[v.key] = not BJIContext.BJC.Race[v.key]
                                end
                            })
                            :build()
                    else
                        LineBuilder()
                            :inputNumeric({
                                id = v.key,
                                type = v.type,
                                precision = v.precision,
                                value = BJIContext.BJC.Race[v.key],
                                min = v.min,
                                max = v.max,
                                step = v.step,
                                stepFast = v.stepFast,
                                onUpdate = function(val)
                                    BJIContext.BJC.Race[v.key] = val
                                    BJITx.config.bjc(string.var("Race.{1}", { v.key }), val)
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
