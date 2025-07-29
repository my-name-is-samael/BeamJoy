---@class BJIScenarioInfected : BJIScenario
local S = {
    _name = "Infected",
    _key = "INFECTED",
    _isSolo = false,

    MINIMUM_PARTICIPANTS = 3,
    STATES = {
        PREPARATION = 1,
        GAME = 2,
    },
    CLIENT_EVENTS = {
        JOIN = "join",
        READY = "ready",
        LEAVE = "leave",
        INFECTION = "infection",
    },

    settings = {
        endAfterLastSurvivorInfected = false,
        ---@type ClientVehicleConfig?
        config = nil,
        enableColors = false,
        ---@type BJIColor?
        survivorsColor = nil,
        defaultSurvivorsColor = BJI.Utils.ShapeDrawer.Color(.33, 1, .33),
        ---@type BJIColor?
        infectedColor = nil,
        defaultInfectedColor = BJI.Utils.ShapeDrawer.Color(1, 0, 0),
    },

    -- server data
    state = nil,
    ---@type tablelib<integer, BJIInfectedParticipant>
    participants = {},
    preparationTimeout = nil,
    ---@type integer?
    survivorsStartTime = nil,
    ---@type integer?
    infectedStartTime = nil,
    finished = false,

    -- client data
    previousCamera = nil,
    ---@type number?
    selfDiag = nil,
    ---@type tablelib<integer, {playerID: integer, veh: NGVehicle, diag: number}> index gameVehID
    survivors = Table(),
    ---@type integer[] gameVehIDs
    closeSurvivors = {},
    resetLock = true,
}
--- gc prevention
local actions, participant, pos, selfDiag, diag

local function stop()
    S.state = nil
    S.participants = {}
    S.preparationTimeout = nil
    S.survivorsStartTime = nil
    S.infectedStartTime = nil
    S.selfDiag = nil
    S.survivors = Table()
    S.closeSurvivors = {}
    S.resetLock = true
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
end

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

---@param ctxt TickContext
local function onUnload(ctxt)
    BJI_Async.removeTask("BJIInfectedResetLockSafe")
    BJI_Message.cancelFlash("BJIInfectedStart")
    BJI_Async.removeTask("BJIInfectedStart")
    BJI_Async.removeTask("BJIInfectedPrestart")

    BJI_Veh.getMPVehicles({ isAi = false }, true):forEach(function(v)
        BJI_Veh.toggleVehicleFocusable({ veh = v.veh, state = true })
    end)

    BJI_GPS.reset()
    for _, veh in pairs(ctxt.user.vehicles) do
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
    participant = S.participants[ctxt.user.playerID]
    local res = Table():addAll(BJI_Restrictions.OTHER.FUN_STUFF, true)
    if S.state == S.STATES.PREPARATION then
        if participant then
            res:addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
                :addAll(BJI_Restrictions.OTHER.CAMERA_CHANGE, true)
                :addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
                :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
                :addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
        end
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

---@param ctxt TickContext
local function postSpawn(ctxt)
    if BJI_Scenario.is(BJI_Scenario.TYPES.INFECTED) then
        BJI_Veh.freeze(true, ctxt.veh.gameVehicleID)
        BJI_Restrictions.update()
        BJI_Cam.setCamera(BJI_Cam.CAMERAS.EXTERNAL)
        if not BJI_Win_VehSelector.show and not S.settings.enableColors then
            BJI_Win_VehSelector.open(false)
        end
    end
end

---@param model string
---@param config table
local function tryReplaceOrSpawn(model, config)
    participant = S.participants[BJI_Context.User.playerID]
    if S.state == S.STATES.PREPARATION and participant and not participant.ready then
        if table.length(BJI_Context.User.vehicles) > 0 and not BJI_Veh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        local startPos = participant.originalInfected and
            BJI_Scenario.Data.HunterInfected.minorPositions[participant.startPosition] or
            BJI_Scenario.Data.HunterInfected.majorPositions[participant.startPosition]
        BJI_Cam.resetForceCamera()
        BJI_Veh.replaceOrSpawnVehicle(model, config, startPos)
        BJI_Veh.waitForVehicleSpawn(postSpawn)
    end
end

---@param paintIndex integer
---@param paint NGPaint
local function tryPaint(paintIndex, paint)
    participant = S.participants[BJI_Context.User.playerID]
    local veh = BJI_Veh.getCurrentVehicleOwn()
    if veh and S.state == S.STATES.PREPARATION and
        participant and not participant.ready and
        not S.settings.enableColors then
        BJI_Veh.paintVehicle(veh, paintIndex, paint)
    end
