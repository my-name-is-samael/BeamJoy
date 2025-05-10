local M = {
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
    M.state = nil
    M.preparationTimeout = nil
    M.startTime = nil
    M.participants = {}
    ---@type {startPositions: table, config: table, previewPosition: BJIPositionRotation?}?
    M.baseArena = nil
    M.startPos = nil

    M.nextResetExempt = false
    M.destroy.process = false
    M.destroy.lastPos = nil
    M.destroy.targetTime = nil
    M.destroy.lock = false

    BJIMessage.cancelFlash("BJIDerbyStart")
    BJIMessage.cancelFlash("BJIDerbyDestroy")

    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
end

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return true
end

-- load hook
local function onLoad(ctxt)
    BJIVeh.deleteAllOwnVehicles()
    BJIVehSelector.tryClose()
    BJIRestrictions.update({ {
        restrictions = Table({
            BJIRestrictions.RESET.ALL,
            BJIRestrictions.OTHER.AI_CONTROL,
            BJIRestrictions.OTHER.VEHICLE_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_DEBUG,
            BJIRestrictions.OTHER.WALKING,
            BJIRestrictions.OTHER.BIG_MAP,
        }):flat(),
        state = true,
    } })
    BJIBigmap.toggleQuickTravel(false)
    BJIGPS.reset()
    BJICam.addRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
end

local function findFreeStartPosition(ownGameVehID)
    if not M.baseArena then
        return
    end
    local positions = {}
    for _, p in ipairs(M.baseArena.startPositions) do
        local free = true
        for _, v in pairs(BJIVeh.getMPVehicles()) do
            if v.gameVehicleID ~= ownGameVehID then
                local veh = BJIVeh.getVehicleObject(v.gameVehicleID)
                local pos = BJIVeh.getPositionRotation(veh)
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
    local participant = M.getParticipant()
    if M.state == M.STATES.PREPARATION and participant and not participant.ready then
        if table.length(BJIContext.User.vehicles) > 0 and not BJIVeh.isCurrentVehicleOwn() then
            -- trying to spawn a second veh
            return
        end
        if not M.startPos then
            M.startPos = findFreeStartPosition(BJIVeh.getCurrentVehicleOwn():getID())
        end
        PrintObj(M.startPos)
        BJIVeh.replaceOrSpawnVehicle(model, config, M.startPos)
        BJIAsync.task(function(ctxt)
            return ctxt.isOwner
        end, function()
            BJICam.setCamera(BJICam.CAMERAS.EXTERNAL)
            BJIVeh.freeze(true)
        end, "BJIDerbyPostSpawn")
    end
end

local function tryPaint(paint, paintNumber)
    local participant = M.getParticipant()
    if BJIVeh.isCurrentVehicleOwn() and
        M.state == M.STATES.PREPARATION and participant and not participant.ready then
        BJIVeh.paintVehicle(paint, paintNumber)
        BJIVeh.freeze(true)
    end
end

local function getModelList()
    local participant = M.getParticipant()
    if M.state ~= M.STATES.PREPARATION or
        not participant or participant.ready or
        #M.configs > 0 then
        return {}
    end

    local models = BJIVeh.getAllVehicleConfigs()

    if #BJIContext.Database.Vehicles.ModelBlacklist > 0 then
        for _, model in ipairs(BJIContext.Database.Vehicles.ModelBlacklist) do
            models[model] = nil
        end
    end
    return models
end

local function switchToRandomParticipant()
    local vehIDs = {}
    for _, participant in pairs(M.participants) do
        if not participant.eliminationTime then
            if participant.gameVehID then
                local veh = BJIVeh.getVehicleObject(participant.gameVehID)
                if veh then
                    table.insert(vehIDs, veh:getID())
                end
            else
                local gameVehID
                for _, v in pairs(BJIContext.Players[participant.playerID].vehicles) do
                    local veh = BJIVeh.getVehicleObject(v.gameVehID)
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
        BJIVeh.focusVehicle(gameVehID)
    end
end

local function canVehUpdate()
    local participant = M.getParticipant()
    return M.state == M.STATES.PREPARATION and participant and not participant.ready
end

local function doShowNametag(vehData)
    return M.isParticipant(vehData.ownerID) and not M.isEliminated(vehData.ownerID)
end

-- player list contextual actions getter
local function getPlayerListActions(player, ctxt)
    local actions = {}

    if M.isSpec() and not M.isSpec(player.playerID) then
        local finalGameVehID
        for _, v in pairs(BJIContext.Players[player.playerID].vehicles) do
            local veh = BJIVeh.getVehicleObject(v.gameVehID)
            if veh then
                finalGameVehID = veh:getID()
                break
            end
        end
        table.insert(actions, {
            id = string.var("focus{1}", { player.playerID }),
            icon = ICONS.visibility,
            style = BTN_PRESETS.INFO,
            disabled = not finalGameVehID or
                (ctxt.veh and ctxt.veh:getID() == finalGameVehID),
            onClick = function()
                BJIVeh.focusVehicle(finalGameVehID)
            end
        })
    end

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

local function onVehicleResetted(gameVehID)
    local ctxt = BJITick.getContext()
    if M.state == M.STATES.GAME and
        BJIVeh.isVehicleOwn(gameVehID) and
        ctxt.isOwner then
        if M.nextResetExempt then
            M.nextResetExempt = false
            return
        end

        if not M.startPos or ctxt.vehPosRot.pos:distance(M.startPos.pos) > .5 then
            if not M.startPos then
                M.startPos = findFreeStartPosition(ctxt.isOwner and ctxt.veh:getID() or nil)
            end
            BJIVeh.setPositionRotation(M.startPos.pos, M.startPos.rot)
        else
            local participant = M.getParticipant()
            if participant then
                BJIMessage.cancelFlash("BJIDerbyDestroy")
                if participant.lives == 1 then
                    BJIRestrictions.updateResets(BJIRestrictions.RESET.ALL)
                end
                BJITx.scenario.DerbyUpdate(M.CLIENT_EVENTS.DESTROYED, math.round(ctxt.now - M.startTime))
            end
        end
    end
end

local function renderTick(ctxt)
    local participant = M.getParticipant()
    if participant and not M.isEliminated() and ctxt.isOwner then
        if M.state == M.STATES.PREPARATION then
            if not M.startPos then
                M.startPos = findFreeStartPosition(ctxt.isOwner and ctxt.veh:getID() or nil)
            end
        elseif M.startTime and ctxt.now > M.startTime then
            local dist = M.destroy.lastPos and ctxt.vehPosRot.pos:distance(M.destroy.lastPos) or nil
            if M.destroy.process then
                if dist and dist > M.destroy.distanceThreshold then
                    BJIMessage.cancelFlash("BJIDerbyDestroy")
                    M.destroy.process = false
                    M.destroy.targetTime = nil
                end
            else
                if not M.destroy.lock and dist and dist <= M.destroy.distanceThreshold then
                    M.destroy.targetTime = ctxt.now + (M.destroyedTimeout * 1000)
                    M.destroy.process = true
                    local msg
                    if participant.lives > 0 then
                        if participant.lives == 1 then
                            msg = BJILang.get("derby.play.flashNoLifeRemaining")
                        elseif participant.lives == 2 then
                            msg = BJILang.get("derby.play.flashLifeRemaining"):var({ lives = participant.lives - 1 })
                        else
                            msg = BJILang.get("derby.play.flashLivesRemaining"):var({ lives = participant.lives - 1 })
                        end
                    end
                    BJIMessage.cancelFlash("BJIDerbyDestroy")
                    BJIMessage.flashCountdown("BJIDerbyDestroy", M.destroy.targetTime, false, msg, nil, function()
                        participant = M.getParticipant()
                        if participant then
                            if participant.lives > 0 then
                                if not M.startPos then
                                    M.startPos = findFreeStartPosition(ctxt.isOwner and ctxt.veh:getID() or nil)
                                end
                                BJIVeh.setPositionRotation(M.startPos.pos, M.startPos.rot)
                            else
                                BJITx.scenario.DerbyUpdate(M.CLIENT_EVENTS.DESTROYED, math.round(ctxt.now - M.startTime))
                            end
                            M.destroy.process = false
                            M.destroy.targetTime = nil
                            M.destroy.lastPos = nil
                            M.destroy.lock = true
                            BJIAsync.task(function()
                                -- wait for data update before unlocking destroy process
                                local updated = M.getParticipant()
                                return participant.lives == 0 and M.isEliminated() or
                                    (type(updated) == "table" and updated.lives == participant.lives - 1)
                            end, function()
                                M.destroy.lock = false
                            end, "BJIDerbyDestroyLockSafe")
                        end
                    end)
                end
                M.destroy.lastPos = ctxt.vehPosRot.pos
            end
        end
    end
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJIRestrictions.update({ {
        restrictions = Table({
            BJIRestrictions.RESET.ALL,
            BJIRestrictions.OTHER.AI_CONTROL,
            BJIRestrictions.OTHER.VEHICLE_SWITCH,
            BJIRestrictions.OTHER.VEHICLE_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_DEBUG,
            BJIRestrictions.OTHER.WALKING,
            BJIRestrictions.OTHER.BIG_MAP,
            BJIRestrictions.OTHER.FREE_CAM,
        }):flat(),
        state = false,
    } })
    BJIMessage.cancelFlash("BJIDerbyDestroy")
    if ctxt.isOwner then
        BJIVeh.freeze(false)
        if ctxt.camera == BJICam.CAMERAS.EXTERNAL then
            ctxt.camera = BJICam.CAMERAS.ORBIT
            BJICam.setCamera(ctxt.camera)
        end
    end
    BJIBigmap.toggleQuickTravel(true)
end

local function initPreparation(data)
    M.startTime = BJITick.applyTimeOffset(data.startTime)
    BJIScenario.switchScenario(BJIScenario.TYPES.DERBY)
    BJIRestrictions.updateResets(BJIRestrictions.RESET.ALL)

    M.state = data.state
    M.baseArena = data.baseArena
    M.configs = data.configs
    M.preparationTimeout = BJITick.applyTimeOffset(data.preparationTimeout)
    M.participants = data.participants
    BJICam.setCamera(BJICam.CAMERAS.FREE)
    BJICam.setPositionRotation(M.baseArena.previewPosition.pos, M.baseArena.previewPosition.rot)
end

local function onJoinParticipants()
    BJIRestrictions.update({ {
        restrictions = BJIRestrictions.OTHER.VEHICLE_SELECTOR,
        state = #M.configs == 1,
    }, {
        restrictions = BJIRestrictions.OTHER.FREE_CAM,
        state = true,
    } })
    M.startPos = findFreeStartPosition()
    if #M.configs == 1 then
        M.trySpawnNew(M.configs[1].model, M.configs[1].config)
        BJIVehSelector.open({}, false)
    elseif #M.configs == 0 then
        BJIVehSelector.open(M.getModelList(), false)
    end
end

local function onLeaveParticipants()
    BJIRestrictions.update({ {
        restrictions = BJIRestrictions.OTHER.VEHICLE_SELECTOR,
        state = true,
    }, {
        restrictions = BJIRestrictions.OTHER.FREE_CAM,
        state = false,
    } })
    HideGameMenu()
    BJICam.setCamera(BJICam.CAMERAS.FREE)
    BJICam.setPositionRotation(M.baseArena.previewPosition.pos, M.baseArena.previewPosition.rot)
    BJIVeh.deleteAllOwnVehicles()
end

local function onReady()
    BJIVehSelector.tryClose(true)
    BJIRestrictions.update({ {
        restrictions = Table({
            BJIRestrictions.OTHER.VEHICLE_SELECTOR,
            BJIRestrictions.OTHER.FREE_CAM,
            BJIRestrictions.OTHER.VEHICLE_SWITCH,
        }):flat(),
        state = true,
    } })
end


local function updatePreparation(data)
    local wasParticipant = M.getParticipant()
    local wasReady = wasParticipant and wasParticipant.ready or false
    M.participants = data.participants

    local participant = M.getParticipant()
    if not wasParticipant and participant then
        onJoinParticipants()
    elseif wasParticipant and not participant then
        onLeaveParticipants()
    elseif not wasReady and participant and participant.ready then
        onReady()
    end
end

local function initGame(data)
    BJIVehSelector.tryClose(true)

    M.state = data.state
    M.baseArena = M.baseArena
    M.startTime = BJITick.applyTimeOffset(data.startTime)
    M.participants = data.participants

    local now = GetCurrentTimeMillis()

    local function onStart()
        if now - 1000 <= M.startTime then
            BJIMessage.flash("BJIDerbyStart", BJILang.get("derby.play.flashStart"), 3, true)
        end
        local participant = M.getParticipant()
        if participant then
            BJIVeh.freeze(false)
            if participant.lives > 0 then
                BJIRestrictions.updateResets(BJIRestrictions.RESET.ALL_BUT_LOADHOME)
            end
        end
    end

    if now < M.startTime then
        local participant = M.getParticipant()
        if participant then
            BJIAsync.programTask(function(ctxt)
                if ctxt.camera == BJICam.CAMERAS.EXTERNAL then
                    ctxt.camera = BJICam.CAMERAS.ORBIT
                    BJICam.setCamera(ctxt.camera)
                end
            end, M.startTime - 3000, "BJIDerbyPreStart")
        end
        BJIMessage.flashCountdown("BJIDerbyStart", M.startTime, true, "", nil, onStart, true)
    else
        BJICam.setCamera(BJICam.CAMERAS.ORBIT)
        onStart()
    end
end

local function onElimination()
    local participant = M.getParticipant()
    if participant then
        BJIRestrictions.updateResets(BJIRestrictions.RESET.ALL)
        BJIRestrictions.update({ {
            restrictions = Table({
                BJIRestrictions.OTHER.FREE_CAM,
                BJIRestrictions.OTHER.VEHICLE_SWITCH,
            }):flat(),
            state = false,
        } })
        if participant.gameVehID then
            BJITx.player.explodeVehicle(participant.gameVehID)
        else
            for _, v in pairs(BJIContext.User.vehicles) do
                local veh = BJIVeh.getVehicleObject(v.gameVehID)
                if veh then
                    BJITx.player.explodeVehicle(veh:getID())
                end
            end
        end
        BJIMessage.flash("BJIDerbyElimination", BJILang.get("derby.play.flashElimination"), 3, false)
        BJIAsync.delayTask(switchToRandomParticipant, 3000, "BJIDerbyPostEliminationSwitch")
    end
end

local function updateGame(data)
    local wasEliminated = M.isEliminated()
    M.participants = data.participants

    if not wasEliminated and M.isEliminated() then
        onElimination()
    end
end

local function rxData(data)
    M.MINIMUM_PARTICIPANTS = data.minimumParticipants
    if data.state then
        if data.state == M.STATES.PREPARATION then
            if not M.state then
                initPreparation(data)
            elseif M.state == M.STATES.PREPARATION then
                updatePreparation(data)
            end
        elseif data.state == M.STATES.GAME then
            if M.state ~= M.STATES.GAME then
                initGame(data)
            else
                updateGame(data)
            end
        end
    else
        if M.state then
            M.stop()
        end
    end
end

local function getParticipant(playerID)
    playerID = playerID or BJIContext.User.playerID
    for i, p in ipairs(M.participants) do
        if p.playerID == playerID then
            return p, i
        end
    end
    return nil, nil
end

local function isParticipant(playerID)
    local participant = M.getParticipant(playerID)
    return not not participant
end

local function isEliminated(playerID)
    local participant = M.getParticipant(playerID)
    return participant and participant.eliminationTime
end

local function isSpec(playerID)
    return not M.isParticipant(playerID) or M.isEliminated(playerID)
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.trySpawnNew = tryReplaceOrSpawn
M.tryReplaceOrSpawn = tryReplaceOrSpawn
M.tryPaint = tryPaint
M.getModelList = getModelList

M.canSpawnNewVehicle = canVehUpdate
M.canReplaceVehicle = canVehUpdate
M.canDeleteVehicle = FalseFn
M.canDeleteOtherVehicles = FalseFn
M.getCollisionsType = function() return BJICollisions.TYPES.FORCED end
M.doShowNametag = doShowNametag

M.getPlayerListActions = getPlayerListActions

M.onVehicleResetted = onVehicleResetted
M.renderTick = renderTick

M.onUnload = onUnload

M.rxData = rxData
M.getParticipant = getParticipant
M.isParticipant = isParticipant
M.isEliminated = isEliminated
M.isSpec = isSpec

M.stop = stop

return M
