--- gc prevention
local nextValue

return function(ctxt, labels, cache)
    if BeginTable("BJIServerBJCVoteKick", {
            { label = "##bjiserverbjcvotekick-labels" },
            { label = "##bjiserverbjcvotekick-inputs",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##bjiserverbjcvotekick-preview", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(labels.voteKick.timeout)
        TableNextColumn()
        if IconButton("votekickTimeoutReset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = cache.disableInputs or
                    BJI.Managers.Context.BJC.VoteKick.Timeout == 30 }) then
            BJI.Managers.Context.BJC.VoteKick.Timeout = 30
            BJI.Tx.config.bjc("VoteKick.Timeout", BJI.Managers.Context.BJC.VoteKick.Timeout)
            cache.voteKick.timeoutPretty = BJI.Utils.UI.PrettyDelay(BJI.Managers.Context.BJC.VoteKick.Timeout)
        end
        SameLine()
        nextValue = SliderIntPrecision("voteTimeout", BJI.Managers.Context.BJC.VoteKick.Timeout, 5, 300,
            { step = 1, stepFast = 5, disabled = cache.disableInputs, formatRender = "%ds" })
        if nextValue then
            BJI.Managers.Context.BJC.VoteKick.Timeout = nextValue
            BJI.Tx.config.bjc("VoteKick.Timeout", BJI.Managers.Context.BJC.VoteKick.Timeout)
            cache.voteKick.timeoutPretty = BJI.Utils.UI.PrettyDelay(BJI.Managers.Context.BJC.VoteKick.Timeout)
        end
        TableNextColumn()
        Text(cache.voteKick.timeoutPretty)

        TableNewRow()
        Text(labels.voteKick.thresholdRatio)
        TableNextColumn()
        if IconButton("votekickThresholdRatioReset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = cache.disableInputs or
                    BJI.Managers.Context.BJC.VoteKick.ThresholdRatio == 0.51 }) then
            BJI.Managers.Context.BJC.VoteKick.ThresholdRatio = 0.51
            BJI.Tx.config.bjc("VoteKick.ThresholdRatio", BJI.Managers.Context.BJC.VoteKick.ThresholdRatio)
        end
        SameLine()
        nextValue = SliderIntPrecision("voteThresholdRatio", BJI.Managers.Context.BJC.VoteKick.ThresholdRatio * 100, 1,
            100, { step = 1, stepFast = 5, disabled = cache.disableInputs, formatRender = "%d%%" })
        if nextValue then
            BJI.Managers.Context.BJC.VoteKick.ThresholdRatio = math.round(nextValue / 100, 2)
            BJI.Tx.config.bjc("VoteKick.ThresholdRatio", BJI.Managers.Context.BJC.VoteKick.ThresholdRatio)
        end
        TableNextColumn()
        Text(tostring(BJI.Managers.Context.BJC.VoteKick.ThresholdRatio * 100) .. "%%")

        EndTable()
    end
end
