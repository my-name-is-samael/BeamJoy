---@class BJIScenarioDeliveryMulti : BJIScenario
local S = {
    -- server data
    participants = {},
    ---@type {pos: vec3, rot: vec3, radius: number}?
    target = nil,

    baseDistance = nil,
    distance = nil,
    nextResetGarage = false,    -- exempt reset when repairing at a garage
    tanksSaved = nil,
    checkTargetProcess = false, -- process to check player reached target and stayed in its radius
}

local function stop()
    -- server data
    S.participants = {}
    S.target = nil

    S.baseDistance = nil
    S.distance = nil
    S.tanksSaved = nil
    S.nextResetGarage = false

    BJI.Managers.Message.flash("BJIDeliveryMultiStop", BJI.Managers.Lang.get("packageDelivery.flashEnd"), 3, false)
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
end

local function getRadiusMultiplier()
    return math.clamp(table.length(S.participants), 1, 4)
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return BJI.Managers.Scenario.isFreeroam() and
        ctxt.isOwner and
        not BJI.Managers.Veh.isUnicycle(ctxt.veh:getID()) and
        BJI.Managers.Context.Scenario.Data.Deliveries and
        #BJI.Managers.Context.Scenario.Data.Deliveries > 1
end

-- load hook
local function onLoad(ctxt)
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.Restrictions.update({
        {
            restrictions = Table({
                BJI.Managers.Restrictions.RESET.TELEPORT,
                BJI.Managers.Restrictions.RESET.HEAVY_RELOAD,
                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            }):flat(),
            state = BJI.Managers.Restrictions.STATE.RESTRICTED,
        },
    })
    BJI.Managers.GPS.reset()
    BJI.Managers.RaceWaypoint.resetAll()
end

-- player vehicle reset hook
local function onVehicleResetted(gameVehID)
    if gameVehID ~= S.participants[BJI.Managers.Context.User.playerID].gameVehID or
        not BJI.Managers.Veh.isVehicleOwn(gameVehID) then
        return -- is not player delivery vehicle
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

    BJI.Tx.scenario.DeliveryMultiResetted()
end

-- player vehicle destroy hook
local function onVehicleDestroyed(gameVehID)
    if BJI.Managers.Veh.isVehicleOwn(gameVehID) then
        BJI.Tx.scenario.DeliveryMultiLeave()
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
    S.nextResetGarage = true
    Table(BJI.Managers.Context.User.vehicles)
        :find(function(v)
            return v.gameVehID == BJI.Managers.Context.User.currentVehicle
        end, function(v)
            S.tanksSaved = table.clone(v.tanks)
        end)
end

local function onTargetReached(ctxt)
    if not ctxt.isOwner then
        BJI.Tx.scenario.DeliveryMultiLeave()
        return
    end

    S.baseDistance = nil
    S.distance = nil
    BJI.Managers.RaceWaypoint.resetAll()
    BJI.Tx.scenario.DeliveryMultiReached()
end

-- each second tick hook
local function slowTick(ctxt)
    if not ctxt.isOwner or not S.participants[BJI.Managers.Context.User.playerID] then
        BJI.Tx.scenario.DeliveryMultiLeave()
        return
    end

    if S.participants[BJI.Managers.Context.User.playerID].reached then
        BJI.Managers.Message.realtimeDisplay("deliverymulti",
            BJI.Managers.Lang.get("deliveryTogether.waitingForOtherPlayers"))
    elseif not S.target then
        BJI.Managers.Message.realtimeDisplay("deliverymulti", BJI.Managers.Lang.get("deliveryTogether.waitingForTarget"))
    else
        BJI.Managers.Message.stopRealtimeDisplay()
        S.distance = BJI.Managers.GPS.getCurrentRouteLength() or 0
        if not S.baseDistance or S.distance > S.baseDistance then
            S.baseDistance = S.distance
        end

        if #BJI.Managers.RaceWaypoint._targets == 0 then
            BJI.Managers.RaceWaypoint.addWaypoint({
                name = "BJIDeliveryMultiTarget",
                pos = S.target.pos,
                radius = S.target.radius * getRadiusMultiplier(),
                color = BJI.Managers.RaceWaypoint.COLORS.BLUE
            })
        end

        local distance = ctxt.vehPosRot.pos:distance(S.target.pos)
        if distance < S.target.radius * getRadiusMultiplier() then
            if not S.checkTargetProcess then
                BJI.Managers.Message.flashCountdown("BJIDeliveryMultiTarget", ctxt.now + 3100, false,
                    BJI.Managers.Lang.get("deliveryTogether.flashPackage"), nil,
                    onTargetReached)
                S.checkTargetProcess = true
            end
        else
            if S.checkTargetProcess then
                BJI.Managers.Message.cancelFlash("BJIDeliveryMultiTarget")
                S.checkTargetProcess = false
            end
            if #BJI.Managers.GPS.targets == 0 then
                BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.DELIVERY_TARGET, S.target.pos,
                    S.target.radius * getRadiusMultiplier(), nil, nil, false)
            end
        end
    end
