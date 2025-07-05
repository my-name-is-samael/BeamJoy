---@class BJIScenarioDerby : BJIScenario
local S = {
    _name = "Derby",
    _key = "DERBY",
    _isSolo = false,

    MINIMUM_PARTICIPANTS = 3,
    CLIENT_EVENTS = {
        JOIN = "Join",           -- preparation
        READY = "Ready",         -- preparation
        LEAVE = "Leave",         -- game
        DESTROYED = "Destroyed", -- game
    },
    STATES = {
        PREPARATION = 1, -- time when all players choose cars and mark ready
        GAME = 2,        -- time during game / spectate
    },

    -- server data
    ---@type integer?
    state = nil,
    destroyedTimeout = 5,
    preparationTimeout = nil,
    ---@type integer?
    startTime = nil,
    ---@type integer?
    zoneReductionTime = nil,
    ---@type BJIDerbyParticipant[]
    participants = {},
    ---@type BJArena?
    baseArena = nil,
    configs = {},

    -- self data
    preDerbyCam = nil,
    resetLock = true,
    destroy = {
        distanceThreshold = .1,
        process = false,
        lastPos = nil,
        targetTime = nil,
        lock = false,
    },
}
--- gc prevention
local actions, veh

local function stop()
    S.state = nil
    S.preparationTimeout = nil
    S.startTime = nil
    S.participants = {}
    S.baseArena = nil

    S.resetLock = true
    S.destroy.process = false
    S.destroy.lastPos = nil
    S.destroy.targetTime = nil
    S.destroy.lock = false

    BJI.Managers.Message.cancelFlash("BJIDerbyStart")
    BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")

    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return true
end

-- load hook
local function onLoad(ctxt)
    if S.state == S.STATES.PREPARATION then
        -- not on join during match
        if ctxt.isOwner then
            S.preDerbyCam = ctxt.camera
            if table.includes({
                    BJI.Managers.Cam.CAMERAS.FREE,
                    BJI.Managers.Cam.CAMERAS.BIG_MAP,
                    BJI.Managers.Cam.CAMERAS.EXTERNAL
                }, S.preDerbyCam) then
                S.preDerbyCam = BJI.Managers.Cam.CAMERAS.ORBIT
            end
        else
            S.preDerbyCam = BJI.Managers.Cam.CAMERAS.ORBIT
        end
        BJI.Managers.Veh.deleteAllOwnVehicles()
        BJI.Windows.VehSelector.tryClose(true)
        BJI.Managers.GPS.reset()
    end
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")
    BJI.Managers.Async.removeTask("BJIDerbyResetLockSafe")
    BJI.Managers.Async.removeTask("BJIDerbyPostResetRestrictionsResetsUpdate")
    BJI.Managers.Async.removeTask("BJIDerbyPostEliminationSwitch")

    BJI.Managers.Veh.getMPVehicles({ isAi = false }, true):forEach(function(v)
        BJI.Managers.Minimap.toggleVehicle({ veh = v.veh, state = true })
        BJI.Managers.Veh.toggleVehicleFocusable({ veh = v.veh, state = true })
    end)

    BJI.Managers.Cam.resetRestrictedCameras()
    BJI.Managers.Cam.resetForceCamera(true)
    if ctxt.isOwner then
        BJI.Managers.Veh.freeze(false)
        if ctxt.camera == BJI.Managers.Cam.CAMERAS.EXTERNAL then
            ctxt.camera = BJI.Managers.Cam.CAMERAS.ORBIT
            BJI.Managers.Cam.setCamera(ctxt.camera)
        end
    end
    BJI.Windows.VehSelector.tryClose(true)

    Table(ctxt.user.vehicles):find(TrueFn, function(v)
        BJI.Managers.Veh.focusVehicle(v.gameVehID)
    end)
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    local participant = S.getParticipant()
    local res = Table()
        :addAll(BJI.Managers.Restrictions.OTHER.BIG_MAP, true)
        :addAll(BJI.Managers.Restrictions.OTHER.FUN_STUFF, true)
    if S.state == S.STATES.PREPARATION then
        if participant then
            res:addAll(BJI.Managers.Restrictions.OTHER.FREE_CAM, true)
                :addAll(BJI.Managers.Restrictions.OTHER.PHOTO_MODE, true)
        end
    else
        if participant and not participant.eliminationTime then
            res:addAll(BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH, true)
                :addAll(BJI.Managers.Restrictions.OTHER.FREE_CAM, true)
                :addAll(BJI.Managers.Restrictions.OTHER.PHOTO_MODE, true)
        end
    end
    return res
