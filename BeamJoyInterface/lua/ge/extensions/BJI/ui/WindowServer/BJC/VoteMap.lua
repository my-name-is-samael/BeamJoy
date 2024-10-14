return function(ctxt)
    local labels = {
        BJILang.get("serverConfig.bjc.mapVote.timeout"),
        BJILang.get("serverConfig.bjc.mapVote.thresholdRatio"),
    }
    local labelWidth = 0
    for _, label in ipairs(labels) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    ColumnsBuilder("mapVoteSettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.mapVote.timeout") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "voteTimeout",
                            type = "int",
                            value = BJIContext.BJC.VoteMap.Timeout,
                            min = 5,
                            max = 300,
                            step = 1,
                            stepFast = 5,
                            width = 120,
                            onUpdate = function(val)
                                BJIContext.BJC.VoteMap.Timeout = val
                                BJITx.config.bjc("VoteMap.Timeout", val)
                            end,
                        })
                        :text(PrettyDelay(BJIContext.BJC.VoteMap.Timeout))
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.mapVote.thresholdRatio") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "voteThresholdRatio",
                            type = "float",
                            precision = 2,
                            value = BJIContext.BJC.VoteMap.ThresholdRatio,
                            min = 0.01,
                            max = 1,
                            step = .01,
                            stepFast = .05,
                            width = 120,
                            onUpdate = function(val)
                                BJIContext.BJC.VoteMap.ThresholdRatio = val
                                BJITx.config.bjc("VoteMap.ThresholdRatio", val)
                            end,
                        })
                        :build()
                end
            }
        })
        :build()
end
