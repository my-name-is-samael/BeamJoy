local actionLinebreak = "linebreak"
local function getHeaderActions(playerID, isAccordionOpen, ctxt)
    local isSelf = BJIContext.isSelf(playerID)
    local selfGroup = BJIPerm.Groups[BJIContext.User.group] or { level = 0 }
    local target = BJIContext.Players[playerID]
    local targetGroup = BJIPerm.Groups[target.group] or { level = 0 }
    local isGroupLower = selfGroup.level > targetGroup.level
    local isStaff = targetGroup.staff
    local nbVehicles = tlength(target.vehicles)

    -- base actions
    local actions = BJIScenario.getPlayerListActions(target, ctxt)

    -- VEHICLES DELETE
    if nbVehicles > 0 and
        BJIScenario.isFreeroam() and
        (isSelf or (isGroupLower and not isStaff and
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DELETE_VEHICLE))) then
        table.insert(actions, {
            id = svar("deleteVehicles{1}", { playerID }),
            icon = ICONS.directions_car,
            background = BTN_PRESETS.ERROR,
            onClick = function()
                if isSelf then
                    BJIContext.User.currentVehicle = nil
                end
                BJITx.moderation.deleteVehicle(playerID, -1)
            end,
        })
    end

    if #actions > 0 then
        table.insert(actions, actionLinebreak)
    end

    -- line moderation actions
    if not isSelf and isGroupLower and not isStaff then
        if not isAccordionOpen then
            if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.MUTE) then
                table.insert(actions, {
                    id = svar("toggleMute{1}", { playerID }),
                    icon = ICONS.speaker_notes_off,
                    background = target.muted and BTN_PRESETS.SUCCESS or BTN_PRESETS.ERROR,
                    onClick = function()
                        BJITx.moderation.mute(target.playerName)
                    end
                })
            end

            if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.KICK) then
                table.insert(actions, {
                    id = svar("kick{1}", { playerID }),
                    label = BJILang.get("moderationBlock.buttons.kick"),
                    style = BTN_PRESETS.ERROR,
                    onClick = function()
                        BJIPopup.createModal(
                            svar(BJILang.get("moderationBlock.kickModal"),
                                { playerName = target.playerName }),
                            {
                                {
                                    label = BJILang.get("common.buttons.cancel"),
                                },
                                {
                                    label = BJILang.get("common.buttons.confirm"),
                                    onClick = function()
                                        BJITx.moderation.kick(playerID)
                                    end
                                }
                            }
                        )
                    end
                })
            end
        end
    end

    if isGroupLower and not isStaff then
        if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.FREEZE_PLAYERS) then
            table.insert(actions, {
                id = svar("toggleFreeze{1}", { playerID }),
                icon = ICONS.ac_unit,
                background = target.freeze and BTN_PRESETS.SUCCESS or BTN_PRESETS.ERROR,
                onClick = function()
                    BJITx.moderation.freeze(playerID)
                end
            })
        end

        if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.ENGINE_PLAYERS) then
            table.insert(actions, {
                id = svar("toggleEngine{1}", { playerID }),
                icon = ICONS.cogs,
                background = target.engine and BTN_PRESETS.SUCCESS or BTN_PRESETS.ERROR,
                onClick = function()
                    BJITx.moderation.engine(playerID)
                end
            })
        end
    end

    return actions
end

