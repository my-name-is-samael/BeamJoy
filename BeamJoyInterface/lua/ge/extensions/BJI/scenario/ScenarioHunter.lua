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
        ---@type {model: string, config: table}?
        huntedConfig = nil,
        ---@type {model: string, config: table}[]
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
}

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
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return true
end

-- load hook
---@param ctxt TickContext
local function onLoad(ctxt)
    BJI.Windows.VehSelector.tryClose(true)
    if ctxt.isOwner then
        BJI.Managers.Veh.saveCurrentVehicle()
        if not table.includes({
                BJI.Managers.Cam.CAMERAS.FREE,
                BJI.Managers.Cam.CAMERAS.BIG_MAP,
                BJI.Managers.Cam.CAMERAS.EXTERNAL
            }, ctxt.camera) then
            S.previousCamera = ctxt.camera
        end
    else
        S.previousCamera = BJI.Managers.Cam.CAMERAS.ORBIT
    end
    BJI.Managers.Veh.deleteAllOwnVehicles()
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.CAMERA_CHANGE,
            BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    BJI.Managers.RaceWaypoint.resetAll()
    BJI.Managers.GPS.reset()
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
end

-- unload hook
local function onUnload()
    -- cancel message processes
    BJI.Managers.Message.cancelFlash("BJIHuntedDNF")
    BJI.Managers.Message.cancelFlash("BJIHuntedStart")
    BJI.Managers.Message.cancelFlash("BJIHunterStart")
    BJI.Managers.Message.cancelFlash("BJIHunterReset")
    BJI.Managers.Async.removeTask("BJIHunterResetCam")
    BJI.Managers.Async.removeTask("BJIHunterForcedConfigSpawn")
    BJI.Managers.Async.removeTask("BJIHuntedStartCam")
    BJI.Managers.Async.removeTask("BJIHunterStartCam")
    BJI.Managers.Async.removeTask("BJIHuntedResetReveal")

    BJI.Managers.RaceWaypoint.resetAll()
    BJI.Managers.GPS.reset()
    for _, veh in pairs(BJI.Managers.Context.User.vehicles) do
        BJI.Managers.Veh.focusVehicle(veh.gameVehID)
        BJI.Managers.Veh.freeze(false, veh.gameVehID)
        break
    end
    BJI.Managers.Cam.resetRestrictedCameras()
    BJI.Managers.Cam.resetForceCamera(true)
    if BJI.Managers.Cam.getCamera() == BJI.Managers.Cam.CAMERAS.EXTERNAL then
        BJI.Managers.Cam.setCamera(S.previousCamera or BJI.Managers.Cam.CAMERAS.ORBIT)
    end
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.CAMERA_CHANGE,
            BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Windows.VehSelector.tryClose(true)
end

---@param ctxt TickContext
local function postSpawn(ctxt)
    if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.HUNTER) then
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.CAMERA_CHANGE,
                    BJI.Managers.Restrictions.OTHER.FREE_CAM,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.RESTRICTED
            },
        })
        if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
            BJI.Managers.Cam.toggleFreeCam()
        end
        BJI.Managers.Cam.forceCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
        BJI.Managers.Veh.freeze(true, ctxt.veh:getID())
        if not BJI.Windows.VehSelector.show then
            BJI.Windows.VehSelector.open(false)
        end
    end
end

---@param model string
---@param config table
local function tryReplaceOrSpawn(model, config)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if S.state == S.STATES.PREPARATION and participant and not participant.ready then
        if table.length(BJI.Managers.Context.User.vehicles) > 0 and not BJI.Managers.Veh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        local startPos = participant.hunted and
            BJI.Managers.Context.Scenario.Data.Hunter.huntedPositions[participant.startPosition] or
            BJI.Managers.Context.Scenario.Data.Hunter.hunterPositions[participant.startPosition]
        BJI.Managers.Veh.replaceOrSpawnVehicle(model, config, startPos)
        BJI.Managers.Veh.waitForVehicleSpawn(postSpawn)
    end
end

