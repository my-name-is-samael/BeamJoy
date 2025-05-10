local M = {
    reset = {
        restricted = false,
        nextExempt = false,
    },
    teleport = {
        restricted = false,
    },
    engineStates = {},
}

local function canChangeTo()
    return true
end

local function onLoad(ctxt)
    BJICam.resetForceCamera()
    BJICam.resetRestrictedCameras()

    BJIRestrictions.update({ {
        restrictions = Table({
            not BJIPerm.canSpawnAI() and BJIRestrictions.OTHER.AI_CONTROL or nil,
            not BJIPerm.canSpawnVehicle() and BJIRestrictions.OTHER.VEHICLE_SELECTOR or nil,
            not BJIPerm.canSpawnVehicle() and BJIRestrictions.OTHER.VEHICLE_PARTS_SELECTOR or nil,
            (BJIContext.BJC.Freeroam and not BJIContext.BJC.Freeroam.AllowUnicycle) and
            BJIRestrictions.OTHER.WALKING or nil,
        }):values():flat(),
        state = true,
    } })

    M.reset.restricted = false
    M.reset.nextExempt = false
    M.teleport.restricted = false

    BJIAsync.task(function()
        return not not BJIContext.BJC.Freeroam
    end, function()
        BJIBigmap.toggleQuickTravel(BJIContext.BJC.Freeroam.QuickTravel)
    end, "BJIScenarioFreeroamLoadUpdateQuickTravel")
    BJINametags.tryUpdate()
end

local function tryApplyFreeze(gameVehID)
    local veh
    for _, v in pairs(BJIContext.User.vehicles) do
        if v.gameVehID == gameVehID then
            veh = v
            break
        end
    end
    if not veh then
        return
    end

    local state = BJIContext.User.freeze or veh.freeze or veh.freezeStation
    BJIVeh.freeze(state, gameVehID)
end

local function tryApplyEngineState(gameVehID)
    local veh
    for _, v in pairs(BJIContext.User.vehicles) do
        if v.gameVehID == gameVehID then
            veh = v
            break
        end
    end
    if not veh then
        return
    end

    if M.engineStates[gameVehID] == nil then
        M.engineStates[gameVehID] = true
    end

    local state = BJIContext.User.engine and veh.engine and veh.engineStation
    if state and M.engineStates[gameVehID] then
        return
    else
        M.engineStates[gameVehID] = state
    end
    BJIVeh.engine(state, gameVehID)
    if not state then
        BJIVeh.lights(false, gameVehID)
    end
end

local function renderTick(ctxt)
    if not BJIContext.User.engine then
        for _, veh in pairs(BJIContext.User.vehicles) do
            BJIVeh.engine(false, veh.gameVehID)
            BJIVeh.lights(false, veh.gameVehID)
        end
    else
        for _, veh in pairs(BJIContext.User.vehicles) do
            if not veh.engine or not veh.engineStation then
                BJIVeh.engine(false, veh.gameVehID)
                BJIVeh.lights(false, veh.gameVehID)
            end
        end
    end
end

local function slowTick(ctxt)
    -- engine states cleanup
    for gameVehID in pairs(M.engineStates) do
        if not BJIVeh.getVehicleObject(gameVehID) or
            not BJIVeh.isVehicleOwn(gameVehID) then
            M.engineStates[gameVehID] = nil
        end
    end
end

local function onVehicleSpawned(gameVehID)
    BJIVeh.onVehicleSpawned(gameVehID)

    if BJIContext.BJC.Freeroam.PreserveEnergy then
        M.exemptPreserveEnergy = true
    end

    if not BJIContext.Scenario.isEditorOpen() then
        tryApplyFreeze(gameVehID)
        tryApplyEngineState(gameVehID)
    end
end

local function onVehicleResetted(gameVehID)
    if gameVehID ~= BJIContext.User.currentVehicle then
        return
    end

    if M.exemptPreserveEnergy then
        M.exemptPreserveEnergy = nil
    elseif BJIContext.BJC.Freeroam.PreserveEnergy then
        BJIVeh.postResetPreserveEnergy(gameVehID)
    end

    -- ResetTimer restriction
    local isResetDelay = BJIContext.BJC.Freeroam.ResetDelay > 0
    local bypass = BJIPerm.isStaff() or M.reset.nextExempt
    if isResetDelay and not bypass then
        M.reset.restricted = true
        BJIRestrictions.updateResets(BJIRestrictions.RESET.ALL)
        BJIAsync.delayTask(
            function()
                M.reset.restricted = false
                BJIRestrictions.updateResets({})
            end,
            BJIContext.BJC.Freeroam.ResetDelay * 1000,
            BJIAsync.KEYS.RESTRICTIONS_RESET_TIMER
        )
    end
    M.reset.nextExempt = false

    if not BJIContext.Scenario.isEditorOpen() then
        tryApplyFreeze(gameVehID)
        tryApplyEngineState(gameVehID)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if BJIVeh.isVehicleOwn(newGameVehID) and not BJIContext.Scenario.isEditorOpen() then
        tryApplyFreeze(newGameVehID)
        tryApplyEngineState(newGameVehID)
    end
