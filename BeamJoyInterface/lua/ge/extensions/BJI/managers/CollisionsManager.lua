local M = {
    _name = "BJICollisions",
    TYPES = {
        FORCED = 1,
        DISABLED = 2,
        GHOSTS = 3,
    },
    type = 1,     -- forced by default (collisions on, no one is transparent)
    state = true, -- default state when joining
    ghosts = Table(),
    permaGhosts = Table(),
    ghostProcessKey = "BJIGhostAlpha-{1}",

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

---@param gameVehID integer
---@return boolean
local function isVehicle(gameVehID)
    local veh = BJIVeh.getVehicleObject(gameVehID)
    return veh ~= nil and not BJIVeh.isUnicycle(gameVehID) and
        not table.includes({ BJI_VEHICLE_TYPES.TRAILER, BJI_VEHICLE_TYPES.PROP },
            BJIVeh.getType(veh.jbeam))
end

---@param gameVehID integer
---@return boolean
local function canBecomeGhost(gameVehID)
    return isVehicle(gameVehID) and not BJIAI.isAIVehicle(gameVehID)
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

---@param gameVehID integer
---@return tablelib<userdata>
local function getCloseVehicles(gameVehID)
    if not gameVehID then
        return false
    end

    local veh = BJIVeh.getVehicleObject(gameVehID)
    if not veh then
        return false
    end

    local attachedVehs = Table(core_vehicle_partmgmt.findAttachedVehicles(veh:getID()))
    return Table(BJIVeh.getMPVehicles()):values()
        :map(function(v)
            return BJIVeh.getVehicleObject(v.gameVehicleID)
        end)
        :filter(function(v)
            return v:getID() ~= gameVehID and not attachedVehs:includes(v:getID()) and
                isVehicle(v:getID()) and BJIVeh.getPositionRotation(veh).pos:distance(
                    BJIVeh.getPositionRotation(v).pos) < getGhostDistance(veh, v)
        end)
end

---@param gameVehID integer
---@param onReset? boolean
local function applyGhostTransparency(gameVehID, onReset)
    if onReset then
        -- apply multiple times to prevent desyncs
        table.forEach({ 0, 300, 600 }, function(delay)
            -- apply alpha if not my current veh
            BJIAsync.delayTask(function(ctxt)
                if BJIVeh.getVehicleObject(gameVehID) and
                    (not ctxt.veh or ctxt.veh:getID() ~= gameVehID) then
                    setAlpha(gameVehID, M.ghostAlpha)
                end
            end, delay)
        end)
    else
        setAlpha(gameVehID, M.ghostAlpha)
    end
end

---@param gameVehID number
---@param ctxt? TickContext
---@param onReset? boolean
local function addGhost(gameVehID, ctxt, onReset)
    if M.type ~= M.TYPES.GHOSTS or M.ghosts[gameVehID] or M.permaGhosts[gameVehID] then
        return -- ghosts disabled or already ghost/permaghost
    elseif not canBecomeGhost(gameVehID) then
        return -- not a valid target
    end

    ctxt = ctxt or BJITick.getContext()
    M.ghosts[gameVehID] = true
    if ctxt.veh and ctxt.veh:getID() == gameVehID then
        setCollisions(false)
    else
        applyGhostTransparency(gameVehID, onReset)
    end

    local minTime = GetCurrentTimeMillis() + M.ghostDelay
    local eventName = string.var(M.ghostProcessKey, { gameVehID })
    BJIAsync.removeTask(eventName)
    BJIAsync.task(function(ctxt2)
        -- collisions changed or not valid anymore
        if M.type ~= M.TYPES.GHOSTS or not BJIVeh.getVehicleObject(gameVehID) or BJIAI.isAIVehicle(gameVehID) then
            return true
        end

        -- ghost contamination here ^^
        local closeVehs = getCloseVehicles(gameVehID)
        if #closeVehs > 0 then
            BJIAsync.delayTask(function(ctxt3)
                closeVehs:filter(function(veh)
                    return not M.ghosts[veh:getID()] and not M.permaGhosts[veh:getID()]
                end)
                    :forEach(function(veh)
                        addGhost(veh:getID(), ctxt3)
                    end)
            end, 0)
        end

        -- delay passed and not close to another vehicle
        return ctxt2.now >= minTime and #closeVehs == 0
    end, function(ctxt2)
        if M.type ~= M.TYPES.GHOSTS or not BJIVeh.getVehicleObject(gameVehID) then
            return
        end

        if not ctxt2.veh or ctxt2.veh:getID() ~= gameVehID then
            setAlpha(gameVehID, M.playerAlpha)
        end
        M.ghosts[gameVehID] = nil
        if ctxt2.veh and ctxt2.veh:getID() == gameVehID then
            setCollisions(true)
        end
    end, eventName)
end

-- on spawn or reset
local function onVehicleResetted(gameVehID)
    if gameVehID == -1 or BJIAI.isAIVehicle(gameVehID) then
        return
    end

    if M.permaGhosts[gameVehID] then
        applyGhostTransparency(gameVehID, true)
        return
    end

    if M.type == M.TYPES.GHOSTS then
        local veh = BJIVeh.getVehicleObject(gameVehID)
        if not veh or not isVehicle(gameVehID) then
            return
        end

        addGhost(gameVehID, nil, true)
    elseif M.type == M.TYPES.DISABLED then
        local ctxt = BJITick.getContext()
        if not (ctxt.isOwner and ctxt.veh:getID() == gameVehID) then
            applyGhostTransparency(gameVehID, true)
        end
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if M.type == M.TYPES.GHOSTS then
        if oldGameVehID ~= -1 then
            -- previous vehicle actions
            if M.ghosts[oldGameVehID] or M.permaGhosts[oldGameVehID] then
                setAlpha(oldGameVehID, M.ghostAlpha)
            end
        end
        if newGameVehID ~= -1 then
            -- new vehicle actions
            if M.ghosts[newGameVehID] or M.permaGhosts[newGameVehID] then
                setAlpha(newGameVehID, M.playerAlpha)
                setCollisions(false)
            else
                setCollisions(true)
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

local function onVehicleDeleted(gameVehID)
    if M.ghosts[gameVehID] then
        M.ghosts[gameVehID] = nil
        BJIAsync.removeTask(string.var(M.ghostProcessKey, { gameVehID }))
    end
    if M.permaGhosts[gameVehID] then
        M.permaGhosts[gameVehID] = nil
    end
end

---@param ctxt TickContext
local function renderTick(ctxt)
    if not ctxt.veh then
        return -- no current veh
    elseif not canBecomeGhost(ctxt.veh:getID()) then
        return -- is AI or not a vehicle
    end

    -- check if a ghost is near the current veh
    if M.type == M.TYPES.GHOSTS and not M.ghosts[ctxt.veh:getID()] and
        M.state and Table({ M.ghosts, M.permaGhosts })
        :any(function(ghosts)
            return ghosts:any(function(_, gameVehID)
                local target = BJIVeh.getVehicleObject(gameVehID)
                local distance = ctxt.vehPosRot.pos:distance(BJIVeh.getPositionRotation(target).pos)
                return distance < M.ghostsRadius
            end)
        end) then
        addGhost(ctxt.veh:getID(), ctxt)
    end
end

---@param ctxt SlowTickContext
local function slowTick(ctxt)
    if M.type == M.TYPES.GHOSTS then
        -- clear invalid ghosts
        M.ghosts:forEach(function(_, gameVehID)
            if not BJIVeh.getVehicleObject(gameVehID) or
                BJIAI.isAIVehicle(gameVehID) then
                M.ghosts[gameVehID] = nil
            end
        end)
    end
end

local function updatePermaGhosts()
    if M.type == M.TYPES.GHOSTS then
        Table(BJIContext.Players)
            :filter(function(p) return p.playerID ~= BJIContext.User.PlayerID end)
            :forEach(function(player)
                Table(player.vehicles)
                    :map(function(v)
                        return v.finalGameVehID
                    end):values()
                    :filter(function(gameVehID)
                        local veh = BJIVeh.getVehicleObject(gameVehID)
                        return veh ~= nil and canBecomeGhost(gameVehID)
                    end)
                    :forEach(function(gameVehID)
                        if player.isGhost and not M.permaGhosts[gameVehID] then
                            M.permaGhosts[gameVehID] = true
                            if M.ghosts[gameVehID] then
                                BJIAsync.removeTask(string.var(M.ghostProcessKey, { gameVehID }))
                            else
                                applyGhostTransparency(gameVehID)
                            end
                        elseif not player.isGhost and M.permaGhosts[gameVehID] then
                            M.permaGhosts[gameVehID] = nil
                            setAlpha(gameVehID, M.playerAlpha)
                        end
                    end)
            end)
    end
end

---@param ctxt TickContext
---@param nextType integer
local function onTypeChange(ctxt, nextType)
    M.ghosts:forEach(function(_, gameVehID)
        BJIAsync.removeTask(string.var(M.ghostProcessKey, { gameVehID }))
        setAlpha(gameVehID, M.playerAlpha)
    end)
    M.ghosts:clear()
    M.permaGhosts:clear()
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
            if ctxt.veh then
                -- set ghost as safety
                addGhost(ctxt.veh:getID(), ctxt)
            end
        end
        updatePermaGhosts()
    end
end

local listeners = Table()
local function onLoad()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.SCENARIO_CHANGED,
        BJIEvents.EVENTS.SCENARIO_UPDATED,
    }, function(ctxt)
        local nextType = BJIScenario.getCollisionsType(ctxt)
        if nextType ~= M.type then
            onTypeChange(ctxt, nextType)
            M.type = nextType
        end
    end))

    listeners:insert(BJIEvents.addListener(BJIEvents.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJICache.CACHES.PLAYERS then
            updatePermaGhosts()
        end
    end))
end
local function onUnload()
    listeners:forEach(BJIEvents.removeListener)
end

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleDeleted = onVehicleDeleted

M.renderTick = renderTick
M.slowTick = slowTick

M.onLoad = onLoad
M.onUnload = onUnload

RegisterBJIManager(M)
return M
