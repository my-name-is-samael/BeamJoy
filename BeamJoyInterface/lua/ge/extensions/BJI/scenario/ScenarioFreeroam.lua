---@class BJIScenarioFreeroam : BJIScenario
local S = {
    _name = "Freeroam",
    _key = "FREEROAM",
    _isSolo = true,

    reset = {
        restricted = false,
        nextExempt = false,
    },
    teleport = {
        restricted = false,
    },
    engineStates = {},
}

local function onLoad(ctxt)
    BJI_Cam.resetForceCamera(true)
    BJI_Cam.resetRestrictedCameras()

    S.reset.restricted = false
    S.reset.nextExempt = false
    S.teleport.restricted = false
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    local res = Table()
    if not ctxt.isOwner then
        res:addAll(BJI_Restrictions.OTHER.FUN_STUFF, true)
    end
    return res
end

local function tryApplyFreeze(gameVehID)
    local veh
    for _, v in pairs(BJI_Context.User.vehicles) do
        if v.gameVehID == gameVehID then
            veh = v
            break
        end
    end
    if not veh then
        return
    end

    local state = BJI_Context.User.freeze or veh.freeze or veh.freezeStation
    BJI_Veh.freeze(state, gameVehID)
end

local function tryApplyEngineState(gameVehID)
    local veh
    for _, v in pairs(BJI_Context.User.vehicles) do
        if v.gameVehID == gameVehID then
            veh = v
            break
        end
    end
    if not veh then
        return
    end

    if S.engineStates[gameVehID] == nil then
        S.engineStates[gameVehID] = true
    end

    local state = BJI_Context.User.engine and veh.engine and veh.engineStation
    if state and S.engineStates[gameVehID] then
        return
    else
        S.engineStates[gameVehID] = state
    end
    BJI_Veh.engine(state, gameVehID)
    if not state then
        BJI_Veh.lights(false, gameVehID)
    end
end

local function fastTick(ctxt)
    if not BJI_Context.User.engine then
        for _, veh in pairs(BJI_Context.User.vehicles) do
            BJI_Veh.engine(false, veh.gameVehID)
            BJI_Veh.lights(false, veh.gameVehID)
        end
    else
        for _, veh in pairs(BJI_Context.User.vehicles) do
            if not veh.engine or not veh.engineStation then
                BJI_Veh.engine(false, veh.gameVehID)
                BJI_Veh.lights(false, veh.gameVehID)
            end
        end
    end
end

local function slowTick(ctxt)
    -- engine states cleanup
    for gameVehID in pairs(S.engineStates) do
        if not BJI_Veh.getVehicleObject(gameVehID) or
            not BJI_Veh.isVehicleOwn(gameVehID) then
            S.engineStates[gameVehID] = nil
        end
    end
end

---@param mpVeh BJIMPVehicle
local function onVehicleSpawned(mpVeh)
    if BJI_Context.BJC.Freeroam and
        BJI_Context.BJC.Freeroam.PreserveEnergy then
        S.exemptPreserveEnergy = true
    end

    if not BJI_Win_ScenarioEditor.getState() then
        tryApplyFreeze(mpVeh.gameVehicleID)
        tryApplyEngineState(mpVeh.gameVehicleID)
    end
end

local function onVehicleResetted(gameVehID)
    if gameVehID ~= BJI_Context.User.currentVehicle or
        not BJI_Veh.isVehicleOwn(gameVehID) then
        return
    end

    if S.exemptPreserveEnergy then
        S.exemptPreserveEnergy = nil
    elseif BJI_Context.BJC.Freeroam.PreserveEnergy then
        BJI_Veh.postResetPreserveEnergy(gameVehID)
    end

    -- ResetTimer restriction
    local isResetDelay = BJI_Context.BJC.Freeroam.ResetDelay > 0
    local bypass = BJI_Perm.isStaff() or S.reset.nextExempt
    if isResetDelay and not bypass then
        S.reset.restricted = true
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
        BJI_Restrictions.update()
        BJI_Async.delayTask(
            function()
                S.reset.restricted = false
                BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
                BJI_Restrictions.update()
            end,
            BJI_Context.BJC.Freeroam.ResetDelay * 1000,
            "restrictionsResetTimer"
        )
    end
    S.reset.nextExempt = false

    if not BJI_Win_ScenarioEditor.getState() then
        tryApplyFreeze(gameVehID)
        tryApplyEngineState(gameVehID)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if BJI_Veh.isVehicleOwn(newGameVehID) and
        not BJI_Win_ScenarioEditor.getState() then
        tryApplyFreeze(newGameVehID)
        tryApplyEngineState(newGameVehID)
    end
    BJI_Restrictions.update()
