---@class BJIWindowDerby : BJIWindow
local W = {
    name = "Derby",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 300,
    h = 280,

    labels = {
        arenaName = "",
        places = "",

        preparationTimeoutAboutToEnd = "",
        preparationTimeoutIn = "",
        readyMark = "",
        notReadyMark = "",

        startsIn = "",
        flashStart = "",
        resetIn = "",
        eliminatedIn = "",
        amountLives = "",
        amountLife = "",

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

        -- common
        arenaName = "",
        places = "",
        disableButtons = false,

        -- preparation
        preparationTimeout = 0,
        isParticipant = false,
        isReady = false,
        showPreparationActions = false,
        showReadyBtn = false,
        preparationParticipants = Table(),
        showPreparationConfigs = false,
        preparationConfigs = Table(),

        -- game
        showStartTime = false,
        startTime = 0,
        lives = 0,
        showForfeitBtn = false,
        showManualResetBtn = false,
        manualResetWidth = 0,
        gameLeaderboardCols = ColumnsBuilder("BJIDerbyLeaderboard", {}),
        gameLeaderboardNamesWidth = 0,
    },
    ---@type BJIScenarioDerby
    scenario = nil,
}

local function updateLabels()
    W.labels.arenaName = BJI.Managers.Lang.get("derby.play.arenaName")
    W.labels.places = BJI.Managers.Lang.get("derby.settings.places")

    W.labels.preparationTimeoutAboutToEnd = BJI.Managers.Lang.get("derby.play.preparationTimeoutAboutToEnd")
    W.labels.preparationTimeoutIn = BJI.Managers.Lang.get("derby.play.preparationTimeoutIn")
    W.labels.readyMark = string.var(" ({1})", { BJI.Managers.Lang.get("derby.play.readyMark") })
    W.labels.notReadyMark = string.var(" ({1})", { BJI.Managers.Lang.get("derby.play.notReadyMark") })

    W.labels.startsIn = BJI.Managers.Lang.get("derby.play.gameStartsIn")
    W.labels.flashStart = BJI.Managers.Lang.get("derby.play.flashStart")
    W.labels.resetIn = BJI.Managers.Lang.get("derby.play.resetIn")
    W.labels.eliminatedIn = BJI.Managers.Lang.get("derby.play.eliminatedIn")
    W.labels.amountLives = BJI.Managers.Lang.get("derby.play.amountLives")
    W.labels.amountLife = BJI.Managers.Lang.get("derby.play.amountLife")

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

    if not W.cache.showPreparation and not W.cache.showGame then
        return
    end

    W.cache.arenaName = W.labels.arenaName:var({ name = W.scenario.baseArena.name })
    W.cache.places = W.labels.places:var({ places = #W.scenario.baseArena.startPositions })
    W.cache.disableButtons = not BJI.Managers.Perm.canSpawnVehicle()

    local participant = W.scenario.getParticipant()
    W.cache.preparationTimeout = W.scenario.preparationTimeout
    W.cache.isParticipant = participant ~= nil
    W.cache.isReady = participant and participant.ready
    W.cache.showPreparationActions = BJI.Managers.Perm.canSpawnVehicle() and not W.cache.isReady and (
        not BJI.Managers.Tournament.state or not BJI.Managers.Tournament.whitelist or
        BJI.Managers.Tournament.whitelistPlayers:includes(ctxt.user.playerName)
    )
    W.cache.showReadyBtn = W.cache.isParticipant and not W.cache.isReady
    W.cache.preparationParticipants = Table()
    W.cache.preparationConfigs = Table()
    if W.cache.showPreparation then
        W.cache.preparationParticipants = Table(W.scenario.participants):map(function(p)
            return {
                name = ctxt.players[p.playerID].playerName,
                nameColor = p.playerID == BJI.Managers.Context.User.playerID and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                    BJI.Utils.Style.TEXT_COLORS.DEFAULT,
                nameSuffix = p.ready and W.labels.readyMark or W.labels.notReadyMark,
                suffixColor = p.ready and BJI.Utils.Style.TEXT_COLORS.SUCCESS or BJI.Utils.Style.TEXT_COLORS.DEFAULT,
            }
        end)

        W.cache.showPreparationConfigs = W.cache.isParticipant and not W.cache.isReady and #W.scenario.configs > 1
        if W.cache.showPreparationConfigs then
            W.cache.preparationConfigs = Table(W.scenario.configs):clone()
        end
    end

    W.cache.startTime = W.scenario.startTime
    W.cache.showStartTime = W.cache.showStartTime ~= nil
    W.cache.lives = participant and participant.lives or 0
    W.cache.showForfeitBtn = W.cache.isParticipant and not W.scenario.isEliminated()
    W.cache.manualResetWidth = 0
    W.cache.gameLeaderboardCols = ColumnsBuilder("BJIDerbyLeaderboard", {})
    if W.cache.showGame then
        W.cache.showManualResetBtn = participant ~= nil and participant.lives > 0
        if W.cache.showManualResetBtn then
            W.cache.manualResetWidth = BJI.Utils.UI.GetBtnIconSize(true) + BJI.Utils.UI.GetTextWidth("  ")
        end
        W.cache.gameLeaderboardNamesWidth = 0
        local selfSpec = not W.scenario.isParticipant() or W.scenario.isEliminated()
        ---@param p BJIDerbyParticipant
        local cols = Table(W.scenario.participants):map(function(p)
            local name, nameColor = ctxt.players[p.playerID].playerName,
                p.playerID == BJI.Managers.Context.User.playerID and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                BJI.Utils.Style.TEXT_COLORS.DEFAULT
            local w = BJI.Utils.UI.GetColumnTextWidth(name) + BJI.Utils.UI.GetBtnIconSize()
            if w > W.cache.gameLeaderboardNamesWidth then
                W.cache.gameLeaderboardNamesWidth = w
            end
            local suffix, suffixColor = "", p.playerID == BJI.Managers.Context.User.playerID and
                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
            if p.eliminationTime then
                suffix = BJI.Utils.UI.RaceDelay(p.eliminationTime)
                suffixColor = BJI.Utils.Style.TEXT_COLORS.ERROR
            else
                suffix = string.var("({1})", {
                    (p.lives > 1 and W.labels.amountLives or W.labels.amountLife):var({ amount = p.lives })
                })
            end
            return {
                function()
                    local line = LineBuilder()
                    if selfSpec then
                        line:btnIcon({
                            id = "focus" .. tostring(p.playerID),
                            icon = BJI.Utils.Icon.ICONS.visibility,
                            disabled = BJI.Managers.Context.User.currentVehicle == p.gameVehID or
                                W.scenario.isEliminated(p.playerID),
                            onClick = function()
                                BJI.Managers.Veh.focusVehicle(p.gameVehID)
                            end,
                        })
                    end
                    line:text(name, nameColor):build()
                end,
                function()
                    LineLabel(suffix, suffixColor)
                end,
            }
        end)
        W.cache.gameLeaderboardCols = ColumnsBuilder("BJIDerbyLeaderboard", { W.cache.gameLeaderboardNamesWidth, -1 })
        cols:forEach(function(el)
            W.cache.gameLeaderboardCols:addRow({ cells = el })
        end)
    end
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DERBY)

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function(ctxt)
            if W.cache.showGame and not BJI.Managers.Perm.canSpawnVehicle() then
                -- permission loss
                BJI.Tx.scenario.DerbyUpdate(W.scenario.CLIENT_EVENTS.LEAVE)
            end
        end, W.name .. "AutoLeave"))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        function(ctxt)
            if W.scenario.getParticipant() and BJI.Managers.Tournament.whitelist and
                not BJI.Managers.Tournament.whitelistPlayers:includes(ctxt.user.playerName) then
                -- got out of whitelist
                BJI.Tx.scenario.DerbyUpdate(W.scenario.state == W.scenario.STATES.PREPARATION and
                    W.scenario.CLIENT_EVENTS.JOIN or W.scenario.CLIENT_EVENTS.LEAVE)
            end
        end, W.name .. "AutoLeaveTournament"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param targetTime integer
