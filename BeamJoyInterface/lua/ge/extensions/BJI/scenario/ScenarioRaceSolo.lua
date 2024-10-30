local M = {
    RESPAWN_STRATEGIES = {
        NO_RESPAWN = "norespawn",
        LAST_CHECKPOINT = "lastcheckpoint",
        STAND = "stand",
    },

    baseSettings = nil,
    baseRaceData = nil,

    testing = false,
    testingCallback = nil,

    exemptNextReset = false,

    raceName = nil,
    record = nil,

    settings = {
        raceID = nil,
        laps = nil,
        model = nil,
        respawnStrategy = nil,
    },

    gridResetProcess = false,

    startPosition = nil,

    race = {
        startTime = nil,
        raceData = {
            -- loopable
            -- wpPerLap
            -- steps
        },
        leaderboard = {},
        lap = 1,
        waypoint = 0,
        stands = {},
        lastWaypoint = nil,
        timers = {
            race = nil,
            lap = nil,
            finalTime = nil,
        },
    },

    dnf = {
        minDistance = .5,
        timeout = 10,    -- +1 during first check
        process = false, -- true if countdown is launched

        standExempt = false,
        lastPos = nil,
        targetTime = nil,
    },

    loop = false,
}

local function stopRace()
    M.baseSettings = nil
    M.baseRaceData = nil

    M.testing = false
    if type(M.testingCallback) == "function" then
        M.testingCallback()
        M.testingCallback = nil
    end

    M.exemptNextReset = false

    M.raceName = nil
    M.record = nil

    M.settings = {
        raceID = nil,
        laps = nil,
        model = nil,
        respawnStrategy = nil,
    }

    M.startPosition = nil

    M.race = {
        startTime = nil,
        raceData = {},
        leaderboard = {},
        lap = 1,
        waypoint = 0,
        stands = {},
        lastWaypoint = nil,
        timers = {
            race = nil,
            lap = nil,
            finalTime = nil,
        },
    }

    M.dnf = {
        minDistance = .5,
        timeout = 10,
        process = false,

        lastPos = nil,
        targetTime = nil,
    }
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return BJIScenario.isFreeroam() and
        ctxt.isOwner and
        not BJIVeh.isUnicycle(ctxt.veh:getID()) and
        #BJIContext.Scenario.Data.Races > 0
end

-- load hook
local function onLoad(ctxt)
    BJIVehSelector.tryClose()
    BJIRestrictions.apply(BJIRestrictions.TYPES.ResetRace, true)
    BJIQuickTravel.toggle(false)
    BJIRaceWaypoint.resetAll()
    BJIWaypointEdit.reset()
    BJIGPS.reset()
    BJICam.addRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
    BJITx.scenario.RaceSoloStart()
end

-- player vehicle switch hook
local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if newGameVehID ~= -1 then
        BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
    end
end

local function canVehUpdate()
    return false
end

local function getCollisionsType(ctxt)
    return BJICollisions.TYPES.DISABLED
end

-- player list contextual actions getter
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

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJIAsync.removeTask("BJIRaceStandReset")
    BJIAsync.removeTask("BJIRaceStandEnd")
    BJIAsync.removeTask("BJIRaceStart")
    BJIAsync.removeTask("BJIRaceStartWaypoints")
    BJIAsync.removeTask("BJIRaceStartTime")
    BJIAsync.removeTask("BJIRaceDNFStop")
    BJIMessage.cancelFlash("BJIRaceStartShortCountdown")
    BJIMessage.cancelFlash("BJIRaceDNF")
    if ctxt.isOwner then
        BJIVeh.freeze(false, ctxt.veh:getID())
    end

    BJIRaceUI.clear()
    BJITx.scenario.RaceSoloEnd(M.race.timers.finalTime ~= nil)
    stopRace()
    BJIRaceWaypoint.resetAll()
    BJIRestrictions.apply(BJIRestrictions.TYPES.ResetRace, false)
    BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
    BJIMessage.stopRealtimeDisplay()
