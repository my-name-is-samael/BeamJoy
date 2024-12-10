local M = {
    STATES = {
        GRID = 1,     -- time when all players choose a vehicle
        RACE = 2,     -- time from countdown to last player finish
        FINISHED = 3, -- end of the race, flashing who won
    },
    RESPAWN_STRATEGIES = {
        NO_RESPAWN = "norespawn",
        LAST_CHECKPOINT = "lastcheckpoint",
        STAND = "stand",
    },
    CLIENT_EVENTS = {
        JOIN = "Join",                            -- grid
        READY = "Ready",                          -- grid
        LEAVE = "Leave",                          -- race
        CHECKPOINT_REACHED = "CheckpointReached", -- race
        FINISH_REACHED = "FinishReached",         -- race
    },

    testing = false,
    testingCallback = nil,

    state = nil,

    exemptNextReset = false,
    preRaceCam = nil,

    raceName = nil,
    record = nil,

    settings = {
        laps = nil,
        model = nil,
        config = nil,
        respawnStrategy = nil,
    },

    grid = {
        timeout = nil,
        readyTime = nil,
        previewPosition = nil,
        startPositions = {},
        participants = {},
        ready = {},
    },

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
            raceOffset = 0,
            lap = nil,
        },
        finished = {},
        eliminated = {},
    },

    dnf = {
        minDistance = .5,
        timeout = 10,    -- +1 during first check
        process = false, -- true if countdown is launched
        targetTime = nil,

        standExempt = false,
        lastPos = nil,
    },
}

local function stopRace()
    M.testing = false
    if type(M.testingCallback) == "function" then
        M.testingCallback()
        M.testingCallback = nil
    end

    M.state = nil
    M.exemptNextReset = false
    M.preRaceCam = nil

    M.raceName = nil
    M.record = nil

    M.settings = {
        laps = nil,
        model = nil,
        config = nil,
        respawnStrategy = nil,
    }

    M.grid = {
        timeout = nil,
        readyTime = nil,
        previewPosition = nil,
        startPositions = {},
        participants = {},
        ready = {},
    }

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
            raceOffset = 0,
            lap = nil,
        },
        finished = {},
        eliminated = {},
    }

    M.dnf = {
        minDistance = .5,
        timeout = 10,
        process = false,
        targetTime = nil,

        lastPos = nil,
    }

    BJIVehSelector.tryClose(true)
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
end

local function isStateGridOrRace()
    return M.state and M.state <= M.STATES.RACE
end

local function isStateRaceOrFinished()
    return M.state and M.state >= M.STATES.RACE
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return true
end

-- load hook
local function onLoad(ctxt)
    BJIVehSelector.tryClose(true)
    BJIVeh.saveCurrentVehicle()
    BJIVeh.deleteAllOwnVehicles()
    BJIAI.removeVehicles()
    BJIRestrictions.apply(BJIRestrictions.TYPES.ResetRace, true)
    BJIQuickTravel.toggle(false)
    BJIRaceWaypoint.resetAll()
    BJIGPS.reset()
    BJICam.addRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
    BJIRaceUI.clear()
end

-- player vehicle switch hook
local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if M.isParticipant() and not M.isSpec() then
        -- racer
        for _, v in pairs(BJIVeh.getMPOwnVehicles()) do
            BJIVeh.focusVehicle(v.gameVehicleID)
            return
        end

        -- no own veh found => eliminated
        BJITx.scenario.RaceMultiUpdate(M.CLIENT_EVENTS.LEAVE)
        return
    end

    if M.isRaceStarted() and not M.isRaceFinished() then
        -- finished or eliminated player spec switch
        local ownerID = BJIVeh.getVehOwnerID(newGameVehID)

        if tincludes(M.race.finished, ownerID, true) or
            tincludes(M.race.eliminated, ownerID, true) then
            BJIVeh.focusNextVehicle()
        end
    end
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
    BJIRaceWaypoint.resetAll()
    for _, veh in pairs(BJIContext.User.vehicles) do
        BJIVeh.focusVehicle(veh.gameVehID)
        BJIVeh.freeze(false, veh.gameVehID)
        if M.preRaceCam then
            BJICam.setCamera(M.preRaceCam)
        elseif ctxt.veh and ctxt.camera == BJICam.CAMERAS.EXTERNAL then
            ctxt.camera = BJICam.CAMERAS.ORBIT
            BJICam.setCamera(ctxt.camera)
        end
        break
    end
    BJIRestrictions.apply(BJIRestrictions.TYPES.ResetRace, false)
    BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
    BJIVehSelector.tryClose(true)
    BJIMessage.stopRealtimeDisplay()
