local function draw(ctxt)
    local voteSpeed = BJIVote.Speed
    local creator = BJIContext.Players[voteSpeed.creatorID]
    local creatorName = creator and creator.playerName
    if voteSpeed.isEvent then
        LineBuilder()
            :text(svar(BJILang.get("speed.vote.hasStarted"), { creatorName = creatorName }))
            :build()
    else
        LineBuilder()
            :text(svar(BJILang.get("speed.vote.hasStartedVote"), { creatorName = creatorName }))
            :build()
    end

    local remainingTime = BJITick.applyTimeOffset(voteSpeed.endsAt) - ctxt.now
    if voteSpeed.isEvent then
        local labelDelay
        if remainingTime < 1000 then
            labelDelay = BJILang.get("speed.vote.speedAboutToStart")
        else
            labelDelay = svar(BJILang.get("speed.vote.timeout"),
                { delay = PrettyDelay(math.floor(remainingTime / 1000)) })
        end
        LineBuilder()
            :text(labelDelay)
            :build()
    else
        local labelDelay
        if remainingTime < 1000 then
            labelDelay = BJILang.get("speed.vote.voteAboutToEnd")
        else
            labelDelay = svar(BJILang.get("speed.vote.voteTimeout"),
                { delay = PrettyDelay(math.floor(remainingTime / 1000)) })
        end
        LineBuilder()
            :text(labelDelay)
            :build()
    end

    if not voteSpeed.isEvent then
        LineBuilder()
            :btnSwitch({
                id = "voteRace",
                labelOn = BJILang.get("speed.vote.join"),
                labelOff = BJILang.get("speed.vote.leave"),
                state = not voteSpeed.participants[BJIContext.User.playerID],
                disabled = not ctxt.isOwner,
                onClick = function()
                    local data
                    if not voteSpeed.participants[BJIContext.User.playerID] then
                        data = ctxt.veh:getID()
                    end
                    BJITx.scenario.SpeedJoin(data)
                end,
            })
            :build()
    end
    local participants = {}
    for playerID in pairs(voteSpeed.participants) do
        table.insert(participants, BJIContext.Players[playerID].playerName)
    end
    LineBuilder()
        :text(svar("{1}: {2}",
            { BJILang.get("speed.vote.participants"), table.concat(participants, ", ") }))
        :build()
end
return draw
