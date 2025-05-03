local M = {
    _name = "BJICollisions",
    TYPES = {
        FORCED = 1,
        DISABLED = 2,
        GHOSTS = 3,
    },
    type = 1,     -- forced by default (collisions on, no one is transparent)
    state = true, -- default state when joining
    ghosts = {},

    ghostsRadius = 5,
    ghostDelay = 5000,
    ghostAlpha = .5,
    playerAlpha = 1,
}

local function getVehAlpha(gameVehID)
    local veh = BJIVeh.getVehicleObject(gameVehID)
    if not veh then
        return
    end

    local vData = core_vehicle_manager.getVehicleData(gameVehID).vdata
    if vData.flexbodies and vData.flexbodies[0] then
        return veh:getMeshAlpha(vData.flexbodies[0].mesh)
    else
        return
    end
end

local function setCollisions(state)
    if state ~= M.state then
        be:setDynamicCollisionEnabled(state)
        M.state = state
    end
end

local function setAlpha(gameVehID, alpha)
    if BJIVeh.getVehicleObject(gameVehID) then
        core_vehicle_partmgmt.setHighlightedPartsVisiblity(alpha, gameVehID)
    end
end

local function getGhostDistance(selfVeh, targetVeh)
    return selfVeh:getInitialLength() / 2 + targetVeh:getInitialLength() / 2 + M.ghostsRadius
end

local function areCloseVehicles(selfVehID)
    if not selfVehID then
        return false
    end

    local veh = BJIVeh.getVehicleObject(selfVehID)
    if not veh then
        return false
    end

    local attachedVehs = core_vehicle_partmgmt.findAttachedVehicles(veh:getID())
    for _, v in pairs(BJIVeh.getMPVehicles()) do
        if not table.includes(attachedVehs, v.gameVehicleID) and
            v.gameVehicleID ~= veh:getID() then
            local target = BJIVeh.getVehicleObject(v.gameVehicleID)
            if target then
                local distance = BJIVeh.getPositionRotation(veh).pos
                    :distance(BJIVeh.getPositionRotation(target).pos)
                local maxDist = getGhostDistance(veh, target)
                if distance < maxDist then
                    return true
                end
            end
        end
    end
    return false
end

-- on spawn or reset
local function onVehicleResetted(gameVehID)
    if gameVehID == -1 then
        return
    end

    local function applyTransparencyAfterReset(g)
        -- apply 3 times to prevent desyncs
        table.forEach({ 0, 300, 600 }, function(delay)
            -- apply alpha if not my current veh
            BJIAsync.delayTask(function(ctxt)
                if BJIVeh.getVehicleObject(g) and
                    not (ctxt.isOwner and ctxt.veh:getID() == g) then
                    setAlpha(g, M.ghostAlpha)
                end
            end, delay)
        end)
    end

    if M.type == M.TYPES.GHOSTS then
        if gameVehID == -1 or
            not BJIVeh.getVehicleObject(gameVehID) or
            BJIAI.isAIVehicle(gameVehID) or
            BJIVeh.isUnicycle(gameVehID) then
            return
        end

        M.ghosts[gameVehID] = true
        local minTime = GetCurrentTimeMillis() + M.ghostDelay
        local eventName = string.var("BJIGhostAlpha-{1}", { gameVehID })
        BJIAsync.removeTask(eventName)
        BJIAsync.task(function(ctxt)
            -- collision type has changed
            if M.type ~= M.TYPES.GHOSTS or not BJIVeh.getVehicleObject(gameVehID) then
                return true
            end
            -- delay passed and not close to another vehicle
            return ctxt.now >= minTime and not areCloseVehicles(gameVehID)
        end, function(ctxt)
            if BJIVeh.getVehicleObject(gameVehID) then
                setAlpha(gameVehID, M.playerAlpha)
            end
            M.ghosts[gameVehID] = nil
            if ctxt.veh and ctxt.veh:getID() == gameVehID then
                setCollisions(true)
            end
        end, eventName)

        local ctxt = BJITick.getContext()
        if ctxt.isOwner and ctxt.veh:getID() == gameVehID then
            setCollisions(false)
        else
            applyTransparencyAfterReset(gameVehID)
        end
    elseif M.type == M.TYPES.DISABLED then
        local ctxt = BJITick.getContext()
        if not (ctxt.isOwner and ctxt.veh:getID() == gameVehID) then
            applyTransparencyAfterReset(gameVehID)
        end
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if M.type == M.TYPES.GHOSTS then
        if oldGameVehID ~= -1 then
            -- previous vehicle actions
            if M.ghosts[oldGameVehID] then
                setAlpha(oldGameVehID, M.ghostAlpha)
            end
        end
        if newGameVehID ~= -1 then
            -- new vehicle actions
            if M.ghosts[newGameVehID] then
                setAlpha(newGameVehID, M.playerAlpha)
                setCollisions(false)
            else
                local veh = BJIVeh.getPositionRotation(BJIVeh.getVehicleObject(newGameVehID))
                if veh then
                    setCollisions(table.any(M.ghosts, function(_, gameVehID)
                        local target = BJIVeh.getPositionRotation(BJIVeh.getVehicleObject(gameVehID))
                        return target and veh.pos:distance(target.pos) < M.ghostsRadius or false
                    end))
                else
                    setCollisions(true)
                end
            end
        end
    elseif M.type == M.TYPES.DISABLED then
        if oldGameVehID ~= -1 then
            setAlpha(oldGameVehID, M.ghostAlpha)
        end
        if newGameVehID ~= -1 then
            setAlpha(newGameVehID, M.playerAlpha)
        end
    end