end

local function initGrid(data)
    -- init grid data
    M.grid.timeout = BJITick.applyTimeOffset(data.timeout)
    M.grid.readyTime = BJITick.applyTimeOffset(data.readyTime)
    local parsed = TryParsePosRot(data.previewPosition)
    M.grid.previewPosition = {
        pos = parsed.pos,
        rot = parsed.rot
    }
    M.grid.startPositions = data.startPositions
    for i, sp in ipairs(M.grid.startPositions) do
        M.grid.startPositions[i] = TryParsePosRot(sp)
    end

    local veh = BJIVeh.getCurrentVehicleOwn()

    M.preRaceCam = BJICam.CAMERAS.ORBIT
    if veh then
        M.preRaceCam = BJICam.getCamera()
        if tincludes({
                BJICam.CAMERAS.FREE,
                BJICam.CAMERAS.BIG_MAP,
                BJICam.CAMERAS.EXTERNAL,
                BJICam.CAMERAS.PASSENGER
            }, M.preRaceCam) then
            -- will preserve camera for race start (if valid camera)
            M.preRaceCam = BJICam.CAMERAS.ORBIT
        end
    end

    BJIScenario.switchScenario(BJIScenario.TYPES.RACE_MULTI)
    BJICam.setCamera(BJICam.CAMERAS.FREE)
    BJICam.setPositionRotation(M.grid.previewPosition.pos, M.grid.previewPosition.rot)
end

local function tryReplaceOrSpawn(model, config)
    if M.state == M.STATES.GRID and M.isParticipant() and not M.isReady() then
        if tlength(BJIContext.User.vehicles) > 0 and not BJIVeh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        local pos = tpos(M.grid.participants, BJIContext.User.playerID)
        local posrot = M.grid.startPositions[pos]
        BJIVeh.replaceOrSpawnVehicle(model, config, posrot)
        BJIAsync.task(function(ctxt)
            return ctxt.isOwner and BJIVeh.isVehReady(ctxt.veh:getID())
        end, function()
            BJICam.setCamera(BJICam.CAMERAS.EXTERNAL)
            BJIVeh.freeze(true)
        end, "BJIRacePostSpawn")
    end
end

local function tryPaint(paint, paintNumber)
    if BJIVeh.isCurrentVehicleOwn() and
        M.state == M.STATES.GRID and M.isParticipant() and not M.isReady() then
        BJIVeh.paintVehicle(paint, paintNumber)
        BJIVeh.freeze(true)
    end
end

local function getModelList()
    if M.state ~= M.STATES.GRID or
        not M.isParticipant() or M.isReady() or M.settings.config then
        return {}
    end

    local models = BJIVeh.getAllVehicleConfigs()

    if #BJIContext.Database.Vehicles.ModelBlacklist > 0 then
        for _, model in ipairs(BJIContext.Database.Vehicles.ModelBlacklist) do
            models[model] = nil
        end
    end

    if M.settings.model then
        return { [M.settings.model] = models[M.settings.model] }
    end
    return models
end

local function onJoinGridParticipants()
    -- join participants
    if not M.testing then
        -- prepare vehicle selector
        local models = BJIVeh.getAllVehicleConfigs()
        if M.settings.model then
            models = { [M.settings.model] = models[M.settings.model] }
            if not models[M.settings.model] then
                LogError("No model available after race filter")
            else
                if M.settings.config then
                    models = {}
                end
            end
        end
        BJIVehSelector.open(models, false)
    end
    if M.settings.config then
        -- if forced config, then no callback from vehicle selector
        tryReplaceOrSpawn(M.settings.model, M.settings.config)
    else
        BJIMessage.flash("BJIRaceGridChooseVehicle", BJILang.get("races.play.joinFlash"))
    end
    BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, true)
