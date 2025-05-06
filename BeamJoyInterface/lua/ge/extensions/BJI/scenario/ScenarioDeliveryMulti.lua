local M = {
    -- server data
    participants = {},
    target = nil,

    baseDistance = nil,
    distance = nil,
    nextResetGarage = false,    -- exempt reset when repairing at a garage
    tanksSaved = nil,
    checkTargetProcess = false, -- process to check player reached target and stayed in its radius

    ui = {
        participants = {},
        playerLabelWidth = 0,
    }
}

local function updateUI()
    M.ui.playerLabelWidth = 0
    for playerID in pairs(M.participants) do
        local player = BJIContext.Players[playerID]
        M.ui.participants[playerID] = player.playerName

        local w = GetColumnTextWidth(M.ui.participants[playerID])
        if w > M.ui.playerLabelWidth then
            M.ui.playerLabelWidth = w
        end
    end
end

local function stop()
    -- server data
    M.participants = {}
    M.target = nil

    M.baseDistance = nil
    M.distance = nil
    M.tanksSaved = nil
    M.nextResetGarage = false

    BJIMessage.flash("BJIDeliveryMultiStop", BJILang.get("packageDelivery.flashEnd"), 3, false)
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
end

local function getRadiusMultiplier()
    return math.clamp(table.length(M.participants), 1, 4)
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return BJIScenario.isFreeroam() and
        ctxt.isOwner and
        not BJIVeh.isUnicycle(ctxt.veh:getID()) and
        BJIContext.Scenario.Data.Deliveries and
        #BJIContext.Scenario.Data.Deliveries > 1
end

-- load hook
local function onLoad(ctxt)
    BJIVehSelector.tryClose()
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RECOVER_VEHICLE)
    BJIQuickTravel.toggle(false)
    BJIAI.toggle(false)
    BJIGPS.reset()
    BJIRaceWaypoint.resetAll()
end

-- player vehicle spawn hook
local function onVehicleSpawned(gameVehID)
    if BJIVeh.isVehicleOwn(gameVehID) then
        BJITx.scenario.DeliveryMultiLeave()
    end
end

-- player vehicle reset hook
local function onVehicleResetted(gameVehID)
    if gameVehID ~= BJIContext.User.currentVehicle then
        return
    elseif M.nextResetGarage then
        if M.tanksSaved then
            for tankName, tank in pairs(M.tanksSaved) do
                local fuel = tank.currentEnergy
                BJIVeh.setFuel(tankName, fuel)
            end
            M.tanksSaved = nil
        end
        M.nextResetGarage = false
        return
    end

    BJITx.scenario.DeliveryMultiResetted()
end

-- player vehicle switch hook
local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if M.participants[BJIContext.User.playerID] then
        if newGameVehID ~= M.participants[BJIContext.User.playerID].gameVehID then
            BJIVeh.focusVehicle(M.participants[BJIContext.User.playerID].gameVehID)
        end
    end
end

-- player vehicle destroy hook
local function onVehicleDestroyed(gameVehID)
    if BJIVeh.isVehicleOwn(gameVehID) then
        BJITx.scenario.DeliveryMultiLeave()
    end
end

-- can player refuel at a station
local function canRefuelAtStation()
    return true
end

-- can player repair vehicle at a garage
local function canRepairAtGarage()
    return true
end

-- player garage repair hook
local function onGarageRepair()
    M.nextResetGarage = true
    local veh
    for _, v in pairs(BJIContext.User.vehicles) do
        if v.gameVehID == BJIContext.User.currentVehicle then
            veh = v
            break
        end
    end
    if veh then
        M.tanksSaved = table.clone(veh.tanks)
    end
end

local function canVehUpdate()
    return false
end

local function onTargetReached(ctxt)
    if not ctxt.isOwner then
        BJITx.scenario.DeliveryMultiLeave()
        return
    end

    M.baseDistance = nil
    M.distance = nil
    BJIRaceWaypoint.resetAll()
    BJITx.scenario.DeliveryMultiReached()
end

