--- gc prevention
local nextValue

return function(ctxt, labels, cache)
    if BeginTable("BJIServerBJCVoteMap", {
            { label = "##bjiserverbjcvotemap-labels" },
            { label = "##bjiserverbjcvotemap-inputs",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##bjiserverbjcvotemap-preview", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(labels.mapVote.timeout)
        TableNextColumn()
        if IconButton("votemapTimeoutReset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = cache.disableInputs or
                    BJI_Context.BJC.VoteMap.Timeout == 30 }) then
            BJI_Context.BJC.VoteMap.Timeout = 30
            BJI_Tx_config.bjc("VoteMap.Timeout", BJI_Context.BJC.VoteMap.Timeout)
            cache.mapVote.timeoutPretty = BJI.Utils.UI.PrettyDelay(BJI_Context.BJC.VoteMap.Timeout)
        end
        SameLine()
        nextValue = SliderIntPrecision("voteTimeout", BJI_Context.BJC.VoteMap.Timeout, 5, 300,
            { step = 1, stepFast = 5, disabled = cache.disableInputs, formatRender = "%ds" })
        if nextValue then
            BJI_Context.BJC.VoteMap.Timeout = nextValue
            BJI_Tx_config.bjc("VoteMap.Timeout", BJI_Context.BJC.VoteMap.Timeout)
            cache.mapVote.timeoutPretty = BJI.Utils.UI.PrettyDelay(BJI_Context.BJC.VoteMap.Timeout)
        end
        TableNextColumn()
        Text(cache.mapVote.timeoutPretty)

        TableNewRow()
        Text(labels.mapVote.thresholdRatio)
        TableNextColumn()
        if IconButton("votemapThresholdRatioReset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = cache.disableInputs or
                    BJI_Context.BJC.VoteMap.ThresholdRatio == 0.51 }) then
            BJI_Context.BJC.VoteMap.ThresholdRatio = 0.51
            BJI_Tx_config.bjc("VoteMap.ThresholdRatio", BJI_Context.BJC.VoteMap.ThresholdRatio)
        end
        SameLine()
        nextValue = SliderIntPrecision("voteThresholdRatio", BJI_Context.BJC.VoteMap.ThresholdRatio * 100, 1,
            100, { step = 1, stepFast = 5, disabled = cache.disableInputs, formatRender = "%d%%" })
        if nextValue then
            BJI_Context.BJC.VoteMap.ThresholdRatio = math.round(nextValue / 100, 2)
            BJI_Tx_config.bjc("VoteMap.ThresholdRatio", BJI_Context.BJC.VoteMap.ThresholdRatio)
        end
        TableNextColumn()
        Text(tostring(BJI_Context.BJC.VoteMap.ThresholdRatio * 100) .. "%%")

        EndTable()
    end
end
