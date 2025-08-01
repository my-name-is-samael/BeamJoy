---@class BJIScenarioRaceMulti : BJIScenario
local S = {
    _name = "RaceMulti",
    _key = "RACE_MULTI",
    _isSolo = false,

    MINIMUM_PARTICIPANTS = 2,
    ALLOW_NODEGRABBER = false,
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
--- gc prevention
local actions, veh

local function initManagerData()
    S.state = nil
    S.exemptNextReset = false
    S.preRaceCam = nil

    S.raceName = nil
    S.raceID = nil
    S.raceHash = nil
    S.record = nil

    S.settings = {
        laps = nil,
        model = nil,
        config = nil,
        respawnStrategy = nil,
        collisions = true,
    }

    S.grid = {
        timeout = nil,
        readyTime = nil,
        previewPosition = nil,
        startPositions = {},
        participants = {},
        ready = {},
    }

    S.race = {
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
            ---@type Timer?
            race = nil,
            raceOffset = 0,
            ---@type Timer?
            lap = nil,
        },
        finished = {},
        eliminated = {},
    }

    ---@type MapRacePBWP[]
    S.lapData = {}
    S.lastLaunchedCheckpoint = nil
    S.lastLaunchedCheckpointTime = 0

    S.resetLock = true

    S.dnf.process = false -- true if countdown is launched
    S.dnf.lastPos = nil
    S.dnf.targetTime = nil
end
initManagerData()

local function stopRace()
    initManagerData()
    BJI_Cam.resetForceCamera()
    BJI_Win_VehSelector.tryClose(true)
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
end

local function isStateGridOrRace()
    return S.state and S.state <= S.STATES.RACE
end

local function isStateRaceOrFinished()
    return S.state and S.state >= S.STATES.RACE
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return true
end

---@param mpVeh BJIMPVehicle
local function hideVehicle(mpVeh)
    core_vehicle_partmgmt.setHighlightedPartsVisiblity(0, mpVeh.gameVehicleID)
    mpVeh.veh:queueLuaCommand("obj:setGhostEnabled(true)")
    BJI_Minimap.toggleVehicle({ veh = mpVeh.veh, state = false })
    BJI_Veh.toggleVehicleFocusable({ veh = mpVeh.veh, state = false })
    BJI_Veh.stopVehicle(mpVeh)
    if mpVeh.isLocal then
        BJI_Veh.freeze(true, mpVeh.gameVehicleID)
    end
end

local function revealVehicles()
    BJI_Veh.getMPVehicles(nil, true):forEach(function(mpVeh)
        core_vehicle_partmgmt.setHighlightedPartsVisiblity(1, mpVeh.gameVehicleID)
        mpVeh.veh:queueLuaCommand("obj:setGhostEnabled(false)")
        BJI_Minimap.toggleVehicle({ veh = mpVeh.veh, state = not mpVeh.isAi })
        BJI_Veh.toggleVehicleFocusable({ veh = mpVeh.veh, state = not mpVeh.isAi })
        if mpVeh.isLocal then
            BJI_Veh.freeze(false, mpVeh.gameVehicleID)
        end
    end)
end

-- load hook
---@param ctxt TickContext
local function onLoad(ctxt)
    BJI_Win_VehSelector.tryClose(true)
    if ctxt.veh then
        BJI_Veh.saveCurrentVehicle()
    end
    if table.length(ctxt.user.vehicles) > 0 then
        BJI_Veh.deleteAllOwnVehicles()
    end
    BJI_RaceWaypoint.resetAll()
    BJI_WaypointEdit.reset()
    BJI_GPS.reset()
    BJI_Cam.addRestrictedCamera(BJI_Cam.CAMERAS.BIG_MAP)
    BJI_RaceUI.clearRaceTime()
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJI_Message.cancelFlash("BJIRaceStart")
    BJI_Message.cancelFlash("BJIRaceStand")
    BJI_Message.cancelFlash("BJIRaceDNF")
    BJI_Async.removeTask("BJIRaceStart")
    BJI_Async.removeTask("BJIRacePreStart")
    BJI_Async.removeTask("BJIRacePostStart")
    BJI_Async.removeTask("BJIRaceStartShortCountdown")
    BJI_Async.removeTask("BJIRaceStartWaypoints")
    BJI_Async.removeTask("BJIRaceStartTime")
    BJI_Async.removeTask("BJIRaceMultiWaitForServerWp")
    BJI_Async.removeTask("BJIRacePostFinish")

    BJI_Veh.getMPVehicles({ isAi = false }, true):forEach(function(v)
        BJI_Minimap.toggleVehicle({ veh = v.veh, state = true })
        BJI_Veh.toggleVehicleFocusable({ veh = v.veh, state = true })
    end)
    revealVehicles()

    BJI_RaceWaypoint.resetAll()
    for _, veh in pairs(BJI_Context.User.vehicles) do
        BJI_Veh.focusVehicle(veh.gameVehID)
        BJI_Veh.freeze(false, veh.gameVehID)
        if S.preRaceCam then
            BJI_Cam.setCamera(S.preRaceCam)
        elseif ctxt.camera == BJI_Cam.CAMERAS.EXTERNAL then
            BJI_Cam.setCamera(BJI_Cam.CAMERAS.ORBIT)
        end
        break
    end
    BJI_Cam.resetRestrictedCameras()
    BJI_Win_VehSelector.tryClose(true)
    BJI_RaceUI.clear()
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    local res = Table():addAll(BJI_Restrictions.OTHER.FUN_STUFF, true)
    if S.state == S.STATES.GRID then
        res:addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
            :addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
            :addAll(BJI_Restrictions.OTHER.CAMERA_CHANGE, true)
            :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
            :addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
    elseif S.state == S.STATES.RACE then
        res:addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
        if not S.isSpec() then
            res:addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
                :addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
                :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
        end
    end
    return res
