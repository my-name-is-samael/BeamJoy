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
            BJI.Managers.Lang.get("deliveryTogether.waitingForOtherPlayers"):var({
                amount = Table(S.participants):filter(function(p) return not p.reached end):length()
            }))
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
                S.checkTargetTime = ctxt.now + 3100
                BJI.Managers.Message.flashCountdown("BJIDeliveryMultiTarget", S.checkTargetTime, false,
                    BJI.Managers.Lang.get("deliveryTogether.flashPackage"), nil,
                    onTargetReached)
                S.checkTargetProcess = true
            end
        else
            if S.checkTargetProcess then
                BJI.Managers.Message.cancelFlash("BJIDeliveryMultiTarget")
                S.checkTargetProcess = false
                S.checkTargetTime = nil
            end
            if #BJI.Managers.GPS.targets == 0 then
                BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.DELIVERY_TARGET, S.target.pos,
                    S.target.radius * getRadiusMultiplier(), nil, nil, false)
            end
        end
    end
end

---@param vehData BJIMPVehicle
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if vehData.ownerID ~= BJI.Managers.Context.User.playerID and S.participants[vehData.ownerID] then
        return true, BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1), BJI.Utils.ShapeDrawer.Color(.66, 1, .66, .5)
    end
    return true
end

---@param player BJIPlayer
---@param ctxt TickContext
local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            icon = BJI.Utils.Icon.ICONS.event_busy,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = BJI.Managers.Lang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJI.Managers.Votes.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

---@param ctxt TickContext
local function drawUI(ctxt)
    local participant = S.participants[ctxt.user.playerID]
    if not participant then
        return
    end

    local line = LineBuilder():btnIcon({
        id = "deliveryMultiLeave",
        icon = BJI.Utils.Icon.ICONS.exit_to_app,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        disabled = S.disableBtns,
        tooltip = BJI.Managers.Lang.get("common.buttons.leave"),
        onClick = function()
            S.disableBtns = true
            BJI.Tx.scenario.DeliveryMultiLeave()
        end,
    }):text(BJI.Managers.Lang.get("deliveryTogether.title"))
    if S.checkTargetTime then
        local remainingSec = math.ceil((S.checkTargetTime - ctxt.now) / 1000)
        if remainingSec > 0 then
            line:text(string.var("({1})", { BJI.Managers.Lang.get("deliveryTogether.depositIn"):var({
                delay = remainingSec
            }) }), BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
        end
    end
    line:build()

    line = LineBuilder()
    if participant.reached then
        local remainingPlayers = Table(S.participants):filter(function(p) return not p.reached end):length()
        if remainingPlayers == 0 then
            line:text(BJI.Managers.Lang.get("deliveryTogether.waitingForTarget"))
        else
            line:text(string.var(BJI.Managers.Lang.get("deliveryTogether.waitingForOtherPlayers"),
                { amount = remainingPlayers }))
        end
    else
        line:text(BJI.Managers.Lang.get("deliveryTogether.reachDestination"),
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
    end
    if participant.nextTargetReward then
        line:text(string.var("({1}: {2})", { BJI.Managers.Lang.get("deliveryTogether.streak"),
            participant.streak }))
    else
        line:text(string.var("({1})", { BJI.Managers.Lang.get("deliveryTogether.resetted") }),
            BJI.Utils.Style.TEXT_COLORS.ERROR)
    end
    line:build()

    if not participant.reached and S.distance then
        ProgressBar({
            floatPercent = 1 - math.max(S.distance / S.baseDistance, 0),
            style = BJI.Utils.Style.BTN_PRESETS.INFO[1],
            tooltip = string.var("{1}: {2}", {
                BJI.Managers.Lang.get("deliveryTogether.distance"),
                BJI.Utils.UI.PrettyDistance(S.distance)
            }),
        })
    end
end

---@param ctxt TickContext
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
S.canPaintVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.canSpawnAI = TrueFn

S.doShowNametag = doShowNametag
S.getPlayerListActions = getPlayerListActions
S.drawUI = drawUI

S.slowTick = slowTick

S.onUnload = onUnload

S.rxData = rxData

return S
