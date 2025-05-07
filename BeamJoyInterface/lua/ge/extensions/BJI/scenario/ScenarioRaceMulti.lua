local M = {
    MINIMUM_PARTICIPANTS = 2,
    STATES = {
        GRID = 1,     -- time when all players choose a vehicle
        RACE = 2,     -- time from countdown to last player finish
        FINISHED = 3, -- end of the race, flashing who won
    },
    CLIENT_EVENTS = {
        JOIN = "Join",                            -- grid
        READY = "Ready",                          -- grid
        LEAVE = "Leave",                          -- race
        CHECKPOINT_REACHED = "CheckpointReached", -- race
        FINISH_REACHED = "FinishReached",         -- race
    },

    dnf = {
        minDistance = .5,
        timeout = 10,
    },
}

local function initManagerData()
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
        ---@type RaceStand[]
        stands = {},
        lastWaypoint = nil,
        ---@type RaceStand
        lastStand = nil,
        timers = {
            race = nil,
            raceOffset = 0,
            lap = nil,
        },
        finished = {},
        eliminated = {},
    }

    M.currentSpeed = 0
    ---@type MapRacePBWP[]
    M.lapData = {}

    M.dnf.process = false -- true if countdown is launched
    M.dnf.lastPos = nil
    M.dnf.targetTime = nil
end
initManagerData()

local function stopRace()
    initManagerData()

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
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_NONE)
    BJIQuickTravel.toggle(false)
    BJIRaceWaypoint.resetAll()
    BJIWaypointEdit.reset()
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

        if table.includes(M.race.finished, ownerID) or
            table.includes(M.race.eliminated, ownerID) then
            BJIVeh.focusNextVehicle()
        end
    end
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
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_ALL)
    BJIVehSelector.tryClose(true)
    guihooks.trigger('ScenarioResetTimer')
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
        if table.includes({
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
        if table.length(BJIContext.User.vehicles) > 0 and not BJIVeh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        local pos = table.indexOf(M.grid.participants, BJIContext.User.playerID)
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

    if M.settings.config then
        -- if forced config, then no callback from vehicle selector
        tryReplaceOrSpawn(M.settings.model, M.settings.config)
    else
        BJIMessage.flash("BJIRaceGridChooseVehicle", BJILang.get("races.play.joinFlash"))
    end
end

local function onLeaveGridParticipants()
    BJICam.setCamera(BJICam.CAMERAS.FREE)
    BJICam.setPositionRotation(M.grid.previewPosition.pos, M.grid.previewPosition.rot)
    BJIVeh.deleteAllOwnVehicles()
    BJIVehSelector.tryClose(true)
end

local function onJoinGridReady()
    BJIVehSelector.tryClose(true)
end

local function specRandomRacer()
    local players = {}
    for _, playerID in ipairs(M.grid.participants) do
        if playerID ~= BJIContext.User.playerID and
            not table.includes(M.race.eliminated, playerID) and
            not table.includes(M.race.finished, playerID) then
            table.insert(players, playerID)
        end
    end
    if #players > 0 then
        BJIVeh.focus(table.random(players))
    end
end

local function onStandStop(delayMs, wp, lastWp, callback)
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_NONE)
    M.dnf.standExempt = true

    delayMs = delayMs and math.max(delayMs, 3000) or 5000
    BJIMessage.flashCountdown("BJIRaceStand", GetCurrentTimeMillis() + delayMs, true,
        BJILang.get("races.play.flashCountdownZero"))

    local previousCam = BJICam.getCamera()
    BJICam.setCamera(BJICam.CAMERAS.EXTERNAL)
    BJIVeh.stopCurrentVehicle()
    BJIVeh.freeze(true)
    M.race.lastStand = { step = lastWp.wp, pos = BJIVeh.getPositionRotation().pos, rot = wp.rot }
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
    end, delayMs - 3000, "BJIRacePreStart")

    BJIAsync.delayTask(function()
        BJIVeh.freeze(false)
        if M.settings.respawnStrategy ~= BJI_RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
            BJIAsync.delayTask(function()
                -- delays reset restriction remove
                local restrictions = BJIRestrictions.TYPES.LOAD_HOME
                if M.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key then
                    restrictions = {
                        BJIRestrictions.TYPES.RECOVER_VEHICLE,
                        BJIRestrictions.TYPES.RECOVER_VEHICLE_ALT,
                    }
                end
                BJIRestrictions.updateReset(restrictions)
                M.dnf.standExempt = false
            end, 1000, "BJIRacePostStart")
        end
        if type(callback) == "function" then
            callback()
        end
    end, delayMs, "BJIRaceStart")
end

