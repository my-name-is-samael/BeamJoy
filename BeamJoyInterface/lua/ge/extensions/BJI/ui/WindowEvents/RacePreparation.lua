return function(ctxt, cache)
    local vr = BJIVote.Race
    LineBuilder():text(cache.hasStarted):build()
    LineBuilder():text(cache.title):build()
    LineBuilder():text(cache.settings):build()

    if cache.timeWeather then
        LineBuilder():text(cache.timeWeather):build()
    end

    if cache.record then
        LineBuilder():text(cache.record):build()
    end

    local line = LineBuilder()
    if cache.votes then
        line:text(cache.votes)
    end
    local remainingTime = vr.endsAt - ctxt.now
    line:text(remainingTime < 1000 and cache.timeAboutEnd or cache.timeout
        :var({ delay = PrettyDelay(math.floor(remainingTime / 1000)) }))
        :build()

    if cache.showVoteBtn or BJIPerm.isStaff() then
        line = LineBuilder()
        if cache.showVoteBtn then
            line:btnIconToggle({
                id = "voteRace",
                icon = vr.isVote and
                    (vr.selfVoted and ICONS.event_busy or ICONS.event_available) or
                    ICONS.cancel,
                state = not vr.selfVoted,
                disabled = cache.voteDisabled,
                onClick = function()
                    cache.voteDisabled = true
                    BJITx.voterace.vote()
                end,
            })
        end
        if BJIPerm.isStaff() and vr.isVote or not cache.showVoteBtn then
            line:btnIcon({
                id = "stopPrepRace",
                icon = ICONS.cancel,
                style = BTN_PRESETS.ERROR,
                disabled = cache.stopDisabled,
                onClick = function()
                    cache.stopDisabled = true
                    BJITx.voterace.stop()
                end,
            })
        end
        line:build()
    end
end