end

local function onLeaveGridParticipants()
    BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
    BJICam.setCamera(BJICam.CAMERAS.FREE)
    BJICam.setPositionRotation(M.grid.previewPosition.pos, M.grid.previewPosition.rot)
    BJIVeh.deleteAllOwnVehicles()
    BJIVehSelector.tryClose(true)
end

local function onJoinGridReady()
    BJIVehSelector.tryClose(true)
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
                table.insert(M.race.stands, { step = iStep, pos = wp.pos, rot = wp.rot })
            end
        end
    end
end

local function specRandomRacer()
    local players = {}
    for _, playerID in ipairs(M.grid.participants) do
        if playerID ~= BJIContext.User.playerID and
            not tincludes(M.race.eliminated, playerID, true) and
            not tincludes(M.race.finished, playerID, true) then
            table.insert(players, playerID)
        end
    end
    if #players > 0 then
        BJIVeh.focus(trandom(players))
    end
end

local function updateTestingLeaderBoard(remainingSteps, raceTime, lapTime)
    local reachedWp
    if not M.settings.laps or M.settings.laps == 1 then
        -- sprint
        reachedWp = #M.race.raceData.steps - remainingSteps

        M.race.leaderboard[1].wp = reachedWp
        M.race.leaderboard[1].waypoints[reachedWp] = raceTime
    else
        -- loopable
        local remainingLaps = M.settings.laps - M.race.lap
        local remainingWp = remainingSteps - (remainingLaps * M.race.raceData.wpPerLap)
        reachedWp = M.race.raceData.wpPerLap - remainingWp

        if not M.race.leaderboard[1].laps[M.race.lap] then
            M.race.leaderboard[1].laps[M.race.lap] = {
                wp = reachedWp,
                time = nil,
                diff = nil,
            }
        else
            M.race.leaderboard[1].laps[M.race.lap].wp = reachedWp
        end
        if reachedWp == M.race.raceData.wpPerLap then
            M.race.leaderboard[1].laps[M.race.lap].time = lapTime
        end

        local finishedLaps = #M.race.leaderboard[1].laps
        while finishedLaps > 1 and not M.race.leaderboard[1].laps[finishedLaps].time do
            finishedLaps = finishedLaps - 1
        end
        if finishedLaps > 1 then
            local bestLap, bestLapTime = 1, M.race.leaderboard[1].laps[1].time
            for iLap, lap in ipairs(M.race.leaderboard[1].laps) do
                if lap.time then
                    if lap.time < bestLapTime then
                        bestLap = iLap
                        bestLapTime = lap.time
                    end
                    lap.diff = nil
                end
            end

            for iLap, lap in ipairs(M.race.leaderboard[1].laps) do
                if iLap ~= bestLap then
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
        BJIAsync.delayTask(function()
            BJIVeh.freeze(true)
        end, 100, "BJIRaceStandFreeze")
    end, delayMs - 3000, "BJIRacePreStart")

    BJIAsync.delayTask(function()
        BJIVeh.freeze(false)
        if not M.settings.respawnStrategy ~= M.RESPAWN_STRATEGIES.NO_RESPAWN then
            BJIAsync.delayTask(function()
                -- delays reset restriction remove
                BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
                M.dnf.standExempt = false
            end, 1000, "BJIRacePostStart")
        end
        if type(callback) == "function" then
            callback()
        end
    end, delayMs, "BJIRaceStart")
end

local function drawTimeDiff(lap, wp)
    BJIAsync.task(function()
        for _, lb in ipairs(M.race.leaderboard) do
            if BJIContext.isSelf(lb.playerID) then
                return lb.lap == lap and lb.wp == wp
            end
        end
        return false
    end, function()
        for _, lb in ipairs(M.race.leaderboard) do
            if BJIContext.isSelf(lb.playerID) then
                local recordDiff
                if lb.lapTime and M.record then
                    -- lap / finish
                    recordDiff = lb.lapTime - M.record.time
                    BJIRaceUI.addHotlapRow(lb.lap, lb.lapTime)
                end
                BJIRaceUI.setRaceTime(lb.diff ~= 0 and lb.diff or nil, recordDiff, 2000)
                break
            end
        end
    end, "BJIRaceUIWpDiff")
