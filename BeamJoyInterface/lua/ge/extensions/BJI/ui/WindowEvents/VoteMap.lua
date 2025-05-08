return function(ctxt, cache)
    local vm = BJIVote.Map
    LineBuilder()
        :text(cache.creator,
            BJIContext.User.playerID == vm.creatorID and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
        :text(cache.hasStarted)
        :text(vm.mapLabel)
        :text(cache.mapCustom)
        :build()
    local remainingTime = vm.endsAt - ctxt.now
    local delayLabel = remainingTime < 1000 and cache.voteAboutEnd or cache.timeout
        :var({ delay = PrettyDelay(math.floor(remainingTime / 1000)) })
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
                BJITx.votemap.vote()
            end
        })
    if BJIPerm.isStaff() then
        line:btnIcon({
            id = "stopVoteMap",
            icon = ICONS.cancel,
            style = BTN_PRESETS.ERROR,
            disabled = cache.stopDisabled,
            onClick = function()
                cache.stopDisabled = true
                BJITx.votemap.stop()
            end,
        })
    end
    line:build()
end