end

local function renderTick(ctxt)
    -- check if a ghost is near the current veh
    if M.type == M.TYPES.GHOSTS and ctxt.veh and M.state and
        table.any(M.ghosts, function(_, gameVehID)
            local target = BJIVeh.getVehicleObject(gameVehID)
            local distance = ctxt.vehPosRot.pos:distance(BJIVeh.getPositionRotation(target).pos)
            return distance < M.ghostsRadius
        end) then
        setCollisions(false)
    end
end

---@param ctxt SlowTickContext
local function slowTick(ctxt)
    if M.type == M.TYPES.GHOSTS then
        -- clear invalid ghosts
        table.forEach(M.ghosts, function(_, gameVehID)
            if not BJIVeh.getVehicleObject(gameVehID) or
                BJIAI.isAIVehicle(gameVehID) then
                M.ghosts[gameVehID] = nil
            end
        end)
    end
end

local function onTypeChanged(ctxt, nextType)
    table.forEach(M.ghosts, function(_, gameVehID)
        BJIAsync.removeTask(string.var("BJIGhostAlpha-{1}", { gameVehID }))
        setAlpha(gameVehID, M.playerAlpha)
    end)
    table.clear(M.ghosts)
    if nextType ~= M.TYPES.GHOSTS then
        if nextType == M.TYPES.DISABLED then
            table.forEach(BJIVeh.getMPVehicles(), function(veh)
                if veh.gameVehicleID ~= ctxt.veh:getID() then
                    setAlpha(veh.gameVehicleID, M.ghostAlpha)
                end
            end)
        end
        setCollisions(nextType == M.TYPES.FORCED)
    else
        if M.type == M.TYPES.DISABLED then
            setCollisions(not areCloseVehicles(ctxt.isOwner and ctxt.veh:getID() or nil))
        else
            setCollisions(true)
        end
    end
end

local listeners = {}
local function onLoad()
    table.insert(listeners, BJIEvents.addListener(BJIEvents.EVENTS.SCENARIO_CHANGED, function(ctxt)
        local nextType = BJIScenario.getCollisionsType(ctxt)
        if nextType ~= M.type then
            onTypeChanged(ctxt, nextType)
            M.type = nextType
        end
    end))
end
local function onUnload()
    table.forEach(listeners, BJIEvents.removeListener)
end

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched

M.renderTick = renderTick
M.slowTick = slowTick

M.onLoad = onLoad
M.onUnload = onUnload

RegisterBJIManager(M)
return M