---@param now integer
---@return integer
local function getDiffTime(targetTime, now)
    return math.ceil((targetTime - now) / 1000)
end

local function drawHeaderPreparation(ctxt)
    if W.cache.preparationTimeout then
        local remainingTime = getDiffTime(W.cache.preparationTimeout, ctxt.now)
        LineLabel(remainingTime < 1 and W.labels.preparationTimeoutAboutToEnd or
            W.labels.preparationTimeoutIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingTime) }),
            remainingTime < 3 and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
    else
        EmptyLine()
    end

    if W.cache.showPreparationActions then
        local line = LineBuilder():btnIconToggle({
            id = "joinDerby",
            icon = W.cache.isParticipant and BJI.Utils.Icon.ICONS.exit_to_app or BJI.Utils.Icon.ICONS.videogame_asset,
            big = true,
            state = not W.cache.isParticipant,
            disabled = W.cache.disableButtons,
            tooltip = W.cache.isParticipant and W.labels.buttons.spectate or W.labels.buttons.join,
            onClick = function()
                W.cache.disableButtons = true -- api request protection
                BJI.Tx.scenario.DerbyUpdate(W.scenario.CLIENT_EVENTS.JOIN)
            end
        })
        if W.cache.showReadyBtn then
            line:btnIcon({
                id = "readyDerby",
                icon = BJI.Utils.Icon.ICONS.check,
                big = true,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = not ctxt.isOwner or W.cache.disableButtons,
                tooltip = W.labels.buttons.markReady,
                onClick = function()
                    W.cache.disableButtons = true -- api request protection
                    BJI.Tx.scenario.DerbyUpdate(W.scenario.CLIENT_EVENTS.READY, ctxt.veh:getID())
                end
            })
        end
        line:build()
    end