end

-- prepare complete race steps list
local function initSteps(steps)
    -- parse vectors data
    for _, step in ipairs(steps or {}) do
        for _, wp in ipairs(step) do
            local parsed = TryParsePosRot(wp)
            wp.pos = parsed.pos
            wp.rot = parsed.rot
        end
    end

    local nSteps = {}

    -- parse for each lap
    for iLap = 1, M.settings.laps or 1 do
        for iStep, step in ipairs(steps) do
            local nStep = {}
            for _, wp in ipairs(step) do
                local parents = {}
                for _, parent in ipairs(wp.parents) do
                    if parent == "start" then
                        if iLap == 1 then
                            table.insert(parents, parent)
                        else
                            -- point from last lap finishes
                            for _, lastWP in ipairs(steps[#steps]) do
                                table.insert(parents, svar("{1}-{2}", { lastWP.name, iLap - 1 }))
                            end
                        end
                    else
                        table.insert(parents, svar("{1}-{2}", { parent, iLap }))
                    end
                end
                local name = svar("{1}-{2}", { wp.name, iLap })
                table.insert(nStep, {
                    name = name,
                    pos = wp.pos,
                    rot = wp.rot,
                    radius = wp.radius,
                    parents = parents,
                    lap = iStep == #steps,
                    stand = wp.stand,
                })
            end
            table.insert(nSteps, nStep)
        end
    end
    M.race.raceData.steps = nSteps
end

local function parseRaceData(steps)
    M.race.raceData.wpPerLap = #steps
    initSteps(steps)
    for iStep, step in ipairs(steps or {}) do
        for _, wp in ipairs(step) do
            if wp.stand then
                table.insert(M.race.stands, { step = iStep, pos = wp.pos, rot = wp.rot })
            end
        end
    end
end

--[[
2 formats:<br>
<ul>
    <li>Solo Sprint (or loopable with 1 lap) : array =</li>
    <li>
        <ul>
            <li>wp: number (last waypoint reached)</li>
            <li>waypoints: object =</li>
            <li>
                <ul>
                    <li>wp: number = raceTime: number</li>
                </ul>
            </li>
        </ul>
    </li>
    <li>Solo Loopable: array =</li>
    <li>
        <ul>
            <li>laps: array =</li>
            <li>
                <ul>
                    <li>wp: number (last waypoint reached)</li>
                    <li>time: number (lap time, if lap finished)</li>
                    <li>diff: number (best lap time difference, if lap finished and not best)</li>
                </ul>
            </li>
        </ul>
    </li>
</ul>
]]
local function initLeaderboard()
    if M.isSprint() then
        -- sprint
        M.race.leaderboard = {
            wp = 0,
            waypoints = {},
        }
    else
        -- loopable
        M.race.leaderboard = {
            laps = {},
        }
    end
end

local function updateLeaderBoard(remainingSteps, raceTime, lapTime)
    local reachedWp
    if M.isSprint() then
        -- sprint
        reachedWp = #M.race.raceData.steps - remainingSteps

        M.race.leaderboard.wp = reachedWp
        M.race.leaderboard.waypoints[reachedWp] = raceTime
    else
        -- loopable
        local remainingLaps = M.settings.laps - M.race.lap
        local remainingWpInLap = remainingSteps - (remainingLaps * M.race.raceData.wpPerLap)
        reachedWp = M.race.raceData.wpPerLap - remainingWpInLap

        if not M.race.leaderboard.laps[M.race.lap] then
            M.race.leaderboard.laps[M.race.lap] = {
                wp = reachedWp,
                time = nil,
                diff = nil,
            }
        else
            M.race.leaderboard.laps[M.race.lap].wp = reachedWp
        end
        if reachedWp == M.race.raceData.wpPerLap then
            M.race.leaderboard.laps[M.race.lap].time = lapTime
        end

        local finishedLaps = #M.race.leaderboard.laps
        while finishedLaps > 1 and not M.race.leaderboard.laps[finishedLaps].time do
            finishedLaps = finishedLaps - 1
        end
        if finishedLaps > 1 then
            local bestLap, bestLapTime = 1, M.race.leaderboard.laps[1].time
            for iLap, lap in ipairs(M.race.leaderboard.laps) do
                if lap.time then
                    if lap.time < bestLapTime then
                        bestLap = iLap
                        bestLapTime = lap.time
                    end
                    lap.diff = nil
                end
            end

            for iLap, lap in ipairs(M.race.leaderboard.laps) do
                if lap.time and iLap ~= bestLap then
                    lap.diff = lap.time - bestLapTime
                end
            end
        end
    end
end

local function onStandStop(delayMs, wp, callback)
    BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, true)
    M.dnf.standExempt = true

    delayMs = delayMs and math.max(delayMs, 3000) or 5000
    BJIMessage.flashCountdown("BJIRaceStand", GetCurrentTimeMillis() + delayMs, true,
        BJILang.get("races.play.flashCountdownZero"))

    local previousCam = BJICam.getCamera()
    BJICam.setCamera(BJICam.CAMERAS.EXTERNAL)
    BJIVeh.stopCurrentVehicle()
    BJIVeh.freeze(true)

    BJIAsync.delayTask(function()
        local rot = wp and wp.rot or nil
        M.exemptNextReset = true
        BJIVeh.setPositionRotation(BJIVeh.getPositionRotation().pos, rot)
        if BJICam.getCamera() == BJICam.CAMERAS.EXTERNAL then
            BJICam.setCamera(previousCam)
        end
        BJIAsync.delayTask(function(ctxt3)
            BJIVeh.freeze(true)
            if ctxt3.camera == BJICam.CAMERAS.EXTERNAL then
                ctxt3.camera = BJICam.CAMERAS.ORBIT
                BJICam.setCamera(ctxt3.camera)
            end
        end, 100, "BJIRaceCameraCheckAndFreeze")
    end, delayMs - 3000, "BJIRaceStandReset")

    BJIAsync.delayTask(function()
        BJIVeh.freeze(false)
        if not M.settings.respawnStrategy ~= M.RESPAWN_STRATEGIES.NO_RESPAWN then
            BJIAsync.delayTask(function()
                -- delays reset restriction remove
                BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
                M.dnf.standExempt = false
            end, 1000, "BJIRaceStandEndRestrictionReset")
        end
        if type(callback) == "function" then
            callback()
        end
    end, delayMs, "BJIRaceStandEnd")
end

local function drawLapDiff()
    local diff, recordDiff
    if M.isSprint() then
        local time = M.race.leaderboard.waypoints[M.race.raceData.wpPerLap]
        if time and M.record then
            recordDiff = time - M.record.time
        end
    else
        local previousBestTime
        for i = 1, M.race.lap - 1 do
            local time = M.race.leaderboard.laps[i].time
            if not previousBestTime or time < previousBestTime then
                previousBestTime = time
            end
        end
        local lapTime = M.race.leaderboard.laps[M.race.lap].time
        if previousBestTime then
            diff = lapTime - previousBestTime
        end
        if M.record then
            recordDiff = lapTime - M.record.time
        end
        BJIRaceUI.addHotlapRow(M.race.lap, lapTime)
    end
    BJIRaceUI.setRaceTime(diff, recordDiff, 3000)
end

local function onCheckpointReached(wp, remainingSteps)
    local currentWaypoint = #M.race.raceData.steps - remainingSteps
    M.race.waypoint = currentWaypoint

    local function wpTrigger()
        local raceTime = M.race.timers.race:get()
        local lapTime = M.race.timers.lap:get()

        if M.settings.respawnStrategy == M.RESPAWN_STRATEGIES.LAST_CHECKPOINT then
            M.race.lastWaypoint = { pos = wp.pos, rot = wp.rot }
        end

        updateLeaderBoard(remainingSteps, raceTime, lapTime)

        local function onLap()
            if not M.testing then
                -- send to server (time broadcasted or new record)
                BJITx.scenario.RaceSoloUpdate(M.settings.raceID, lapTime, M.settings.model)
            end
        end

        BJISound.play(BJISound.SOUNDS.RACE_WAYPOINT)
        if remainingSteps == 0 then
            -- finish
            M.race.timers.lap = nil
            M.race.timers.race = nil
            M.race.timers.finalTime = lapTime

            BJIRaceUI.setWaypoint(M.race.raceData.wpPerLap, M.race.raceData.wpPerLap)
            drawLapDiff()

            onLap()
        elseif wp.lap then
            -- lap
            M.race.timers.lap:reset()

            BJIRaceUI.setWaypoint(M.race.waypoint % M.race.raceData.wpPerLap, M.race.raceData.wpPerLap)
            drawLapDiff()

            M.race.lap = M.race.lap + 1
            BJIRaceUI.setLap(M.race.lap, M.settings.laps)

            local lapMessage
            if M.race.lap == M.settings.laps then
                lapMessage = BJILang.get("races.play.finalLapFlash")
            else
                lapMessage = svar(BJILang.get("races.play.Lap"), { lap = M.race.lap })
            end
            BJIMessage.flash("BJIRaceLap", lapMessage, 5, false)

            onLap()
        else
            -- regular checkpoint
            BJIMessage.flash("BJIRaceCheckpoint", RaceDelay(lapTime), 2, false)
            BJIRaceUI.setWaypoint(M.race.waypoint % M.race.raceData.wpPerLap, M.race.raceData.wpPerLap)
        end
    end

    if wp.stand then
        onStandStop(5000, wp, wpTrigger)
    else
        wpTrigger()
    end
end

local function stopWithLoop()
    local settings, raceData = M.baseSettings, M.baseRaceData
    local loop = not M.testing and M.loop
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
    if loop then
        M.initRace(BJITick.getContext(), settings, raceData)
        M.loop = true
    end
end

local function onFinishReached()
    local postFinishTimeout = BJIContext.BJC.Race.FinishTimeout * 1000
    BJIMessage.flash("BJIRaceEndSelf", BJILang.get("races.play.finishFlashSolo"), 3, false)
    BJIAsync.delayTask(stopWithLoop, postFinishTimeout, "BJIRacePostFinish")
end

local function initWaypoints()
    BJIRaceWaypoint.resetAll()
    for _, step in ipairs(M.race.raceData.steps) do
        BJIRaceWaypoint.addRaceStep(step)
    end

    BJIRaceWaypoint.setRaceWaypointHandler(onCheckpointReached)
    BJIRaceWaypoint.setRaceFinishHandler(onFinishReached)
end

local function isRaceStarted(ctxt)
    local now = ctxt and ctxt.now or GetCurrentTimeMillis()
    return M.race.startTime and now >= M.race.startTime
end

local function isRaceFinished()
    return not not M.race.timers.finalTime
end

-- player vehicle reset hook
local function onVehicleResetted(gameVehID)
    if M.exemptNextReset then
        M.exemptNextReset = false
        return
    end

    if M.isRaceStarted() and M.settings.respawnStrategy then
        local rs = M.settings.respawnStrategy
        if rs == M.RESPAWN_STRATEGIES.LAST_CHECKPOINT then
            M.exemptNextReset = true
            local wp = M.race.lastWaypoint or M.startPosition
            if wp then
                BJIVeh.setPositionRotation(wp.pos, wp.rot)
            end
        elseif rs == M.RESPAWN_STRATEGIES.STAND then
            local pastStand
            for _, stand in ipairs(M.race.stands) do
                if stand.step <= M.race.waypoint and
                    (not pastStand or stand.step > pastStand.step) then
                    pastStand = stand
                end
                if stand.step > M.race.waypoint then
                    break
                end
            end
            if not pastStand and M.startPosition then
                -- no past stand then start pos
                pastStand = {
                    pos = M.startPosition.pos,
                    rot = M.startPosition.rot,
                }
            end
            M.exemptNextReset = true
            BJIVeh.setPositionRotation(pastStand.pos, pastStand.rot)
        end
    end
end

local function findFreeStartPosition(startPositions)
    local vehs = BJIVeh.getMPVehicles()
    for _, sp in ipairs(startPositions) do
        local positionFree = true
        for _, v in pairs(vehs) do
            local veh = BJIVeh.getVehicleObject(v.gameVehicleID)
            if veh and v.gameVehicleID ~= BJIContext.User.currentVehicle then
                local posRot = BJIVeh.getPositionRotation(veh)
                if posRot and
                    posRot.pos:distance(vec3(sp.pos)) <= veh:getInitialLength() / 2 then
                    positionFree = false
                    break
                end
            end
        end
        if positionFree then
            return TryParsePosRot(tdeepcopy(sp))
        end
    end
    return TryParsePosRot(tdeepcopy(startPositions[1]))
end

local function initRace(ctxt, settings, raceData, testingCallback)
    M.baseSettings = tdeepcopy(settings)
    M.baseRaceData = tdeepcopy(raceData)

    if testingCallback then
        M.testing = true
        M.testingCallback = testingCallback
    end

    BJIVeh.deleteOtherOwnVehicles()
    BJIScenario.switchScenario(BJIScenario.TYPES.RACE_SOLO, ctxt)
    M.settings.model = BJIVeh.getCurrentModel()
    M.settings.laps = settings.laps
    M.settings.respawnStrategy = settings.respawnStrategy

    M.settings.raceID = raceData.id
    M.raceName = raceData.name
    M.raceAuthor = raceData.author
    M.record = raceData.record
    M.startPosition = findFreeStartPosition(raceData.startPositions)
    parseRaceData(raceData.steps)
    initLeaderboard()

    if not M.isSprint() then
        BJIRaceUI.setLap(M.race.lap, M.settings.laps)
    end
    BJIRaceUI.setWaypoint(M.race.waypoint, M.race.raceData.wpPerLap)

    BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, true)
    local previousCam = ctxt.camera
    BJIVeh.setPositionRotation(M.startPosition.pos, M.startPosition.rot)
    BJIVeh.freeze(true)
    if tincludes({
            BJICam.CAMERAS.FREE,
            BJICam.CAMERAS.BIG_MAP,
            BJICam.CAMERAS.PASSENGER,
            BJICam.CAMERAS.EXTERNAL,
        }, previousCam) then
        previousCam = BJICam.CAMERAS.ORBIT
    end
    BJICam.setCamera(BJICam.CAMERAS.EXTERNAL)
    M.race.startTime = GetCurrentTimeMillis() + 5500

    BJIMessage.flashCountdown("BJIRaceStart", M.race.startTime, true,
        BJILang.get("races.play.flashCountdownZero"), 5, nil, true)
    initWaypoints()

    -- 3secs before start
    BJIAsync.programTask(function(ctxt2)
        if ctxt2.camera == BJICam.CAMERAS.EXTERNAL then
            BJICam.setCamera(previousCam)
        end
    end, M.race.startTime - 3000, "BJIRaceStartShortCountdown")

    -- enable waypoints before start to avoid stutter
    BJIAsync.programTask(BJIRaceWaypoint.startRace,
        M.race.startTime - 500, "BJIRaceStartWaypoints")

    -- on start
    BJIAsync.programTask(function()
        M.race.timers.race = TimerCreate()
        M.race.timers.lap = TimerCreate()
        BJIVeh.freeze(false)
        if M.settings.respawnStrategy ~= M.RESPAWN_STRATEGIES.NO_RESPAWN then
            BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
        end
    end, M.race.startTime, "BJIRaceStartTime")