end

-- player list contextual actions getter
local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            icon = ICONS.event_busy,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = BJI.Managers.Lang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJI.Managers.Votes.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.TELEPORT,
            BJI.Managers.Restrictions.RESET.HEAVY_RELOAD,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.DELIVERY_TARGET)
    BJI.Managers.Message.stopRealtimeDisplay()
    BJI.Managers.RaceWaypoint.resetAll()
end

local function onTargetChange()
    BJI.Managers.GPS.appendWaypoint(BJI.Managers.GPS.KEYS.DELIVERY_TARGET, S.target.pos,
        S.target.radius * getRadiusMultiplier(), nil, nil, false)
    BJI.Managers.Message.flash("BJIDeliveryMultiNextTarget", BJI.Managers.Lang.get("packageDelivery.flashStart"), 3,
        false)
    BJI.Managers.RaceWaypoint.resetAll()
    BJI.Managers.RaceWaypoint.addWaypoint({
        name = "BJIDeliveryMultiTarget",
        pos = S.target.pos,
        radius = S.target.radius * getRadiusMultiplier(),
        color = BJI.Managers.RaceWaypoint.COLORS.BLUE
    })
end

local function rxData(data)
    local wasParticipant = not not S.participants[BJI.Managers.Context.User.playerID]
    local previousRadius = getRadiusMultiplier()
    S.participants = data.participants
    local previousTarget = S.target and math.tryParsePosRot(S.target) or nil
    S.target = math.tryParsePosRot(data.target)

    if not wasParticipant and S.participants[BJI.Managers.Context.User.playerID] and S.target then
        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.DELIVERY_MULTI)
    elseif wasParticipant and (not S.participants[BJI.Managers.Context.User.playerID] or not S.target) then
        stop()
    end

    if S.participants[BJI.Managers.Context.User.playerID] and S.target then
        if not previousTarget or previousTarget.pos:distance(S.target.pos) > 0 then
            onTargetChange()
        end
    end

    if previousRadius ~= getRadiusMultiplier() then
        if BJI.Managers.GPS.getByKey(BJI.Managers.GPS.KEYS.DELIVERY_TARGET) then
            BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.DELIVERY_TARGET)
            BJI.Managers.GPS.appendWaypoint(BJI.Managers.GPS.KEYS.DELIVERY_TARGET, S.target.pos,
                S.target.radius * getRadiusMultiplier(), nil, nil, false)
        end
        if #BJI.Managers.RaceWaypoint._targets > 0 then
            BJI.Managers.RaceWaypoint.resetAll()
            BJI.Managers.RaceWaypoint.addWaypoint({
                name = "BJIDeliveryMultiTarget",
                pos = S.target.pos,
                radius = S.target.radius * getRadiusMultiplier(),
                color = BJI.Managers.RaceWaypoint.COLORS.BLUE
            })
        end
    end
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad

S.onVehicleResetted = onVehicleResetted
S.onVehicleDestroyed = onVehicleDestroyed
S.canRefuelAtStation = canRefuelAtStation
S.canRepairAtGarage = canRepairAtGarage
S.onGarageRepair = onGarageRepair

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.canSpawnAI = TrueFn

S.getPlayerListActions = getPlayerListActions

S.slowTick = slowTick

S.onUnload = onUnload

S.rxData = rxData

return S
