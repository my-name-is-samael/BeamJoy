---@class BJIScenarioHunter : BJIScenario
local S = {
    MINIMUM_PARTICIPANTS = 3,
    HUNTED_RESPAWN_DISTANCE = 150,
    HUNTED_REVEAL_DISTANCE = 50,
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

    state = nil,
    participants = {},
    preparationTimeout = nil,
    huntedStartTime = nil,
    hunterStartTime = nil,
    huntersRespawnDelay = 0,
    hunterRespawnTargetTime = nil,
    waypoints = {},
    previousCamera = nil,
    revealHunted = false,

    ---@type BJIPositionRotation?
    startpos = nil,
    waypoint = 1,

    dnf = {
        process = false,
        targetTime = nil,
        lastpos = nil,
        minDistance = .5,
        timeout = 10, -- +1 during first check
    },

    proximityProcess = {
        ---@type userdata?
        huntedVeh = nil,
        ---@type userdata[]
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
    S.revealHunted = false
    S.startpos = nil
    S.waypoint = 1
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
    if ctxt.veh and not table.includes({
            BJI.Managers.Cam.CAMERAS.FREE,
            BJI.Managers.Cam.CAMERAS.BIG_MAP,
            BJI.Managers.Cam.CAMERAS.EXTERNAL
        }, ctxt.camera) then
        S.previousCamera = ctxt.camera
    end
    BJI.Managers.Veh.saveCurrentVehicle()
    BJI.Managers.Veh.deleteAllOwnVehicles()
    BJI.Managers.AI.removeVehicles()
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.ALL,
            BJI.Managers.Restrictions.OTHER.AI_CONTROL,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR,
            BJI.Managers.Restrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJI.Managers.Restrictions.OTHER.VEHICLE_DEBUG,
            BJI.Managers.Restrictions.OTHER.WALKING,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.CAMERA_CHANGE,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    BJI.Managers.Bigmap.toggleQuickTravel(false)
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
            BJI.Managers.Restrictions.RESET.ALL,
            BJI.Managers.Restrictions.OTHER.AI_CONTROL,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR,
            BJI.Managers.Restrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJI.Managers.Restrictions.OTHER.VEHICLE_DEBUG,
            BJI.Managers.Restrictions.OTHER.WALKING,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.CAMERA_CHANGE,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Windows.VehSelector.tryClose(true)
    BJI.Managers.Bigmap.toggleQuickTravel(true)
end

local function tryReplaceOrSpawn(model, config)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if S.state == S.STATES.PREPARATION and participant and not participant.ready then
        if table.length(BJI.Managers.Context.User.vehicles) > 0 and not BJI.Managers.Veh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        BJI.Managers.Veh.replaceOrSpawnVehicle(model, config, S.startpos)
        BJI.Managers.Cam.forceCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.CAMERA_CHANGE,
                    BJI.Managers.Restrictions.OTHER.FREE_CAM,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.RESTRICTED
            },
        })
        BJI.Managers.Veh.waitForVehicleSpawn(function(ctxt)
            BJI.Managers.Veh.freeze(true, ctxt.veh:getID())
            if not BJI.Windows.VehSelector.show then
                BJI.Windows.VehSelector.open({}, false)
            end
        end)
    end
end

local function tryPaint(paint, paintNumber)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    local veh = BJI.Managers.Veh.getCurrentVehicleOwn()
    if veh and
        S.state == S.STATES.PREPARATION and
        participant and not participant.ready then
        BJI.Managers.Veh.paintVehicle(paint, paintNumber)
        BJI.Managers.Veh.freeze(true, veh:getID())
    end
end

local function getModelList()
    local models = {}
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if S.state == S.STATES.PREPARATION and participant and not participant.ready then
        if participant.hunted and S.settings.huntedConfig then
            -- forced config
            return models
        elseif not participant.hunted and #S.settings.hunterConfigs > 0 then
            -- forced configs (spawned automatically or by hunter window)
            return models
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

