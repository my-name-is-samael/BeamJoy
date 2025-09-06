---@class BJIScenarioHunter : BJIScenario
local S = {
    _name = "Hunter",
    _key = "HUNTER",
    _isSolo = false,

    MINIMUM_PARTICIPANTS = 3,
    huntedResetRevealDuration = 5,
    huntedRevealProximityDistance = 50,
    huntedResetDistanceThreshold = 150,
    STATES = {
        PREPARATION = 1,
        GAME = 2,
    },
    CLIENT_EVENTS = {
        JOIN = "join",
        READY = "ready",
        LEAVE = "leave",
        CHECKPOINT_REACHED = "checkpointReached",
        ELIMINATED = "eliminated",
    },

    settings = {
        waypoints = 3,
        ---@type ClientVehicleConfig?
        huntedConfig = nil,
        ---@type ClientVehicleConfig[]
        hunterConfigs = {},
        lastWaypointGPS = false,
    },

    -- server data
    state = nil,
    ---@type tablelib<integer, BJIHunterParticipant>
    participants = {},
    preparationTimeout = nil,
    huntedStartTime = nil,
    hunterStartTime = nil,
    huntersRespawnDelay = 0,
    hunterRespawnTargetTime = nil,
    finished = false,

    -- client data
    waypoints = {},
    previousCamera = nil,
    revealHuntedProximity = false,
    revealHuntedLastWaypoint = false,
    revealHuntedReset = false,
    waypoint = 1,

    resetLock = true,
    dnf = {
        process = false,
        targetTime = nil,
        lastpos = nil,
        minDistance = .5,
        timeout = 10, -- +1 during first check
    },

    proximityProcess = {
        ---@type NGVehicle?
        huntedVeh = nil,
        ---@type NGVehicle[]
        huntersVehs = Table(),
    },

    nametagSettings = {
        fugitiveColor = BJI.Utils.ShapeDrawer.Color(1, .6, 0, 1),
        fugitiveBg = BJI.Utils.ShapeDrawer.Color(1, 1, 1, .5),
        hunterColor = BJI.Utils.ShapeDrawer.Color(1, 1, 1, 1),
        hunterBg = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5),
    },
}
--- gc prevention
local actions, target

local function stop()
    S.state = nil
    S.participants = {}
    S.preparationTimeout = nil
    S.huntedStartTime = nil
    S.hunterStartTime = nil
    S.waypoints = {}
    S.revealHuntedProximity = false
    S.revealHuntedLastWaypoint = false
    S.revealHuntedReset = false
    S.waypoint = 1
    S.resetLock = true
    S.dnf = {
        process = false,
        targetTime = nil,
        lastpos = nil,
        minDistance = .5,
        timeout = 10,
    }
    S.proximityProcess = {
        huntedVeh = nil,
        huntersVehs = Table(),
    }
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
end

-- load hook
---@param ctxt TickContext
local function onLoad(ctxt)
    BJI_Win_VehSelector.tryClose(true)
    if ctxt.isOwner then
        BJI_Veh.saveCurrentVehicle()
    end
    if not ctxt.isOwner or table.includes({
            BJI_Cam.CAMERAS.FREE,
            BJI_Cam.CAMERAS.BIG_MAP,
            BJI_Cam.CAMERAS.EXTERNAL
        }, ctxt.camera) then
        S.previousCamera = BJI_Cam.CAMERAS.ORBIT
    else
        S.previousCamera = ctxt.camera
    end
    BJI_Veh.deleteAllOwnVehicles()
    BJI_RaceWaypoint.resetAll()
    BJI_GPS.reset()
    BJI_Cam.addRestrictedCamera(BJI_Cam.CAMERAS.BIG_MAP)
end

