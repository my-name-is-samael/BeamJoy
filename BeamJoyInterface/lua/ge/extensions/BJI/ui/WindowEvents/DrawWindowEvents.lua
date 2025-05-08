local cache = {
    kick = {
        hasStarted = "",
        voteAboutEnd = "",
        timeout = "",

        creator = "",
        target = "",
        votes = "",
        voteDisabled = false,
        stopDisabled = false,
    },
    map = {
        hasStarted = "",
        voteAboutEnd = "",
        timeout = "",

        creator = "",
        mapCustom = "",
        votes = "",
        voteDisabled = false,
        stopDisabled = false,
    },
    race = {
        hasStarted = "",
        title = "",
        settings = "",
        timeWeather = "",
        record = "",
        votes = "",
        timeAboutEnd = "",
        timeout = "",
        showVoteBtn = false,
        voteDisabled = false,
        stopDisabled = false,
    },
    speed = {
        hasStarted = "",
        timeAboutEnd = "",
        timeout = "",
        votes = "",
        showVoteBtn = false,
        voteDisabled = false,
        participants = "",
    },
}

---@param ctxt? TickContext
local function updateCaches(ctxt)
    LogWarn("EVENTS CACHE UPDATE")
    ctxt = ctxt or BJITick.getContext()

    if BJIVote.Kick.started() then
        cache.kick.hasStarted = BJILang.get("votekick.hasStarted")
        cache.kick.voteAboutEnd = BJILang.get("votekick.voteAboutToEnd")
        cache.kick.timeout = BJILang.get("votekick.voteTimeout")

        cache.kick.creator = BJIVote.Kick.creatorID and
            BJIContext.Players[BJIVote.Kick.creatorID].playerName or
            BJILang.get("races.preparation.defaultPlayerName")
        cache.kick.target = BJIVote.Kick.targetID and
            BJIContext.Players[BJIVote.Kick.targetID].playerName or
            BJILang.get("races.preparation.defaultPlayerName")
        cache.kick.votes = string.var("{1}/{2}", { BJIVote.Kick.amountVotes, BJIVote.Kick.threshold })
        cache.kick.voteDisabled = BJIVote.Kick.targetID == ctxt.user.playerID
        cache.kick.stopDisabled = false
    end

    if BJIVote.Map.started() then
        cache.map.hasStarted = BJILang.get("votemap.hasStarted")
        cache.map.voteAboutEnd = BJILang.get("votemap.voteAboutToEnd")
        cache.map.timeout = BJILang.get("votemap.voteTimeout")

        local creator = BJIContext.Players[BJIVote.Map.creatorID]
        cache.map.creator = creator and creator.playerName or BJILang.get("races.preparation.defaultPlayerName")
        cache.map.mapCustom = BJIVote.Map.mapCustom and string.var("({1})",
            { BJILang.get("votemap.targetMapCustom") }) or ""
        cache.map.votes = string.var("{1}/{2}", { BJIVote.Map.amountVotes, BJIVote.Map.threshold })
        cache.map.voteDisabled = false
        cache.map.stopDisabled = false
    end

    if BJIVote.Race.started() then
        local creator = BJIContext.Players[BJIVote.Race.creatorID]
        local creatorName = creator and creator.playerName or BJILang.get("races.preparation.defaultPlayerName")
        cache.race.hasStarted = BJILang.get(BJIVote.Race.isVote and
                "races.preparation.hasStartedVote" or "races.preparation.hasStarted")
            :var({ creatorName = creatorName, raceName = BJIVote.Race.raceName, places = BJIVote.Race.places })
        cache.race.title = string.var("{1}:", { BJILang.get("races.settings.title") })

        local settings = Table()
        if BJIVote.Race.laps then
            settings:insert(BJIVote.Race.laps > 1 and
                BJILang.get("races.settings.laps"):var({ laps = BJIVote.Race.laps }) or
                BJILang.get("races.settings.lap"):var({ lap = BJIVote.Race.laps }))
        end
        if not BJIVote.Race.model then
            settings:insert(BJILang.get("races.settings.vehicles.all"))
        else
            local model = BJIVeh.getModelLabel(BJIVote.Race.model)
            if not BJIVote.Race.specificConfig then
                settings:insert(model)
            else
                settings:insert(BJILang.get("races.settings.vehicles.specific")
                    :var({ model = model }))
            end
        end
        settings:insert(string.var("{1}: {2}", {
            BJILang.get("races.settings.respawnStrategies.respawns"),
            BJILang.get(string.var("races.settings.respawnStrategies.{1}", { BJIVote.Race.respawnStrategy }))
        }))
        cache.race.settings = settings:join(", ")

        cache.race.timeWeather = nil
        if BJIVote.Race.timeLabel or BJIVote.Race.weatherLabel then
            cache.race.timeWeather = Table({
                BJIVote.Race.timeLabel and string.var("{1}: {2}",
                    { BJILang.get("environment.ToD"), BJILang.get(string.var("presets.time.{1}",
                        { BJIVote.Race.timeLabel })) }) or nil,
                BJIVote.Race.weatherLabel and string.var("{1}: {2}",
                    { BJILang.get("environment.weather"), BJILang.get(string.var("presets.weather.{1}",
                        { BJIVote.Race.weatherLabel })) }) or nil
            }):join(BJILang.get("common.vSeparator"))
        end

        cache.race.record = nil
        if type(BJIVote.Race.record) == "table" then
            cache.race.record = BJILang.get("races.play.record"):var({
                playerName = BJIVote.Race.record.playerName,
                model = BJIVeh.getModelLabel(BJIVote.Race.record.model) or BJIVote.Race.record.model,
                time = RaceDelay(BJIVote.Race.record.time)
            })
        end

        cache.race.votes = nil
        if BJIVote.Race.isVote then
            cache.race.votes = string.var("{1}: {2}/{3}",
                { BJILang.get("races.preparation.currentVotes"), BJIVote.Race.amountVotes, BJIVote.Race.threshold })
        end
        cache.race.timeAboutEnd = BJILang.get(BJIVote.Race.isVote and
            "races.preparation.voteAboutToEnd" or "races.preparation.raceAboutToStart")
        cache.race.timeout = BJILang.get(BJIVote.Race.isVote and
            "races.preparation.voteTimeout" or "races.preparation.startTimeout")

        cache.race.showVoteBtn = BJIVote.Race.isVote or BJIVote.Race.creatorID == ctxt.user.playerID
        cache.race.voteDisabled = false
        cache.race.stopDisabled = false
    end

    if BJIVote.Speed.started() then
        local creator = BJIContext.Players[BJIVote.Speed.creatorID]
        local creatorName = creator and creator.playerName or BJILang.get("races.preparation.defaultPlayerName")
        cache.speed.hasStarted = BJILang.get(BJIVote.Speed.isEvent and
                "speed.vote.hasStarted" or "speed.vote.hasStartedVote")
            :var({ creatorName = creatorName })
        cache.speed.timeAboutEnd = BJILang.get(BJIVote.Speed.isEvent and
            "speed.vote.speedAboutToStart" or "speed.vote.voteAboutToEnd")
        cache.speed.timeout = BJILang.get(BJIVote.Speed.isEvent and
            "speed.vote.voteTimeout" or "speed.vote.voteTimeout")
        cache.speed.showVoteBtn = not BJIVote.Speed.isEvent
        cache.speed.voteDisabled = false
        cache.speed.participants = string.var("{1}: {2}", {
            BJILang.get("speed.vote.participants"),
            Table(BJIVote.Speed.participants):map(function(_, pid)
                return BJIContext.Players[pid].playerName
            end):join(", "),
        })
    end
    dump(cache)
