local actionLinebreak = "linebreak"
local function getHeaderActions(player, isAccordionOpen, ctxt)
    -- base actions
    local actions = BJIScenario.getPlayerListActions(player, ctxt)

    -- VEHICLES DELETE
    if player.vehiclesCount > 0 and
        BJIScenario.isFreeroam() and
        (player.self or (player.isGroupLower and not player.staff and
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DELETE_VEHICLE))) then
        table.insert(actions, {
            id = string.var("deleteVehicles{1}", { player.playerID }),
            icon = ICONS.directions_car,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                if player.self then
                    BJIContext.User.currentVehicle = nil
                end
                BJITx.moderation.deleteVehicle(player.playerID, -1)
            end,
        })
    end

    if #actions > 0 then
        table.insert(actions, actionLinebreak)
    end

    -- line moderation actions
    if not player.self and player.isGroupLower and not player.staff then
        if not isAccordionOpen then
            if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.MUTE) then
                table.insert(actions, {
                    id = string.var("toggleMute{1}", { player.playerID }),
                    icon = ICONS.speaker_notes_off,
                    style = player.muted and BTN_PRESETS.SUCCESS or BTN_PRESETS.ERROR,
                    onClick = function()
                        BJITx.moderation.mute(player.playerName)
                    end
                })
            end

            if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.KICK) then
                table.insert(actions, {
                    id = string.var("kick{1}", { player.playerID }),
                    label = BJILang.get("moderationBlock.buttons.kick"),
                    style = BTN_PRESETS.ERROR,
                    onClick = function()
                        BJIPopup.createModal(
                            BJILang.get("moderationBlock.kickModal")
                            :var({ playerName = player.playerName }),
                            {
                                {
                                    label = BJILang.get("common.buttons.cancel"),
                                },
                                {
                                    label = BJILang.get("common.buttons.confirm"),
                                    onClick = function()
                                        BJITx.moderation.kick(player.playerID)
                                    end
                                }
                            }
                        )
                    end
                })
            end
        end
    end

    if player.isGroupLower and not player.staff then
        if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.FREEZE_PLAYERS) then
            table.insert(actions, {
                id = string.var("toggleFreeze{1}", { player.playerID }),
                icon = ICONS.ac_unit,
                style = player.freeze and BTN_PRESETS.SUCCESS or BTN_PRESETS.ERROR,
                onClick = function()
                    BJITx.moderation.freeze(player.playerID)
                end
            })
        end

        if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.ENGINE_PLAYERS) then
            table.insert(actions, {
                id = string.var("toggleEngine{1}", { player.playerID }),
                icon = ICONS.cogs,
                style = player.engine and BTN_PRESETS.SUCCESS or BTN_PRESETS.ERROR,
                onClick = function()
                    BJITx.moderation.engine(player.playerID)
                end
            })
        end
    end

    return actions
end

