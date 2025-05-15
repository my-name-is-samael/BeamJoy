return function(ctxt, labels, cache)
    ColumnsBuilder("voteKickSettings", { cache.voteKick.labelsWidth, -1 })
        :addRow({
            cells = {
                function() LineLabel(labels.voteKick.timeout) end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "voteTimeout",
                            type = "int",
                            value = BJI.Managers.Context.BJC.VoteKick.Timeout,
                            min = 5,
                            max = 300,
                            step = 1,
                            stepFast = 5,
                            width = 120,
                            disabled = cache.disableInputs,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.VoteKick.Timeout = val
                                BJI.Tx.config.bjc("VoteKick.Timeout", val)
                            end,
                        })
                        :text(cache.voteKick.timeoutPretty)
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function() LineLabel(labels.voteKick.thresholdRatio) end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "voteThresholdRatio",
                            type = "float",
                            precision = 2,
                            value = BJI.Managers.Context.BJC.VoteKick.ThresholdRatio,
                            min = 0.01,
                            max = 1,
                            step = .01,
                            stepFast = .05,
                            width = 120,
                            disabled = cache.disableInputs,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.VoteKick.ThresholdRatio = val
                                BJI.Tx.config.bjc("VoteKick.ThresholdRatio", val)
                            end,
                        })
                        :text(string.var("({1}%%)",
                            { math.round(BJI.Managers.Context.BJC.VoteKick.ThresholdRatio * 100) }))
                        :build()
                end
            }
        })
        :build()
end