local function onVehicleSpawned(gameVehID)
    local veh = gameVehID ~= 1 and BJI.Managers.Veh.getVehicleObject(gameVehID) or nil
    local vehPosRot = veh and BJI.Managers.Veh.getPositionRotation(veh) or nil
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if vehPosRot and BJI.Managers.Veh.isVehicleOwn(gameVehID) and
        S.state == S.STATES.PREPARATION and participant and not participant.ready then
        local startPos = participant.hunted and
            BJI.Managers.Context.Scenario.Data.Hunter.huntedPositions[participant.startPosition] or
            BJI.Managers.Context.Scenario.Data.Hunter.hunterPositions[participant.startPosition]
        if vehPosRot.pos:distance(startPos.pos) > 1 then
            -- spawned via basegame vehicle selector
            BJI.Managers.Veh.setPositionRotation(startPos.pos, startPos.rot, { safe = false })
            BJI.Managers.Veh.waitForVehicleSpawn(postSpawn)
        end
    end
end

---@param paintIndex integer
---@param paint NGPaint
local function tryPaint(paintIndex, paint)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    local veh = BJI.Managers.Veh.getCurrentVehicleOwn()
    if veh and S.state == S.STATES.PREPARATION and
        participant and not participant.ready then
        BJI.Managers.Veh.paintVehicle(veh, paintIndex, paint)
    end
end

local function canRecoverVehicle()
    local ctxt = BJI.Managers.Tick.getContext()
    local participant = S.participants[ctxt.user.playerID]
    return S.state == S.STATES.GAME and participant and not S.resetLock and
        (participant.hunted and S.huntedStartTime or S.hunterStartTime) < ctxt.now
end

---@return table<string, table>?
local function getModelList()
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if S.state ~= S.STATES.PREPARATION or not participant or participant.ready then
        return -- veh selector should not be opened
    end

    local models = {}
    if S.state == S.STATES.PREPARATION and participant and not participant.ready then
        if participant.hunted and S.settings.huntedConfig then
            return models -- only paints
        elseif not participant.hunted and #S.settings.hunterConfigs > 0 then
            return models -- only paints
        end

        models = BJI.Managers.Veh.getAllVehicleConfigs(
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SPAWN_TRAILERS),
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SPAWN_PROPS)
        )

        if #BJI.Managers.Context.Database.Vehicles.ModelBlacklist > 0 then
            for _, model in ipairs(BJI.Managers.Context.Database.Vehicles.ModelBlacklist) do
                models[model] = nil
            end
        end
    end

    return models
end

---@return boolean
local function canSpawnNewVehicle()
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    return S.state == S.STATES.PREPARATION and participant and not participant.ready and
        table.length(BJI.Managers.Context.User.vehicles) == 0
end

---@return boolean
local function canVehUpdate()
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if S.state ~= S.STATES.PREPARATION or not participant or participant.ready or
        not BJI.Managers.Veh.isCurrentVehicleOwn() then
        return false
    end

    return (participant.hunted and not S.settings.huntedConfig) or
        (not participant.hunted and #S.settings.hunterConfigs ~= 1)
end

---@return boolean
local function canPaintVehicle()
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    return S.state == S.STATES.PREPARATION and participant and not participant.ready and
        BJI.Managers.Veh.isCurrentVehicleOwn()
end

---@param vehData BJIMPVehicle
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if S.state == S.STATES.GAME then
        if not S.participants[BJI.Managers.Context.User.playerID] then
            -- spec
            return true
        elseif not S.participants[BJI.Managers.Context.User.playerID].hunted then
            -- hunters only can see other hunters or reaveled hunted
            local target = S.participants[vehData.ownerID]
            if target.hunted and (S.revealHuntedProximity or S.revealHuntedLastWaypoint or S.revealHuntedReset) then
                return true, BJI.Utils.ShapeDrawer.Color(1, .6, 0, 1), BJI.Utils.ShapeDrawer.Color(1, 1, 1, 1)
            elseif not target.hunted then
                return true, BJI.Utils.ShapeDrawer.Color(1, 1, 1, 1), BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1)
            end
        end
    end
    return false
end