local function canVehUpdate()
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if S.state ~= S.STATES.PREPARATION or
        not participant or participant.ready then
        return false
    end

    if BJI.Managers.Veh.isCurrentVehicleOwn() then
        local forcedConfig = false
        if participant.hunted and S.settings.huntedConfig then
            forcedConfig = true
        elseif not participant.hunted and #S.settings.hunterConfigs == 1 then
            forcedConfig = true
        end
        if forcedConfig then
            return false
        end
    end
    return true
end

local function canSpawnNewVehicle()
    return canVehUpdate() and table.length(BJI.Managers.Context.User.vehicles) == 0
end

---@param vehData { gameVehicleID: integer, ownerID: integer }
local function doShowNametag(vehData)
    if S.state == S.STATES.PREPARATION then
        -- no nametags during preparation
        return false
    elseif S.state == S.STATES.GAME then
        if S.participants[BJI.Managers.Context.User.playerID].hunted then
            -- hunted do not see anyone
            return false
        else
            -- hunters can only see other hunters or lastWaypointGPS triggered
            local target = S.participants[vehData.ownerID]
            if target.hunted and S.revealHunted then
                return true, BJI.Utils.ShapeDrawer.Color(1, .6, 0, 1), BJI.Utils.ShapeDrawer.Color(1, 1, 1, 1)
            elseif not target.hunted then
                return true, BJI.Utils.ShapeDrawer.Color(1, 1, 1, 1), BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1)
            end
            return false
        end
    end
end

local function onVehicleDeleted(gameVehID)
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

local function onVehicleResetted(gameVehID)
    if BJI.Managers.Veh.isVehicleOwn(gameVehID) then
        local participant = S.participants[BJI.Managers.Context.User.playerID]
        if S.state == S.STATES.GAME and                    -- game started
            participant and not participant.hunted and     -- is hunter
            S.hunterStartTime < GetCurrentTimeMillis() and -- already started
            S.huntersRespawnDelay > 0 then                 -- minimum stuck delay configured
            BJI.Managers.Veh.freeze(true, gameVehID)
            BJI.Managers.Cam.forceCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
            BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)
            S.hunterRespawnTargetTime = GetCurrentTimeMillis() + (S.huntersRespawnDelay * 1000) + 50
            BJI.Managers.Async.programTask(function(ctxt)
                BJI.Managers.Cam.resetForceCamera(true)
            end, S.hunterRespawnTargetTime - 3000)
            BJI.Managers.Message.flashCountdown("BJIHunterReset", S.hunterRespawnTargetTime,
                false, BJI.Managers.Lang.get("hunter.play.flashHunterResume"), S.huntersRespawnDelay, function()
                    BJI.Managers.Veh.freeze(false, gameVehID)
                    BJI.Managers.Restrictions.updateResets(Table()
                        :addAll(BJI.Managers.Restrictions.RESET.TELEPORT)
                        :addAll(BJI.Managers.Restrictions.RESET.HEAVY_RELOAD))
                end)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
        end
    end
end

local function initPreparation(data)
    S.settings.waypoints = data.waypoints
    S.settings.huntedConfig = data.huntedConfig
    S.settings.hunterConfigs = data.hunterConfigs
    S.preparationTimeout = BJI.Managers.Tick.applyTimeOffset(data.preparationTimeout)
    S.state = data.state
    BJI.Managers.Cam.forceFreecamPos()
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.HUNTER)
end

