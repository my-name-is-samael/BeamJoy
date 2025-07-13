---@class BJIScenarioDeliveryMulti : BJIScenario
local S = {
    _name = "DeliveryTogether",
    _key = "DELIVERY_MULTI",
    _isSolo = false,

    -- server data
    participants = {},
    ---@type {pos: vec3, rot: vec3, radius: number}?
    target = nil,

    baseDistance = nil,
    ---@type number?
    distance = nil,
    nextResetGarage = false,    -- exempt reset when repairing at a garage
    tanksSaved = nil,
    checkTargetProcess = false, -- process to check player reached target and stayed in its radius
    ---@type integer?
    checkTargetTime = nil,

    disableBtns = false,
}
--- gc prevention
local actions, participant, remainingSec, remainingPlayers

local function stop()
    -- server data
    S.participants = {}
    S.target = nil

    S.baseDistance = nil
    S.distance = nil
    S.nextResetGarage = false
    S.tanksSaved = nil
    S.checkTargetProcess = false
    S.checkTargetTime = nil

    S.disableBtns = false

    BJI_Message.flash("BJIDeliveryMultiStop", BJI_Lang.get("packageDelivery.flashEnd"), 3, false)
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
end

local function getRadiusMultiplier()
    return math.clamp(table.length(S.participants), 1, 4)
end

-- can switch to scenario hook
---@param ctxt TickContext
local function canChangeTo(ctxt)
    return BJI_Scenario.isFreeroam() and
        ctxt.isOwner and
        not BJI_Veh.isUnicycle(ctxt.veh.gameVehicleID) and
        BJI_Scenario.Data.Deliveries and
        #BJI_Scenario.Data.Deliveries > 1
end

-- load hook
---@param ctxt TickContext
local function onLoad(ctxt)
    BJI_Win_VehSelector.tryClose()
    BJI_GPS.reset()
    BJI_RaceWaypoint.resetAll()
end

---@param ctxt TickContext
local function onUnload(ctxt)
    BJI_GPS.removeByKey(BJI_GPS.KEYS.DELIVERY_TARGET)
    BJI_Message.stopRealtimeDisplay()
    BJI_RaceWaypoint.resetAll()
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    return Table():addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
        :addAll(BJI_Restrictions.OTHER.FUN_STUFF, true)
end

-- player vehicle reset hook
local function onVehicleResetted(gameVehID)
    if gameVehID ~= S.participants[BJI_Context.User.playerID].gameVehID or
        not BJI_Veh.isVehicleOwn(gameVehID) then
        return -- is not player delivery vehicle
    elseif S.nextResetGarage then
        if S.tanksSaved then
            for tankName, tank in pairs(S.tanksSaved) do
                local fuel = tank.currentEnergy
                BJI_Veh.setFuel(tankName, fuel)
            end
            S.tanksSaved = nil
        end
        S.nextResetGarage = false
        return
    end

    BJI_Tx_scenario.DeliveryMultiResetted()
end

-- player vehicle destroy hook
local function onVehicleDestroyed(gameVehID)
    if BJI_Veh.isVehicleOwn(gameVehID) then
        BJI_Tx_scenario.DeliveryMultiLeave()
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
    Table(BJI_Context.User.vehicles)
        :find(function(v)
            return v.gameVehID == BJI_Context.User.currentVehicle
        end, function(v)
            S.tanksSaved = table.clone(v.tanks)
        end)
end

local function onTargetReached(ctxt)
    if not ctxt.isOwner then
        BJI_Tx_scenario.DeliveryMultiLeave()
        return
    end

    S.baseDistance = nil
    S.distance = nil
    BJI_RaceWaypoint.resetAll()
    BJI_Tx_scenario.DeliveryMultiReached()
end

-- each second tick hook
---@param ctxt TickContext
local function slowTick(ctxt)
    if not ctxt.isOwner or not S.participants[BJI_Context.User.playerID] then
        BJI_Tx_scenario.DeliveryMultiLeave()
        return
    end

    if S.participants[BJI_Context.User.playerID].reached then
        BJI_Message.realtimeDisplay("deliverymulti",
            BJI_Lang.get("deliveryTogether.waitingForOtherPlayers"):var({
                amount = Table(S.participants):filter(function(p) return not p.reached end):length()
            }))
    elseif not S.target then
        BJI_Message.realtimeDisplay("deliverymulti", BJI_Lang.get("deliveryTogether.waitingForTarget"))
    else
        BJI_Message.stopRealtimeDisplay()
        S.distance = BJI_GPS.getCurrentRouteLength() or 0
        if not S.baseDistance or S.distance > S.baseDistance then
            S.baseDistance = S.distance
        end

        if #BJI_RaceWaypoint._targets == 0 then
            BJI_RaceWaypoint.addWaypoint({
                name = "BJIDeliveryMultiTarget",
                pos = S.target.pos,
                radius = S.target.radius * getRadiusMultiplier(),
                color = BJI_RaceWaypoint.COLORS.BLUE
            })
        end

        local distance = ctxt.veh.position:distance(S.target.pos)
        if distance < S.target.radius * getRadiusMultiplier() then
            if not S.checkTargetProcess then
                S.checkTargetTime = ctxt.now + 3100
                BJI_Message.flashCountdown("BJIDeliveryMultiTarget", S.checkTargetTime, false,
                    BJI_Lang.get("deliveryTogether.flashPackage"), nil,
                    onTargetReached)
                S.checkTargetProcess = true
            end
        else
            if S.checkTargetProcess then
                BJI_Message.cancelFlash("BJIDeliveryMultiTarget")
                S.checkTargetProcess = false
                S.checkTargetTime = nil
            end
            if #BJI_GPS.targets == 0 then
                BJI_GPS.prependWaypoint({
                    key = BJI_GPS.KEYS.DELIVERY_TARGET,
                    pos = S.target.pos,
                    radius = S.target.radius * getRadiusMultiplier(),
                    clearable = false
                })
            end
        end
    end