local function onCheckpointReached(wp, remainingSteps)
    local currentWaypoint = #M.race.raceData.steps - remainingSteps

    local lastWp = {
        lap = M.race.lap,
        wp = currentWaypoint % M.race.raceData.wpPerLap > 0 and currentWaypoint % M.race.raceData.wpPerLap or
            M.race.raceData.wpPerLap,
    }

    local function waitForServerWp(lap, waypoint, callback)
        BJIAsync.removeTask("BJIRaceMultiWaitForServerWp")
        local target
        BJIAsync.task(function()
            target = table.find(M.race.leaderboard, function(lb)
                return BJIContext.isSelf(lb.playerID) and not lb.desync and lb.lap == lap and lb.wp == waypoint
            end)
            return not not target
        end, function() callback(target) end, "BJIRaceMultiWaitForServerWp")
    end

    local function wpTrigger()
        local previousRecordTime = M.record and M.record.time
        BJITx.scenario.RaceMultiUpdate(M.CLIENT_EVENTS.CHECKPOINT_REACHED, currentWaypoint)
        M.race.waypoint = currentWaypoint

        local raceTime = M.race.timers.race:get()
        local lapTime = M.race.timers.lap:get()

        M.race.lap = lastWp.wp == M.race.raceData.wpPerLap and lastWp.lap + 1 or lastWp.lap
        M.race.waypoint = lastWp.wp % M.race.raceData.wpPerLap
        if M.race.lap > (M.settings.laps or 1) then
            -- finish case
            M.race.lap = M.settings.laps or 1
            M.race.waypoint = M.race.raceData.wpPerLap
        end

        M.lapData[lastWp.wp] = {
            time = lapTime,
            speed = math.round(M.currentSpeed * 3.6, 2),
        }

        BJIRaceUI.setWaypoint(M.race.waypoint % M.race.raceData.wpPerLap, M.race.raceData.wpPerLap)
        BJISound.play(BJISound.SOUNDS.RACE_WAYPOINT)

        if remainingSteps == 0 then
            M.race.timers.lap = nil
        else
            if not wp.stand and not table.includes({
                    BJI_RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key,
                    BJI_RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key
                }, M.settings.respawnStrategy) then
                if M.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key then
                    BJIVeh.saveHome({ pos = wp.pos, rot = wp.rot })
                elseif M.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.STAND.key then
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

            if wp.lap then
                M.race.timers.lap:reset()

                local lapMessage
                if M.race.lap == M.settings.laps then
                    lapMessage = BJILang.get("races.play.finalLapFlash")
                else
                    lapMessage = BJILang.get("races.play.Lap"):var({ lap = M.race.lap })
                end
                BJIMessage.flash("BJIRaceLap", lapMessage, 5, false)
            else
                BJIMessage.flash("BJIRaceCheckpoint", RaceDelay(lapTime), 2, false)
            end
        end

        -- temp leaderboard assign
        table.find(M.race.leaderboard, function(lb)
            return BJIContext.isSelf(lb.playerID)
        end, function(lb)
            lb.desync = true
            lb.lap = M.race.lap
            lb.wp = M.race.waypoint
            lb.time = raceTime
            lb.lapTime = wp.lap and raceTime or nil
        end)

        waitForServerWp(M.race.lap, M.race.waypoint, function(lb)
            M.lapData[lastWp.wp].time = lb.wpTime

            -- detect new pb
            ---@type MapRacePBWP[]?
            local pb = BJIRaceWaypoint.getPB(M.raceHash)

            if wp.lap or remainingSteps == 0 then
                -- pb process
                local newPb = false
                if not pb then
                    pb = M.lapData
                    newPb = true
                else
                    local pbTime = pb[lastWp.wp] and pb[lastWp.wp].time or nil
                    if pbTime and M.lapData[lastWp.wp].time < pbTime then
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
                        time = M.lapData[lastWp.wp].time,
                    })
                end
            end

            -- UI update
            local diff, recordDiff
            if lb.diff ~= 0 then
                -- not first position => compare to first racer
                diff = lb.diff
            elseif pb and pb[lastWp.wp] then
                -- if first pos and pb exists => compare to pb
                diff = M.lapData[lastWp.wp].time - pb[lastWp.wp].time
            end
            if wp.lap or remainingSteps == 0 then
                if previousRecordTime then
                    -- lap / finish record diff
                    recordDiff = M.lapData[lastWp.wp].time - previousRecordTime
                end

                BJIRaceUI.addHotlapRow(M.raceName, M.lapData[lastWp.wp].time)
            end
            BJIRaceUI.setRaceTime(diff, recordDiff, 3000)

            if wp.lap then
                M.lapData = {}
            end
            BJIEvents.trigger(BJIEvents.EVENTS.SCENARIO_UPDATED) -- server wp reached
        end)
        BJIEvents.trigger(BJIEvents.EVENTS.SCENARIO_UPDATED)     -- local wp reached
    end

    if wp.stand then
        onStandStop(5000, wp, lastWp, wpTrigger)
    else
        wpTrigger()
    end