local function onJoinParticipants(isHunted)
    local model, config
    S.startpos = nil
    if isHunted then
        -- generate start position
        local freepos
        while not S.startpos or not freepos do
            S.startpos = table.random(BJI.Managers.Context.Scenario.Data.Hunter.huntedPositions)
            freepos = true
            for _, mpveh in pairs(BJI.Managers.Veh.getMPVehicles()) do
                local v = BJI.Managers.Veh.getVehicleObject(mpveh.gameVehicleID)
                local posrot = v and BJI.Managers.Veh.getPositionRotation(v) or nil
                if posrot and posrot.pos:distance(vec3(S.startpos.pos)) < 2 then
                    freepos = false
                    break
                end
            end
        end

        -- generate waypoints to reach
        local function findNextWaypoint(pos)
            return Table(BJI.Managers.Context.Scenario.Data.Hunter.targets)
                :map(function(wp)
                    return {
                        wp = {
                            pos = vec3(wp.pos),
                            radius = wp.radius,
                        },
                        distance = vec3(pos):distance(vec3(wp.pos)),
                    }
                end)
                :sort(function(a, b)
                    return a.distance > b.distance
                end)
                :map(function(el)
                    return el.wp
                end)
                :filter(function(_, i)
                    return i < math.ceil(#BJI.Managers.Context.Scenario.Data.Hunter.targets / 2)
                end)
                :random()
        end
        local previousPos = S.startpos.pos
        while #S.waypoints < S.settings.waypoints do
            if #S.waypoints > 0 then
                previousPos = S.waypoints[#S.waypoints].pos
            end
            table.insert(S.waypoints, findNextWaypoint(previousPos))
        end

        if S.settings.huntedConfig then
            -- forced config
            model, config = S.settings.huntedConfig.model, S.settings.huntedConfig.config
        else
            BJI.Managers.Restrictions.update({
                {
                    restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR,
                    state = BJI.Managers.Restrictions.STATE.ALLOWED,
                }
            })
            BJI.Managers.Message.flash("BJIHunterChooseVehicle", BJI.Managers.Lang.get("hunter.play.flashChooseVehicle"),
                3, false)
            BJI.Windows.VehSelector.open(getModelList(), false)
        end
    else
        -- hunter
        -- generate start position
        local freepos
        while not S.startpos or not freepos do
            S.startpos = table.random(BJI.Managers.Context.Scenario.Data.Hunter.hunterPositions)
            freepos = true
            for _, mpveh in pairs(BJI.Managers.Veh.getMPVehicles()) do
                local v = BJI.Managers.Veh.getVehicleObject(mpveh.gameVehicleID)
                local posrot = v and BJI.Managers.Veh.getPositionRotation(v) or nil
                if posrot and posrot.pos:distance(vec3(S.startpos.pos)) < 2 then
                    freepos = false
                    break
                end
            end
        end

        if #S.settings.hunterConfigs == 1 then
            -- forced config
            model, config = S.settings.hunterConfigs[1].model, S.settings.hunterConfigs[1].config
        elseif #S.settings.hunterConfigs == 0 then
            BJI.Managers.Restrictions.update({
                {
                    restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR,
                    state = BJI.Managers.Restrictions.STATE.ALLOWED,
                }
            })
            BJI.Managers.Message.flash("BJIHunterChooseVehicle", BJI.Managers.Lang.get("hunter.play.flashChooseVehicle"),
                3, false)
            BJI.Windows.VehSelector.open(getModelList(), false)
        end
    end

    -- when forced config
    if config then
        BJI.Managers.Async.task(function(ctxt)
            return S.canSpawnNewVehicle()
        end, function(ctxt)
            S.tryReplaceOrSpawn(model, config)
        end, "BJIHunterForcedConfigSpawn")
    end
end

local function onLeaveParticipants()
    if S.state == S.STATES.PREPARATION then
        -- prevents from switching to another participant (spoil)
        BJI.Managers.Cam.forceFreecamPos()
    end
    BJI.Managers.Veh.deleteAllOwnVehicles()
end

local function updatePreparation(data)
    local wasParticipant = S.participants[BJI.Managers.Context.User.playerID]
    local wasHunted = wasParticipant and wasParticipant.hunted or false
    S.participants = data.participants
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if not wasParticipant and participant then
        onJoinParticipants(participant.hunted)
    elseif wasParticipant and not participant then
        onLeaveParticipants()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR,
                state = BJI.Managers.Restrictions.STATE.RESTRICTED,
            }
        })
        BJI.Windows.VehSelector.tryClose(true)
        S.waypoints = {}
    elseif wasParticipant and participant and
        wasHunted ~= participant.hunted then
        -- role changed > reset vehicles then reload
        onLeaveParticipants()
        onJoinParticipants(participant.hunted)
    end
