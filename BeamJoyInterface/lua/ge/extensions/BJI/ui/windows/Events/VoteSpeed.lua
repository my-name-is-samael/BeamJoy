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
            :btnIconToggle({
                id = "joinSpeed",
                icon = vs.participants[BJI.Managers.Context.User.playerID] and
                    ICONS.exit_to_app or ICONS.videogame_asset,
                state = not vs.participants[BJI.Managers.Context.User.playerID],
                tooltip = vs.participants[BJI.Managers.Context.User.playerID] and
                    cache.buttons.spectate or cache.buttons.join,
                disabled = not ctxt.isOwner or cache.disableButtons,
                big = true,
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