end

---@param gameVehID integer
---@param resetType string
---@return boolean
local function canReset(gameVehID, resetType)
    if BJI_Veh.isVehicleOwn(gameVehID) then
        return BJI_Perm.isStaff() or not S.reset.restricted
    else
        return table.includes({
            BJI_Input.INPUTS.RECOVER,
            BJI_Input.INPUTS.RECOVER_ALT,
            BJI_Input.INPUTS.LOAD_HOME,
            BJI_Input.INPUTS.RESET_PHYSICS,
            BJI_Input.INPUTS.RESET_ALL_PHYSICS,
            BJI_Input.INPUTS.RELOAD,
            BJI_Input.INPUTS.RELOAD_ALL,
        }, resetType)
    end
end

---@param gameVehID integer
---@return number
local function getRewindLimit(gameVehID)
    return -1
end

---@param gameVehID integer
---@param resetType string
---@param baseCallback fun()
---@return boolean
local function tryReset(gameVehID, resetType, baseCallback)
    if canReset(gameVehID, resetType) then
        if BJI_Veh.isVehicleOwn(gameVehID) then
            baseCallback()
            return true
        else
            if table.includes({
                    BJI_Input.INPUTS.RECOVER,
                    BJI_Input.INPUTS.RECOVER_ALT,
                    BJI_Input.INPUTS.LOAD_HOME,
                    BJI_Input.INPUTS.RESET_PHYSICS,
                    BJI_Input.INPUTS.RELOAD,
                }, resetType) then
                BJI_Veh.recoverInPlace()
                return true
            elseif table.includes({
                    BJI_Input.INPUTS.RESET_ALL_PHYSICS,
                    BJI_Input.INPUTS.RELOAD_ALL,
                }, resetType) then
                baseCallback()
                return true
            end
        end
    end
    return false
end

local function updateVehicles()
    if not BJI_Win_ScenarioEditor.getState() then
        for _, veh in pairs(BJI_Context.User.vehicles) do
            tryApplyFreeze(veh.gameVehID)
            tryApplyEngineState(veh.gameVehID)
        end
    end
end

local function onDropPlayerAtCamera()
    BJI_Veh.dropPlayerAtCamera(true)
end

local function onDropPlayerAtCameraNoReset()
    BJI_Veh.dropPlayerAtCamera()
end

local function tryTeleportToPlayer(targetID, forced)
    local target = BJI_Context.Players[targetID]
    if target == nil then
        LogError(string.var("Invalid player {1}", { targetID }))
        return
    elseif not target.currentVehicle or target.vehicles:length() == 0 then
        LogError(string.var("Player {1} has no vehicle", { targetID }))
        return
    end

    -- TeleportTimer restriction
    local isTeleportDelay = BJI_Context.BJC.Freeroam.TeleportDelay > 0
    local bypass = BJI_Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.MOD)
    if not isTeleportDelay or forced or not S.teleport.restricted or bypass then
        S.teleport.restricted = true

        -- teleporting triggers reset, so set flag to exempt from reset timer
        S.reset.nextExempt = true
        BJI_Veh.teleportToPlayer(targetID)

        BJI_Async.delayTask(
            function()
                S.teleport.restricted = false
            end,
            BJI_Context.BJC.Freeroam.TeleportDelay * 1000,
            "restrictionsTeleportTimer"
        )
    end
end

local function tryTeleportToPos(pos, saveHome)
    -- setting position triggers reset, so set flag to exempt from reset timer
    S.reset.nextExempt = true
    BJI_Veh.setPositionRotation(pos, nil, { saveHome = true })
