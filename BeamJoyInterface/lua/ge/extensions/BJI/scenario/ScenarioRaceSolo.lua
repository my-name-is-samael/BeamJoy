---@class MapRacePBWP
---@field time integer time in ms since lap start
---@field speed number speed in km/h

---@class RaceStand
---@field step integer
---@field pos vec3
---@field rot quat

local M = {
    RESPAWN_STRATEGIES = {
        NO_RESPAWN = "norespawn",
        LAST_CHECKPOINT = "lastcheckpoint",
        STAND = "stand",
    },

    dnf = {
        minDistance = .5,
        timeout = 10, -- +1 during first check
    },
}

local function initManagerData()
    M.baseSettings = nil
    M.baseRaceData = nil

    M.testing = false
    if type(M.testingCallback) == "function" then
        M.testingCallback()
    end
    M.testingCallback = nil

    M.exemptNextReset = false

    M.raceName = nil
    M.raceHash = nil
    M.record = nil

    M.settings = {
        raceID = nil,
        laps = nil,
        model = nil,
        respawnStrategy = nil,
    }
    M.raceVeh = nil

    M.gridResetProcess = false

    M.startPosition = nil

    M.race = {
        startTime = nil,
        raceData = {
            -- loopable
            -- wpPerLap
            -- steps
        },
        leaderboard = {},
        lap = 1,
        waypoint = 0,
        ---@type RaceStand[]
        stands = {},
        lastWaypoint = nil,
        ---@type RaceStand
        lastStand = nil,
        timers = {
            race = nil,
            lap = nil,
            finalTime = nil,
        },
    }

    M.currentSpeed = 0
    ---@type MapRacePBWP[]
    M.lapData = {}

    M.dnf.process = false -- true if countdown is launched
    M.dnf.standExempt = false
    M.dnf.lastPos = nil
    M.dnf.targetTime = nil
end
initManagerData()

local function stopRace()
    initManagerData()
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
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_NONE)
    BJIQuickTravel.toggle(false)
    BJIRaceWaypoint.resetAll()
    BJIWaypointEdit.reset()
    BJIGPS.reset()
    BJICam.addRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
    BJITx.scenario.RaceSoloStart()
end

