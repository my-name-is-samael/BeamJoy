local M = {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },

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

        -- preparation
        preparationTimeout = 0,
        isParticipant = false,
        isReady = false,
        showReadyBtn = false,
        disableJoinBtn = false,
        disableReadyBtn = false,
        preparationParticipants = Table(),
        showPreparationConfigs = false,
        preparationConfigs = Table(),

        -- game
        showStartTime = false,
        startTime = 0,
        lives = 0,
        showForfeitBtn = false,
        disableForfeitBtn = false,
        gameLeaderboardCols = Table(),
        gameLeaderboardNamesWidth = 0,
    },
    scenario = nil,
}

local function updateLabels()
    M.labels.arenaName = BJILang.get("derby.play.arenaName")
    M.labels.places = BJILang.get("derby.settings.places")

    M.labels.preparationTimeoutAboutToEnd = BJILang.get("derby.play.preparationTimeoutAboutToEnd")
    M.labels.preparationTimeoutIn = BJILang.get("derby.play.preparationTimeoutIn")
    M.labels.readyMark = string.var(" ({1})", { BJILang.get("derby.play.readyMark") })
    M.labels.notReadyMark = string.var(" ({1})", { BJILang.get("derby.play.notReadyMark") })

    M.labels.startsIn = BJILang.get("derby.play.gameStartsIn")
    M.labels.flashStart = BJILang.get("derby.play.flashStart")
    M.labels.resetIn = BJILang.get("derby.play.resetIn")
    M.labels.eliminatedIn = BJILang.get("derby.play.eliminatedIn")
    M.labels.amountLives = BJILang.get("derby.play.amountLives")
    M.labels.amountLife = BJILang.get("derby.play.amountLife")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    M.scenario = BJIScenario.get(BJIScenario.TYPES.DERBY)

    M.cache.showPreparation = M.scenario.state == M.scenario.STATES.PREPARATION
    M.cache.showGame = M.scenario.state == M.scenario.STATES.GAME

    M.cache.arenaName = M.labels.arenaName:var({ name = M.scenario.baseArena.name })
    M.cache.places = M.labels.places:var({ places = #M.scenario.baseArena.startPositions })

    local participant = M.scenario.getParticipant()
    M.cache.preparationTimeout = M.scenario.preparationTimeout
    M.cache.isParticipant = participant ~= nil
    M.cache.isReady = M.cache.isParticipant and participant.ready
    M.cache.showReadyBtn = M.cache.isParticipant and not M.cache.isReady
    M.cache.disableJoinBtn = false
    M.cache.disableReadyBtn = false
    M.cache.preparationParticipants = Table()
    M.cache.preparationConfigs = Table()
    if M.cache.showPreparation then
        M.cache.preparationParticipants = Table(M.scenario.participants):map(function(p)
            return {
                name = BJIContext.Players[p.playerID].playerName,
                nameColor = p.playerID == BJIContext.User.playerID and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT,
                nameSuffix = p.ready and M.label.readyMark or M.labels.notReadyMark,
                suffixColor = p.ready and TEXT_COLORS.SUCCESS or TEXT_COLORS.DEFAULT,
            }
        end)

        M.cache.showPreparationConfigs = M.cache.isParticipant and not M.cache.isReady and #M.scenario.configs > 1
        if M.cache.showPreparationConfigs then
            M.cache.preparationConfigs = Table(M.scenario.configs):clone()
        end
    end

    M.cache.startTime = M.scenario.startTime
    M.cache.showStartTime = M.cache.showStartTime ~= nil
    M.cache.lives = M.cache.isParticipant and participant.lives or 0
    M.cache.showForfeitBtn = M.cache.isParticipant and not M.scenario.isEliminated()
    M.cache.disableForfeitBtn = false
    M.cache.gameLeaderboardCols = Table()
    if M.cache.showGame then
        M.cache.gameLeaderboardNamesWidth = 0
        M.cache.gameLeaderboardCols = Table(M.scenario.participants):map(function(p)
            local name, nameColor = BJIContext.Players[p.playerID].playerName,
                p.playerID == BJIContext.User.playerID and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
            local w = GetColumnTextWidth(name)
            if w > M.cache.gameLeaderboardNamesWidth then
                M.cache.gameLeaderboardNamesWidth = w
            end
            local suffix, suffixColor = "", TEXT_COLORS.DEFAULT
            if p.eliminationTime then
                suffix = RaceDelay(p.eliminationTime)
                suffixColor = TEXT_COLORS.HIGHLIGHT
            elseif p.lives > 0 then
                suffix = string.var("({1})", {
                    (p.lives > 1 and M.labels.amountLives or M.labels.amountLife):var({ amount = p.lives })
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
    updateLabels()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end))

    updateCache()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.SCENARIO_UPDATED,
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache))
end

local function onUnload()
    listeners:forEach(BJIEvents.removeListener)
end

---@param targetTime integer
---@param now integer
---@return integer
local function getDiffTime(targetTime, now)
    return math.ceil((targetTime - now) / 1000)
end

local function drawHeaderPreparation(ctxt)
    local remainingTime = getDiffTime(M.cache.preparationTimeout, ctxt.now)
    LineLabel(remainingTime < 1 and M.labels.preparationTimeoutAboutToEnd or
        M.labels.preparationTimeoutIn:var({ delay = PrettyDelay(remainingTime) }),
        remainingTime < 3 and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)

    if not M.cache.isParticipant or not M.cache.isReady then
        local line = LineBuilder()
            :btnIconToggle({
                id = "joinDerby",
                icon = M.cache.isParticipant and ICONS.exit_to_app or ICONS.videogame_asset,
                state = not M.cache.isParticipant,
                big = true,
                disabled = M.cache.disableJoinBtn,
                onClick = function()
                    M.cache.disableJoinBtn = true -- api request protection
                    if M.cache.isParticipant then
                        M.cache.disableReadyBtn = true -- api request protection
                    end
                    BJITx.scenario.DerbyUpdate(BJIScenario.get(BJIScenario.TYPES.DERBY).CLIENT_EVENTS.JOIN)
                end
            })
        if M.cache.showReadyBtn then
            line:btnIcon({
                id = "readyDerby",
                icon = ICONS.check,
                style = BTN_PRESETS.SUCCESS,
                big = true,
                disabled = not ctxt.isOwner or M.cache.disableReadyBtn,
                onClick = function()
                    M.cache.disableReadyBtn = true -- api request protection
                    M.cache.disableJoinBtn = true -- api request protection
                    BJITx.scenario.DerbyUpdate(
                        BJIScenario.get(BJIScenario.TYPES.DERBY).CLIENT_EVENTS.READY,
                        ctxt.veh:getID()
                    )
                end
            })
        end
        line:build()
    end
end

local function drawHeaderGame(ctxt)
    local line = LineBuilder()
    if M.cache.showForfeitBtn and M.cache.startTime < ctxt.now then
        line:btnIcon({
            id = "leaveDerby",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            big = true,
            disabled = M.cache.disableForfeitBtn,
            onClick = function()
                M.cache.disableForfeitBtn = true
                BJITx.scenario.DerbyUpdate(M.scenario.CLIENT_EVENTS.LEAVE, ctxt.now - M.cache.startTime)
                BJITx.player.explodeVehicle(M.scenario.getParticipant().gameVehID)
            end
        })
    end

    line:icon({
        icon = ICONS.timer,
        big = true,
    })
    -- START COUNTDOWN / DNF COUNTDOWN
    if M.cache.startTime and M.cache.startTime + 3000 > ctxt.now then
        local remainingTime = getDiffTime(M.cache.startTime, ctxt.now)
        line:text(remainingTime > 0 and M.labels.startsIn:var({ delay = PrettyDelay(remainingTime) }) or
            M.labels.flashStart)
    elseif M.cache.isParticipant and M.scenario.destroy.process then
        local remainingTime = getDiffTime(M.scenario.destroy.targetTime, ctxt.now)
        line:text((M.cache.lives > 0 and M.labels.resetIn or M.labels.eliminatedIn)
            :var({ delay = PrettyDelay(remainingTime) }))
    end

    line:build()
end

local function header(ctxt)
    LineBuilder():text(M.cache.arenaName):text(M.cache.places):build()

    if M.cache.showPreparation then
        drawHeaderPreparation(ctxt)
    elseif M.cache.showGame then
        drawHeaderGame(ctxt)
    end
end

local function body(ctxt)
    if M.cache.showPreparation then
        M.cache.preparationParticipants:forEach(function(p)
            LineBuilder()
                :text(p.name)
                :text(p.nameSuffix, p.suffixColor)
                :build()
        end)

        M.cache.preparationConfigs:forEach(function(c, i)
            LineBuilder()
                :btnIcon({
                    id = string.var("spawnConfig{1}", { i }),
                    icon = ICONS.carSensors,
                    style = ctxt.isOwner and BTN_PRESETS.WARNING or BTN_PRESETS.SUCCESS,
                    onClick = function()
                        M.scenario.tryReplaceOrSpawn(c.model, c.config)
                    end
                })
                :text(c.label)
                :build()
        end)
    elseif M.cache.showGame then
        local cols = ColumnsBuilder("BJIDerbyLeaderboard", { M.cache.gameLeaderboardNamesWidth, -1 })
        M.cache.gameLeaderboardCols:forEach(function(col) cols:addRow(col) end)
        cols:build()
    end
end


M.onLoad = onLoad
M.onUnload = onUnload
M.header = header
M.body = body


return M
