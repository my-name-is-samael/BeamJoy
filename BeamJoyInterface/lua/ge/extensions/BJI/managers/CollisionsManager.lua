---@class BJIManagerCollisions : BJIManager
local M = {
    _name = "Collisions",

    TYPES = {
        FORCED = 1,
        DISABLED = 2,
        GHOSTS = 3,
    },
    type = 1, -- forced by default (collisions on, no one is transparent)

    ghostsRadius = 5,
    ghostDelay = 5000,
    ghostAlpha = .5,
    playerAlpha = 1,

    ---@type tablelib<integer, {ownerID: integer, ghostType: boolean, ai: boolean, veh: NGVehicle}> index gameVehID
    vehsCaches = Table(),

    ---@type tablelib<integer, integer> index gameVehID, value targetTime
    ghosts = Table(),
    ---@type tablelib<integer, true> index gameVehID
    permaGhosts = Table(),
}

local function getState(ctxt)
    if not ctxt.veh then
        return M.type ~= M.TYPES.DISABLED
    elseif M.type ~= M.TYPES.GHOSTS then
        return M.type == M.TYPES.FORCED or
            not M.vehsCaches[ctxt.veh:getID()].ghostType or
            M.vehsCaches[ctxt.veh:getID()].ai
    else
        return not M.permaGhosts[ctxt.veh:getID()] and
            not M.ghosts[ctxt.veh:getID()]
    end
end

---@param gameVehID integer
---@return number?
local function getVehAlpha(gameVehID)
    local veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
    if not veh then
        return
    end

    local vData = core_vehicle_manager.getVehicleData(gameVehID)
    vData = vData and vData.vData or nil
    vData = vData and vData.flexbodies or nil
    vData = vData and vData[0] or nil
    vData = vData and vData.mesh or nil
    if vData then
        return veh:getMeshAlpha(vData)
    else
        return
    end
end

---@param ctxt TickContext
---@param veh NGVehicle?
---@param alpha number
local function setAlpha(ctxt, veh, alpha)
    if veh and (alpha == M.playerAlpha or not ctxt.veh or ctxt.veh:getID() ~= veh:getID()) then
        core_vehicle_partmgmt.setHighlightedPartsVisiblity(alpha, veh:getID())
    end
end

---@param selfVeh NGVehicle
---@param targetVeh NGVehicle
---@return number
local function getGhostDistance(selfVeh, targetVeh)
    return selfVeh:getInitialLength() / 2 + targetVeh:getInitialLength() / 2 + M.ghostsRadius
end

---@param ctxt TickContext
---@param gameVehID integer
---@param veh NGVehicle?
local function addGhost(ctxt, gameVehID, veh)
    M.ghosts[gameVehID] = GetCurrentTimeMillis() + M.ghostDelay
    if veh then
        veh:queueLuaCommand("obj:setGhostEnabled(true)")
        setAlpha(ctxt, veh, M.ghostAlpha)
    end
end

---@param ctxt TickContext?
---@param gameVehID integer
---@param veh NGVehicle?
local function removeGhost(ctxt, gameVehID, veh)
    M.ghosts[gameVehID] = nil
    if veh then
        veh:queueLuaCommand("obj:setGhostEnabled(false)")
        ctxt = ctxt or BJI.Managers.Tick.getContext()
        setAlpha(ctxt, veh, M.playerAlpha)
    end
end

---@param ctxt TickContext
---@param previousType integer
local function onTypeChange(ctxt, previousType)
    -- remove ghosts
    M.ghosts:forEach(function(_, gameVehID)
        removeGhost(ctxt, gameVehID, M.vehsCaches[gameVehID] and M.vehsCaches[gameVehID].veh or nil)
    end)
    M.ghosts:clear()

    if M.type ~= M.TYPES.GHOSTS then
        M.vehsCaches:filter(function(vehData, gameVehID)
            return vehData.ghostType and not vehData.aid and not M.permaGhosts[gameVehID]
        end):forEach(function(el, gameVehID)
            el.veh:queueLuaCommand("obj:setGhostEnabled(" .. tostring(M.type == M.TYPES.DISABLED) .. ")")
            if M.type == M.TYPES.DISABLED then
                setAlpha(ctxt, el.veh, M.ghostAlpha)
            else -- forced
                setAlpha(ctxt, el.veh, M.playerAlpha)
            end
        end)
    elseif previousType == M.TYPES.DISABLED then
        M.vehsCaches:filter(function(vehData, gameVehID)
            return vehData.ghostType and not vehData.ai and not M.permaGhosts[gameVehID]
        end):forEach(function(vehData, gameVehID)
            addGhost(ctxt, gameVehID, vehData.veh)
        end)
    end
end

