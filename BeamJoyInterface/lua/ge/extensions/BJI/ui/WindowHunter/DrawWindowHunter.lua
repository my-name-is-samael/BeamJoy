local sh
local huntedID

local function drawHeaderPreparation(ctxt)
    local remaining = math.round((sh.preparationTimeout - ctxt.now) / 1000)
    local label = remaining < 1 and
        BJILang.get("hunter.play.preparationTimeoutAboutToEnd") or
        BJILang.get("hunter.play.preparationTimeoutIn"):var({ delay = PrettyDelay(remaining) })
    LineBuilder():text(label):build()

    local participant = sh.participants[BJIContext.User.playerID]
    if not participant or not participant.ready then
        local line = LineBuilder()
            :btnIconToggle({
                id = "joinHunter",
                icon = participant and ICONS.exit_to_app or ICONS.videogame_asset,
                state = not participant,
                onClick = function()
                    BJITx.scenario.HunterUpdate(sh.CLIENT_EVENTS.JOIN)
                    if participant and BJIVeh.isCurrentVehicleOwn() then
                        BJICam.removeRestrictedCamera(BJICam.CAMERAS.FREE)
                        BJICam.setCamera(BJICam.CAMERAS.FREE)
                        BJIVeh.deleteAllOwnVehicles()
                    end
                end,
                big = true,
            })
        if ctxt.isOwner then
            line:btnIcon({
                id = "readyHunter",
                icon = ICONS.check,
                style = BTN_PRESETS.SUCCESS,
                onClick = function()
                    BJITx.scenario.HunterUpdate(sh.CLIENT_EVENTS.READY, ctxt.veh:getID())
                end,
                big = true,
            })
        end
        line:build()
    end
end

local function drawHeaderGame(ctxt)
    if not huntedID then
        for playerID, p in pairs(sh.participants) do
            if p.hunted then
                huntedID = playerID
                break
            end
        end
    end

    local participant = sh.participants[BJIContext.User.playerID]
    if participant then
        LineBuilder()
            :btnIcon({
                id = "leaveHunter",
                icon = ICONS.exit_to_app,
                style = BTN_PRESETS.ERROR,
                onClick = function()
                    BJICam.removeRestrictedCamera(BJICam.CAMERAS.FREE)
                    BJITx.scenario.HunterUpdate(
                        huntedID == BJIContext.User.playerID and
                        sh.CLIENT_EVENTS.ELIMINATED or
                        sh.CLIENT_EVENTS.LEAVE
                    )
                end,
                big = true,
            })
            :build()

        if participant.hunted then
            if ctxt.now < sh.huntedStartTime then
                local remaining = math.round((sh.huntedStartTime - ctxt.now) / 1000)
                local label = remaining < 1 and
                    BJILang.get("hunter.play.aboutToStart") or
                    BJILang.get("hunter.play.startIn"):var({ delay = PrettyDelay(remaining) })
                LineBuilder():text(label):build()
            elseif sh.dnf.process and sh.dnf.targetTime then
                local remaining = math.round((sh.dnf.targetTime - ctxt.now) / 1000)
                local color = remaining <= 3 and TEXT_COLORS.ERROR or TEXT_COLORS.HIGHLIGHT
                local label = remaining < 1 and
                    BJILang.get("hunter.play.huntedAboutToLoose") or
                    BJILang.get("hunter.play.huntedLooseIn"):var({ delay = PrettyDelay(remaining) })
                LineBuilder():text(label, color):build()
            end
        else
            if ctxt.now < sh.hunterStartTime then
                local remaining = math.round((sh.hunterStartTime - ctxt.now) / 1000)
                local label = remaining < 1 and
                    BJILang.get("hunter.play.aboutToStart") or
                    BJILang.get("hunter.play.startIn"):var({ delay = PrettyDelay(remaining) })
                LineBuilder():text(label):build()
            end
        end
    end
end

local function drawHeader(ctxt)
    sh = BJIScenario.get(BJIScenario.TYPES.HUNTER)
    if not sh then return end

    if sh.state == sh.STATES.PREPARATION then
        huntedID = nil
        drawHeaderPreparation(ctxt)
    elseif sh.state == sh.STATES.GAME then
        drawHeaderGame(ctxt)
    end