end

local function switchToRandomParticipant()
    if S.participants[BJI.Managers.Context.User.playerID] then
        return
    end

    local part = table.random(S.participants)
    if part then
        BJI.Managers.Veh.focus(Table(S.participants):indexOf(part))
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
    end

    if S.huntedStartTime > GetCurrentTimeMillis() then
        BJI.Managers.Async.programTask(resetCamAndInitWP, S.huntedStartTime - 3000)
        BJI.Managers.Message.flashCountdown("BJIHuntedStart", S.huntedStartTime, false, nil, 5, start, true)
    else
        resetCamAndInitWP()
        start()
    end
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
        BJI.Managers.Restrictions.updateResets(Table({
            BJI.Managers.Restrictions.RESET.TELEPORT,
            BJI.Managers.Restrictions.RESET.HEAVY_RELOAD,
        }):flat())
        local hunted = Table(S.participants):find(function(p) return p.hunted end)
        if S.settings.lastWaypointGPS and hunted and
            hunted.waypoint == S.settings.waypoints - 1 then
            S.revealHunted = true
        end
    end

    if S.hunterStartTime > GetCurrentTimeMillis() then
        BJI.Managers.Async.programTask(resetCam, S.hunterStartTime - 3000)
        BJI.Managers.Message.flashCountdown("BJIHunterStart", S.hunterStartTime, false, nil, 5, start, true)
    else
        resetCam()
        start()
    end
end

local function initGame(data)
    S.settings.waypoints = data.waypoints
    S.state = data.state
    S.participants = data.participants
    S.huntedStartTime = BJI.Managers.Tick.applyTimeOffset(data.huntedStartTime)
    S.hunterStartTime = BJI.Managers.Tick.applyTimeOffset(data.hunterStartTime)

    local participant = S.participants[BJI.Managers.Context.User.playerID]
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.CAMERA_CHANGE,
            not participant and BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH or nil,
            not participant and BJI.Managers.Restrictions.OTHER.FREE_CAM or nil,
        }):flat(),
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
        switchToRandomParticipant()
    end

    if BJI.Managers.Cam.getCamera() == BJI.Managers.Cam.CAMERAS.FREE then
        BJI.Managers.Cam.toggleFreeCam()
    end
end

local function updateGame(data)
    local wasParticipant = S.participants[BJI.Managers.Context.User.playerID]
    S.participants = data.participants
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
    if S.settings.lastWaypointGPS and not S.revealHunted then
        Table(S.participants):find(function(p) return p.hunted end, function(p)
            if p.waypoint == S.settings.waypoints - 1 then
                S.revealHunted = true
            end
        end)
    end
end

-- receive hunter data from backend
local function rxData(data)
    S.MINIMUM_PARTICIPANTS = data.minimumParticipants
    S.huntersRespawnDelay = data.huntersRespawnDelay
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
    else
        if S.state then
            S.stop()
        end
    end
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