end

---@param ctxt TickContext
local function postSpawn(ctxt)
    if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.DERBY) then
        BJI.Managers.Cam.forceCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
        BJI.Managers.Veh.freeze(true, ctxt.veh.gameVehicleID)
        if not BJI.Windows.VehSelector.show then
            BJI.Windows.VehSelector.open(false)
        end
    end
end

local function tryReplaceOrSpawn(model, config)
    local participant = S.getParticipant()
    if S.state == S.STATES.PREPARATION and participant and not participant.ready then
        if table.length(BJI.Managers.Context.User.vehicles) > 0 and not BJI.Managers.Veh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        local startPos = S.baseArena.startPositions[participant.startPosition]
        BJI.Managers.Veh.replaceOrSpawnVehicle(model, config, startPos)
        BJI.Managers.Veh.waitForVehicleSpawn(
            function(ctxt)
                BJI.Managers.Veh.saveHome(startPos)
                postSpawn(ctxt)
            end)
    end
end

---@param mpVeh BJIMPVehicle
local function onVehicleSpawned(mpVeh)
    local participant = S.getParticipant()
    if mpVeh.isLocal and S.state == S.STATES.PREPARATION and participant and not participant.ready then
        local startPos = S.baseArena.startPositions[participant.startPosition]
        if startPos and mpVeh.position:distance(startPos.pos) > 1 then
            -- spawned via basegame vehicle selector
            BJI.Managers.Veh.setPositionRotation(startPos.pos, startPos.rot, { safe = false })
            BJI.Managers.Veh.waitForVehicleSpawn(function(ctxt)
                BJI.Managers.Veh.saveHome(startPos)
                postSpawn(ctxt)
            end)
        end
    end
end

local function tryPaint(paintIndex, paint)
    local participant = S.getParticipant()
    local veh = BJI.Managers.Veh.getCurrentVehicleOwn()
    if veh and S.state == S.STATES.PREPARATION and participant and not participant.ready then
        BJI.Managers.Veh.paintVehicle(veh, paintIndex, paint)
    end
end

---@return table<string, table>?
local function getModelList()
    local participant = S.getParticipant()
    if S.state ~= S.STATES.PREPARATION or
        not participant or participant.ready then
        return    -- veh selector should not be opened
    elseif #S.configs > 0 then
        return {} -- only paints
    end

    local models = BJI.Managers.Veh.getAllVehicleConfigs()

    if #BJI.Managers.Context.Database.Vehicles.ModelBlacklist > 0 then
        for _, model in ipairs(BJI.Managers.Context.Database.Vehicles.ModelBlacklist) do
            models[model] = nil
        end
    end
    return models
end

local function switchToRandomParticipant()
    local gameVehID = Table(S.participants)
        :filter(function(p) return not S.isEliminated(p.playerID) end)
        :map(function(p)
            local veh = BJI.Managers.Veh.getVehicleObject(p.gameVehID)
            return veh and veh:getID() or nil
        end):random()
    if gameVehID then
        BJI.Managers.Veh.focusVehicle(gameVehID)
    end
end

---@return boolean
local function canSpawnNewVehicle()
    local participant = S.getParticipant()
    return S.state == S.STATES.PREPARATION and participant ~= nil and not participant.ready and
        table.length(BJI.Managers.Context.User.vehicles) == 0
end

---@return boolean
local function canVehUpdate()
    local participant = S.getParticipant()
    if S.state ~= S.STATES.PREPARATION or not participant or participant.ready or
        not BJI.Managers.Veh.isCurrentVehicleOwn() then
        return false
    end

    return #S.configs ~= 1
end

---@return boolean
local function canPaintVehicle()
    local participant = S.getParticipant()
    return S.state == S.STATES.PREPARATION and participant ~= nil and not participant.ready and
        BJI.Managers.Veh.isCurrentVehicleOwn()
end

---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    return S.isParticipant(vehData.ownerID) and not S.isEliminated(vehData.ownerID)
end