---@param gameVehID integer
local function onVehicleDestroyed(gameVehID)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if BJI.Managers.Veh.isVehicleOwn(gameVehID) and participant then
        if S.state == S.STATES.PREPARATION then
            if (participant.hunted and S.settings.huntedConfig) or
                (not participant.hunted and #S.settings.hunterConfigs == 1) then
                -- leave when forced preset
                BJI.Tx.scenario.HunterUpdate(S.CLIENT_EVENTS.JOIN)
            end
        else
            BJI.Tx.scenario.HunterUpdate(S.CLIENT_EVENTS.LEAVE)
        end
    end
end

---@param gameVehID integer
local function onVehicleResetted(gameVehID)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if S.state == S.STATES.GAME and -- self hunter during game
        participant and not participant.hunted and
        S.hunterStartTime < GetCurrentTimeMillis() and
        not S.finished then
        local ownVeh = BJI.Managers.Veh.isVehicleOwn(gameVehID)
        -- respawn delay
        if ownVeh and S.huntersRespawnDelay > 0 then -- minimum stuck delay configured
            BJI.Managers.Veh.freeze(true, gameVehID)
            BJI.Managers.Cam.forceCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
            S.hunterRespawnTargetTime = GetCurrentTimeMillis() + (S.huntersRespawnDelay * 1000) + 50
            S.resetLock = true
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)

            BJI.Managers.Async.programTask(function(ctxt)
                BJI.Managers.Cam.resetForceCamera(true)
            end, S.hunterRespawnTargetTime - 3000, "BJIHunterResetCam")

            BJI.Managers.Message.flashCountdown("BJIHunterReset", S.hunterRespawnTargetTime,
                false, BJI.Managers.Lang.get("hunter.play.flashHunterResume"), S.huntersRespawnDelay, function()
                    BJI.Managers.Veh.freeze(false, gameVehID)
                    S.resetLock = false
                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
                end)
        end

        if not ownVeh and S.huntedResetRevealDuration > 0 and
            S.proximityProcess.huntedVeh and gameVehID == S.proximityProcess.huntedVeh:getID() then
            -- if fugitive respawns, reveal for few secs
            BJI.Managers.Async.removeTask("BJIHuntedResetReveal")
            S.revealHuntedReset = true
            BJI.Managers.Async.delayTask(function()
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
    S.preparationTimeout = BJI.Managers.Tick.applyTimeOffset(data.preparationTimeout)
    S.state = data.state
    BJI.Managers.Cam.forceFreecamPos()
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.HUNTER)
end

