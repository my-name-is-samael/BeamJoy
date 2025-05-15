return function(ctxt, cache)
    local vs = BJI.Managers.Votes.Speed
    LineBuilder():text(cache.hasStarted):build()

    local remainingTime = vs.endsAt - ctxt.now
    LineBuilder()
        :text(remainingTime < 1000 and cache.timeAboutEnd or cache.timeout
            :var({ delay = BJI.Utils.Common.PrettyDelay(math.floor(remainingTime / 1000)) }))
        :build()

    if cache.showVoteBtn then
        LineBuilder()
            :btnSwitch({
                id = "voteRace",
                labelOn = BJI.Managers.Lang.get("speed.vote.join"),
                labelOff = BJI.Managers.Lang.get("speed.vote.leave"),
                state = not vs.participants[BJI.Managers.Context.User.playerID],
                disabled = not ctxt.isOwner or cache.disableButtons,
                onClick = function()
                    cache.disableButtons = true
                    BJI.Tx.scenario.SpeedJoin(not vs.participants[BJI.Managers.Context.User.playerID] and
                        ctxt.veh:getID() or nil)
                end,
            })
            :build()
    end

    LineBuilder():text(cache.participants):build()
end