-- player list contextual actions getter
---@param player BJIPlayer
---@param ctxt TickContext
local function getPlayerListActions(player, ctxt)
    actions = {}

    if S.isSpec() and not S.isSpec(player.playerID) then
        ---@type BJIMPVehicle?
        veh = BJI.Managers.Veh.getMPVehicles({ ownerID = player.playerID }, true):find(TrueFn)
        if veh then
            table.insert(actions, {
                id = string.var("focus{1}", { player.playerID }),
                icon = BJI.Utils.Icon.ICONS.visibility,
                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                disabled = ctxt.veh and ctxt.veh.gameVehicleID == veh.gameVehicleID,
                tooltip = BJI.Managers.Lang.get("common.buttons.show"),
                onClick = function()
                    BJI.Managers.Veh.focusVehicle(veh.gameVehicleID)
                end
            })
        end
    end

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

---@param ctxt TickContext
---@return boolean?
local function tryRespawn(ctxt)
    local participant = S.getParticipant()
    if participant and participant.lives > 0 and not S.resetLock then
        BJI.Managers.Veh.loadHome()
        S.resetLock = true
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
        BJI.Managers.Async.delayTask(function() -- 1 sec reset lock safe
            S.resetLock = false
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
        end, 1000, "BJIDerbyResetLockSafe")

        BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")
        BJI.Tx.scenario.DerbyUpdate(S.CLIENT_EVENTS.DESTROYED)
        local msg
        if participant.lives == 1 then
            msg = BJI.Managers.Lang.get("derby.play.flashNoLifeRemaining")
        elseif participant.lives == 2 then
            msg = BJI.Managers.Lang.get("derby.play.flashLifeRemaining"):var({
                lives = participant.lives - 1
            })
        else
            msg = BJI.Managers.Lang.get("derby.play.flashLivesRemaining"):var({
                lives = participant.lives - 1
            })
        end
        BJI.Managers.Message.flash("BJIDerbyRemainingLives", msg, 3, false)
        return true
    end
end

local function getZoneRadius(ctxt)
    if not S.startTime or not S.zoneReductionTime then
        return S.baseArena.radius
    end
    return math.scale(ctxt.now, S.startTime, S.zoneReductionTime, S.baseArena.radius, 5, true)
end

---@param ctxt TickContext
local function renderTick(ctxt)
    if S.startTime then
        local bottomPos = vec3(S.baseArena.centerPosition)
        bottomPos.z = bottomPos.z - S.baseArena.radius / 2
        local topPos = vec3(S.baseArena.centerPosition)
        topPos.z = topPos.z + 200
        BJI.Utils.ShapeDrawer.Cylinder(bottomPos, topPos, getZoneRadius(ctxt),
            BJI.Utils.ShapeDrawer.Color(.33, .33, 1, .15))
    end
end

---@param ctxt TickContext
local function isVehInZone(ctxt)
    return math.horizontalDistance(ctxt.veh.position, S.baseArena.centerPosition) <= getZoneRadius(ctxt) and
        ctxt.veh.position.z >= S.baseArena.centerPosition.z - S.baseArena.radius / 2
end

---@param ctxt TickContext
local function fastTick(ctxt)
    local participant = S.getParticipant()
    if participant and not S.isEliminated() and ctxt.isOwner then
        if S.state == S.STATES.GAME and S.startTime and ctxt.now > S.startTime and S.destroy.process then
            local cancelProcess = false
            if S.participants[2] and S.participants[2].eliminationTime then
                -- game is over
                cancelProcess = true
            elseif S.isEliminated() then
                -- when self eliminated
                cancelProcess = true
            else
                local dist = S.destroy.lastPos and ctxt.veh.position:distance(S.destroy.lastPos) or nil
                local moved = dist ~= nil and dist > S.destroy.distanceThreshold * 10
                local inZone = isVehInZone(ctxt)
                if moved and inZone then
                    -- self moved enough and inZone
                    cancelProcess = true
                end
            end
            if cancelProcess then
                BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")
                S.destroy.process = false
                S.destroy.targetTime = nil
            end
        end
    end
end

