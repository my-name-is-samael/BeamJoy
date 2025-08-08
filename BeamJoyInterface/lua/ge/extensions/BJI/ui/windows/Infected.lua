---@class BJIWindowInfected : BJIWindow
local W = {
    name = "Infected",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    minSize = ImVec2(250, 200),
    maxSize = ImVec2(350, 400),

    labels = {
        infected = "",
        survivors = "",
        infectedAmount = "",

        preparationTimeoutAboutToEnd = "",
        preparationTimeoutIn = "",
        configChoose = "",
        readyMark = "",
        notReadyMark = "",

        playStartIn = "",
        flashStartInfected = "",
        flashStartSurvivor = "",

        buttons = {
            join = "",
            spectate = "",
            markReady = "",
            forfeit = "",
            spawn = "",
            replace = "",
            manualReset = "",
            setAsInfected = "",
        },
    },
    cache = {
        showPreparation = false,
        showGame = false,
        disabledButtons = false,
        isParticipant = false,
        isInfected = false,
        survivorsList = Table(),
        infectedList = Table(),

        -- preparation
        ---@type integer|nil
        preparationTimeoutTargetTime = nil,
        isReady = false,
        showPreparationActions = false,
        showInfectedAssignBtn = false,

        -- game
        showGameActions = false,
        showManualResetBtn = false,
        startTime = 0,
        flashStart = "",
    },
    ---@type BJIScenarioInfected
    scenario = nil,
}
--- gc prevention
local label, color, remaining

