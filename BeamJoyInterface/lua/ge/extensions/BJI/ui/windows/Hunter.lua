---@class BJIWindowHunter : BJIWindow
local W = {
    name = "Hunter",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    w = 300,
    h = 280,

    labels = {
        hunted = "",
        hunters = "",

        preparationTimeoutAboutToEnd = "",
        preparationTimeoutIn = "",
        configChoose = "",
        readyMark = "",
        notReadyMark = "",

        playStartIn = "",
        startFlashHunted = "",
        flashStartHunter = "",
        huntedAboutToLoose = "",
        huntedLooseIn = "",
        hunterResumeIn = "",
        waypoints = "",

        buttons = {
            join = "",
            spectate = "",
            markReady = "",
            forfeit = "",
            spawn = "",
            replace = "",
            manualReset = "",
        },
    },
    cache = {
        showPreparation = false,
        showGame = false,
        disabledButtons = false,
        isParticipant = false,
        isHunted = false,
        playersList = Table(),
        waypointsReached = 0,
        waypointsTotal = 0,

        -- preparation
        ---@type integer|nil
        preparationTimeoutTargetTime = nil,
        isReady = false,
        showPreparationActions = false,
        showConfigs = false,

        -- game
        huntedID = 0,
        ---@type BJIPlayer?
        huntedPlayer = nil,
        showGameActions = false,
        showManualResetBtn = false,
        manualResetWidth = 0,
        startTime = 0,
    },
    ---@type BJIScenarioHunter
    scenario = nil,
}

local function updateLabels()
    W.labels.hunted = string.var("{1}:", { BJI.Managers.Lang.get("hunter.play.hunted") })
    W.labels.hunters = string.var("{1}:", { BJI.Managers.Lang.get("hunter.play.hunters") })

    W.labels.preparationTimeoutAboutToEnd = BJI.Managers.Lang.get("hunter.play.preparationTimeoutAboutToEnd")
    W.labels.preparationTimeoutIn = BJI.Managers.Lang.get("hunter.play.preparationTimeoutIn")
    W.labels.configChoose = string.var("{1}:", { BJI.Managers.Lang.get("hunter.play.configChoose") })
    W.labels.readyMark = string.var("({1})", { BJI.Managers.Lang.get("hunter.play.readyMark") })
    W.labels.notReadyMark = string.var("({1})", { BJI.Managers.Lang.get("hunter.play.notReadyMark") })

    W.labels.playStartIn = BJI.Managers.Lang.get("hunter.play.startIn")
    W.labels.startFlashHunted = BJI.Managers.Lang.get("hunter.play.flashHuntedStart")
    W.labels.flashStartHunter = BJI.Managers.Lang.get("hunter.play.flashHunterResume")
    W.labels.huntedAboutToLoose = BJI.Managers.Lang.get("hunter.play.huntedAboutToLoose")
    W.labels.huntedLooseIn = BJI.Managers.Lang.get("hunter.play.huntedLooseIn")
    W.labels.hunterResumeIn = BJI.Managers.Lang.get("hunter.play.hunterResumeIn")
    W.labels.waypoints = BJI.Managers.Lang.get("hunter.play.waypoints")

    W.labels.buttons.join = BJI.Managers.Lang.get("common.buttons.join")
    W.labels.buttons.spectate = BJI.Managers.Lang.get("common.buttons.spectate")
    W.labels.buttons.markReady = BJI.Managers.Lang.get("common.buttons.markReady")
    W.labels.buttons.forfeit = BJI.Managers.Lang.get("common.buttons.forfeit")
    W.labels.buttons.spawn = BJI.Managers.Lang.get("common.buttons.spawn")
    W.labels.buttons.replace = BJI.Managers.Lang.get("common.buttons.replace")
    W.labels.buttons.manualReset = BJI.Managers.Lang.get("common.buttons.manualReset")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.cache.showPreparation = W.scenario.state == W.scenario.STATES.PREPARATION
    W.cache.showGame = W.scenario.state == W.scenario.STATES.GAME
    W.cache.disabledButtons = not BJI.Managers.Perm.canSpawnVehicle()

    W.cache.isParticipant = not not W.scenario.participants[BJI.Managers.Context.User.playerID]
    W.cache.isHunted = W.cache.isParticipant and
        W.scenario.participants[BJI.Managers.Context.User.playerID].hunted

    W.cache.showConfigs = false
    if W.cache.showPreparation then
        W.cache.preparationTimeoutTargetTime = W.scenario.preparationTimeout
        W.cache.isReady = W.cache.isParticipant and W.scenario.participants[BJI.Managers.Context.User.playerID].ready
        W.cache.showPreparationActions = BJI.Managers.Perm.canSpawnVehicle() and not W.cache.isReady and (
            not BJI.Managers.Tournament.state or not BJI.Managers.Tournament.whitelist or
            BJI.Managers.Tournament.whitelistPlayers:includes(ctxt.user.playerName)
        )
        W.cache.showConfigs = W.cache.isParticipant and not W.cache.isReady and
            not W.cache.isHunted and #W.scenario.settings.hunterConfigs > 1
    end

    W.cache.huntedID = nil
    W.cache.huntedPlayer = nil
    W.cache.manualResetWidth = 0
    if W.cache.showGame then
        Table(W.scenario.participants):find(function(part) return part.hunted end,
            function(_, playerID)
                W.cache.huntedID = playerID
                W.cache.huntedPlayer = ctxt.players[playerID]
            end)
        W.cache.showGameActions = W.cache.isParticipant
        W.cache.startTime = W.cache.isHunted and W.scenario.huntedStartTime or W.scenario.hunterStartTime

        W.cache.showManualResetBtn = W.cache.isParticipant
        if W.cache.showManualResetBtn then
            W.cache.manualResetWidth = BJI.Utils.UI.GetBtnIconSize(true) + BJI.Utils.UI.GetTextWidth("  ")
        end
    end

    W.cache.playersList = Table(W.scenario.participants)
        :map(function(p, playerID)
            return {
                playerName = ctxt.players[playerID].playerName,
                self = playerID == ctxt.user.playerID,
                readyLabel = p.ready and W.labels.readyMark or W.labels.notReadyMark,
                color = p.ready and BJI.Utils.Style.TEXT_COLORS.SUCCESS or BJI.Utils.Style.TEXT_COLORS.ERROR,
                hunted = p.hunted,
            }
        end):values()
        :sort(function(a, b)
            -- sort hunted first
            if a.hunted or b.hunted then return a.hunted end
            -- then alphabetically
            return a.playerName < b.playerName
        end)
    W.cache.waypointsReached = W.cache.huntedID and W.scenario.participants[W.cache.huntedID].waypoint
    W.cache.waypointsTotal = W.scenario.settings.waypoints
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.HUNTER)

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        function(ctxt)
            if W.scenario.participants[ctxt.user.playerID] and BJI.Managers.Tournament.whitelist and
                not BJI.Managers.Tournament.whitelistPlayers:includes(ctxt.user.playerName) then
                -- got out of whitelist
                BJI.Tx.scenario.HunterUpdate(W.scenario.state == W.scenario.STATES.PREPARATION and
                    W.scenario.CLIENT_EVENTS.JOIN or W.scenario.CLIENT_EVENTS.LEAVE)
            end
        end, W.name .. "AutoLeaveTournament"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local sh