end

local function onCheckpointReached(wp, remainingSteps)
    local currentWaypoint = #M.race.raceData.steps - remainingSteps
    if not M.testing then BJITx.scenario.RaceMultiUpdate(M.CLIENT_EVENTS.CHECKPOINT_REACHED, currentWaypoint) end
    M.race.waypoint = currentWaypoint

    local function wpTrigger()
        local raceTime = M.race.timers.race:get()
        local lapTime = M.race.timers.lap:get()

        BJIRaceUI.setWaypoint(M.race.waypoint % M.race.raceData.wpPerLap, M.race.raceData.wpPerLap)

        if M.testing then
            updateTestingLeaderBoard(remainingSteps, raceTime, lapTime)
        end

        BJISound.play(BJISound.SOUNDS.RACE_WAYPOINT)
        if remainingSteps == 0 then
            -- finish
            M.race.timers.lap = nil
            if M.testing then
                M.race.timers.race = nil
            end
            if M.settings.laps and M.settings.laps > 1 then
                drawTimeDiff(M.race.lap, M.race.waypoint % M.race.raceData.wpPerLap)
            end
        else
            if M.settings.respawnStrategy == M.RESPAWN_STRATEGIES.LAST_CHECKPOINT then
                M.race.lastWaypoint = { pos = wp.pos, rot = wp.rot }
            end

            drawTimeDiff(M.race.lap, M.race.waypoint % M.race.raceData.wpPerLap)
            if wp.lap then
                -- lap
                M.race.lap = M.race.lap + 1
                M.race.timers.lap:reset()

                local lapMessage
                if M.race.lap == M.settings.laps then
                    lapMessage = BJILang.get("races.play.finalLapFlash")
                else
                    lapMessage = svar(BJILang.get("races.play.Lap"), { lap = M.race.lap })
                end
                BJIMessage.flash("BJIRaceLap", lapMessage, 5, false)
            else
                -- regular checkpoint
                BJIMessage.flash("BJIRaceCheckpoint", RaceDelay(lapTime), 2, false)
            end
        end
    end

    if wp.stand then
        onStandStop(5000, wp, wpTrigger)
    else
        wpTrigger()
    end
end

local function onFinishReached()
    if not M.testing then BJITx.scenario.RaceMultiUpdate(M.CLIENT_EVENTS.FINISH_REACHED) end

    local racePosition
    for i, lb in ipairs(M.race.leaderboard) do
        if BJIContext.isSelf(lb.playerID) then
            racePosition = i
            break
        end
    end
    local isLast = racePosition == #M.race.leaderboard

    local postFinishTimeout = BJIContext.BJC.Race.FinishTimeout * 1000
    if M.testing then
        -- solo testing
        table.insert(M.race.finished, BJIContext.User.playerID)
        BJIMessage.flash("BJIRaceEndSelf", BJILang.get("races.play.finishFlashSolo"), 3, false)
        BJIAsync.delayTask(M.stopRace, postFinishTimeout, "BJIRacePostFinish")
    elseif not isLast then
        -- multiplayer and not last
        BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, true)
        BJIVeh.freeze(true)

        local isLappedRacer = false
        if M.settings.laps and M.settings.laps > 1 then
            for i = racePosition + 1, #M.race.leaderboard do
                local lb = M.race.leaderboard[i]
                if not BJIContext.isSelf(lb.playerID) and
                    not tincludes(M.race.eliminated, lb.playerID, true) and
                    not tincludes(M.race.finished, lb.playerID, true) then
                    if lb.lap < M.settings.laps then
                        isLappedRacer = true
                        break
                    end
                end
            end
        end
        BJIMessage.flash("BJIRaceEndSelf", svar(BJILang.get("races.play.finishFlashMulti"),
            { place = racePosition }), 3, false)
        BJIAsync.delayTask(function()
            if isLappedRacer then
                BJIVeh.deleteAllOwnVehicles()
            else
                for _, v in ipairs(BJIVeh.getMPOwnVehicles()) do
                    BJIVeh.freeze(false, v.gameVehicleID)
                end
                specRandomRacer()
            end
        end, postFinishTimeout, "BJIRacePostFinish")
    end
