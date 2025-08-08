---@class MapRacePBWP
---@field time integer time in ms since lap start
---@field speed number speed in km/h

---@class RaceStand : BJIPositionRotation
---@field step integer

---@class BJIScenarioRaceSolo : BJIScenario
local S = {
    _name = "RaceSolo",
    _key = "RACE_SOLO",
    _isSolo = true,

    preRaceCam = nil,
    settings = {},
    race = {},
    dnf = {
        minDistance = .5,
        timeout = 10, -- +1 during first check
    },
}
--- gc prevention
local actions

local function initManagerData()
    S.baseSettings = nil
    S.baseRaceData = nil

    S.testing = false

    S.exemptNextReset = false

    S.raceName = nil
    S.raceID = nil
    S.raceHash = nil
    S.record = nil

    S.preRaceCam = nil
    S.settings = {
        laps = nil,
        model = nil,
        respawnStrategy = nil,
    }
    S.raceVeh = nil

    S.startPosition = nil

    S.race = {
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

    ---@type MapRacePBWP[]
    S.lapData = {}
    ---@type BJIPositionRotationVelocity?
    S.lastLaunchedCheckpoint = nil
    S.lastLaunchedCheckpointTime = 0

    S.resetLock = true
    S.dnf.process = false -- true if countdown is launched
    S.dnf.standExempt = false
    S.dnf.lastPos = nil
    S.dnf.targetTime = nil
end
initManagerData()

local function stopRace()
    if type(S.testingCallback) == "function" then
        BJI_Async.delayTask(S.testingCallback, 0, "BJIRaceTestingCallback")
        S.testingCallback = nil
    end

    initManagerData()
end

-- can switch to scenario hook
---@param ctxt TickContext
local function canChangeTo(ctxt)
    return BJI_Scenario.isFreeroam() and
        ctxt.isOwner and
        not BJI_Veh.isUnicycle(ctxt.veh.gameVehicleID)
end

-- load hook
local function onLoad(ctxt)
    BJI_Win_VehSelector.tryClose()
    BJI_RaceWaypoint.resetAll()
    BJI_WaypointEdit.reset()
    BJI_GPS.reset()
    BJI_Cam.addRestrictedCamera(BJI_Cam.CAMERAS.BIG_MAP)
    if not S.testing then
        BJI_Tx_scenario.RaceSoloStart()
    end
end

-- unload hook (before switch to another scenario)
---@param ctxt TickContext
local function onUnload(ctxt)
    BJI_Async.removeTask("BJIRaceStandReset")
    BJI_Async.removeTask("BJIRaceStandEndRestrictionReset")
    BJI_Async.removeTask("BJIRaceStandEnd")
    BJI_Async.removeTask("BJIRaceStartShortCountdown")
    BJI_Async.removeTask("BJIRaceStartWaypoints")
    BJI_Async.removeTask("BJIRaceStartTime")
    BJI_Async.removeTask("BJIRaceDNFStop")
    BJI_Async.removeTask("BJIRacePostFinish")
    BJI_Message.cancelFlash("BJIRaceStart")
    BJI_Message.cancelFlash("BJIRaceStand")
    BJI_Message.cancelFlash("BJIRaceDNF")
    BJI_Message.cancelFlash("BJIRaceEndSelf")
    if ctxt.isOwner then
        BJI_Veh.freeze(false, ctxt.veh.gameVehicleID)
    end

    BJI_RaceUI.clear()
    if not S.testing then
        BJI_Tx_scenario.RaceSoloEnd(S.race.timers.finalTime ~= nil)
    end
    stopRace()
    BJI_RaceWaypoint.resetAll()
    if S.preRaceCam then
        BJI_Cam.setCamera(S.preRaceCam)
    elseif ctxt.camera == BJI_Cam.CAMERAS.EXTERNAL then
        BJI_Cam.setCamera(BJI_Cam.CAMERAS.ORBIT)
    end
    guihooks.trigger('ScenarioResetTimer')
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    return Table():addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
        :addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
        :addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
        :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
        :addAll(BJI_Restrictions.OTHER.FUN_STUFF, true)
end

---@param gameVehID integer
---@param resetType string BJI_Input.INPUTS
---@return boolean
local function canReset(gameVehID, resetType)
    if S.isRaceStarted() and not S.isRaceFinished() and
        S.settings.respawnStrategy ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
        return table.includes({
            BJI_Input.INPUTS.RECOVER,
            BJI_Input.INPUTS.RECOVER_ALT,
            BJI_Input.INPUTS.RECOVER_LAST_ROAD,
            BJI_Input.INPUTS.SAVE_HOME,
            BJI_Input.INPUTS.LOAD_HOME,
            BJI_Input.INPUTS.RESET_PHYSICS,
            BJI_Input.INPUTS.RELOAD,
        }, resetType)
    end
    return false
end

---@param gameVehID integer
---@return number
local function getRewindLimit(gameVehID)
    return S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key and
        -1 or 0
end

---@param gameVehID integer
---@param resetType string BJI_Input.INPUTS
---@param baseCallback fun()
---@return boolean
local function tryReset(gameVehID, resetType, baseCallback)
    if S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key then
        if table.includes({
                BJI_Input.INPUTS.RECOVER,
                BJI_Input.INPUTS.RECOVER_ALT,
            }, resetType) then
            baseCallback()
            return true
        elseif table.includes({
                BJI_Input.INPUTS.RESET_ALL_PHYSICS,
                BJI_Input.INPUTS.RELOAD_ALL,
                BJI_Input.INPUTS.RECOVER_LAST_ROAD,
                BJI_Input.INPUTS.LOAD_HOME,
            }, resetType) then
            BJI_Input.actions.loadHome.downBaseAction()
            return true
        else
            BJI_Veh.recoverInPlace()
            return true
        end
    elseif S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key then
        local now = GetCurrentTimeMillis()
        if S.lastLaunchedCheckpoint and now - S.lastLaunchedCheckpointTime > 1000 then
            BJI_Veh.setPosRotVel(S.lastLaunchedCheckpoint)
            S.lastLaunchedCheckpointTime = now
            return true
        else
            BJI_Input.actions.loadHome.downBaseAction()
            return true
        end
    elseif S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key then
        BJI_Input.actions.loadHome.downBaseAction()
        return true
    end
    return false
end

local function getCollisionsType(ctxt)
    return BJI_Collisions.TYPES.DISABLED
end

-- player list contextual actions getter
local function getPlayerListActions(player, ctxt)
    actions = {}

    if BJI_Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

-- prepare complete race steps list
local function initSteps(steps)
    -- parse vectors data
    for _, step in ipairs(steps or {}) do
        for _, wp in ipairs(step) do
            local parsed = math.tryParsePosRot(wp)
            wp.pos = parsed.pos
            wp.rot = parsed.rot
        end
    end

    local nSteps = {}

    -- parse for each lap
    for iLap = 1, S.settings.laps or 1 do
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
    S.race.raceData.steps = nSteps
end

local function parseRaceData(steps)
    S.race.raceData.wpPerLap = #steps
    initSteps(steps)
    for iStep, step in ipairs(steps or {}) do
        for _, wp in ipairs(step) do
            if wp.stand then
                table.insert(S.race.stands, { step = iStep, pos = vec3(wp.pos), rot = quat(wp.rot) })
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
    if S.isSprint() then
        -- sprint
        S.race.leaderboard = {
            wp = 0,
            waypoints = {},
        }
    else
        -- loopable
        S.race.leaderboard = {
            laps = {},
        }
    end
end

local function updateLeaderBoard(remainingSteps, raceTime, lapTime)
    local reachedWp
    if S.isSprint() then
        -- sprint
        reachedWp = #S.race.raceData.steps - remainingSteps

        S.race.leaderboard.wp = reachedWp
        S.race.leaderboard.waypoints[reachedWp] = raceTime
    else
        -- loopable
        local remainingLaps = S.settings.laps - S.race.lap
        local remainingWpInLap = remainingSteps - (remainingLaps * S.race.raceData.wpPerLap)
        reachedWp = S.race.raceData.wpPerLap - remainingWpInLap

        if not S.race.leaderboard.laps[S.race.lap] then
            S.race.leaderboard.laps[S.race.lap] = {
                wp = reachedWp,
                time = nil,
                diff = nil,
            }
        else
            S.race.leaderboard.laps[S.race.lap].wp = reachedWp
        end
        if reachedWp == S.race.raceData.wpPerLap then
            S.race.leaderboard.laps[S.race.lap].time = lapTime
        end

        local finishedLaps = #S.race.leaderboard.laps
        while finishedLaps > 1 and not S.race.leaderboard.laps[finishedLaps].time do
            finishedLaps = finishedLaps - 1
        end
        if finishedLaps > 1 then
            local bestLap, bestLapTime = 1, S.race.leaderboard.laps[1].time
            for iLap, lap in ipairs(S.race.leaderboard.laps) do
                if lap.time then
                    if lap.time < bestLapTime then
                        bestLap = iLap
                        bestLapTime = lap.time
                    end
                    lap.diff = nil
                end
            end

            for iLap, lap in ipairs(S.race.leaderboard.laps) do
                if lap.time and iLap ~= bestLap then
                    lap.diff = lap.time - bestLapTime
                end
            end
        end
    end
end

local function onStandStop(delayMs, wp, lastWp, callback)
    local ctxt = BJI_Tick.getContext()
    S.resetLock = true
    S.dnf.standExempt = true
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)

    BJI_Message.flashCountdown("BJIRaceStand", GetCurrentTimeMillis() + delayMs, true,
        BJI_Lang.get("races.play.flashCountdownZero"))

    S.preRaceCam = BJI_Cam.getCamera()
    BJI_Cam.setCamera(BJI_Cam.CAMERAS.EXTERNAL)
    BJI_Veh.stopVehicle(ctxt.veh)
    BJI_Veh.freeze(true, ctxt.veh.gameVehicleID)
    BJI_Veh.getPositionRotation(nil, function(pos)
        S.race.lastStand = { step = lastWp.wp, pos = pos, rot = wp.rot }
        BJI_Veh.saveHome(S.race.lastStand)
    end)

    BJI_Async.delayTask(function()
        S.exemptNextReset = true
        BJI_Input.actions.loadHome.downBaseAction()
        BJI_Veh.waitForVehicleSpawn(function(ctxt2)
            BJI_Veh.freeze(true)
            if ctxt2.camera == BJI_Cam.CAMERAS.EXTERNAL then
                BJI_Cam.setCamera(S.preRaceCam)
                ctxt2.camera = BJI_Cam.getCamera()
            end
            if ctxt2.camera == BJI_Cam.CAMERAS.EXTERNAL then
                BJI_Cam.setCamera(BJI_Cam.CAMERAS.ORBIT)
                ctxt2.camera = BJI_Cam.getCamera()
            end
        end)
    end, delayMs - 3000, "BJIRaceStandReset")

    BJI_Async.delayTask(function()
        BJI_Veh.freeze(false)
        if S.settings.respawnStrategy ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
            BJI_Async.delayTask(function()
                -- delays reset restriction remove
                S.resetLock = false
                S.dnf.standExempt = false
                BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
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
    local pb = BJI_RaceWaypoint.getPB(S.raceHash)

    local diff, recordDiff
    local time = S.lapData[wp].time
    if S.isSprint() then
        if time then
            if pb then
                diff = time - pb[wp].time
            end
            if isLap and S.record then
                recordDiff = time - S.record.time
            end
        end
    else
        if pb then
            diff = time - pb[wp].time
        end
        if isLap and S.record then
            recordDiff = time - S.record.time
        end
    end
    if isLap then
        BJI_RaceUI.addHotlapRow(S.raceName, time)
    end
    BJI_RaceUI.setRaceTime(diff, recordDiff, 3000)
end

local function onCheckpointReached(wp, remainingSteps)
    local currentWaypoint = #S.race.raceData.steps - remainingSteps
    S.race.waypoint = currentWaypoint

    local lastWp = {
        lap = math.ceil(currentWaypoint / S.race.raceData.wpPerLap),
        wp = currentWaypoint % S.race.raceData.wpPerLap > 0 and
            currentWaypoint % S.race.raceData.wpPerLap or S.race.raceData.wpPerLap,
    }

    local function wpTrigger()
        local raceTime = S.race.timers.race:get()
        local lapTime = S.race.timers.lap:get()

        if not wp.stand and S.settings.respawnStrategy and
            S.settings.respawnStrategy ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
            if S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key or
                S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key then
                BJI_Veh.saveHome({ pos = wp.pos, rot = wp.rot })
                --[[BJI_Veh.getPosRotVel(nil, function(data)
                    S.lastLaunchedCheckpoint = data
                end)]]
            elseif S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key then
                -- check if current or previous stand is different than last
                ---@param stand RaceStand
                local latestStand = table.filter(S.race.stands, function(stand)
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
                    latestStand = table.reduce(S.race.stands, function(acc, stand)
                        return (not acc or stand.step > acc.step) and stand or acc
                    end)
                end
                if latestStand and latestStand.step ~= S.race.lastStand.step then
                    S.race.lastStand = latestStand
                    BJI_Veh.saveHome(latestStand)
                end
            end
        end

        local lapWaypoint = currentWaypoint % S.race.raceData.wpPerLap
        lapWaypoint = lapWaypoint > 0 and lapWaypoint or S.race.raceData.wpPerLap
        local veh = BJI_Veh.getVehicleObject()
        S.lapData[lapWaypoint] = {
            time = lapTime,
            speed = math.round((veh and tonumber(veh.speed) or 0) * 3.6, 2),
        }
        updateLeaderBoard(remainingSteps, raceTime, lapTime)

        if not S.testing then
            drawTimeDiff(wp.lap or remainingSteps == 0, lastWp.lap, lastWp.wp)
        end

        local function onLap()
            if not S.testing then
                -- send to server (time broadcasted or new record)
                BJI_Tx_scenario.RaceSoloUpdate(S.raceID, lapTime, S.settings.model)

                -- detect new pb and save it
                ---@type MapRacePBWP[]?
                local pb = BJI_RaceWaypoint.getPB(S.raceHash)
                local newPb = false
                if not pb then
                    pb = S.lapData
                    newPb = true
                else
                    local pbTime = pb[lapWaypoint] and pb[lapWaypoint].time or nil
                    if pbTime and S.lapData[lapWaypoint].time < pbTime then
                        pb = S.lapData
                        newPb = true
                    end
                end
                if newPb then
                    BJI_RaceWaypoint.setPB(S.raceHash, pb)
                    BJI_Events.trigger(BJI_Events.EVENTS.RACE_NEW_PB, {
                        raceName = S.race.raceData.name,
                        raceID = S.raceID,
                        raceHash = S.raceHash,
                        time = S.lapData[lapWaypoint].time,
                    })
                end
            end
        end

        BJI_Sound.play(BJI_Sound.SOUNDS.RACE_WAYPOINT)
        if remainingSteps == 0 then
            -- finish
            S.race.timers.lap = nil
            S.race.timers.race = nil
            S.race.timers.finalTime = lapTime

            BJI_RaceUI.setWaypoint(S.race.raceData.wpPerLap, S.race.raceData.wpPerLap)

            onLap()
        elseif wp.lap then
            -- lap
            S.race.timers.lap:reset()

            BJI_RaceUI.setWaypoint(S.race.waypoint % S.race.raceData.wpPerLap, S.race.raceData.wpPerLap)

            S.race.lap = S.race.lap + 1
            BJI_RaceUI.setLap(S.race.lap, S.settings.laps)

            local lapMessage
            if S.race.lap == S.settings.laps then
                lapMessage = BJI_Lang.get("races.play.finalLapFlash")
            else
                lapMessage = BJI_Lang.get("races.play.Lap"):var({ lap = S.race.lap })
            end
            BJI_Message.flash("BJIRaceLap", lapMessage, 5, false)

            onLap()
        else
            -- regular checkpoint
            BJI_Message.flash("BJIRaceCheckpoint", BJI.Utils.UI.RaceDelay(lapTime), 2, false)
            BJI_RaceUI.setWaypoint(S.race.waypoint % S.race.raceData.wpPerLap, S.race.raceData.wpPerLap)
        end

        if wp.lap then
            S.lapData = {}
        end
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
    end

    if wp.stand then
        onStandStop(5000, wp, lastWp, wpTrigger)
    else
        wpTrigger()
    end
end

local function stopWithLoop()
    if not BJI_Scenario.is(BJI_Scenario.TYPES.RACE_SOLO) then
        return -- skipped by user
    end

    local settings, raceData = S.baseSettings, S.baseRaceData
    local loop = not S.testing and
        BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.SCENARIO_SOLO_RACE_LOOP)
    if loop then
        S.restartRace(settings, raceData)
    else
        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
    end
end

local function onFinishReached()
    BJI_Message.flash("BJIRaceEndSelf", BJI_Lang.get("races.play.finishFlashSolo"), 3, false)
    BJI_Async.delayTask(stopWithLoop, 3000, "BJIRacePostFinish")
end

local function initWaypoints()
    BJI_RaceWaypoint.resetAll()
    for _, step in ipairs(S.race.raceData.steps) do
        BJI_RaceWaypoint.addRaceStep(step)
    end

    BJI_RaceWaypoint.setRaceWaypointHandler(onCheckpointReached)
    BJI_RaceWaypoint.setRaceFinishHandler(onFinishReached)
end

---@param ctxt TickContext?
local function isRaceStarted(ctxt)
    local now = ctxt and ctxt.now or GetCurrentTimeMillis()
    return S.race.startTime and now >= S.race.startTime
end

local function isRaceFinished()
    return not not S.race.timers.finalTime
end

local function findFreeStartPosition(startPositions)
    local currVeh = BJI_Veh.getCurrentVehicleOwn()
    if not currVeh then
        error("Current vehicle not found")
    end
    local currMargin = currVeh:getInitialWidth() / 2

    local otherVehsPositions = BJI_Veh.getMPVehicles():filter(function(v)
        return v.gameVehicleID ~= currVeh:getID()
    end):map(function(v) return v.position end)

    return math.tryParsePosRot(table.clone(#startPositions > 1 and table.find(startPositions, function(sp)
        return otherVehsPositions:every(function(vpos)
            return vpos:distance(vec3(sp.pos)) > vpos:getInitialWidth() / 2 + currMargin
        end)
    end) or startPositions[1]))
end

---@param ctxt TickContext
---@param settings table
---@param raceData table
---@param testingCallback function?
local function initRace(ctxt, settings, raceData, testingCallback)
    S.baseSettings = table.clone(settings)
    S.baseRaceData = table.clone(raceData)

    if testingCallback then
        S.testing = true
        S.testingCallback = testingCallback
    end

    BJI_Veh.deleteOtherOwnVehicles()
    S.raceVeh = ctxt.veh.gameVehicleID
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.RACE_SOLO, ctxt)
    S.settings.model = BJI_Veh.getCurrentModel()
    S.settings.laps = settings.laps
    S.settings.respawnStrategy = settings.respawnStrategy

    S.raceName = raceData.name
    S.raceID = raceData.id
    S.raceHash = raceData.hash
    S.raceAuthor = raceData.author
    S.record = raceData.record
    S.startPosition = findFreeStartPosition(raceData.startPositions)
    parseRaceData(raceData.steps)
    initLeaderboard()

    if not S.isSprint() then
        BJI_RaceUI.setLap(S.race.lap, S.settings.laps)
    end
    BJI_RaceUI.setWaypoint(S.race.waypoint, S.race.raceData.wpPerLap)

    S.preRaceCam = ctxt.camera
    BJI_Veh.saveHome({ pos = S.startPosition.pos, rot = S.startPosition.rot })
    BJI_Input.actions.loadHome.downBaseAction()
    BJI_Veh.waitForVehicleSpawn(function()
        BJI_Veh.freeze(true, ctxt.veh.gameVehicleID)
        if table.includes({
                BJI_Cam.CAMERAS.FREE,
                BJI_Cam.CAMERAS.BIG_MAP,
                BJI_Cam.CAMERAS.PASSENGER,
                BJI_Cam.CAMERAS.EXTERNAL,
            }, S.preRaceCam) then
            S.preRaceCam = BJI_Cam.CAMERAS.ORBIT
        end
        BJI_Cam.setCamera(BJI_Cam.CAMERAS.EXTERNAL)
    end)
    S.race.startTime = GetCurrentTimeMillis() + 5500
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)

    S.lapData = {}

    BJI_Message.flashCountdown("BJIRaceStart", S.race.startTime, true,
        BJI_Lang.get("races.play.flashCountdownZero"), 5, nil, true)
    initWaypoints()

    -- 3secs before start
    BJI_Async.programTask(function(ctxt2)
        if ctxt2.camera == BJI_Cam.CAMERAS.EXTERNAL then
            BJI_Cam.setCamera(S.preRaceCam)
        end
        if S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key then
            S.race.lastStand = { step = 0, pos = S.startPosition.pos, rot = S.startPosition.rot }
        end
    end, S.race.startTime - 3000, "BJIRaceStartShortCountdown")

    -- enable waypoints before start to avoid stutter
    BJI_Async.programTask(BJI_RaceWaypoint.startRace,
        S.race.startTime - 500, "BJIRaceStartWaypoints")

    -- on start
    BJI_Async.programTask(function()
        S.race.timers.race = math.timer()
        S.race.timers.lap = math.timer()
        BJI_Veh.freeze(false)
        S.resetLock = S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
        BJI_RaceUI.incrementRaceAttempts(S.raceID, S.raceHash)
    end, S.race.startTime, "BJIRaceStartTime")