-- each second tick hook
local function slowTick(ctxt)
    local participant = S.participants[BJI.Managers.Context.User.playerID]
    if ctxt.isOwner and
        S.state == S.STATES.GAME then
        if participant then
            if participant.hunted and S.huntedStartTime and S.huntedStartTime <= ctxt.now then
                -- respawn rest update
                if Table(S.participants)
                    :filter(function(_, playerID) return playerID ~= ctxt.user.playerID end)
                    :map(function(p) return BJI.Managers.Veh.getVehicleObject(p.gameVehID) end)
                    :map(function(veh) return BJI.Managers.Veh.getPositionRotation(veh) end)
                    :map(function(posRot) return ctxt.vehPosRot.pos:distance(posRot.pos) end)
                    :any(function(d) return d < S.HUNTED_RESPAWN_DISTANCE end) then
                    -- if any hunter is close, block respawn
                    BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)
                else
                    BJI.Managers.Restrictions.updateResets(Table({
                        BJI.Managers.Restrictions.RESET.TELEPORT,
                        BJI.Managers.Restrictions.RESET.HEAVY_RELOAD,
                    }):flat())
                end

                -- DNF check
                if not S.dnf.lastpos then
                    S.dnf.lastpos = ctxt.vehPosRot.pos
                else
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
                    else
                        -- good distance, remove countdown if there is one
                        if S.dnf.process then
                            BJI.Managers.Message.cancelFlash("BJIHuntedDNF")
                            S.dnf.process = false
                            S.dnf.targetTime = nil
                        end
                        S.dnf.lastpos = ctxt.vehPosRot.pos
                    end
                end
            end

            if not participant.hunted and S.huntedStartTime and S.huntedStartTime <= ctxt.now then
                -- proximity reveal
                if not S.proximityProcess.huntedVeh then
                    -- init vehs
                    Table(S.participants):find(function(p) return p.hunted end, function(hunted)
                        S.proximityProcess.huntedVeh = BJI.Managers.Veh.getVehicleObject(hunted.gameVehID)
                    end)
                    S.proximityProcess.huntersVehs = Table(S.participants)
                        :filter(function(p) return not p.hunted end)
                        :map(function(p)
                            return BJI.Managers.Veh.getVehicleObject(p.gameVehID)
                        end)
                end
                local waypoint = 0
                if S.proximityProcess.huntedVeh and #S.proximityProcess.huntersVehs > 0 then
                    Table(S.participants):find(function(p) return p.hunted end,
                        function(hunted) waypoint = hunted.waypoint end)
                    if not S.settings.lastWaypointGPS or waypoint < S.settings.waypoints - 1 then
                        local minDistance = S.proximityProcess.huntersVehs:map(function(hunter)
                            return BJI.Managers.Veh.getPositionRotation(hunter).pos:distance(
                                BJI.Managers.Veh.getPositionRotation(S.proximityProcess.huntedVeh).pos
                            )
                        end):reduce(function(acc, d) return (not acc or d < acc) and d or acc end)
                        if S.revealHunted and minDistance > S.HUNTED_REVEAL_DISTANCE then
                            S.revealHunted = false
                        elseif not S.revealHunted and minDistance <= S.HUNTED_REVEAL_DISTANCE then
                            S.revealHunted = true
                        end
                    end
                end

                -- auto gps
                if S.revealHunted and not BJI.Managers.GPS.getByKey(BJI.Managers.GPS.KEYS.PLAYER) then
                    Table(S.participants):find(function(p) return p.hunted end, function(_, huntedID)
                        BJI.Managers.GPS.appendWaypoint(BJI.Managers.GPS.KEYS.PLAYER, nil, .1, nil,
                            BJI.Managers.Context.Players[huntedID].playerName, false)
                    end)
                end
            end
        end
    end
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.trySpawnNew = tryReplaceOrSpawn
S.tryReplaceOrSpawn = tryReplaceOrSpawn
S.tryPaint = tryPaint
S.getModelList = getModelList
S.canSpawnNewVehicle = canSpawnNewVehicle
S.canReplaceVehicle = canVehUpdate
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.doShowNametag = doShowNametag

S.onVehicleDeleted = onVehicleDeleted
S.onVehicleResetted = onVehicleResetted

S.rxData = rxData

S.slowTick = slowTick

S.stop = stop

return S