end

local function drawHeaderGame(ctxt)
    ColumnsBuilder("BJIDerbyHeader", { -1, W.cache.manualResetWidth }):addRow({
        cells = {
            function()
                local line = LineBuilder()
                if W.cache.showForfeitBtn and W.cache.startTime < ctxt.now then
                    line:btnIcon({
                        id = "leaveDerby",
                        icon = BJI.Utils.Icon.ICONS.exit_to_app,
                        big = true,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        disabled = W.cache.disableButtons,
                        tooltip = W.labels.buttons.forfeit,
                        onClick = function()
                            W.cache.disableButtons = true
                            BJI.Tx.scenario.DerbyUpdate(W.scenario.CLIENT_EVENTS.LEAVE, ctxt.now - W.cache.startTime)
                            BJI.Tx.player.explodeVehicle(W.scenario.getParticipant().gameVehID)
                        end
                    })
                end

                line:icon({
                    icon = BJI.Utils.Icon.ICONS.timer,
                    big = true,
                })
                if W.cache.startTime and W.cache.startTime + 3000 > ctxt.now then -- START COUNTDOWN
                    local remainingTime = getDiffTime(W.cache.startTime, ctxt.now)
                    line:text(remainingTime > 0 and
                        W.labels.startsIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingTime) }) or
                        W.labels.flashStart)
                elseif W.cache.isParticipant and W.scenario.destroy.process then -- DNF COUNTDOWN
                    local remainingTime = getDiffTime(W.scenario.destroy.targetTime, ctxt.now)
                    line:text((W.cache.lives > 0 and W.labels.resetIn or W.labels.eliminatedIn)
                        :var({ delay = BJI.Utils.UI.PrettyDelay(remainingTime) }))
                end

                line:build()
            end,
            W.cache.showManualResetBtn and function()
                LineBuilder():btnIcon({
                    id = "manualReset",
                    icon = BJI.Utils.Icon.ICONS.build,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    big = true,
                    disabled = W.scenario.resetLock,
                    tooltip = string.var("{1} ({2})", {
                        W.labels.buttons.manualReset,
                        extensions.core_input_bindings.getControlForAction("loadHome"):capitalizeWords()
                    }),
                    onClick = function()
                        BJI.Managers.Veh.loadHome()
                    end,
                }):build()
            end or nil,
        }
    }):build()
end

local function header(ctxt)
    LineBuilder():text(W.cache.arenaName):text(W.cache.places):build()

    if W.cache.showPreparation then
        drawHeaderPreparation(ctxt)
    elseif W.cache.showGame then
        drawHeaderGame(ctxt)
    end
end

local function body(ctxt)
    if W.cache.showPreparation then
        W.cache.preparationParticipants:forEach(function(p)
            LineBuilder():text(p.name):text(p.nameSuffix, p.suffixColor):build()
        end)

        W.cache.preparationConfigs:forEach(function(c, i)
            LineBuilder():btnIcon({
                id = string.var("spawnConfig{1}", { i }),
                icon = BJI.Utils.Icon.ICONS.carSensors,
                style = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.disableButtons,
                tooltip = ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn,
                onClick = function() W.scenario.tryReplaceOrSpawn(c.model, c) end,
            }):text(c.label):build()
        end)
    elseif W.cache.showGame then
        W.cache.gameLeaderboardCols:build()
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.getState = function()
    return BJI.Managers.Cache.areBaseCachesFirstLoaded() and
        BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.DERBY)
end

return W