---@param targetTime integer
---@param now integer
---@return integer
local function getDiffTime(targetTime, now)
    return math.ceil((targetTime - now) / 1000)
end

---@param ctxt TickContext
local function drawHeaderPreparation(ctxt)
    if W.cache.preparationTimeoutTargetTime then
        local remaining = getDiffTime(W.cache.preparationTimeoutTargetTime, ctxt.now)
        local label = remaining < 1 and
            W.labels.preparationTimeoutAboutToEnd or
            W.labels.preparationTimeoutIn:var({ delay = BJI.Utils.UI.PrettyDelay(remaining) })
        LineLabel(label, remaining < 10 and
            BJI.Utils.Style.TEXT_COLORS.ERROR or
            BJI.Utils.Style.TEXT_COLORS.DEFAULT
        )
    else
        EmptyLine()
    end

    if W.cache.showPreparationActions then
        local line = LineBuilder():btnIconToggle({
            id = "joinParticipants",
            icon = W.cache.isParticipant and BJI.Utils.Icon.ICONS.exit_to_app or BJI.Utils.Icon.ICONS.videogame_asset,
            state = not W.cache.isParticipant,
            disabled = W.cache.disabledButtons,
            tooltip = W.cache.isParticipant and W.labels.buttons.spectate or W.labels.buttons.join,
            onClick = function()
                W.cache.disabledButtons = true -- api request protection
                BJI.Tx.scenario.HunterUpdate(W.scenario.CLIENT_EVENTS.JOIN)
            end,
            big = true,
        })
        if ctxt.isOwner and not W.cache.isReady then
            line:btnIcon({
                id = "readyHunter",
                icon = BJI.Utils.Icon.ICONS.check,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = not ctxt.isOwner or W.cache.disabledButtons,
                tooltip = W.labels.buttons.markReady,
                onClick = function()
                    W.cache.disabledButtons = true -- api request protection
                    BJI.Tx.scenario.HunterUpdate(W.scenario.CLIENT_EVENTS.READY, ctxt.veh:getID())
                end,
                big = true,
            })
        end
        line:build()
    end
end