-- Destroy process is detected through slowTick, then checked through renderTick
---@param ctxt TickContext
local function slowTick(ctxt)
    local participant = S.getParticipant()
    local isDNFProcessAvail = not S.destroy.process and not S.destroy.lock
    local gameStarted = S.startTime and ctxt.now > S.startTime
    local validParticipant = participant and not S.isEliminated()
    local gameNotOver = not S.participants[2] or not S.participants[2].eliminationTime
    if S.state == S.STATES.GAME and ctxt.isOwner and isDNFProcessAvail and
        gameStarted and validParticipant and gameNotOver then
        local dist = S.destroy.lastPos and ctxt.veh.position:distance(S.destroy.lastPos) or nil
        local notMoved = dist and dist < S.destroy.distanceThreshold * 10
        local outOfZone = not isVehInZone(ctxt)
        if notMoved or outOfZone then
            S.destroy.targetTime = ctxt.now + (S.destroyedTimeout * 1000) + 50
            S.destroy.process = true
            BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")
            BJI.Managers.Message.flashCountdown("BJIDerbyDestroy", S.destroy.targetTime, false, nil, nil,
                function()
                    participant = S.getParticipant()
                    if participant then
                        BJI.Tx.scenario.DerbyUpdate(S.CLIENT_EVENTS.DESTROYED)
                        if participant.lives > 0 then
                            BJI.Managers.Veh.loadHome()
                        end
                        S.destroy.process = false
                        S.destroy.targetTime = nil
                        S.destroy.lastPos = nil
                        S.destroy.lock = true
                        S.resetLock = true
                        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
                        BJI.Managers.Async.task(function()
                            -- wait for data update before unlocking destroy process
                            local updated = S.getParticipant()
                            return participant.lives == 0 and S.isEliminated() or
                                (type(updated) == "table" and updated.lives == participant.lives - 1)
                        end, function()
                            S.destroy.lock = false
                            S.resetLock = participant.lives < 2 -- do not release if no more life or eliminated
                            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
                        end, "BJIDerbyDestroyLockSafe")
                    end
                end)
        end
        if not S.destroy.lastPos or not S.destroy.process then
            S.destroy.lastPos = ctxt.veh.position
        end
    end
end

local function initPreparation(data)
    S.startTime = BJI.Managers.Tick.applyTimeOffset(data.startTime)
    S.state = data.state
    S.baseArena = data.baseArena
    S.configs = data.configs
    S.participants = data.participants
    S.preparationTimeout = BJI.Managers.Tick.applyTimeOffset(data.preparationTimeout)
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.DERBY)

    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
    BJI.Managers.Cam.setPositionRotation(S.baseArena.previewPosition.pos, S.baseArena.previewPosition.rot)
end

local function onJoinParticipants()
    if #S.configs == 0 then
        BJI.Windows.VehSelector.open(false)
    elseif #S.configs == 1 then
        BJI.Managers.Async.task(function()
            return BJI.Managers.VehSelectorUI.stateSelector
        end, function()
            S.trySpawnNew(S.configs[1].model, S.configs[1])
        end)
    end
end

local function onLeaveParticipants()
    BJI.Managers.UI.hideGameMenu()
    BJI.Windows.VehSelector.tryClose(true)
    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
    BJI.Managers.Cam.setPositionRotation(S.baseArena.previewPosition.pos, S.baseArena.previewPosition.rot)
    BJI.Managers.Veh.deleteAllOwnVehicles()
end

local function onReady()
    BJI.Windows.VehSelector.tryClose(true)
end


local function updatePreparation(data)
    local wasParticipant = S.getParticipant()
    local wasReady = wasParticipant and wasParticipant.ready or false
    S.participants = data.participants
    S.preparationTimeout = BJI.Managers.Tick.applyTimeOffset(data.preparationTimeout)

    local participant = S.getParticipant()
    if not wasParticipant and participant then
        onJoinParticipants()
        BJI.Managers.Restrictions.update()
    elseif wasParticipant and not participant then
        onLeaveParticipants()
        BJI.Managers.Restrictions.update()
    elseif not wasReady and participant and participant.ready then
        onReady()
        BJI.Managers.Restrictions.update()
    end
end

local function initGame(data)
    BJI.Windows.VehSelector.tryClose(true)
    S.state = data.state
    S.baseArena = data.baseArena
    S.startTime = BJI.Managers.Tick.applyTimeOffset(data.startTime)
    S.zoneReductionTime = BJI.Managers.Tick.applyTimeOffset(data.zoneReductionTime)
    S.participants = data.participants
    if not BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.DERBY) then
        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.DERBY)
    end
    BJI.Managers.Cam.resetForceCamera()

    local now = GetCurrentTimeMillis()

    local function onStart()
        if now - 1000 <= S.startTime then
            BJI.Managers.Message.flash("BJIDerbyStart", BJI.Managers.Lang.get("derby.play.flashStart"), 3, true)
        end
        local participant = S.getParticipant()
        if participant then
            BJI.Managers.Veh.freeze(false)
            S.resetLock = participant.lives == 0
        end
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
    end

    if now < S.startTime then
        local participant = S.getParticipant()
        BJI.Managers.Async.programTask(function(ctxt)
            if participant then
                if ctxt.camera == BJI.Managers.Cam.CAMERAS.EXTERNAL then
                    BJI.Managers.Cam.setCamera(S.preDerbyCam)
                end
            else
                -- spec
                if not ctxt.veh then
                    switchToRandomParticipant()
                end
            end
        end, S.startTime - 3000, "BJIDerbyPreStart")
        BJI.Managers.Message.flashCountdown("BJIDerbyStart", S.startTime, true, nil, 5, onStart, true)
    else
        BJI.Managers.Cam.setCamera(S.preDerbyCam)
        onStart()
    end