---@param gameVehID integer
local function onVehSpawned(gameVehID)
    local veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
    if veh then
        removeGhost(nil, gameVehID)
        local ownerID = BJI.Managers.Veh.getVehOwnerID(gameVehID)
        M.vehsCaches[gameVehID] = {
            ownerID = ownerID,
            ghostType = not table.includes({ BJI.Managers.Veh.TYPES.TRAILER, BJI.Managers.Veh.TYPES.PROP },
                BJI.Managers.Veh.getType(veh.jbeam)),
            ai = veh.isTraffic == "true" or veh.isParked == "true",
            veh = veh,
        }
    end
end

---@param gameVehID integer
local function onVehReset(gameVehID)
    if BJI.Managers.AI.isAIVehicle(gameVehID) then
        local veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
        if veh then
            veh:queueLuaCommand("obj:setGhostEnabled(false)")
        end
        return
    end

    local ctxt = BJI.Managers.Tick.getContext()
    if M.type == M.TYPES.GHOSTS and not M.permaGhosts[gameVehID] then
        local vehData = M.vehsCaches[gameVehID]
        if vehData.ghostType and not vehData.ai then
            addGhost(ctxt, gameVehID, vehData.veh)
        elseif M.ghosts[gameVehID] then
            removeGhost(ctxt, gameVehID, vehData.veh)
        end
    else
        if M.type == M.TYPES.FORCED then
            M.vehsCaches[gameVehID].veh:queueLuaCommand("obj:setGhostEnabled(false)")
        elseif M.type == M.TYPES.DISABLED or M.permaGhosts[gameVehID] then
            setAlpha(ctxt, M.vehsCaches[gameVehID].veh, M.ghostAlpha)
            M.vehsCaches[gameVehID].veh:queueLuaCommand("obj:setGhostEnabled(true)")
        end
    end
end

---@param oldGameVehID integer
---@param newGameVehID integer
local function onVehSwitched(oldGameVehID, newGameVehID)
    local ctxt = BJI.Managers.Tick.getContext()
    if M.type == M.TYPES.GHOSTS then
        -- previous vehicle actions
        if oldGameVehID ~= -1 and (M.ghosts[oldGameVehID] or M.permaGhosts[oldGameVehID]) then
            setAlpha(ctxt, M.vehsCaches[oldGameVehID].veh, M.ghostAlpha)
        end
        -- new vehicle actions
        if newGameVehID ~= -1 and (M.ghosts[newGameVehID] or M.permaGhosts[newGameVehID]) then
            setAlpha(ctxt, M.vehsCaches[newGameVehID].veh, M.playerAlpha)
        end
    elseif M.type == M.TYPES.DISABLED then
        if oldGameVehID ~= -1 and (M.vehsCaches[oldGameVehID].ghostType and not M.vehsCaches[oldGameVehID].ai) then
            setAlpha(ctxt, M.vehsCaches[oldGameVehID].veh, M.ghostAlpha)
        end
        if newGameVehID ~= -1 then
            setAlpha(ctxt, M.vehsCaches[newGameVehID].veh, M.playerAlpha)
        end
    end
end

---@param gameVehID integer
local function onVehDestroyed(gameVehID)
    M.ghosts[gameVehID] = nil
    M.permaGhosts[gameVehID] = nil
    M.vehsCaches[gameVehID] = nil
end

--- Change vehicle manual AI state
---@param gameVehID integer
---@param aiState "disabled"|"traffic"|"stop"|"script"|"flee"|"chase"|"follow"|"manual"|"span"|"random"
local function onVehAIStateChanged(gameVehID, aiState)
    local ctxt = BJI.Managers.Tick.getContext()
    local state = aiState ~= "disabled"
    if not M.vehsCaches[gameVehID].ai and state then
        M.vehsCaches[gameVehID].ai = true
        if M.ghosts[gameVehID] then
            M.ghosts[gameVehID] = nil
            M.vehsCaches[gameVehID].veh:queueLuaCommand("obj:setGhostEnabled(false)")
            setAlpha(ctxt, M.vehsCaches[gameVehID].veh, M.playerAlpha)
        end
    elseif M.vehsCaches[gameVehID].ai and not state then
        M.vehsCaches[gameVehID].ai = false
        if M.type == M.TYPES.GHOSTS then
            if ctxt.veh and ctxt.veh:getID() == gameVehID then
                addGhost(ctxt, gameVehID)
                ctxt.veh:queueLuaCommand("obj:setGhostEnabled(true)")
                -- do not apply ghost alpha on current vehicle
            else
                addGhost(ctxt, gameVehID, M.vehsCaches[gameVehID].veh)
            end
        elseif M.type == M.TYPES.DISABLED then
            M.vehsCaches[gameVehID].veh:queueLuaCommand("obj:setGhostEnabled(true)")
            setAlpha(ctxt, M.vehsCaches[gameVehID].veh, M.ghostAlpha)
        end
    end
end

