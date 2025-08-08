--- gc prevention
local mgr, remainingTime

return function(ctxt, cache)
    if not mgr then
        mgr = BJI_Votes.Scenario
    end

    Text(cache.hasStarted)
    Text(cache.settings)

    if cache.votes then
        Text(cache.votes)
        SameLine()
    end
    remainingTime = mgr.endsAt - ctxt.now
    Text(remainingTime < 1000 and cache.timeAboutEnd or cache.timeout
        :var({ delay = BJI.Utils.UI.PrettyDelay(math.floor(remainingTime / 1000)) }))

    if cache.showVoteBtn then
        if IconButton("vote", mgr.selfVoted and BJI.Utils.Icon.ICONS.event_busy or
                BJI.Utils.Icon.ICONS.event_available, { disabled = cache.disableButtons,
                    big = true, btnStyle = mgr.selfVoted and BJI.Utils.Style.BTN_PRESETS.ERROR or
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            cache.disableButtons = true
            BJI_Tx_vote.ScenarioVote()
        end
        TooltipText(mgr.isVote and
            (mgr.selfVoted and cache.buttons.unvote or cache.buttons.vote) or
            cache.buttons.stop)
    end
    if cache.showCancelBtn then
        if cache.showVoteBtn then
            SameLine()
        end
        if IconButton("stopPreparation", BJI.Utils.Icon.ICONS.cancel, { disabled = cache.disableButtons,
                big = true, btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            cache.disableButtons = true
            BJI_Tx_vote.ScenarioStop()
        end
        TooltipText(cache.buttons.stop)
    end
end
