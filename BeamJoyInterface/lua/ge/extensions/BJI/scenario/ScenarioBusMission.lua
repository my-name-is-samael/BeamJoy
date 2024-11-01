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
    nextLoop = false,

    init = false,
    nextResetExempt = true,     -- exempt reset fail for vehicle creation
    checkTargetProcess = false, -- process to check player reached target and stayed in its radius
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
    M.nextLoop           = false

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

local function updateTarget()
    local next = M.line.stops[M.nextStop]

    BJIRaceWaypoint.resetAll()
    BJIRaceWaypoint.addWaypoint("BJIBusMission", next.pos, next.radius, BJIRaceWaypoint.COLORS.BLUE)
    if M.init then
        BJIBusUI.nextStop(M.nextStop)
        BJIBusUI.requestStop(true)
    end

    BJIGPS.reset()
    BJIGPS.prependWaypoint(BJIGPS.KEYS.BUS_STOP, next.pos, next.radius)
end

local function initDrive(ctxt)
    M.nextStop = 2

    local points = {}
    for _, stop in ipairs(M.line.stops) do
        table.insert(points, vec3(stop.pos))
    end
    M.line.totalDistance = BJIGPS.getRouteLength(points)

    local startPosRot = M.line.stops[1]
    BJIVeh.replaceOrSpawnVehicle(M.model, M.config, startPosRot)
    BJIAsync.task(function(ctxt2)
        return ctxt2.isOwner and
        not BJIVeh.isConfigCustom(ctxt2.veh.partConfig) and
        ctxt2.veh.partConfig:find(svar("/{1}.", {M.config}))
    end, function()
        M.state = M.STATES.DRIVE
        updateTarget()
        BJIMessage.flash("BJIBusMissionTarget", BJILang.get("buslines.play.flashDriveNext"), 3, false)
        BJIAsync.delayTask(function()
            BJIBusUI.initBusMission(M.line.id, M.line.stops, M.nextStop)
            BJIBusUI.requestStop(true)
        end, 300, "BJIBusMissionInitBusUI")

        BJITx.scenario.BusMissionStart()
        M.init = true
    end, "BJIBusMissionInitVehicle")
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

local function drawMissionUI(ctxt)
    if M.state == M.STATES.DRIVE then
        LineBuilder()
            :text(svar(BJILang.get("buslines.play.line"), { name = M.line.name }))
            :build()
        LineBuilder()
            :text(svar(BJILang.get("buslines.play.stopCount"),
                { current = M.nextStop - 1, total = #M.line.stops }))
            :build()
        ProgressBar({
            floatPercent = M.progression,
            width = 250,
        })
        if M.line.loopable then
            LineBuilder()
                :text(BJILang.get("buslines.play.continueLoop"))
                :btnSwitchYesNo({
                    id = "continueLoop",
                    state = M.nextLoop,
                    onClick = function()
                        M.nextLoop = not M.nextLoop
                    end
                })
                :build()
        end
        LineBuilder()
            :btn({
                id = "stopBusMission",
                label = "Stop mission",
                style = BTN_PRESETS.ERROR,
                onClick = onStopBusMission,
            })
            :build()
    end
end

local function onTargetReached()
    M.checkTargetProcess = false
    local flashMsg = BJILang.get("buslines.play.flashDriveNext")
    if M.nextStop == #M.line.stops then
        BJITx.scenario.BusMissionReward(M.line.id)
        if M.line.loopable and M.nextLoop then
            -- trigger next loop
            M.nextStop = 2
            updateTarget()
        else
            -- end of mission
            BJITx.scenario.BusMissionStop()
            flashMsg = BJILang.get("buslines.play.flashFinish")
            BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
        end
    else
        M.nextStop = M.nextStop + 1
        updateTarget()
    end
    BJIMessage.flash("BJIBusMissionTarget", flashMsg, 3, false)
end

local function canVehUpdate()
    return not M.init
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
        local distance = GetHorizontalDistance(ctxt.vehPosRot.pos, target.pos) - (ctxt.veh:getInitialWidth() / 2)

        if distance < target.radius then
            -- core_vehicleBridge.registerValueChangeNotification(veh, "kneel")
            -- core_vehicleBridge.registerValueChangeNotification(veh, "dooropen")
            -- core_vehicleBridge.getCachedVehicleData(id, 'kneel') == 1
            -- core_vehicleBridge.getCachedVehicleData(id, 'dooropen') == 1
            if not M.checkTargetProcess then
                M.checkTargetProcess = true
                BJIMessage.flashCountdown("BJIBusMissionTarget", ctxt.now + 5100, false, "", nil, onTargetReached)
            end
        else
            if M.checkTargetProcess then
                BJIMessage.cancelFlash("BJIBusMissionTarget")
                M.checkTargetProcess = false
            end
            if #BJIGPS.targets == 0 then
                BJIGPS.prependWaypoint(BJIGPS.KEYS.BUS_STOP, target.pos, target.radius)
            end
        end
    end
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    local isSelf = BJIContext.isSelf(player.playerID)

    if not BJIPerm.isStaff() and not isSelf and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_KICK) and
        BJIVote.Kick.canStartVote(player.playerID) then
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
    reset()
    BJIRestrictions.apply(BJIRestrictions.TYPES.ResetBusMission, false)
    BJIQuickTravel.toggle(true)
    BJINametags.toggle(true)
    BJIGPS.reset()
    BJIRaceWaypoint.resetAll()
    BJIBusUI.reset()
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.initDrive = initDrive

M.drawMissionUI = drawMissionUI

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
