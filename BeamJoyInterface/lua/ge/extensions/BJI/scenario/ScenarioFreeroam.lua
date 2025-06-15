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
    BJI.Managers.Cam.resetForceCamera(true)
    BJI.Managers.Cam.resetRestrictedCameras()

    S.reset.restricted = false
    S.reset.nextExempt = false
    S.teleport.restricted = false
end

local function tryApplyFreeze(gameVehID)
    local veh
    for _, v in pairs(BJI.Managers.Context.User.vehicles) do
        if v.gameVehID == gameVehID then
            veh = v
            break
        end
    end
    if not veh then
        return
    end

    local state = BJI.Managers.Context.User.freeze or veh.freeze or veh.freezeStation
    BJI.Managers.Veh.freeze(state, gameVehID)
end

local function tryApplyEngineState(gameVehID)
    local veh
    for _, v in pairs(BJI.Managers.Context.User.vehicles) do
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

    local state = BJI.Managers.Context.User.engine and veh.engine and veh.engineStation
    if state and S.engineStates[gameVehID] then
        return
    else
        S.engineStates[gameVehID] = state
    end
    BJI.Managers.Veh.engine(state, gameVehID)
    if not state then
        BJI.Managers.Veh.lights(false, gameVehID)
    end
end

local function fastTick(ctxt)
    if not BJI.Managers.Context.User.engine then
        for _, veh in pairs(BJI.Managers.Context.User.vehicles) do
            BJI.Managers.Veh.engine(false, veh.gameVehID)
            BJI.Managers.Veh.lights(false, veh.gameVehID)
        end
    else
        for _, veh in pairs(BJI.Managers.Context.User.vehicles) do
            if not veh.engine or not veh.engineStation then
                BJI.Managers.Veh.engine(false, veh.gameVehID)
                BJI.Managers.Veh.lights(false, veh.gameVehID)
            end
        end
    end
end

local function slowTick(ctxt)
    -- engine states cleanup
    for gameVehID in pairs(S.engineStates) do
        if not BJI.Managers.Veh.getVehicleObject(gameVehID) or
            not BJI.Managers.Veh.isVehicleOwn(gameVehID) then
            S.engineStates[gameVehID] = nil
        end
    end
end

local function onVehicleSpawned(gameVehID)
    if BJI.Managers.Context.BJC.Freeroam and
        BJI.Managers.Context.BJC.Freeroam.PreserveEnergy then
        S.exemptPreserveEnergy = true
    end

    if not BJI.Windows.ScenarioEditor.getState() then
        tryApplyFreeze(gameVehID)
        tryApplyEngineState(gameVehID)
    end
end

local function onVehicleResetted(gameVehID)
    if gameVehID ~= BJI.Managers.Context.User.currentVehicle or
        not BJI.Managers.Veh.isVehicleOwn(gameVehID) then
        return
    end

    if S.exemptPreserveEnergy then
        S.exemptPreserveEnergy = nil
    elseif BJI.Managers.Context.BJC.Freeroam.PreserveEnergy then
        BJI.Managers.Veh.postResetPreserveEnergy(gameVehID)
    end

    -- ResetTimer restriction
    local isResetDelay = BJI.Managers.Context.BJC.Freeroam.ResetDelay > 0
    local bypass = BJI.Managers.Perm.isStaff() or S.reset.nextExempt
    if isResetDelay and not bypass then
        S.reset.restricted = true
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
        BJI.Managers.Async.delayTask(
            function()
                S.reset.restricted = false
                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
            end,
            BJI.Managers.Context.BJC.Freeroam.ResetDelay * 1000,
            "restrictionsResetTimer"
        )
    end
    S.reset.nextExempt = false

    if not BJI.Windows.ScenarioEditor.getState() then
        tryApplyFreeze(gameVehID)
        tryApplyEngineState(gameVehID)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if BJI.Managers.Veh.isVehicleOwn(newGameVehID) and
        not BJI.Windows.ScenarioEditor.getState() then
        tryApplyFreeze(newGameVehID)
        tryApplyEngineState(newGameVehID)
    end
end

---@return boolean
local function canReset()
    return not S.reset.restricted
end

---@param ctxt BJCContext
---@return boolean?
local function saveHome(ctxt)
    if not S.reset.restricted then
        BJI.Managers.Veh.saveHome()
        return true
    end
end

