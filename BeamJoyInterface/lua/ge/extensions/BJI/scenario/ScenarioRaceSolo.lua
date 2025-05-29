---@class MapRacePBWP
---@field time integer time in ms since lap start
---@field speed number speed in km/h

---@class RaceStand : BJIPositionRotation
---@field step integer

---@class BJIScenarioRaceSolo : BJIScenario
local S = {
    preRaceCam = nil,
    settings = {},
    race = {},
    dnf = {
        minDistance = .5,
        timeout = 10, -- +1 during first check
    },
}

local function initManagerData()
    S.baseSettings = nil
    S.baseRaceData = nil

    S.testing = false

    S.exemptNextReset = false

    S.raceName = nil
    S.raceHash = nil
    S.record = nil

    S.preRaceCam = nil
    S.settings = {
        raceID = nil,
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

    S.currentSpeed = 0
    ---@type MapRacePBWP[]
    S.lapData = {}

    S.dnf.process = false -- true if countdown is launched
    S.dnf.standExempt = false
    S.dnf.lastPos = nil
    S.dnf.targetTime = nil
end
initManagerData()

local function stopRace()
    if type(S.testingCallback) == "function" then
        BJI.Managers.Async.delayTask(S.testingCallback, 0, "BJIRaceTestingCallback")
        S.testingCallback = nil
    end

    initManagerData()
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return BJI.Managers.Scenario.isFreeroam() and
        ctxt.isOwner and
        not BJI.Managers.Veh.isUnicycle(ctxt.veh:getID()) and
        #BJI.Managers.Context.Scenario.Data.Races > 0
end

-- load hook
local function onLoad(ctxt)
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.ALL,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    BJI.Managers.RaceWaypoint.resetAll()
    BJI.Managers.WaypointEdit.reset()
    BJI.Managers.GPS.reset()
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
    if not S.testing then
        BJI.Tx.scenario.RaceSoloStart()
    end
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJI.Managers.Async.removeTask("BJIRaceStandReset")
    BJI.Managers.Async.removeTask("BJIRaceStandEndRestrictionReset")
    BJI.Managers.Async.removeTask("BJIRaceStandEnd")
    BJI.Managers.Async.removeTask("BJIRaceStartShortCountdown")
    BJI.Managers.Async.removeTask("BJIRaceStartWaypoints")
    BJI.Managers.Async.removeTask("BJIRaceStartTime")
    BJI.Managers.Async.removeTask("BJIRaceDNFStop")
    BJI.Managers.Async.removeTask("BJIRacePostFinish")
    BJI.Managers.Message.cancelFlash("BJIRaceStart")
    BJI.Managers.Message.cancelFlash("BJIRaceStand")
    BJI.Managers.Message.cancelFlash("BJIRaceDNF")
    BJI.Managers.Message.cancelFlash("BJIRaceEndSelf")
    if ctxt.isOwner then
        BJI.Managers.Veh.freeze(false, ctxt.veh:getID())
    end

    BJI.Managers.RaceUI.clear()
    if not S.testing then
        BJI.Tx.scenario.RaceSoloEnd(S.race.timers.finalTime ~= nil)
    end
    stopRace()
    BJI.Managers.RaceWaypoint.resetAll()
    if S.preRaceCam then
        BJI.Managers.Cam.setCamera(S.preRaceCam)
    elseif ctxt.camera == BJI.Managers.Cam.CAMERAS.EXTERNAL then
        BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.ORBIT)
    end
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.ALL,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    guihooks.trigger('ScenarioResetTimer')
end