local function updateLabels()
    W.labels.infected = BJI_Lang.get("infected.play.infected") .. " :"
    W.labels.survivors = BJI_Lang.get("infected.play.survivors") .. " :"
    W.labels.infectedAmount = string.var("({1})", { BJI_Lang.get("infected.play.infectedAmount") })

    W.labels.preparationTimeoutAboutToEnd = BJI_Lang.get("infected.play.preparationTimeoutAboutToEnd")
    W.labels.preparationTimeoutIn = BJI_Lang.get("infected.play.preparationTimeoutIn")
    W.labels.configChoose = BJI_Lang.get("infected.play.configChoose") .. " :"
    W.labels.readyMark = string.var("({1})", { BJI_Lang.get("infected.play.readyMark") })
    W.labels.notReadyMark = string.var("({1})", { BJI_Lang.get("infected.play.notReadyMark") })

    W.labels.playStartIn = BJI_Lang.get("infected.play.startIn")
    W.labels.flashStartInfected = BJI_Lang.get("infected.play.flashInfectedStart")
    W.labels.flashStartSurvivor = BJI_Lang.get("infected.play.flashSurvivorStart")

    W.labels.buttons.join = BJI_Lang.get("common.buttons.join")
    W.labels.buttons.spectate = BJI_Lang.get("common.buttons.spectate")
    W.labels.buttons.markReady = BJI_Lang.get("common.buttons.markReady")
    W.labels.buttons.forfeit = BJI_Lang.get("common.buttons.forfeit")
    W.labels.buttons.spawn = BJI_Lang.get("common.buttons.spawn")
    W.labels.buttons.replace = BJI_Lang.get("common.buttons.replace")
    W.labels.buttons.manualReset = BJI_Lang.get("common.buttons.manualReset")
    W.labels.buttons.setAsInfected = BJI_Lang.get("infected.play.setAsInfected")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    W.cache.showPreparation = W.scenario.state == W.scenario.STATES.PREPARATION
    W.cache.showGame = W.scenario.state == W.scenario.STATES.GAME
    W.cache.disabledButtons = not BJI_Perm.canSpawnVehicle()

    local participant = W.scenario.participants[BJI_Context.User.playerID]
    W.cache.isParticipant = participant ~= nil
    W.cache.isInfected = W.scenario.isInfected()

    W.cache.survivorsList = Table()
    W.cache.infectedList = Table()
    Table(W.scenario.participants):forEach(function(p, pid)
        (W.scenario.isInfected(pid) and W.cache.infectedList or W.cache.survivorsList):insert({
            playerID = pid,
            playerName = ctxt.players[pid].playerName,
            self = pid == ctxt.user.playerID,
            readyLabel = p.ready and W.labels.readyMark or W.labels.notReadyMark,
            color = p.ready and BJI.Utils.Style.TEXT_COLORS.SUCCESS or BJI.Utils.Style.TEXT_COLORS.ERROR,
            infectedSurvivors = p.infectedSurvivors,
        })
    end)
    Table({ W.cache.survivorsList, W.cache.infectedList }):forEach(function(t)
        t.sort(function(a, b)
            return a.playerName:lower() < b.playerName:lower()
        end)
    end)

    if W.cache.showPreparation then
        W.cache.preparationTimeoutTargetTime = W.scenario.preparationTimeout
        W.cache.isReady = W.cache.isParticipant and participant.ready
        W.cache.showPreparationActions = BJI_Perm.canSpawnVehicle() and not W.cache.isReady and (
            not BJI_Tournament.state or not BJI_Tournament.whitelist or
            BJI_Tournament.whitelistPlayers:includes(ctxt.user.playerName)
        )
        W.cache.showInfectedAssignBtn = not W.cache.isReady and
            BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS
                .START_SERVER_SCENARIO)
    end

    W.cache.huntedID = nil
    W.cache.huntedPlayer = nil
    if W.cache.showGame then
        Table(W.scenario.participants):find(function(part) return part.hunted end,
            function(_, playerID)
                W.cache.huntedID = playerID
                W.cache.huntedPlayer = ctxt.players[playerID]
            end)
        W.cache.showGameActions = W.cache.isParticipant
        W.cache.startTime = W.cache.isInfected and W.scenario.infectedStartTime or W.scenario.survivorsStartTime
        W.cache.flashStart = W.cache.isInfected and W.labels.flashStartInfected or W.labels.flashStartSurvivor

        W.cache.showManualResetBtn = W.cache.isParticipant
    end
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI_Scenario.get(BJI_Scenario.TYPES.INFECTED)

    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.SCENARIO_UPDATED,
        BJI_Events.EVENTS.TOURNAMENT_UPDATED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))

    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.TOURNAMENT_UPDATED,
        function(ctxt)
            if W.scenario.participants[ctxt.user.playerID] and BJI_Tournament.whitelist and
                not BJI_Tournament.whitelistPlayers:includes(ctxt.user.playerName) then
                -- got out of whitelist
                BJI_Tx_scenario.HunterUpdate(W.scenario.state == W.scenario.STATES.PREPARATION and
                    W.scenario.CLIENT_EVENTS.JOIN or W.scenario.CLIENT_EVENTS.LEAVE)
            end
        end, W.name .. "AutoLeaveTournament"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

---@param targetTime integer
---@param now integer
---@return integer
local function getDiffTime(targetTime, now)
    return math.ceil((targetTime - now) / 1000)
end

---@param ctxt TickContext
local function drawHeaderPreparation(ctxt)
    if W.cache.preparationTimeoutTargetTime then
        remaining = getDiffTime(W.cache.preparationTimeoutTargetTime, ctxt.now)
        Text(remaining < 1 and
            W.labels.preparationTimeoutAboutToEnd or
            W.labels.preparationTimeoutIn:var({ delay = BJI.Utils.UI.PrettyDelay(remaining) }), {
                color = remaining < 10 and
                    BJI.Utils.Style.TEXT_COLORS.ERROR or
                    BJI.Utils.Style.TEXT_COLORS.DEFAULT
            })
    else
        EmptyLine()
    end

    if W.cache.showPreparationActions then
        if IconButton("joinParticipants", W.cache.isParticipant and
                BJI.Utils.Icon.ICONS.exit_to_app or BJI.Utils.Icon.ICONS.videogame_asset,
                { btnStyle = W.cache.isParticipant and BJI.Utils.Style.BTN_PRESETS.ERROR or
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disabledButtons, big = true }) then
            W.cache.disabledButtons = true -- api request protection
            BJI_Tx_scenario.InfectedUpdate(W.scenario.CLIENT_EVENTS.JOIN)
        end
        TooltipText(W.cache.isParticipant and W.labels.buttons.spectate or W.labels.buttons.join)
        if ctxt.isOwner and not W.cache.isReady then
            SameLine()
            if IconButton("readyInfected", BJI.Utils.Icon.ICONS.check,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, big = true,
                        disabled = not ctxt.isOwner or W.cache.disabledButtons }) then
                W.cache.disabledButtons = true -- api request protection
                BJI_Tx_scenario.InfectedUpdate(W.scenario.CLIENT_EVENTS.READY, ctxt.veh.gameVehicleID)
            end
            TooltipText(W.labels.buttons.markReady)
        end
    end
