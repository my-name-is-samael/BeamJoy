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
        gameLeaderboardCols = Table(),
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
end

---@param ctxt? TickContext
local function updateCache(ctxt)
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
    W.cache.showPreparationActions = BJI.Managers.Perm.canSpawnVehicle() and not W.cache.isReady
    W.cache.showReadyBtn = W.cache.isParticipant and not W.cache.isReady
    W.cache.preparationParticipants = Table()
    W.cache.preparationConfigs = Table()
    if W.cache.showPreparation then
        W.cache.preparationParticipants = Table(W.scenario.participants):map(function(p)
            return {
                name = BJI.Managers.Context.Players[p.playerID].playerName,
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
    W.cache.gameLeaderboardCols = Table()
    if W.cache.showGame then
        W.cache.gameLeaderboardNamesWidth = 0
        W.cache.gameLeaderboardCols = Table(W.scenario.participants):map(function(p)
            local name, nameColor = BJI.Managers.Context.Players[p.playerID].playerName,
                p.playerID == BJI.Managers.Context.User.playerID and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                BJI.Utils.Style.TEXT_COLORS.DEFAULT
            local w = BJI.Utils.Common.GetColumnTextWidth(name)
            if w > W.cache.gameLeaderboardNamesWidth then
                W.cache.gameLeaderboardNamesWidth = w
            end
            local suffix, suffixColor = "", BJI.Utils.Style.TEXT_COLORS.DEFAULT
            if p.eliminationTime then
                suffix = BJI.Utils.Common.RaceDelay(p.eliminationTime)
                suffixColor = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
            elseif p.lives > 0 then
                suffix = string.var("({1})", {
                    (p.lives > 1 and W.labels.amountLives or W.labels.amountLife):var({ amount = p.lives })
                })
            end
            return {
                cells = {
                    function()
                        LineLabel(name, nameColor)
                    end,
                    function()
                        LineLabel(suffix, suffixColor)
                    end,
                }
            }
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
    end, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function(ctxt)
            if W.cache.showGame and not BJI.Managers.Perm.canSpawnVehicle() then
                -- permission loss
                BJI.Tx.scenario.DerbyUpdate(W.scenario.CLIENT_EVENTS.LEAVE, ctxt.now - W.cache.startTime)
            end
        end, W.name))
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
    local remainingTime = getDiffTime(W.cache.preparationTimeout, ctxt.now)
    LineLabel(remainingTime < 1 and W.labels.preparationTimeoutAboutToEnd or
        W.labels.preparationTimeoutIn:var({ delay = BJI.Utils.Common.PrettyDelay(remainingTime) }),
        remainingTime < 3 and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)

    if W.cache.showPreparationActions then
        local line = LineBuilder()
            :btnIconToggle({
                id = "joinDerby",
                icon = W.cache.isParticipant and ICONS.exit_to_app or ICONS.videogame_asset,
                state = not W.cache.isParticipant,
                big = true,
                disabled = W.cache.disableButtons,
                onClick = function()
                    W.cache.disableButtons = true -- api request protection
                    BJI.Tx.scenario.DerbyUpdate(W.scenario.CLIENT_EVENTS.JOIN)
                end
            })
        if W.cache.showReadyBtn then
            line:btnIcon({
                id = "readyDerby",
                icon = ICONS.check,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                big = true,
                disabled = not ctxt.isOwner or W.cache.disableButtons,
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
    local line = LineBuilder()
    if W.cache.showForfeitBtn and W.cache.startTime < ctxt.now then
        line:btnIcon({
            id = "leaveDerby",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            big = true,
            disabled = W.cache.disableButtons,
            onClick = function()
                W.cache.disableButtons = true
                BJI.Tx.scenario.DerbyUpdate(W.scenario.CLIENT_EVENTS.LEAVE, ctxt.now - W.cache.startTime)
                BJI.Tx.player.explodeVehicle(W.scenario.getParticipant().gameVehID)
            end
        })
    end

    line:icon({
        icon = ICONS.timer,
        big = true,
    })
    -- START COUNTDOWN / DNF COUNTDOWN
    if W.cache.startTime and W.cache.startTime + 3000 > ctxt.now then
        local remainingTime = getDiffTime(W.cache.startTime, ctxt.now)
        line:text(remainingTime > 0 and W.labels.startsIn:var({ delay = BJI.Utils.Common.PrettyDelay(remainingTime) }) or
            W.labels.flashStart)
    elseif W.cache.isParticipant and W.scenario.destroy.process then
        local remainingTime = getDiffTime(W.scenario.destroy.targetTime, ctxt.now)
        line:text((W.cache.lives > 0 and W.labels.resetIn or W.labels.eliminatedIn)
            :var({ delay = BJI.Utils.Common.PrettyDelay(remainingTime) }))
    end

    line:build()
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
            LineBuilder()
                :text(p.name)
                :text(p.nameSuffix, p.suffixColor)
                :build()
        end)

        W.cache.preparationConfigs:forEach(function(c, i)
            LineBuilder()
                :btnIcon({
                    id = string.var("spawnConfig{1}", { i }),
                    icon = ICONS.carSensors,
                    style = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableButtons,
                    onClick = function()
                        W.scenario.tryReplaceOrSpawn(c.model, c.config)
                    end
                })
                :text(c.label)
                :build()
        end)
    elseif W.cache.showGame then
        local cols = ColumnsBuilder("BJIDerbyLeaderboard", { W.cache.gameLeaderboardNamesWidth, -1 })
        W.cache.gameLeaderboardCols:forEach(function(col) cols:addRow(col) end)
        cols:build()
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