end

local function canRecoverVehicle()
    local ctxt = BJI_Tick.getContext()
    participant = S.participants[ctxt.user.playerID]
    return S.state == S.STATES.GAME and participant and not S.resetLock and
        (participant.originalInfected and S.infectedStartTime or S.survivorsStartTime) < ctxt.now
end

---@return table<string, table>?
local function getModelList()
    local participant = S.participants[BJI_Context.User.playerID]
    if S.state ~= S.STATES.PREPARATION or not participant or participant.ready then
        return -- veh selector should not be opened
    end

    if S.settings.config and S.settings.enableColors then
        return -- veh selector should not be opened
    end

    if S.settings.config then
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

    return not S.settings.config
end

local function canPaintVehicle()
    return not S.settings.enableColors
end

---@param vehData BJIMPVehicle
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if S.participants[vehData.ownerID] then
        if S.isInfected(vehData.ownerID) then
            return true, S.settings.infectedColor or S.settings.defaultInfectedColor,
                BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5)
        else
            return true, S.settings.survivorsColor or S.settings.defaultSurvivorsColor,
                BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5)
        end
    end
    return false
end

---@param mpVeh BJIMPVehicle
local function onVehicleSpawned(mpVeh)
    participant = S.participants[BJI_Context.User.playerID]
    if mpVeh.isLocal and S.state == S.STATES.PREPARATION and participant and not participant.ready then
        local startPos = participant.originalInfected and
            BJI_Scenario.Data.HunterInfected.minorPositions[participant.startPosition] or
            BJI_Scenario.Data.HunterInfected.majorPositions[participant.startPosition]
        if mpVeh.position:distance(startPos.pos) > 1 then
            -- spawned via basegame vehicle selector
            BJI_Veh.setPositionRotation(startPos.pos, startPos.rot, { safe = false })
            BJI_Veh.waitForVehicleSpawn(postSpawn)
        end
    end
end

---@param gameVehID integer
local function onVehicleResetted(gameVehID)
    participant = S.participants[BJI_Context.User.playerID]
    if S.state == S.STATES.GAME and participant and (participant.originalInfected and
            S.infectedStartTime or S.survivorsStartTime) < GetCurrentTimeMillis() and
        not S.finished and BJI_Veh.isVehicleOwn(gameVehID) then
        S.resetLock = true
        BJI_Restrictions.update()

        BJI_Async.delayTask(function()
            S.resetLock = false
            BJI_Restrictions.update()
        end, 1000, "BJIInfectedResetLockSafe")
    end
end

local function initPreparation(data)
    S.settings.config = data.config
    S.state = data.state
    S.participants = data.participants
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.INFECTED)
end

---@param participant BJIInfectedParticipant
local function onJoinParticipants(participant)
    local ownVeh = BJI_Veh.isCurrentVehicleOwn()
    -- when forced config
    if ownVeh then
        -- already spawned (probably team switch)
        BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE)
        BJI_Veh.deleteCurrentOwnVehicle()
        BJI_Async.delayTask(function() onJoinParticipants(participant) end, 250, "BJIInfectedSwitchTeam")
        return
    end

    local model, config
    if S.settings.config then
        -- forced config
        model, config = S.settings.config.model, S.settings.config
    else
        BJI_Message.flash("BJIInfectedChooseVehicle",
            BJI_Lang.get("infected.play.flashChooseVehicle"),
            3, false)
        BJI_Win_VehSelector.open(false)
    end
    if config then
        BJI_Async.task(function()
            return BJI_VehSelectorUI.stateSelector
        end, function()
            S.trySpawnNew(model, config)
        end, "BJIInfectedForcedConfigSpawn")
    end
    BJI_Restrictions.update()
end

local function onLeaveParticipants()
    if S.state == S.STATES.PREPARATION then
        BJI_Win_VehSelector.tryClose(true)
    end
    BJI_Veh.deleteAllOwnVehicles()
    BJI_Restrictions.update()
end

local function updatePreparation(data)
    local wasParticipant = S.participants[BJI_Context.User.playerID]
    local wasInfected = wasParticipant and wasParticipant.originalInfected
    S.participants = data.participants
    participant = S.participants[BJI_Context.User.playerID]
    if not wasParticipant and participant then
        onJoinParticipants(participant)
    elseif wasParticipant and not participant then
        onLeaveParticipants()
        BJI_Win_VehSelector.tryClose(true)
    elseif wasParticipant and participant and
        wasInfected ~= participant.originalInfected then
        -- role changed > update position
        onJoinParticipants(participant)
    end
