local M = {
    MINIMUM_PARTICIPANTS = 3,
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
    },

    state = nil,
    participants = {},
    preparationTimeout = nil,
    huntedStartTime = nil,
    hunterStartTime = nil,
    huntersRespawnDelay = 0,
    waypoints = {},

    startpos = nil,
    waypoint = 1,

    dnf = {
        process = false,
        targetTime = nil,
        lastpos = nil,
        minDistance = .5,
        timeout = 10, -- +1 during first check
    },
}

local function stop()
    M.state = nil
    M.participants = {}
    M.preparationTimeout = nil
    M.huntedStartTime = nil
    M.hunterStartTime = nil
    M.waypoints = {}
    M.startpos = nil
    M.waypoint = 1
    M.dnf = {
        process = false,
        targetTime = nil,
        lastpos = nil,
        minDistance = .5,
        timeout = 10,
    }
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
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
    BJIGPS.reset()
    BJICam.addRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
end

-- unload hook
local function onUnload()
    -- cancel message processes
    BJIMessage.cancelFlash("BJIHuntedDNF")
    BJIMessage.cancelFlash("BJIHuntedStart")
    BJIMessage.cancelFlash("BJIHunterStart")

    BJIRaceWaypoint.resetAll()
    BJIGPS.reset()
    for _, veh in pairs(BJIContext.User.vehicles) do
        BJIVeh.focusVehicle(veh.gameVehID)
        BJIVeh.freeze(false, veh.gameVehID)
        break
    end
    BJICam.removeRestrictedCamera(BJICam.CAMERAS.FREE)
    BJICam.removeRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_ALL)
    BJIVehSelector.tryClose(true)
end

local function tryReplaceOrSpawn(model, config)
    local participant = M.participants[BJIContext.User.playerID]
    if M.state == M.STATES.PREPARATION and participant and not participant.ready then
        if table.length(BJIContext.User.vehicles) > 0 and not BJIVeh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        BJIVeh.replaceOrSpawnVehicle(model, config, M.startpos)
        BJIAsync.task(function(ctxt) return ctxt.isOwner end, function(ctxt)
            BJICam.addRestrictedCamera(BJICam.CAMERAS.FREE)
            BJICam.forceCamera(BJICam.CAMERAS.EXTERNAL)
            BJIVeh.freeze(true, ctxt.veh:getID())
        end, "BJIHunterReplaceOrSpawn")
    end
end

local function tryPaint(paint, paintNumber)
    local participant = M.participants[BJIContext.User.playerID]
    local veh = BJIVeh.getCurrentVehicleOwn()
    if veh and
        M.state == M.STATES.PREPARATION and
        participant and not participant.ready then
        BJIVeh.paintVehicle(paint, paintNumber)
        BJIVeh.freeze(true, veh:getID())
    end
end

local function getModelList()
    local models = {}
    local participant = M.participants[BJIContext.User.playerID]
    if M.state == M.STATES.PREPARATION and participant and not participant.ready then
        if participant.hunted and M.settings.huntedConfig then
            -- forced config
            return models
        elseif not participant.hunted and #M.settings.hunterConfigs > 0 then
            -- forced configs (spawned automatically or by hunter window)
            return models
        end

        models = BJIVeh.getAllVehicleConfigs(
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SPAWN_TRAILERS),
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SPAWN_PROPS)
        )

        if #BJIContext.Database.Vehicles.ModelBlacklist > 0 then
            for _, model in ipairs(BJIContext.Database.Vehicles.ModelBlacklist) do
                models[model] = nil
            end
        end
    end

    return models
end

local function canVehUpdate()
    local participant = M.participants[BJIContext.User.playerID]
    if M.state ~= M.STATES.PREPARATION or
        not participant or participant.ready then
        return false
    end

    if BJIVeh.isCurrentVehicleOwn() then
        local forcedConfig = false
        if participant.hunted and M.settings.huntedConfig then
            forcedConfig = true
        elseif not participant.hunted and #M.settings.hunterConfigs == 1 then
            forcedConfig = true
        end
        if forcedConfig then
            return false
        end
    end
    return true
end

local function canSpawnNewVehicle()
    return canVehUpdate() and table.length(BJIContext.User.vehicles) == 0
end