---@param participant BJIHunterParticipant
local function onJoinParticipants(participant)
    local model, config
    if participant.hunted then
        -- generate waypoints to reach
        ---@param pos vec3
        local function findNextWaypoint(pos)
            return Table(BJI.Managers.Context.Scenario.Data.Hunter.targets)
                :map(function(wp)
                    return {
                        wp = {
                            pos = vec3(wp.pos),
                            radius = wp.radius,
                        },
                        distance = pos:distance(wp.pos),
                    }
                end)
                :sort(function(a, b)
                    return a.distance > b.distance
                end)
                :map(function(el)
                    return el.wp
                end)
                :filter(function(_, i)
                    return i <= math.ceil(#BJI.Managers.Context.Scenario.Data.Hunter.targets / 2)
                end)
                :random()
        end
        local lastPos = BJI.Managers.Context.Scenario.Data.Hunter.huntedPositions[participant.startPosition].pos
        while #S.waypoints < S.settings.waypoints do
            if #S.waypoints > 0 then
                lastPos = S.waypoints[#S.waypoints].pos
            end
            table.insert(S.waypoints, findNextWaypoint(vec3(lastPos)))
        end

        if S.settings.huntedConfig then
            -- forced config
            model, config = S.settings.huntedConfig.model, S.settings.huntedConfig
        else
            BJI.Managers.Message.flash("BJIHunterChooseVehicle", BJI.Managers.Lang.get("hunter.play.flashChooseVehicle"),
                3, false)
            BJI.Windows.VehSelector.open(false)
        end
    else
        -- hunter
        if #S.settings.hunterConfigs == 1 then
            -- forced config
            model, config = S.settings.hunterConfigs[1].model, S.settings.hunterConfigs[1]
        elseif #S.settings.hunterConfigs == 0 then
            BJI.Managers.Message.flash("BJIHunterChooseVehicle", BJI.Managers.Lang.get("hunter.play.flashChooseVehicle"),
                3, false)
            BJI.Windows.VehSelector.open(false)
        end
    end

    -- when forced config
    if config then
        BJI.Managers.Async.task(function(ctxt)
            return BJI.Managers.VehSelectorUI.stateSelector
        end, function(ctxt)
            S.trySpawnNew(model, config)
        end, "BJIHunterForcedConfigSpawn")
    end
end

local function onLeaveParticipants()
    if S.state == S.STATES.PREPARATION then
        -- prevents from switching to another participant (spoil)
        BJI.Managers.Cam.forceFreecamPos()
        BJI.Windows.VehSelector.tryClose(true)
    end
    BJI.Managers.Veh.deleteAllOwnVehicles()
end

local function updatePreparation(data)
    local wasParticipant = S.participants[BJI.Managers.Context.User.playerID]
    local wasHunted = wasParticipant and wasParticipant.hunted or false
    S.participants = data.participants
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if not wasParticipant and participant then
        onJoinParticipants(participant)
    elseif wasParticipant and not participant then
        onLeaveParticipants()
        BJI.Windows.VehSelector.tryClose(true)
        S.waypoints = {}
    elseif wasParticipant and participant and
        wasHunted ~= participant.hunted then
        -- role changed > reset vehicles then reload
        onLeaveParticipants()
        onJoinParticipants(participant)
    end
end

local function switchToRandomParticipant()
    if S.participants[BJI.Managers.Context.User.playerID] then
        return
    end

    local part = table.random(S.participants)
    if part then
        BJI.Managers.Veh.focus(S.participants:indexOf(part) or 0)
    end
end

local function initGameHunted(participant)
    local function updateWP()
        -- current WP
        local wp = S.waypoints[S.waypoint]
        BJI.Managers.RaceWaypoint.addWaypoint({
            name = "BJIHunter",
            pos = wp.pos,
            radius = wp.radius,
            color = BJI.Managers.RaceWaypoint.COLORS.BLUE
        })
        -- next WP
        local nextWp = S.waypoints[S.waypoint + 1]
        if nextWp then
            BJI.Managers.RaceWaypoint.addWaypoint({
                name = "BJIHunterNext",
                pos = nextWp.pos,
                radius = nextWp.radius,
                color = BJI.Managers.RaceWaypoint.COLORS.BLACK
            })
        end

        BJI.Managers.GPS.appendWaypoint(BJI.Managers.GPS.KEYS.HUNTER, wp.pos, wp.radius, function()
            BJI.Managers.RaceWaypoint.resetAll()
            BJI.Tx.scenario.HunterUpdate(S.CLIENT_EVENTS.CHECKPOINT_REACHED)
            S.waypoint = S.waypoint + 1
            if S.waypoint <= #S.waypoints then
                updateWP()
            end
        end, nil, false)
    end

    local function resetCamAndInitWP()
        updateWP()
        if BJI.Managers.Cam.getCamera() == BJI.Managers.Cam.CAMERAS.EXTERNAL then
            BJI.Managers.Cam.setCamera(S.previousCamera or BJI.Managers.Cam.CAMERAS.ORBIT)
        end
    end
    local function start()
        BJI.Managers.Message.flash("BJIHuntedStart", BJI.Managers.Lang.get("hunter.play.flashHuntedStart"), 5, false)
        BJI.Managers.Veh.freeze(false, participant.gameVehID)
        S.resetLock = false
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
    end

    if S.huntedStartTime > GetCurrentTimeMillis() then
        BJI.Managers.Async.programTask(resetCamAndInitWP, S.huntedStartTime - 3000, "BJIHuntedStartCam")
        BJI.Managers.Message.flashCountdown("BJIHuntedStart", S.huntedStartTime, false, nil, 5, start, true)
    else
        resetCamAndInitWP()
        start()
    end
end

local function updateProximityVehs()
    Table(S.participants):find(function(p) return p.hunted end, function(hunted)
        S.proximityProcess.huntedVeh = BJI.Managers.Veh.getVehicleObject(hunted.gameVehID)
    end)
    S.proximityProcess.huntersVehs = Table(S.participants)
        :filter(function(p) return not p.hunted end)
        :map(function(p)
            return BJI.Managers.Veh.getVehicleObject(p.gameVehID)
        end):values()
end

local function initGameHunter(participant)
    local function resetCam()
        if BJI.Managers.Cam.getCamera() == BJI.Managers.Cam.CAMERAS.EXTERNAL then
            BJI.Managers.Cam.setCamera(S.previousCamera or BJI.Managers.Cam.CAMERAS.ORBIT)
        end
    end
    local function start()
        BJI.Managers.Message.flash("BJIHunterStart", BJI.Managers.Lang.get("hunter.play.flashHunterResume"), 5, false)
        BJI.Managers.Veh.freeze(false, participant.gameVehID)
        if S.settings.lastWaypointGPS then
            Table(S.participants):find(function(p) return p.hunted end, function(hunted)
                if hunted.waypoint == S.settings.waypoints - 1 then
                    S.revealHuntedLastWaypoint = true
                end
            end)
        end
        S.resetLock = false
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
    end

    if S.hunterStartTime > GetCurrentTimeMillis() then
        BJI.Managers.Async.programTask(resetCam, S.hunterStartTime - 3000, "BJIHunterStartCam")
        BJI.Managers.Message.flashCountdown("BJIHunterStart", S.hunterStartTime, false, nil, 5, start, true)
    else
        resetCam()
        start()
    end

    -- init proximity detector vehs
    updateProximityVehs()
end

local function initGame(data)
    S.settings.waypoints = data.waypoints
    S.state = data.state
    S.participants = data.participants
    S.huntedStartTime = BJI.Managers.Tick.applyTimeOffset(data.huntedStartTime)
    S.hunterStartTime = BJI.Managers.Tick.applyTimeOffset(data.hunterStartTime)

    local participant = S.participants[BJI.Managers.Context.User.playerID]
    BJI.Managers.Restrictions.update({ {
        restrictions = BJI.Managers.Restrictions.OTHER.CAMERA_CHANGE,
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.Cam.resetForceCamera()

    if participant then
        BJI.Windows.VehSelector.tryClose(true)
        if participant.hunted then
            initGameHunted(participant)
        else
            initGameHunter(participant)
        end
    else -- spec
        BJI.Managers.Restrictions.update({ {
            restrictions = Table({
                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                BJI.Managers.Restrictions.OTHER.FREE_CAM,
                BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
            }):flat(),
            state = BJI.Managers.Restrictions.STATE.ALLOWED,
        } })
        switchToRandomParticipant()
    end

    if BJI.Managers.Cam.getCamera() == BJI.Managers.Cam.CAMERAS.FREE then
        BJI.Managers.Cam.toggleFreeCam()
    end
end

local function updateGame(data)
    local wasParticipant = S.participants[BJI.Managers.Context.User.playerID]
    local amountParticipants = table.length(data.participants)
    S.participants = data.participants
    local wasFinished = S.finished
    S.finished = data.finished

    if wasParticipant and not S.participants[BJI.Managers.Context.User.playerID] then
        onLeaveParticipants()
        BJI.Managers.Restrictions.update({ {
            restrictions = Table({
                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                BJI.Managers.Restrictions.OTHER.FREE_CAM,
            }):flat(),
            state = BJI.Managers.Restrictions.STATE.ALLOWED,
        } })
        -- own vehicle deletion will trigger switch to another participant
    end
    if S.settings.lastWaypointGPS and not S.revealHuntedLastWaypoint then
        Table(S.participants):find(function(p) return p.hunted end, function(p)
            if p.waypoint == S.settings.waypoints - 1 then
                S.revealHuntedLastWaypoint = true
            end
        end)
    end
    if amountParticipants ~= table.length(S.participants) then
        updateProximityVehs()
    end
    if S.participants[BJI.Managers.Context.User.playerID] and not wasFinished and S.finished then
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.OTHER.FREE_CAM,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Async.removeTask("BJIHuntedResetReveal")
        BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.PLAYER)
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
        if not S.state then
            initPreparation(data)
        else
            updatePreparation(data)
        end
    elseif data.state == S.STATES.GAME then
        if S.state ~= S.STATES.GAME then
            initGame(data)
        else
            updateGame(data)
        end
    elseif S.state then
        S.stop()
    end
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

-- check for close hunters to prevent hunted from respawning<br/>
-- check for movement when DNF process is active<br/>
-- check for revealing hunted position to hunters
local function fastTick(ctxt)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if ctxt.isOwner and S.state == S.STATES.GAME and participant then
        if S.huntedResetDistanceThreshold > 0 and
            participant.hunted and S.huntedStartTime and S.huntedStartTime <= ctxt.now then
            -- respawn rest update
            local closeHunter = Table(S.participants)
                :filter(function(_, playerID) return playerID ~= ctxt.user.playerID end)
                :map(function(p) return BJI.Managers.Veh.getVehicleObject(p.gameVehID) end)
                :map(function(veh) return BJI.Managers.Veh.getPositionRotation(veh) end)
                :map(function(posRot) return ctxt.vehPosRot.pos:distance(posRot.pos) end)
                :any(function(d) return d < S.huntedResetDistanceThreshold end)
            if closeHunter and not S.resetLock then
                S.resetLock = true
                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
            elseif not closeHunter and S.resetLock then
                S.resetLock = false
                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
            end

            -- DNF disabling update
            if S.dnf.lastpos and S.dnf.process then
                if S.finished or math.horizontalDistance(S.dnf.lastpos, ctxt.vehPosRot.pos) > S.dnf.minDistance then
                    BJI.Managers.Message.cancelFlash("BJIHuntedDNF")
                    S.dnf.process = false
                    S.dnf.targetTime = nil
                end
            end
        elseif S.huntedResetDistanceThreshold == 0 and not S.resetLock then
            S.resetLock = true
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
        end

        if not participant.hunted and S.hunterStartTime and S.hunterStartTime <= ctxt.now then
            -- proximity reveal update
            if S.huntedRevealProximityDistance > 0 and S.proximityProcess.huntedVeh and #S.proximityProcess.huntersVehs > 0 then
                Table(S.participants):find(function(p) return p.hunted end,
                    function(hunted)
                        if not S.settings.lastWaypointGPS or hunted.waypoint < S.settings.waypoints - 1 then
                            local minDistance = S.proximityProcess.huntersVehs:map(function(hunter)
                                return BJI.Managers.Veh.getPositionRotation(hunter).pos:distance(
                                    BJI.Managers.Veh.getPositionRotation(S.proximityProcess.huntedVeh).pos
                                )
                            end):reduce(function(acc, d) return (not acc or d < acc) and d or acc end)
                            if S.revealHuntedProximity and minDistance > S.huntedRevealProximityDistance then
                                S.revealHuntedProximity = false
                            elseif not S.revealHuntedProximity and minDistance <= S.huntedRevealProximityDistance then
                                S.revealHuntedProximity = true
                            end
                        end
                    end)
            end

            -- auto gps
            local reveal = S.revealHuntedProximity or S.revealHuntedLastWaypoint or S.revealHuntedReset
            if reveal and not BJI.Managers.GPS.getByKey(BJI.Managers.GPS.KEYS.PLAYER) then
                Table(S.participants):find(function(p) return p.hunted end, function(_, huntedID)
                    BJI.Managers.GPS.appendWaypoint(BJI.Managers.GPS.KEYS.PLAYER, nil, .1, nil,
                        ctxt.players[huntedID].playerName, false)
                end)
            elseif not reveal and BJI.Managers.GPS.getByKey(BJI.Managers.GPS.KEYS.PLAYER) then
                BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.PLAYER)
            end
        end
    end
end

-- check for DNF process activation
local function slowTick(ctxt)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if ctxt.isOwner and S.state == S.STATES.GAME and participant then
        if participant.hunted and S.huntedStartTime and S.huntedStartTime <= ctxt.now then
            -- DNF check
            if not S.finished and S.dnf.lastpos and not S.dnf.process then
                local distance = math.horizontalDistance(S.dnf.lastpos, ctxt.vehPosRot.pos)
                if distance < S.dnf.minDistance then
                    -- start countdown process
                    if not S.dnf.process then
                        S.dnf.targetTime = ctxt.now + (S.dnf.timeout * 1000)
                        BJI.Managers.Message.flashCountdown("BJIHuntedDNF",
                            S.dnf.targetTime,
                            true, "", 10, function()
                                BJI.Managers.Cam.removeRestrictedCamera(BJI.Managers.Cam.CAMERAS.FREE)
                                BJI.Tx.scenario.HunterUpdate(S.CLIENT_EVENTS.ELIMINATED)
                                BJI.Tx.player.explodeVehicle(participant.gameVehID)
                            end, false)
                        S.dnf.process = true
                    end
                end
            end
            S.dnf.lastpos = ctxt.vehPosRot.pos
        end
    end
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.trySpawnNew = tryReplaceOrSpawn
S.tryReplaceOrSpawn = tryReplaceOrSpawn
S.tryPaint = tryPaint
S.canRecoverVehicle = canRecoverVehicle
S.getModelList = getModelList
S.canSpawnNewVehicle = canSpawnNewVehicle
S.canReplaceVehicle = canVehUpdate
S.canPaintVehicle = canPaintVehicle
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.doShowNametag = doShowNametag
S.getCollisionsType = function() return BJI.Managers.Collisions.TYPES.FORCED end

S.onVehicleSpawned = onVehicleSpawned
S.onVehicleDestroyed = onVehicleDestroyed
S.onVehicleResetted = onVehicleResetted

S.rxData = rxData

S.fastTick = fastTick
S.slowTick = slowTick

S.stop = stop

return S
