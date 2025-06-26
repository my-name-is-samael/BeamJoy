local W = {
    name = "Events",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 480,
    h = 250,

    kick = {
        hasStarted = "",
        voteAboutEnd = "",
        timeout = "",
        buttons = {
            vote = "",
            unvote = "",
            stop = "",
        },

        creator = "",
        target = "",
        votes = "",
        disableButtons = false,
    },
    map = {
        hasStarted = "",
        voteAboutEnd = "",
        timeout = "",
        buttons = {
            vote = "",
            unvote = "",
            stop = "",
        },

        creator = "",
        mapCustom = "",
        votes = "",
        disableButtons = false,
    },
    race = {
        hasStarted = "",
        title = "",
        settings = "",
        record = "",
        votes = "",
        timeAboutEnd = "",
        timeout = "",
        buttons = {
            vote = "",
            unvote = "",
            stop = "",
        },

        showVoteBtn = false,
        disableButtons = false,
    },
    speed = {
        hasStarted = "",
        timeAboutEnd = "",
        timeout = "",
        votes = "",
        buttons = {
            join = "",
            spectate = "",
        },

        showVoteBtn = false,
        disableButtons = false,
        participants = "",
    },
}

---@type table<integer, table>
local votes = {
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteKick"),
        show = BJI.Managers.Votes.Kick.started,
        cache = W.kick
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteMap"),
        show = BJI.Managers.Votes.Map.started,
        cache = W.map
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/RacePreparation"),
        show = BJI.Managers.Votes.Race.started,
        cache = W.race
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteSpeed"),
        show = BJI.Managers.Votes.Speed.started,
        cache = W.speed
    },
}