-- player vehicle switch hook
local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if newGameVehID ~= -1 and
        newGameVehID ~= M.raceVeh then
        BJIVeh.focusVehicle(newGameVehID)
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
            id = string.var("voteKick{1}", { player.playerID }),
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
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_ALL)
    guihooks.trigger('ScenarioResetTimer')
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
                                table.insert(parents, string.var("{1}-{2}", { lastWP.name, iLap - 1 }))
                            end
                        end
                    else
                        table.insert(parents, string.var("{1}-{2}", { parent, iLap }))
                    end
                end
                local name = string.var("{1}-{2}", { wp.name, iLap })
                table.insert(nStep, {
                    name = name,
                    pos = wp.pos,
                    zOffset = wp.zOffset,
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
                table.insert(M.race.stands, { step = iStep, pos = vec3(wp.pos), rot = quat(wp.rot) })
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

local function onStandStop(delayMs, wp, lastWp, callback)
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_NONE)
    M.dnf.standExempt = true

    BJIMessage.flashCountdown("BJIRaceStand", GetCurrentTimeMillis() + delayMs, true,
        BJILang.get("races.play.flashCountdownZero"))

    local previousCam = BJICam.getCamera()
    BJICam.setCamera(BJICam.CAMERAS.EXTERNAL)
    BJIVeh.stopCurrentVehicle()
    BJIVeh.freeze(true)
    M.race.lastStand = {step = lastWp.wp, pos = BJIVeh.getPositionRotation().pos, rot = wp.rot}
    BJIVeh.saveHome(M.race.lastStand)

    BJIAsync.delayTask(function()
        M.exemptNextReset = true
        BJIVeh.loadHome(function(ctxt)
            BJIVeh.freeze(true)
            if ctxt.camera == BJICam.CAMERAS.EXTERNAL then
                BJICam.setCamera(previousCam)
                ctxt.camera = BJICam.getCamera()
            end
            if ctxt.camera == BJICam.CAMERAS.EXTERNAL then
                BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                ctxt.camera = BJICam.getCamera()
            end
        end)
    end, delayMs - 3000, "BJIRaceStandReset")

    BJIAsync.delayTask(function()
        BJIVeh.freeze(false)
        if not M.settings.respawnStrategy ~= M.RESPAWN_STRATEGIES.NO_RESPAWN then
            BJIAsync.delayTask(function()
                -- delays reset restriction remove
                BJIRestrictions.updateReset(M.settings.respawnStrategy and
                    BJIRestrictions.TYPES.LOAD_HOME or BJIRestrictions.TYPES.RESET_ALL)
                M.dnf.standExempt = false
            end, 1000, "BJIRaceStandEndRestrictionReset")
        end
        if type(callback) == "function" then
            callback()
        end
    end, delayMs, "BJIRaceStandEnd")
end

---@param isLap boolean
---@param lap integer
---@param wp integer
local function drawTimeDiff(isLap, lap, wp)
    ---@type MapRacePBWP[]?
    local pb = BJIRaceWaypoint.getPB(M.raceHash)

    local diff, recordDiff
    local time = M.lapData[wp].time
    if M.isSprint() then
        if time then
            if pb then
                diff = time - pb[wp].time
            end
            if isLap and M.record then
                recordDiff = time - M.record.time
            end
        end
    else
        if pb then
            diff = time - pb[wp].time
        end
        if isLap and M.record then
            recordDiff = time - M.record.time
        end
    end
    if isLap then
        BJIRaceUI.addHotlapRow(M.raceName, time)
    end
    BJIRaceUI.setRaceTime(diff, recordDiff, 3000)
end

local function onCheckpointReached(wp, remainingSteps)
    local currentWaypoint = #M.race.raceData.steps - remainingSteps
    M.race.waypoint = currentWaypoint

    local lastWp = {
        lap = math.ceil(currentWaypoint / M.race.raceData.wpPerLap),
        wp = currentWaypoint % M.race.raceData.wpPerLap > 0 and
            currentWaypoint % M.race.raceData.wpPerLap or M.race.raceData.wpPerLap,
    }

    local function wpTrigger()
        local raceTime = M.race.timers.race:get()
        local lapTime = M.race.timers.lap:get()

        if not wp.stand and M.settings.respawnStrategy and
            M.settings.respawnStrategy ~= M.RESPAWN_STRATEGIES.NO_RESPAWN then
            if M.settings.respawnStrategy == M.RESPAWN_STRATEGIES.LAST_CHECKPOINT then
                BJIVeh.saveHome({ pos = wp.pos, rot = wp.rot })
            elseif M.settings.respawnStrategy == M.RESPAWN_STRATEGIES.STAND then
                -- check if current or previous stand is different than last
                ---@param stand RaceStand
                local latestStand = table.filter(M.race.stands, function(stand)
                        return stand.step <= lastWp.wp
                    end)
                    ---@param acc? RaceStand
                    ---@param stand RaceStand
                    :reduce(function(acc, stand)
                        return (not acc or stand.step > acc.step) and stand or acc
                    end)
                if not latestStand and lastWp.lap > 1 then
                    ---@param acc? RaceStand
                    ---@param stand RaceStand
                    latestStand = table.reduce(M.race.stands, function(acc, stand)
                        return (not acc or stand.step > acc.step) and stand or acc
                    end)
                end
                if latestStand and latestStand.step ~= M.race.lastStand.step then
                    M.race.lastStand = latestStand
                    BJIVeh.saveHome(latestStand)
                end
            end
        end

        local lapWaypoint = currentWaypoint % M.race.raceData.wpPerLap
        lapWaypoint = lapWaypoint > 0 and lapWaypoint or M.race.raceData.wpPerLap
        M.lapData[lapWaypoint] = {
            time = lapTime,
            speed = math.round(M.currentSpeed * 3.6, 2),
        }
        updateLeaderBoard(remainingSteps, raceTime, lapTime)

        drawTimeDiff(wp.lap or remainingSteps == 0, lastWp.lap, lastWp.wp)

        local function onLap()
            if not M.testing then
                -- send to server (time broadcasted or new record)
                BJITx.scenario.RaceSoloUpdate(M.settings.raceID, lapTime, M.settings.model)

                -- detect new pb and save it
                ---@type MapRacePBWP[]?
                local pb = BJIRaceWaypoint.getPB(M.raceHash)
                local newPb = false
                if not pb then
                    pb = M.lapData
                    newPb = true
                else
                    local pbTime = pb[lapWaypoint] and pb[lapWaypoint].time or nil
                    if pbTime and M.lapData[lapWaypoint].time < pbTime then
                        pb = M.lapData
                        newPb = true
                    end
                end
                if newPb then
                    BJIRaceWaypoint.setPB(M.raceHash, pb)
                    BJIEvents.trigger(BJIEvents.EVENTS.RACE_NEW_PB, {
                        raceName = M.race.raceData.name,
                        raceID = M.settings.raceID,
                        raceHash = M.raceHash,
                        time = M.lapData[lapWaypoint].time,
                    })
                end
            end
        end

        BJISound.play(BJISound.SOUNDS.RACE_WAYPOINT)
        if remainingSteps == 0 then
            -- finish
            M.race.timers.lap = nil
            M.race.timers.race = nil
            M.race.timers.finalTime = lapTime

            BJIRaceUI.setWaypoint(M.race.raceData.wpPerLap, M.race.raceData.wpPerLap)

            onLap()
        elseif wp.lap then
            -- lap
            M.race.timers.lap:reset()

            BJIRaceUI.setWaypoint(M.race.waypoint % M.race.raceData.wpPerLap, M.race.raceData.wpPerLap)

            M.race.lap = M.race.lap + 1
            BJIRaceUI.setLap(M.race.lap, M.settings.laps)

            local lapMessage
            if M.race.lap == M.settings.laps then
                lapMessage = BJILang.get("races.play.finalLapFlash")
            else
                lapMessage = BJILang.get("races.play.Lap"):var({ lap = M.race.lap })
            end
            BJIMessage.flash("BJIRaceLap", lapMessage, 5, false)

            onLap()
        else
            -- regular checkpoint
            BJIMessage.flash("BJIRaceCheckpoint", RaceDelay(lapTime), 2, false)
            BJIRaceUI.setWaypoint(M.race.waypoint % M.race.raceData.wpPerLap, M.race.raceData.wpPerLap)
        end

        if wp.lap then
            M.lapData = {}
        end
    end

    if wp.stand then
        onStandStop(5000, wp, lastWp, wpTrigger)
    else
        wpTrigger()
    end
end

local function stopWithLoop()
    local settings, raceData = M.baseSettings, M.baseRaceData
    local loop = not M.testing and BJILocalStorage.get(BJILocalStorage.GLOBAL_VALUES.SCENARIO_SOLO_RACE_LOOP)
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
    if loop then
        M.initRace(BJITick.getContext(), settings, raceData)
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

local function findFreeStartPosition(startPositions)
    local vehs = BJIVeh.getMPVehicles()
    for _, sp in ipairs(startPositions) do
        local positionFree = true
        for _, v in pairs(vehs) do
            local veh = BJIVeh.getVehicleObject(v.gameVehicleID)
            if veh and v.gameVehicleID ~= BJIContext.User.currentVehicle then
                local posRot = BJIVeh.getPositionRotation(veh)
                if posRot and
                    posRot.pos:distance(vec3(sp.pos)) <= veh:getInitialWidth() / 2 then
                    positionFree = false
                    break
                end
            end
        end
        if positionFree then
            return TryParsePosRot(table.clone(sp))
        end
    end
    return TryParsePosRot(table.clone(startPositions[1]))
end

local function initRace(ctxt, settings, raceData, testingCallback)
    M.baseSettings = table.clone(settings)
    M.baseRaceData = table.clone(raceData)

    if testingCallback then
        M.testing = true
        M.testingCallback = testingCallback
    end

    BJIVeh.deleteOtherOwnVehicles()
    M.raceVeh = ctxt.veh:getID()
    BJIScenario.switchScenario(BJIScenario.TYPES.RACE_SOLO, ctxt)
    M.settings.model = BJIVeh.getCurrentModel()
    M.settings.laps = settings.laps
    M.settings.respawnStrategy = settings.respawnStrategy

    M.settings.raceID = raceData.id
    M.raceName = raceData.name
    M.raceHash = raceData.hash
    M.raceAuthor = raceData.author
    M.record = raceData.record
    M.startPosition = findFreeStartPosition(raceData.startPositions)
    parseRaceData(raceData.steps)
    initLeaderboard()

    if not M.isSprint() then
        BJIRaceUI.setLap(M.race.lap, M.settings.laps)
    end
    BJIRaceUI.setWaypoint(M.race.waypoint, M.race.raceData.wpPerLap)

    local previousCam = ctxt.camera
    BJIVeh.saveHome({ pos = M.startPosition.pos, rot = M.startPosition.rot })
    BJIVeh.loadHome(function()
        BJIVeh.freeze(true)
        if table.includes({
                BJICam.CAMERAS.FREE,
                BJICam.CAMERAS.BIG_MAP,
                BJICam.CAMERAS.PASSENGER,
                BJICam.CAMERAS.EXTERNAL,
            }, previousCam) then
            previousCam = BJICam.CAMERAS.ORBIT
        end
        BJICam.setCamera(BJICam.CAMERAS.EXTERNAL)
    end)
    M.race.startTime = GetCurrentTimeMillis() + 5500

    M.lapData = {}

    BJIMessage.flashCountdown("BJIRaceStart", M.race.startTime, true,
        BJILang.get("races.play.flashCountdownZero"), 5, nil, true)
    initWaypoints()

    -- 3secs before start
    BJIAsync.programTask(function(ctxt2)
        if ctxt2.camera == BJICam.CAMERAS.EXTERNAL then
            BJICam.setCamera(previousCam)
        end
        if M.settings.respawnStrategy == M.RESPAWN_STRATEGIES.STAND then
            M.race.lastStand = { step = 0, pos = M.startPosition.pos, rot = M.startPosition.rot }
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
            BJIRestrictions.updateReset(M.settings.respawnStrategy and
                BJIRestrictions.TYPES.LOAD_HOME or BJIRestrictions.TYPES.RESET_ALL)
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

    ctxt.veh:queueLuaCommand([[
        obj:queueGameEngineLua("BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).currentSpeed = " .. obj:getAirflowSpeed())
    ]])

    -- lap realtimeDisplay
    local time = 0
    if M.race.timers.finalTime then
        time = M.race.timers.finalTime
    elseif M.race.timers.lap then
        time = M.race.timers.lap:get()
    end
    guihooks.trigger('raceTime', { time = math.round(time / 1000, 3), reverseTime = true })

    -- fix vehicle position / damages on grid
    if not M.gridResetProcess and
        not M.isRaceStarted(ctxt) and
        M.startPosition then
        local moved = GetHorizontalDistance(
            M.startPosition.pos,
            ctxt.vehPosRot.pos
        ) > .5
        local damageThreshold = 10
        local damaged = ctxt.vehData and ctxt.vehData.damageState > damageThreshold
        if moved or damaged then
            M.startPosition = findFreeStartPosition(M.baseRaceData.startPositions)
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