local function drawPlayerVehicles(player, ctxt, cache)
    if player.vehiclesCount > 0 then
        LineBuilder()
            :text(string.var("{1} ({2}):", { cache.labels.players.moderation.vehicles, player.vehiclesCount }))
            :build()

        local cols = ColumnsBuilder(string.var("BJIPlayerVehicles-{1}", { player.playerID }),
            { player.vehiclesLabelWidth, -1 })
        for vehID, vehicle in pairs(player.vehicles) do
            local finalGameVehID = BJIVeh.getVehicleObject(vehicle.gameVehID)
            finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
            local isCurrentVehicle = not finalGameVehID or (ctxt.veh and ctxt.veh:getID() == finalGameVehID)
            cols:addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text("@ =>", isCurrentVehicle and TEXT_COLORS.HIGHLIGHT or RGBA(0, 0, 0, 0))
                            :text(vehicle.model)
                            :build()
                    end,
                    (player.self or player.isGroupLower) and function()
                        LineBuilder()
                            :btnIcon({
                                id = string.var("focus{1}-{2}", { player.playerID, vehID }),
                                icon = ICONS.cameraFocusOnVehicle2,
                                style = BTN_PRESETS.INFO,
                                disabled = isCurrentVehicle,
                                onClick = function()
                                    BJIVeh.focusVehicle(finalGameVehID)
                                end
                            })
                            :btnIconToggle({
                                id = string.var("toggleFreeze{1}-{2}", { player.playerID, vehID }),
                                icon = ICONS.ac_unit,
                                state = not not vehicle.freeze,
                                disabled = not finalGameVehID,
                                onClick = function()
                                    BJITx.moderation.freeze(player.playerID, vehID)
                                end
                            })
                            :btnIconToggle({
                                id = string.var("toggleEngine{1}-{2}", { player.playerID, vehID }),
                                icon = ICONS.cogs,
                                state = not not vehicle.engine,
                                disabled = not finalGameVehID,
                                onClick = function()
                                    BJITx.moderation.engine(player.playerID, vehID)
                                end
                            })
                            :btnIcon({
                                id = string.var("delete{1}-{2}", { player.playerID, vehID }),
                                icon = ICONS.delete_forever,
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJITx.moderation.deleteVehicle(player.playerID, vehicle.gameVehID)
                                end
                            })
                            :btnIcon({
                                id = string.var("explode{1}-{2}", { player.playerID, vehID }),
                                icon = ICONS.whatshot,
                                style = BTN_PRESETS.ERROR,
                                disabled = not finalGameVehID,
                                onClick = function()
                                    BJITx.player.explodeVehicle(vehicle.gameVehID)
                                end
                            })
                            :build()
                    end,
                }
            })
        end
        cols:build()
    end
end

