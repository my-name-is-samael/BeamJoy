return function(ctxt, labels, cache)
    ColumnsBuilder("mapVoteSettings", { cache.mapVote.labelsWidth, -1 })
        :addRow({
            cells = {
                function() LineLabel(labels.mapVote.timeout) end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "voteTimeout",
                            type = "int",
                            value = BJI.Managers.Context.BJC.VoteMap.Timeout,
                            min = 5,
                            max = 300,
                            step = 1,
                            stepFast = 5,
                            width = 120,
                            disabled = cache.disableInputs,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.VoteMap.Timeout = val
                                BJI.Tx.config.bjc("VoteMap.Timeout", val)
                            end,
                        })
                        :text(cache.mapVote.timeoutPretty)
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function() LineLabel(labels.mapVote.thresholdRatio) end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "voteThresholdRatio",
                            type = "float",
                            precision = 2,
                            value = BJI.Managers.Context.BJC.VoteMap.ThresholdRatio,
                            min = 0.01,
                            max = 1,
                            step = .01,
                            stepFast = .05,
                            width = 120,
                            disabled = cache.disableInputs,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.VoteMap.ThresholdRatio = val
                                BJI.Tx.config.bjc("VoteMap.ThresholdRatio", val)
                            end,
                        })
                        :text(string.var("({1}%%)",
                            { math.round(BJI.Managers.Context.BJC.VoteMap.ThresholdRatio * 100) }))
                        :build()
                end
            }
        })
        :build()
end