end

---@param ctxt TickContext
local function canUseNodegrabber(ctxt)
    return S.ALLOW_NODEGRABBER and (
        (ctxt.isOwner and S.isRaceStarted(ctxt)) or
        S.isRaceFinished()
    )
end

---@param gameVehID integer
---@param resetType string BJI_Input.INPUTS
---@return boolean
local function canReset(gameVehID, resetType)
    if S.isParticipant() and not S.isFinished() and
        not S.isEliminated() and S.isRaceStarted() and
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

-- player list contextual actions getter
---@param player BJIPlayer
---@param ctxt TickContext
local function getPlayerListActions(player, ctxt)
    actions = {}

    if S.state > S.STATES.GRID and S.isSpec() and not S.isSpec(player.playerID) then
        ---@type BJIMPVehicle?
        veh = BJI_Veh.getMPVehicles({ ownerID = player.playerID }, true):find(TrueFn)
        if veh then
            table.insert(actions, {
                id = string.var("focus{1}", { player.playerID }),
                icon = BJI.Utils.Icon.ICONS.visibility,
                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                disabled = ctxt.veh and ctxt.veh.gameVehicleID == veh.gameVehicleID,
                tooltip = BJI_Lang.get("common.buttons.show"),
                onClick = function()
                    BJI_Veh.focusVehicle(veh.gameVehicleID)
                end
            })
        end
    end

    if BJI_Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

local function initGrid(data)
    -- init grid data
    S.grid.timeout = BJI_Tick.applyTimeOffset(data.timeout)
    S.grid.readyTime = BJI_Tick.applyTimeOffset(data.readyTime)
    local parsed = math.tryParsePosRot(data.previewPosition)
    S.grid.previewPosition = {
        pos = parsed.pos,
        rot = parsed.rot
    }
    S.grid.startPositions = data.startPositions
    for i, sp in ipairs(S.grid.startPositions) do
        S.grid.startPositions[i] = math.tryParsePosRot(sp)
    end

    local veh = BJI_Veh.getCurrentVehicleOwn()

    S.preRaceCam = BJI_Cam.CAMERAS.ORBIT
    if veh then
        S.preRaceCam = BJI_Cam.getCamera()
        if table.includes({
                BJI_Cam.CAMERAS.FREE,
                BJI_Cam.CAMERAS.BIG_MAP,
                BJI_Cam.CAMERAS.EXTERNAL,
                BJI_Cam.CAMERAS.PASSENGER
            }, S.preRaceCam) then
            -- will preserve camera for race start (if valid camera)
            S.preRaceCam = BJI_Cam.CAMERAS.ORBIT
        end
    end

    if BJI_Win_Race.getState() then
        -- hard switch from solo race
        BJI_Win_Race.onUnload()
        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.RACE_MULTI)
        BJI_Win_Race.onLoad()
    else
        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.RACE_MULTI)
    end
    BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE)
    BJI_Cam.setPositionRotation(S.grid.previewPosition.pos, S.grid.previewPosition.rot)
end

---@param ctxt TickContext
local function postSpawn(ctxt)
    if BJI_Scenario.is(BJI_Scenario.TYPES.RACE_MULTI) and ctxt.isOwner then
        BJI_Veh.freeze(true, ctxt.veh.gameVehicleID)
        BJI_Cam.setCamera(BJI_Cam.CAMERAS.EXTERNAL)
    end
end

local function tryReplaceOrSpawn(model, config)
    if S.state == S.STATES.GRID and S.isParticipant() and not S.isReady() then
        if table.length(BJI_Context.User.vehicles) > 0 and not BJI_Veh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        local pos = table.indexOf(S.grid.participants, BJI_Context.User.playerID)
        local posrot = S.grid.startPositions[pos]
        BJI_Veh.replaceOrSpawnVehicle(model, config, posrot)
        BJI_Veh.waitForVehicleSpawn(postSpawn)
    end
