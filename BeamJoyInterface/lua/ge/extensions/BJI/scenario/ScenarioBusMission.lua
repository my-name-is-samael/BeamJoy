---@class BJIScenarioBusMission : BJIScenario
local S = {
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
    progression = nil,

    checkTargetProcess = false, -- process to check player reached target and stayed in its radius

    cornerMarkers = {},
}

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
    S.progression        = nil

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
            table.insert(S.cornerMarkers, marker)
        end
    end
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
    for k, marker in ipairs(S.cornerMarkers) do
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
    local next = S.line.stops[S.nextStop]

    updateCornerMarkers(ctxt, next)
    BJI.Managers.BusUI.nextStop(S.nextStop)
    BJI.Managers.BusUI.requestStop(true)

    BJI.Managers.GPS.reset()
    BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.BUS_STOP, next.pos, next.radius, nil, nil, false)
end

local function onLoad(ctxt)
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.Restrictions.update({
        {
            restrictions = Table({
                BJI.Managers.Restrictions.RESET.ALL,
                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            }):flat(),
            state = BJI.Managers.Restrictions.STATE.RESTRICTED,
        }
    })
    BJI.Managers.GPS.reset()
    BJI.Managers.RaceWaypoint.resetAll()

    BJI.Tx.scenario.BusMissionStart()
end

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
                    ctxt2.veh.partConfig:find(string.var("/{1}.", { S.config }))
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

local function drawUI(ctxt, cache)
    LineBuilder()
        :text(cache.labels.busMission.line:var({ name = S.line.name }))
        :build()
    LineBuilder()
        :text(cache.labels.busMission.stopCount
            :var({ current = S.nextStop - 1, total = #S.line.stops }))
        :build()
    ProgressBar({
        floatPercent = S.progression,
        width = 250,
        style = BJI.Utils.Style.BTN_PRESETS.INFO[1],
    })
    local line = LineBuilder()
    if S.line.loopable then
        local loop = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_BUS_MISSION_LOOP)
        line:btnIconToggle({
            id = "toggleBusLoop",
            icon = ICONS.all_inclusive,
            state = loop,
            tooltip = cache.labels.busMission.loop,
            onClick = function()
                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_BUS_MISSION_LOOP, not loop)
            end,
            big = true,
        })
    end
    line:btnIcon({
        id = "stopBusMission",
        icon = ICONS.exit_to_app,
        big = true,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = cache.labels.busMission.leave,
        onClick = onStopBusMission,
    }):build()
end

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

local function updateCornerMarkersColor(reached)
    for _, marker in ipairs(S.cornerMarkers) do
        if reached then
            marker:setField('instanceColor', 0, '0 1 0 1')
        else
            marker:setField('instanceColor', 0, "1 0 0 1")
        end
    end
end

local function slowTick(ctxt)
    if not ctxt.isOwner then
        S.onStopBusMission()
        return
    end

    local points = { vec3(ctxt.vehPosRot.pos) }
    for i = S.nextStop, #S.line.stops do
        table.insert(points, vec3(S.line.stops[i].pos))
    end
    local remainingDistance = BJI.Managers.GPS.getRouteLength(points)
    S.progression = 1 - (remainingDistance / S.line.totalDistance)

    local target = S.line.stops[S.nextStop]
    local distance = math.horizontalDistance(ctxt.vehPosRot.pos, target.pos)

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
            BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.BUS_STOP, target.pos, target.radius, nil, nil,
                false)
        end
    end
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if not BJI.Managers.Perm.isStaff() and not player.self and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_KICK) and
        BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
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

local function removeCornerMarkers()
    for _, marker in ipairs(S.cornerMarkers) do
        scenetree.findObject('ScenarioObjectsGroup'):removeObject(marker)
        marker:unregisterObject()
        marker:delete()
    end
    table.clear(S.cornerMarkers)
end

local function onUnload(ctxt)
    removeCornerMarkers()
    reset()
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.ALL,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.GPS.reset()
    BJI.Managers.BusUI.reset()
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad

S.start = start

S.drawUI = drawUI

S.onStopBusMission = onStopBusMission
S.onTargetReached = onTargetReached

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn

S.canSpawnAI = TrueFn

S.slowTick = slowTick

S.getPlayerListActions = getPlayerListActions

S.onUnload = onUnload

return S