end

local function initWaypoints()
    BJIRaceWaypoint.resetAll()
    for _, step in ipairs(M.race.raceData.steps) do
        BJIRaceWaypoint.addRaceStep(step)
    end

    BJIRaceWaypoint.setRaceWaypointHandler(onCheckpointReached)
    BJIRaceWaypoint.setRaceFinishHandler(onFinishReached)
end

local function initRace(data)
    BJIVehSelector.tryClose(true)
    if not M.isSpec() then
        parseRaceData(data.steps)
    end
    M.race.lap = 1
    M.race.waypoint = 0

    if M.settings.laps and M.settings.laps > 1 then
        BJIRaceUI.setLap(M.race.lap, M.settings.laps)
    end
    BJIRaceUI.setWaypoint(M.race.waypoint, M.race.raceData.wpPerLap)

    if M.race.startTime > GetCurrentTimeMillis() then
        BJIMessage.flashCountdown("BJIRaceStart", M.race.startTime, true,
            BJILang.get("races.play.flashCountdownZero"), 5, nil, true)
    end

    -- 3secs before start
    BJIAsync.programTask(function()
        if M.state then
            if M.isSpec() then
                -- spec
                if not BJIVeh.getCurrentVehicle() then
                    specRandomRacer()
                end
                if BJICam.getCamera() == BJICam.CAMERAS.FREE then
                    BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                end
            else
                -- participant
                if M.preRaceCam then
                    if BJICam.getCamera() == BJICam.CAMERAS.EXTERNAL then
                        BJICam.setCamera(M.preRaceCam)
                    end
                end
            end
        end
    end, M.race.startTime - 3000, "BJIRaceStartShortCountdown")

    if M.isParticipant() and M.state then
        -- players
        initWaypoints()
        -- enable waypoints before start to avoid stutter
        BJIAsync.programTask(function()
            if M.isParticipant() and M.state then
                -- players
                BJIRaceWaypoint.startRace()
            end
        end, M.race.startTime - 500, "BJIRaceStartWaypoints")
    end

    -- on start
    BJIAsync.programTask(function(ctxt)
        if M.state then
            M.race.timers.race = TimerCreate()
            M.race.timers.raceOffset = Round(ctxt.now - M.race.startTime)
            if math.abs(M.race.timers.raceOffset) < 100 then
                M.race.timers.raceOffset = 0
            end
            if not M.isSpec() then
                BJIVeh.freeze(false)
                M.race.timers.lap = TimerCreate()
                if M.settings.respawnStrategy ~= M.RESPAWN_STRATEGIES.NO_RESPAWN then
                    BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
                end
            end
        end
    end, M.race.startTime, "BJIRaceStartTime")
end

local function updateRace()
    if not M.isRaceFinished() and
        (M.isFinished() or M.isEliminated()) and
        BJIVeh.isCurrentVehicleOwn() then
        if M.isEliminated() then
            BJIVeh.deleteAllOwnVehicles()
        end
        if BJIRaceWaypoint.isRacing() then
            BJIRaceWaypoint.resetAll()
        end
        specRandomRacer()
    end
end

local function initRaceFinish()
    M.state = M.STATES.FINISHED
    M.race.timers = {}

    if M.race.leaderboard[1] then
        local winner = M.race.leaderboard[1].playerID
        local target = winner and BJIContext.Players[winner]

        if target then
            BJIMessage.flash("BJIRaceFinish",
                svar(BJILang.get("races.play.flashWinner"), { playerName = target.playerName }),
                5, false)
        end
    end
end

