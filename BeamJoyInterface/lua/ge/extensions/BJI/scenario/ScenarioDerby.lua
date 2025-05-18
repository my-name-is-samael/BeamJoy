---@class BJIScenarioDerby : BJIScenario
local S = {
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
    destroyedTimeout = 5,
    preparationTimeout = nil,
    startTime = nil,
    participants = {},
    ---@type {name: string, startPositions: table, previewPosition: BJIPositionRotation?}?
    baseArena = nil,
    configs = {},
    ---@type BJIPositionRotation?
    startPos = nil,

    -- self data
    nextResetExempt = false,
    destroy = {
        distanceThreshold = .1,
        process = false,
        lastPos = nil,
        targetTime = nil,
        lock = false,
    },
}

local function stop()
    S.state = nil
    S.preparationTimeout = nil
    S.startTime = nil
    S.participants = {}
    S.baseArena = nil
    S.startPos = nil

    S.nextResetExempt = false
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
    BJI.Managers.Veh.deleteAllOwnVehicles()
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.ALL,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    BJI.Managers.GPS.reset()
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
end

local function findFreeStartPosition(ownGameVehID)
    if not S.baseArena then
        return
    end
    local positions = {}
    for _, p in ipairs(S.baseArena.startPositions) do
        local free = true
        for _, v in pairs(BJI.Managers.Veh.getMPVehicles()) do
            if v.gameVehicleID ~= ownGameVehID then
                local veh = BJI.Managers.Veh.getVehicleObject(v.gameVehicleID)
                local pos = BJI.Managers.Veh.getPositionRotation(veh)
                if pos and pos.pos:distance(vec3(p.pos)) < .5 then
                    free = false
                    break
                end
            end
        end
        if free then
            table.insert(positions, {
                pos = vec3(p.pos),
                rot = quat(p.rot),
            })
        end
    end
    return table.random(positions)
end

local function tryReplaceOrSpawn(model, config)
    local participant = S.getParticipant()
    if S.state == S.STATES.PREPARATION and participant and not participant.ready then
        if table.length(BJI.Managers.Context.User.vehicles) > 0 and not BJI.Managers.Veh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        if not S.startPos then
            S.startPos = findFreeStartPosition(BJI.Managers.Veh.getCurrentVehicleOwn():getID())
        end
        BJI.Managers.Veh.replaceOrSpawnVehicle(model, config, S.startPos)
        BJI.Managers.Async.task(function(ctxt)
            return ctxt.isOwner
        end, function()
            BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
            BJI.Managers.Veh.freeze(true)
            if not BJI.Windows.VehSelector.show then
                BJI.Windows.VehSelector.open({}, false)
            end
        end, "BJIDerbyPostSpawn")
    end
end

local function tryPaint(paint, paintNumber)
    local participant = S.getParticipant()
    if BJI.Managers.Veh.isCurrentVehicleOwn() and
        S.state == S.STATES.PREPARATION and participant and not participant.ready then
        BJI.Managers.Veh.paintVehicle(paint, paintNumber)
        BJI.Managers.Veh.freeze(true)
    end
end

local function getModelList()
    local participant = S.getParticipant()
    if S.state ~= S.STATES.PREPARATION or
        not participant or participant.ready or
        #S.configs > 0 then
        return {}
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
    local vehIDs = {}
    for _, participant in pairs(S.participants) do
        if not participant.eliminationTime then
            if participant.gameVehID then
                local veh = BJI.Managers.Veh.getVehicleObject(participant.gameVehID)
                if veh then
                    table.insert(vehIDs, veh:getID())
                end
            else
                local gameVehID
                for _, v in pairs(BJI.Managers.Context.Players[participant.playerID].vehicles) do
                    local veh = BJI.Managers.Veh.getVehicleObject(v.gameVehID)
                    if veh then
                        gameVehID = veh:getID()
                        break
                    end
                end
                if gameVehID then
                    table.insert(vehIDs, gameVehID)
                end
            end
        end
    end
    local gameVehID = table.random(vehIDs)
    if gameVehID then
        BJI.Managers.Veh.focusVehicle(gameVehID)
    end
end

local function canVehUpdate()
    local participant = S.getParticipant()
    return S.state == S.STATES.PREPARATION and participant and not participant.ready
end

local function doShowNametag(vehData)
    return S.isParticipant(vehData.ownerID) and not S.isEliminated(vehData.ownerID)
end

-- player list contextual actions getter
local function getPlayerListActions(player, ctxt)
    local actions = {}

    if S.isSpec() and not S.isSpec(player.playerID) then
        local finalGameVehID = Table(BJI.Managers.Context.Players[player.playerID].vehicles)
            :reduce(function(acc, v)
                if not acc then
                    local veh = BJI.Managers.Veh.getVehicleObject(v.gameVehID)
                    return veh and veh:getID()
                end
                return acc
            end, nil)
        table.insert(actions, {
            id = string.var("focus{1}", { player.playerID }),
            icon = ICONS.visibility,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            disabled = not finalGameVehID or
                (ctxt.veh and ctxt.veh:getID() == finalGameVehID),
            onClick = function()
                BJI.Managers.Veh.focusVehicle(finalGameVehID)
            end
        })
    end

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            label = BJI.Managers.Lang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJI.Managers.Votes.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

