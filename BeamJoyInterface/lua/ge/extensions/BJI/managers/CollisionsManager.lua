---@class BJIManagerCollisions : BJIManager
local M = {
    _name = "Collisions",

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
    local veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
    if not veh then
        return
    end

    local vData = core_vehicle_manager.getVehicleData(gameVehID).vdata
    if vData and vData.flexbodies and vData.flexbodies[0] then
        return veh:getMeshAlpha(vData.flexbodies[0].mesh)
    else
        return
    end
end

---@param gameVehID integer
---@return boolean
local function isVehicle(gameVehID)
    local veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
    return veh ~= nil and not BJI.Managers.Veh.isUnicycle(gameVehID) and
        not table.includes({ BJI.Managers.Veh.TYPES.TRAILER, BJI.Managers.Veh.TYPES.PROP },
            BJI.Managers.Veh.getType(veh.jbeam))
end

---@param gameVehID integer
---@return boolean
local function canBecomeGhost(gameVehID)
    return isVehicle(gameVehID) and not BJI.Managers.AI.isAIVehicle(gameVehID)
end

local function setCollisions(state)
    if state ~= M.state then
        be:setDynamicCollisionEnabled(state)
        M.state = state
    end
end

local function setAlpha(gameVehID, alpha)
    if BJI.Managers.Veh.getVehicleObject(gameVehID) then
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

    local veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
    if not veh then
        return false
    end

    local attachedVehs = Table(core_vehicle_partmgmt.findAttachedVehicles(veh:getID()))
    return Table(BJI.Managers.Veh.getMPVehicles()):values()
        :map(function(v)
            return BJI.Managers.Veh.getVehicleObject(v.gameVehicleID)
        end)
        :filter(function(v)
            return v:getID() ~= gameVehID and not attachedVehs:includes(v:getID()) and
                isVehicle(v:getID()) and BJI.Managers.Veh.getPositionRotation(veh).pos:distance(
                    BJI.Managers.Veh.getPositionRotation(v).pos) < getGhostDistance(veh, v)
        end)
end

---@param gameVehID integer
---@param onReset? boolean
local function applyGhostTransparency(gameVehID, onReset)
    if onReset then
        -- apply multiple times to prevent desyncs
        table.forEach({ 0, 300, 600 }, function(delay)
            -- apply alpha if not my current veh
            BJI.Managers.Async.delayTask(function(ctxt)
                if BJI.Managers.Veh.getVehicleObject(gameVehID) and
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

    ctxt = ctxt or BJI.Managers.Tick.getContext()
    M.ghosts[gameVehID] = true
    if ctxt.veh and ctxt.veh:getID() == gameVehID then
        setCollisions(false)
    else
        applyGhostTransparency(gameVehID, onReset)
    end

    local minTime = GetCurrentTimeMillis() + M.ghostDelay
    local eventName = string.var(M.ghostProcessKey, { gameVehID })
    BJI.Managers.Async.removeTask(eventName)
    BJI.Managers.Async.task(function(ctxt2)
        -- collisions changed or not valid anymore
        if M.type ~= M.TYPES.GHOSTS or not BJI.Managers.Veh.getVehicleObject(gameVehID) or BJI.Managers.AI.isAIVehicle(gameVehID) then
            return true
        end

        -- ghost contamination here ^^
        local closeVehs = getCloseVehicles(gameVehID)
        if #closeVehs > 0 then
            BJI.Managers.Async.delayTask(function(ctxt3)
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
        if M.type ~= M.TYPES.GHOSTS or not BJI.Managers.Veh.getVehicleObject(gameVehID) then
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
---@param gameVehID integer
local function onVehicleResetted(gameVehID)
    if gameVehID == -1 or BJI.Managers.AI.isAIVehicle(gameVehID) then
        return
    end

    if M.permaGhosts[gameVehID] then
        applyGhostTransparency(gameVehID, true)
        return
    end

    if M.type == M.TYPES.GHOSTS then
        local veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
        if not veh or not isVehicle(gameVehID) then
            return
        end

        addGhost(gameVehID, nil, true)
    elseif M.type == M.TYPES.DISABLED then
        local ctxt = BJI.Managers.Tick.getContext()
        if not (ctxt.isOwner and ctxt.veh:getID() == gameVehID) then
            applyGhostTransparency(gameVehID, true)
        end
    end
end

---@param oldGameVehID integer
---@param newGameVehID integer
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

---@param gameVehID integer
local function onVehicleDeleted(gameVehID)
    if M.ghosts[gameVehID] then
        M.ghosts[gameVehID] = nil
        BJI.Managers.Async.removeTask(string.var(M.ghostProcessKey, { gameVehID }))
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
                local target = BJI.Managers.Veh.getVehicleObject(gameVehID)
                local distance = ctxt.vehPosRot.pos:distance(BJI.Managers.Veh.getPositionRotation(target).pos)
                return distance < M.ghostsRadius
            end)
        end) then
        addGhost(ctxt.veh:getID(), ctxt)
    end
end

-- when spawning AI vehicles, alpha can get desynced
local function checkAIVehicles()
    if table.includes({ M.TYPES.GHOSTS, M.TYPES.FORCED }, M.type) then
        Table(BJI.Managers.Context.Players)
            :map(function(p)
                return p.ai
            end):flat()
            :forEach(function(vid)
                BJI.Managers.Async.task(function()
                    return BJI.Managers.Veh.isVehReady(vid)
                end, function()
                    local a = getVehAlpha(vid)
                    if a and a ~= M.playerAlpha then
                        setAlpha(vid, M.playerAlpha)
                        LogWarn(("Restored desync alpha from {1}"):var({ a }))
                    end
                end, string.var("CheckAIAlpha-{1}", { vid }))
            end)
    end
end

local ghostsFixingProcess = { time = 10, count = 0 } -- check every 10 seconds
---@param ctxt SlowTickContext
local function slowTick(ctxt)
    ghostsFixingProcess.count = ghostsFixingProcess.count + 1
    if ghostsFixingProcess.count >= ghostsFixingProcess.time then
        if M.type == M.TYPES.GHOSTS then
            -- clear invalid ghosts
            local saw = {}
            Table(BJI.Managers.Veh.getMPVehicles())
            ---@param mpVeh BJIMPVehicle
                :forEach(function(mpVeh)
                    if not M.ghosts[mpVeh.gameVehicleID] and not M.permaGhosts[mpVeh.gameVehicleID] then
                        local alpha = getVehAlpha(mpVeh.gameVehicleID)
                        if alpha and alpha < M.playerAlpha then
                            setAlpha(mpVeh.gameVehicleID, M.playerAlpha)
                            LogDebug(string.var("Fixed veh alpha for {1}", { mpVeh.gameVehicleID }))
                        end
                    elseif not isVehicle(mpVeh.gameVehicleID) or
                        BJI.Managers.AI.isAIVehicle(mpVeh.gameVehicleID) then
                        M.ghosts[mpVeh.gameVehicleID] = nil
                        BJI.Managers.Async.removeTask(string.var(M.ghostProcessKey, { mpVeh.gameVehicleID }))
                        M.permaGhosts[mpVeh.gameVehicleID] = nil
                        setAlpha(mpVeh.gameVehicleID, M.playerAlpha)
                    end
                    saw[mpVeh.gameVehicleID] = true
                end)
            M.ghosts:filter(function(_, id) return not saw[id] end)
                :forEach(function(_, id)
                    M.ghosts[id] = nil
                    BJI.Managers.Async.removeTask(string.var(M.ghostProcessKey, { id }))
                end)
        end
        ghostsFixingProcess.count = 0
    end
end

local function updatePermaGhosts()
    if M.type == M.TYPES.GHOSTS then
        Table(BJI.Managers.Context.Players)
            :filter(function(p) return p.playerID ~= BJI.Managers.Context.User.playerID end)
            :forEach(function(player)
                Table(player.vehicles)
                    :map(function(v) return v.finalGameVehID end)
                    :filter(function(gameVehID)
                        local veh = BJI.Managers.Veh.getVehicleObject(gameVehID)
                        return veh ~= nil and canBecomeGhost(gameVehID)
                    end)
                    :forEach(function(gameVehID)
                        if player.isGhost and not M.permaGhosts[gameVehID] then
                            M.permaGhosts[gameVehID] = true
                            if M.ghosts[gameVehID] then
                                BJI.Managers.Async.removeTask(string.var(M.ghostProcessKey, { gameVehID }))
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
        BJI.Managers.Async.removeTask(string.var(M.ghostProcessKey, { gameVehID }))
        setAlpha(gameVehID, M.playerAlpha)
    end)
    M.ghosts:clear()
    M.permaGhosts:clear()
    if nextType ~= M.TYPES.GHOSTS then
        if nextType == M.TYPES.DISABLED then
            table.forEach(BJI.Managers.Veh.getMPVehicles(), function(veh)
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

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function onLoad()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
    }, function(ctxt)
        local nextType = BJI.Managers.Scenario.getCollisionsType(ctxt)
        if nextType ~= M.type then
            onTypeChange(ctxt, nextType)
            M.type = nextType
        end
    end, M._name))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI.Managers.Cache.CACHES.PLAYERS then
            updatePermaGhosts()
        end
    end, M._name))

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_RESETTED, onVehicleResetted, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED, onVehicleSwitched, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_DESTROYED, onVehicleDeleted, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
end

M.onLoad = onLoad
M.checkAIVehicles = checkAIVehicles
M.renderTick = renderTick

return M