end

local function drawBodyPreparation(ctxt)
    local participant = sh.participants[BJIContext.User.playerID]
    if participant then
        if not participant.hunted and
            #sh.settings.hunterConfigs > 1 and
            not participant.ready then
            LineBuilder()
                :text(string.var("{1}:", { BJILang.get("hunter.play.configChoose") }))
                :build()
            Indent(1)
            local cols = ColumnsBuilder("HunterVehicles", { GetBtnIconSize(), -1 })
            for i, confData in ipairs(sh.settings.hunterConfigs) do
                cols:addRow({
                    cells = {
                        function()
                            LineBuilder()
                                :btnIcon({
                                    id = string.var("spawnConfig{1}", { i }),
                                    icon = ICONS.carSensors,
                                    style = BTN_PRESETS.SUCCESS,
                                    onClick = function()
                                        sh.tryReplaceOrSpawn(confData.model, confData.config)
                                        if not BJIVehSelector.state then
                                            BJIVehSelector.open({}, false)
                                        end
                                    end,
                                })
                                :build()
                        end,
                        function()
                            LineBuilder()
                                :text(confData.label)
                                :build()
                        end,
                    }
                })
            end
            cols:build()
            Indent(-1)
        end
    end

    local function getReadyData(playerID)
        local template = "({1})"
        if sh.participants[playerID].ready then
            return template:var({ BJILang.get("hunter.play.readyMark") }), TEXT_COLORS.SUCCESS
        else
            return template:var({ BJILang.get("hunter.play.notReadyMark") }), TEXT_COLORS.ERROR
        end
    end

    if table.length(sh.participants) > 0 then
        local huntedId
        for playerID, p in pairs(sh.participants) do
            if p.hunted then
                huntedId = playerID
                break
            end
        end

        if huntedId then
            LineBuilder()
                :text(string.var("{1}:", { BJILang.get("hunter.play.hunted") }))
                :build()
            local player = BJIContext.Players[huntedId]
            local readyLabel, readyColor = getReadyData(huntedId)
            Indent(1)
            LineBuilder()
                :text(player.playerName)
                :text(readyLabel, readyColor)
                :build()
            Indent(-1)
        end
        if table.length(sh.participants) > (huntedId and 1 or 0) then
            LineBuilder()
                :text(string.var("{1}:", { BJILang.get("hunter.play.hunters") }))
                :build()
            Indent(1)
            for playerID in pairs(sh.participants) do
                if playerID ~= huntedId then
                    local player = BJIContext.Players[playerID]
                    local readyLabel, readyColor = getReadyData(playerID)
                    LineBuilder()
                        :text(player.playerName)
                        :text(readyLabel, readyColor)
                        :build()
                end
            end
            Indent(-1)
        end
    end
end

local function drawBodyGame(ctxt)
    local hunted = BJIContext.Players[huntedID]
    if hunted then
        local color = huntedID == BJIContext.User.playerID and
            TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
        LineBuilder()
            :text(string.var("{1}:", { BJILang.get("hunter.play.hunted") }))
            :text(string.var("{1} ({2}/{3} {4})",
                    { hunted.playerName,
                        sh.participants[huntedID].waypoint,
                        sh.settings.waypoints,
                        BJILang.get("hunter.play.waypoints") }),
                color)
            :build()
    end

    LineBuilder()
        :text(string.var("{1}:", { BJILang.get("hunter.play.hunters") }))
        :build()
    Indent(1)
    for playerID, p in pairs(sh.participants) do
        if not p.hunted then
            local player = BJIContext.Players[playerID]
            LineBuilder():text(player.playerName):build()
        end
    end
    Indent(-1)
end

local function drawBody(ctxt)
    if not sh then return end

    if sh.state == sh.STATES.PREPARATION then
        drawBodyPreparation(ctxt)
    elseif sh.state == sh.STATES.GAME then
        drawBodyGame(ctxt)
    end
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE,
    },
    header = drawHeader,
    body = drawBody,
}
