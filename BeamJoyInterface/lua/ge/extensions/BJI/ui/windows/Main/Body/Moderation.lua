local _actionLinebreak = "linebreak"
-- gc prevention
local skipLine, actions, opened, inputs, nextValue, min, max, canFocus, isCurrentVehicle

---@param cache table
local function drawWaitingPlayers(cache)
    if #cache.data.players.waiting == 0 then
        return
    end

    Text(cache.labels.players.moderation.waiting)
    Indent()
    for _, player in ipairs(cache.data.players.waiting) do
        Text(player.playerName)
        SameLine()
        Text(player.groupLabel)
        if player.demoteGroup then
            SameLine()
            if IconButton("demotewaiting" .. player.playerName, BJI.Utils.Icon.ICONS.person,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                BJI.Tx.moderation.setGroup(player.playerName, player.demoteGroup)
            end
            TooltipText(string.var(cache.labels.players.moderation.buttons.demoteTo,
                { group = player.demoteLabel }))
        end
        if player.promoteGroup then
            SameLine()
            if IconButton("promotewaiting" .. player.playerName, BJI.Utils.Icon.ICONS.person_add,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                BJI.Tx.moderation.setGroup(player.playerName, player.promoteGroup)
            end
            TooltipText(string.var(cache.labels.players.moderation.buttons.promoteTo,
                { group = player.promoteLabel }))
        end
    end
    Unindent()
    EmptyLine()
end

---@param player table
---@param isAccordionOpen boolean
---@param ctxt TickContext
local function getHeaderActions(player, isAccordionOpen, ctxt, cache)
    -- base actions
    actions = BJI.Managers.Scenario.getPlayerListActions(player, ctxt)

    -- VEHICLES DELETE
    if player.vehiclesCount > 0 and
        BJI.Managers.Scenario.isFreeroam() and
        (player.self or (player.isGroupLower and not player.staff and
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.DELETE_VEHICLE))) then
        table.insert(actions, {
            id = string.var("deleteVehicles{1}", { player.playerID }),
            icon = BJI.Utils.Icon.ICONS.directions_car,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = cache.labels.players.moderation.buttons.deleteAllVehicles,
            onClick = function()
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
                    icon = player.muted and BJI.Utils.Icon.ICONS.speaker_notes_off or BJI.Utils.Icon.ICONS.speaker_notes,
                    style = player.muted and BJI.Utils.Style.BTN_PRESETS.ERROR or BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    tooltip = cache.labels.players.moderation.buttons.mute,
                    onClick = function()
                        BJI.Tx.moderation.mute(player.playerName)
                    end
                })
            end

            if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.KICK) then
                table.insert(actions, {
                    id = string.var("kick{1}", { player.playerID }),
                    label = cache.labels.players.moderation.buttons.kick,
                    style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                    onClick = function()
                        BJI.Managers.Popup.createModal(
                            BJI.Managers.Lang.get("moderationBlock.kickModal")
                            :var({ playerName = player.playerName }), {
                                BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
                                BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"),
                                    function()
                                        BJI.Tx.moderation.kick(player.playerID)
                                    end),
                            })
                    end
                })
            end
        end
    end

    if player.isGroupLower and not player.staff then
        if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.FREEZE_PLAYERS) then
            table.insert(actions, {
                id = string.var("toggleFreeze{1}", { player.playerID }),
                icon = BJI.Utils.Icon.ICONS.ac_unit,
                style = player.freeze and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                tooltip = cache.labels.players.moderation.buttons.freeze,
                onClick = function()
                    BJI.Tx.moderation.freeze(player.playerID)
                end
            })
        end

        if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.ENGINE_PLAYERS) then
            table.insert(actions, {
                id = string.var("toggleEngine{1}", { player.playerID }),
                icon = BJI.Utils.Icon.ICONS.cogs,
                style = player.engine and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                tooltip = cache.labels.players.moderation.buttons.engine,
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
local function drawModeration(player, ctxt, cache)
    if player.demoteGroup or player.promoteGroup then
        if player.demoteGroup then
            if IconButton("demote" .. player.playerName, BJI.Utils.Icon.ICONS.person,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                BJI.Tx.moderation.setGroup(player.playerName, player.demoteGroup)
            end
            TooltipText(string.var(cache.labels.players.moderation.buttons.demoteTo,
                { group = player.demoteLabel }))
        end
        if player.demoteGroup and player.promoteGroup then
            SameLine()
        end
        if player.promoteGroup then
            if IconButton("promote" .. player.playerName, BJI.Utils.Icon.ICONS.person_add,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                BJI.Tx.moderation.setGroup(player.playerName, player.promoteGroup)
            end
            TooltipText(string.var(cache.labels.players.moderation.buttons.promoteTo,
                { group = player.promoteLabel }))
        end
    end

    inputs = cache.data.players.moderationInputs
    if BeginTable("BJIMainPlayerModeration-" .. player.playerName, {
            { label = "##main-player-moderation-label" },
            { label = "##main-player-moderation-input",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##main-player-moderation-actions" },
        }) then
        -- MUTE
        TableNewRow()
        Text(cache.labels.players.moderation.muteReason)
        TableNextColumn()
        nextValue = InputText("muteReason-" .. player.playerName, player.muted and
            player.muteReason or inputs.muteReason, { disabled = player.muted })
        if nextValue then
            inputs.muteReason = nextValue
        end
        TableNextColumn()
        if IconButton("toggleMute-" .. player.playerName, player.muted and
                BJI.Utils.Icon.ICONS.speaker_notes_off or BJI.Utils.Icon.ICONS.speaker_notes,
                { btnStyle = player.muted and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            BJI.Tx.moderation.mute(player.playerName, inputs.muteReason)
            inputs.muteReason = ""
        end
        TooltipText(cache.labels.players.moderation.buttons.mute)

        -- MUTE previous reason
        if not player.muted and player.muteReason and #player.muteReason > 0 then
            TableNewRow()
            Text(cache.labels.players.moderation.savedReason)
            TableNextColumn()
            Text(player.muteReason)
        end

        -- KICK
        TableNewRow()
        Text(cache.labels.players.moderation.kickReason)
        TableNextColumn()
        nextValue = InputText("kickReason-" .. player.playerName, inputs.kickReason)
        if nextValue then
            inputs.kickReason = nextValue
        end
        TableNextColumn()
        if Button("kick-" .. player.playerName, cache.labels.players.moderation.buttons.kick,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            BJI.Managers.Popup.createModal(
                BJI.Managers.Lang.get("moderationBlock.kickModal")
                :var({ playerName = player.playerName }), {
                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"),
                        function()
                            BJI.Tx.moderation.kick(player.playerID, inputs.kickReason)
                            inputs.kickReason = ""
                        end),
                })
        end

        -- KICK previous reason
        if player.kickReason and #player.kickReason > 0 then
            TableNewRow()
            Text(cache.labels.players.moderation.savedReason)
            TableNextColumn()
            Text(player.kickReason)
        end

        -- BAN REASON / BAN
        TableNewRow()
        Text(cache.labels.players.moderation.banReason)
        TableNextColumn()
        nextValue = InputText("banReason-" .. player.playerName, inputs.banReason)
        if nextValue then
            inputs.banReason = nextValue
        end
        TableNextColumn()
        if cache.data.players.canBan then
            if IconButton("ban-" .. player.playerName, BJI.Utils.Icon.ICONS.gavel,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                BJI.Managers.Popup.createModal(
                    BJI.Managers.Lang.get("moderationBlock.banModal")
                    :var({ playerName = player.playerName }), {
                        BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
                        BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"),
                            function()
                                BJI.Tx.moderation.ban(player.playerName, inputs.banReason)
                                inputs.banReason = ""
                            end),
                    })
            end
            TooltipText(cache.labels.players.moderation.buttons.ban)
        end

        -- BAN previous reason
        if player.banReason and #player.banReason > 0 then
            TableNewRow()
            Text(cache.labels.players.moderation.savedReason)
            TableNextColumn()
            Text(player.banReason)
        end

        -- TEMPBAN
        TableNewRow()
        Text(cache.labels.players.moderation.tempBanDuration)
        TableNextColumn()
        Text(BJI.Utils.UI.PrettyDelay(tonumber(inputs.tempBanDuration) or 0))
        TableNextColumn()
        if IconButton("tempBan-" .. player.playerName, BJI.Utils.Icon.ICONS.av_timer,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            BJI.Managers.Popup.createModal(
                BJI.Managers.Lang.get("moderationBlock.tempBanModal")
                :var({ playerName = player.playerName }), {
                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"),
                        function()
                            BJI.Tx.moderation.tempban(player.playerName,
                                inputs.tempBanDuration,
                                player.banReason)
                        end),
                })
        end
        TooltipText(cache.labels.players.moderation.buttons.tempban)

        EndTable()
    end

    if BJI.Managers.Context.BJC.TempBan then
        min, max = BJI.Managers.Context.BJC.TempBan.minTime, BJI.Managers.Context.BJC.TempBan.maxTime
        nextValue = BJI.Utils.UI.DrawLineDurationModifiers("tempBanDuration" .. tostring(player.playerID),
            inputs.tempBanDuration, min, max, BJI.Managers.Context.BJC.TempBan.minTime)
        if nextValue then
            inputs.tempBanDuration = nextValue
        end
    end
end

---@param player table
---@param ctxt TickContext
---@param cache table
local function drawVehicles(player, ctxt, cache)
    local function drawList()
        if BeginTable("BJIPlayerVehicles-" .. player.playerName, {
                { label = "##BJIPlayerVehicles-" .. player.playerName .. "-icon" },
                { label = "##BJIPlayerVehicles-" .. player.playerName .. "-name" },
                { label = "##BJIPlayerVehicles-" .. player.playerName .. "-actions", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            }) then
            for vehID, vehicle in pairs(player.vehicles) do
                TableNewRow()
                if vehicle.isAi then
                    Icon(BJI.Utils.Icon.ICONS.AIMicrochip, {
                        color = isCurrentVehicle and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                            BJI.Utils.Style.TEXT_COLORS.DEFAULT
                    })
                elseif isCurrentVehicle then
                    Icon(BJI.Utils.Icon.ICONS.visibility, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
                end
                TableNextColumn()
                Text(vehicle.model)
                TableNextColumn()
                if player.self or player.isGroupLower then
                    if canFocus then
                        if IconButton("focus-" .. player.playerName .. "-" .. tostring(vehID),
                                BJI.Utils.Icon.ICONS.cameraFocusOnVehicle2,
                                { btnStyle = BJI.Utils.Style.BTN_PRESETS.INFO }) then
                            BJI.Managers.Veh.focusVehicle(vehicle.finalGameVehID)
                        end
                        TooltipText(cache.labels.players.moderation.buttons.show)
                        SameLine()
                    end
                    if IconButton("toggleFreeze-" .. player.playerName .. "-" .. tostring(vehID),
                            BJI.Utils.Icon.ICONS.ac_unit, { disabled = not vehicle.finalGameVehID,
                                btnStyle = vehicle.freeze and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                        BJI.Tx.moderation.freeze(player.playerID, vehID)
                    end
                    TooltipText(cache.labels.players.moderation.buttons.freeze)
                    SameLine()
                    if IconButton("toggleEngine-" .. player.playerName .. "-" .. tostring(vehID),
                            BJI.Utils.Icon.ICONS.ac_unit, { disabled = not vehicle.finalGameVehID,
                                btnStyle = vehicle.engine and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                        BJI.Tx.moderation.engine(player.playerID, vehID)
                    end
                    TooltipText(cache.labels.players.moderation.buttons.engine)
                    SameLine()
                    if IconButton("delete-" .. player.playerName .. "-" .. tostring(vehID),
                            BJI.Utils.Icon.ICONS.delete_forever, { disabled = not vehicle.finalGameVehID,
                                btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                        BJI.Tx.moderation.deleteVehicle(player.playerID, vehicle.gameVehID)
                    end
                    TooltipText(cache.labels.players.moderation.buttons.delete)
                    SameLine()
                    if IconButton("explode-" .. player.playerName .. "-" .. tostring(vehID),
                            BJI.Utils.Icon.ICONS.whatshot,
                            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                        BJI.Tx.player.explodeVehicle(vehicle.gameVehID)
                    end
                    TooltipText(cache.labels.players.moderation.buttons.explode)
                end
            end
            EndTable()
        end
    end

    if player.showModeration then
        opened = BeginTree(cache.labels.players.moderation.vehicles ..
            "##" .. string.var("vehicles{1}", { player.playerID }))
        SameLine()
        Text(string.var("({1}):", { player.vehiclesCount }))
        if opened then
            drawList()
            EndTree()
        end
    else
        Text(cache.labels.players.moderation.vehicles)
        SameLine()
        Text(string.var("({1}):", { player.vehiclesCount }))
        drawList()
    end
end

---@param ctxt TickContext
---@param cache table
---@param player any
---@param isAccordionOpen boolean
local function drawHeaderActions(ctxt, cache, player, isAccordionOpen)
    skipLine = false
    actions = getHeaderActions(player, isAccordionOpen, ctxt, cache)
    if not isAccordionOpen then
        Indent(); Indent()
    end
    for _, action in ipairs(actions) do
        if not skipLine then
            SameLine()
        end
        skipLine = false
        if action == _actionLinebreak then
            skipLine = true
        elseif action.icon then
            if IconButton(action.id, action.icon, {
                    btnStyle = action.style,
                    disabled = action.disabled,
                }) then
                action.onClick()
            end
            if action.tooltip then
                TooltipText(action.tooltip)
            end
        else
            if Button(action.id, action.label, {
                    btnStyle = action.style,
                    disabled = action.disabled,
                }) then
                action.onClick()
            end
        end
    end
    if not isAccordionOpen then
        Unindent(); Unindent()
    end
end

---@param ctxt TickContext
---@param cache table
local function drawListPlayers(ctxt, cache)
    canFocus = not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH)

    Text(cache.labels.players.moderation.list)
    Table(cache.data.players.list):forEach(function(player)
        if not player.showModeration and not player.showVehicles then
            Indent()
            Text(player.playerName, {
                color = player.self and
                    BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
            })
            SameLine()
            Text(player.nameSuffix,
                { color = player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT })
            drawHeaderActions(ctxt, cache, player, false)
            Unindent()
        else
            opened = BeginTree(player.playerName,
                { color = player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT })
            SameLine()
            Text(player.nameSuffix,
                { color = player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT })
            drawHeaderActions(ctxt, cache, player, opened)
            if opened then
                if player.showModeration then
                    drawModeration(player, ctxt, cache)
                end
                if player.showVehicles then
                    drawVehicles(player, ctxt, cache)
                end
            end
        end
    end)
end

---@param ctxt TickContext
---@param cache table
return function(ctxt, cache)
    if #cache.data.players.list + #cache.data.players.waiting == 0 then
        Text(cache.labels.loading)
        return
    end

    drawWaitingPlayers(cache)
    drawListPlayers(ctxt, cache)
end