local function doShowNametag(vehData)
    if M.state == M.STATES.PREPARATION then
        -- no nametags during preparation
        return false
    elseif M.state == M.STATES.GAME then
        if M.participants[BJIContext.User.playerID].hunted then
            -- hunted do not see anyone
            return false
        else
            -- hunters can only see other hunters
            local target = M.participants[vehData.ownerID]
            return target and not target.hunted
        end
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    -- participants keep focus on their own vehicle
    local participant = M.participants[BJIContext.User.playerID]
    if not BJIVeh.isVehicleOwn(newGameVehID) and
        participant and
        (participant.gameVehID or table.length(BJIContext.User.vehicles) > 0) then
        local targetVehID = participant.gameVehID
        if not targetVehID then
            for _, v in pairs(BJIContext.User.vehicles) do
                targetVehID = v.gameVehID
                break
            end
        end
        if targetVehID then
            BJIVeh.focusVehicle(targetVehID)
        end
    end
end

local function onVehicleDeleted(gameVehID)
    local participant = M.participants[BJIContext.User.playerID]
    if BJIVeh.isVehicleOwn(gameVehID) and participant then
        if M.state == M.STATES.PREPARATION then
            if (participant.hunted and M.settings.huntedConfig) or
                (not participant.hunted and #M.settings.hunterConfigs == 1) then
                -- leave when forced preset
                BJITx.scenario.HunterUpdate(M.CLIENT_EVENTS.JOIN)
            end
        else
            BJITx.scenario.HunterUpdate(M.CLIENT_EVENTS.LEAVE)
        end
    end
end

local function onVehicleResetted(gameVehID)
    if BJIVeh.isVehicleOwn(gameVehID) then
        local participant = M.participants[BJIContext.User.playerID]
        if M.state == M.STATES.GAME and                    -- game started
            participant and not participant.hunted and     -- is hunter
            M.hunterStartTime < GetCurrentTimeMillis() and -- already started
            M.huntersRespawnDelay > 0 then                 -- minimum stuck delay configured
            BJIVeh.freeze(true, gameVehID)
            BJICam.forceCamera(BJICam.CAMERAS.EXTERNAL)
            BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_NONE)
            local targetTime = GetCurrentTimeMillis() + (M.huntersRespawnDelay * 1000) + 50
            BJIMessage.flashCountdown("BJIHunterReset", targetTime,
                false, BJILang.get("hunter.play.flashHunterResume"), M.huntersRespawnDelay, function()
                    BJICam.resetForceCamera()
                    BJIVeh.freeze(false, gameVehID)
                    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RECOVER_VEHICLE)
                end)
        end
    end
end

local function initPreparation(data)
    M.settings.waypoints = data.waypoints
    M.settings.huntedConfig = data.huntedConfig
    M.settings.hunterConfigs = data.hunterConfigs
    M.preparationTimeout = BJITick.applyTimeOffset(data.preparationTimeout)
    M.state = data.state
    BJIScenario.switchScenario(BJIScenario.TYPES.HUNTER)
end