end

local function updateVehicles()
    if not BJIContext.Scenario.isEditorOpen() then
        for _, veh in pairs(BJIContext.User.vehicles) do
            tryApplyFreeze(veh.gameVehID)
            tryApplyEngineState(veh.gameVehID)
        end
    end
end

local function onDropPlayerAtCamera()
    BJIVeh.dropPlayerAtCamera(true)
end

local function onDropPlayerAtCameraNoReset()
    BJIVeh.dropPlayerAtCamera()
end

local function tryTeleportToPlayer(targetID, forced)
    local target = BJIContext.Players[targetID]
    if target == nil then
        LogError(string.var("Invalid player {1}", { targetID }))
        return
    elseif table.length(target.vehicles) == 0 or not target.currentVehicle then
        LogError(string.var("Player {1} has no vehicle", { targetID }))
        return
    end

    -- TeleportTimer restriction
    local isTeleportDelay = BJIContext.BJC.Freeroam.TeleportDelay > 0
    local bypass = BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.MOD)
    if not isTeleportDelay or forced or not M.teleport.restricted or bypass then
        M.teleport.restricted = true

        -- teleporting triggers reset, so set flag to exempt from reset timer
        M.reset.nextExempt = true
        BJIVeh.teleportToPlayer(targetID)

        BJIAsync.delayTask(
            function()
                M.teleport.restricted = false
            end,
            BJIContext.BJC.Freeroam.TeleportDelay * 1000,
            BJIAsync.KEYS.RESTRICTIONS_TELEPORT_TIMER
        )
    end
end

local function tryTeleportToPos(pos, saveHome)
    -- setting position triggers reset, so set flag to exempt from reset timer
    M.reset.nextExempt = true
    BJIVeh.setPositionRotation(pos, nil, { saveHome = true })
end

local function tryFocus(targetID)
    BJIVeh.focus(targetID)
end

local function trySpawnNew(model, config)
    local group = BJIPerm.Groups[BJIContext.User.group]
    local limitReached = group.vehicleCap > -1 and group.vehicleCap <= table.length(BJIContext.User.vehicles)
    if BJIPerm.canSpawnVehicle() and not limitReached then
        M.exemptNextReset()
        BJIVeh.spawnNewVehicle(model, config)
    end
end

local function tryReplaceOrSpawn(model, config)
    local replacing = BJIVeh.isCurrentVehicleOwn()
    local group = BJIPerm.Groups[BJIContext.User.group]
    local limitReached = group.vehicleCap > -1 and group.vehicleCap <= table.length(BJIContext.User.vehicles)
    if BJIPerm.canSpawnVehicle() and (replacing or not limitReached) then
        M.exemptNextReset()
        BJIVeh.replaceOrSpawnVehicle(model, config)
    end
end

local function tryPaint(paint, paintNumber)
    if BJIVeh.isCurrentVehicleOwn() then
        M.exemptNextReset()
        BJIVeh.paintVehicle(paint, paintNumber)
    end
end

local function getModelList()
    local models = BJIVeh.getAllVehicleConfigs(
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SPAWN_TRAILERS),
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SPAWN_PROPS)
    )

    if not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.BYPASS_MODEL_BLACKLIST) and
        #BJIContext.Database.Vehicles.ModelBlacklist > 0 then
        for _, model in ipairs(BJIContext.Database.Vehicles.ModelBlacklist) do
            models[model] = nil
        end
    end

    return models
end

