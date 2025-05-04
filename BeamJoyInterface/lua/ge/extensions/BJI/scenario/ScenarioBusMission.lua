local M = {
    STATES = {
        PREPARATION = 1,
        DRIVE = 2,
    },
    state = 1,
    model = "citybus",
    config = nil,
    line = {
        id = nil,
        name = nil,
        loopable = false,
        stops = {},
        totalDistance = nil,
    },
    nextStop = 1,
    progression = nil,

    init = false,
    nextResetExempt = true,     -- exempt reset fail for vehicle creation
    checkTargetProcess = false, -- process to check player reached target and stayed in its radius

    cornerMarkers = {},
}

local function reset()
    M.state              = M.STATES.PREPARATION
    M.model              = "citybus"
    M.config             = nil
    M.line               = {
        id = nil,
        name = nil,
        loopable = false,
        stops = {},
        totalDistance = nil,
    }
    M.nextStop           = 1
    M.progression        = nil

    M.nextResetExempt    = true
    M.init               = false
    M.checkTargetProcess = false
end

local function canChangeTo(ctxt)
    return BJIScenario.isFreeroam() and
        BJICache.isFirstLoaded(BJICache.CACHES.BUS_LINES) and
        BJIContext.Scenario.Data.BusLines and
        #BJIContext.Scenario.Data.BusLines > 0
end

local function initCornerMarkers()
    local function create(name)
        local marker = createObject('TSStatic')
        marker:setField('shapeName', 0, "art/shapes/interface/position_marker.dae")
        marker:setPosition(vec3(0, 0, 0))
        marker.scale = vec3(1, 1, 1)
        marker:setField('rotation', 0, '1 0 0 0')
        marker.useInstanceRenderData = true
        marker:setField('instanceColor', 0, '1 1 1 0')
        marker:setField('collisionType', 0, "Collision Mesh")
        marker:setField('decalType', 0, "Collision Mesh")
        marker:setField('playAmbient', 0, "1")
        marker:setField('allowPlayerStep', 0, "1")
        marker:setField('canSave', 0, "0")
        marker:setField('canSaveDynamicFields', 0, "1")
        marker:setField('renderNormals', 0, "0")
        marker:setField('meshCulling', 0, "0")
        marker:setField('originSort', 0, "0")
        marker:setField('forceDetail', 0, "-1")
        marker.canSave = false
        marker:registerObject(name)
        return marker;
    end

    if not scenetree.findObject("ScenarioObjectsGroup") then
        local ScenarioObjectsGroup = createObject('SimGroup')
        ScenarioObjectsGroup:registerObject('ScenarioObjectsGroup')
        ScenarioObjectsGroup.canSave = false
        scenetree.MissionGroup:addObject(ScenarioObjectsGroup.obj)
    end
    for _, name in ipairs({ "busMarkerTL", "busMarkerTR", "busMarkerBL", "busMarkerBR" }) do
        local marker = scenetree.findObject(name)
        if not marker then
            marker = create(name)
            scenetree.findObject("ScenarioObjectsGroup"):addObject(marker.obj)
            table.insert(M.cornerMarkers, marker)
        end
    end
end

local function onLoad(ctxt)
    reset()
    BJIVehSelector.tryClose()

    M.state = M.STATES.PREPARATION

    BJIRestrictions.apply(BJIRestrictions.TYPES.ResetBusMission, true)
    BJIQuickTravel.toggle(false)
    BJINametags.tryUpdate()
    BJIGPS.reset()
    BJIRaceWaypoint.resetAll()
end

local function updateCornerMarkers(ctxt, stop)
    if not ctxt.veh or not stop then return end

    local wpRadius = 2
    local tpos = stop.pos + vec3(0, 0, 3)
    local pos = vec3()
    local tr = stop.rot * quatFromEuler(0, 0, math.rad(90))
    local r
    local yVec, xVec = tr * vec3(0, 1, 0), tr * vec3(1, 0, 0)
    local d = ctxt.veh:getInitialLength() / 2 + wpRadius / 2
    local w = ctxt.veh:getInitialWidth() / 2 + wpRadius / 2
    for k, marker in ipairs(M.cornerMarkers) do
        if k == 1 then
            pos = (tpos - xVec * d + yVec * w)
            r = tr * quatFromEuler(0, 0, math.rad(90))
        elseif k == 2 then
            pos = (tpos + xVec * d + yVec * w)
            r = tr * quatFromEuler(0, 0, math.rad(180))
        elseif k == 3 then
            pos = (tpos + xVec * d - yVec * w)
            r = tr * quatFromEuler(0, 0, math.rad(270))
        elseif k == 4 then
            pos = (tpos - xVec * d - yVec * w)
            r = tr
        end
        pos.z = be:getSurfaceHeightBelow(pos) + .2
        marker:setPosRot(pos.x, pos.y, pos.z, r.x, r.y, r.z, r.w)
        marker:setField('instanceColor', 0, "1 0 0 1")
    end