local function onJoinParticipants(isHunted)
    local model, config
    M.startpos = nil
    if isHunted then
        -- generate start position
        local freepos
        while not M.startpos or not freepos do
            M.startpos = table.random(BJIContext.Scenario.Data.Hunter.huntedPositions)
            freepos = true
            for _, mpveh in pairs(BJIVeh.getMPVehicles()) do
                local v = BJIVeh.getVehicleObject(mpveh.gameVehicleID)
                local posrot = v and BJIVeh.getPositionRotation(v) or nil
                if posrot and posrot.pos:distance(vec3(M.startpos.pos)) < 2 then
                    freepos = false
                    break
                end
            end
        end

        -- generate waypoints to reach
        local function findNextWaypoint(pos)
            pos = vec3(pos)
            local wps = {}
            for _, wp in ipairs(table.clone(BJIContext.Scenario.Data.Hunter.targets)) do
                table.insert(wps, {
                    wp = {
                        pos = vec3(wp.pos),
                        radius = wp.radius,
                    },
                    distance = pos:distance(vec3(wp.pos)),
                })
            end
            table.sort(wps, function(a, b)
                return a.distance > b.distance
            end)
            local thresh = math.ceil(#wps / 2)
            while wps[thresh] do
                table.remove(wps, thresh)
            end
            return table.random(wps).wp
        end
        local previousPos = M.startpos.pos
        while #M.waypoints < M.settings.waypoints do
            if #M.waypoints > 0 then
                previousPos = M.waypoints[#M.waypoints].pos
            end
            table.insert(M.waypoints, findNextWaypoint(previousPos))
        end

        if M.settings.huntedConfig then
            -- forced config
            model, config = M.settings.huntedConfig.model, M.settings.huntedConfig.config
        else
            BJIMessage.flash("BJIHunterChooseVehicle", BJILang.get("hunter.play.flashChooseVehicle"), 3, false)
            BJIVehSelector.open(getModelList(), false)
        end
    else
        -- hunter
        -- generate start position
        local freepos
        while not M.startpos or not freepos do
            M.startpos = table.random(BJIContext.Scenario.Data.Hunter.hunterPositions)
            freepos = true
            for _, mpveh in pairs(BJIVeh.getMPVehicles()) do
                local v = BJIVeh.getVehicleObject(mpveh.gameVehicleID)
                local posrot = v and BJIVeh.getPositionRotation(v) or nil
                if posrot and posrot.pos:distance(vec3(M.startpos.pos)) < 2 then
                    freepos = false
                    break
                end
            end
        end

        if #M.settings.hunterConfigs == 1 then
            -- forced config
            model, config = M.settings.hunterConfigs[1].model, M.settings.hunterConfigs[1].config
        elseif #M.settings.hunterConfigs == 0 then
            BJIMessage.flash("BJIHunterChooseVehicle", BJILang.get("hunter.play.flashChooseVehicle"), 3, false)
            BJIVehSelector.open(getModelList(), false)
        end
    end

    -- when forced config
    if config then
        BJIAsync.task(function(ctxt)
            return M.canSpawnNewVehicle()
        end, function(ctxt)
            M.tryReplaceOrSpawn(model, config)
        end, "BJIHunterForcedConfigSpawn")
    end
end

local function onLeaveParticipants()
    M.waypoints = {}
    BJICam.resetForceCamera()
    if BJICam.getCamera() ~= BJICam.CAMERAS.FREE then
        BJICam.setCamera(BJICam.CAMERAS.FREE)
    end
    BJIVeh.deleteAllOwnVehicles()
    BJIVehSelector.tryClose(true)
end

local function updatePreparation(data)
    local wasParticipant = M.participants[BJIContext.User.playerID]
    local wasHunted = wasParticipant and wasParticipant.hunted or false
    M.participants = data.participants
    local participant = M.participants[BJIContext.User.playerID]
    if not wasParticipant and participant then
        onJoinParticipants(participant.hunted)
    elseif wasParticipant and not participant then
        onLeaveParticipants()
    elseif wasParticipant and participant and
        wasHunted ~= participant.hunted then
        -- role changed > reset vehicles then reload
        onLeaveParticipants()
        onJoinParticipants(participant.hunted)
    end
end

local function initGameHunted(participant)
    local function updateWP()
        -- current WP
        local wp = M.waypoints[M.waypoint]
        BJIRaceWaypoint.addWaypoint({
            name = "BJIHunter",
            pos = wp.pos,
            radius = wp.radius,
            color = BJIRaceWaypoint.COLORS.BLUE
        })
        -- next WP
        local nextWp = M.waypoints[M.waypoint + 1]
        if nextWp then
            BJIRaceWaypoint.addWaypoint({
                name = "BJIHunterNext",
                pos = nextWp.pos,
                radius = nextWp.radius,
                color = BJIRaceWaypoint.COLORS.BLACK
            })
        end

        BJIGPS.appendWaypoint(BJIGPS.KEYS.HUNTER, wp.pos, wp.radius, function()
            BJIRaceWaypoint.resetAll()
            BJITx.scenario.HunterUpdate(M.CLIENT_EVENTS.CHECKPOINT_REACHED)
            M.waypoint = M.waypoint + 1
            if M.waypoint <= #M.waypoints then
                updateWP()
            end
        end, nil, false)
    end

    local function start()
        updateWP()

        BJIMessage.flash("BJIHuntedStart", BJILang.get("hunter.play.flashHuntedStart"), 5, false)
        BJIVeh.freeze(false, participant.gameVehID)
        BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_NONE)
        BJICam.resetForceCamera()
        if BJICam.getCamera() == BJICam.CAMERAS.EXTERNAL then
            BJICam.setCamera(BJICam.CAMERAS.ORBIT)
        end
    end

    if M.huntedStartTime > GetCurrentTimeMillis() then
        BJIMessage.flashCountdown("BJIHuntedStart", M.huntedStartTime, false,
            nil, 5, start, true)
    else
        start()
    end
end

local function initGameHunter(participant)
    local function start()
        BJIMessage.flash("BJIHunterStart", BJILang.get("hunter.play.flashHunterResume"), 5, false)
        BJIVeh.freeze(false, participant.gameVehID)
        BJIRestrictions.updateReset(BJIRestrictions.TYPES.RECOVER_VEHICLE)
        BJICam.resetForceCamera()
        if BJICam.getCamera() == BJICam.CAMERAS.EXTERNAL then
            BJICam.setCamera(BJICam.CAMERAS.ORBIT)
        end
    end

    if M.hunterStartTime > GetCurrentTimeMillis() then
        BJIMessage.flashCountdown("BJIHunterStart", M.hunterStartTime, false,
            "", 5, start, true)
    else
        start()
    end
end

local function initGame(data)
    M.settings.waypoints = data.waypoints
    M.state = data.state
    M.participants = data.participants
    M.huntedStartTime = BJITick.applyTimeOffset(data.huntedStartTime)
    M.hunterStartTime = BJITick.applyTimeOffset(data.hunterStartTime)
    local participant = M.participants[BJIContext.User.playerID]
    if participant then
        BJIVehSelector.tryClose(true)
        if participant.hunted then
            initGameHunted(participant)
        else
            initGameHunter(participant)
        end
    end
end

local function updateGame(data)
    local wasParticipant = M.participants[BJIContext.User.playerID]
    M.participants = data.participants
    if wasParticipant and not M.participants[BJIContext.User.playerID] then
        onLeaveParticipants()
        -- own vehicle deletion will trigger switch to another participant
    end
end

-- receive hunter data from backend
local function rxData(data)
    M.MINIMUM_PARTICIPANTS = data.minimumParticipants
    M.huntersRespawnDelay = data.huntersRespawnDelay
    if data.state == M.STATES.PREPARATION then
        if not M.state then
            initPreparation(data)
        else
            updatePreparation(data)
        end
    elseif data.state == M.STATES.GAME then
        if M.state ~= M.STATES.GAME then
            initGame(data)
        else
            updateGame(data)
        end
    else
        if M.state then
            M.stop()
        end
    end
end

-- each second tick hook
local function slowTick(ctxt)
    local participant = M.participants[BJIContext.User.playerID]
    if ctxt.isOwner and
        M.state == M.STATES.GAME and
        participant and participant.hunted and
        M.huntedStartTime and M.huntedStartTime <= ctxt.now then
        if not M.dnf.lastpos then
            M.dnf.lastpos = ctxt.vehPosRot.pos
        else
            local distance = GetHorizontalDistance(M.dnf.lastpos, ctxt.vehPosRot.pos)
            if distance < M.dnf.minDistance then
                -- start countdown process
                if not M.dnf.process then
                    M.dnf.targetTime = ctxt.now + (M.dnf.timeout * 1000)
                    BJIMessage.flashCountdown("BJIHuntedDNF",
                        M.dnf.targetTime,
                        true, "", 10, function()
                            BJICam.removeRestrictedCamera(BJICam.CAMERAS.FREE)
                            BJITx.scenario.HunterUpdate(M.CLIENT_EVENTS.ELIMINATED)
                            BJITx.player.explodeVehicle(participant.gameVehID)
                        end, false)
                    M.dnf.process = true
                end
            else
                -- good distance, remove countdown if there is one
                if M.dnf.process then
                    BJIMessage.cancelFlash("BJIHuntedDNF")
                    M.dnf.process = false
                    M.dnf.targetTime = nil
                end
                M.dnf.lastpos = ctxt.vehPosRot.pos
            end
        end
    end
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad
M.onUnload = onUnload

M.trySpawnNew = tryReplaceOrSpawn
M.tryReplaceOrSpawn = tryReplaceOrSpawn
M.tryPaint = tryPaint
M.getModelList = getModelList
M.canSelectVehicle = canVehUpdate
M.canSpawnNewVehicle = canSpawnNewVehicle
M.canReplaceVehicle = canVehUpdate
M.canDeleteVehicle = function() return false end
M.canDeleteOtherVehicles = function() return false end
M.canEditVehicle = function() return false end
M.doShowNametag = doShowNametag

M.onVehicleSwitched = onVehicleSwitched
M.onVehicleDeleted = onVehicleDeleted
M.onVehicleResetted = onVehicleResetted

M.rxData = rxData

M.slowTick = slowTick

M.stop = stop

return M