local function getCollisionsType(ctxt)
    return BJI.Managers.Collisions.TYPES.DISABLED
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
    local previousRestrictions = BJI.Managers.Restrictions.getCurrentResets()
    BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)
    S.dnf.standExempt = true

    BJI.Managers.Message.flashCountdown("BJIRaceStand", GetCurrentTimeMillis() + delayMs, true,
        BJI.Managers.Lang.get("races.play.flashCountdownZero"))

    S.preRaceCam = BJI.Managers.Cam.getCamera()
    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
    BJI.Managers.Veh.stopCurrentVehicle()
    BJI.Managers.Veh.freeze(true)
    S.race.lastStand = { step = lastWp.wp, pos = BJI.Managers.Veh.getPositionRotation().pos, rot = wp.rot }
    BJI.Managers.Veh.saveHome(S.race.lastStand)

    BJI.Managers.Async.delayTask(function()
        S.exemptNextReset = true
        BJI.Managers.Veh.loadHome(function(ctxt)
            BJI.Managers.Veh.freeze(true)
            if ctxt.camera == BJI.Managers.Cam.CAMERAS.EXTERNAL then
                BJI.Managers.Cam.setCamera(S.preRaceCam)
                ctxt.camera = BJI.Managers.Cam.getCamera()
            end
            if ctxt.camera == BJI.Managers.Cam.CAMERAS.EXTERNAL then
                BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.ORBIT)
                ctxt.camera = BJI.Managers.Cam.getCamera()
            end
        end)
    end, delayMs - 3000, "BJIRaceStandReset")

    BJI.Managers.Async.delayTask(function()
        BJI.Managers.Veh.freeze(false)
        if S.settings.respawnStrategy ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
            BJI.Managers.Async.delayTask(function()
                -- delays reset restriction remove
                BJI.Managers.Restrictions.updateResets(previousRestrictions)
                S.dnf.standExempt = false
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
    local pb = BJI.Managers.RaceWaypoint.getPB(S.raceHash)

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
        BJI.Managers.RaceUI.addHotlapRow(S.raceName, time)
    end
    BJI.Managers.RaceUI.setRaceTime(diff, recordDiff, 3000)
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
            if S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key then
                BJI.Managers.Veh.saveHome({ pos = wp.pos, rot = wp.rot })
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
                    BJI.Managers.Veh.saveHome(latestStand)
                end
            end
        end

        local lapWaypoint = currentWaypoint % S.race.raceData.wpPerLap
        lapWaypoint = lapWaypoint > 0 and lapWaypoint or S.race.raceData.wpPerLap
        S.lapData[lapWaypoint] = {
            time = lapTime,
            speed = math.round(S.currentSpeed * 3.6, 2),
        }
        updateLeaderBoard(remainingSteps, raceTime, lapTime)

        if not S.testing then
            drawTimeDiff(wp.lap or remainingSteps == 0, lastWp.lap, lastWp.wp)
        end

        local function onLap()
            if not S.testing then
                -- send to server (time broadcasted or new record)
                BJI.Tx.scenario.RaceSoloUpdate(S.settings.raceID, lapTime, S.settings.model)

                -- detect new pb and save it
                ---@type MapRacePBWP[]?
                local pb = BJI.Managers.RaceWaypoint.getPB(S.raceHash)
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
                    BJI.Managers.RaceWaypoint.setPB(S.raceHash, pb)
                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.RACE_NEW_PB, {
                        raceName = S.race.raceData.name,
                        raceID = S.settings.raceID,
                        raceHash = S.raceHash,
                        time = S.lapData[lapWaypoint].time,
                    })
                end
            end
        end

        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.RACE_WAYPOINT)
        if remainingSteps == 0 then
            -- finish
            S.race.timers.lap = nil
            S.race.timers.race = nil
            S.race.timers.finalTime = lapTime

            BJI.Managers.RaceUI.setWaypoint(S.race.raceData.wpPerLap, S.race.raceData.wpPerLap)

            onLap()
        elseif wp.lap then
            -- lap
            S.race.timers.lap:reset()

            BJI.Managers.RaceUI.setWaypoint(S.race.waypoint % S.race.raceData.wpPerLap, S.race.raceData.wpPerLap)

            S.race.lap = S.race.lap + 1
            BJI.Managers.RaceUI.setLap(S.race.lap, S.settings.laps)

            local lapMessage
            if S.race.lap == S.settings.laps then
                lapMessage = BJI.Managers.Lang.get("races.play.finalLapFlash")
            else
                lapMessage = BJI.Managers.Lang.get("races.play.Lap"):var({ lap = S.race.lap })
            end
            BJI.Managers.Message.flash("BJIRaceLap", lapMessage, 5, false)

            onLap()
        else
            -- regular checkpoint
            BJI.Managers.Message.flash("BJIRaceCheckpoint", BJI.Utils.Common.RaceDelay(lapTime), 2, false)
            BJI.Managers.RaceUI.setWaypoint(S.race.waypoint % S.race.raceData.wpPerLap, S.race.raceData.wpPerLap)
        end

        if wp.lap then
            S.lapData = {}
        end
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
    end

    if wp.stand then
        onStandStop(5000, wp, lastWp, wpTrigger)
    else
        wpTrigger()
    end
end