end

---@param mpVeh BJIMPVehicle
local function onVehicleSpawned(mpVeh)
    if mpVeh.isLocal and S.state == S.STATES.GRID and S.isParticipant() and not S.isReady() then
        local startPos = S.grid.startPositions
            [table.indexOf(S.grid.participants, BJI_Context.User.playerID)]
        if startPos and mpVeh.position:distance(startPos.pos) > 1 then
            -- spawned via basegame vehicle selector
            BJI_Veh.setPositionRotation(startPos.pos, startPos.rot, { safe = false })
            BJI_Veh.waitForVehicleSpawn(postSpawn)
        end
    end
end

local function tryPaint(paintIndex, paint)
    local veh = BJI_Veh.getCurrentVehicleOwn()
    if veh and S.state == S.STATES.GRID and S.isParticipant() and not S.isReady() then
        BJI_Veh.paintVehicle(veh, paintIndex, paint)
    end
end

local function getModelList()
    if S.state ~= S.STATES.GRID or
        not S.isParticipant() or S.isReady() then
        return    -- veh selector should not be opened
    elseif S.settings.config then
        return {} -- only paints
    end

    local models = BJI_Veh.getAllVehicleConfigs()

    if #BJI_Context.Database.Vehicles.ModelBlacklist > 0 then
        for _, model in ipairs(BJI_Context.Database.Vehicles.ModelBlacklist) do
            models[model] = nil
        end
    end

    if S.settings.model then
        return { [S.settings.model] = models[S.settings.model] }
    end
    return models
end

local function onJoinGridParticipants()
    if S.settings.config then
        BJI_Async.task(function()
            return BJI_VehSelectorUI.stateSelector
        end, function()
            -- if forced config, then no callback from vehicle selector
            S.trySpawnNew(S.settings.model, S.settings.config)
            BJI_Win_VehSelector.open(false)
        end)
    else
        BJI_Message.flash("BJIRaceGridChooseVehicle", BJI_Lang.get("races.play.joinFlash"))
        local models = BJI_Veh.getAllVehicleConfigs()
        if S.settings.model then
            models = { [S.settings.model] = models[S.settings.model] }
        end
        BJI_Win_VehSelector.open(false)
    end
end

local function onLeaveGridParticipants()
    BJI_UI.hideGameMenu()
    BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE)
    BJI_Cam.setPositionRotation(S.grid.previewPosition.pos, S.grid.previewPosition.rot)
    BJI_Veh.deleteAllOwnVehicles()
    BJI_Win_VehSelector.tryClose(true)
end

local function onJoinGridReady()
    BJI_Win_VehSelector.tryClose(true)
end

local function specRandomRacer()
    local players = {}
    for _, playerID in ipairs(S.grid.participants) do
        if playerID ~= BJI_Context.User.playerID and
            not table.includes(S.race.eliminated, playerID) and
            not table.includes(S.race.finished, playerID) then
            table.insert(players, playerID)
        end
    end
    if #players > 0 then
        BJI_Veh.focus(table.random(players))
    end
end

local function onStandStop(delayMs, wp, lastWp, callback)
    local ctxt = BJI_Tick.getContext()
    S.resetLock = true
    S.dnf.standExempt = true
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)

    delayMs = delayMs and math.max(delayMs, 3000) or 5000
    BJI_Message.flashCountdown("BJIRaceStand", GetCurrentTimeMillis() + delayMs, true,
        BJI_Lang.get("races.play.flashCountdownZero"))

    local previousCam = BJI_Cam.getCamera()
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
                BJI_Cam.setCamera(previousCam)
                ctxt2.camera = BJI_Cam.getCamera()
            end
            if ctxt2.camera == BJI_Cam.CAMERAS.EXTERNAL then
                BJI_Cam.setCamera(BJI_Cam.CAMERAS.ORBIT)
                ctxt2.camera = BJI_Cam.getCamera()
            end
        end)
    end, delayMs - 3000, "BJIRacePreStart")

    BJI_Async.delayTask(function()
        BJI_Veh.freeze(false)
        if S.settings.respawnStrategy ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
            BJI_Async.delayTask(function()
                -- delays reset restriction remove
                S.resetLock = false
                S.dnf.standExempt = false
                BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
            end, 1000, "BJIRacePostStart")
        end
        if type(callback) == "function" then
            callback()
        end
    end, delayMs, "BJIRaceStart")
end

