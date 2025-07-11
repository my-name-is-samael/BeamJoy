local W = {
    name = "Events",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
        BJI.Utils.Style.WINDOW_FLAGS.ALWAYS_AUTO_RESIZE,
    },

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
        showCancelBtn = false,
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
        showCancelBtn = false,
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
        showCancelBtn = false,
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
            stop = "",
        },

        showVoteBtn = false,
        showCancelBtn = false,
        disableButtons = false,
        participants = "",
    },
    hunter = {
        hasStarted = "",
        settings = "",
        votes = "",
        timeAboutEnd = "",
        timeout = "",
        buttons = {
            vote = "",
            unvote = "",
            stop = "",
        },

        showVoteBtn = false,
        showCancelBtn = false,
        disableButtons = false,
    },
    infected = {
        hasStarted = "",
        settings = "",
        votes = "",
        timeAboutEnd = "",
        timeout = "",
        buttons = {
            vote = "",
            unvote = "",
            stop = "",
        },

        showVoteBtn = false,
        showCancelBtn = false,
        disableButtons = false,
    },
    derby = {
        hasStarted = "",
        settings = "",
        votes = "",
        timeAboutEnd = "",
        timeout = "",
        buttons = {
            vote = "",
            unvote = "",
            stop = "",
        },

        showVoteBtn = false,
        showCancelBtn = false,
        disableButtons = false,
    },
}

---@type tablelib<integer, table>
local votes = Table({
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteKick"),
        show = BJI_Votes.Kick.started,
        cache = W.kick
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteMap"),
        show = BJI_Votes.Map.started,
        cache = W.map
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteScenario/VoteScenarioRace"),
        show = function()
            return BJI_Votes.Scenario.started() and
                BJI_Votes.Scenario.type == BJI_Votes.SCENARIO_TYPES.RACE
        end,
        cache = W.race
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteScenario/VoteScenarioSpeed"),
        show = function()
            return BJI_Votes.Scenario.started() and
                BJI_Votes.Scenario.type == BJI_Votes.SCENARIO_TYPES.SPEED
        end,
        cache = W.speed
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteScenario/VoteScenarioGeneric"),
        show = function()
            return BJI_Votes.Scenario.started() and
                BJI_Votes.Scenario.type == BJI_Votes.SCENARIO_TYPES.HUNTER
        end,
        cache = W.hunter
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteScenario/VoteScenarioGeneric"),
        show = function()
            return BJI_Votes.Scenario.started() and
                BJI_Votes.Scenario.type == BJI_Votes.SCENARIO_TYPES.INFECTED
        end,
        cache = W.infected
    },
    {
        drawFn = require("ge/extensions/BJI/ui/windows/Events/VoteScenario/VoteScenarioGeneric"),
        show = function()
            return BJI_Votes.Scenario.started() and
                BJI_Votes.Scenario.type == BJI_Votes.SCENARIO_TYPES.DERBY
        end,
        cache = W.derby
    },
})

