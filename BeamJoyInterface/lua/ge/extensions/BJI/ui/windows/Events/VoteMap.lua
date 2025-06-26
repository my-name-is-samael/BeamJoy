return function(ctxt, cache)
    local vm = BJI.Managers.Votes.Map
    LineBuilder()
        :text(cache.creator,
            BJI.Managers.Context.User.playerID == vm.creatorID and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :text(cache.hasStarted)
        :text(vm.mapLabel)
        :text(cache.mapCustom)
        :build()
    local remainingTime = vm.endsAt - ctxt.now
    local delayLabel = remainingTime < 1000 and cache.voteAboutEnd or cache.timeout
        :var({ delay = BJI.Utils.UI.PrettyDelay(math.floor(remainingTime / 1000)) })
    LineBuilder()
        :text(cache.votes)
        :text(delayLabel)
        :build()
    local line = LineBuilder()
        :btnIconToggle({
            id = "voteMap",
            icon = vm.selfVoted and BJI.Utils.Icon.ICONS.event_busy or BJI.Utils.Icon.ICONS.event_available,
            state = not vm.selfVoted,
            tooltip = vm.selfVoted and cache.buttons.unvote or cache.buttons.vote,
            disabled = cache.disableButtons,
            big = true,
            onClick = function()
                cache.disableButtons = true
                BJI.Tx.votemap.vote()
            end
        })
    if BJI.Managers.Perm.isStaff() then
        line:btnIcon({
            id = "stopVoteMap",
            icon = BJI.Utils.Icon.ICONS.cancel,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = cache.buttons.stop,
            disabled = cache.disableButtons,
            big = true,
            onClick = function()
                cache.disableButtons = true
                BJI.Tx.votemap.stop()
            end,
        })
    end
    line:build()
end
