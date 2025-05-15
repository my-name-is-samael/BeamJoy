return function(ctxt, cache)
    local vk = BJI.Managers.Votes.Kick

    LineBuilder()
        :text(cache.creator, ctxt.user.playerID == vk.creatorID and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :text(cache.hasStarted)
        :text(cache.target, ctxt.user.playerID == vk.targetID and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :build()
    local remainingTime = vk.endsAt - ctxt.now
    local delayLabel = remainingTime < 1000 and cache.aboutEnd or cache.timeout
        :var({ delay = BJI.Utils.Common.PrettyDelay(math.floor(remainingTime / 1000)) })
    LineBuilder()
        :text(cache.votes)
        :text(delayLabel)
        :build()
    local line = LineBuilder()
        :btnIconToggle({
            id = "voteKick",
            icon = vk.selfVoted and ICONS.event_busy or ICONS.event_available,
            state = not vk.selfVoted,
            disabled = cache.voteDisabled,
            onClick = function()
                cache.voteDisabled = true
                BJI.Tx.votekick.vote()
                vk.selfVoted = not vk.selfVoted
                vk.amountVotes = vk.amountVotes + (vk.selfVoted and 1 or -1)
            end
        })
    if BJI.Managers.Perm.isStaff() then
        line:btnIcon({
            id = "stopVoteKick",
            icon = ICONS.cancel,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = cache.disableButtons,
            onClick = function()
                cache.disableButtons = true
                BJI.Tx.votekick.stop()
            end,
        })
    end
    line:build()
end