end

local function tryFocus(targetID)
    BJI_Veh.focus(targetID)
end

local function trySpawnNew(model, config)
    local group = BJI_Perm.Groups[BJI_Context.User.group]
    local limitReached = group.vehicleCap > -1 and group.vehicleCap <= BJI_Veh.getSelfVehiclesCount()
    if BJI_Perm.canSpawnVehicle() and not limitReached then
        S.exemptNextReset()
        BJI_Veh.spawnNewVehicle(model, config)
    end
end

local function tryReplaceOrSpawn(model, config)
    local replacing = BJI_Veh.isCurrentVehicleOwn()
    local group = BJI_Perm.Groups[BJI_Context.User.group]
    local limitReached = group.vehicleCap > -1 and group.vehicleCap <= BJI_Veh.getSelfVehiclesCount()
    if BJI_Perm.canSpawnVehicle() and (replacing or not limitReached) then
        S.exemptNextReset()
        BJI_Veh.replaceOrSpawnVehicle(model, config)
    end
end

local function tryPaint(paintIndex, paint)
    local veh = BJI_Veh.getCurrentVehicleOwn()
    if veh then
        S.exemptNextReset()
        BJI_Veh.paintVehicle(veh, paintIndex, paint)
    end
end

local function canWalk()
    return BJI_Context.BJC.Freeroam and BJI_Context.BJC.Freeroam.AllowUnicycle
end

local function canShowNametags()
    return BJI_Context.BJC.Freeroam and BJI_Context.BJC.Freeroam.Nametags == true
end

---@param ctxt TickContext
local function canQuickTravel(ctxt)
    return BJI_Perm.isStaff() or
        (BJI_Context.BJC.Freeroam and BJI_Context.BJC.Freeroam.QuickTravel)
end

---@param ctxt TickContext
local function canUseNodegrabber(ctxt)
    return BJI_Perm.isStaff() or
        (BJI_Context.BJC.Freeroam and BJI_Context.BJC.Freeroam.Nodegrabber)
end

local function canSpawnNewVehicle()
    return (BJI_Perm.canSpawnVehicle() and BJI_Context.BJC.Freeroam.VehicleSpawning) or
        BJI_Perm.isStaff()
end

local function getModelList()
    local models = BJI_Veh.getAllVehicleConfigs(
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SPAWN_TRAILERS),
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SPAWN_PROPS)
    )

    if not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.BYPASS_MODEL_BLACKLIST) and
        #BJI_Context.Database.Vehicles.ModelBlacklist > 0 then
        for _, model in ipairs(BJI_Context.Database.Vehicles.ModelBlacklist) do
            models[model] = nil
        end
    end

    return models
end

local function exemptNextReset()
    S.reset.nextExempt = true
end