-- update ghosts
---@param ctxt TickContext
local function fastTick(ctxt)
    if M.type == M.TYPES.GHOSTS then
        local currVeh, targetVeh
        M.ghosts:filter(function(targetTime)
            return targetTime <= ctxt.now
        end):forEach(function(_, gameVehID)
            M.vehsCaches[gameVehID].veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
            currVeh = M.vehsCaches[gameVehID].veh
            if currVeh then
                BJI.Managers.Veh.getPositionRotation(currVeh, function(currVehPos)
                    if not M.vehsCaches:filter(function(_, vid)
                            return not M.ghosts[vid] and not M.permaGhosts[vid]
                        end):any(function(vehData)
                            targetVeh = vehData.veh
                            local targetVehPos = BJI.Managers.Veh.getPositionRotation(targetVeh)
                            return targetVehPos ~= nil and currVehPos:distance(targetVehPos) <
                                getGhostDistance(currVeh, targetVeh)
                        end) then
                        removeGhost(ctxt, gameVehID, currVeh)
                    end
                end)
            end
        end)
    end
end

---@param ctxt TickContext
local function updatePermaghostsAndAI(ctxt)
    -- CHECK PERMAGHOSTS
    BJI.Managers.Context.Players:filter(function(p)
        return p.playerID ~= BJI.Managers.Context.User.playerID
    end):forEach(function(player)
        player.vehicles:map(function(v)
            return v.finalGameVehID
        end):forEach(function(gameVehID)
            if player.isGhost and not M.permaGhosts[gameVehID] and
                M.vehsCaches[gameVehID].ghostType and not M.vehsCaches[gameVehID].ai then
                M.permaGhosts[gameVehID] = true
                if not M.ghosts[gameVehID] and M.type ~= M.TYPES.DISABLED then
                    M.vehsCaches[gameVehID].veh:queueLuaCommand("obj:setGhostEnabled(true)")
                    setAlpha(ctxt, M.vehsCaches[gameVehID].veh, M.ghostAlpha)
                end
                M.ghosts[gameVehID] = nil
            elseif not player.isGhost and M.permaGhosts[gameVehID] then
                M.permaGhosts[gameVehID] = nil
                if M.type == M.TYPES.FORCED then
                    M.vehsCaches[gameVehID].veh:queueLuaCommand("obj:setGhostEnabled(false)")
                    setAlpha(ctxt, M.vehsCaches[gameVehID].veh, M.playerAlpha)
                elseif M.type == M.TYPES.GHOSTS then
                    addGhost(ctxt, gameVehID)
                end
            end
        end)
    end)

    -- CHECK AI
    M.vehsCaches:forEach(function(vehData, gameVehID)
        if not vehData.ai and BJI.Managers.AI.isAIVehicle(gameVehID) then
            -- wasn't an AI and is now
            vehData.ai = true
            vehData.veh:queueLuaCommand("obj:setGhostEnabled(false)")
            if M.ghosts[gameVehID] then
                removeGhost(ctxt, gameVehID, vehData.veh)
            elseif M.permaGhosts[gameVehID] then
                M.permaGhosts[gameVehID] = nil
                setAlpha(ctxt, vehData.veh, M.playerAlpha)
            end
        elseif vehData.ai and not (vehData.ownerID == BJI.Managers.Context.User.playerID and
                BJI.Managers.AI.isSelfAIVehicle(gameVehID) or BJI.Managers.AI.isAIVehicle(gameVehID)) then
            -- was an AI and isn't anymore
            vehData.ai = false
            if BJI.Managers.Context.Players[vehData.ownerID].isGhost then
                M.permaGhosts[gameVehID] = true
                vehData.veh:queueLuaCommand("obj:setGhostEnabled(true)")
                setAlpha(ctxt, vehData.veh, M.ghostAlpha)
            elseif M.type == M.TYPES.GHOSTS then
                addGhost(ctxt, gameVehID, vehData.veh)
            elseif M.type == M.TYPES.DISABLED then
                vehData.veh:queueLuaCommand("obj:setGhostEnabled(false)")
                setAlpha(ctxt, vehData.veh, M.playerAlpha)
            end
        end
    end)
end

local function onLoad()
    BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
    }, function(ctxt)
        -- check scenario type changed
        local nextType = BJI.Managers.Scenario.getCollisionsType(ctxt)
        if nextType ~= M.type then
            local previousType = M.type
            M.type = nextType
            onTypeChange(ctxt, previousType)
        end
    end, M._name)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SPAWNED, onVehSpawned, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_RESETTED, onVehReset, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED, onVehSwitched, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_DESTROYED, onVehDestroyed, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_AI_MODE_CHANGE, onVehAIStateChanged, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.VEHICLES_UPDATED, updatePermaghostsAndAI, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick, M._name)
end

M.onLoad = onLoad
M.getState = getState

return M
