return function(ctxt, cache)
    local vr = BJI.Managers.Votes.Race
    LineBuilder():text(cache.hasStarted):build()
    LineBuilder():text(cache.title):build()
    LineBuilder():text(cache.settings):build()

    if cache.record then
        LineBuilder():text(cache.record):build()
    end

    local line = LineBuilder()
    if cache.votes then
        line:text(cache.votes)
    end
    local remainingTime = vr.endsAt - ctxt.now
    line:text(remainingTime < 1000 and cache.timeAboutEnd or cache.timeout
        :var({ delay = BJI.Utils.Common.PrettyDelay(math.floor(remainingTime / 1000)) }))
        :build()

    if cache.showVoteBtn or BJI.Managers.Perm.isStaff() then
        line = LineBuilder()
        if cache.showVoteBtn then
            line:btnIconToggle({
                id = "voteRace",
                icon = vr.isVote and
                    (vr.selfVoted and ICONS.event_busy or ICONS.event_available) or
                    ICONS.cancel,
                state = not vr.selfVoted,
                tooltip = vr.isVote and
                    (vr.selfVoted and cache.buttons.unvote or cache.buttons.vote) or
                    cache.buttons.stop,
                disabled = cache.disableButtons,
                big = true,
                onClick = function()
                    cache.disableButtons = true
                    BJI.Tx.voterace.vote()
                end,
            })
        end
        if BJI.Managers.Perm.isStaff() and vr.isVote or not cache.showVoteBtn then
            line:btnIcon({
                id = "stopPrepRace",
                icon = ICONS.cancel,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                tooltip = cache.buttons.stop,
                disabled = cache.disableButtons,
                big = true,
                onClick = function()
                    cache.disableButtons = true
                    BJI.Tx.voterace.stop()
                end,
            })
        end
        line:build()
    end
end
