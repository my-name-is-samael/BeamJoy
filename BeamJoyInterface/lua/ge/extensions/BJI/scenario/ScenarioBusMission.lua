---@class BJIScenarioBusMission : BJIScenario
local S = {
    _name = "BusMission",
    _key = "BUS_MISSION",
    _isSolo = true,

    BASE_MODEL = "citybus",
    config = nil,
    line = {
        id = nil,
        name = nil,
        loopable = false,
        stops = {},
        totalDistance = 0,
    },
    nextStop = 2,
    progression = 0,

    checkTargetProcess = false, -- process to check player reached target and stayed in its radius

    ---@type table?
    cornerMarkers = nil,
}
--- gc prevention
local actions, loop, stopLabel

local function reset()
    S.config             = nil
    S.line               = {
        id = nil,
        name = nil,
        loopable = false,
        stops = {},
        totalDistance = 0,
    }
    S.nextStop           = 2
    S.progression        = 0

    S.checkTargetProcess = false
end
reset()

local function canChangeTo(ctxt)
    return BJI.Managers.Scenario.isFreeroam() and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.BUS_LINES) and
        BJI.Managers.Context.Scenario.Data.BusLines and
        #BJI.Managers.Context.Scenario.Data.BusLines > 0 and
        S.config
end

local function initCornerMarkers()
    S.cornerMarkers = BJI.Managers.WorldObject.createGroup("BJIBusMarkers")
    if not S.cornerMarkers then
        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
        error("Unable to create BJI bus markers tree")
    end
    for _, name in ipairs({ "BJIBusMarker1", "BJIBusMarker2", "BJIBusMarker3", "BJIBusMarker4" }) do
        local marker = scenetree.findObject(name)
        if not marker then
            marker = BJI.Managers.WorldObject.createCornerMarker(name)
            S.cornerMarkers:addObject(marker.obj)
        end
    end
end

---@param ctxt TickContext
---@param stop BJIPositionRotation
local function updateCornerMarkers(ctxt, stop)
    if not ctxt.veh or not stop then return end

    local wpRadius = 2
    local tpos = stop.pos + vec3(0, 0, 3)
    local pos = vec3()
    local tr = stop.rot * quatFromEuler(0, 0, math.rad(90))
    local r
    local yVec, xVec = tr * vec3(0, 1, 0), tr * vec3(1, 0, 0)
    local d = ctxt.veh.veh:getInitialLength() / 2 + wpRadius / 2
    local w = ctxt.veh.veh:getInitialWidth() / 2 + wpRadius / 2
    BJI.Managers.WorldObject.getGroupChildren(S.cornerMarkers)
        :forEach(function(marker, i)
            if i == 1 then
                pos = (tpos - xVec * d + yVec * w)
                r = tr * quatFromEuler(0, 0, math.rad(90))
            elseif i == 2 then
                pos = (tpos + xVec * d + yVec * w)
                r = tr * quatFromEuler(0, 0, math.rad(180))
            elseif i == 3 then
                pos = (tpos + xVec * d - yVec * w)
                r = tr * quatFromEuler(0, 0, math.rad(270))
            elseif i == 4 then
                pos = (tpos - xVec * d - yVec * w)
                r = tr
            end
            pos.z = be:getSurfaceHeightBelow(pos) + .2
            marker:setPosRot(pos.x, pos.y, pos.z, r.x, r.y, r.z, r.w)
            marker:setField('instanceColor', 0, "1 0 0 1")
        end)
end

local function updateTarget(ctxt)
    local next = S.line.stops[S.nextStop]

    updateCornerMarkers(ctxt, next)
    BJI.Managers.BusUI.nextStop(S.nextStop)
    BJI.Managers.BusUI.requestStop(true)

    BJI.Managers.GPS.reset()
    BJI.Managers.GPS.prependWaypoint({
        key = BJI.Managers.GPS.KEYS.BUS_STOP,
        pos = next.pos,
        radius = next.radius,
        clearable = false,
    })
end

local function onLoad(ctxt)
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.GPS.reset()
    BJI.Managers.RaceWaypoint.resetAll()

    BJI.Tx.scenario.BusMissionStart()
end

local function clearScenetreeObjects()
    if S.cornerMarkers then
        BJI.Managers.WorldObject.unregister(S.cornerMarkers)
        S.cornerMarkers = nil
    end
end

local function onUnload(ctxt)
    clearScenetreeObjects()
    reset()
    BJI.Managers.GPS.reset()
    BJI.Managers.BusUI.reset()
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    return Table():addAll(BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH, true)
        :addAll(BJI.Managers.Restrictions.OTHER.FUN_STUFF, true)
end

---@param ctxt TickContext
---@param lineData table
---@param model string
---@param config table
local function start(ctxt, lineData, model, config)
    reset()
    table.assign(S.line, lineData)
    model = model or S.BASE_MODEL
    S.config = config
    S.nextStop = 2

    local points = {}
    for _, stop in ipairs(S.line.stops) do
        table.insert(points, vec3(stop.pos))
    end
    S.line.totalDistance = BJI.Managers.GPS.getRouteLength(points)

    BJI.Managers.UI.applyLoading(true, function()
        local startPosRot = S.line.stops[1]
        BJI.Managers.Async.removeTask("BJIBusMissionInitVehicle")
        BJI.Managers.Veh.replaceOrSpawnVehicle(model, S.config, startPosRot)
        BJI.Managers.Veh.waitForVehicleSpawn(function()
            BJI.Managers.Async.task(function(ctxt2)
                return ctxt2.isOwner and ctxt2.veh.jbeam == model and
                    ctxt2.veh.veh.partConfig:find(string.var("/{1}.", { S.config })) ~= nil
            end, function(ctxt2)
                initCornerMarkers()
                updateTarget(ctxt2)
                BJI.Managers.Message.flash("BJIBusMissionTarget", BJI.Managers.Lang.get("buslines.play.flashDriveNext"),
                    3, false)
                BJI.Managers.Async.delayTask(function()
                    BJI.Managers.BusUI.initBusMission(S.line.id, S.line.stops, S.nextStop)
                    BJI.Managers.BusUI.requestStop(true)
                end, 300, "BJIBusMissionInitBusUI")

                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.BUS_MISSION, ctxt)
                BJI.Managers.UI.applyLoading(false)
            end, "BJIBusMissionInitVehicle")
        end)
    end)