local function stopWithLoop()
    if not BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_SOLO) then
        return -- skipped by user
    end

    local settings, raceData = S.baseSettings, S.baseRaceData
    local loop = not S.testing and
        BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_SOLO_RACE_LOOP)
    if loop then
        S.restartRace(settings, raceData)
    else
        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
    end
end

local function onFinishReached()
    BJI.Managers.Message.flash("BJIRaceEndSelf", BJI.Managers.Lang.get("races.play.finishFlashSolo"), 3, false)
    BJI.Managers.Async.delayTask(stopWithLoop, 3000, "BJIRacePostFinish")
end

local function initWaypoints()
    BJI.Managers.RaceWaypoint.resetAll()
    for _, step in ipairs(S.race.raceData.steps) do
        BJI.Managers.RaceWaypoint.addRaceStep(step)
    end

    BJI.Managers.RaceWaypoint.setRaceWaypointHandler(onCheckpointReached)
    BJI.Managers.RaceWaypoint.setRaceFinishHandler(onFinishReached)
end

local function isRaceStarted(ctxt)
    local now = ctxt and ctxt.now or GetCurrentTimeMillis()
    return S.race.startTime and now >= S.race.startTime
end

local function isRaceFinished()
    return not not S.race.timers.finalTime
end

local function findFreeStartPosition(startPositions)
    local vehs = BJI.Managers.Veh.getMPVehicles()
    for _, sp in ipairs(startPositions) do
        local positionFree = true
        for _, v in pairs(vehs) do
            local veh = BJI.Managers.Veh.getVehicleObject(v.gameVehicleID)
            if veh and v.gameVehicleID ~= BJI.Managers.Context.User.currentVehicle then
                local posRot = BJI.Managers.Veh.getPositionRotation(veh)
                if posRot and
                    posRot.pos:distance(vec3(sp.pos)) <= veh:getInitialWidth() / 2 then
                    positionFree = false
                    break
                end
            end
        end
        if positionFree then
            return math.tryParsePosRot(table.clone(sp))
        end
    end
    return math.tryParsePosRot(table.clone(startPositions[1]))
end

local function initRace(ctxt, settings, raceData, testingCallback)
    S.baseSettings = table.clone(settings)
    S.baseRaceData = table.clone(raceData)

    if testingCallback then
        S.testing = true
        S.testingCallback = testingCallback
    end

    BJI.Managers.Veh.deleteOtherOwnVehicles()
    S.raceVeh = ctxt.veh:getID()
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.RACE_SOLO, ctxt)
    S.settings.model = BJI.Managers.Veh.getCurrentModel()
    S.settings.laps = settings.laps
    S.settings.respawnStrategy = settings.respawnStrategy

    S.settings.raceID = raceData.id
    S.raceName = raceData.name
    S.raceHash = raceData.hash
    S.raceAuthor = raceData.author
    S.record = raceData.record
    S.startPosition = findFreeStartPosition(raceData.startPositions)
    parseRaceData(raceData.steps)
    initLeaderboard()

    if not S.isSprint() then
        BJI.Managers.RaceUI.setLap(S.race.lap, S.settings.laps)
    end
    BJI.Managers.RaceUI.setWaypoint(S.race.waypoint, S.race.raceData.wpPerLap)

    S.preRaceCam = ctxt.camera
    BJI.Managers.Veh.saveHome({ pos = S.startPosition.pos, rot = S.startPosition.rot })
    BJI.Managers.Veh.loadHome(function()
        BJI.Managers.Veh.freeze(true, ctxt.veh:getID())
        if table.includes({
                BJI.Managers.Cam.CAMERAS.FREE,
                BJI.Managers.Cam.CAMERAS.BIG_MAP,
                BJI.Managers.Cam.CAMERAS.PASSENGER,
                BJI.Managers.Cam.CAMERAS.EXTERNAL,
            }, S.preRaceCam) then
            S.preRaceCam = BJI.Managers.Cam.CAMERAS.ORBIT
        end
        BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
    end)
    S.race.startTime = GetCurrentTimeMillis() + 5500
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)

    S.lapData = {}

    BJI.Managers.Message.flashCountdown("BJIRaceStart", S.race.startTime, true,
        BJI.Managers.Lang.get("races.play.flashCountdownZero"), 5, nil, true)
    initWaypoints()

    -- 3secs before start
    BJI.Managers.Async.programTask(function(ctxt2)
        if ctxt2.camera == BJI.Managers.Cam.CAMERAS.EXTERNAL then
            BJI.Managers.Cam.setCamera(S.preRaceCam)
        end
        if S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key then
            S.race.lastStand = { step = 0, pos = S.startPosition.pos, rot = S.startPosition.rot }
        end
    end, S.race.startTime - 3000, "BJIRaceStartShortCountdown")

    -- enable waypoints before start to avoid stutter
    BJI.Managers.Async.programTask(BJI.Managers.RaceWaypoint.startRace,
        S.race.startTime - 500, "BJIRaceStartWaypoints")

    -- on start
    BJI.Managers.Async.programTask(function()
        S.race.timers.race = math.timer()
        S.race.timers.lap = math.timer()
        BJI.Managers.Veh.freeze(false)
        if S.settings.respawnStrategy ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
            local restrictions = BJI.Managers.Restrictions.RESET.ALL_BUT_LOADHOME
            if S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key then
                restrictions = Table()
                    :addAll(BJI.Managers.Restrictions.RESET.TELEPORT)
                    :addAll(BJI.Managers.Restrictions.RESET.HEAVY_RELOAD)
            end
            BJI.Managers.Restrictions.updateResets(restrictions)
        end
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
    end, S.race.startTime, "BJIRaceStartTime")