---@param ctxt TickContext
local function drawHeaderGame(ctxt)
    if W.cache.showGameActions or W.cache.showManualResetBtn then
        ColumnsBuilder("HunterGameHeader", { -1, W.cache.manualResetWidth }):addRow({
            cells = {
                W.cache.showGameActions and function()
                    local line = LineBuilder():btnIcon({
                        id = "leaveHunter",
                        icon = BJI.Utils.Icon.ICONS.exit_to_app,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        disabled = W.cache.disabledButtons,
                        tooltip = W.labels.buttons.forfeit,
                        onClick = function()
                            W.cache.disabledButtons = true
                            BJI.Tx.scenario.HunterUpdate(
                                W.cache.huntedID == BJI.Managers.Context.User.playerID and
                                W.scenario.CLIENT_EVENTS.ELIMINATED or
                                W.scenario.CLIENT_EVENTS.LEAVE
                            )
                        end,
                        big = true,
                    })

                    local label, color
                    if W.cache.startTime and ctxt.now < W.cache.startTime + 3000 then
                        local remaining = getDiffTime(W.cache.startTime, ctxt.now)
                        if remaining > 0 then
                            label = W.labels.playStartIn:var({ delay = BJI.Utils.UI.PrettyDelay(remaining) })
                        else
                            label = W.cache.isHunted and W.labels.startFlashHunted or W.labels.flashStartHunter
                        end
                        color = remaining <= 3 and
                            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                            BJI.Utils.Style.TEXT_COLORS.DEFAULT
                    else
                        if W.cache.isHunted then
                            --DNF DISPLAY
                            if W.scenario.dnf.process and W.scenario.dnf.targetTime and
                                ctxt.now < W.scenario.dnf.targetTime then
                                local remaining = getDiffTime(W.scenario.dnf.targetTime, ctxt.now)
                                label = W.labels.huntedLooseIn:var({ delay = BJI.Utils.UI.PrettyDelay(remaining) })
                                color = remaining <= 3 and
                                    BJI.Utils.Style.TEXT_COLORS.ERROR or
                                    BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
                            end
                        else
                            --- respawn cooldown
                            if W.scenario.hunterRespawnTargetTime and ctxt.now < W.scenario.hunterRespawnTargetTime + 3000 then
                                local remaining = getDiffTime(W.scenario.hunterRespawnTargetTime, ctxt.now)
                                label = remaining >= 0 and
                                    W.labels.hunterResumeIn:var({ delay = BJI.Utils.UI.PrettyDelay(remaining) }) or
                                    W.labels.flashStartHunter
                                color = remaining <= 3 and
                                    BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                                    BJI.Utils.Style.TEXT_COLORS.DEFAULT
                            end
                        end
                    end
                    if label then
                        line:icon({
                            icon = BJI.Utils.Icon.ICONS.timer,
                            big = true,
                        }):text(label, color)
                    end
                    line:build()
                end or nil,
                W.cache.showManualResetBtn and function()
                    LineBuilder():btnIcon({
                        id = "manualReset",
                        icon = BJI.Utils.Icon.ICONS.build,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        big = true,
                        disabled = W.scenario.resetLock,
                        tooltip = string.var("{1} ({2})", {
                            W.labels.buttons.manualReset,
                            extensions.core_input_bindings.getControlForAction("recover_vehicle"):capitalizeWords()
                        }),
                        onClick = function()
                            BJI.Managers.Veh.recoverInPlace()
                        end,
                    }):build()
                end or nil,
            }
        }):build()
    end
end

---@param ctxt TickContext
local function drawHeader(ctxt)
    if W.cache.showPreparation then
        drawHeaderPreparation(ctxt)
    elseif W.cache.showGame then
        drawHeaderGame(ctxt)
    end
end

---@param ctxt TickContext
local function drawBodyPreparation(ctxt)
    if W.cache.showConfigs then
        LineLabel(W.labels.configChoose)
        Indent(1)
        Table(W.scenario.settings.hunterConfigs)
            :forEach(function(confData, i)
                LineBuilder():btnIcon({
                    id = string.var("spawnConfig{1}", { i }),
                    icon = ctxt.isOwner and BJI.Utils.Icon.ICONS.carSensors or BJI.Utils.Icon.ICONS.add,
                    style = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disabledButtons,
                    tooltip = ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn,
                    onClick = function()
                        W.scenario.tryReplaceOrSpawn(confData.model, confData)
                    end,
                }):text(confData.label):build()
            end)
        Indent(-1)
    end

    W.cache.playersList:forEach(function(p, i)
        if i < 3 then
            LineLabel(i == 1 and W.labels.hunted or W.labels.hunters)
            Indent(1)
        end
        LineBuilder():text(p.playerName, p.self and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
            BJI.Utils.Style.TEXT_COLORS.DEFAULT)
            :text(p.readyLabel, p.color):build()
        if i < 3 then
            Indent(-1)
        end
    end)
end

---@param ctxt TickContext
local function drawBodyGame(ctxt)
    W.cache.playersList:forEach(function(p, i)
        local color = p.self and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
            BJI.Utils.Style.TEXT_COLORS.DEFAULT
        if i == 1 then
            LineLabel(W.labels.hunted)
            LineLabel(string.var("{1} - {2}/{3} {4}", { p.playerName, W.cache.waypointsReached,
                W.cache.waypointsTotal, W.labels.waypoints }), color)
        else
            if i == 2 then
                LineLabel(W.labels.hunters)
                Indent(1)
            end
            LineLabel(p.playerName, color)
            if i == #W.cache.playersList then
                Indent(-1)
            end
        end
    end)
end

---@param ctxt TickContext
local function drawBody(ctxt)
    if W.cache.showPreparation then
        drawBodyPreparation(ctxt)
    elseif W.cache.showGame then
        drawBodyGame(ctxt)
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = drawHeader
W.body = drawBody
W.getState = function()
    return BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.HUNTER)
end

return W
