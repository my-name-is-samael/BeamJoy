---@class BJIScenarioPackageDelivery : BJIScenario
local S = {
    ---@type { pos: vec3, radius: number, distance?: number }?
    targetPosition = nil,
    baseDistance = nil,
    distance = nil,
    streak = 0,

    nextResetGarage = false,    -- exempt reset when repairing at a garage
    tanksSaved = nil,
    checkTargetProcess = false, -- process to check player reached target and stayed in its radius
}

local function reset()
    S.targetPosition = nil
    S.baseDistance = nil
    S.distance = nil
    S.streak = 0

    S.nextResetGarage = false
    S.tanksSaved = nil
    S.checkTargetProcess = false
end

local function canChangeTo(ctxt)
    return BJI.Managers.Scenario.isFreeroam() and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.DELIVERIES) and
        BJI.Managers.Context.Scenario.Data.Deliveries and
        #BJI.Managers.Context.Scenario.Data.Deliveries > 1 and
        ctxt.isOwner and
        not BJI.Managers.Veh.isUnicycle(ctxt.veh:getID())
end

local function initPositions(ctxt)
    if not ctxt.isOwner then
        return
    end

    local targets = {}
    for _, position in ipairs(BJI.Managers.Context.Scenario.Data.Deliveries) do
        -- local distance = BJIGPS.getRouteLength({ ctxt.vehPosRot.pos, position.pos }) -- costs a lot
        local distance = ctxt.vehPosRot.pos:distance(position.pos)
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
        local threhsholdPos = math.ceil(#targets * .66) + 1 -- 66% furthest
        while targets[threhsholdPos] do
            table.remove(targets, threhsholdPos)
        end
    end
    S.targetPosition = table.random(targets)
    S.targetPosition.distance = nil
end

local function initDelivery()
    BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.DELIVERY_TARGET, S.targetPosition.pos,
        S.targetPosition.radius, nil, nil, false)
    S.baseDistance = BJI.Managers.GPS.getCurrentRouteLength()
    BJI.Managers.RaceWaypoint.addWaypoint({
        name = "BJIVehicleDelivery",
        pos = S.targetPosition.pos,
        radius = S.targetPosition.radius,
        color = BJI.Managers.RaceWaypoint.COLORS.BLUE
    })
end

local function onLoad(ctxt)
    reset()
    BJI.Windows.VehSelector.tryClose()

    local init = false
    if ctxt.isOwner then
        initPositions(ctxt)

        if S.targetPosition then
            BJI.Managers.Restrictions.update({
                {
                    restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    state = BJI.Managers.Restrictions.STATE.RESTRICTED,
                }
            })
            BJI.Managers.GPS.reset()
            BJI.Managers.RaceWaypoint.resetAll()

            initDelivery()
            BJI.Tx.scenario.DeliveryPackageStart()
            BJI.Managers.Message.flash("BJIDeliveryPackageStart", BJI.Managers.Lang.get("packageDelivery.flashStart"), 3,
                false)
            init = true
        end
    end
    if not init then
        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM, ctxt)
    end
end

local function onUnload(ctxt)
    BJI.Managers.Restrictions.update({ {
        restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.GPS.reset()
    BJI.Managers.RaceWaypoint.resetAll()
end

local function onDeliveryEnded()
    BJI.Tx.scenario.DeliveryPackageFail()
    BJI.Managers.Message.flash("BJIDeliveryPackageFail", BJI.Managers.Lang.get("packageDelivery.flashEnd"), 3, false)
    reset()
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
end

local function onVehicleResetted(gameVehID)
    if gameVehID ~= BJI.Managers.Context.User.currentVehicle then
        return
    elseif S.nextResetGarage then
        if S.tanksSaved then
            for tankName, tank in pairs(S.tanksSaved) do
                local fuel = tank.currentEnergy
                BJI.Managers.Veh.setFuel(tankName, fuel)
            end
            S.tanksSaved = nil
        end
        S.nextResetGarage = false
        return
    end

    onDeliveryEnded()
end

local function onGarageRepair()
    S.nextResetGarage = true
    Table(BJI.Managers.Context.User.vehicles)
        :find(function(v)
            return v.gameVehID == BJI.Managers.Context.User.currentVehicle
        end, function(v)
            S.tanksSaved = table.clone(v.tanks)
        end)
end

local function onStopDelivery()
    onDeliveryEnded()
end

local function drawUI(ctxt, cache)
    if S.distance then
        LineBuilder()
            :text(string.var("{1}: {2}", {
                cache.labels.delivery.current,
                cache.labels.delivery.distanceLeft
                    :var({ distance = BJI.Utils.Common.PrettyDistance(S.distance) })
            }))
            :build()

        ProgressBar({
            floatPercent = 1 - math.max(S.distance / S.baseDistance, 0),
            width = 250,
        })
    end

    LineBuilder()
        :text(cache.labels.delivery.package.streak:var({ streak = S.streak }))
        :helpMarker(cache.labels.delivery.package.streakTooltip)
        :build()

    LineBuilder()
        :btnIcon({
            id = "stopPackageDelivery",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = S.onStopDelivery,
            big = true,
        })
        :build()
end

local function onTargetReached(ctxt)
    if not ctxt.isOwner then
        S.onStopDelivery()
        return
    end

    BJI.Tx.scenario.DeliveryPackageSuccess()
    initPositions(ctxt)
    if not S.targetPosition then
        S.onStopDelivery()
    end
    initDelivery()
end

local function rxStreak(streak)
    S.streak = streak
end

local function slowTick(ctxt)
    if not ctxt.isOwner or not S.targetPosition then
        S.onStopDelivery()
        return
    end

    S.distance = BJI.Managers.GPS.getRouteLength({
        vec3(ctxt.vehPosRot.pos),
        vec3(S.targetPosition.pos),
    })
    if S.distance > S.baseDistance then
        S.baseDistance = S.distance
    end

    local distance = ctxt.vehPosRot.pos:distance(S.targetPosition.pos)
    if distance < S.targetPosition.radius then
        if not S.checkTargetProcess then
            local streak = S.streak + 1
            local msg
            if streak == 1 then
                msg = BJI.Managers.Lang.get("packageDelivery.flashFirstPackage")
            else
                msg = BJI.Managers.Lang.get("packageDelivery.flashPackageStreak"):var({ streak = streak })
            end
            BJI.Managers.Message.flashCountdown("BJIDeliveryTarget", ctxt.now + 3100, false, msg, nil,
                onTargetReached)
            S.checkTargetProcess = true
        end
    else
        if S.checkTargetProcess then
            BJI.Managers.Message.cancelFlash("BJIDeliveryTarget")
            S.checkTargetProcess = false
        end
        if #BJI.Managers.GPS.targets == 0 then
            BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.DELIVERY_TARGET, S.targetPosition.pos,
                S.targetPosition.radius, nil, nil, false)
        end
    end
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            label = BJI.Managers.Lang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJI.Managers.Votes.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.drawUI = drawUI

S.onVehicleResetted = onVehicleResetted
S.onGarageRepair = onGarageRepair
S.onStopDelivery = onStopDelivery

S.canRefuelAtStation = TrueFn
S.canRepairAtGarage = TrueFn
S.doShowNametagsSpecs = TrueFn

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.canSpawnAI = TrueFn

S.rxStreak = rxStreak

S.slowTick = slowTick

S.getPlayerListActions = getPlayerListActions


return S
