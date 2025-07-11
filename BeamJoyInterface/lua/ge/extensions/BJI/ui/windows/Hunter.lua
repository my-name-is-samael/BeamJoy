---@class BJIWindowHunter : BJIWindow
local W = {
    name = "Hunter",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    size = ImVec2(300, 280),

    labels = {
        hunted = "",
        hunters = "",

        preparationTimeoutAboutToEnd = "",
        preparationTimeoutIn = "",
        configChoose = "",
        readyMark = "",
        notReadyMark = "",

        playStartIn = "",
        flashStartHunted = "",
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
            setAsFugitive = "",
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
        showFugitiveAssignBtn = false,

        -- game
        huntedID = 0,
        ---@type BJIPlayer?
        huntedPlayer = nil,
        showGameActions = false,
        showManualResetBtn = false,
        startTime = 0,
    },
    ---@type BJIScenarioHunter
    scenario = nil,
}
--- gc prevention
local label, color, remaining

local function updateLabels()
    W.labels.hunted = BJI_Lang.get("hunter.play.hunted") .. " :"
    W.labels.hunters = BJI_Lang.get("hunter.play.hunters") .. " :"

    W.labels.preparationTimeoutAboutToEnd = BJI_Lang.get("hunter.play.preparationTimeoutAboutToEnd")
    W.labels.preparationTimeoutIn = BJI_Lang.get("hunter.play.preparationTimeoutIn")
    W.labels.configChoose = BJI_Lang.get("hunter.play.configChoose") .. " :"
    W.labels.readyMark = string.var("({1})", { BJI_Lang.get("hunter.play.readyMark") })
    W.labels.notReadyMark = string.var("({1})", { BJI_Lang.get("hunter.play.notReadyMark") })

    W.labels.playStartIn = BJI_Lang.get("hunter.play.startIn")
    W.labels.flashStartHunted = BJI_Lang.get("hunter.play.flashHuntedStart")
    W.labels.flashStartHunter = BJI_Lang.get("hunter.play.flashHunterResume")
    W.labels.huntedAboutToLoose = BJI_Lang.get("hunter.play.huntedAboutToLoose")
    W.labels.huntedLooseIn = BJI_Lang.get("hunter.play.huntedLooseIn")
    W.labels.hunterResumeIn = BJI_Lang.get("hunter.play.hunterResumeIn")
    W.labels.waypoints = BJI_Lang.get("hunter.play.waypoints")

    W.labels.buttons.join = BJI_Lang.get("common.buttons.join")
    W.labels.buttons.spectate = BJI_Lang.get("common.buttons.spectate")
    W.labels.buttons.markReady = BJI_Lang.get("common.buttons.markReady")
    W.labels.buttons.forfeit = BJI_Lang.get("common.buttons.forfeit")
    W.labels.buttons.spawn = BJI_Lang.get("common.buttons.spawn")
    W.labels.buttons.replace = BJI_Lang.get("common.buttons.replace")
    W.labels.buttons.manualReset = BJI_Lang.get("common.buttons.manualReset")
    W.labels.buttons.setAsFugitive = BJI_Lang.get("hunter.play.setAsFugitive")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    W.cache.showPreparation = W.scenario.state == W.scenario.STATES.PREPARATION
    W.cache.showGame = W.scenario.state == W.scenario.STATES.GAME
    W.cache.disabledButtons = not BJI_Perm.canSpawnVehicle()

    W.cache.isParticipant = not not W.scenario.participants[BJI_Context.User.playerID]
    W.cache.isHunted = W.cache.isParticipant and
        W.scenario.participants[BJI_Context.User.playerID].hunted

    W.cache.showConfigs = false
    if W.cache.showPreparation then
        W.cache.preparationTimeoutTargetTime = W.scenario.preparationTimeout
        W.cache.isReady = W.cache.isParticipant and W.scenario.participants[BJI_Context.User.playerID].ready
        W.cache.showPreparationActions = BJI_Perm.canSpawnVehicle() and not W.cache.isReady and (
            not BJI_Tournament.state or not BJI_Tournament.whitelist or
            BJI_Tournament.whitelistPlayers:includes(ctxt.user.playerName)
        )
        W.cache.showConfigs = W.cache.isParticipant and not W.cache.isReady and
            not W.cache.isHunted and #W.scenario.settings.hunterConfigs > 1
        W.cache.showFugitiveAssignBtn = not W.cache.isReady and
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
        W.cache.startTime = W.cache.isHunted and W.scenario.huntedStartTime or W.scenario.hunterStartTime

        W.cache.showManualResetBtn = W.cache.isParticipant
    end

    W.cache.playersList = Table(W.scenario.participants)
        :map(function(p, playerID)
            return {
                playerID = playerID,
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
    W.scenario = BJI_Scenario.get(BJI_Scenario.TYPES.HUNTER)

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
            BJI_Tx_scenario.HunterUpdate(W.scenario.CLIENT_EVENTS.JOIN)
        end
        TooltipText(W.cache.isParticipant and W.labels.buttons.spectate or W.labels.buttons.join)
        if ctxt.isOwner and not W.cache.isReady then
            SameLine()
            if IconButton("readyHunter", BJI.Utils.Icon.ICONS.check,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, big = true,
                        disabled = not ctxt.isOwner or W.cache.disabledButtons }) then
                W.cache.disabledButtons = true -- api request protection
                BJI_Tx_scenario.HunterUpdate(W.scenario.CLIENT_EVENTS.READY, ctxt.veh.gameVehicleID)
            end
            TooltipText(W.labels.buttons.markReady)
        end
    end
end

---@param ctxt TickContext
local function drawHeaderGame(ctxt)
    if W.cache.showGameActions or W.cache.showManualResetBtn then
        if BeginTable("HunterGameHeader", {
                { label = "##hunter-header-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "##hunter-header-right" },
            }) then
            TableNewRow()
            if W.cache.showGameActions then
                if IconButton("leaveHunter", BJI.Utils.Icon.ICONS.exit_to_app,
                        { big = true, btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                    W.cache.disabledButtons = true
                    BJI_Tx_scenario.HunterUpdate(
                        W.cache.huntedID == BJI_Context.User.playerID and
                        W.scenario.CLIENT_EVENTS.ELIMINATED or
                        W.scenario.CLIENT_EVENTS.LEAVE
                    )
                end
                TooltipText(W.labels.buttons.forfeit)

                label, color = nil, nil
                if W.cache.startTime and ctxt.now < W.cache.startTime + 3000 then
                    remaining = getDiffTime(W.cache.startTime, ctxt.now)
                    if remaining > 0 then
                        label = W.labels.playStartIn:var({ delay = BJI.Utils.UI.PrettyDelay(remaining) })
                    else
                        label = W.cache.isHunted and W.labels.flashStartHunted or W.labels.flashStartHunter
                    end
                    color = remaining <= 3 and
                        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                        BJI.Utils.Style.TEXT_COLORS.DEFAULT
                else
                    if W.cache.isHunted then
                        --DNF DISPLAY
                        if W.scenario.dnf.process and W.scenario.dnf.targetTime and
                            ctxt.now < W.scenario.dnf.targetTime then
                            remaining = getDiffTime(W.scenario.dnf.targetTime, ctxt.now)
                            label = W.labels.huntedLooseIn:var({ delay = BJI.Utils.UI.PrettyDelay(remaining) })
                            color = remaining <= 3 and
                                BJI.Utils.Style.TEXT_COLORS.ERROR or
                                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
                        end
                    else
                        --- respawn cooldown
                        if W.scenario.hunterRespawnTargetTime and ctxt.now < W.scenario.hunterRespawnTargetTime + 3000 then
                            remaining = getDiffTime(W.scenario.hunterRespawnTargetTime, ctxt.now)
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
local function drawBodyPreparation(ctxt)
    if W.cache.showConfigs then
        Text(W.labels.configChoose)
        Indent()
        Table(W.scenario.settings.hunterConfigs)
            :forEach(function(confData, i)
                if IconButton("spawnConfig" .. tostring(i), ctxt.isOwner and
                        BJI.Utils.Icon.ICONS.carSensors or BJI.Utils.Icon.ICONS.add,
                        { btnStyle = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                            BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disabledButtons }) then
                    W.scenario.tryReplaceOrSpawn(confData.model, confData)
                end
                TooltipText(ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn)
                SameLine()
                Text(confData.label)
            end)
        Unindent()
    end

    W.cache.playersList:forEach(function(p, i)
        if i < 3 then
            Text(i == 1 and W.labels.hunted or W.labels.hunters)
            Indent()
        end
        Text(p.playerName, {
            color = p.self and
                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                BJI.Utils.Style.TEXT_COLORS.DEFAULT
        })
        SameLine()
        Text(p.readyLabel, { color = p.color })
        if i > 1 and W.cache.showFugitiveAssignBtn then
            SameLine()
            if Button("forceFugitive" .. p.playerName, W.labels.buttons.setAsFugitive,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disabledButtons }) then
                W.cache.disabledButtons = true
                BJI_Tx_scenario.HunterForceFugitive(p.playerID)
            end
        end
        if i == 1 or i == #W.cache.playersList then
            Unindent()
        end
    end)
end

---@param ctxt TickContext
local function drawBodyGame(ctxt)
    W.cache.playersList:forEach(function(p, i)
        color = p.self and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
            BJI.Utils.Style.TEXT_COLORS.DEFAULT
        if i == 1 then
            Text(W.labels.hunted)
            Text(string.var("{1} - {2}/{3} {4}", { p.playerName, W.cache.waypointsReached,
                W.cache.waypointsTotal, W.labels.waypoints }), { color = color })
        else
            if i == 2 then
                Text(W.labels.hunters)
                Indent()
            end
            Text(p.playerName, { color = color })
            if i == #W.cache.playersList then
                Unindent()
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
    return BJI_Scenario.is(BJI_Scenario.TYPES.HUNTER)
end

return W