---@param ctxt BJCContext
---@return boolean?
local function loadHome(ctxt)
    if not S.reset.restricted then
        BJI.Managers.Veh.loadHome()
        return true
    end
end

local function updateVehicles()
    if not BJI.Windows.ScenarioEditor.getState() then
        for _, veh in pairs(BJI.Managers.Context.User.vehicles) do
            tryApplyFreeze(veh.gameVehID)
            tryApplyEngineState(veh.gameVehID)
        end
    end
end

local function onDropPlayerAtCamera()
    BJI.Managers.Veh.dropPlayerAtCamera(true)
end

local function onDropPlayerAtCameraNoReset()
    BJI.Managers.Veh.dropPlayerAtCamera()
end

local function tryTeleportToPlayer(targetID, forced)
    local target = BJI.Managers.Context.Players[targetID]
    if target == nil then
        LogError(string.var("Invalid player {1}", { targetID }))
        return
    elseif not target.currentVehicle or target.vehicles:length() == 0 then
        LogError(string.var("Player {1} has no vehicle", { targetID }))
        return
    end

    -- TeleportTimer restriction
    local isTeleportDelay = BJI.Managers.Context.BJC.Freeroam.TeleportDelay > 0
    local bypass = BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.MOD)
    if not isTeleportDelay or forced or not S.teleport.restricted or bypass then
        S.teleport.restricted = true

        -- teleporting triggers reset, so set flag to exempt from reset timer
        S.reset.nextExempt = true
        BJI.Managers.Veh.teleportToPlayer(targetID)

        BJI.Managers.Async.delayTask(
            function()
                S.teleport.restricted = false
            end,
            BJI.Managers.Context.BJC.Freeroam.TeleportDelay * 1000,
            BJI.Managers.Async.KEYS.RESTRICTIONS_TELEPORT_TIMER
        )
    end
end

local function tryTeleportToPos(pos, saveHome)
    -- setting position triggers reset, so set flag to exempt from reset timer
    S.reset.nextExempt = true
    BJI.Managers.Veh.setPositionRotation(pos, nil, { saveHome = true })
end

local function tryFocus(targetID)
    BJI.Managers.Veh.focus(targetID)
end

local function trySpawnNew(model, config)
    local group = BJI.Managers.Perm.Groups[BJI.Managers.Context.User.group]
    local limitReached = group.vehicleCap > -1 and group.vehicleCap <= BJI.Managers.Veh.getSelfVehiclesCount()
    if BJI.Managers.Perm.canSpawnVehicle() and not limitReached then
        S.exemptNextReset()
        BJI.Managers.Veh.spawnNewVehicle(model, config)
    end
end

local function tryReplaceOrSpawn(model, config)
    local replacing = BJI.Managers.Veh.isCurrentVehicleOwn()
    local group = BJI.Managers.Perm.Groups[BJI.Managers.Context.User.group]
    local limitReached = group.vehicleCap > -1 and group.vehicleCap <= BJI.Managers.Veh.getSelfVehiclesCount()
    if BJI.Managers.Perm.canSpawnVehicle() and (replacing or not limitReached) then
        S.exemptNextReset()
        BJI.Managers.Veh.replaceOrSpawnVehicle(model, config)
    end
end

local function tryPaint(paintIndex, paint)
    local veh = BJI.Managers.Veh.getCurrentVehicleOwn()
    if veh then
        S.exemptNextReset()
        BJI.Managers.Veh.paintVehicle(veh, paintIndex, paint)
    end
end

local function canWalk()
    return BJI.Managers.Context.BJC.Freeroam and BJI.Managers.Context.BJC.Freeroam.AllowUnicycle
end

local function canShowNametags()
    return BJI.Managers.Context.BJC.Freeroam and BJI.Managers.Context.BJC.Freeroam.Nametags == true
end

local function canQuickTravel()
    return BJI.Managers.Perm.isStaff() or
        (BJI.Managers.Context.BJC.Freeroam and BJI.Managers.Context.BJC.Freeroam.QuickTravel)
end

local function canSpawnNewVehicle()
    return (BJI.Managers.Perm.canSpawnVehicle() and BJI.Managers.Context.BJC.Freeroam.VehicleSpawning) or
        BJI.Managers.Perm.isStaff()
end