local function drawPlayerVehicles(playerID, ctxt)
    local target = BJIContext.Players[playerID]

    if tlength(target.vehicles) > 0 then
        local isSelf = BJIContext.isSelf(playerID)
        local targetGroup = BJIPerm.Groups[target.group]
        local isGroupLower = ctxt.group.level > targetGroup.level

        LineBuilder()
            :text(svar("{1} ({2}):",
                { BJILang.get("moderationBlock.vehicles"), tlength(target.vehicles) }))
            :build()

        Indent(1)
        for vehID, vehicle in pairs(target.vehicles) do
            local currColor = RGBA(0, 0, 0, 0)
            if target.currentVehicle == vehicle.gameVehID then
                currColor = RGBA(1, 0, 0, 1)
            end
            local finalGameVehID = BJIVeh.getVehicleObject(vehicle.gameVehID)
            finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
            local line = LineBuilder()
                :text("@", currColor)
                :text(vehicle.model)
            if isSelf or isGroupLower then
                line:btnIcon({
                    id = svar("focus{1}-{2}", { playerID, vehID }),
                    icon = ICONS.cameraFocusOnVehicle2,
                    background = BTN_PRESETS.INFO,
                    disabled = not finalGameVehID or
                        (ctxt.veh and ctxt.veh:getID() == finalGameVehID),
                    onClick = function()
                        BJIVeh.focusVehicle(finalGameVehID)
                    end
                })
                    :btnIconSwitch({
                        id = svar("toggleFreeze{1}-{2}", { playerID, vehID }),
                        iconEnabled = ICONS.ac_unit,
                        state = vehicle.freeze == true,
                        disabled = not finalGameVehID,
                        onClick = function()
                            BJITx.moderation.freeze(playerID, vehID)
                        end
                    })
                    :btnIconSwitch({
                        id = svar("toggleEngine{1}-{2}", { playerID, vehID }),
                        iconEnabled = ICONS.cogs,
                        state = vehicle.engine == false,
                        disabled = not finalGameVehID,
                        onClick = function()
                            BJITx.moderation.engine(playerID, vehID)
                        end
                    })
                    :btnIcon({
                        id = svar("delete{1}-{2}", { playerID, vehID }),
                        icon = ICONS.delete_forever,
                        background = BTN_PRESETS.ERROR,
                        onClick = function()
                            BJITx.moderation.deleteVehicle(playerID, vehicle.gameVehID)
                        end
                    })
                    :btnIcon({
                        id = svar("explode{1}-{2}", { playerID, vehID }),
                        icon = ICONS.whatshot,
                        background = BTN_PRESETS.ERROR,
                        disabled = not finalGameVehID,
                        onClick = function()
                            BJITx.player.explodeVehicle(vehicle.gameVehID)
                        end
                    })
            end
            line:build()
        end
        Indent(-1)
    end
end