end

local function onFinishReached()
    BJITx.scenario.RaceMultiUpdate(M.CLIENT_EVENTS.FINISH_REACHED)

    local racePosition
    for i, lb in ipairs(M.race.leaderboard) do
        if BJIContext.isSelf(lb.playerID) then
            racePosition = i
            break
        end
    end
    local isLast = racePosition == #M.race.leaderboard

    local postFinishTimeout = BJIContext.BJC.Race.FinishTimeout * 1000
    if not isLast then
        -- multiplayer and not last
        BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_NONE)
        BJIVeh.freeze(true)

        local isLappedRacer = false
        if M.settings.laps and M.settings.laps > 1 then
            for i = racePosition + 1, #M.race.leaderboard do
                local lb = M.race.leaderboard[i]
                if not BJIContext.isSelf(lb.playerID) and
                    not table.includes(M.race.eliminated, lb.playerID) and
                    not table.includes(M.race.finished, lb.playerID) then
                    if lb.lap < M.settings.laps then
                        isLappedRacer = true
                        break
                    end
                end
            end
        end
        BJIMessage.flash("BJIRaceEndSelf", BJILang.get("races.play.finishFlashMulti")
            :var({ place = racePosition }), 3, false)
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

-- prepare complete race steps list
local function initSteps(steps, withLaps)
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
    for iLap = 1, withLaps and M.settings.laps or 1 do
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
    initSteps(steps, not M.isSpec())
    for iStep, step in ipairs(steps or {}) do
        for _, wp in ipairs(step) do
            if wp.stand then
                table.insert(M.race.stands, { step = iStep, pos = wp.pos, rot = wp.rot })
            end
        end
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

local function showSpecWaypoints()
    BJIRaceWaypoint.resetAll()
    Table(M.race.raceData.steps):forEach(function(step)
        Table(step):forEach(function(wp)
            local color = BJIRaceWaypoint.COLORS.RED
            local rot = wp.rot
            if wp.stand then
                color = BJIRaceWaypoint.COLORS.ORANGE
                rot = nil
            elseif wp.lap then
                color = BJIRaceWaypoint.COLORS.BLUE
            end
            BJIRaceWaypoint.addWaypoint({
                name = wp.name,
                pos = wp.pos,
                radius = wp.radius,
                rot = rot,
                color = color,
            })
        end)
    end)
end

local function initRace(data)
    BJIVehSelector.tryClose(true)
    parseRaceData(data.steps)
    M.race.lap = 1
    M.race.waypoint = 0
    M.lapData = {}

    if M.settings.laps and M.settings.laps > 1 then
        BJIRaceUI.setLap(M.race.lap, M.settings.laps)
    end
    BJIRaceUI.setWaypoint(M.race.waypoint, M.race.raceData.wpPerLap)

    if M.race.startTime > GetCurrentTimeMillis() then
        BJIMessage.flashCountdown("BJIRaceStart", M.race.startTime, true,
            BJILang.get("races.play.flashCountdownZero"), 5, nil, true)
    end

    -- 3secs before start
    BJIAsync.programTask(function(ctxt)
        if M.state then
            if M.isSpec() then
                -- spec
                if not BJIVeh.getCurrentVehicle() then
                    specRandomRacer()
                end
                if ctxt.camera == BJICam.CAMERAS.FREE then
                    BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                end
            else
                -- participant
                if M.preRaceCam then
                    if BJICam.getCamera() == BJICam.CAMERAS.EXTERNAL then
                        BJICam.setCamera(M.preRaceCam)
                    end
                end

                if M.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.STAND.key then
                    local pos = table.indexOf(M.grid.participants, BJIContext.User.playerID)
                    local posrot = M.grid.startPositions[pos]
                    M.race.lastStand = { step = 0, pos = posrot.pos, rot = posrot.rot }
                end

                BJIVeh.saveHome()
            end
        end
    end, M.race.startTime - 3000, "BJIRaceStartShortCountdown")

    if M.state then
        if M.isParticipant() then
            -- players
            initWaypoints()
            -- enable waypoints before start to avoid stutter
            BJIAsync.programTask(function()
                if M.isParticipant() and M.state then
                    -- players
                    BJIRaceWaypoint.startRace()
                end
            end, M.race.startTime - 500, "BJIRaceStartWaypoints")
        else
            showSpecWaypoints()
        end
    end

    -- on start
    BJIAsync.programTask(function(ctxt)
        if M.state then
            M.race.timers.race = TimerCreate()
            M.race.timers.raceOffset = math.round(ctxt.now - M.race.startTime)
            if math.abs(M.race.timers.raceOffset) < 100 then
                M.race.timers.raceOffset = 0
            end
            if not M.isSpec() then
                BJIVeh.freeze(false)
                M.race.timers.lap = TimerCreate()
                if M.settings.respawnStrategy ~= BJI_RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
                    local restrictions = BJIRestrictions.TYPES.LOAD_HOME
                    if M.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key then
                        restrictions = {
                            BJIRestrictions.TYPES.RECOVER_VEHICLE,
                            BJIRestrictions.TYPES.RECOVER_VEHICLE_ALT,
                        }
                    end
                    BJIRestrictions.updateReset(restrictions)
                end
            end
        end
        BJIEvents.trigger(BJIEvents.EVENTS.SCENARIO_UPDATED)
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
                BJILang.get("races.play.flashWinner"):var({ playerName = target.playerName }),
                5, false)
        end
    end
