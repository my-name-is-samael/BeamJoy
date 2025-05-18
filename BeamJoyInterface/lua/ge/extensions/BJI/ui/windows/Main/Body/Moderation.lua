local _actionLinebreak = "linebreak"

---@param player table
---@param isAccordionOpen boolean
---@param ctxt TickContext
local function getHeaderActions(player, isAccordionOpen, ctxt)
    -- base actions
    local actions = BJI.Managers.Scenario.getPlayerListActions(player, ctxt)

    -- VEHICLES DELETE
    if player.vehiclesCount > 0 and
        BJI.Managers.Scenario.isFreeroam() and
        (player.self or (player.isGroupLower and not player.staff and
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.DELETE_VEHICLE))) then
        table.insert(actions, {
            id = string.var("deleteVehicles{1}", { player.playerID }),
            icon = ICONS.directions_car,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = function()
                if player.self then
                    BJI.Managers.Context.User.currentVehicle = nil
                end
                BJI.Tx.moderation.deleteVehicle(player.playerID, -1)
            end,
        })
    end

    if #actions > 0 then
        table.insert(actions, _actionLinebreak)
    end

    -- line moderation actions
    if not player.self and player.isGroupLower and not player.staff then
        if not isAccordionOpen then
            if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.MUTE) then
                table.insert(actions, {
                    id = string.var("toggleMute{1}", { player.playerID }),
                    icon = ICONS.speaker_notes_off,
                    style = player.muted and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                    onClick = function()
                        BJI.Tx.moderation.mute(player.playerName)
                    end
                })
            end

            if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.KICK) then
                table.insert(actions, {
                    id = string.var("kick{1}", { player.playerID }),
                    label = BJI.Managers.Lang.get("moderationBlock.buttons.kick"),
                    style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                    onClick = function()
                        BJI.Managers.Popup.createModal(
                            BJI.Managers.Lang.get("moderationBlock.kickModal")
                            :var({ playerName = player.playerName }),
                            {
                                {
                                    label = BJI.Managers.Lang.get("common.buttons.cancel"),
                                },
                                {
                                    label = BJI.Managers.Lang.get("common.buttons.confirm"),
                                    onClick = function()
                                        BJI.Tx.moderation.kick(player.playerID)
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
        if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.FREEZE_PLAYERS) then
            table.insert(actions, {
                id = string.var("toggleFreeze{1}", { player.playerID }),
                icon = ICONS.ac_unit,
                style = player.freeze and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Tx.moderation.freeze(player.playerID)
                end
            })
        end

        if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.ENGINE_PLAYERS) then
            table.insert(actions, {
                id = string.var("toggleEngine{1}", { player.playerID }),
                icon = ICONS.cogs,
                style = player.engine and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Tx.moderation.engine(player.playerID)
                end
            })
        end
    end

    return actions
end

---@param player table
---@param ctxt TickContext
---@param cache table
local function drawVehicles(player, ctxt, cache)
    if player.vehiclesCount > 0 then
        local canFocus = not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH)

        local function drawList()
            local cols = ColumnsBuilder(string.var("BJIPlayerVehicles-{1}", { player.playerID }),
                { player.vehiclesLabelWidth, -1 })
            for vehID, vehicle in pairs(player.vehicles) do
                local isCurrentVehicle = ctxt.veh and ctxt.veh:getID() == vehicle.finalGameVehID
                cols:addRow({
                    cells = {
                        function()
                            local line = LineBuilder()
                            if vehicle.isAI then
                                line:icon({
                                    icon = ICONS.AIMicrochip,
                                    style = { isCurrentVehicle and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT },
                                    coloredIcon = true,
                                })
                            elseif isCurrentVehicle then
                                line:icon({
                                    icon = ICONS.visibility,
                                    style = { BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT },
                                    coloredIcon = true,
                                })
                            else
                                line:icon({
                                    icon = ICONS.visibility_off,
                                    style = { BJI.Utils.Style.RGBA(0, 0, 0, 0) },
                                    coloredIcon = true,
                                })
                            end
                            line:text(vehicle.model)
                                :build()
                        end,
                        (player.self or player.isGroupLower) and function()
                            local line = LineBuilder()
                            if canFocus then
                                line:btnIcon({
                                    id = string.var("focus{1}-{2}", { player.playerID, vehID }),
                                    icon = ICONS.cameraFocusOnVehicle2,
                                    style = BJI.Utils.Style.BTN_PRESETS.INFO,
                                    disabled = isCurrentVehicle,
                                    onClick = function()
                                        BJI.Managers.Veh.focusVehicle(vehicle.finalGameVehID)
                                    end
                                })
                            end
                            line:btnIconToggle({
                                id = string.var("toggleFreeze{1}-{2}", { player.playerID, vehID }),
                                icon = ICONS.ac_unit,
                                state = not not vehicle.freeze,
                                disabled = not vehicle.finalGameVehID,
                                onClick = function()
                                    BJI.Tx.moderation.freeze(player.playerID, vehID)
                                end
                            })
                                :btnIconToggle({
                                    id = string.var("toggleEngine{1}-{2}", { player.playerID, vehID }),
                                    icon = ICONS.cogs,
                                    state = not not vehicle.engine,
                                    disabled = not vehicle.finalGameVehID,
                                    onClick = function()
                                        BJI.Tx.moderation.engine(player.playerID, vehID)
                                    end
                                })
                                :btnIcon({
                                    id = string.var("delete{1}-{2}", { player.playerID, vehID }),
                                    icon = ICONS.delete_forever,
                                    style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                    onClick = function()
                                        BJI.Tx.moderation.deleteVehicle(player.playerID, vehicle.gameVehID)
                                    end
                                })
                                :btnIcon({
                                    id = string.var("explode{1}-{2}", { player.playerID, vehID }),
                                    icon = ICONS.whatshot,
                                    style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                    disabled = not vehicle.finalGameVehID,
                                    onClick = function()
                                        BJI.Tx.player.explodeVehicle(vehicle.gameVehID)
                                    end
                                })
                                :build()
                        end,
                    }
                })
            end
            cols:build()
        end

        local vehsLabel = string.var("{1} ({2}):", { cache.labels.players.moderation.vehicles, player.vehiclesCount })
        if player.showModeration then
            AccordionBuilder()
                :label(vehsLabel)
                :openedBehavior(drawList)
                :build()
        else
            LineLabel(vehsLabel)
            drawList()
        end
    end
end

---@param player table
---@param ctxt TickContext
---@param cache table
local function drawModeration(player, ctxt, cache)
    local inputs = cache.data.players.moderationInputs
    local cols = ColumnsBuilder(string.var("moderation{1}", { player.playerID }),
            { cache.widths.players.moderation.labels, -1, cache.widths.players.moderation.buttons })
        :addRow({
            cells = {
                function()
                    LineLabel(cache.labels.players.moderation.muteReason)
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = string.var("muteReason{1}", { player.playerID }),
                            value = inputs.muteReason,
                            onUpdate = function(val)
                                inputs.muteReason = val
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
                                BJI.Tx.moderation.mute(player.playerName, inputs.muteReason)
                                inputs.muteReason = ""
                            end
                        })
                        :build()
                end
            }
        })
    if player.muteReason and #player.muteReason > 0 then
        cols:addRow({
            cells = {
                function()
                    LineLabel(cache.labels.players.moderation.savedReason)
                end,
                function()
                    LineLabel(player.muteReason)
                end
            }
        })
    end
    cols:addRow({
        cells = {
            function()
                LineLabel(cache.labels.players.moderation.kickReason)
            end,
            function()
                LineBuilder()
                    :inputString({
                        id = string.var("kickReason{1}", { player.playerID }),
                        value = inputs.kickReason,
                        onUpdate = function(val)
                            inputs.kickReason = val
                        end
                    })
                    :build()
            end,
            function()
                LineBuilder()
                    :btn({
                        id = string.var("kick{1}", { player.playerID }),
                        label = cache.labels.players.moderation.kickButton,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        onClick = function()
                            BJI.Managers.Popup.createModal(
                                BJI.Managers.Lang.get("moderationBlock.kickModal")
                                :var({ playerName = player.playerName }),
                                {
                                    {
                                        label = BJI.Managers.Lang.get("common.buttons.cancel"),
                                    },
                                    {
                                        label = BJI.Managers.Lang.get("common.buttons.confirm"),
                                        onClick = function()
                                            BJI.Tx.moderation.kick(player.playerID, inputs.kickReason)
                                            inputs.kickReason = ""
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
    if player.kickReason and #player.kickReason > 0 then
        cols:addRow({
            cells = {
                function()
                    LineLabel(cache.labels.players.moderation.savedReason)
                end,
                function()
                    LineLabel(player.kickReason)
                end
            }
        })
    end
    cols:addRow({
        cells = {
            function()
                LineLabel(cache.labels.players.moderation.banReason)
            end,
            function()
                LineBuilder()
                    :inputString({
                        id = string.var("banReason{1}", { player.playerID }),
                        value = inputs.banReason,
                        onUpdate = function(val)
                            inputs.banReason = val
                        end
                    })
                    :build()
            end,
            cache.data.players.canBan and function()
                LineBuilder()
                    :btnIcon({
                        id = string.var("ban{1}", { player.playerID }),
                        icon = ICONS.gavel,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        onClick = function()
                            BJI.Managers.Popup.createModal(
                                BJI.Managers.Lang.get("moderationBlock.banModal")
                                :var({ playerName = player.playerName }),
                                {
                                    {
                                        label = BJI.Managers.Lang.get("common.buttons.cancel"),
                                    },
                                    {
                                        label = BJI.Managers.Lang.get("common.buttons.confirm"),
                                        onClick = function()
                                            BJI.Tx.moderation.ban(player.playerName, inputs.banReason)
                                            inputs.banReason = ""
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
    if player.banReason and #player.banReason > 0 then
        cols:addRow({
            cells = {
                function()
                    LineLabel(cache.labels.players.moderation.savedReason)
                end,
                function()
                    LineLabel(player.banReason)
                end
            }
        })
    end
    cols:addRow({
        cells = {
            function()
                LineLabel(cache.labels.players.moderation.tempBanDuration)
            end,
            function()
                LineLabel(BJI.Utils.Common.PrettyDelay(tonumber(inputs.tempBanDuration) or 0))
            end,
            function()
                LineBuilder()
                    :btnIcon({
                        id = string.var("tempBan{1}", { player.playerID }),
                        icon = ICONS.av_timer,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        onClick = function()
                            BJI.Managers.Popup.createModal(
                                BJI.Managers.Lang.get("moderationBlock.tempBanModal")
                                :var({ playerName = player.playerName }),
                                {
                                    {
                                        label = BJI.Managers.Lang.get("common.buttons.cancel"),
                                    },
                                    {
                                        label = BJI.Managers.Lang.get("common.buttons.confirm"),
                                        onClick = function()
                                            BJI.Tx.moderation.tempban(player.playerName,
                                                inputs.tempBanDuration,
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

    if BJI.Managers.Context.BJC.TempBan then
        local min, max = BJI.Managers.Context.BJC.TempBan.minTime, BJI.Managers.Context.BJC.TempBan.maxTime
        BJI.Utils.Common.DrawLineDurationModifiers("tempBanDuration" .. tostring(player.playerID),
            inputs.tempBanDuration, min, max, BJI.Managers.Context.BJC.TempBan.minTime, function(val)
                inputs.tempBanDuration = val
            end)
    end

    if player.demoteGroup or player.promoteGroup then
        local line = LineBuilder()
        if player.demoteGroup then
            line:btn({
                id = string.var("demote{1}", { player.playerID }),
                label = player.demoteLabel,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Tx.moderation.setGroup(player.playerName, player.demoteGroup)
                end
            })
        end
        if player.promoteGroup then
            line:btn({
                id = string.var("promote{1}", { player.playerID }),
                label = player.promoteLabel,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                onClick = function()
                    BJI.Tx.moderation.setGroup(player.playerName, player.promoteGroup)
                end
            })
        end
        line:build()
    end
end

---@param cache table
local function drawWaitingPlayers(cache)
    if #cache.data.players.waiting == 0 then
        return
    end

    LineBuilder():text(cache.labels.players.moderation.waiting):build()
    Indent(1)
    for _, player in ipairs(cache.data.players.waiting) do
        if player.promoteGroup then
            local line = LineBuilder()
                :text(player.playerName)
                :text(player.groupLabel)
            if cache.data.players.demoteGroup then
                line:btn({
                    id = string.var("demotewaiting{1}", { player.playerID }),
                    label = cache.labels.players.moderation.demoteWaitingTo
                        :var({ groupName = player.demoteLabel }),
                    onClick = function()
                        BJI.Tx.moderation.setGroup(player.playerName, player.demoteGroup)
                    end
                })
            end
            if cache.data.players.promoteGroup then
                line:btn({
                    id = string.var("promotewaiting{1}", { player.playerID }),
                    label = cache.labels.players.moderation.promoteWaitingTo
                        :var({ groupName = player.promoteLabel }),
                    onClick = function()
                        BJI.Tx.moderation.setGroup(player.playerName, player.promoteGroup)
                    end
                })
            end
            line:build()
        end
    end
    Indent(-1)
    EmptyLine()
end

---@param ctxt TickContext
---@param cache table
local function drawListPlayers(ctxt, cache)
    local drawHeaderActions = function(player, isAccordionOpen)
        local actions = getHeaderActions(player, isAccordionOpen, ctxt)
        if not isAccordionOpen then
            Indent(2)
        end
        local line = LineBuilder(true)
        for _, action in ipairs(actions) do
            if action == _actionLinebreak then
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

    LineLabel(cache.labels.players.moderation.list)
    Table(cache.data.players.list)
        :forEach(function(player)
            if not player.showModeration and not player.showVehicles then
                Indent(1)
                LineBuilder()
                    :text(player.playerName,
                        player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                    :text(player.nameSuffix,
                        player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                    :build()
                drawHeaderActions(player, false)
                Indent(-1)
            else
                AccordionBuilder(0)
                    :label(player.playerName,
                        player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                    :commonStart(function()
                        LineBuilder(true):text(player.nameSuffix,
                            player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                            :build()
                    end)
                    :closedBehavior(
                        function()
                            drawHeaderActions(player, false)
                        end
                    )
                    :openedBehavior(
                        function()
                            drawHeaderActions(player, true)

                            if player.showModeration then
                                drawModeration(player, ctxt, cache)
                            end
                            if player.showVehicles then
                                drawVehicles(player, ctxt, cache)
                            end
                        end
                    )
                    :build()
            end
        end)
end

---@param ctxt TickContext
---@param cache table
return function(ctxt, cache)
    if #cache.data.players.list + #cache.data.players.waiting == 0 then
        LineBuilder()
            :text(cache.labels.loading)
            :build()
        return
    end

    drawWaitingPlayers(cache)
    drawListPlayers(ctxt, cache)
end
