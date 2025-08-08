--- gc prevention
local vk, remainingTime, delayLabel

return function(ctxt, cache)
    if not vk then
        vk = BJI_Votes.Kick
    end

    Text(cache.creator, ctxt.user.playerID == vk.creatorID and
        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
    SameLine()
    Text(cache.hasStarted)
    SameLine()
    Text(cache.target, ctxt.user.playerID == vk.targetID and
        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)

    remainingTime = vk.endsAt - ctxt.now
    delayLabel = remainingTime < 1000 and cache.aboutEnd or cache.timeout
        :var({ delay = BJI.Utils.UI.PrettyDelay(math.floor(remainingTime / 1000)) })
    Text(cache.votes)
    SameLine()
    Text(delayLabel)

    if IconButton("voteKick", vk.selfVoted and BJI.Utils.Icon.ICONS.event_busy or
            BJI.Utils.Icon.ICONS.event_available, { disabled = cache.disableButtons,
                big = true, btnStyle = vk.selfVoted and BJI.Utils.Style.BTN_PRESETS.ERROR or
                BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
        cache.disableButtons = true
        BJI_Tx_vote.KickVote()
        vk.selfVoted = not vk.selfVoted
        vk.amountVotes = vk.amountVotes + (vk.selfVoted and 1 or -1)
    end
    TooltipText(vk.selfVoted and cache.buttons.unvote or cache.buttons.vote)
    if cache.showCancelBtn then
        SameLine()
        if IconButton("stopVoteKick", BJI.Utils.Icon.ICONS.cancel, {
                disabled = cache.disableButtons, big = true,
                btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            cache.disableButtons = true
            BJI_Tx_vote.KickStop()
        end
        TooltipText(cache.buttons.stop)
    end
end