local function drawPlayerDetails(playerID, ctxt)
    local target = BJIContext.Players[playerID]
    local isSelf = BJIContext.isSelf(playerID)
    local targetGroup = BJIPerm.Groups[target.group]
    local isGroupLower = ctxt.group.level > targetGroup.level

    if not isSelf then
        local labels = {
            "moderationBlock.muteReason",
            "moderationBlock.kickReason",
            "moderationBlock.banReason",
            "moderationBlock.tempBanDuration",
        }
        local labelWidth = 0
        for _, k in ipairs(labels) do
            local label = BJILang.get(k)
            local w = GetColumnTextWidth(label .. ":")
            if w > labelWidth then
                labelWidth = w
            end
        end

        local buttonsWidth = GetBtnIconSize()
        local labelKickButton = BJILang.get("moderationBlock.buttons.kick")
        if GetColumnTextWidth(labelKickButton) > buttonsWidth then
            buttonsWidth = GetColumnTextWidth(labelKickButton)
        end

        ColumnsBuilder(svar("moderation{1}", { playerID }), { labelWidth, -1, buttonsWidth })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("moderationBlock.muteReason"))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = svar("muteReason{1}", { playerID }),
                                value = target.muteReason,
                                onUpdate = function(val)
                                    target.muteReason = val
                                end
                            })
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :btnIconSwitch({
                                id = svar("toggleMute{1}", { playerID }),
                                iconEnabled = ICONS.speaker_notes_off,
                                state = target.muted == true,
                                onClick = function()
                                    BJITx.moderation.mute(target.playerName, target.muteReason)
                                end
                            })
                            :build()
                    end
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("moderationBlock.kickReason"))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = svar("kickReason{1}", { playerID }),
                                value = target.kickReason,
                                onUpdate = function(val)
                                    target.kickReason = val
                                end
                            })
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :btn({
                                id = svar("kick{1}", { playerID }),
                                label = labelKickButton,
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        svar(BJILang.get("moderationBlock.kickModal"),
                                            { playerName = target.playerName }),
                                        {
                                            {
                                                label = BJILang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJILang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJITx.moderation.kick(playerID, target.kickReason)
                                                end
                                            }
                                        }
                                    )
                                end
                            })
                            :build()
                    end
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("moderationBlock.banReason"))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = svar("banReason{1}", { playerID }),
                                value = target.banReason,
                                onUpdate = function(val)
                                    target.banReason = val
                                end
                            })
                            :build()
                    end,
                    BJIPerm.hasPermission(BJIPerm.PERMISSIONS.BAN) and function()
                        LineBuilder()
                            :btnIcon({
                                id = svar("ban{1}", { playerID }),
                                icon = ICONS.gavel,
                                background = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        svar(BJILang.get("moderationBlock.banModal"),
                                            { playerName = target.playerName }),
                                        {
                                            {
                                                label = BJILang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJILang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJITx.moderation.ban(target.playerName, target.banReason)
                                                end
                                            }
                                        }
                                    )
                                end
                            })
                            :build()
                    end or nil
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("moderationBlock.tempBanDuration"))
                            :build()
                    end,
                    function()
                        local delay = tonumber(target.tempBanDuration) or 0
                        LineBuilder()
                            :text(PrettyDelay(delay))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :btnIcon({
                                id = svar("tempBan{1}", { playerID }),
                                icon = ICONS.av_timer,
                                background = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        svar(BJILang.get("moderationBlock.tempBanModal"),
                                            { playerName = target.playerName }),
                                        {
                                            {
                                                label = BJILang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJILang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJITx.moderation.tempban(target.playerName,
                                                        target.tempBanDuration,
                                                        target.banReason)
                                                end
                                            }
                                        }
                                    )
                                end
                            })
                            :build()
                    end
                }
            })
            :build()

        local min, max = BJIContext.BJC.TempBan.minTime, BJIContext.BJC.TempBan.maxTime
        DrawLineDurationModifiers("tempBanDuration" .. tostring(playerID),
            target.tempBanDuration, min, max, BJIContext.BJC.TempBan.minTime, function(val)
                target.tempBanDuration = val
            end)

        local showDemote = isGroupLower and
            not tincludes({ BJI_GROUP_NAMES.NONE, BJI_GROUP_NAMES.OWNER },
                target.group)
        local showPromote = isGroupLower and
            not tincludes({ BJI_GROUP_NAMES.OWNER },
                BJIPerm.getNextGroup(target.group))
        if showDemote or showPromote then
            local line = LineBuilder()
            if showDemote then
                local previous = BJIPerm.getPreviousGroup(target.group)
                line:btn({
                    id = svar("demote{1}", { playerID }),
                    label = svar(BJILang.get("moderationBlock.buttons.demoteTo"),
                        { groupName = BJILang.get("groups." .. previous, previous) }),
                    style = BTN_PRESETS.ERROR,
                    onClick = function()
                        BJITx.moderation.setGroup(target.playerName, previous)
                    end
                })
            end
            local next = BJIPerm.getNextGroup(target.group)
            if showPromote and next then
                line:btn({
                    id = svar("promote{1}", { playerID }),
                    label = svar(BJILang.get("moderationBlock.buttons.promoteTo"),
                        { groupName = BJILang.get("groups." .. next, next) }),
                    style = BTN_PRESETS.SUCCESS,
                    onClick = function()
                        BJITx.moderation.setGroup(target.playerName, next)
                    end
                })
            end
            line:build()
        end
    end

    drawPlayerVehicles(playerID, ctxt)
end