---@param ctxt? TickContext
local function updateCaches(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    if votes[1].show() then -- kick
        W.kick.hasStarted = BJI_Lang.get("votekick.hasStarted")
        W.kick.voteAboutEnd = BJI_Lang.get("votekick.voteAboutToEnd")
        W.kick.timeout = BJI_Lang.get("votekick.voteTimeout")
        W.kick.buttons.vote = BJI_Lang.get("common.buttons.vote")
        W.kick.buttons.unvote = BJI_Lang.get("common.buttons.unvote")
        W.kick.buttons.stop = BJI_Lang.get("common.buttons.stopVote")

        W.kick.creator = BJI_Votes.Kick.creatorID and
            ctxt.players[BJI_Votes.Kick.creatorID].playerName or
            BJI_Lang.get("common.defaultPlayerName")
        W.kick.target = BJI_Votes.Kick.targetID and
            ctxt.players[BJI_Votes.Kick.targetID].playerName or
            BJI_Lang.get("common.defaultPlayerName")
        W.kick.votes = string.var("{1}/{2}", { BJI_Votes.Kick.amountVotes, BJI_Votes.Kick.threshold })
        W.kick.voteDisabled = BJI_Votes.Kick.targetID == ctxt.user.playerID
        W.kick.showCancelBtn = BJI_Perm.isStaff() or
            BJI_Votes.Kick.creatorID == ctxt.user.playerID
        W.kick.disableButtons = false
    end

    if votes[2].show() then -- map
        W.map.hasStarted = BJI_Lang.get("votemap.hasStarted")
        W.map.voteAboutEnd = BJI_Lang.get("votemap.voteAboutToEnd")
        W.map.timeout = BJI_Lang.get("votemap.voteTimeout")
        W.map.buttons.vote = BJI_Lang.get("common.buttons.vote")
        W.map.buttons.unvote = BJI_Lang.get("common.buttons.unvote")
        W.map.buttons.stop = BJI_Lang.get("common.buttons.stopVote")

        local creator = ctxt.players[BJI_Votes.Map.creatorID]
        W.map.creator = creator and creator.playerName or
            BJI_Lang.get("common.defaultPlayerName")
        W.map.mapCustom = BJI_Votes.Map.mapCustom and string.var("({1})",
            { BJI_Lang.get("votemap.targetMapCustom") }) or ""
        W.map.votes = string.var("{1}/{2}", { BJI_Votes.Map.amountVotes, BJI_Votes.Map.threshold })
        W.map.showCancelBtn = BJI_Perm.isStaff() or
            BJI_Votes.Map.creatorID == ctxt.user.playerID
        W.map.disableButtons = false
    end

    if votes[3].show() then -- race
        local creator = ctxt.players[BJI_Votes.Scenario.creatorID]
        local creatorName = creator and creator.playerName or
            BJI_Lang.get("common.defaultPlayerName")
        W.race.hasStarted = BJI_Lang.get(BJI_Votes.Scenario.isVote and
                "races.preparation.hasStartedVote" or "races.preparation.hasStarted")
            :var({
                creatorName = creatorName,
                raceName = BJI_Votes.Scenario.scenarioData.raceName,
                places = BJI_Votes
                    .Scenario.scenarioData.places
            })
        W.race.title = string.var("{1}:", { BJI_Lang.get("races.settings.title") })

        local settings = Table()
        if BJI_Votes.Scenario.scenarioData.settings.laps then
            settings:insert(BJI_Votes.Scenario.scenarioData.settings.laps > 1 and
                BJI_Lang.get("races.settings.laps"):var({
                    laps = BJI_Votes.Scenario.scenarioData
                        .settings.laps
                }) or
                BJI_Lang.get("races.settings.lap"):var({
                    lap = BJI_Votes.Scenario.scenarioData
                        .settings.laps
                }))
        end
        if not BJI_Votes.Scenario.scenarioData.settings.model then
            settings:insert(BJI_Lang.get("races.settings.vehicles.all"))
        else
            local model = BJI_Veh.getModelLabel(BJI_Votes.Scenario.scenarioData.settings.model)
            if not BJI_Votes.Scenario.scenarioData.settings.config then
                settings:insert(model)
            else
                settings:insert(BJI_Lang.get("races.settings.vehicles.specific")
                    :var({ model = model }))
            end
        end
        settings:insert(string.var("{1}: {2}", {
            BJI_Lang.get("races.settings.collisions"),
            BJI_Votes.Scenario.scenarioData.settings.collisions and BJI_Lang.get("common.enabled") or
            BJI_Lang.get("common.disabled")
        }))
        settings:insert(string.var("{1}: {2}", {
            BJI_Lang.get("races.settings.respawnStrategies.respawns"),
            BJI_Lang.get(string.var("races.settings.respawnStrategies.{1}",
                { BJI_Votes.Scenario.scenarioData.settings.respawnStrategy }))
        }))
        W.race.settings = settings:join(", ")

        W.race.record = nil
        if type(BJI_Votes.Scenario.scenarioData.record) == "table" then
            W.race.record = BJI_Lang.get("races.play.record"):var({
                playerName = BJI_Votes.Scenario.scenarioData.record.playerName,
                model = BJI_Veh.getModelLabel(BJI_Votes.Scenario.scenarioData.record.model) or
                    BJI_Votes.Scenario.scenarioData.record.model,
                time = BJI.Utils.UI.RaceDelay(BJI_Votes.Scenario.scenarioData.record.time)
            })
        end

        W.race.votes = nil
        if BJI_Votes.Scenario.isVote then
            W.race.votes = string.var("{1}: {2}/{3}",
                { BJI_Lang.get("races.preparation.currentVotes"),
                    BJI_Votes.Scenario.amountVotes,
                    BJI_Votes.Scenario.threshold })
        end
        W.race.timeAboutEnd = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "races.preparation.voteAboutToEnd" or "races.preparation.raceAboutToStart")
        W.race.timeout = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "races.preparation.voteTimeout" or "races.preparation.startTimeout")

        W.race.showVoteBtn = BJI_Votes.Scenario.isVote
        W.race.showCancelBtn = BJI_Perm.isStaff() or
            BJI_Votes.Scenario.creatorID == ctxt.user.playerID
        W.race.disableButtons = false

        W.race.buttons.vote = BJI_Lang.get("common.buttons.vote")
        W.race.buttons.unvote = BJI_Lang.get("common.buttons.unvote")
        W.race.buttons.stop = BJI_Lang.get("common.buttons.cancel")
    end

    if votes[4].show() then -- speed
        local creator = ctxt.players[BJI_Votes.Scenario.creatorID]
        local creatorName = creator and creator.playerName or
            BJI_Lang.get("common.defaultPlayerName")
        W.speed.hasStarted = BJI_Lang.get(BJI_Votes.Scenario.isVote and
                "speed.vote.hasStartedVote" or "speed.vote.hasStarted")
            :var({ creatorName = creatorName })
        W.speed.timeAboutEnd = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "speed.vote.voteAboutToEnd" or "speed.vote.speedAboutToStart")
        W.speed.timeout = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "speed.vote.voteTimeout" or "speed.vote.voteTimeout")
        W.speed.showVoteBtn = BJI_Votes.Scenario.isVote
        W.speed.showCancelBtn = BJI_Perm.isStaff() or
            BJI_Votes.Scenario.creatorID == ctxt.user.playerID
        W.speed.disableButtons = false
        W.speed.participants = string.var("{1}: {2}", {
            BJI_Lang.get("speed.vote.participants"),
            Table(BJI_Votes.Scenario.voters):map(function(_, pid)
                return ctxt.players[pid].playerName
            end):join(", "),
        })

        W.speed.buttons.join = BJI_Lang.get("common.buttons.join")
        W.speed.buttons.spectate = BJI_Lang.get("common.buttons.spectate")
        W.speed.buttons.stop = BJI_Lang.get("common.buttons.cancel")
    end

    if votes[5].show() then -- hunter
        local creator = ctxt.players[BJI_Votes.Scenario.creatorID]
        local creatorName = creator and creator.playerName or
            BJI_Lang.get("common.defaultPlayerName")
        W.hunter.hasStarted = BJI_Lang.get(BJI_Votes.Scenario.isVote and
                "hunter.vote.hasStartedVote" or "hunter.vote.hasStarted")
            :var({ creatorName = creatorName, places = BJI_Votes.Scenario.scenarioData.places })

        local settings = Table()
        if BJI_Votes.Scenario.scenarioData.huntedConfig then
            settings:insert(string.var("{1}: {2}", {
                BJI_Lang.get("hunter.settings.huntedConfig"),
                BJI_Lang.get("common.enabled"),
            }))
        end
        if #BJI_Votes.Scenario.scenarioData.hunterConfigs > 0 then
            settings:insert(string.var("{1}: {2}", {
                BJI_Lang.get("hunter.settings.hunterConfigs"),
                #BJI_Votes.Scenario.scenarioData.hunterConfigs,
            }))
        end
        settings:insert(string.var("{1}: {2}", {
            BJI_Lang.get("hunter.settings.lastWaypointGPS"),
            BJI_Lang.get(BJI_Votes.Scenario.scenarioData.lastWaypointGPS and
                "common.enabled" or "common.disabled"),
        }))
        W.hunter.settings = settings:join(", ")

        W.hunter.votes = nil
        if BJI_Votes.Scenario.isVote then
            W.hunter.votes = string.var("{1}: {2}/{3}",
                { BJI_Lang.get("hunter.vote.currentVotes"),
                    BJI_Votes.Scenario.amountVotes,
                    BJI_Votes.Scenario.threshold })
        end
        W.hunter.timeAboutEnd = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "hunter.vote.voteAboutToEnd" or "hunter.vote.aboutToStart")
        W.hunter.timeout = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "hunter.vote.voteTimeout" or "hunter.vote.timeout")

        W.hunter.showVoteBtn = BJI_Votes.Scenario.isVote
        W.hunter.showCancelBtn = BJI_Perm.isStaff() or
            BJI_Votes.Scenario.creatorID == ctxt.user.playerID
        W.hunter.disableButtons = false

        W.hunter.buttons.vote = BJI_Lang.get("common.buttons.vote")
        W.hunter.buttons.unvote = BJI_Lang.get("common.buttons.unvote")
        W.hunter.buttons.stop = BJI_Lang.get("common.buttons.cancel")
    end

    if votes[6].show() then -- infected
        local creator = ctxt.players[BJI_Votes.Scenario.creatorID]
        local creatorName = creator and creator.playerName or
            BJI_Lang.get("common.defaultPlayerName")
        W.infected.hasStarted = BJI_Lang.get(BJI_Votes.Scenario.isVote and
                "infected.vote.hasStartedVote" or "infected.vote.hasStarted")
            :var({ creatorName = creatorName, places = BJI_Votes.Scenario.scenarioData.places })

        local settings = Table()
        settings:insert(string.var("{1}: {2}", {
            BJI_Lang.get("infected.settings.endAfterLastSurvivorInfected"),
            BJI_Lang.get(BJI_Votes.Scenario.scenarioData.endAfterLastSurvivorInfected and
                "common.enabled" or "common.disabled"),
        }))
        if BJI_Votes.Scenario.scenarioData.config then
            settings:insert(string.var("{1}: {2}", {
                BJI_Lang.get("infected.settings.config"),
                BJI_Lang.get("common.enabled"),
            }))
        end
        settings:insert(string.var("{1}: {2}", {
            BJI_Lang.get("infected.settings.enableColors"),
            BJI_Lang.get(BJI_Votes.Scenario.scenarioData.enableColors and
                "common.enabled" or "common.disabled"),
        }))
        W.infected.settings = settings:join(", ")

        W.infected.votes = nil
        if BJI_Votes.Scenario.isVote then
            W.infected.votes = string.var("{1}: {2}/{3}",
                { BJI_Lang.get("infected.vote.currentVotes"),
                    BJI_Votes.Scenario.amountVotes,
                    BJI_Votes.Scenario.threshold })
        end
        W.infected.timeAboutEnd = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "infected.vote.voteAboutToEnd" or "infected.vote.aboutToStart")
        W.infected.timeout = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "infected.vote.voteTimeout" or "infected.vote.timeout")

        W.infected.showVoteBtn = BJI_Votes.Scenario.isVote
        W.infected.showCancelBtn = BJI_Perm.isStaff() or
            BJI_Votes.Scenario.creatorID == ctxt.user.playerID
        W.infected.disableButtons = false

        W.infected.buttons.vote = BJI_Lang.get("common.buttons.vote")
        W.infected.buttons.unvote = BJI_Lang.get("common.buttons.unvote")
        W.infected.buttons.stop = BJI_Lang.get("common.buttons.cancel")
    end

    if votes[7].show() then -- derby
        local creator = ctxt.players[BJI_Votes.Scenario.creatorID]
        local creatorName = creator and creator.playerName or
            BJI_Lang.get("common.defaultPlayerName")
        W.derby.hasStarted = BJI_Lang.get(BJI_Votes.Scenario.isVote and
                "derby.vote.hasStartedVote" or "derby.vote.hasStarted")
            :var({
                creatorName = creatorName,
                arenaName = BJI_Votes.Scenario.scenarioData.arenaName,
                places = BJI_Votes.Scenario.scenarioData.places
            })

        W.derby.settings = (BJI_Votes.Scenario.scenarioData.lives < 2 and
                BJI_Lang.get("derby.play.amountLife") or
                BJI_Lang.get("derby.play.amountLives"))
            :var({ amount = BJI_Votes.Scenario.scenarioData.lives })

        W.derby.votes = nil
        if BJI_Votes.Scenario.isVote then
            W.derby.votes = string.var("{1}: {2}/{3}",
                { BJI_Lang.get("derby.vote.currentVotes"),
                    BJI_Votes.Scenario.amountVotes,
                    BJI_Votes.Scenario.threshold })
        end
        W.derby.timeAboutEnd = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "derby.vote.voteAboutToEnd" or "derby.vote.aboutToStart")
        W.derby.timeout = BJI_Lang.get(BJI_Votes.Scenario.isVote and
            "derby.vote.voteTimeout" or "derby.vote.timeout")

        W.derby.showVoteBtn = BJI_Votes.Scenario.isVote
        W.derby.showCancelBtn = BJI_Perm.isStaff() or
            BJI_Votes.Scenario.creatorID == ctxt.user.playerID
        W.derby.disableButtons = false

        W.derby.buttons.vote = BJI_Lang.get("common.buttons.vote")
        W.derby.buttons.unvote = BJI_Lang.get("common.buttons.unvote")
        W.derby.buttons.stop = BJI_Lang.get("common.buttons.cancel")
    end
end

local listeners = Table()
local function onLoad()
    updateCaches()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.VOTE_UPDATED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCaches, W.name))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function body(ctxt)
    Icon(BJI.Utils.Icon.ICONS.event_note, { big = true })

    votes:filter(function(v)
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
    return votes:any(function(v) return v.show() end)
end

return W
