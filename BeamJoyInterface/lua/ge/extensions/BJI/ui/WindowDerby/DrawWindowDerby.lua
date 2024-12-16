local dm

local function drawHeaderPreparation(ctxt)
    local remainingTime = Round((dm.preparationTimeout - ctxt.now) / 1000)
    local msg = remainingTime < 1 and
        BJILang.get("derby.play.preparationTimeoutAboutToEnd") or
        svar(BJILang.get("derby.play.preparationTimeoutIn"),
            { delay = PrettyDelay(remainingTime) })
    LineBuilder()
        :text(msg)
        :build()

    local participant = dm.getParticipant()
    if not participant or not participant.ready then
        local line = LineBuilder()
            :btnIconToggle({
                id = "joinDerby",
                icon = participant and ICONS.exit_to_app or ICONS.videogame_asset,
                state = not participant,
                big = true,
                onClick = function()
                    BJITx.scenario.DerbyUpdate(dm.CLIENT_EVENTS.JOIN)
                end
            })
        if participant and ctxt.isOwner then
            line:btnIcon({
                id = "readyDerby",
                icon = ICONS.check,
                style = BTN_PRESETS.SUCCESS,
                big = true,
                onClick = function()
                    BJITx.scenario.DerbyUpdate(dm.CLIENT_EVENTS.READY, ctxt.veh:getID())
                end
            })
        end
        line:build()
    end
end

local function drawHeaderGame(ctxt)
    -- START COUNTDOWN
    if dm.startTime then
        local remainingTime = math.ceil((dm.startTime - ctxt.now) / 1000)
        if remainingTime > 0 then
            LineBuilder()
                :text(svar(BJILang.get("derby.play.gameStartsIn"),
                    { delay = PrettyDelay(remainingTime) }))
                :build()
        elseif remainingTime > -3 then
            LineBuilder()
                :text(BJILang.get("derby.play.flashStart"))
                :build()
        else
            EmptyLine()
        end
    else
        EmptyLine()
    end

    -- LEAVE BUTTON
    local participant = dm.getParticipant()
    if participant and not dm.isEliminated() and ctxt.now > dm.startTime then
        LineBuilder()
            :btnIcon({
                id = "leaveDerby",
                icon = ICONS.exit_to_app,
                style = BTN_PRESETS.ERROR,
                big = true,
                onClick = function()
                    BJITx.scenario.DerbyUpdate(dm.CLIENT_EVENTS.LEAVE, ctxt.now - dm.startTime)
                    BJITx.player.explodeVehicle(participant.gameVehID)
                end
            })
            :build()
    end

    -- DESTROY COUTDOWN
    if participant and dm.destroy.process then
        local remainingTime = math.ceil((dm.destroy.targetTime - ctxt.now) / 1000)
        if remainingTime > 0 and remainingTime < dm.destroyedTimeout then
            local msg = participant.lives > 0 and
                BJILang.get("derby.play.resetIn") or
                BJILang.get("derby.play.eliminatedIn")
            LineBuilder()
                :text(svar(msg, { delay = PrettyDelay(remainingTime) }))
                :build()
        else
            EmptyLine()
        end
    else
        EmptyLine()
    end
end

local function drawHeader(ctxt)
    dm = BJIScenario.get(BJIScenario.TYPES.DERBY)

    LineBuilder()
        :text(svar(BJILang.get("derby.play.arenaName"), { name = dm.baseArena.name }))
        :text(svar("({1})", { svar(BJILang.get("derby.settings.places"),
            { places = #dm.baseArena.startPositions }) }))
        :build()

    if dm.state == dm.STATES.PREPARATION then
        drawHeaderPreparation(ctxt)
    else
        drawHeaderGame(ctxt)
    end
end

local function drawBodyPreparation(ctxt)
    if #dm.participants > 0 then
        for _, participant in ipairs(dm.participants) do
            local player = BJIContext.Players[participant.playerID]
            local mark = svar("({1})",
                { participant.ready and
                BJILang.get("derby.play.readyMark") or
                BJILang.get("derby.play.notReadyMark") })
            LineBuilder()
                :text(player.playerName)
                :text(mark, participant.ready and TEXT_COLORS.SUCCESS or TEXT_COLORS.ERROR)
                :build()
        end
    end

    local participant = dm.getParticipant()
    if participant and not participant.ready and #dm.configs > 1 then
        for i, config in ipairs(dm.configs) do
            LineBuilder()
                :btnIcon({
                    id = svar("spawnConfig{1}", { i }),
                    icon = ICONS.carSensors,
                    style = ctxt.isOwner and BTN_PRESETS.WARNING or BTN_PRESETS.SUCCESS,
                    onClick = function()
                        dm.tryReplaceOrSpawn(config.model, config.config)
                    end
                })
                :text(config.label)
                :build()
        end
    end
end

local function drawBodyGame(ctxt)
    for i, participant in ipairs(dm.participants) do
        local player = BJIContext.Players[participant.playerID]
        if dm.isEliminated(participant.playerID) then
            LineBuilder()
                :text(svar("{1} {2}", { i, player.playerName }),
                    participant.playerID == BJIContext.User.playerID and
                    TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
                :text(svar("({1})", { RaceDelay(participant.eliminationTime) }),
                    TEXT_COLORS.ERROR)
                :build()
        else
            local line = LineBuilder()
                :text(svar("- {1}", { player.playerName }),
                    participant.playerID == BJIContext.User.playerID and
                    TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
            if participant.lives > 0 then
                local livesLabel = participant.lives > 1 and
                    BJILang.get("derby.play.amountLives") or
                    BJILang.get("derby.play.amountLife")
                livesLabel = svar(livesLabel, { amount = participant.lives })
                line:text(svar("({1})", { livesLabel }))
            end
            line:build()
        end
    end
end

local function drawBody(ctxt)
    if dm.state == dm.STATES.PREPARATION then
        drawBodyPreparation(ctxt)
    else
        drawBodyGame(ctxt)
    end
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    header = drawHeader,
    body = drawBody
}