local function getModelList()
    local models = BJI.Managers.Veh.getAllVehicleConfigs(
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SPAWN_TRAILERS),
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SPAWN_PROPS)
    )

    if not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.BYPASS_MODEL_BLACKLIST) and
        #BJI.Managers.Context.Database.Vehicles.ModelBlacklist > 0 then
        for _, model in ipairs(BJI.Managers.Context.Database.Vehicles.ModelBlacklist) do
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
            local veh = BJI.Managers.Veh.getVehicleObject(player.currentVehicle)
            local finalGameVehID = veh and veh:getID() or nil
            disabled = finalGameVehID and ctxt.veh and ctxt.veh:getID() == finalGameVehID or false
        end
        table.insert(actions, {
            id = string.var("focus{1}", { player.playerID }),
            icon = BJI.Utils.Icon.ICONS.visibility,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            disabled = disabled,
            tooltip = BJI.Managers.Lang.get("common.buttons.show"),
            onClick = function()
                if player.self then
                    local selfVehs = Table(ctxt.user.vehicles)
                        :map(function(v)
                            return v.gameVehID
                        end):values():filter(function(vid)
                            return not table.includes(ctxt.players[ctxt.user.playerID].ai, vid)
                        end)
                    local currentOwnIndex = selfVehs:indexOf(BJI.Managers.Context.User.currentVehicle)
                    local nextIndex
                    if currentOwnIndex then
                        -- if current veh is own, cycle to next index
                        nextIndex = (currentOwnIndex % #selfVehs) + 1
                    else
                        -- else focus first own veh
                        nextIndex = 1
                    end
                    BJI.Managers.Veh.focusVehicle(selfVehs[nextIndex])
                else
                    -- another player current veh (or spec)
                    BJI.Managers.Veh.focus(player.playerID)
                end
            end
        })
    end

    if ctxt.isOwner then
        if player.self and BJI.Managers.Veh.isUnicycle(ctxt.veh:getID()) then
            table.insert(actions, {
                id = "stopWalking",
                icon = BJI.Utils.Icon.ICONS.directions_run,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                tooltip = BJI.Managers.Lang.get("playersBlock.buttons.stopWalking"),
                onClick = BJI.Managers.Veh.deleteCurrentOwnVehicle,
            })
        end

        if not player.self and player.vehiclesCount > 0 then
            table.insert(actions, {
                id = string.var("gpsPlayer{1}", { player.playerID }),
                icon = BJI.Utils.Icon.ICONS.add_location,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                tooltip = BJI.Managers.Lang.get("common.buttons.setGPS"),
                onClick = function()
                    BJI.Managers.GPS.prependWaypoint({
                        key = BJI.Managers.GPS.KEYS.PLAYER,
                        radius = 20,
                        playerName = player.playerName,
                    })
                end
            })

            if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.TELEPORT_TO) then
                table.insert(actions, {
                    id = string.var("teleportTo{1}", { player.playerID }),
                    icon = BJI.Utils.Icon.ICONS.tb_height_higher,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    disabled = S.teleport.restricted,
                    tooltip = BJI.Managers.Lang.get("playersBlock.buttons.teleportTo"),
                    onClick = function()
                        S.tryTeleportToPlayer(player.playerID)
                    end
                })
            end

            if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.TELEPORT_FROM) then
                local veh = BJI.Managers.Veh.getVehicleObject(player.currentVehicle)
                local finalGameVehID = veh and veh:getID() or nil
                if finalGameVehID and BJI.Managers.Veh.getVehOwnerID(finalGameVehID) == player.playerID then
                    table.insert(actions, {
                        id = string.var("teleportFrom{1}", { player.playerID }),
                        icon = BJI.Utils.Icon.ICONS.tb_height_lower,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = not finalGameVehID or
                            not ctxt.isOwner or
                            finalGameVehID == ctxt.veh:getID(),
                        tooltip = BJI.Managers.Lang.get("playersBlock.buttons.teleportFrom"),
                        onClick = function()
                            BJI.Tx.moderation.teleportFrom(player.playerID)
                        end
                    })
                end
            end
        end
    end

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

S.canChangeTo = TrueFn
S.onLoad = onLoad

S.onVehicleSpawned = onVehicleSpawned
S.onVehicleResetted = onVehicleResetted
S.onVehicleSwitched = onVehicleSwitched

S.canReset = canReset
S.saveHome = saveHome
S.loadHome = loadHome

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