end

-- receive race data from backend
local function rxData(data)
    M.MINIMUM_PARTICIPANTS = data.minimumParticipants
    if data.state then
        M.raceName = data.raceName
        M.raceHash = data.raceHash
        M.raceAuthor = data.raceAuthor
        M.record = data.record
        -- settings
        M.settings.laps = data.laps
        M.settings.model = data.model
        M.settings.config = data.config
        M.settings.respawnStrategy = data.respawnStrategy
        -- grid
        local wasParticipant = table.includes(M.grid.participants, BJIContext.User.playerID)
        local wasReady = table.includes(M.grid.ready, BJIContext.User.playerID)
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
                local isParticipant = table.includes(data.participants, BJIContext.User.playerID)
                local isReady = table.includes(data.ready, BJIContext.User.playerID)

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
    BJIEvents.trigger(BJIEvents.EVENTS.SCENARIO_UPDATED)
end

local function isParticipant()
    return table.includes(M.grid.participants, BJIContext.User.playerID)
end

local function isFinished()
    return table.includes(M.race.finished, BJIContext.User.playerID)
end

local function isEliminated()
    return table.includes(M.race.eliminated, BJIContext.User.playerID)
end

local function isReady()
    return M.isParticipant() and table.includes(M.grid.ready, BJIContext.User.playerID)
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

-- each frame tick hook
local function renderTick(ctxt)
    if ctxt.isOwner and M.isRaceStarted(ctxt) and not M.isFinished() and not M.isEliminated() then
        ctxt.veh:queueLuaCommand([[
            obj:queueGameEngineLua("BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).currentSpeed = " .. obj:getAirflowSpeed())
        ]])
    end

    -- lap realtimeDisplay
    if M.isRaceOrCountdownStarted() then
        if M.isSpec() and not M.isRaceFinished() then
            local time = M.race.timers.race and M.race.timers.race:get() or 0
            if M.race.timers.raceOffset then
                time = time + M.race.timers.raceOffset
            end
            guihooks.trigger('raceTime', { time = math.round(time / 1000, 3), reverseTime = true })
        elseif M.isParticipant() and not M.isFinished() and not M.isEliminated() then
            local time = M.race.timers.lap and M.race.timers.lap:get() or 0
            guihooks.trigger('raceTime', { time = math.round(time / 1000, 3), reverseTime = true })
        elseif BJIMessage.realtimeData.context == "race" then
            guihooks.trigger('ScenarioResetTimer')
        end
    end

    if ctxt.isOwner and isStateGridOrRace() and not M.isRaceStarted(ctxt) and M.isParticipant() then
        -- fix vehicle position / damages on grid
        if not M.race.startTime or ctxt.now < M.race.startTime - 1000 then
            local startPos = M.grid.startPositions[table.indexOf(M.grid.participants, BJIContext.User.playerID)]
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
            if table.includes(M.race.finished, ownerID) or
                table.includes(M.race.eliminated, ownerID) then
                BJIVeh.focusNextVehicle()
            end
        end
    end
end

-- each second tick hook
local function slowTick(ctxt)
    -- DNF PROCESS
    if ctxt.isOwner and M.isRaceStarted(ctxt) and not M.isRaceFinished() and M.isParticipant() and
        M.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key and
        not M.dnf.standExempt then
        if not M.dnf.lastPos then
            -- first check
            M.dnf.lastPos = ctxt.vehPosRot.pos
        else
            if M.isEliminated() or M.isFinished() then
                M.dnf.targetTime = nil
                M.dnf.process = false
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

    if M.isSpec() then
        --displaySpecWaypoints()
    end
end

local function canVehUpdate()
    return M.state == M.STATES.GRID and M.isParticipant() and not M.isReady()
end

local function canSpawnNewVehicle()
    return canVehUpdate() and table.length(BJIContext.User.vehicles) == 0
end

local function getCollisionsType(ctxt)
    return M.isRaceStarted(ctxt) and BJICollisions.TYPES.GHOSTS or BJICollisions.TYPES.FORCED
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

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
