local function draw(ctxt)
    local vk = BJIVote.Kick
    local creator = BJIContext.Players[vk.creatorID]
    local creatorName = creator and creator.playerName or BJILang.get("common.unknown")
    local target = BJIContext.Players[vk.targetID]
    local targetName = target and target.playerName or BJILang.get("common.unknown")

    LineBuilder()
        :text(creatorName,
            BJIContext.User.playerID == vk.creatorID and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
        :text(BJILang.get("votekick.hasStarted"))
        :text(targetName,
            BJIContext.User.playerID == vk.targetID and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
        :build()
    local delayLabel
    local remainingTime = vk.endsAt - ctxt.now
    if remainingTime < 1000 then
        delayLabel = BJILang.get("votekick.voteAboutToEnd")
    else
        delayLabel = BJILang.get("votekick.voteTimeout")
            :var({ delay = PrettyDelay(math.floor(remainingTime / 1000)) })
    end
    LineBuilder()
        :text(string.var("{1}/{2}", { vk.amountVotes, vk.threshold }))
        :text(delayLabel)
        :build()
    local line = LineBuilder()
        :btnIconToggle({
            id = "voteKick",
            icon = vk.selfVoted and ICONS.event_busy or ICONS.event_available,
            state = not vk.selfVoted,
            onClick = function()
                BJITx.votekick.vote()
            end
        })
    if BJIPerm.isStaff() then
        line:btnIcon({
            id = "stopVoteKick",
            icon = ICONS.cancel,
            style = BTN_PRESETS.ERROR,
            onClick = BJITx.votekick.stop,
        })
    end
    line:build()
end
return draw
