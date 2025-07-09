--- gc prevention
local mgr, remainingTime

return function(ctxt, cache)
    if not mgr then
        mgr = BJI.Managers.Votes.Scenario
    end

    Text(cache.hasStarted)

    remainingTime = mgr.endsAt - ctxt.now
    Text(remainingTime < 1000 and cache.timeAboutEnd or cache.timeout
        :var({ delay = BJI.Utils.UI.PrettyDelay(math.floor(remainingTime / 1000)) }))

    if cache.showVoteBtn then
        if IconButton("joinSpeed", mgr.voters[BJI.Managers.Context.User.playerID] and
                BJI.Utils.Icon.ICONS.exit_to_app or BJI.Utils.Icon.ICONS.videogame_asset,
                { disabled = not ctxt.isOwner or cache.disableButtons, big = true,
                    btnStyle = mgr.voters[BJI.Managers.Context.User.playerID] and
                        BJI.Utils.Style.BTN_PRESETS.ERROR or BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            cache.disableButtons = true
            BJI.Tx.vote.ScenarioVote(ctxt.veh.gameVehicleID)
        end
        TooltipText(mgr.voters[BJI.Managers.Context.User.playerID] and
            cache.buttons.spectate or cache.buttons.join)
    end
    if cache.showCancelBtn then
        if cache.showVoteBtn then
            SameLine()
        end
        if IconButton("stopSpeed", BJI.Utils.Icon.ICONS.cancel, { disabled = cache.disableButtons,
                big = true, btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            cache.disableButtons = true
            BJI.Tx.vote.ScenarioStop()
        end
        TooltipText(cache.buttons.stop)
    end

    Text(cache.participants)
end