-- unload hook
---@param ctxt TickContext
local function onUnload(ctxt)
    -- cancel message processes
    BJI_Message.cancelFlash("BJIHuntedDNF")
    BJI_Message.cancelFlash("BJIHuntedStart")
    BJI_Message.cancelFlash("BJIHunterStart")
    BJI_Message.cancelFlash("BJIHunterReset")
    BJI_Async.removeTask("BJIHunterResetCam")
    BJI_Async.removeTask("BJIHunterForcedConfigSpawn")
    BJI_Async.removeTask("BJIHuntedStartCam")
    BJI_Async.removeTask("BJIHunterStartCam")
    BJI_Async.removeTask("BJIHuntedResetReveal")

    BJI_Veh.getMPVehicles({ isAi = false }, true):forEach(function(v)
        BJI_Minimap.toggleVehicle({ veh = v.veh, state = true })
        BJI_Veh.toggleVehicleFocusable({ veh = v.veh, state = true })
    end)

    BJI_RaceWaypoint.resetAll()
    BJI_GPS.reset()
    for _, veh in pairs(ctxt.user.vehicles) do
        BJI_Veh.focusVehicle(veh.gameVehID)
        BJI_Veh.freeze(false, veh.gameVehID)
        break
    end
    BJI_Cam.resetRestrictedCameras()
    BJI_Cam.resetForceCamera(true)
    if ctxt.camera == BJI_Cam.CAMERAS.EXTERNAL then
        BJI_Cam.setCamera(S.previousCamera or BJI_Cam.CAMERAS.ORBIT)
    end
    BJI_Win_VehSelector.tryClose(true)
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    local participant = S.participants[ctxt.user.playerID]
    local res = Table():addAll(BJI_Restrictions.OTHER.FUN_STUFF, true)
    if S.state == S.STATES.PREPARATION then
        res:addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
            :addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
            :addAll(BJI_Restrictions.OTHER.CAMERA_CHANGE, true)
            :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
            :addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
    else
        if participant and not S.finished then
            res:addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
                :addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
                :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
                :addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
        end
    end
    return res
end

---@param gameVehID integer
---@param resetType string BJI_Input.INPUTS
---@return boolean
local function canReset(gameVehID, resetType)
    local ctxt = BJI_Tick.getContext()
    local participant = S.participants[ctxt.user.playerID]
    if S.state == S.STATES.GAME and participant and not S.resetLock and
        (participant.hunted and S.huntedStartTime or S.hunterStartTime) < ctxt.now then
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
    return 5
end

---@param gameVehID integer
---@param resetType string BJI_Input.INPUTS
---@param baseCallback fun()
---@return boolean
local function tryReset(gameVehID, resetType, baseCallback)
    if table.includes({
            BJI_Input.INPUTS.RECOVER,
            BJI_Input.INPUTS.RECOVER_ALT,
        }, resetType) then
        baseCallback()
        return true
    else
        BJI_Veh.recoverInPlace()
        return true
    end
end

---@param ctxt TickContext
local function postSpawn(ctxt)
    if BJI_Scenario.is(BJI_Scenario.TYPES.HUNTER) then
        BJI_Veh.freeze(true, ctxt.veh.gameVehicleID)
        BJI_Restrictions.update()
        BJI_Cam.setCamera(BJI_Cam.CAMERAS.EXTERNAL)
        if not BJI_Win_VehSelector.show then
            BJI_Win_VehSelector.open(false)
        end
    end
end

---@param model string
---@param config table
local function tryReplaceOrSpawn(model, config)
    local participant = S.participants[BJI_Context.User.playerID]
    if S.state == S.STATES.PREPARATION and participant and not participant.ready then
        if table.length(BJI_Context.User.vehicles) > 0 and not BJI_Veh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        local startPos = participant.hunted and
            BJI_Scenario.Data.HunterInfected.minorPositions[participant.startPosition] or
            BJI_Scenario.Data.HunterInfected.majorPositions[participant.startPosition]
        BJI_Cam.resetForceCamera()
        BJI_Veh.replaceOrSpawnVehicle(model, config, startPos)
        BJI_Veh.waitForVehicleSpawn(postSpawn)
    end
end