local function onCheckpointReached(wp, remainingSteps)
    local currentWaypoint = #S.race.raceData.steps - remainingSteps

    local lastWp = {
        lap = S.race.lap,
        wp = currentWaypoint % S.race.raceData.wpPerLap > 0 and currentWaypoint % S.race.raceData.wpPerLap or
            S.race.raceData.wpPerLap,
    }

    local function waitForServerWp(lap, waypoint, callback)
        BJI_Async.removeTask("BJIRaceMultiWaitForServerWp")
        local target
        BJI_Async.task(function()
            target = table.find(S.race.leaderboard, function(lb)
                return BJI_Context.isSelf(lb.playerID) and not lb.desync and lb.lap == lap and lb.wp == waypoint
            end)
            return not not target
        end, function() callback(target) end, "BJIRaceMultiWaitForServerWp")
    end

    local function wpTrigger()
        local previousRecordTime = S.record and S.record.time
        BJI_Tx_scenario.RaceMultiUpdate(S.CLIENT_EVENTS.CHECKPOINT_REACHED, currentWaypoint)
        S.race.waypoint = currentWaypoint

        local raceTime = S.race.timers.race:get()
        local lapTime = S.race.timers.lap:get()

        S.race.lap = lastWp.wp == S.race.raceData.wpPerLap and lastWp.lap + 1 or lastWp.lap
        S.race.waypoint = lastWp.wp % S.race.raceData.wpPerLap
        if S.race.lap > (S.settings.laps or 1) then
            -- finish case
            S.race.lap = S.settings.laps or 1
            S.race.waypoint = S.race.raceData.wpPerLap
        end

        local veh = BJI_Veh.getVehicleObject()
        S.lapData[lastWp.wp] = {
            time = lapTime,
            speed = math.round((veh and tonumber(veh.speed) or 0) * 3.6, 2),
        }

        if S.settings.laps and S.settings.laps > 1 then
            BJI_RaceUI.setLap(S.race.lap, S.settings.laps)
        end
        local drawnCheckpoint = remainingSteps == 0 and S.race.raceData.wpPerLap or
            S.race.waypoint % S.race.raceData.wpPerLap
        BJI_RaceUI.setWaypoint(drawnCheckpoint, S.race.raceData.wpPerLap)
        BJI_Sound.play(BJI_Sound.SOUNDS.RACE_WAYPOINT)

        if remainingSteps == 0 then
            S.race.timers.lap = nil
        else
            if not wp.stand and not table.includes({
                    BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key,
                    BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key
                }, S.settings.respawnStrategy) then
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

            if wp.lap then
                S.race.timers.lap:reset()

                local lapMessage
                if S.race.lap == S.settings.laps then
                    lapMessage = BJI_Lang.get("races.play.finalLapFlash")
                else
                    lapMessage = BJI_Lang.get("races.play.Lap"):var({ lap = S.race.lap })
                end
                BJI_Message.flash("BJIRaceLap", lapMessage, 5, false)
            else
                BJI_Message.flash("BJIRaceCheckpoint", BJI.Utils.UI.RaceDelay(lapTime), 2, false)
            end
        end


        -- temp leaderboard assign
        table.find(S.race.leaderboard, function(lb)
            return BJI_Context.isSelf(lb.playerID)
        end, function(lb)
            lb.desync = true
            lb.lap = S.race.lap
            lb.wp = S.race.waypoint
            lb.time = raceTime
            lb.lapTime = wp.lap and raceTime or nil
        end)
        -- temp leaderboard sort
        table.sort(S.race.leaderboard, function(a, b)
            if S.isEliminated(a.playerID) ~= S.isEliminated(b.playerID) then
                return S.isEliminated(a.playerID)
            elseif a.lap ~= b.lap then
                return a.lap > b.lap
            elseif a.wp ~= b.wp then
                return a.wp > b.wp
            else
                return a.time < b.time
            end
        end)
        -- temp print race wp times
        table.find(S.race.leaderboard, function(lb)
            return BJI_Context.isSelf(lb.playerID)
        end, function(lb, pos)
            lb.diff = pos == 1 and 0 or lb.diff
            ---@type MapRacePBWP[]?
            local pb = BJI_RaceWaypoint.getPB(S.raceHash)
            -- UI update before server data
            local diff, recordDiff
            if lb.diff ~= 0 then
                -- not first position => compare to first racer
                diff = lb.diff
            elseif pb and pb[lastWp.wp] then
                -- if first pos and pb exists => compare to pb
                diff = S.lapData[lastWp.wp].time - pb[lastWp.wp].time
            end
            if wp.lap or remainingSteps == 0 then
                if previousRecordTime then
                    -- lap / finish record diff
                    recordDiff = S.lapData[lastWp.wp].time - previousRecordTime
                end
            end
            BJI_RaceUI.setRaceTime(diff, recordDiff, 3000)
        end)

        waitForServerWp(S.race.lap, S.race.waypoint, function(lb)
            S.lapData[lastWp.wp].time = lb.time - lb.lapStartTime

            -- detect new pb
            local pb = BJI_RaceWaypoint.getPB(S.raceHash)

            if wp.lap or remainingSteps == 0 then
                -- pb process
                local newPb = false
                if not pb then
                    pb = S.lapData
                    newPb = true
                else
                    local pbTime = pb[lastWp.wp] and pb[lastWp.wp].time or nil
                    if pbTime and S.lapData[lastWp.wp].time < pbTime then
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
                        time = pb[lastWp.wp].time,
                    })
                end
            end

            -- UI update with server times
            local diff, recordDiff = nil, nil
            if lb.diff ~= 0 then
                -- not first position => compare to first racer
                diff = lb.diff
            elseif pb and pb[lastWp.wp] then
                -- if first pos and pb exists => compare to pb
                diff = S.lapData[lastWp.wp].time - pb[lastWp.wp].time
            end
            if wp.lap or remainingSteps == 0 then
                if previousRecordTime then
                    -- lap / finish record diff
                    recordDiff = S.lapData[lastWp.wp].time - previousRecordTime
                end

                BJI_RaceUI.addHotlapRow(S.raceName, S.lapData[lastWp.wp].time)
            end
            BJI_RaceUI.setRaceTime(diff, recordDiff, 3000)

            if wp.lap then
                S.lapData = {}
            end
            BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED) -- server wp reached
        end)
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)     -- local wp reached
    end

    if wp.stand then
        onStandStop(5000, wp, lastWp, wpTrigger)
    else
        wpTrigger()
    end
