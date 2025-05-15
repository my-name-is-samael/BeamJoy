return function(ctxt, cache)
    local vm = BJI.Managers.Votes.Map
    LineBuilder()
        :text(cache.creator,
            BJI.Managers.Context.User.playerID == vm.creatorID and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :text(cache.hasStarted)
        :text(vm.mapLabel)
        :text(cache.mapCustom)
        :build()
    local remainingTime = vm.endsAt - ctxt.now
    local delayLabel = remainingTime < 1000 and cache.voteAboutEnd or cache.timeout
        :var({ delay = BJI.Utils.Common.PrettyDelay(math.floor(remainingTime / 1000)) })
    LineBuilder()
        :text(cache.votes)
        :text(delayLabel)
        :build()
    local line = LineBuilder()
        :btnIconToggle({
            id = "voteMap",
            icon = vm.selfVoted and ICONS.event_busy or ICONS.event_available,
            state = not vm.selfVoted,
            disabled = cache.voteDisabled,
            onClick = function()
                cache.voteDisabled = true
                BJI.Tx.votemap.vote()
            end
        })
    if BJI.Managers.Perm.isStaff() then
        line:btnIcon({
            id = "stopVoteMap",
            icon = ICONS.cancel,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = cache.disableButtons,
            onClick = function()
                cache.disableButtons = true
                BJI.Tx.votemap.stop()
            end,
        })
    end
    line:build()
end
