local M = {
    TYPES = {
        FORCED = 1,
        DISABLED = 2,
        GHOSTS = 3,
    },
    type = 1,     -- forced by default (collisions on, no one is transparent)
    state = true, -- default state when joining
    ghosts = {},
    selfGhost = false,

    ghostsRadius = 5,
    ghostDelay = 3000,
    ghostAlpha = .1,
    playerAlpha = 1,

    alphas = {},
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
    core_vehicle_partmgmt.setHighlightedPartsVisiblity(alpha, gameVehID)
end

local function getGhostDistance(selfVeh, targetVeh)
    return selfVeh:getInitialLength() / 2 + targetVeh:getInitialLength() / 2 + M.ghostsRadius
end

local function getAlphaByDistance(distance, maxDistance)
    if distance > maxDistance then
        return M.playerAlpha
    else
        local alpha = Round(Scale(distance, maxDistance, 2, M.playerAlpha, M.ghostAlpha), 2)
        if alpha < M.ghostAlpha then
            alpha = M.ghostAlpha
        end
        return alpha
    end
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
        if not tincludes(attachedVehs, v.gameVehicleID, true) and
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

local function addGhostSelf(gameVehID)
    local selfVeh = BJIVeh.getVehicleObject(gameVehID)
    if not selfVeh then
        return
    end

    M.selfGhost = true
    local eventNameTimeout = svar("BJIGhostSelfTimeout{1}", { gameVehID })
    BJIAsync.removeTask(eventNameTimeout)
    local timeout = GetCurrentTimeMillis() + M.ghostDelay
    BJIAsync.task(function(ctxt)
        -- collision type has changed
        if M.type ~= M.TYPES.GHOSTS then
            return true
        end
        -- first delay
        if ctxt.now < timeout then
            return false
        end
        return true
    end, function()
        M.selfGhost = false
    end, eventNameTimeout)
end

local function addGhostOther(gameVehID)
    M.ghosts[gameVehID] = true
    local eventNameTimeout = svar("BJIGhostOtherTimeout{1}", { gameVehID })
    BJIAsync.removeTask(eventNameTimeout)
    BJIAsync.delayTask(function()
        M.ghosts[gameVehID] = nil
    end, M.ghostDelay, eventNameTimeout)
end

-- on spawn or reset
local function onVehicleResetted(gameVehID)
    if M.type ~= M.TYPES.GHOSTS or
        gameVehID == -1 or
        not BJIVeh.getVehicleObject(gameVehID) or
        BJIAI.isAIVehicle(gameVehID) or
        BJIVeh.isUnicycle(gameVehID) then
        return
    end
    if BJIVeh.isVehicleOwn(gameVehID) then
        addGhostSelf(gameVehID)
    else
        addGhostOther(gameVehID)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if M.type == M.TYPES.GHOSTS then
        setCollisions(true)
    end
end

local function renderTick(ctxt)
    local nextType = BJIScenario.getCollisionsType(ctxt)
    if nextType ~= M.type then
        if nextType ~= M.TYPES.GHOSTS then
            M.ghosts = {}
            setCollisions(nextType == M.TYPES.FORCED)
        else
            if M.type == M.TYPES.DISABLED then
                setCollisions(not areCloseVehicles(ctxt.isOwner and ctxt.veh:getID() or nil))
            else
                setCollisions(true)
            end
        end
        M.type = nextType
    end

    -- GHOST RULES
    if M.type == M.TYPES.GHOSTS then
        if ctxt.isOwner then
            if M.ghosts[ctxt.veh:getID()] then
                -- remove self from ghosts
                M.ghosts[ctxt.veh:getID()] = nil
            end
            if M.state then
                if M.selfGhost then
                    setCollisions(false)
                else
                    -- check if ghosts near
                    for g in pairs(M.ghosts) do
                        local target = BJIVeh.getVehicleObject(g)
                        local distance = ctxt.vehPosRot.pos:distance(BJIVeh.getPositionRotation(target).pos)
                        if distance < M.ghostsRadius then
                            setCollisions(false)
                        end
                    end
                end
            elseif not M.selfGhost then
                -- check if far enough from any vehicle
                if not areCloseVehicles(ctxt.veh:getID()) then
                    setCollisions(true)
                end
            end
        elseif not M.state then
            setCollisions(true)
        end
    end

    for _, veh in pairs(BJIVeh.getMPVehicles()) do
        if veh.gameVehicleID ~= -1 then
            local alpha = M.playerAlpha
            if not M.state then
                local isSelf = ctxt.isOwner and veh.gameVehicleID == ctxt.veh:getID()
                if not isSelf and ctxt.isOwner then
                    local target = BJIVeh.getVehicleObject(veh.gameVehicleID)
                    local posRot = target and BJIVeh.getPositionRotation(target) or nil
                    if posRot then
                        local dist = ctxt.vehPosRot.pos:distance(posRot.pos)
                        local maxDist = getGhostDistance(ctxt.veh, target)
                        alpha = getAlphaByDistance(dist, maxDist)
                    end
                end
            end
            if M.alphas[veh.gameVehicleID] ~= alpha then
                local targetAlpha = alpha ~= M.playerAlpha and alpha or nil
                M.alphas[veh.gameVehicleID] = targetAlpha
                setAlpha(veh.gameVehicleID, alpha)
            end
        end
    end
end

local function slowTick(ctxt)
    if M.type == M.TYPES.GHOSTS then
        -- clear invalid ghosts
        for g in pairs(M.ghosts) do
            if not BJIVeh.getVehicleObject(g) or
                BJIAI.isAIVehicle(g) then
                M.ghosts[g] = nil
            end
        end
    end

    -- invalid alpha target fix
    if M.alphas[-1] then
        M.alphas[-1] = nil
    end

    -- clear invalid alphas
    for g in pairs(M.alphas) do
        if not BJIVeh.getVehicleObject(g) then
            M.alphas[g] = nil
        end
    end

    if ctxt.veh then
        local vehID = ctxt.veh:getID()
        if M.alphas[vehID] ~= M.playerAlpha then
            M.alphas[vehID] = nil
            setAlpha(vehID, M.playerAlpha)
        elseif getVehAlpha(vehID) ~= M.playerAlpha then
            setAlpha(vehID, M.playerAlpha)
        end
    end
end

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched

M.renderTick = renderTick
M.slowTick = slowTick

RegisterBJIManager(M)
return M