end

local function onFinishReached()
    BJI_Tx_scenario.RaceMultiUpdate(S.CLIENT_EVENTS.FINISH_REACHED)
    local postFinishTimeout = GetCurrentTimeMillis() + BJI_Context.BJC.Race.FinishTimeout * 1000
    BJI_Async.task(function()
        return S.isFinished() -- wait for server validating finish before showing anything
    end, function()
        local racePosition
        for i, lb in ipairs(S.race.leaderboard) do
            if BJI_Context.isSelf(lb.playerID) then
                racePosition = i
                break
            end
        end
        local isLast = racePosition == #S.race.leaderboard

        if not isLast then
            -- multiplayer and not last
            BJI_Veh.freeze(true)

            local isLappedRacer = false
            if S.settings.laps and S.settings.laps > 1 then
                for i = racePosition + 1, #S.race.leaderboard do
                    local lb = S.race.leaderboard[i]
                    if not BJI_Context.isSelf(lb.playerID) and
                        not table.includes(S.race.eliminated, lb.playerID) and
                        not table.includes(S.race.finished, lb.playerID) then
                        if lb.lap < S.settings.laps then
                            isLappedRacer = true
                            break
                        end
                    end
                end
            end

            BJI_Message.flash("BJIRaceEndSelf", BJI_Lang.get("races.play.finishFlashMulti")
                :var({ place = racePosition }), 3, false)

            BJI_Async.programTask(function()
                for _, v in ipairs(BJI_Veh.getMPOwnVehicles()) do
                    hideVehicle(v)
                    BJI_Veh.freeze(false, v.gameVehicleID)
                end
                specRandomRacer()
            end, postFinishTimeout, "BJIRacePostFinish")
        end
    end)
end

-- prepare complete race steps list
local function initSteps(steps, withLaps)
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
    for iLap = 1, withLaps and S.settings.laps or 1 do
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
    initSteps(steps, not S.isSpec())
    for iStep, step in ipairs(steps or {}) do
        for _, wp in ipairs(step) do
            if wp.stand then
                table.insert(S.race.stands, { step = iStep, pos = wp.pos, rot = wp.rot })
            end
        end
    end
end

local function initWaypoints()
    BJI_RaceWaypoint.resetAll()
    for _, step in ipairs(S.race.raceData.steps) do
        BJI_RaceWaypoint.addRaceStep(step)
    end

    BJI_RaceWaypoint.setRaceWaypointHandler(onCheckpointReached)
    BJI_RaceWaypoint.setRaceFinishHandler(onFinishReached)
end