end

---@param ctxt TickContext
local function drawHeaderGame(ctxt)
    if W.cache.showGameActions or W.cache.showManualResetBtn then
        if BeginTable("InfectedGameHeader", {
                { label = "##infected-header-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "##infected-header-right" },
            }) then
            TableNewRow()
            if W.cache.showGameActions then
                if IconButton("leaveInfected", BJI.Utils.Icon.ICONS.exit_to_app,
                        { big = true, btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                    W.cache.disabledButtons = true
                    BJI_Tx_scenario.InfectedUpdate(W.scenario.CLIENT_EVENTS.LEAVE)
                end
                TooltipText(W.labels.buttons.forfeit)

                label, color = nil, nil
                if W.cache.startTime and ctxt.now < W.cache.startTime + 3000 then
                    remaining = getDiffTime(W.cache.startTime, ctxt.now)
                    if remaining > 0 then
                        label = W.labels.playStartIn:var({ delay = BJI.Utils.UI.PrettyDelay(remaining) })
                    else
                        label = W.cache.flashStart
                    end
                    color = remaining <= 3 and
                        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                        BJI.Utils.Style.TEXT_COLORS.DEFAULT
                end
                if label then
                    SameLine()
                    Icon(BJI.Utils.Icon.ICONS.timer, { big = true })
                    SameLine()
                    Text(label, { color = color })
                end
            end
            TableNextColumn()
            if W.cache.showManualResetBtn then
                if IconButton("manualReset", BJI.Utils.Icon.ICONS.build,
                        { big = true, btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = W.scenario.resetLock }) then
                    BJI_Veh.recoverInPlace()
                end
                TooltipText(string.var("{1} ({2})", {
                    W.labels.buttons.manualReset,
                    extensions.core_input_bindings.getControlForAction("recover_vehicle"):capitalizeWords()
                }))
            end

            EndTable()
        end
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
local function drawBody(ctxt)
    Table({ W.cache.infectedList, W.cache.survivorsList }):forEach(function(l, i)
        if #l > 0 then
            if i == 2 then
                EmptyLine()
            end
            Text(i == 1 and W.labels.infected or W.labels.survivors)
            Indent()
            Table(l)
                :forEach(function(p)
                    Text(p.playerName, {
                        color = p.self and
                            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                            BJI.Utils.Style.TEXT_COLORS.DEFAULT
                    })
                    if W.cache.showPreparation then
                        SameLine()
                        Text(p.readyLabel, { color = p.color })
                        if i == 2 and W.cache.showInfectedAssignBtn then
                            SameLine()
                            if Button("forceFugitive" .. p.playerName, W.labels.buttons.setAsInfected,
                                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disabledButtons }) then
                                W.cache.disabledButtons = true
                                BJI_Tx_scenario.InfectedForceInfected(p.playerID)
                            end
                        end
                    elseif W.cache.showGame and #p.infectedSurvivors > 0 then
                        SameLine()
                        Text(W.labels.infectedAmount:var({ amount = #p.infectedSurvivors }), {
                            color = p.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                                BJI.Utils.Style.TEXT_COLORS.DEFAULT
                        })
                    end
                end)
            Unindent()
        end
    end)
    if #W.cache.infectedList == 0 and #W.cache.survivorsList == 0 then
        EmptyLine()
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = drawHeader
W.body = drawBody
W.getState = function()
    return BJI_Scenario.is(BJI_Scenario.TYPES.INFECTED)
end

return W