end

local function restartRace(settings, raceData)
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
    BJI.Managers.Async.task(function(ctxt)
        return Table(BJI.Managers.Context.Players):any(function(p)
            return p.playerID == ctxt.user.playerID and not p.isGhost
        end)
    end, function()
        if BJI.Managers.Scenario.isFreeroam() then
            S.initRace(BJI.Managers.Tick.getContext(), settings, raceData)
        end
    end)
end

local function isSprint()
    return not S.settings.laps or S.settings.laps == 1
end

-- each frame tick hook
local function renderTick(ctxt)
    if not ctxt.isOwner then
        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
        return
    end

    ctxt.veh:queueLuaCommand([[
        obj:queueGameEngineLua("BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_SOLO).currentSpeed = " .. obj:getAirflowSpeed())
    ]])

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
        ctxt.veh:queueLuaCommand("thrusters.applyVelocity(vec3(0,0,0))")
    end
end

-- each second tick hook
local function slowTick(ctxt)
    if not S.isRaceStarted(ctxt) and S.startPosition and ctxt.vehData and
        ctxt.vehData.damageState > BJI.Managers.Context.VehiclePristineThreshold then
        BJI.Managers.Veh.loadHome(function(ctxt2)
            BJI.Managers.Veh.freeze(true, ctxt2.veh:getID())
        end)
    end

    -- DNF PROCESS
    if ctxt.isOwner and S.isRaceStarted(ctxt) and not S.isRaceFinished() and
        S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key and
        not S.dnf.standExempt then
        if not S.dnf.lastPos then
            -- first check
            S.dnf.lastPos = ctxt.vehPosRot.pos
        else
            if math.horizontalDistance(ctxt.vehPosRot.pos, S.dnf.lastPos) < S.dnf.minDistance then
                -- distance isn't enough
                if not S.dnf.process then
                    -- start countdown process
                    S.dnf.process = true
                    S.dnf.targetTime = ctxt.now + (S.dnf.timeout * 1000)
                    BJI.Managers.Message.flashCountdown("BJIRaceDNF", S.dnf.targetTime, true,
                        BJI.Managers.Lang.get("races.play.flashDnfOut"), nil,
                        function()
                            BJI.Managers.Message.flash("BJIRaceEndSelf", BJI.Managers.Lang.get("races.play.flashDnfOut"),
                                3, false)
                            BJI.Managers.Async.delayTask(stopWithLoop, 3000, "BJIRaceDNFStop")
                        end)
                end
            else
                -- good distance, remove countdown if there is one
                if S.dnf.process then
                    BJI.Managers.Message.cancelFlash("BJIRaceDNF")
                    S.dnf.process = false
                    S.dnf.targetTime = nil
                end
                S.dnf.lastPos = ctxt.vehPosRot.pos
            end
        end
    end

    -- RECORD UPDATE
    for _, race in ipairs(BJI.Managers.Context.Scenario.Data.Races) do
        if race.id == S.settings.raceID and race.record and
            (not S.record or race.record.time ~= S.record.time) then
            S.record = race.record
        end
    end
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.initRace = initRace
S.restartRace = restartRace

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
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