end

local function initSurvivorsVehs()
    S.survivors = table.filter(S.participants, function(p)
        return not p.originalInfected
    end):reduce(function(res, p, pid)
        local veh = BJI_Veh.getVehicleObject(p.gameVehID)
        if veh then
            res[veh:getID()] = {
                playerID = pid,
                veh = veh,
                diag = math.sqrt((veh:getInitialLength() / 2) ^ 2 + (veh:getInitialWidth() / 2) ^ 2)
            }
        end
        return res
    end, Table())
end

---@param participant BJIInfectedParticipant
local function tryApplyScenarioColor(participant)
    if S.settings.enableColors then
        local color = (participant.originalInfected or participant.infectionTime) and
            S.settings.infectedColor or S.settings.survivorsColor
        local veh = BJI_Veh.getVehicleObject(participant.gameVehID)
        if color and veh then
            ---@type NGPaint
            local ngColor = {
                baseColor = { color.r, color.g, color.b, color.a },
                metallic = .5,
                roughness = .5,
                clearCoat = .5,
                clearCoatRoughness = .5,
            }
            for i = 1, 3 do
                BJI_Veh.paintVehicle(veh, i, ngColor)
            end
        end
    end
end

---@param veh NGVehicle?
local function initSelfDiag(veh)
    if veh then
        S.selfDiag = math.sqrt((veh:getInitialLength() / 2) ^ 2 + (veh:getInitialWidth() / 2) ^ 2)
    end
end

---@param participant BJIInfectedParticipant
local function initGameParticipant(participant)
    local function preStart()
        BJI_Cam.setCamera(S.previousCamera)
        if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.EXTERNAL then
            BJI_Cam.setCamera(S.previousCamera or BJI_Cam.CAMERAS.ORBIT)
        end

        initSurvivorsVehs()
        initSelfDiag(BJI_Veh.getCurrentVehicleOwn())
        if participant.originalInfected and S.survivors:length() == 1 then -- DEBUG should not append (min 3 players)
            S.survivors:find(TrueFn, function(p, vid)
                BJI_GPS.prependWaypoint({
                    key = BJI_GPS.KEYS.VEHICLE,
                    gameVehID = vid,
                    radius = 0,
                    clearable = false,
                })
            end)
        end
    end
    local function start()
        local flashKey = participant.originalInfected and "infected.play.flashInfectedStart" or
            "infected.play.flashSurvivorStart"
        BJI_Message.flash("BJIInfectedStart", BJI_Lang.get(flashKey), 5, false)
        BJI_Veh.freeze(false, participant.gameVehID)
        S.resetLock = false
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
    end

    local veh = BJI_Veh.getCurrentVehicleOwn()
    if veh and tonumber(veh.damageState) and
        tonumber(veh.damageState) >= 1 then
        BJI_Veh.recoverInPlace(postSpawn)
    end
    local startTime = tonumber(participant.originalInfected and S.infectedStartTime or S.survivorsStartTime) or 0
    if startTime > GetCurrentTimeMillis() then
        BJI_Async.programTask(preStart, startTime - 3000, "BJIInfectedPrestart")
        BJI_Message.flashCountdown("BJIInfectedStart", startTime, false, nil, 5, start, true)
    else
        preStart()
        start()
    end

    tryApplyScenarioColor(participant)
end

local function switchToRandomParticipant()
    if S.participants[BJI_Context.User.playerID] then return end

    local part = table.random(S.participants)
    if part then
        BJI_Veh.focus(S.participants:indexOf(part) or 0)
    end
end

local function initGame(data)
    S.state = data.state
    S.participants = data.participants
    S.survivorsStartTime = BJI_Tick.applyTimeOffset(data.survivorsStartTime)
    S.infectedStartTime = BJI_Tick.applyTimeOffset(data.infectedStartTime)

    participant = S.participants[BJI_Context.User.playerID]
    BJI_Win_VehSelector.tryClose(true)
    if participant then
        initGameParticipant(participant)
    else
        -- spec start
        if not BJI_Veh.getCurrentVehicle() then
            switchToRandomParticipant()
            BJI_Cam.setCamera(S.previousCamera)
        end
    end

    if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
        BJI_Cam.toggleFreeCam()
    end
    BJI_Restrictions.update()
end

local function updateSurvivorsVehs()
    S.survivors:forEach(function(p, vid)
        if S.participants[p.playerID].infectionTime then
            S.survivors[vid] = nil
            S.closeSurvivors = table.filter(S.survivors, function(cvid) return cvid ~= vid end)
        end
    end)
