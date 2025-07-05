---@class BJIScenarioPackageDelivery : BJIScenario
local S = {
    _name = "PackageDelivery",
    _key = "PACKAGE_DELIVERY",
    _isSolo = false,

    ---@type { pos: vec3, radius: number, distance?: number }?
    targetPosition = nil,
    baseDistance = nil,
    distance = nil,
    streak = 0,

    nextResetGarage = false, -- exempt reset when repairing at a garage
    tanksSaved = nil,

    ---@type integer?
    checkTargetTime = nil, -- process to check player reached target and stayed in its radius
}
--- gc prevention
local actions, remainingSec

local function reset()
    S.targetPosition = nil
    S.baseDistance = nil
    S.distance = nil
    S.streak = 0

    S.nextResetGarage = false
    S.tanksSaved = nil
    S.checkTargetTime = nil
end

---@param ctxt TickContext
local function canChangeTo(ctxt)
    return BJI.Managers.Scenario.isFreeroam() and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.DELIVERIES) and
        BJI.Managers.Context.Scenario.Data.Deliveries and
        #BJI.Managers.Context.Scenario.Data.Deliveries > 1 and
        ctxt.isOwner and
        not BJI.Managers.Veh.isUnicycle(ctxt.veh.gameVehicleID)
end

---@param ctxt TickContext
local function initPositions(ctxt)
    if not ctxt.isOwner then
        return
    end

    local targets = {}
    for _, position in ipairs(BJI.Managers.Context.Scenario.Data.Deliveries) do
        -- local distance = BJIGPS.getRouteLength({ ctxt.veh.position, position.pos }) -- costs a lot
        local distance = ctxt.veh.position:distance(position.pos)
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
    BJI.Managers.GPS.prependWaypoint({
        key = BJI.Managers.GPS.KEYS.DELIVERY_TARGET,
        pos = S.targetPosition.pos,
        radius = S.targetPosition.radius,
        clearable = false
    })
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
    BJI.Managers.GPS.reset()
    BJI.Managers.RaceWaypoint.resetAll()
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    return Table():addAll(BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH, true)
        :addAll(BJI.Managers.Restrictions.OTHER.FUN_STUFF, true)
end

local function onDeliveryEnded()
    BJI.Tx.scenario.DeliveryPackageFail()
    BJI.Managers.Message.flash("BJIDeliveryPackageFail", BJI.Managers.Lang.get("packageDelivery.flashEnd"), 3, false)
    reset()
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
end

local function onVehicleResetted(gameVehID)
    if gameVehID ~= BJI.Managers.Context.User.currentVehicle or
        not BJI.Managers.Veh.isVehicleOwn(gameVehID) then
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

---@param ctxt TickContext
local function drawUI(ctxt)
    if IconButton("stopDelivery", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        S.onStopDelivery()
    end
    TooltipText(BJI.Managers.Lang.get("menu.scenario.packageDelivery.stop"))
    SameLine()
    Text(BJI.Managers.Lang.get("packageDelivery.title"))
    if S.checkTargetTime then
        remainingSec = math.ceil((S.checkTargetTime - ctxt.now) / 1000)
        if remainingSec > 0 then
            SameLine()
            Text(string.var("({1})", { BJI.Managers.Lang.get("packageDelivery.depositIn"):var({
                delay = remainingSec
            }) }), { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
        end
    end

    Text(BJI.Managers.Lang.get("packageDelivery.currentStreak")
        :var({ streak = S.streak }))
    TooltipText(BJI.Managers.Lang.get("packageDelivery.streakTooltip"))

    if S.distance then
        ProgressBar(1 - math.max(S.distance / S.baseDistance, 0),
            { color = BJI.Utils.Style.BTN_PRESETS.INFO[1] })
        TooltipText(string.var("{1}: {2}", {
            BJI.Managers.Lang.get("delivery.currentDelivery"),
            BJI.Managers.Lang.get("delivery.distanceLeft")
                :var({ distance = BJI.Utils.UI.PrettyDistance(S.distance) })
        }))
    end
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

---@param ctxt TickContext
local function slowTick(ctxt)
    if not ctxt.isOwner or not S.targetPosition then
        S.onStopDelivery()
        return
    end

    S.distance = BJI.Managers.GPS.getCurrentRouteLength()
    if S.distance > S.baseDistance then
        S.baseDistance = S.distance
    end

    local distance = ctxt.veh.position:distance(S.targetPosition.pos)
    if distance < S.targetPosition.radius then
        if not S.checkTargetTime then
            local streak = S.streak + 1
            local msg
            if streak == 1 then
                msg = BJI.Managers.Lang.get("packageDelivery.flashFirstPackage")
            else
                msg = BJI.Managers.Lang.get("packageDelivery.flashPackageStreak"):var({ streak = streak })
            end
            S.checkTargetTime = ctxt.now + 3100
            BJI.Managers.Message.flashCountdown("BJIDeliveryTarget", S.checkTargetTime, false, msg, nil,
                onTargetReached)
        end
    else
        if S.checkTargetTime then
            BJI.Managers.Message.cancelFlash("BJIDeliveryTarget")
            S.checkTargetTime = nil
        end
        if #BJI.Managers.GPS.targets == 0 then
            BJI.Managers.GPS.prependWaypoint({
                key = BJI.Managers.GPS.KEYS.DELIVERY_TARGET,
                pos = S.targetPosition.pos,
                radius = S.targetPosition.radius,
                clearable = false
            })
        end
    end
end

local function getPlayerListActions(player, ctxt)
    actions = {}

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

S.drawUI = drawUI

S.onVehicleResetted = onVehicleResetted
S.onGarageRepair = onGarageRepair
S.onStopDelivery = onStopDelivery

S.canRefuelAtStation = TrueFn
S.canRepairAtGarage = TrueFn
S.doShowNametagsSpecs = TrueFn

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.canSpawnAI = TrueFn

S.rxStreak = rxStreak

S.slowTick = slowTick

S.getPlayerListActions = getPlayerListActions


return S