---@param ctxt? TickContext
local function updateCaches(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    if votes[1].show() then
        W.kick.hasStarted = BJI.Managers.Lang.get("votekick.hasStarted")
        W.kick.voteAboutEnd = BJI.Managers.Lang.get("votekick.voteAboutToEnd")
        W.kick.timeout = BJI.Managers.Lang.get("votekick.voteTimeout")
        W.kick.buttons.vote = BJI.Managers.Lang.get("common.buttons.vote")
        W.kick.buttons.unvote = BJI.Managers.Lang.get("common.buttons.unvote")
        W.kick.buttons.stop = BJI.Managers.Lang.get("common.buttons.stopVote")

        W.kick.creator = BJI.Managers.Votes.Kick.creatorID and
            ctxt.players[BJI.Managers.Votes.Kick.creatorID].playerName or
            BJI.Managers.Lang.get("races.preparation.defaultPlayerName")
        W.kick.target = BJI.Managers.Votes.Kick.targetID and
            ctxt.players[BJI.Managers.Votes.Kick.targetID].playerName or
            BJI.Managers.Lang.get("races.preparation.defaultPlayerName")
        W.kick.votes = string.var("{1}/{2}", { BJI.Managers.Votes.Kick.amountVotes, BJI.Managers.Votes.Kick.threshold })
        W.kick.voteDisabled = BJI.Managers.Votes.Kick.targetID == ctxt.user.playerID
        W.kick.disableButtons = false
    end

    if votes[2].show() then
        W.map.hasStarted = BJI.Managers.Lang.get("votemap.hasStarted")
        W.map.voteAboutEnd = BJI.Managers.Lang.get("votemap.voteAboutToEnd")
        W.map.timeout = BJI.Managers.Lang.get("votemap.voteTimeout")
        W.map.buttons.vote = BJI.Managers.Lang.get("common.buttons.vote")
        W.map.buttons.unvote = BJI.Managers.Lang.get("common.buttons.unvote")
        W.map.buttons.stop = BJI.Managers.Lang.get("common.buttons.stopVote")

        local creator = ctxt.players[BJI.Managers.Votes.Map.creatorID]
        W.map.creator = creator and creator.playerName or
            BJI.Managers.Lang.get("races.preparation.defaultPlayerName")
        W.map.mapCustom = BJI.Managers.Votes.Map.mapCustom and string.var("({1})",
            { BJI.Managers.Lang.get("votemap.targetMapCustom") }) or ""
        W.map.votes = string.var("{1}/{2}", { BJI.Managers.Votes.Map.amountVotes, BJI.Managers.Votes.Map.threshold })
        W.map.disableButtons = false
    end

    if votes[3].show() then
        local creator = ctxt.players[BJI.Managers.Votes.Race.creatorID]
        local creatorName = creator and creator.playerName or
            BJI.Managers.Lang.get("races.preparation.defaultPlayerName")
        W.race.hasStarted = BJI.Managers.Lang.get(BJI.Managers.Votes.Race.isVote and
                "races.preparation.hasStartedVote" or "races.preparation.hasStarted")
            :var({
                creatorName = creatorName,
                raceName = BJI.Managers.Votes.Race.raceName,
                places = BJI.Managers.Votes
                    .Race.places
            })
        W.race.title = string.var("{1}:", { BJI.Managers.Lang.get("races.settings.title") })

        local settings = Table()
        if BJI.Managers.Votes.Race.laps then
            settings:insert(BJI.Managers.Votes.Race.laps > 1 and
                BJI.Managers.Lang.get("races.settings.laps"):var({ laps = BJI.Managers.Votes.Race.laps }) or
                BJI.Managers.Lang.get("races.settings.lap"):var({ lap = BJI.Managers.Votes.Race.laps }))
        end
        if not BJI.Managers.Votes.Race.model then
            settings:insert(BJI.Managers.Lang.get("races.settings.vehicles.all"))
        else
            local model = BJI.Managers.Veh.getModelLabel(BJI.Managers.Votes.Race.model)
            if not BJI.Managers.Votes.Race.specificConfig then
                settings:insert(model)
            else
                settings:insert(BJI.Managers.Lang.get("races.settings.vehicles.specific")
                    :var({ model = model }))
            end
        end
        settings:insert(string.var("{1}: {2}", {
            BJI.Managers.Lang.get("races.settings.collisions"),
            BJI.Managers.Votes.Race.collisions and BJI.Managers.Lang.get("common.enabled") or
            BJI.Managers.Lang.get("common.disabled")
        }))
        settings:insert(string.var("{1}: {2}", {
            BJI.Managers.Lang.get("races.settings.respawnStrategies.respawns"),
            BJI.Managers.Lang.get(string.var("races.settings.respawnStrategies.{1}",
                { BJI.Managers.Votes.Race.respawnStrategy }))
        }))
        W.race.settings = settings:join(", ")

        W.race.record = nil
        if type(BJI.Managers.Votes.Race.record) == "table" then
            W.race.record = BJI.Managers.Lang.get("races.play.record"):var({
                playerName = BJI.Managers.Votes.Race.record.playerName,
                model = BJI.Managers.Veh.getModelLabel(BJI.Managers.Votes.Race.record.model) or
                    BJI.Managers.Votes.Race.record.model,
                time = BJI.Utils.UI.RaceDelay(BJI.Managers.Votes.Race.record.time)
            })
        end

        W.race.votes = nil
        if BJI.Managers.Votes.Race.isVote then
            W.race.votes = string.var("{1}: {2}/{3}",
                { BJI.Managers.Lang.get("races.preparation.currentVotes"), BJI.Managers.Votes.Race.amountVotes, BJI
                    .Managers.Votes.Race.threshold })
        end
        W.race.timeAboutEnd = BJI.Managers.Lang.get(BJI.Managers.Votes.Race.isVote and
            "races.preparation.voteAboutToEnd" or "races.preparation.raceAboutToStart")
        W.race.timeout = BJI.Managers.Lang.get(BJI.Managers.Votes.Race.isVote and
            "races.preparation.voteTimeout" or "races.preparation.startTimeout")

        W.race.showVoteBtn = BJI.Managers.Votes.Race.isVote or BJI.Managers.Votes.Race.creatorID == ctxt.user.playerID
        W.race.disableButtons = false

        W.race.buttons.vote = BJI.Managers.Lang.get("common.buttons.vote")
        W.race.buttons.unvote = BJI.Managers.Lang.get("common.buttons.unvote")
        W.race.buttons.stop = BJI.Managers.Lang.get("common.buttons.cancel")
    end

    if votes[4].show() then
        local creator = ctxt.players[BJI.Managers.Votes.Speed.creatorID]
        local creatorName = creator and creator.playerName or
            BJI.Managers.Lang.get("races.preparation.defaultPlayerName")
        W.speed.hasStarted = BJI.Managers.Lang.get(BJI.Managers.Votes.Speed.isEvent and
                "speed.vote.hasStarted" or "speed.vote.hasStartedVote")
            :var({ creatorName = creatorName })
        W.speed.timeAboutEnd = BJI.Managers.Lang.get(BJI.Managers.Votes.Speed.isEvent and
            "speed.vote.speedAboutToStart" or "speed.vote.voteAboutToEnd")
        W.speed.timeout = BJI.Managers.Lang.get(BJI.Managers.Votes.Speed.isEvent and
            "speed.vote.voteTimeout" or "speed.vote.voteTimeout")
        W.speed.showVoteBtn = not BJI.Managers.Votes.Speed.isEvent
        W.speed.disableButtons = false
        W.speed.participants = string.var("{1}: {2}", {
            BJI.Managers.Lang.get("speed.vote.participants"),
            Table(BJI.Managers.Votes.Speed.participants):map(function(_, pid)
                return ctxt.players[pid].playerName
            end):join(", "),
        })

        W.speed.buttons.join = BJI.Managers.Lang.get("common.buttons.join")
        W.speed.buttons.spectate = BJI.Managers.Lang.get("common.buttons.spectate")
    end
end

local listeners = Table()
local function onLoad()
    updateCaches()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.VOTE_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCaches, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body(ctxt)
    LineBuilder()
        :icon({
            icon = BJI.Utils.Icon.ICONS.event_note,
            big = true,
        })
        :build()

    Table(votes):filter(function(v)
        return v.show()
    end):forEach(function(v, i, tab)
        v.drawFn(ctxt, v.cache)
        if i < #tab then
            Separator()
        end
    end)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body
W.getState = function()
    return Table(votes):any(function(v) return v.show() end)
end

return W