-- receive race data from backend
local function rxData(data)
    if data.state then
        M.raceName = data.raceName
        M.raceAuthor = data.raceAuthor
        M.record = data.record
        -- settings
        M.settings.laps = data.laps
        M.settings.model = data.model
        M.settings.config = data.config
        M.settings.respawnStrategy = data.respawnStrategy
        -- grid
        local wasParticipant = tincludes(M.grid.participants, BJIContext.User.playerID, true)
        local wasReady = tincludes(M.grid.ready, BJIContext.User.playerID, true)
        M.grid.participants = data.participants
        M.grid.ready = data.ready
        -- race
        if not M.race.startTime then
            M.race.startTime = BJITick.applyTimeOffset(data.startTime)
        end
        M.race.leaderboard = data.leaderboard
        M.race.finished = data.finished
        M.race.eliminated = data.eliminated

        if data.state == M.STATES.GRID then
            if not M.state then
                initGrid(data)
            elseif M.state == data.state then
                local isParticipant = tincludes(data.participants, BJIContext.User.playerID, true)
                local isReady = tincludes(data.ready, BJIContext.User.playerID, true)

                if not wasParticipant and isParticipant then
                    onJoinGridParticipants()
                elseif wasParticipant and not isParticipant then
                    onLeaveGridParticipants()
                elseif not wasReady and isReady then
                    onJoinGridReady()
                end
            end
        elseif data.state == M.STATES.RACE then
            if not M.state or M.state == M.STATES.GRID then
                initRace(data)
            elseif M.state >= data.state then
                updateRace()
            end
        elseif data.state == M.STATES.FINISHED then
            if M.state == M.STATES.RACE then
                initRaceFinish()
            end
        end

        M.state = data.state
    elseif M.state then
        M.stopRace()
    end
end

local function isParticipant()
    return tincludes(M.grid.participants, BJIContext.User.playerID, true)
end

local function isFinished()
    return tincludes(M.race.finished, BJIContext.User.playerID, true)
end

local function isEliminated()
    return tincludes(M.race.eliminated, BJIContext.User.playerID, true)
end

local function isReady()
    return M.isParticipant() and tincludes(M.grid.ready, BJIContext.User.playerID, true)
end

local function isSpec()
    return isStateRaceOrFinished() and (
        not M.isParticipant() or M.isFinished() or M.isEliminated()
    )
end

local function isRaceStarted(ctxt)
    local now = ctxt and ctxt.now or GetCurrentTimeMillis()
    return isStateRaceOrFinished() and M.race.startTime and now >= M.race.startTime
end

local function isRaceOrCountdownStarted()
    return isStateRaceOrFinished()
end