end

local listeners = Table()
local function onLoad()
    updateCaches()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.VOTE_UPDATED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, updateCaches))
end

local function onUnload()
    listeners:forEach(BJIEvents.removeListener)
end

local votes = Table({
    {
        drawFn = require("ge/extensions/BJI/ui/WindowEvents/VoteKick"),
        show = BJIVote.Kick.started,
        cache = cache.kick
    },
    {
        drawFn = require("ge/extensions/BJI/ui/WindowEvents/VoteMap"),
        show = BJIVote.Map.started,
        cache = cache.map
    },
    {
        drawFn = require("ge/extensions/BJI/ui/WindowEvents/RacePreparation"),
        show = BJIVote.Race.started,
        cache = cache.race
    },
    {
        drawFn = require("ge/extensions/BJI/ui/WindowEvents/VoteSpeed"),
        show = BJIVote.Speed.started,
        cache = cache.speed
    },
})

local function body(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.event_note,
            big = true,
        })
        :build()

    votes:clone()
        :filter(function(v)
            return v.show()
        end)
        :forEach(function(v, i, tab)
            v.drawFn(ctxt, v.cache)
            if i < #tab then
                Separator()
            end
        end)
end

return {
    flags = function()
        return {
            WINDOW_FLAGS.NO_COLLAPSE
        }
    end,
    onLoad = onLoad,
    onUnload = onUnload,
    body = body,
}