end

local function onElimination()
    local participant, pos = S.getParticipant()
    if participant then
        S.resetLock = true
        if participant.gameVehID then
            BJI.Tx.player.explodeVehicle(participant.gameVehID)
        else
            for _, v in pairs(BJI.Managers.Context.User.vehicles) do
                local veh = BJI.Managers.Veh.getVehicleObject(v.gameVehID)
                if veh then
                    BJI.Tx.player.explodeVehicle(veh:getID())
                end
            end
        end
        if pos > 2 then
            BJI.Managers.Message.flash("BJIDerbyElimination", BJI.Managers.Lang.get("derby.play.flashElimination"), 3,
                false)
        end
        BJI.Managers.Async.delayTask(switchToRandomParticipant, 3000, "BJIDerbyPostEliminationSwitch")
    end
end

local function updateGame(data)
    local wasEliminated = S.isEliminated()
    S.participants = data.participants

    if not wasEliminated and S.isEliminated() then
        onElimination()
        BJI.Managers.Restrictions.update()
    end

    ---@param v BJIMPVehicle
    BJI.Managers.Veh.getMPVehicles(nil, true):forEach(function(v)
        if S.isEliminated(v.ownerID) then
            BJI.Managers.Minimap.toggleVehicle({ veh = v.veh, state = false })
            BJI.Managers.Veh.toggleVehicleFocusable({ veh = v.veh, state = false })
        end
    end)
end

local function rxData(data)
    S.MINIMUM_PARTICIPANTS = data.minimumParticipants
    if data.state then
        if data.state == S.STATES.PREPARATION then
            if not S.state then
                initPreparation(data)
            elseif S.state == S.STATES.PREPARATION then
                updatePreparation(data)
            end
        elseif data.state == S.STATES.GAME then
            if S.state ~= S.STATES.GAME then
                initGame(data)
                BJI.Managers.Restrictions.update()
            else
                updateGame(data)
            end
        end
    else
        if S.state then
            S.stop()
        end
    end
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

---@param playerID? integer
---@return BJIDerbyParticipant?, integer?
local function getParticipant(playerID)
    playerID = playerID or BJI.Managers.Context.User.playerID
    for i, p in ipairs(S.participants) do
        if p.playerID == playerID then
            return p, i
        end
    end
    return nil, nil
end

---@param playerID? integer
---@return boolean
local function isParticipant(playerID)
    local participant = S.getParticipant(playerID)
    return not not participant
end

---@param playerID? integer
---@return boolean
local function isEliminated(playerID)
    local participant = S.getParticipant(playerID)
    return participant ~= nil and participant.eliminationTime ~= nil
end

---@param playerID? integer
---@return boolean
local function isSpec(playerID)
    return not S.isParticipant(playerID) or S.isEliminated(playerID)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

S.trySpawnNew = tryReplaceOrSpawn
S.tryReplaceOrSpawn = tryReplaceOrSpawn
S.tryPaint = tryPaint
S.getModelList = getModelList

S.canSpawnNewVehicle = canSpawnNewVehicle
S.canReplaceVehicle = canVehUpdate
S.canPaintVehicle = canPaintVehicle
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.getCollisionsType = function() return BJI.Managers.Collisions.TYPES.FORCED end
S.doShowNametag = doShowNametag

S.getPlayerListActions = getPlayerListActions

S.onVehicleSpawned = onVehicleSpawned
S.saveHome = tryRespawn
S.loadHome = tryRespawn
S.renderTick = renderTick
S.fastTick = fastTick
S.slowTick = slowTick

S.rxData = rxData
S.getParticipant = getParticipant
S.isParticipant = isParticipant
S.isEliminated = isEliminated
S.isSpec = isSpec

S.stop = stop

return S