local function drawWaitingPlayers(players)
    if #players == 0 then
        return
    end

    LineBuilder()
        :text(svar("{1}:", { BJILang.get("moderationBlock.waitingPlayers") }))
        :build()
    Indent(1)
    for _, player in ipairs(players) do
        local nextGroup = BJIPerm.getNextGroup(player.group)
        LineBuilder()
            :text(player.playerName)
            :text(svar("({1})", { player.group }))
            :btn({
                id = svar("promotewaiting{1}", { player.playerID }),
                label = svar(BJILang.get("moderationBlock.buttons.promoteTo"),
                    { groupName = BJILang.get("groups." .. nextGroup, nextGroup) }),
                onClick = function()
                    BJITx.moderation.setGroup(player.playerName, nextGroup)
                end
            })
            :build()
    end
    Indent(-1)
    EmptyLine()
end

local function drawListPlayers(players, ctxt)
    local drawHeaderActions = function(targetID, isAccordionOpen)
        local actions = getHeaderActions(targetID, isAccordionOpen, ctxt)
        if not isAccordionOpen then
            Indent(2)
        end
        local line = LineBuilder(true)
        for _, action in ipairs(actions) do
            if action == actionLinebreak then
                line:build()
                line = LineBuilder()
            elseif action.icon then
                line:btnIcon(action)
            elseif action.labelOn then
                line:btnSwitch(action)
            else
                line:btn(action)
            end
        end
        line:build()
        if not isAccordionOpen then
            Indent(-2)
        end
    end

    LineBuilder()
        :text(svar("{1}:", { BJILang.get("moderationBlock.players") }))
        :build()
    for _, player in ipairs(players) do
        local isSelf = BJIContext.isSelf(player.playerID)
        local targetGroup = BJIPerm.Groups[player.group] or { level = 0 }
        local isGroupLower = ctxt.group.level > targetGroup.level

        local groupLabel = BJILang.get(svar("groups.{1}", { player.group }), player.group)

        if isSelf and tlength(player.vehicles) == 0 then
            -- self without vehicles
            Indent(1)
            LineBuilder()
                :text(player.playerName, TEXT_COLORS.HIGHLIGHT)
                :text(svar("({1})", { groupLabel }), TEXT_COLORS.HIGHLIGHT)
                :build()
            Indent(-1)
        elseif not isSelf and not isGroupLower then
            -- similar or higher staff member
            Indent(1)
            LineBuilder()
                :text(player.playerName)
                :text(svar("({1})", { groupLabel }))
                :build()
            drawHeaderActions(player.playerID, false)
            Indent(-1)
        else
            -- players and lower staff members
            local reputationLabel = not player.staff and
                svar("{1}{2}", {
                    BJILang.get("chat.reputationTag"),
                    BJIReputation.getReputationLevel(player.reputation)
                }) or nil
            local nameSuffix = reputationLabel and
                svar("({1} | {2})", { groupLabel, reputationLabel }) or
                svar("({1})", { groupLabel })
            AccordionBuilder()
                :label("##" .. player.playerName)
                :commonStart(
                    function()
                        local color = isSelf and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
                        LineBuilder(true)
                            :text(player.playerName, color)
                            :text(nameSuffix, color)
                            :build()
                    end
                )
                :closedBehavior(
                    function()
                        drawHeaderActions(player.playerID, false)
                    end
                )
                :openedBehavior(
                    function()
                        drawHeaderActions(player.playerID, true)

                        drawPlayerDetails(player.playerID, ctxt)
                    end
                )
                :build()
        end
    end
end

local function drawModeration(ctxt)
    if tlength(BJIContext.Players) == 0 then
        LineBuilder()
            :text(BJILang.get("common.loading"))
            :build()
        return
    end

    local waitingPlayers, players = {}, {}
    for playerID, player in pairs(BJIContext.Players) do
        if BJIPerm.canSpawnVehicle(playerID) then
            table.insert(players, player)
        else
            table.insert(waitingPlayers, player)
        end
    end
    table.sort(waitingPlayers, function(a, b)
        return a.playerName < b.playerName
    end)
    table.sort(players, function(a, b)
        return a.playerName < b.playerName
    end)

    drawWaitingPlayers(waitingPlayers)
    drawListPlayers(players, ctxt)
end

return drawModeration