end

local function onMissionFailed()
    BJI.Tx.scenario.BusMissionStop()
    BJI.Managers.Message.flash("BJIBusMissionFailed", BJI.Managers.Lang.get("buslines.play.flashStopped"), 3, false)
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
end

local function onStopBusMission()
    onMissionFailed()
end

---@param ctxt TickContext
local function drawUI(ctxt)
    if IconButton("stopBusMission", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onStopBusMission()
    end
    TooltipText(BJI.Managers.Lang.get("menu.scenario.busMission.stop"))
    if S.line.loopable then
        SameLine()
        loop = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_BUS_MISSION_LOOP)
        if IconButton("toggleBusLoop", BJI.Utils.Icon.ICONS.all_inclusive, { btnStyle = loop and
                BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.INFO }) then
            BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_BUS_MISSION_LOOP, not loop)
        end
        TooltipText(BJI.Managers.Lang.get("common.buttons.loop"))
    end
    SameLine()
    Text(BJI.Managers.Lang.get("buslines.play.title"))

    stopLabel = BJI.Managers.Lang.get("buslines.play.stopCount")
        :var({ current = S.nextStop - 1, total = #S.line.stops })

    Text(BJI.Managers.Lang.get("buslines.play.line")
        :var({ name = S.line.name }))
    TooltipText(stopLabel)

    ProgressBar(S.progression, { color = BJI.Utils.Style.BTN_PRESETS.INFO[1] })
    TooltipText(stopLabel)
end

---@param ctxt TickContext
local function onTargetReached(ctxt)
    S.checkTargetProcess = false
    local flashMsg = BJI.Managers.Lang.get("buslines.play.flashDriveNext")
    if S.nextStop == #S.line.stops then
        BJI.Tx.scenario.BusMissionReward(S.line.id)
        if S.line.loopable and BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_BUS_MISSION_LOOP) then
            -- trigger next loop
            S.nextStop = 1
            updateTarget(ctxt)
        else
            -- end of mission
            BJI.Tx.scenario.BusMissionStop()
            flashMsg = BJI.Managers.Lang.get("buslines.play.flashFinish")
            BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
        end
    else
        S.nextStop = S.nextStop + 1
        updateTarget(ctxt)
    end
    BJI.Managers.Message.flash("BJIBusMissionTarget", flashMsg, 3, false)
end

---@param reached boolean
local function updateCornerMarkersColor(reached)
    BJI.Managers.WorldObject.getGroupChildren(S.cornerMarkers)
        :forEach(function(marker)
            if reached then
                marker:setField('instanceColor', 0, '0 1 0 1')
            else
                marker:setField('instanceColor', 0, "1 0 0 1")
            end
        end)
end

---@param ctxt TickContext
local function slowTick(ctxt)
    if not ctxt.isOwner then
        S.onStopBusMission()
        return
    end

    local points = { vec3(ctxt.veh.position) }
    for i = S.nextStop, #S.line.stops do
        table.insert(points, vec3(S.line.stops[i].pos))
    end
    local remainingDistance = BJI.Managers.GPS.getRouteLength(points)
    S.progression = 1 - (remainingDistance / S.line.totalDistance)

    local target = S.line.stops[S.nextStop]
    local distance = math.horizontalDistance(ctxt.veh.position, target.pos)

    if distance < target.radius then
        -- core_vehicleBridge.registerValueChangeNotification(veh, "kneel")
        -- core_vehicleBridge.registerValueChangeNotification(veh, "dooropen")
        -- core_vehicleBridge.getCachedVehicleData(id, 'kneel') == 1
        -- core_vehicleBridge.getCachedVehicleData(id, 'dooropen') == 1
        if not S.checkTargetProcess then
            S.checkTargetProcess = true
            BJI.Managers.Message.flashCountdown("BJIBusMissionTarget", ctxt.now + 5100, false, "", nil,
                onTargetReached)
            updateCornerMarkersColor(true)
        end
    else
        if S.checkTargetProcess then
            BJI.Managers.Message.cancelFlash("BJIBusMissionTarget")
            S.checkTargetProcess = false
            updateCornerMarkersColor(false)
        end
        if #BJI.Managers.GPS.targets == 0 then
            BJI.Managers.GPS.prependWaypoint({
                key = BJI.Managers.GPS.KEYS.BUS_STOP,
                pos = target.pos,
                radius = target.radius,
                clearable = false,
            })
        end
    end
end

---@param player BJIPlayer
---@param ctxt TickContext
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

S.start = start

S.drawUI = drawUI

S.onStopBusMission = onStopBusMission
S.onTargetReached = onTargetReached

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn

S.canSpawnAI = TrueFn

S.slowTick = slowTick

S.getPlayerListActions = getPlayerListActions

return S