local function showSpecWaypoints()
    BJI_RaceWaypoint.resetAll()
    Table(S.race.raceData.steps):forEach(function(step)
        Table(step):forEach(function(wp)
            local color = BJI_RaceWaypoint.COLORS.RED
            local rot = wp.rot
            if wp.stand then
                color = BJI_RaceWaypoint.COLORS.ORANGE
                rot = nil
            elseif wp.lap then
                color = BJI_RaceWaypoint.COLORS.BLUE
            end
            BJI_RaceWaypoint.addWaypoint({
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
    local ctxt = BJI_Tick.getContext()

    parseRaceData(data.steps)

    -- freshly joined players (auto spec)
    if not S.state and S.race.startTime < ctxt.now then
        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.RACE_MULTI)
        showSpecWaypoints()
        S.race.timers.race = math.timer()
        S.race.timers.raceOffset = math.round(ctxt.now - S.race.startTime)
        return
    end

    BJI_Win_VehSelector.tryClose(true)
    if S.isParticipant() then
        S.race.lap = 1
        S.race.waypoint = 0
        S.lapData = {}

        BJI_Cam.resetForceCamera()
        if S.settings.laps and S.settings.laps > 1 then
            BJI_RaceUI.setLap(S.race.lap, S.settings.laps)
        end
        BJI_RaceUI.setWaypoint(S.race.waypoint, S.race.raceData.wpPerLap)
    else
        -- spec
        if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
            if not BJI_Veh.getCurrentVehicle() then
                -- will toggle free cam automatically
                specRandomRacer()
            end
        end
    end

    if S.race.startTime > ctxt.now then
        BJI_Message.flashCountdown("BJIRaceStart", S.race.startTime, true,
            BJI_Lang.get("races.play.flashCountdownZero"), 5, nil, true)
    end

    -- 3secs before start
    if S.isParticipant() then
        BJI_Async.programTask(function()
            if S.preRaceCam then
                if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.EXTERNAL then
                    BJI_Cam.setCamera(S.preRaceCam)
                end
            end

            if S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key then
                local pos = table.indexOf(S.grid.participants, BJI_Context.User.playerID)
                local posrot = S.grid.startPositions[pos]
                S.race.lastStand = { step = 0, pos = posrot.pos, rot = posrot.rot }
            end

            BJI_Veh.saveHome()
            initWaypoints()
        end, S.race.startTime - 3000, "BJIRaceStartShortCountdown")
    end

    -- enable waypoints before start to avoid stutter
    BJI_Async.programTask(function()
        if S.isParticipant() then
            -- players
            BJI_RaceWaypoint.startRace()
        else
            -- specs
            showSpecWaypoints()
        end
    end, S.race.startTime - 500, "BJIRaceStartWaypoints")

    -- on start
    BJI_Async.programTask(function(ctxt2)
        S.race.timers.race = math.timer()
        S.race.timers.raceOffset = math.round(ctxt2.now - S.race.startTime)
        if math.abs(S.race.timers.raceOffset) < 100 then
            S.race.timers.raceOffset = 0
        end
        if S.isParticipant() then
            BJI_Veh.freeze(false)
            S.race.timers.lap = math.timer()
            S.resetLock = S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key
            BJI_RaceUI.incrementRaceAttempts(S.raceID, S.raceHash)
        end
        BJI_Restrictions.update()
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
    end, S.race.startTime, "BJIRaceStartTime")

    BJI_Veh.applyQueuedEvents()
end

local function updateRace(data, wasFinished, wasEliminated)
    if not S.isRaceFinished() and BJI_Veh.isCurrentVehicleOwn() then
        if not wasFinished and not wasEliminated and
            (S.isFinished() or S.isEliminated()) then
            S.resetLock = true
            if BJI_RaceWaypoint.isRacing() then
                BJI_RaceWaypoint.resetAll()
            end
            specRandomRacer()

            -- parse steps again on spectating switch
            parseRaceData(data.steps)
            showSpecWaypoints()
        end
    end

    ---@param v BJIMPVehicle
    BJI_Veh.getMPVehicles(nil, true):forEach(function(v)
        if S.isFinished(v.ownerID) or S.isEliminated(v.ownerID) then
            hideVehicle(v)
        end
    end)
end

local function initRaceFinish()
    S.resetLock = true
    S.state = S.STATES.FINISHED
    S.race.timers = {}
    BJI_RaceWaypoint.resetAll()

    if S.race.leaderboard[1] then
        local winner = S.race.leaderboard[1].playerID
        local target = winner and BJI_Context.Players[winner]

        if target then
            BJI_Message.flash("BJIRaceFinish",
                BJI_Lang.get("races.play.flashWinner"):var({ playerName = target.playerName }),
                5, false)
        end
    end
end

-- receive race data from backend
local function rxData(data)
    S.MINIMUM_PARTICIPANTS = data.minimumParticipants
    S.ALLOW_NODEGRABBER = data.allowNodegrabber
    if data.state then
        S.raceName = data.raceName
        S.raceID = data.raceID
        S.raceHash = data.raceHash
        S.raceAuthor = data.raceAuthor
        S.record = data.record
        -- settings
        S.settings.laps = data.laps
        S.settings.model = data.model
        S.settings.config = data.config
        S.settings.respawnStrategy = data.respawnStrategy
        S.settings.collisions = data.collisions
        -- grid
        local wasParticipant = table.includes(S.grid.participants, BJI_Context.User.playerID)
        local wasReady = table.includes(S.grid.ready, BJI_Context.User.playerID)
        S.grid.participants = data.participants
        S.grid.ready = data.ready
        -- race
        if not S.race.startTime then
            S.race.startTime = BJI_Tick.applyTimeOffset(data.startTime)
        end
        S.race.leaderboard = data.leaderboard
        local wasFinished = table.includes(S.race.finished, BJI_Context.User.playerID)
        S.race.finished = data.finished
        local wasEliminated = table.includes(S.race.eliminated, BJI_Context.User.playerID)
        S.race.eliminated = data.eliminated

        if data.state == S.STATES.GRID then
            if not S.state then
                initGrid(data)
            elseif S.state == S.STATES.GRID then
                local isParticipant = table.includes(data.participants, BJI_Context.User.playerID)
                local isReady = table.includes(data.ready, BJI_Context.User.playerID)
                if not wasParticipant and isParticipant then
                    onJoinGridParticipants()
                elseif wasParticipant and not isParticipant then
                    onLeaveGridParticipants()
                elseif not wasReady and isReady then
                    onJoinGridReady()
                end
            end
        elseif data.state == S.STATES.RACE then
            if S.state ~= S.STATES.RACE then
                initRace(data)
            elseif S.state == S.STATES.RACE then
                updateRace(data, wasFinished, wasEliminated)
            end
        elseif data.state == S.STATES.FINISHED then
            initRaceFinish()
        end
        S.state = data.state
        BJI_Restrictions.update()
    elseif S.state then
        S.stopRace()
    end
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
end

---@param playerID integer?
---@return boolean
local function isParticipant(playerID)
    playerID = playerID or BJI_Context.User.playerID
    return table.includes(S.grid.participants, playerID)
end

---@param playerID integer?
---@return boolean
local function isFinished(playerID)
    playerID = playerID or BJI_Context.User.playerID
    return table.includes(S.race.finished, playerID)
end

---@param playerID integer?
---@return boolean
local function isEliminated(playerID)
    playerID = playerID or BJI_Context.User.playerID
    return table.includes(S.race.eliminated, playerID)
end

---@param playerID integer?
---@return boolean
local function isReady(playerID)
    playerID = playerID or BJI_Context.User.playerID
    return S.isParticipant(playerID) and table.includes(S.grid.ready, playerID)
end

---@param playerID integer?
---@return boolean
local function isSpec(playerID)
    playerID = playerID or BJI_Context.User.playerID
    return isStateRaceOrFinished() and (
        not S.isParticipant(playerID) or S.isFinished(playerID) or S.isEliminated(playerID)
    )
end

---@param ctxt TickContext?
---@return boolean
local function isRaceStarted(ctxt)
    local now = ctxt and ctxt.now or GetCurrentTimeMillis()
    return isStateRaceOrFinished() and S.race.startTime ~= nil and
        now >= S.race.startTime
end

---@return boolean
local function isRaceOrCountdownStarted()
    return isStateRaceOrFinished()
end

---@return boolean
local function isRaceFinished()
    return S.state and (S.state == S.STATES.FINISHED or
        #S.grid.participants == #S.race.finished + #S.race.eliminated)
end

-- each frame tick hook
local function renderTick(ctxt)
    -- lap realtimeDisplay
    if S.isRaceOrCountdownStarted() then
        if S.isSpec() and not S.isRaceFinished() then
            local time = S.race.timers.race and S.race.timers.race:get() or 0
            if S.race.timers.raceOffset then
                time = time + S.race.timers.raceOffset
            end
            guihooks.trigger('raceTime', { time = math.round(time / 1000, 3), reverseTime = true })
        elseif S.isParticipant() and not S.isFinished() and not S.isEliminated() then
            local time = S.race.timers.lap and S.race.timers.lap:get() or 0
            guihooks.trigger('raceTime', { time = math.round(time / 1000, 3), reverseTime = true })
        elseif BJI_Message.realtimeData.context == "race" then
            guihooks.trigger('ScenarioResetTimer')
        end
    end

    if ctxt.isOwner and isStateGridOrRace() and not S.isRaceStarted(ctxt) and S.isParticipant() then
        -- prevent jato usage before start
        if not S.race.startTime or ctxt.now < S.race.startTime then
            ctxt.veh.veh:queueLuaCommand("thrusters.applyVelocity(vec3(0,0,0))")
        end
    end
end

---@param ctxt TickContext
local function fastTick(ctxt)
    if ctxt.isOwner and isStateGridOrRace() and not S.isRaceStarted(ctxt) and S.isParticipant() then
        -- fix vehicle position / damages on grid
        if not S.race.startTime or ctxt.now < S.race.startTime - 1000 then
            local startPos = S.grid.startPositions
                [table.indexOf(S.grid.participants, BJI_Context.User.playerID)]
            local moved = math.horizontalDistance(
                startPos.pos,
                ctxt.veh.position
            ) > 1
            local damaged = false
            for _, v in pairs(BJI_Context.User.vehicles) do
                local veh = BJI_Veh.getVehicleObject(v.gameVehID)
                if veh and v.gameVehID == BJI_Context.User.currentVehicle and
                    tonumber(veh.damageState) and
                    tonumber(veh.damageState) > BJI_Context.VehiclePristineThreshold then
                    damaged = true
                    break
                end
            end
            if moved or damaged then
                BJI_Veh.setPositionRotation(startPos.pos, startPos.rot, { safe = false })
                BJI_Veh.freeze(true, ctxt.veh.gameVehicleID)
            end
        end
    end
end

-- each second tick hook
---@param ctxt TickContext
local function slowTick(ctxt)
    -- DNF PROCESS
    if ctxt.isOwner and S.isRaceStarted(ctxt) and not S.isRaceFinished() and S.isParticipant() and
        S.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key and
        not S.dnf.standExempt then
        if not S.dnf.lastPos then
            -- first check
            S.dnf.lastPos = ctxt.veh.position
        else
            if S.isEliminated() or S.isFinished() then
                S.dnf.targetTime = nil
                S.dnf.process = false
            else
                if math.horizontalDistance(ctxt.veh.position, S.dnf.lastPos) < S.dnf.minDistance then
                    -- distance isn't enough
                    if not S.dnf.process then
                        S.dnf.targetTime = ctxt.now + (S.dnf.timeout * 1000)
                        -- start countdown process
                        BJI_Message.flashCountdown("BJIRaceDNF", S.dnf.targetTime, true,
                            nil, nil, function()
                                BJI_Message.flash("BJIRaceDNFReached",
                                    BJI_Lang.get("races.play.flashDnfOut"), 3)
                                BJI_Tx_scenario.RaceMultiUpdate(S.CLIENT_EVENTS.LEAVE)
                                hideVehicle(ctxt.veh)
                                BJI_RaceWaypoint.resetAll()
                                specRandomRacer()
                            end)
                        S.dnf.process = true
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
    end
end

---@return boolean
local function canSpawnNewVehicle()
    return S.state == S.STATES.GRID and S.isParticipant() and not S.isReady() and
        table.length(BJI_Context.User.vehicles) == 0
end

---@return boolean
local function canVehUpdate()
    return S.state == S.STATES.GRID and S.isParticipant() and not S.isReady() and
        BJI_Veh.isCurrentVehicleOwn() and not S.settings.config
end

---@return boolean
local function canPaintVehicle()
    if S.state ~= S.STATES.GRID or not S.isParticipant() or S.isReady() or
        not BJI_Veh.isCurrentVehicleOwn() then
        return false
    end

    return true
end

local function getCollisionsType(ctxt)
    if S.settings.collisions then
        return S.isRaceStarted(ctxt) and BJI_Collisions.TYPES.GHOSTS or BJI_Collisions.TYPES.FORCED
    end
    return BJI_Collisions.TYPES.DISABLED
end

---@param vehData { gameVehicleID: integer, ownerID: integer }
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if not S.isParticipant(vehData.ownerID) or
        S.isEliminated(vehData.ownerID) or
        S.isFinished(vehData.ownerID) then
        return false
    end

    return true, BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1), BJI.Utils.ShapeDrawer.Color(1, 1, 1, .33)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions
S.canUseNodegrabber = canUseNodegrabber

S.canReset = canReset
S.getRewindLimit = getRewindLimit
S.tryReset = tryReset

S.trySpawnNew = tryReplaceOrSpawn
S.tryReplaceOrSpawn = tryReplaceOrSpawn
S.tryPaint = tryPaint
S.getModelList = getModelList
S.getPlayerListActions = getPlayerListActions

S.renderTick = renderTick
S.fastTick = fastTick
S.slowTick = slowTick

S.rxData = rxData

S.isParticipant = isParticipant
S.isFinished = isFinished
S.isEliminated = isEliminated
S.isReady = isReady
S.isSpec = isSpec
S.isRaceStarted = isRaceStarted
S.isRaceOrCountdownStarted = isRaceOrCountdownStarted
S.isRaceFinished = isRaceFinished

S.stopRace = stopRace

S.canSpawnNewVehicle = canSpawnNewVehicle
S.canReplaceVehicle = canVehUpdate
S.canPaintVehicle = canPaintVehicle
S.getCollisionsType = getCollisionsType

S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn

S.doShowNametag = doShowNametag
S.onVehicleSpawned = onVehicleSpawned

return S