local function onVehicleResetted(gameVehID)
    local ctxt = BJI.Managers.Tick.getContext()
    if S.state == S.STATES.GAME and
        BJI.Managers.Veh.isVehicleOwn(gameVehID) and
        ctxt.isOwner then
        if S.nextResetExempt then
            S.nextResetExempt = false
            return
        end

        if not S.startPos or ctxt.vehPosRot.pos:distance(S.startPos.pos) > .5 then
            if not S.startPos then
                S.startPos = findFreeStartPosition(ctxt.isOwner and ctxt.veh:getID() or nil)
            end
            BJI.Managers.Veh.setPositionRotation(S.startPos.pos, S.startPos.rot)
        else
            local participant = S.getParticipant()
            if participant then
                BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")
                if participant.lives == 1 then
                    BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)
                end
                BJI.Tx.scenario.DerbyUpdate(S.CLIENT_EVENTS.DESTROYED, math.round(ctxt.now - S.startTime))
            end
        end
    end
end

local function fastTick(ctxt)
    local participant = S.getParticipant()
    if participant and not S.isEliminated() and ctxt.isOwner then
        if S.state == S.STATES.PREPARATION then
            if not S.startPos then
                S.startPos = findFreeStartPosition(ctxt.isOwner and ctxt.veh:getID() or nil)
            end
        elseif S.startTime and ctxt.now > S.startTime and S.destroy.process then
            local dist = S.destroy.lastPos and ctxt.vehPosRot.pos:distance(S.destroy.lastPos) or nil
            if dist and dist > S.destroy.distanceThreshold then
                BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")
                S.destroy.process = false
                S.destroy.targetTime = nil
            end
        end
    end
end

-- Destroy process is detected through slowTick, then checked through renderTick
local function slowTick(ctxt)
    local participant = S.getParticipant()
    if S.state == S.STATES.GAME and ctxt.isOwner and
        not S.destroy.process and not S.destroy.lock and
        S.startTime and ctxt.now > S.startTime and
        participant and not S.isEliminated() then
        local dist = S.destroy.lastPos and ctxt.vehPosRot.pos:distance(S.destroy.lastPos) or nil
        if dist and dist < S.destroy.distanceThreshold * 10 then
            S.destroy.targetTime = ctxt.now + (S.destroyedTimeout * 1000)
            S.destroy.process = true
            local msg
            if participant.lives > 0 then
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
            end
            BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")
            BJI.Managers.Message.flashCountdown("BJIDerbyDestroy", S.destroy.targetTime, false, msg, nil,
                function()
                    participant = S.getParticipant()
                    if participant then
                        if participant.lives > 0 then
                            S.startPos = findFreeStartPosition(ctxt.isOwner and ctxt.veh:getID() or nil)
                            BJI.Managers.Veh.setPositionRotation(S.startPos.pos, S.startPos.rot)
                        else
                            BJI.Tx.scenario.DerbyUpdate(S.CLIENT_EVENTS.DESTROYED,
                                math.round(ctxt.now - S.startTime))
                        end
                        S.destroy.process = false
                        S.destroy.targetTime = nil
                        S.destroy.lastPos = nil
                        S.destroy.lock = true
                        BJI.Managers.Async.task(function()
                            -- wait for data update before unlocking destroy process
                            local updated = S.getParticipant()
                            return participant.lives == 0 and S.isEliminated() or
                                (type(updated) == "table" and updated.lives == participant.lives - 1)
                        end, function()
                            S.destroy.lock = false
                        end, "BJIDerbyDestroyLockSafe")
                    end
                end)
        end
        S.destroy.lastPos = ctxt.vehPosRot.pos
    end
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.ALL,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.Message.cancelFlash("BJIDerbyDestroy")
    if ctxt.isOwner then
        BJI.Managers.Veh.freeze(false)
        if ctxt.camera == BJI.Managers.Cam.CAMERAS.EXTERNAL then
            ctxt.camera = BJI.Managers.Cam.CAMERAS.ORBIT
            BJI.Managers.Cam.setCamera(ctxt.camera)
        end
    end
end

local function initPreparation(data)
    S.startTime = BJI.Managers.Tick.applyTimeOffset(data.startTime)
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.DERBY)
    BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)

    S.state = data.state
    S.baseArena = data.baseArena
    S.configs = data.configs
    S.preparationTimeout = BJI.Managers.Tick.applyTimeOffset(data.preparationTimeout)
    S.participants = data.participants
    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
    BJI.Managers.Cam.setPositionRotation(S.baseArena.previewPosition.pos, S.baseArena.previewPosition.rot)
