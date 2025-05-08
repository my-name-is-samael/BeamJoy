return function(ctxt, cache)
    local vs = BJIVote.Speed
    LineBuilder():text(cache.hasStarted):build()

    local remainingTime = vs.endsAt - ctxt.now
    LineBuilder()
        :text(remainingTime < 1000 and cache.timeAboutEnd or cache.timeout
            :var({ delay = PrettyDelay(math.floor(remainingTime / 1000)) }))
        :build()

    if cache.showVoteBtn then
        LineBuilder()
            :btnSwitch({
                id = "voteRace",
                labelOn = BJILang.get("speed.vote.join"),
                labelOff = BJILang.get("speed.vote.leave"),
                state = not vs.participants[BJIContext.User.playerID],
                disabled = not ctxt.isOwner or cache.voteDisabled,
                onClick = function()
                    cache.voteDisabled = true
                    BJITx.scenario.SpeedJoin(not vs.participants[BJIContext.User.playerID] and
                        ctxt.veh:getID() or nil)
                end,
            })
            :build()
    end

    LineBuilder():text(cache.participants):build()
end