end

local function isSprint()
    return not M.settings.laps or M.settings.laps == 1
end

-- each frame tick hook
local function renderTick(ctxt)
    if not ctxt.isOwner then
        BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
        return
    end

    -- lap realtimeDisplay
    local time = 0
    if M.race.timers.finalTime then
        time = M.race.timers.finalTime
    elseif M.race.timers.lap then
        time = M.race.timers.lap:get()
    end
    BJIMessage.realtimeDisplay("race", RaceDelay(time))

    -- fix vehicle position / damages on grid
    if not M.gridResetProcess and
        not M.isRaceStarted(ctxt) then
        local moved = GetHorizontalDistance(
            M.startPosition.pos,
            ctxt.vehPosRot.pos
        ) > .5
        local damageThreshold = 10
        local damaged = ctxt.vehData and ctxt.vehData.damageState > damageThreshold
        if moved or damaged then
            M.startPosition = findFreeStartPosition(M.baseRaceData.startPositions)
            if M.startPosition then
                BJIVeh.setPositionRotation(M.startPosition.pos, M.startPosition.rot)
                BJIVeh.freeze(true, ctxt.veh:getID())
                M.gridResetProcess = true
                BJIAsync.task(function(ctxt2)
                    return not ctxt2.isOwner or
                        (ctxt2.vehPosRot.pos:distance(M.startPosition.pos) < .5 and
                            ctxt2.vehData.damageState < damageThreshold)
                end, function()
                    M.gridResetProcess = false
                end, "BJIRaceSoloGridResetProcess")
            else
                LogError("Unable to find a free start position")
                stopRace()
            end
        end
    end

    -- prevent jato usage before start
    if not M.race.startTime or ctxt.now < M.race.startTime then
        ctxt.veh:queueLuaCommand("thrusters.applyVelocity(vec3(0,0,0))")
    end
