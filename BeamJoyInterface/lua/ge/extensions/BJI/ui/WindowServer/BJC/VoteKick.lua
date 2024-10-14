return function(ctxt)
    local labels = {
        BJILang.get("serverConfig.bjc.voteKick.timeout"),
        BJILang.get("serverConfig.bjc.voteKick.thresholdRatio"),
    }
    local labelWidth = 0
    for _, label in ipairs(labels) do
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    ColumnsBuilder("voteKickSettings", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.voteKick.timeout") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "voteTimeout",
                            type = "int",
                            value = BJIContext.BJC.VoteKick.Timeout,
                            min = 5,
                            max = 300,
                            step = 1,
                            stepFast = 5,
                            width = 120,
                            onUpdate = function(val)
                                BJIContext.BJC.VoteKick.Timeout = val
                                BJITx.config.bjc("VoteKick.Timeout", val)
                            end,
                        })
                        :text(PrettyDelay(BJIContext.BJC.VoteKick.Timeout))
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.voteKick.thresholdRatio") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "voteThresholdRatio",
                            type = "float",
                            precision = 2,
                            value = BJIContext.BJC.VoteKick.ThresholdRatio,
                            min = 0.01,
                            max = 1,
                            step = .01,
                            stepFast = .05,
                            width = 120,
                            onUpdate = function(val)
                                BJIContext.BJC.VoteKick.ThresholdRatio = val
                                BJITx.config.bjc("VoteKick.ThresholdRatio", val)
                            end,
                        })
                        :build()
                end
            }
        })
        :build()
end
