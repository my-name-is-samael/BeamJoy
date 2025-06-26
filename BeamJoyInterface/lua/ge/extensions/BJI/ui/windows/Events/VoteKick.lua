return function(ctxt, cache)
    local vk = BJI.Managers.Votes.Kick

    LineBuilder()
        :text(cache.creator, ctxt.user.playerID == vk.creatorID and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :text(cache.hasStarted)
        :text(cache.target, ctxt.user.playerID == vk.targetID and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :build()
    local remainingTime = vk.endsAt - ctxt.now
    local delayLabel = remainingTime < 1000 and cache.aboutEnd or cache.timeout
        :var({ delay = BJI.Utils.UI.PrettyDelay(math.floor(remainingTime / 1000)) })
    LineBuilder()
        :text(cache.votes)
        :text(delayLabel)
        :build()
    local line = LineBuilder()
        :btnIconToggle({
            id = "voteKick",
            icon = vk.selfVoted and BJI.Utils.Icon.ICONS.event_busy or BJI.Utils.Icon.ICONS.event_available,
            state = not vk.selfVoted,
            tooltip = vk.selfVoted and cache.buttons.unvote or cache.buttons.vote,
            disabled = cache.disableButtons,
            big = true,
            onClick = function()
                cache.disableButtons = true
                BJI.Tx.votekick.vote()
                vk.selfVoted = not vk.selfVoted
                vk.amountVotes = vk.amountVotes + (vk.selfVoted and 1 or -1)
            end
        })
    if BJI.Managers.Perm.isStaff() then
        line:btnIcon({
            id = "stopVoteKick",
            icon = BJI.Utils.Icon.ICONS.cancel,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = cache.buttons.stop,
            disabled = cache.disableButtons,
            big = true,
            onClick = function()
                cache.disableButtons = true
                BJI.Tx.votekick.stop()
            end,
        })
    end
    line:build()
end