end

---@param vehData BJIMPVehicle
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if vehData.ownerID ~= BJI_Context.User.playerID and S.participants[vehData.ownerID] then
        return true, BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1), BJI.Utils.ShapeDrawer.Color(.66, 1, .66, .5)
    end
    return true
end

---@param player BJIPlayer
---@param ctxt TickContext
local function getPlayerListActions(player, ctxt)
    actions = {}

    if BJI_Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

---@param ctxt TickContext
local function drawUI(ctxt)
    participant = S.participants[ctxt.user.playerID]
    if not participant then
        return
    end

    if IconButton("deliveryMultiLeave", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = S.disableBtns }) then
        S.disableBtns = true
        BJI_Tx_scenario.DeliveryMultiLeave()
    end
    TooltipText(BJI_Lang.get("common.buttons.leave"))
    SameLine()
    Text(BJI_Lang.get("deliveryTogether.title"))
    if S.checkTargetTime then
        remainingSec = math.ceil((S.checkTargetTime - ctxt.now) / 1000)
        if remainingSec > 0 then
            SameLine()
            Text(string.var("({1})", { BJI_Lang.get("deliveryTogether.depositIn"):var({
                delay = remainingSec
            }) }), { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
        end
    end


    if participant.reached then
        remainingPlayers = Table(S.participants):filter(function(p) return not p.reached end):length()
        if remainingPlayers == 0 then
            Text(BJI_Lang.get("deliveryTogether.waitingForTarget"))
        else
            Text(string.var(BJI_Lang.get("deliveryTogether.waitingForOtherPlayers"),
                { amount = remainingPlayers }))
        end
    else
        Text(BJI_Lang.get("deliveryTogether.reachDestination"),
            { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
    end
    SameLine()
    if participant.nextTargetReward then
        Text(string.var("({1}: {2})", { BJI_Lang.get("deliveryTogether.streak"),
            participant.streak }))
    else
        Text(string.var("({1})", { BJI_Lang.get("deliveryTogether.resetted") }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end

    if not participant.reached and S.distance then
        ProgressBar(1 - math.max(S.distance / S.baseDistance, 0),
            { color = BJI.Utils.Style.BTN_PRESETS.INFO[1] })
        TooltipText(string.var("{1}: {2}", {
            BJI_Lang.get("deliveryTogether.distance"),
            BJI.Utils.UI.PrettyDistance(S.distance)
        }))
    end
end

local function onTargetChange()
    BJI_GPS.appendWaypoint({
        key = BJI_GPS.KEYS.DELIVERY_TARGET,
        pos = S.target.pos,
        radius = S.target.radius * getRadiusMultiplier(),
        clearable = false
    })
    BJI_Message.flash("BJIDeliveryMultiNextTarget", BJI_Lang.get("packageDelivery.flashStart"), 3,
        false)
    BJI_RaceWaypoint.resetAll()
    BJI_RaceWaypoint.addWaypoint({
        name = "BJIDeliveryMultiTarget",
        pos = S.target.pos,
        radius = S.target.radius * getRadiusMultiplier(),
        color = BJI_RaceWaypoint.COLORS.BLUE
    })
end

local function rxData(data)
    local wasParticipant = not not S.participants[BJI_Context.User.playerID]
    local previousRadius = getRadiusMultiplier()
    S.participants = data.participants
    local previousTarget = S.target and math.tryParsePosRot(S.target) or nil
    S.target = math.tryParsePosRot(data.target)

    if not wasParticipant and S.participants[BJI_Context.User.playerID] and S.target then
        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.DELIVERY_MULTI)
    elseif wasParticipant and (not S.participants[BJI_Context.User.playerID] or not S.target) then
        stop()
    end

    if S.participants[BJI_Context.User.playerID] and S.target then
        if not previousTarget or previousTarget.pos:distance(S.target.pos) > 0 then
            onTargetChange()
        end
    end

    if previousRadius ~= getRadiusMultiplier() then
        if BJI_GPS.getByKey(BJI_GPS.KEYS.DELIVERY_TARGET) then
            BJI_GPS.removeByKey(BJI_GPS.KEYS.DELIVERY_TARGET)
            BJI_GPS.appendWaypoint({
                key = BJI_GPS.KEYS.DELIVERY_TARGET,
                pos = S.target.pos,
                radius = S.target.radius * getRadiusMultiplier(),
                clearable = false
            })
        end
        if #BJI_RaceWaypoint._targets > 0 then
            BJI_RaceWaypoint.resetAll()
            BJI_RaceWaypoint.addWaypoint({
                name = "BJIDeliveryMultiTarget",
                pos = S.target.pos,
                radius = S.target.radius * getRadiusMultiplier(),
                color = BJI_RaceWaypoint.COLORS.BLUE
            })
        end
    end
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

S.onVehicleResetted = onVehicleResetted
S.onVehicleDestroyed = onVehicleDestroyed
S.canRefuelAtStation = canRefuelAtStation
S.canRepairAtGarage = canRepairAtGarage
S.onGarageRepair = onGarageRepair

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn

S.canRecoverVehicle = TrueFn
S.canSpawnAI = TrueFn

S.doShowNametag = doShowNametag
S.getPlayerListActions = getPlayerListActions
S.drawUI = drawUI

S.slowTick = slowTick

S.rxData = rxData

return S