end

local function updateTarget(ctxt)
    local next = M.line.stops[M.nextStop]

    updateCornerMarkers(ctxt, next)
    if M.init then
        BJIBusUI.nextStop(M.nextStop)
        BJIBusUI.requestStop(true)
    end

    BJIGPS.reset()
    BJIGPS.prependWaypoint(BJIGPS.KEYS.BUS_STOP, next.pos, next.radius, nil, nil, false)
end

local function initDrive(ctxt)
    M.nextStop = 2

    local points = {}
    for _, stop in ipairs(M.line.stops) do
        table.insert(points, vec3(stop.pos))
    end
    M.line.totalDistance = BJIGPS.getRouteLength(points)

    BJIUI.applyLoading(true, function()
        local startPosRot = M.line.stops[1]
        BJIVeh.replaceOrSpawnVehicle(M.model, M.config, startPosRot)
        BJIAsync.task(function(ctxt2)
            return ctxt2.isOwner and
                not BJIVeh.isConfigCustom(ctxt2.veh.partConfig) and
                ctxt2.veh.partConfig:find(string.var("/{1}.", { M.config }))
        end, function(ctxt2)
            M.state = M.STATES.DRIVE
            initCornerMarkers()
            updateTarget(ctxt2)
            BJIMessage.flash("BJIBusMissionTarget", BJILang.get("buslines.play.flashDriveNext"), 3, false)
            BJIAsync.delayTask(function()
                BJIBusUI.initBusMission(M.line.id, M.line.stops, M.nextStop)
                BJIBusUI.requestStop(true)
            end, 300, "BJIBusMissionInitBusUI")

            BJITx.scenario.BusMissionStart()
            M.init = true
            BJIUI.applyLoading(false)
        end, "BJIBusMissionInitVehicle")
    end)
end

local function onMissionFailed()
    BJITx.scenario.BusMissionStop()
    BJIMessage.flash("BJIBusMissionFailed", BJILang.get("buslines.play.flashStopped"), 3, false)
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
end

local function onVehicleResetted(gameVehID)
    if M.init and M.state == M.STATES.DRIVE then
        if gameVehID ~= BJIContext.User.currentVehicle then
            return
        end

        if M.nextResetExempt then
            -- used only for vehicle creation
            M.nextResetExempt = false
            return
        end

        onMissionFailed()
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if M.init and M.state == M.STATES.DRIVE then
        onMissionFailed()
    end
end

local function onStopBusMission()
    onMissionFailed()
end