---@param mpVeh BJIMPVehicle
local function onVehicleSpawned(mpVeh)
    if not mpVeh.isLocal then
        BJI_Minimap.toggleVehicle({ veh = mpVeh.veh, state = false })
        BJI_Veh.toggleVehicleFocusable({ veh = mpVeh.veh, state = false })
    end

    local participant = S.participants[BJI_Context.User.playerID]
    if mpVeh.isLocal and S.state == S.STATES.PREPARATION and participant and not participant.ready then
        local startPos = participant.hunted and
            BJI_Scenario.Data.HunterInfected.minorPositions[participant.startPosition] or
            BJI_Scenario.Data.HunterInfected.majorPositions[participant.startPosition]
        if mpVeh.position:distance(startPos.pos) > 1 then
            BJI_Cam.resetForceCamera()
            -- spawned via basegame vehicle selector
            BJI_Veh.setPositionRotation(startPos.pos, startPos.rot, { safe = false })
            BJI_Veh.waitForVehicleSpawn(postSpawn)
        end
    end
end

---@param paintIndex integer
---@param paint NGPaint
local function tryPaint(paintIndex, paint)
    local participant = S.participants[BJI_Context.User.playerID]
    local veh = BJI_Veh.getCurrentVehicleOwn()
    if veh and S.state == S.STATES.PREPARATION and
        participant and not participant.ready then
        BJI_Veh.paintVehicle(veh, paintIndex, paint)
    end
end

---@return table<string, table>?
local function getModelList()
    local participant = S.participants[BJI_Context.User.playerID]
    if S.state ~= S.STATES.PREPARATION or not participant or participant.ready then
        return -- veh selector should not be opened
    end

    if participant.hunted and S.settings.huntedConfig then
        return {} -- only paints
    elseif not participant.hunted and #S.settings.hunterConfigs > 0 then
        return {} -- only paints
    end

    local models = BJI_Veh.getAllVehicleConfigs()
    if #BJI_Context.Database.Vehicles.ModelBlacklist > 0 then
        for _, model in ipairs(BJI_Context.Database.Vehicles.ModelBlacklist) do
            models[model] = nil
        end
    end
    return models
end

---@return boolean
local function canSpawnNewVehicle()
    local participant = S.participants[BJI_Context.User.playerID]
    return S.state == S.STATES.PREPARATION and participant and not participant.ready and
        table.length(BJI_Context.User.vehicles) == 0
end

---@return boolean
local function canVehUpdate()
    local participant = S.participants[BJI_Context.User.playerID]
    if S.state ~= S.STATES.PREPARATION or not participant or participant.ready or
        not BJI_Veh.isCurrentVehicleOwn() then
        return false
    end

    return (participant.hunted and not S.settings.huntedConfig) or
        (not participant.hunted and #S.settings.hunterConfigs ~= 1)
end

---@return boolean
local function canPaintVehicle()
    local participant = S.participants[BJI_Context.User.playerID]
    return S.state == S.STATES.PREPARATION and participant and not participant.ready and
        BJI_Veh.isCurrentVehicleOwn()
end

---@param vehData BJIMPVehicle
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if S.state == S.STATES.GAME then
        if not S.participants[BJI_Context.User.playerID] or
            not S.participants[BJI_Context.User.playerID].hunted then
            -- self spec or hunter
            if not S.participants[vehData.ownerID].hunted then
                -- show hunters
                return true, S.nametagSettings.hunterColor, S.nametagSettings.hunterBg
            end
            if S.finished or S.revealHuntedProximity or S.revealHuntedLastWaypoint or S.revealHuntedReset then
                -- finished or reveal triggered, show hunted
                return true, S.nametagSettings.fugitiveColor, S.nametagSettings.fugitiveBg
            end
        end
    end
    return false
end

---@param gameVehID integer
local function onVehicleResetted(gameVehID)
    local participant = S.participants[BJI_Context.User.playerID]
    if S.state == S.STATES.GAME and -- self hunter during game
        participant and not participant.hunted and
        S.hunterStartTime < GetCurrentTimeMillis() and
        not S.finished then
        local ownVeh = BJI_Veh.isVehicleOwn(gameVehID)
        -- respawn delay
        if ownVeh and S.huntersRespawnDelay > 0 then -- minimum stuck delay configured
            BJI_Veh.freeze(true, gameVehID)
            BJI_Cam.forceCamera(BJI_Cam.CAMERAS.EXTERNAL)
            S.hunterRespawnTargetTime = GetCurrentTimeMillis() + (S.huntersRespawnDelay * 1000) + 50
            S.resetLock = true
            BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)

            BJI_Async.programTask(function(ctxt)
                BJI_Cam.resetForceCamera(true)
            end, S.hunterRespawnTargetTime - 3000, "BJIHunterResetCam")

            BJI_Message.flashCountdown("BJIHunterReset", S.hunterRespawnTargetTime,
                false, BJI_Lang.get("hunter.play.flashHunterResume"), S.huntersRespawnDelay, function()
                    BJI_Veh.freeze(false, gameVehID)
                    S.resetLock = false
                    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
                end)
        end

        if not ownVeh and S.huntedResetRevealDuration > 0 and
            S.proximityProcess.huntedVeh and gameVehID == S.proximityProcess.huntedVeh:getID() then
            -- if fugitive respawns, reveal for few secs
            BJI_Async.removeTask("BJIHuntedResetReveal")
            S.revealHuntedReset = true
            BJI_Async.delayTask(function()
                S.revealHuntedReset = false
            end, S.huntedResetRevealDuration * 1000, "BJIHuntedResetReveal")
        end
    end