end

local function onJoinParticipants()
    BJI.Managers.Restrictions.update({ {
        restrictions = BJI.Managers.Restrictions.OTHER.FREE_CAM,
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    S.startPos = findFreeStartPosition()
    if #S.configs == 0 then
        BJI.Windows.VehSelector.open(S.getModelList(), false)
    elseif #S.configs == 1 then
        -- no models in veh selector cause configs can be absent from others clients
        S.trySpawnNew(S.configs[1].model, S.configs[1].config)
    end
end

local function onLeaveParticipants()
    BJI.Managers.Restrictions.update({ {
        restrictions = BJI.Managers.Restrictions.OTHER.FREE_CAM,
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Utils.Common.HideGameMenu()
    BJI.Windows.VehSelector.tryClose(true)
    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
    BJI.Managers.Cam.setPositionRotation(S.baseArena.previewPosition.pos, S.baseArena.previewPosition.rot)
    BJI.Managers.Veh.deleteAllOwnVehicles()
end

local function onReady()
    BJI.Windows.VehSelector.tryClose(true)
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
end


local function updatePreparation(data)
    local wasParticipant = S.getParticipant()
    local wasReady = wasParticipant and wasParticipant.ready or false
    S.participants = data.participants

    local participant = S.getParticipant()
    if not wasParticipant and participant then
        onJoinParticipants()
    elseif wasParticipant and not participant then
        onLeaveParticipants()
    elseif not wasReady and participant and participant.ready then
        onReady()
    end
end

local function initGame(data)
    BJI.Windows.VehSelector.tryClose(true)

    S.state = data.state
    S.baseArena = S.baseArena
    S.startTime = BJI.Managers.Tick.applyTimeOffset(data.startTime)
    S.participants = data.participants

    local now = GetCurrentTimeMillis()

    local function onStart()
        if now - 1000 <= S.startTime then
            BJI.Managers.Message.flash("BJIDerbyStart", BJI.Managers.Lang.get("derby.play.flashStart"), 3, true)
        end
        local participant = S.getParticipant()
        if participant then
            BJI.Managers.Veh.freeze(false)
            if participant.lives > 0 then
                BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL_BUT_LOADHOME)
            end
        end
    end

    if now < S.startTime then
        local participant = S.getParticipant()
        if participant then
            BJI.Managers.Async.programTask(function(ctxt)
                if ctxt.camera == BJI.Managers.Cam.CAMERAS.EXTERNAL then
                    ctxt.camera = BJI.Managers.Cam.CAMERAS.ORBIT
                    BJI.Managers.Cam.setCamera(ctxt.camera)
                end
            end, S.startTime - 3000, "BJIDerbyPreStart")
        end
        BJI.Managers.Message.flashCountdown("BJIDerbyStart", S.startTime, true, "", nil, onStart, true)
    else
        BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.ORBIT)
        onStart()
    end
end

local function onElimination()
    local participant = S.getParticipant()
    if participant then
        BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.RESET.ALL,
                state = BJI.Managers.Restrictions.STATE.RESTRICTED,
            },
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.FREE_CAM,
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
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
        BJI.Managers.Message.flash("BJIDerbyElimination", BJI.Managers.Lang.get("derby.play.flashElimination"), 3, false)
        BJI.Managers.Async.delayTask(switchToRandomParticipant, 3000, "BJIDerbyPostEliminationSwitch")
    end
end

local function updateGame(data)
    local wasEliminated = S.isEliminated()
    S.participants = data.participants

    if not wasEliminated and S.isEliminated() then
        onElimination()
    end
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

local function getParticipant(playerID)
    playerID = playerID or BJI.Managers.Context.User.playerID
    for i, p in ipairs(S.participants) do
        if p.playerID == playerID then
            return p, i
        end
    end
    return nil, nil
end

local function isParticipant(playerID)
    local participant = S.getParticipant(playerID)
    return not not participant
end

local function isEliminated(playerID)
    local participant = S.getParticipant(playerID)
    return participant and participant.eliminationTime
end

local function isSpec(playerID)
    return not S.isParticipant(playerID) or S.isEliminated(playerID)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad

S.trySpawnNew = tryReplaceOrSpawn
S.tryReplaceOrSpawn = tryReplaceOrSpawn
S.tryPaint = tryPaint
S.getModelList = getModelList

S.canSpawnNewVehicle = canVehUpdate
S.canReplaceVehicle = canVehUpdate
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.getCollisionsType = function() return BJI.Managers.Collisions.TYPES.FORCED end
S.doShowNametag = doShowNametag

S.getPlayerListActions = getPlayerListActions

S.onVehicleResetted = onVehicleResetted
S.fastTick = fastTick
S.slowTick = slowTick

S.onUnload = onUnload

S.rxData = rxData
S.getParticipant = getParticipant
S.isParticipant = isParticipant
S.isEliminated = isEliminated
S.isSpec = isSpec

S.stop = stop

return S
