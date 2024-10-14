local M = {
    reset = {
        restricted = false,
        nextExempt = false,
    },
    teleport = {
        restricted = false,
    },
}

local function canChangeTo()
    return true
end

local function onLoad(ctxt)
    BJICam.resetForceCamera()
    BJICam.resetRestrictedCameras()

    M.reset.restricted = false
    M.reset.nextExempt = false
    M.teleport.restricted = false

    BJIQuickTravel.toggle(BJIContext.BJC.Freeroam.QuickTravel)
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

    local state = BJIContext.User.freeze or veh.freeze
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

    local disabled = not BJIContext.User.engine or not veh.engine
    BJIVeh.engine(not disabled, gameVehID)
    if disabled then
        BJIVeh.lights(false, gameVehID)
    end
end

local function renderTick(ctxt)
    if BJIDEBUGCTXT then
        BJIDEBUG = ctxt
    end
    if not BJIContext.User.engine then
        for _, veh in pairs(BJIContext.User.vehicles) do
            BJIVeh.engine(false, veh.gameVehID)
            BJIVeh.lights(false, veh.gameVehID)
        end
    else
        for _, veh in pairs(BJIContext.User.vehicles) do
            if not veh.engine then
                BJIVeh.engine(false, veh.gameVehID)
                BJIVeh.lights(false, veh.gameVehID)
            end
        end
    end

    BJIDrift.updateRealtimeDisplay(ctxt)
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
    local bypass = BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.MOD) or M.reset.nextExempt
    if isResetDelay and not bypass then
        M.reset.restricted = true
        BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, true)
        BJIAsync.delayTask(
            function()
                M.reset.restricted = false
                BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
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
        LogError(svar("Invalid player {1}", { targetID }))
        return
    elseif tlength(target.vehicles) == 0 or not target.currentVehicle then
        LogError(svar("Player {1} has no vehicle", { targetID }))
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
    local limitReached = group.vehicleCap > -1 and group.vehicleCap <= tlength(BJIContext.User.vehicles)
    if BJIPerm.canSpawnVehicle() and not limitReached then
        M.exemptNextReset()
        BJIVeh.spawnNewVehicle(model, config)
    end
end

local function tryReplaceOrSpawn(model, config)
    local replacing = BJIVeh.isCurrentVehicleOwn()
    local group = BJIPerm.Groups[BJIContext.User.group]
    local limitReached = group.vehicleCap > -1 and group.vehicleCap <= tlength(BJIContext.User.vehicles)
    if BJIPerm.canSpawnVehicle() and (replacing or not limitReached) then
        M.exemptNextReset()
        BJIVeh.replaceOrSpawnVehicle(model, config)
    end
end

local function tryPaint(paint, paintNumber)
    PrintObj("tryPaint FREEROAM")
    if BJIVeh.isCurrentVehicleOwn() then
        PrintObj("tryPaint FREEROAM own")
        M.exemptNextReset()
        BJIVeh.paintVehicle(paint, paintNumber)
    end
end

local function canRefuelAtStation()
    return true
end

local function canRepairAtGarage()
    return true
end

local function canSpawnAI()
    return true
end

local function canDeleteOtherPlayersVehicle()
    return true
end

local function doShowNametagsSpecs(vehData)
    return true
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

    local isSelf = BJIContext.isSelf(player.playerID)

    if tlength(player.vehicles) > 0 then
        local disabled = false
        if isSelf then
            disabled = ctxt.isOwner and tlength(ctxt.user.vehicles) == 1
        else
            local finalGameVehID = BJIVeh.getVehicleObject(player.currentVehicle)
            finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
            disabled = finalGameVehID and ctxt.veh and ctxt.veh:getID() == finalGameVehID or false
        end
        table.insert(actions, {
            id = svar("focus{1}", { player.playerID }),
            icon = ICONS.visibility,
            background = BTN_PRESETS.INFO,
            disabled = disabled,
            onClick = function()
                if isSelf then
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

        if ctxt.isOwner then
            if isSelf then
                if BJIVeh.isUnicycle(ctxt.veh:getID()) then
                    table.insert(actions, {
                        id = svar("stopWalking{1}", { player.playerID }),
                        icon = ICONS.directions_run,
                        background = BTN_PRESETS.ERROR,
                        onClick = BJIVeh.deleteCurrentOwnVehicle,
                    })
                end
            else
                table.insert(actions, {
                    id = svar("gpsPlayer{1}", { player.playerID }),
                    icon = ICONS.add_location,
                    background = BTN_PRESETS.SUCCESS,
                    onClick = function()
                        BJIGPS.prependWaypoint(BJIGPS.KEYS.PLAYER, nil, 20, nil, player.playerName)
                    end
                })

                if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.TELEPORT_TO) then
                    table.insert(actions, {
                        id = svar("teleportTo{1}", { player.playerID }),
                        icon = ICONS.tb_height_higher,
                        background = BTN_PRESETS.WARNING,
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
                            id = svar("teleportFrom{1}", { player.playerID }),
                            icon = ICONS.tb_height_lower,
                            background = BTN_PRESETS.WARNING,
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
    end

    if not BJIPerm.isStaff() and not isSelf and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_KICK) and
        BJIVote.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = svar("voteKick{1}", { player.playerID }),
            icon = ICONS.event_busy,
            background = BTN_PRESETS.ERROR,
            onClick = function()
                BJIVote.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

local function onUnload(ctxt)
    BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)

    BJIQuickTravel.toggle(true)
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

M.canRefuelAtStation = canRefuelAtStation
M.canRepairAtGarage = canRepairAtGarage
M.canSpawnAI = canSpawnAI
M.canDeleteOtherPlayersVehicle = canDeleteOtherPlayersVehicle

M.doShowNametagsSpecs = doShowNametagsSpecs

M.getModelList = getModelList

M.renderTick = renderTick

M.exemptNextReset = exemptNextReset

M.getPlayerListActions = getPlayerListActions

M.onUnload = onUnload

return M
