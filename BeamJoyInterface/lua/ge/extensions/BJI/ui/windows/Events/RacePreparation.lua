--- gc prevention
local vr, remainingTime

return function(ctxt, cache)
    if not vr then
        vr = BJI.Managers.Votes.Race
    end

    Text(cache.hasStarted)
    Text(cache.title)
    Text(cache.settings)

    if cache.record then
        Text(cache.record)
    end

    if cache.votes then
        Text(cache.votes)
        SameLine()
    end
    remainingTime = vr.endsAt - ctxt.now
    Text(remainingTime < 1000 and cache.timeAboutEnd or cache.timeout
        :var({ delay = BJI.Utils.UI.PrettyDelay(math.floor(remainingTime / 1000)) }))

    if cache.showVoteBtn then
        if IconButton("voteRace", vr.selfVoted and BJI.Utils.Icon.ICONS.event_busy or
                BJI.Utils.Icon.ICONS.event_available, { disabled = cache.disableButtons,
                    big = true, btnStyle = vr.selfVoted and BJI.Utils.Style.BTN_PRESETS.ERROR or
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            cache.disableButtons = true
            BJI.Tx.vote.RaceVote()
        end
        TooltipText(vr.isVote and
            (vr.selfVoted and cache.buttons.unvote or cache.buttons.vote) or
            cache.buttons.stop)
    end
    if cache.showCancelBtn then
        if cache.showVoteBtn then
            SameLine()
        end
        if IconButton("stopPrepRace", BJI.Utils.Icon.ICONS.cancel, { disabled = cache.disableButtons,
                big = true, btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            cache.disableButtons = true
            BJI.Tx.vote.RaceStop()
        end
        TooltipText(cache.buttons.stop)
    end
end