local function drawPlayerDetails(player, ctxt, cache)
    if not player.self then
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

        ColumnsBuilder(string.var("moderation{1}", { player.playerID }), { labelWidth, -1, buttonsWidth })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(cache.labels.players.moderation.muteReason)
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = string.var("muteReason{1}", { player.playerID }),
                                value = player.muteReason,
                                onUpdate = function(val)
                                    player.muteReason = val
                                end
                            })
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :btnIconToggle({
                                id = string.var("toggleMute{1}", { player.playerID }),
                                icon = ICONS.speaker_notes_off,
                                state = player.muted == true,
                                onClick = function()
                                    BJITx.moderation.mute(player.playerName, player.muteReason)
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
                            :text(cache.labels.players.moderation.kickReason)
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = string.var("kickReason{1}", { player.playerID }),
                                value = player.kickReason,
                                onUpdate = function(val)
                                    player.kickReason = val
                                end
                            })
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :btn({
                                id = string.var("kick{1}", { player.playerID }),
                                label = labelKickButton,
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        BJILang.get("moderationBlock.kickModal")
                                        :var({ playerName = player.playerName }),
                                        {
                                            {
                                                label = BJILang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJILang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJITx.moderation.kick(player.playerID, player.kickReason)
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
                            :text(cache.labels.players.moderation.banReason)
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = string.var("banReason{1}", { player.playerID }),
                                value = player.banReason,
                                onUpdate = function(val)
                                    player.banReason = val
                                end
                            })
                            :build()
                    end,
                    BJIPerm.hasPermission(BJIPerm.PERMISSIONS.BAN) and function()
                        LineBuilder()
                            :btnIcon({
                                id = string.var("ban{1}", { player.playerID }),
                                icon = ICONS.gavel,
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        BJILang.get("moderationBlock.banModal")
                                        :var({ playerName = player.playerName }),
                                        {
                                            {
                                                label = BJILang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJILang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJITx.moderation.ban(player.playerName, player.banReason)
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
                            :text(cache.labels.players.moderation.tempBanDuration)
                            :build()
                    end,
                    function()
                        local delay = tonumber(player.tempBanDuration) or 0
                        LineBuilder()
                            :text(PrettyDelay(delay))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :btnIcon({
                                id = string.var("tempBan{1}", { player.playerID }),
                                icon = ICONS.av_timer,
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        BJILang.get("moderationBlock.tempBanModal")
                                        :var({ playerName = player.playerName }),
                                        {
                                            {
                                                label = BJILang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJILang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJITx.moderation.tempban(player.playerName,
                                                        player.tempBanDuration,
                                                        player.banReason)
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
        DrawLineDurationModifiers("tempBanDuration" .. tostring(player.playerID),
            player.tempBanDuration, min, max, BJIContext.BJC.TempBan.minTime, function(val)
                player.tempBanDuration = val
            end)

        if player.demoteGroup or player.promoteGroup then
            local line = LineBuilder()
            if player.demoteGroup then
                line:btn({
                    id = string.var("demote{1}", { player.playerID }),
                    label = player.demoteLabel,
                    style = BTN_PRESETS.ERROR,
                    onClick = function()
                        BJITx.moderation.setGroup(player.playerName, player.demoteGroup)
                    end
                })
            end
            if player.promoteGroup then
                line:btn({
                    id = string.var("promote{1}", { player.playerID }),
                    label = player.promoteLabel,
                    style = BTN_PRESETS.SUCCESS,
                    onClick = function()
                        BJITx.moderation.setGroup(player.playerName, player.promoteGroup)
                    end
                })
            end
            line:build()
        end
    end

    drawPlayerVehicles(player, ctxt, cache)
end

local function drawWaitingPlayers(cache)
    if #cache.data.players.waiting == 0 then
        return
    end

    LineBuilder():text(cache.labels.players.moderation.waiting):build()
    Indent(1)
    for _, player in ipairs(cache.data.players.waiting) do
        if player.promoteGroup then
            LineBuilder()
                :text(player.playerName)
                :text(player.groupLabel)
                :btn({
                    id = string.var("promotewaiting{1}", { player.playerID }),
                    label = cache.labels.players.moderation.promoteWaitingTo
                        :var({ groupName = player.promoteLabel }),
                    onClick = function()
                        BJITx.moderation.setGroup(player.playerName, player.promoteGroup)
                    end
                })
                :build()
        end
    end
    Indent(-1)
    EmptyLine()
end

---@param ctxt TickContext
local function drawListPlayers(ctxt, cache)
    local drawHeaderActions = function(player, isAccordionOpen)
        local actions = getHeaderActions(player, isAccordionOpen, ctxt)
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
        :text(cache.labels.players.moderation.list)
        :build()
    for _, player in ipairs(cache.data.players.list) do
        if player.self and player.vehiclesCount == 0 then
            -- self without vehicles
            Indent(1)
            LineBuilder()
                :text(player.playerName, TEXT_COLORS.HIGHLIGHT)
                :text(player.nameSuffix, TEXT_COLORS.HIGHLIGHT)
                :build()
            drawHeaderActions(player, false)
            Indent(-1)
        elseif not player.showVehicles then
            -- same group or higher staff member
            Indent(1)
            LineBuilder()
                :text(player.playerName)
                :text(player.nameSuffix)
                :build()
            drawHeaderActions(player, false)
            Indent(-1)
        else
            -- players and lower staff members
            AccordionBuilder()
                :label("##" .. player.playerName)
                :commonStart(
                    function()
                        local color = player.self and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
                        LineBuilder(true)
                            :text(player.playerName, color)
                            :text(player.nameSuffix, color)
                            :build()
                    end
                )
                :closedBehavior(
                    function()
                        drawHeaderActions(player, false)
                    end
                )
                :openedBehavior(
                    function()
                        drawHeaderActions(player, true)

                        drawPlayerDetails(player, ctxt, cache)
                    end
                )
                :build()
        end
    end
end

---@param ctxt TickContext
local function drawModeration(ctxt, cache)
    if #cache.data.players.list + #cache.data.players.waiting == 0 then
        LineBuilder()
            :text(cache.labels.loading)
            :build()
        return
    end

    drawWaitingPlayers(cache)
    drawListPlayers(ctxt, cache)
end

return drawModeration