local function isRaceFinished()
    return M.state and (M.state == M.STATES.FINISHED or
        #M.grid.participants == #M.race.finished + #M.race.eliminated)
end

-- player vehicle reset hook
local function onVehicleResetted(gameVehID)
    if M.exemptNextReset then
        M.exemptNextReset = false
        return
    end

    if M.isRaceStarted() and M.isParticipant() and M.settings.respawnStrategy then
        local rs = M.settings.respawnStrategy
        if rs == M.RESPAWN_STRATEGIES.LAST_CHECKPOINT then
            M.exemptNextReset = true
            local wp = M.race.lastWaypoint
            if not wp then
                wp = M.grid.startPositions[tpos(M.grid.participants, BJIContext.User.playerID)]
            end
            BJIVeh.setPositionRotation(wp.pos, wp.rot)
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
            if not pastStand then
                -- no past stand then start pos
                local sp = M.grid.startPositions[tpos(M.grid.participants, BJIContext.User.playerID)]
                pastStand = {
                    pos = sp.pos,
                    rot = sp.rot,
                }
            end
            M.exemptNextReset = true
            BJIVeh.setPositionRotation(pastStand.pos, pastStand.rot)
        end
    end
end

-- each frame tick hook
local function renderTick(ctxt)
    -- lap realtimeDisplay
    if M.isRaceOrCountdownStarted() then
        if M.isSpec() and not M.isRaceFinished() then
            local time = M.race.timers.race and M.race.timers.race:get() or 0
            if M.race.timers.raceOffset then
                time = time + M.race.timers.raceOffset
            end
            BJIMessage.realtimeDisplay("race", RaceDelay(time))
        elseif M.isParticipant() and not M.isFinished() and not M.isEliminated() then
            local time = M.race.timers.lap and M.race.timers.lap:get() or 0
            BJIMessage.realtimeDisplay("race", RaceDelay(time))
        elseif BJIMessage.realtimeData.context == "race" then
            BJIMessage.stopRealtimeDisplay()
        end
    end

    if ctxt.isOwner and isStateGridOrRace() and not M.isRaceStarted(ctxt) and M.isParticipant() then
        -- fix vehicle position / damages on grid
        if not M.race.startTime or ctxt.now < M.race.startTime - 1000 then
            local startPos = M.grid.startPositions[tpos(M.grid.participants, BJIContext.User.playerID)]
            local moved = GetHorizontalDistance(
                startPos.pos,
                ctxt.vehPosRot.pos
            ) > .5
            local damaged = false
            for _, v in pairs(BJIContext.User.vehicles) do
                if v.gameVehID == BJIContext.User.currentVehicle and
                    v.damageState and
                    v.damageState > BJIContext.physics.VehiclePristineThreshold then
                    damaged = true
                    break
                end
            end
            if moved or damaged then
                BJIVeh.setPositionRotation(startPos.pos, startPos.rot)
                BJIVeh.freeze(true, ctxt.veh:getID())
            end
        end

        -- prevent jato usage before start
        if not M.race.startTime or ctxt.now < M.race.startTime then
            ctxt.veh:queueLuaCommand("thrusters.applyVelocity(vec3(0,0,0))")
        end
    end

    -- auto switch to racer
    if M.isSpec() and M.isRaceStarted(ctxt) and not M.isRaceFinished() then
        if ctxt.veh then
            local ownerID = BJIVeh.getVehOwnerID(ctxt.veh:getID())
            if tincludes(M.race.finished, ownerID, true) or
                tincludes(M.race.eliminated, ownerID, true) then
                BJIVeh.focusNextVehicle()
            end
        end
    end
end

-- each second tick hook
local function slowTick(ctxt)
    -- DNF PROCESS
    if ctxt.isOwner and M.isRaceStarted(ctxt) and not M.isRaceFinished() and M.isParticipant() and
        M.settings.respawnStrategy == M.RESPAWN_STRATEGIES.NO_RESPAWN and
        not M.dnf.standExempt then
        if not M.dnf.lastPos then
            -- first check
            M.dnf.lastPos = ctxt.vehPosRot.pos
        else
            if GetHorizontalDistance(ctxt.vehPosRot.pos, M.dnf.lastPos) < M.dnf.minDistance then
                -- distance isn't enough
                if not M.dnf.process then
                    M.dnf.targetTime = ctxt.now + (M.dnf.timeout * 1000)
                    -- start countdown process
                    BJIMessage.flashCountdown("BJIRaceDNF", M.dnf.targetTime, true,
                        BJILang.get("races.play.flashDnfOut"), nil,
                        function()
                            BJITx.scenario.RaceMultiUpdate(M.CLIENT_EVENTS.LEAVE)
                            BJIVeh.deleteCurrentOwnVehicle()
                            BJIRaceWaypoint.resetAll()
                            specRandomRacer()
                        end)
                    M.dnf.process = true
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
end

local function canVehUpdate()
    return M.state == M.STATES.GRID and M.isParticipant() and not M.isReady()
end

local function canSpawnNewVehicle()
    return canVehUpdate() and tlength(BJIContext.User.vehicles) == 0
end

local function getCollisionsType(ctxt)
    return M.isRaceStarted(ctxt) and BJICollisions.TYPES.GHOSTS or BJICollisions.TYPES.FORCED
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched

M.trySpawnNew = tryReplaceOrSpawn
M.tryReplaceOrSpawn = tryReplaceOrSpawn
M.tryPaint = tryPaint
M.getModelList = getModelList

M.getPlayerListActions = getPlayerListActions

M.renderTick = renderTick
M.slowTick = slowTick

M.onUnload = onUnload

M.rxData = rxData

M.isParticipant = isParticipant
M.isFinished = isFinished
M.isEliminated = isEliminated
M.isReady = isReady
M.isSpec = isSpec
M.isRaceStarted = isRaceStarted
M.isRaceOrCountdownStarted = isRaceOrCountdownStarted
M.isRaceFinished = isRaceFinished

M.stopRace = stopRace

M.canSelectVehicle = canVehUpdate
M.canSpawnNewVehicle = canSpawnNewVehicle
M.canReplaceVehicle = canVehUpdate
M.canDeleteVehicle = canVehUpdate
M.canDeleteOtherVehicles = function() return false end
M.canEditVehicle = function() return false end
M.getCollisionsType = getCollisionsType

return M