end

local function updateGame(data)
    local wasParticipant = S.participants[BJI_Context.User.playerID]
    local wasInfected = S.isInfected()
    local previousAmountSurvivors = table.filter(S.participants, function(p)
        return not p.originalInfected and not p.infectionTime
    end):length()
    S.participants = data.participants
    participant = S.participants[BJI_Context.User.playerID]
    local isInfected = S.isInfected()
    local amountSurvivors = table.filter(S.participants, function(p)
        return not p.originalInfected and not p.infectionTime
    end):length()
    local wasFinished = S.finished
    S.finished = data.finished

    if wasParticipant and not S.participants[BJI_Context.User.playerID] then
        -- own vehicle deletion will trigger switch to another participant
        onLeaveParticipants()
        BJI_Restrictions.update()
    end
    if not wasInfected and isInfected then
        tryApplyScenarioColor(participant)
    end
    if previousAmountSurvivors ~= amountSurvivors then
        updateSurvivorsVehs()
        if not S.finished and isInfected and S.survivors:length() == 1 then
            S.survivors:find(TrueFn, function(_, vid)
                BJI_GPS.prependWaypoint({
                    key = BJI_GPS.KEYS.VEHICLE,
                    gameVehID = vid,
                    radius = 0,
                    clearable = false,
                })
            end)
        end
    end
    if participant and not wasFinished and S.finished then
        BJI_GPS.reset()
        BJI_Restrictions.update()
    end
end

-- receive infected data from backend
local function rxData(data)
    S.MINIMUM_PARTICIPANTS = data.minimumParticipants
    S.settings.endAfterLastSurvivorInfected = data.endAfterLastSurvivorInfected
    S.settings.enableColors = data.enableColors
    S.settings.survivorsColor = data.survivorsColor
    S.settings.infectedColor = data.infectedColor

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
        else
            updateGame(data)
        end
    elseif S.state then
        S.stop()
    end
    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)

    BJI_Veh.applyQueuedEvents()
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

-- large distance detection tick
---@param ctxt TickContext
local function slowTick(ctxt)
    participant = S.participants[BJI_Context.User.playerID]
    if ctxt.veh and participant and (participant.originalInfected or participant.infectionTime) then
        S.survivors:forEach(function(p, vid)
            pos = BJI_Veh.getPositionRotation(p.veh)
            if pos then
                if ctxt.veh.position:distance(pos) > 50 then
                    S.closeSurvivors = table.filter(S.closeSurvivors, function(cvid) return cvid ~= vid end)
                elseif not table.includes(S.closeSurvivors, vid) then
                    table.insert(S.closeSurvivors, vid)
                end
            end
        end)
    end
end

-- close distance detection tick
---@param ctxt TickContext
local function fastTick(ctxt)
    if S.state == S.STATES.GAME and not S.finished and
        ctxt.veh and S.isInfected() then
        if not S.selfDiag then initSelfDiag(ctxt.veh.veh) end
        table.filter(S.closeSurvivors, function(vid, i)
            if not S.survivors[vid] then table.remove(S.closeSurvivors, i) end
            return S.survivors[vid] ~= nil and not S.survivors[vid].lock
        end):forEach(function(vid)
            pos = BJI_Veh.getPositionRotation(S.survivors[vid].veh)
            if pos and pos:distance(ctxt.veh.position) < S.selfDiag + S.survivors[vid].diag then
                -- tagged
                BJI_Tx_scenario.InfectedUpdate(S.CLIENT_EVENTS.INFECTION, S.survivors[vid].playerID)
                S.survivors[vid].lock = true
                BJI_Async.delayTask(function()
                    if S.survivors[vid] then
                        S.survivors[vid].lock = nil
                    end
                end, 2000)
            end
        end)
    end
end

---@param playerID integer?
---@return boolean
local function isInfected(playerID)
    participant = S.participants[playerID or BJI_Context.User.playerID]
    return participant and (participant.originalInfected or participant.infectionTime ~= nil)
end

S.canChangeTo = TrueFn
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

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
S.getCollisionsType = function() return BJI_Collisions.TYPES.FORCED end

S.onVehicleSpawned = onVehicleSpawned
S.onVehicleResetted = onVehicleResetted

S.rxData = rxData

S.getPlayerListActions = getPlayerListActions

S.slowTick = slowTick
S.fastTick = fastTick

S.stop = stop

S.isInfected = isInfected

return S
