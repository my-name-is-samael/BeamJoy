local M = {
    targetPosition = nil,
    baseDistance = nil,
    distance = nil,
    streak = 0,

    nextResetGarage = false,    -- exempt reset when repairing at a garage
    tanksSaved = nil,
    checkTargetProcess = false, -- process to check player reached target and stayed in its radius
}

local function reset()
    M.targetPosition = nil
    M.baseDistance = nil
    M.distance = nil
    M.streak = 0

    M.nextResetGarage = false
    M.tanksSaved = nil
    M.checkTargetProcess = false
end

local function canChangeTo(ctxt)
    return BJIScenario.isFreeroam() and
        BJICache.isFirstLoaded(BJICache.CACHES.DELIVERIES) and
        BJIContext.Scenario.Data.Deliveries and
        #BJIContext.Scenario.Data.Deliveries > 1 and
        ctxt.isOwner and
        not BJIVeh.isUnicycle(ctxt.veh:getID())
end

local function initPositions(ctxt)
    if not ctxt.isOwner then
        return
    end

    local targets = {}
    for _, position in ipairs(BJIContext.Scenario.Data.Deliveries) do
        -- local distance = BJIGPS.getRouteLength({ ctxt.vehPosRot.pos, position.pos }) -- costs a lot
        local distance = GetHorizontalDistance(ctxt.vehPosRot.pos, position.pos)
        if distance > 0 then
            table.insert(targets, {
                pos = position.pos,
                radius = position.radius,
                distance = distance,
            })
        end
    end
    table.sort(targets, function(a, b)
        return a.distance > b.distance
    end)
    if #targets > 1 then
        local threhsholdPos = math.ceil(#targets / 2) + 1
        while targets[threhsholdPos] do
            table.remove(targets, threhsholdPos)
        end
    end
    M.targetPosition = trandom(targets)
    M.targetPosition.distance = nil
end

local function initDelivery()
    BJIRestrictions.apply(BJIRestrictions.TYPES.Delivery, true)
    BJIQuickTravel.toggle(false)
    BJINametags.tryUpdate()
    BJIGPS.reset()
    BJIRaceWaypoint.resetAll()

    BJIGPS.reset()
    BJIGPS.prependWaypoint(BJIGPS.KEYS.DELIVERY_TARGET, M.targetPosition.pos,
        M.targetPosition.radius, nil, nil, false)
    M.baseDistance = BJIGPS.getCurrentRouteLength()
    BJIRaceWaypoint.addWaypoint("BJIVehicleDelivery", M.targetPosition.pos, M.targetPosition.radius,
        BJIRaceWaypoint.COLORS.BLUE)
end

local function onLoad(ctxt)
    reset()
    BJIVehSelector.tryClose()

    local init = false
    if ctxt.isOwner then
        initPositions(ctxt)

        if M.targetPosition then
            initDelivery()

            BJITx.scenario.DeliveryPackageStart()
            BJIMessage.flash("BJIDeliveryPackageStart", BJILang.get("packageDelivery.flashStart"), 3, false)
            init = true
        end
    end
    if not init then
        BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
    end
end

local function onDeliveryEnded()
    BJITx.scenario.DeliveryPackageFail()
    BJIMessage.flash("BJIDeliveryPackageFail", BJILang.get("packageDelivery.flashEnd"), 3, false)
    reset()
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
end

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

    onDeliveryEnded()
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    onDeliveryEnded()
end

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
        M.tanksSaved = tdeepcopy(veh.tanks)
    end
end

local function onStopDelivery()
    onDeliveryEnded()
end

local function drawDeliveryUI(ctxt)
    if M.distance then
        LineBuilder()
            :text(svar("{1}: {2}", {
                BJILang.get("delivery.currentDelivery"),
                svar(BJILang.get("delivery.distanceLeft"),
                    { distance = PrettyDistance(M.distance) })
            }))
            :build()

        ProgressBar({
            floatPercent = 1 - math.max(M.distance / M.baseDistance, 0),
            width = 250,
        })
    end

    LineBuilder()
        :text(svar(BJILang.get("packageDelivery.currentStreak"), { streak = M.streak }))
        :helpMarker(BJILang.get("packageDelivery.streakTooltip"))
        :build()

    LineBuilder()
        :btnIcon({
            id = "stopPackageDelivery",
            icon = ICONS.exit_to_app,
            background = BTN_PRESETS.ERROR,
            onClick = M.onStopDelivery,
            big = true,
        })
        :build()
end

local function onTargetReached(ctxt)
    if not ctxt.isOwner then
        M.onStopDelivery()
        return
    end

    BJITx.scenario.DeliveryPackageSuccess()
    initPositions(ctxt)
    if not M.targetPosition then
        M.onStopDelivery()
    end
    initDelivery()
end

local function canRefuelAtStation()
    return true
end

local function canRepairAtGarage()
    return true
end

local function canVehUpdate()
    return false
end

local function doShowNametagsSpecs(vehData)
    return true
end

local function rxStreak(streak)
    M.streak = streak
end

local function slowTick(ctxt)
    if not ctxt.isOwner or not M.targetPosition then
        M.onStopDelivery()
        return
    end

    M.distance = BJIGPS.getRouteLength({
        vec3(ctxt.vehPosRot.pos),
        vec3(M.targetPosition.pos),
    })
    if M.distance > M.baseDistance then
        M.baseDistance = M.distance
    end

    local hDistance = GetHorizontalDistance(ctxt.vehPosRot.pos, M.targetPosition.pos)
    if hDistance < M.targetPosition.radius then
        if not M.checkTargetProcess then
            local streak = M.streak + 1
            local msg
            if streak == 1 then
                msg = BJILang.get("packageDelivery.flashFirstPackage")
            else
                msg = svar(BJILang.get("packageDelivery.flashPackageStreak"), { streak = streak })
            end
            BJIMessage.flashCountdown("BJIDeliveryTarget", ctxt.now + 3100, false, msg, nil,
                onTargetReached)
            M.checkTargetProcess = true
        end
    else
        if M.checkTargetProcess then
            BJIMessage.cancelFlash("BJIDeliveryTarget")
            M.checkTargetProcess = false
        end
        if #BJIGPS.targets == 0 then
            BJIGPS.prependWaypoint(BJIGPS.KEYS.DELIVERY_TARGET, M.targetPosition.pos,
                M.targetPosition.radius, nil, nil, false)
        end
    end
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJIVote.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = svar("voteKick{1}", { player.playerID }),
            label = BJILang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJIVote.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

local function onUnload(ctxt)
    BJIRestrictions.apply(BJIRestrictions.TYPES.Delivery, false)
    BJIQuickTravel.toggle(true)
    BJINametags.toggle(true)
    BJIGPS.reset()
    BJIRaceWaypoint.resetAll()
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.drawDeliveryUI = drawDeliveryUI

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.onGarageRepair = onGarageRepair
M.onStopDelivery = onStopDelivery

M.canRefuelAtStation = canRefuelAtStation
M.canRepairAtGarage = canRepairAtGarage

M.canSelectVehicle = canVehUpdate
M.canSpawnNewVehicle = canVehUpdate
M.canReplaceVehicle = canVehUpdate
M.canDeleteVehicle = canVehUpdate
M.canDeleteOtherVehicles = canVehUpdate
M.canEditVehicle = canVehUpdate
M.doShowNametagsSpecs = doShowNametagsSpecs

M.rxStreak = rxStreak

M.slowTick = slowTick

M.getPlayerListActions = getPlayerListActions

M.onUnload = onUnload

return M
