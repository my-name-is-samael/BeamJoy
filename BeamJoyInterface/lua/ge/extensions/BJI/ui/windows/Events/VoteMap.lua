--- gc prevention
local vm, remainingTime, delayLabel

return function(ctxt, cache)
    if not vm then
        vm = BJI_Votes.Map
    end
    Text(cache.creator, {
        color = BJI_Context.User.playerID == vm.creatorID and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    })
    SameLine()
    Text(cache.hasStarted)
    SameLine()
    Text(vm.mapLabel)
    SameLine()
    Text(cache.mapCustom)

    remainingTime = vm.endsAt - ctxt.now
    delayLabel = remainingTime < 1000 and cache.voteAboutEnd or cache.timeout
        :var({ delay = BJI.Utils.UI.PrettyDelay(math.floor(remainingTime / 1000)) })
    Text(cache.votes)
    SameLine()
    Text(delayLabel)

    if IconButton("voteMap", vm.selfVoted and BJI.Utils.Icon.ICONS.event_busy or
            BJI.Utils.Icon.ICONS.event_available, { disabled = cache.disableButtons,
                big = true, btnStyle = vm.selfVoted and BJI.Utils.Style.BTN_PRESETS.ERROR or
                BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
        cache.disableButtons = true
        BJI_Tx_vote.MapVote()
    end
    TooltipText(vm.selfVoted and cache.buttons.unvote or cache.buttons.vote)
    if cache.showCancelBtn then
        SameLine()
        if IconButton("stopVoteMap", BJI.Utils.Icon.ICONS.cancel, {
                disabled = cache.disableButtons, big = true,
                btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            cache.disableButtons = true
            BJI_Tx_vote.MapStop()
        end
        TooltipText(cache.buttons.stop)
    end
end