end

-- each second tick hook
local function slowTick(ctxt)
    -- DNF PROCESS
    if ctxt.isOwner and M.isRaceStarted(ctxt) and not M.isRaceFinished() and
        M.settings.respawnStrategy == M.RESPAWN_STRATEGIES.NO_RESPAWN and
        not M.dnf.standExempt then
        if not M.dnf.lastPos then
            -- first check
            M.dnf.lastPos = ctxt.vehPosRot.pos
        else
            if GetHorizontalDistance(ctxt.vehPosRot.pos, M.dnf.lastPos) < M.dnf.minDistance then
                -- distance isn't enough
                if not M.dnf.process then
                    -- start countdown process
                    M.dnf.process = true
                    M.dnf.targetTime = ctxt.now + (M.dnf.timeout * 1000)
                    BJIMessage.flashCountdown("BJIRaceDNF", M.dnf.targetTime, true,
                        BJILang.get("races.play.flashDnfOut"), nil,
                        function()
                            BJIMessage.flash("BJIRaceEndSelf", BJILang.get("races.play.flashDnfOut"), 3, false)
                            BJIAsync.delayTask(stopWithLoop, 3000, "BJIRaceDNFStop")
                        end)
                end
            else
                -- good distance, remove countdown if there is one
                if M.dnf.process then
                    BJIMessage.cancelFlash("BJIRaceDNF")
                    M.dnf.process = false
                    M.dnf.targetTime = nil
                end
                M.dnf.lastPos = ctxt.vehPosRot.pos
            end
        end
    end

    -- RECORD UPDATE
    for _, race in ipairs(BJIContext.Scenario.Data.Races) do
        if race.id == M.settings.raceID and race.record and
            (not M.record or race.record.time ~= M.record.time) then
            M.record = race.record
        end
    end
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad
M.initRace = initRace

M.isSprint = isSprint

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched

M.canSelectVehicle = canVehUpdate
M.canSpawnNewVehicle = canVehUpdate
M.canReplaceVehicle = canVehUpdate
M.canDeleteVehicle = canVehUpdate
M.canDeleteOtherVehicles = canVehUpdate
M.canEditVehicle = canVehUpdate
M.getCollisionsType = getCollisionsType

M.getPlayerListActions = getPlayerListActions

M.renderTick = renderTick
M.slowTick = slowTick

M.onUnload = onUnload

M.isRaceStarted = isRaceStarted
M.isRaceFinished = isRaceFinished

return M