local function drawUI(ctxt, cache)
    if M.state == M.STATES.DRIVE then
        LineBuilder()
            :text(cache.labels.busMission.line:var({ name = M.line.name }))
            :build()
        LineBuilder()
            :text(cache.labels.busMission.stopCount
                :var({ current = M.nextStop - 1, total = #M.line.stops }))
            :build()
        ProgressBar({
            floatPercent = M.progression,
            width = 250,
        })
        local line = LineBuilder()
        if M.line.loopable then
            local loop = BJILocalStorage.get(BJILocalStorage.VALUES.SCENARIO_BUS_MISSION_LOOP)
            line:btnIconToggle({
                id = "toggleBusLoop",
                icon = ICONS.all_inclusive,
                state = loop,
                onClick = function()
                    BJILocalStorage.set(BJILocalStorage.VALUES.SCENARIO_BUS_MISSION_LOOP, not loop)
                end,
                big = true,
            })
        end
        line
            :btnIcon({
                id = "stopBusMission",
                icon = ICONS.exit_to_app,
                style = BTN_PRESETS.ERROR,
                onClick = onStopBusMission,
                big = true,
            })
            :build()
    end
end

local function onTargetReached(ctxt)
    M.checkTargetProcess = false
    local flashMsg = BJILang.get("buslines.play.flashDriveNext")
    if M.nextStop == #M.line.stops then
        BJITx.scenario.BusMissionReward(M.line.id)
        if M.line.loopable and BJILocalStorage.get(BJILocalStorage.VALUES.SCENARIO_BUS_MISSION_LOOP) then
            -- trigger next loop
            M.nextStop = 2
            updateTarget(ctxt)
        else
            -- end of mission
            BJITx.scenario.BusMissionStop()
            flashMsg = BJILang.get("buslines.play.flashFinish")
            BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
        end
    else
        M.nextStop = M.nextStop + 1
        updateTarget(ctxt)
    end
    BJIMessage.flash("BJIBusMissionTarget", flashMsg, 3, false)
end

local function canVehUpdate()
    return not M.init
end

local function updateCornerMarkersColor(reached)
    for _, marker in ipairs(M.cornerMarkers) do
        if reached then
            marker:setField('instanceColor', 0, '0 1 0 1')
        else
            marker:setField('instanceColor', 0, "1 0 0 1")
        end
    end
end

local function slowTick(ctxt)
    if M.init and M.state == M.STATES.DRIVE then
        if not ctxt.isOwner then
            M.onStopBusMission()
            return
        end

        local points = { vec3(ctxt.vehPosRot.pos) }
        for i = M.nextStop, #M.line.stops do
            table.insert(points, vec3(M.line.stops[i].pos))
        end
        local remainingDistance = BJIGPS.getRouteLength(points)
        M.progression = 1 - (remainingDistance / M.line.totalDistance)

        local target = M.line.stops[M.nextStop]
        local distance = GetHorizontalDistance(ctxt.vehPosRot.pos, target.pos)

        if distance < target.radius then
            -- core_vehicleBridge.registerValueChangeNotification(veh, "kneel")
            -- core_vehicleBridge.registerValueChangeNotification(veh, "dooropen")
            -- core_vehicleBridge.getCachedVehicleData(id, 'kneel') == 1
            -- core_vehicleBridge.getCachedVehicleData(id, 'dooropen') == 1
            if not M.checkTargetProcess then
                M.checkTargetProcess = true
                BJIMessage.flashCountdown("BJIBusMissionTarget", ctxt.now + 5100, false, "", nil, onTargetReached)
                updateCornerMarkersColor(true)
            end
        else
            if M.checkTargetProcess then
                BJIMessage.cancelFlash("BJIBusMissionTarget")
                M.checkTargetProcess = false
                updateCornerMarkersColor(false)
            end
            if #BJIGPS.targets == 0 then
                BJIGPS.prependWaypoint(BJIGPS.KEYS.BUS_STOP, target.pos, target.radius, nil, nil, false)
            end
        end
    end
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if not BJIPerm.isStaff() and not player.self and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_KICK) and
        BJIVote.Kick.canStartVote(player.playerID) then
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

local function removeCornerMarkers()
    for _, marker in ipairs(M.cornerMarkers) do
        scenetree.findObject('ScenarioObjectsGroup'):removeObject(marker)
        marker:unregisterObject()
        marker:delete()
    end
    table.clear(M.cornerMarkers)
end

local function onUnload(ctxt)
    removeCornerMarkers()
    reset()
    BJIRestrictions.apply(BJIRestrictions.TYPES.ResetBusMission, false)
    BJIQuickTravel.toggle(true)
    BJINametags.toggle(true)
    BJIGPS.reset()
    BJIBusUI.reset()
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.initDrive = initDrive

M.drawUI = drawUI

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.onStopBusMission = onStopBusMission
M.onTargetReached = onTargetReached

M.canSelectVehicle = canVehUpdate
M.canSpawnNewVehicle = canVehUpdate
M.canReplaceVehicle = canVehUpdate
M.canDeleteVehicle = canVehUpdate
M.canDeleteOtherVehicles = canVehUpdate
M.canEditVehicle = canVehUpdate

M.slowTick = slowTick

M.getPlayerListActions = getPlayerListActions

M.onUnload = onUnload

return M