end

local function restartRace(settings, raceData)
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
    BJI_Async.task(function(ctxt)
        return BJI_Context.Players[ctxt.user.playerID] and
            not BJI_Context.Players[ctxt.user.playerID].isGhost
    end, function(ctxt2)
        if BJI_Scenario.isFreeroam() and ctxt2.isOwner then
            S.initRace(BJI_Tick.getContext(), settings, raceData)
        end
    end)
end

---@return boolean
local function isSprint()
    return not S.settings.laps or S.settings.laps == 1
end

-- each frame tick hook
---@param ctxt TickContext
local function renderTick(ctxt)
    if not ctxt.isOwner then
        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
        return
    end

    -- lap realtimeDisplay
    local time = 0
    if S.race.timers.finalTime then
        time = S.race.timers.finalTime
    elseif S.race.timers.lap then
        time = S.race.timers.lap:get()
    end
    guihooks.trigger('raceTime', { time = math.round(time / 1000, 3), reverseTime = true })

    -- prevent jato usage before start
    if not S.race.startTime or ctxt.now < S.race.startTime then
        ctxt.veh.veh:queueLuaCommand("thrusters.applyVelocity(vec3(0,0,0))")
    end
end

-- each second tick hook
---@param ctxt TickContext
local function slowTick(ctxt)
    local damages = ctxt.isOwner and tonumber(ctxt.veh.veh.damageState) or nil
    if not S.isRaceStarted(ctxt) and S.startPosition and damages and
        damages > BJI_Context.VehiclePristineThreshold then
        BJI_Input.actions.loadHome.downBaseAction()
        BJI_Veh.waitForVehicleSpawn(function(ctxt2)
            BJI_Veh.freeze(true, ctxt2.veh.gameVehicleID)
        end)
    end

    -- DNF PROCESS
    if ctxt.isOwner and S.isRaceStarted(ctxt) and not S.isRaceFinished() and
        S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key and
        not S.dnf.standExempt then
        if not S.dnf.lastPos then
            -- first check
            S.dnf.lastPos = ctxt.veh.position
        else
            if math.horizontalDistance(ctxt.veh.position, S.dnf.lastPos) < S.dnf.minDistance then
                -- distance isn't enough
                if not S.dnf.process then
                    -- start countdown process
                    S.dnf.process = true
                    S.dnf.targetTime = ctxt.now + (S.dnf.timeout * 1000)
                    BJI_Message.flashCountdown("BJIRaceDNF", S.dnf.targetTime, true,
                        nil, nil, function()
                            BJI_Message.flash("BJIRaceEndSelf", BJI_Lang.get("races.play.flashDnfOut"),
                                3)
                            BJI_Async.delayTask(stopWithLoop, 3000, "BJIRaceDNFStop")
                        end)
                end
            else
                -- good distance, remove countdown if there is one
                if S.dnf.process then
                    BJI_Message.cancelFlash("BJIRaceDNF")
                    S.dnf.process = false
                    S.dnf.targetTime = nil
                end
                S.dnf.lastPos = ctxt.veh.position
            end
        end
    end

    -- RECORD UPDATE
    for _, race in ipairs(BJI_Scenario.Data.Races) do
        if race.id == S.raceID and race.record and
            (not S.record or race.record.time ~= S.record.time) then
            S.record = race.record
        end
    end
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

S.canReset = canReset
S.getRewindLimit = getRewindLimit
S.tryReset = tryReset

S.initRace = initRace
S.restartRace = restartRace

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.getCollisionsType = getCollisionsType

S.getPlayerListActions = getPlayerListActions

S.renderTick = renderTick
S.slowTick = slowTick

S.isRaceStarted = isRaceStarted
S.isRaceFinished = isRaceFinished
S.isSprint = isSprint

return S