local function exemptNextReset()
    M.reset.nextExempt = true
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if player.vehiclesCount > 0 then
        local disabled = false
        if player.self then
            disabled = ctxt.isOwner and table.length(ctxt.user.vehicles) == 1
        else
            local finalGameVehID = BJIVeh.getVehicleObject(player.currentVehicle)
            finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
            disabled = finalGameVehID and ctxt.veh and ctxt.veh:getID() == finalGameVehID or false
        end
        table.insert(actions, {
            id = string.var("focus{1}", { player.playerID }),
            icon = ICONS.visibility,
            style = BTN_PRESETS.INFO,
            disabled = disabled,
            onClick = function()
                if player.self then
                    local selfVehs = {}
                    local currentOwnIndex
                    for _, v in pairs(BJIContext.User.vehicles) do
                        table.insert(selfVehs, v.gameVehID)
                        if v.gameVehID == BJIContext.User.currentVehicle then
                            currentOwnIndex = #selfVehs
                        end
                    end
                    local nextIndex
                    if currentOwnIndex then
                        -- if current veh is own, cycle to next index
                        nextIndex = (currentOwnIndex % #selfVehs) + 1
                    else
                        -- else focus first own veh
                        nextIndex = 1
                    end
                    BJIVeh.focusVehicle(selfVehs[nextIndex])
                else
                    -- another player current veh (or spec)
                    BJIVeh.focus(player.playerID)
                end
            end
        })
    end

    if ctxt.isOwner then
        if player.self and BJIVeh.isUnicycle(ctxt.veh:getID()) then
            table.insert(actions, {
                id = "stopWalking",
                icon = ICONS.directions_run,
                style = BTN_PRESETS.ERROR,
                onClick = BJIVeh.deleteCurrentOwnVehicle,
            })
        end

        if not player.self and player.vehiclesCount > 0 then
            table.insert(actions, {
                id = string.var("gpsPlayer{1}", { player.playerID }),
                icon = ICONS.add_location,
                style = BTN_PRESETS.SUCCESS,
                onClick = function()
                    BJIGPS.prependWaypoint(BJIGPS.KEYS.PLAYER, nil, 20, nil, player.playerName)
                end
            })

            if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.TELEPORT_TO) then
                table.insert(actions, {
                    id = string.var("teleportTo{1}", { player.playerID }),
                    icon = ICONS.tb_height_higher,
                    style = BTN_PRESETS.WARNING,
                    disabled = M.teleport.restricted,
                    onClick = function()
                        M.tryTeleportToPlayer(player.playerID)
                    end
                })
            end

            if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.TELEPORT_FROM) then
                local finalGameVehID = BJIVeh.getVehicleObject(player.currentVehicle)
                finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
                if finalGameVehID and BJIVeh.getVehOwnerID(finalGameVehID) == player.playerID then
                    table.insert(actions, {
                        id = string.var("teleportFrom{1}", { player.playerID }),
                        icon = ICONS.tb_height_lower,
                        style = BTN_PRESETS.WARNING,
                        disabled = not finalGameVehID or
                            not ctxt.isOwner or
                            finalGameVehID == ctxt.veh:getID(),
                        onClick = function()
                            BJITx.moderation.teleportFrom(player.playerID)
                        end
                    })
                end
            end
        end
    end

    if not BJIPerm.isStaff() and not player.self and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_KICK) and
        BJIVote.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            icon = ICONS.event_busy,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                BJIVote.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

local function onUnload(ctxt)
    BJIRestrictions.update({ {
        restrictions = Table({
            BJIRestrictions.RESET.ALL,
            BJIRestrictions.OTHER.AI_CONTROL,
            BJIRestrictions.OTHER.VEHICLE_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJIRestrictions.OTHER.WALKING,
        }):values():flat(),
        state = false,
    } })

    BJIBigmap.toggleQuickTravel(true)
    BJINametags.toggle(true)
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.onVehicleSpawned = onVehicleSpawned
M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched

M.onDropPlayerAtCamera = onDropPlayerAtCamera
M.onDropPlayerAtCameraNoReset = onDropPlayerAtCameraNoReset

M.updateVehicles = updateVehicles

M.tryTeleportToPlayer = tryTeleportToPlayer
M.tryTeleportToPos = tryTeleportToPos
M.tryFocus = tryFocus
M.trySpawnNew = trySpawnNew
M.tryReplaceOrSpawn = tryReplaceOrSpawn
M.tryPaint = tryPaint

M.canRefuelAtStation = TrueFn
M.canRepairAtGarage = TrueFn
M.canDeleteOtherPlayersVehicle = TrueFn
M.doShowNametagsSpecs = TrueFn

M.getModelList = getModelList

M.renderTick = renderTick
M.slowTick = slowTick

M.exemptNextReset = exemptNextReset

M.getPlayerListActions = getPlayerListActions

M.onUnload = onUnload

return M
