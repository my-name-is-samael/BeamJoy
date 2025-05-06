local function draw(ctxt)
    local voteRace = BJIVote.Race
    local creator = BJIContext.Players[voteRace.creatorID]
    local creatorName = creator and creator.playerName or BJILang.get("races.preparation.defaultPlayerName")
    if voteRace.isVote then
        LineBuilder()
            :text(BJILang.get("races.preparation.hasStartedVote")
                :var({ creatorName = creatorName, raceName = voteRace.raceName, places = voteRace.places }))
            :build()
    else
        LineBuilder()
            :text(BJILang.get("races.preparation.hasStarted")
                :var({ creatorName = creatorName, raceName = voteRace.raceName, places = voteRace.places }))
            :build()
    end

    LineBuilder()
        :text(string.var("{1}:", { BJILang.get("races.settings.title") }))
        :build()
    local settings = {}
    if voteRace.laps then
        local laps = voteRace.laps
        table.insert(settings,
            voteRace.laps > 1 and
            BJILang.get("races.settings.laps"):var({ laps = laps }) or
            BJILang.get("races.settings.lap"):var({ lap = laps }))
    end

    if not voteRace.model then
        table.insert(settings, BJILang.get("races.settings.vehicles.all"))
    elseif not voteRace.specificConfig then
        table.insert(settings, BJIVeh.getModelLabel(voteRace.model))
    else
        table.insert(settings, BJILang.get("races.settings.vehicles.specific")
            :var({ model = BJIVeh.getModelLabel(voteRace.model) }))
    end

    local rs = BJILang.get(string.var("races.settings.respawnStrategies.{1}",
        { voteRace.respawnStrategy }))
    table.insert(settings, string.var("{1}: {2}", { BJILang.get("races.settings.respawnStrategies.respawns"), rs }))

    LineBuilder()
        :text(table.join(settings, ", "))
        :build()

    local time = voteRace.timeLabel
    local weather = voteRace.weatherLabel
    if time or weather then
        local line = LineBuilder()
        if time then
            line:text(string.var("{1}: {2}",
                { BJILang.get("environment.ToD"), BJILang.get(string.var("presets.time.{1}", { time })) }))
        end
        if weather then
            if time then
                line:text(BJILang.get("common.vSeparator"))
            end
            line:text(string.var("{1}: {2}",
                { BJILang.get("environment.weather"), BJILang.get(string.var("presets.weather.{1}", { weather })) }))
        end

        line:build()
    end

    if voteRace.record then
        local record = voteRace.record or {}
        local modelName = BJIVeh.getModelLabel(record.model)
        if modelName then
            LineBuilder()
                :text(BJILang.get("races.play.record"):var({
                    playerName = record.playerName,
                    model = modelName,
                    time = RaceDelay(record.time)
                }))
                :build()
        end
    end

    local remainingTime = voteRace.endsAt - ctxt.now
    if voteRace.isVote then
        local labelDelay
        if remainingTime < 1000 then
            labelDelay = BJILang.get("races.preparation.voteAboutToEnd")
        else
            labelDelay = BJILang.get("races.preparation.voteTimeout")
                :var({ delay = PrettyDelay(math.floor(remainingTime / 1000)) })
        end
        LineBuilder()
            :text(string.var("{1}: {2}/{3}",
                { BJILang.get("races.preparation.currentVotes"), voteRace.amountVotes, voteRace.threshold }))
            :text(labelDelay)
            :build()
        local line = LineBuilder()
            :btnIconToggle({
                id = "voteRace",
                icon = voteRace.selfVoted and ICONS.event_busy or ICONS.event_available,
                state = not voteRace.selfVoted,
                onClick = BJITx.voterace.vote,
            })
        if BJIPerm.isStaff() then
            line:btnIcon({
                id = "stopVoteRace",
                icon = ICONS.cancel,
                style = BTN_PRESETS.ERROR,
                onClick = BJITx.voterace.stop,
            })
        end
        line:build()
    else
        local labelDelay
        if remainingTime < 1000 then
            labelDelay = BJILang.get("races.preparation.raceAboutToStart")
        else
            labelDelay = BJILang.get("races.preparation.startTimeout")
                :var({ delay = PrettyDelay(math.floor(remainingTime / 1000)) })
        end
        LineBuilder()
            :text(labelDelay)
            :build()

        if BJIPerm.isStaff() then
            LineBuilder()
                :btnIcon({
                    id = "stopStartRace",
                    icon = ICONS.cancel,
                    style = BTN_PRESETS.ERROR,
                    onClick = BJITx.voterace.stop,
                })
                :build()
        elseif voteRace.creatorID == BJIContext.User.playerID
            and remainingTime > 2 then
            -- creator and staff can stop race start
            LineBuilder()
                :btnIcon({
                    id = "cancelRaceStart",
                    icon = ICONS.cancel,
                    style = BTN_PRESETS.ERROR,
                    onClick = BJITx.voterace.vote,
                })
                :build()
        end
    end
end
return draw