-- each second tick hook
local function slowTick(ctxt)
    if not ctxt.isOwner or not M.participants[BJIContext.User.playerID] then
        BJITx.scenario.DeliveryMultiLeave()
        return
    end

    if M.participants[BJIContext.User.playerID].reached then
        BJIMessage.realtimeDisplay("deliverymulti", BJILang.get("deliveryTogether.waitingForOtherPlayers"))
    elseif not M.target then
        BJIMessage.realtimeDisplay("deliverymulti", BJILang.get("deliveryTogether.waitingForTarget"))
    else
        BJIMessage.stopRealtimeDisplay()
        M.distance = BJIGPS.getCurrentRouteLength() or 0
        if not M.baseDistance or M.distance > M.baseDistance then
            M.baseDistance = M.distance
        end

        if #BJIRaceWaypoint._targets == 0 then
            BJIRaceWaypoint.addWaypoint("BJIDeliveryMultiTarget", M.target.pos, M.target.radius * getRadiusMultiplier(),
                BJIRaceWaypoint.COLORS.BLUE)
        end

        local distance = ctxt.vehPosRot.pos:distance(M.target.pos)
        if distance < M.target.radius * getRadiusMultiplier() then
            if not M.checkTargetProcess then
                BJIMessage.flashCountdown("BJIDeliveryMultiTarget", ctxt.now + 3100, false,
                    BJILang.get("deliveryTogether.flashPackage"), nil,
                    onTargetReached)
                M.checkTargetProcess = true
            end
        else
            if M.checkTargetProcess then
                BJIMessage.cancelFlash("BJIDeliveryMultiTarget")
                M.checkTargetProcess = false
            end
            if #BJIGPS.targets == 0 then
                BJIGPS.prependWaypoint(BJIGPS.KEYS.DELIVERY_TARGET, M.target.pos,
                    M.target.radius * getRadiusMultiplier(), nil, nil, false)
            end
        end
    end
end

-- player list contextual actions getter
local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJIVote.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            label = BJILang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJIVote.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_ALL)
    BJIQuickTravel.toggle(true)
    BJIAI.toggle(true)
    BJIGPS.removeByKey(BJIGPS.KEYS.DELIVERY_TARGET)
    BJIMessage.stopRealtimeDisplay()
    BJIRaceWaypoint.resetAll()
end

local function onTargetChange()
    BJIGPS.appendWaypoint(BJIGPS.KEYS.DELIVERY_TARGET, M.target.pos,
        M.target.radius * getRadiusMultiplier(), nil, nil, false)
    BJIMessage.flash("BJIDeliveryMultiNextTarget", BJILang.get("packageDelivery.flashStart"), 3, false)
    BJIRaceWaypoint.resetAll()
    BJIRaceWaypoint.addWaypoint("BJIDeliveryMultiTarget", M.target.pos, M.target.radius * getRadiusMultiplier(),
        BJIRaceWaypoint.COLORS.BLUE)
end

local function rxData(data)
    local wasParticipant = not not M.participants[BJIContext.User.playerID]
    local previousRadius = getRadiusMultiplier()
    M.participants = data.participants
    local previousTarget = M.target and TryParsePosRot(table.clone(M.target)) or nil
    M.target = TryParsePosRot(data.target)

    updateUI()

    if not wasParticipant and M.participants[BJIContext.User.playerID] and M.target then
        BJIScenario.switchScenario(BJIScenario.TYPES.DELIVERY_MULTI)
    elseif wasParticipant and (not M.participants[BJIContext.User.playerID] or not M.target) then
        stop()
    end

    if M.participants[BJIContext.User.playerID] and M.target then
        if not previousTarget or previousTarget.pos:distance(M.target.pos) > 0 then
            onTargetChange()
        end
    end

    if previousRadius ~= getRadiusMultiplier() then
        if BJIGPS.getByKey(BJIGPS.KEYS.DELIVERY_TARGET) then
            BJIGPS.removeByKey(BJIGPS.KEYS.DELIVERY_TARGET)
            BJIGPS.appendWaypoint(BJIGPS.KEYS.DELIVERY_TARGET, M.target.pos,
                M.target.radius * getRadiusMultiplier(), nil, nil, false)
        end
        if #BJIRaceWaypoint._targets > 0 then
            BJIRaceWaypoint.resetAll()
            BJIRaceWaypoint.addWaypoint("BJIDeliveryMultiTarget", M.target.pos, M.target.radius * getRadiusMultiplier(),
                BJIRaceWaypoint.COLORS.BLUE)
        end
    end
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.onVehicleSpawned = onVehicleSpawned
M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleDestroyed = onVehicleDestroyed
M.canRefuelAtStation = canRefuelAtStation
M.canRepairAtGarage = canRepairAtGarage
M.onGarageRepair = onGarageRepair

M.canSelectVehicle = canVehUpdate
M.canSpawnNewVehicle = canVehUpdate
M.canReplaceVehicle = canVehUpdate
M.canDeleteVehicle = canVehUpdate
M.canDeleteOtherVehicles = canVehUpdate
M.canEditVehicle = canVehUpdate

M.getPlayerListActions = getPlayerListActions

M.slowTick = slowTick

M.onUnload = onUnload

M.rxData = rxData

return M
