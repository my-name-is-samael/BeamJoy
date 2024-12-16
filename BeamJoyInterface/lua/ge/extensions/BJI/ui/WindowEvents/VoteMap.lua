local function draw(ctxt)
    local vm = BJIVote.Map
    local creator = BJIContext.Players[vm.creatorID]
    local creatorName = creator and creator.playerName or BJILang.get("common.unknown")

    LineBuilder()
        :text(creatorName,
            BJIContext.User.playerID == vm.creatorID and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
        :text(BJILang.get("votemap.hasStarted"))
        :text(vm.mapLabel)
        :text(vm.mapCustom and svar("({1})", { BJILang.get("votemap.targetMapCustom") }) or "")
        :build()
    local delayLabel
    local remainingTime = vm.endsAt - ctxt.now
    if remainingTime < 1000 then
        delayLabel = BJILang.get("votekick.voteAboutToEnd")
    else
        delayLabel = svar(BJILang.get("votekick.voteTimeout"),
            { delay = PrettyDelay(math.floor(remainingTime / 1000)) })
    end
    LineBuilder()
        :text(svar("{1}/{2}", { vm.amountVotes, vm.threshold }))
        :text(delayLabel)
        :build()
    local line = LineBuilder()
        :btnIconToggle({
            id = "voteMap",
            icon = vm.selfVoted and ICONS.event_busy or ICONS.event_available,
            state = not vm.selfVoted,
            onClick = function()
                BJITx.votemap.vote()
            end
        })
    if BJIPerm.isStaff() then
        line:btnIcon({
            id = "stopVoteMap",
            icon = ICONS.cancel,
            style = BTN_PRESETS.ERROR,
            onClick = BJITx.votemap.stop,
        })
    end
    line:build()
end
return draw