end

local function initPreparation(data)
    S.settings.waypoints = data.waypoints
    S.settings.huntedConfig = data.huntedConfig
    S.settings.hunterConfigs = data.hunterConfigs
    S.settings.lastWaypointGPS = data.lastWaypointGPS
    S.state = data.state
    S.participants = data.participants
    BJI_Cam.forceFreecamPos(BJI_Cam.getPositionRotation().pos + vec3(0, 0, 1000), quat(-1, 0, 0, 1))
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.HUNTER)
end

---@param participant BJIHunterParticipant
local function onJoinParticipants(participant)
    local ownVeh = BJI_Veh.isCurrentVehicleOwn()
    if participant.hunted then
        -- generate waypoints to reach
        ---@param pos vec3
        local function findNextWaypoint(pos)
            return Table(BJI_Scenario.Data.HunterInfected.waypoints):map(function(wp)
                return {
                    wp = {
                        pos = vec3(wp.pos),
                        radius = wp.radius,
                    },
                    distance = pos:distance(wp.pos),
                }
            end):sort(function(a, b)
                return a.distance > b.distance
            end):map(function(el)
                return el.wp
            end):filter(function(_, i)
                return i <= math.ceil(#BJI_Scenario.Data.HunterInfected.waypoints / 2)
            end):random()
        end
        local lastPos = BJI_Scenario.Data.HunterInfected.minorPositions[participant.startPosition].pos
        while #S.waypoints < S.settings.waypoints do
            if #S.waypoints > 0 then
                lastPos = S.waypoints[#S.waypoints].pos
            end
            table.insert(S.waypoints, findNextWaypoint(vec3(lastPos)))
        end
    end

    if ownVeh then
        -- already spawned (probably team switch)
        BJI_Cam.forceFreecamPos(BJI_Cam.getPositionRotation().pos + vec3(0, 0, 1000), quat(-1, 0, 0, 1))
        BJI_Veh.deleteCurrentOwnVehicle()
        BJI_Async.delayTask(function() onJoinParticipants(participant) end, 250, "BJIHunterSwitchTeam")
        return
    end

    local model, config
    if participant.hunted then
        if S.settings.huntedConfig then
            -- forced config
            model, config = S.settings.huntedConfig.model, S.settings.huntedConfig
        else
            BJI_Message.flash("BJIHunterChooseVehicle",
                BJI_Lang.get("hunter.play.flashChooseVehicle"),
                3, false)
            BJI_Win_VehSelector.open(false)
        end
    else
        -- hunter
        if #S.settings.hunterConfigs == 1 then
            -- forced config
            model, config = S.settings.hunterConfigs[1].model, S.settings.hunterConfigs[1]
        elseif #S.settings.hunterConfigs == 0 then
            BJI_Message.flash("BJIHunterChooseVehicle",
                BJI_Lang.get("hunter.play.flashChooseVehicle"),
                3, false)
            BJI_Win_VehSelector.open(false)
        end
    end
    -- forced config spawn
    if config then
        BJI_Async.task(function()
            return BJI_VehSelectorUI.stateSelector
        end, function()
            S.trySpawnNew(model, config)
        end, "BJIHunterForcedConfigSpawn")
    end
    BJI_Restrictions.update()
end

local function onLeaveParticipants()
    if S.state == S.STATES.PREPARATION then
        -- prevents from switching to another participant (spoil)
        BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE, false)
        BJI_Cam.forceFreecamPos(BJI_Cam.getPositionRotation().pos + vec3(0, 0, 1000), quat(-1, 0, 0, 1))
        BJI_Win_VehSelector.tryClose(true)
    end
    BJI_Veh.deleteAllOwnVehicles()
    BJI_Restrictions.update()
end

local function updatePreparation(data)
    local wasParticipant = S.participants[BJI_Context.User.playerID]
    local wasHunted = wasParticipant and wasParticipant.hunted or false
    S.participants = data.participants
    local participant = S.participants[BJI_Context.User.playerID]
    if not wasParticipant and participant then
        onJoinParticipants(participant)
    elseif wasParticipant and not participant then
        onLeaveParticipants()
        BJI_Win_VehSelector.tryClose(true)
        S.waypoints = {}
    elseif wasParticipant and participant and
        wasHunted ~= participant.hunted then
        -- role changed > update position
        onJoinParticipants(participant)
    end
end

local function switchToRandomHunter()
    if S.participants[BJI_Context.User.playerID] then
        return
    end

    local part
    while not part or part.hunted do
        part = table.random(S.participants)
    end
    if part then
        BJI_Veh.focus(S.participants:indexOf(part) or 0)
    end
end

local function initGameHunted(participant)
    local function updateWP()
        -- current WP
        local wp = S.waypoints[S.waypoint]
        BJI_RaceWaypoint.addWaypoint({
            name = "BJIHunter",
            pos = wp.pos,
            radius = wp.radius,
            color = BJI_RaceWaypoint.COLORS.BLUE
        })
        -- next WP
        local nextWp = S.waypoints[S.waypoint + 1]
        if nextWp then
            BJI_RaceWaypoint.addWaypoint({
                name = "BJIHunterNext",
                pos = nextWp.pos,
                radius = nextWp.radius,
                color = BJI_RaceWaypoint.COLORS.BLACK
            })
        end

        BJI_GPS.appendWaypoint({
            key = BJI_GPS.KEYS.HUNTER,
            pos = wp.pos,
            radius = wp.radius,
            clearable = false,
            callback = function()
                BJI_RaceWaypoint.resetAll()
                BJI_Tx_scenario.HunterUpdate(S.CLIENT_EVENTS.CHECKPOINT_REACHED)
                S.waypoint = S.waypoint + 1
                if S.waypoint <= #S.waypoints then
                    updateWP()
                end
            end,
        })
    end

    local function resetCamAndInitWP()
        updateWP()
        BJI_Cam.setCamera(S.previousCamera)
        if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.EXTERNAL then
            BJI_Cam.setCamera(S.previousCamera or BJI_Cam.CAMERAS.ORBIT)
        end
    end
    local function start()
        BJI_Message.flash("BJIHuntedStart", BJI_Lang.get("hunter.play.flashHuntedStart"), 5, false)
        BJI_Veh.freeze(false, participant.gameVehID)
        S.resetLock = false
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
    end

    if S.huntedStartTime > GetCurrentTimeMillis() then
        BJI_Async.programTask(resetCamAndInitWP, S.huntedStartTime - 3000, "BJIHuntedStartCam")
        BJI_Message.flashCountdown("BJIHuntedStart", S.huntedStartTime, false, nil, 5, start, true)
    else
        resetCamAndInitWP()
        start()
    end
end

local function updateProximityVehs()
    Table(S.participants):find(function(p) return p.hunted end, function(hunted)
        S.proximityProcess.huntedVeh = BJI_Veh.getVehicleObject(hunted.gameVehID)
    end)
    S.proximityProcess.huntersVehs = Table(S.participants)
        :filter(function(p) return not p.hunted end)
        :map(function(p)
            return BJI_Veh.getVehicleObject(p.gameVehID)
        end):values()
end

local function initGameHunter(participant)
    local function resetCam()
        BJI_Cam.setCamera(S.previousCamera)
        if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.EXTERNAL then
            BJI_Cam.setCamera(S.previousCamera or BJI_Cam.CAMERAS.ORBIT)
        end
    end
    local function start()
        BJI_Message.flash("BJIHunterStart", BJI_Lang.get("hunter.play.flashHunterResume"), 5, false)
        BJI_Veh.freeze(false, participant.gameVehID)
        if S.settings.lastWaypointGPS then
            Table(S.participants):find(function(p) return p.hunted end, function(hunted)
                if hunted.waypoint == S.settings.waypoints - 1 then
                    S.revealHuntedLastWaypoint = true
                end
            end)
        end
        S.resetLock = false
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
    end

    if S.hunterStartTime > GetCurrentTimeMillis() then
        BJI_Async.programTask(resetCam, S.hunterStartTime - 3000, "BJIHunterStartCam")
        BJI_Message.flashCountdown("BJIHunterStart", S.hunterStartTime, false, nil, 5, start, true)
    else
        resetCam()
        start()
    end

    -- init proximity detector vehs
    updateProximityVehs()

    ---@param v NGVehicle
    S.proximityProcess.huntersVehs:forEach(function(v)
        -- enable only hunters on minimap
        BJI_Minimap.toggleVehicle({ veh = v, state = true })
    end)
end

local function initGameSpec()
    BJI_Cam.resetForceCamera()
    if not BJI_Veh.getCurrentVehicle() then
        switchToRandomHunter()
    end
    BJI_Cam.setCamera(S.previousCamera)

    -- init proximity detector vehs
    updateProximityVehs()

    local huntedID
    Table(S.participants):find(function(p) return p.hunted end, function(hunted)
        huntedID = hunted.playerID
    end)
    ---@param v BJIMPVehicle
    BJI_Veh.getMPVehicles(nil, true):forEach(function(v)
        if v.ownerID ~= huntedID then
            BJI_Minimap.toggleVehicle({ veh = v.veh, state = true })
            BJI_Veh.toggleVehicleFocusable({ veh = v.veh, state = true })
        end
    end)
end

local function initGame(data)
    S.settings.waypoints = data.waypoints
    S.state = data.state
    S.participants = data.participants
    S.huntedStartTime = BJI_Tick.applyTimeOffset(data.huntedStartTime)
    S.hunterStartTime = BJI_Tick.applyTimeOffset(data.hunterStartTime)

    local participant = S.participants[BJI_Context.User.playerID]

    if participant then
        BJI_Win_VehSelector.tryClose(true)
        local veh = BJI_Veh.getCurrentVehicleOwn()
        if veh and tonumber(veh.damageState) and
            tonumber(veh.damageState) >= 1 then
            BJI_Veh.recoverInPlace(postSpawn)
        end
        if participant.hunted then
            initGameHunted(participant)
        else
            initGameHunter(participant)
        end
    else -- spec
        initGameSpec()
    end

    if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
        BJI_Cam.toggleFreeCam()
    end
    BJI_Restrictions.update()

    BJI_Veh.applyQueuedEvents()
end

local function updateGame(data)
    local wasParticipant = S.participants[BJI_Context.User.playerID]
    local amountParticipants = table.length(data.participants)
    S.participants = data.participants
    local participant = S.participants[BJI_Context.User.playerID]
    local wasFinished = S.finished
    S.finished = data.finished

    if wasParticipant and not participant then
        -- own vehicle deletion will trigger switch to another participant
        onLeaveParticipants()
        BJI_Restrictions.update()
    end
    if S.settings.lastWaypointGPS and not S.revealHuntedLastWaypoint then
        Table(S.participants):find(function(p) return p.hunted end, function(p)
            if p.waypoint == S.settings.waypoints - 1 then
                S.revealHuntedLastWaypoint = true
            end
        end)
    end
    if (not participant or not participant.hunted) and
        amountParticipants ~= table.length(S.participants) then
        updateProximityVehs()
    end
    if participant and not wasFinished and S.finished then
        BJI_Async.removeTask("BJIHuntedResetReveal")
        BJI_GPS.removeByKey(BJI_GPS.KEYS.PLAYER)
        ---@param p BJIHunterParticipant
        Table(S.participants):find(function(p) return p.hunted end, function(p)
            local veh = BJI_Veh.getVehicleObject(p.gameVehID)
            if veh then
                BJI_Veh.toggleVehicleFocusable({ veh = veh, state = true })
                veh.uiState = 1
            end
        end)
        BJI_Restrictions.update()
    end
end

-- receive hunter data from backend
local function rxData(data)
    -- constants
    S.MINIMUM_PARTICIPANTS = data.minimumParticipants
    S.huntersRespawnDelay = data.huntersRespawnDelay
    S.huntedResetRevealDuration = data.huntedResetRevealDuration
    S.huntedRevealProximityDistance = data.huntedRevealProximityDistance
    S.huntedResetDistanceThreshold = data.huntedResetDistanceThreshold

    if data.state == S.STATES.PREPARATION then
        S.preparationTimeout = BJI_Tick.applyTimeOffset(data.preparationTimeout)
        if not S.state then
            initPreparation(data)
        else
            updatePreparation(data)
        end
    elseif data.state == S.STATES.GAME then
        if S.state ~= S.STATES.GAME then
            initGame(data)
            BJI_Restrictions.update()
        else
            updateGame(data)
        end
    elseif S.state then
        S.stop()
    end
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
end

-- player list contextual actions getter
---@param player BJIPlayer
---@param ctxt TickContext
local function getPlayerListActions(player, ctxt)
    actions = {}

    if BJI_Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

-- check for close hunters to prevent hunted from respawning<br/>
-- check for movement when DNF process is active<br/>
-- check for revealing hunted position to hunters
---@param ctxt TickContext
local function fastTick(ctxt)
    local participant = S.participants[BJI_Context.User.playerID]
    if S.state == S.STATES.GAME then
        if participant and participant.hunted then -- check for hunted DNF / reset lock
            if S.huntedResetDistanceThreshold > 0 and
                S.huntedStartTime and S.huntedStartTime <= ctxt.now then
                -- respawn rest update
                local closeHunter = Table(S.participants)
                    :filter(function(_, playerID) return playerID ~= ctxt.user.playerID end)
                    :map(function(p) return BJI_Veh.getVehicleObject(p.gameVehID) end)
                    :map(function(veh) return BJI_Veh.getPositionRotation(veh) end)
                    :map(function(pos) return ctxt.veh.position:distance(pos) end)
                    :any(function(d) return d < S.huntedResetDistanceThreshold end)
                if closeHunter and not S.resetLock then
                    S.resetLock = true
                    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
                elseif not closeHunter and S.resetLock then
                    S.resetLock = false
                    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
                end

                -- DNF disabling update
                if S.dnf.lastpos and S.dnf.process then
                    if S.finished or math.horizontalDistance(S.dnf.lastpos, ctxt.veh.position) > S.dnf.minDistance then
                        BJI_Message.cancelFlash("BJIHuntedDNF")
                        S.dnf.process = false
                        S.dnf.targetTime = nil
                    end
                end
            elseif S.huntedResetDistanceThreshold == 0 and not S.resetLock then
                S.resetLock = true
                BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
            end
        end

        if (not participant or not participant.hunted) then -- fugitive reveal/hide
            -- spec or hunter
            if not S.finished then
                if S.hunterStartTime and S.hunterStartTime <= ctxt.now then
                    -- proximity reveal update
                    if S.huntedRevealProximityDistance > 0 and
                        S.proximityProcess.huntedVeh and
                        #S.proximityProcess.huntersVehs > 0 then
                        Table(S.participants):find(function(p) return p.hunted end,
                            function(hunted)
                                if not S.settings.lastWaypointGPS or hunted.waypoint < S.settings.waypoints - 1 then
                                    local huntedPos = BJI_Veh.getPositionRotation(S.proximityProcess.huntedVeh)
                                    local hunterPos
                                    local minDistance = S.proximityProcess.huntersVehs:map(function(hunter)
                                        hunterPos = BJI_Veh.getPositionRotation(hunter)
                                        return (hunterPos and huntedPos) and hunterPos:distance(huntedPos) or nil
                                    end):reduce(function(acc, d) return (not acc or d < acc) and d or acc end)
                                    if S.revealHuntedProximity and minDistance > S.huntedRevealProximityDistance then
                                        S.revealHuntedProximity = false
                                    elseif not S.revealHuntedProximity and minDistance <= S.huntedRevealProximityDistance then
                                        S.revealHuntedProximity = true
                                    end
                                end
                            end)
                    end

                    -- update reveal state
                    local reveal = S.revealHuntedProximity or S.revealHuntedLastWaypoint or S.revealHuntedReset
                    if reveal and not BJI_GPS.getByKey(BJI_GPS.KEYS.PLAYER) then
                        Table(S.participants):find(function(p) return p.hunted end, function(_, huntedID)
                            BJI_GPS.appendWaypoint({
                                key = BJI_GPS.KEYS.PLAYER,
                                radius = .1,
                                playerName = ctxt.players[huntedID].playerName,
                                clearable = false
                            })
                            local veh = BJI_Veh.getVehicleObject(ctxt.players[huntedID].currentVehicle)
                            if veh then veh.uiState = 1 end
                        end)
                    elseif not reveal and BJI_GPS.getByKey(BJI_GPS.KEYS.PLAYER) then
                        BJI_GPS.removeByKey(BJI_GPS.KEYS.PLAYER)
                        Table(S.participants):find(function(p) return p.hunted end, function(_, huntedID)
                            local veh = BJI_Veh.getVehicleObject(ctxt.players[huntedID].currentVehicle)
                            if veh then veh.uiState = 0 end
                        end)
                    end
                end
            end
        end
    end
end

-- check for DNF process activation
---@param ctxt TickContext
local function slowTick(ctxt)
    local participant = S.participants[BJI_Context.User.playerID]

    if ctxt.isOwner and S.state == S.STATES.GAME and participant then
        if participant.hunted and S.huntedStartTime and S.huntedStartTime <= ctxt.now then
            -- DNF check
            if not S.finished and S.dnf.lastpos and not S.dnf.process then
                local distance = math.horizontalDistance(S.dnf.lastpos, ctxt.veh.position)
                if distance < S.dnf.minDistance then
                    -- start countdown process
                    if not S.dnf.process then
                        S.dnf.targetTime = ctxt.now + (S.dnf.timeout * 1000)
                        BJI_Message.flashCountdown("BJIHuntedDNF",
                            S.dnf.targetTime,
                            true, "", 10, function()
                                BJI_Cam.removeRestrictedCamera(BJI_Cam.CAMERAS.FREE)
                                BJI_Tx_scenario.HunterUpdate(S.CLIENT_EVENTS.ELIMINATED)
                                BJI_Tx_player.explodeVehicle(participant.gameVehID)
                            end, false)
                        S.dnf.process = true
                    end
                end
            end
            S.dnf.lastpos = ctxt.veh.position
        end
    end
end

S.canChangeTo = TrueFn
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

S.canReset = canReset
S.getRewindLimit = getRewindLimit
S.tryReset = tryReset

S.trySpawnNew = tryReplaceOrSpawn
S.tryReplaceOrSpawn = tryReplaceOrSpawn
S.tryPaint = tryPaint
S.getModelList = getModelList
S.canSpawnNewVehicle = canSpawnNewVehicle
S.canReplaceVehicle = canVehUpdate
S.canPaintVehicle = canPaintVehicle
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.doShowNametag = doShowNametag
S.getCollisionsType = function() return BJI_Collisions.TYPES.FORCED end

S.onVehicleSpawned = onVehicleSpawned
S.onVehicleResetted = onVehicleResetted

S.rxData = rxData

S.getPlayerListActions = getPlayerListActions

S.fastTick = fastTick
S.slowTick = slowTick

S.stop = stop

return S