---@param player table
---@param ctxt TickContext
local function getPlayerListActions(player, ctxt)
    local actions = {}

    if player.vehiclesCount > 0 then
        local disabled = false
        if player.self then
            disabled = ctxt.isOwner and table.length(ctxt.user.vehicles) == 1
        else
            local veh = BJI_Veh.getVehicleObject(player.currentVehicle)
            local finalGameVehID = veh and veh:getID() or nil
            disabled = finalGameVehID and ctxt.veh and ctxt.veh.gameVehicleID == finalGameVehID or false
        end
        table.insert(actions, {
            id = string.var("focus{1}", { player.playerID }),
            icon = BJI.Utils.Icon.ICONS.visibility,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            disabled = disabled,
            tooltip = BJI_Lang.get("common.buttons.show"),
            onClick = function()
                if player.self then
                    local selfVehs = Table(ctxt.user.vehicles)
                        :filter(function(v) return not v.isAi end)
                        :map(function(v) return v.gameVehID end):values()
                    local currentOwnIndex = selfVehs:indexOf(BJI_Context.User.currentVehicle)
                    local nextIndex
                    if currentOwnIndex then
                        -- if current veh is own, cycle to next index
                        nextIndex = (currentOwnIndex % #selfVehs) + 1
                    else
                        -- else focus first own veh
                        nextIndex = 1
                    end
                    BJI_Veh.focusVehicle(selfVehs[nextIndex])
                else
                    -- another player current veh (or spec)
                    BJI_Veh.focus(player.playerID)
                end
            end
        })
    end

    if ctxt.isOwner then
        if player.self and BJI_Veh.isUnicycle(ctxt.veh.gameVehicleID) then
            table.insert(actions, {
                id = "stopWalking",
                icon = BJI.Utils.Icon.ICONS.directions_run,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                tooltip = BJI_Lang.get("playersBlock.buttons.stopWalking"),
                onClick = BJI_Veh.deleteCurrentOwnVehicle,
            })
        end

        if not player.self and player.vehiclesCount > 0 then
            table.insert(actions, {
                id = string.var("gpsPlayer{1}", { player.playerID }),
                icon = BJI.Utils.Icon.ICONS.add_location,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                tooltip = BJI_Lang.get("common.buttons.setGPS"),
                onClick = function()
                    BJI_GPS.prependWaypoint({
                        key = BJI_GPS.KEYS.PLAYER,
                        radius = 20,
                        playerName = player.playerName,
                    })
                end
            })

            if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.TELEPORT_TO) then
                table.insert(actions, {
                    id = string.var("teleportTo{1}", { player.playerID }),
                    icon = BJI.Utils.Icon.ICONS.tb_height_higher,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = S.teleport.restricted,
                    tooltip = BJI_Lang.get("playersBlock.buttons.teleportTo"),
                    onClick = function()
                        S.tryTeleportToPlayer(player.playerID)
                    end
                })
            end

            if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.TELEPORT_FROM) then
                local veh = BJI_Veh.getVehicleObject(player.currentVehicle)
                local finalGameVehID = veh and veh:getID() or nil
                if finalGameVehID and BJI_Veh.getVehOwnerID(finalGameVehID) == player.playerID then
                    table.insert(actions, {
                        id = string.var("teleportFrom{1}", { player.playerID }),
                        icon = BJI.Utils.Icon.ICONS.tb_height_lower,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not finalGameVehID or
                            not ctxt.isOwner or
                            finalGameVehID == ctxt.veh.gameVehicleID,
                        tooltip = BJI_Lang.get("playersBlock.buttons.teleportFrom"),
                        onClick = function()
                            BJI_Tx_moderation.teleportFrom(player.playerID)
                        end
                    })
                end
            end
        end
    end

    if BJI_Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

S.canChangeTo = TrueFn
S.onLoad = onLoad

S.getRestrictions = getRestrictions

S.onVehicleSpawned = onVehicleSpawned
S.onVehicleResetted = onVehicleResetted
S.onVehicleSwitched = onVehicleSwitched

S.canReset = canReset
S.getRewindLimit = getRewindLimit
S.tryReset = tryReset

S.onDropPlayerAtCamera = onDropPlayerAtCamera
S.onDropPlayerAtCameraNoReset = onDropPlayerAtCameraNoReset

S.updateVehicles = updateVehicles

S.tryTeleportToPlayer = tryTeleportToPlayer
S.tryTeleportToPos = tryTeleportToPos
S.tryFocus = tryFocus
S.trySpawnNew = trySpawnNew
S.tryReplaceOrSpawn = tryReplaceOrSpawn
S.tryPaint = tryPaint
S.canWalk = canWalk
S.canShowNametags = canShowNametags
S.canQuickTravel = canQuickTravel
S.canUseNodegrabber = canUseNodegrabber
S.canBoost = TrueFn
S.canSpawnNewVehicle = canSpawnNewVehicle

S.canRefuelAtStation = TrueFn
S.canRepairAtGarage = TrueFn
S.canDeleteOtherPlayersVehicle = TrueFn
S.canSpawnAI = TrueFn
S.doShowNametagsSpecs = TrueFn

S.getModelList = getModelList

S.fastTick = fastTick
S.slowTick = slowTick

S.exemptNextReset = exemptNextReset

S.getPlayerListActions = getPlayerListActions

return S
