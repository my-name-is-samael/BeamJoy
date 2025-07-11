---@class BJIGPSWp
---@field key string
---@field clearable boolean? default true
---@field radius number?
---@field callback function?
---@field pos vec3?
---@field playerName string?
---@field gameVehID integer?

---@class BJIManagerGPS : BJIManager
local M = {
    _name = "GPS",

    baseFunctions = {},
    ---@type tablelib<integer, BJIGPSWp> index 1-N
    targets = Table(),
    defaultRadius = 5,

    KEYS = {
        STATION = "gasStation",
        DELIVERY_TARGET = "deliveryTarget",
        PLAYER = "player",
        BUS_STOP = "busStop",
        HUNTER = "hunter",
        MANUAL = "manual",
        VEHICLE = "vehicle",
    },

    COLORS = {
        DEFAULT = { .4, .4, 1 },
        STATION = { 1, .4, 0 },
        BUS = { 1, 1, 0 },
        PLAYER = { 1, .5, .5 },
        VEHICLE = { 1, .5, .5 },
    },

    routePlanner = require('/lua/ge/extensions/gameplay/route/route')(),
}
--- gc prevention
local color, pos, typeTarget, targetPlayer, veh, existingIndex, ok, err, target,
targetIndex, length, wps, distance

local function navigateToMission(poiID)
    -- call default to have line animation on bigmap
    M.baseFunctions.navigateToMission(poiID)

    -- manually create waypoint
    pos, typeTarget = nil, M.KEYS.MANUAL
    for _, cluster in ipairs(gameplay_playmodeMarkers.getPlaymodeClusters()) do
        if cluster.containedIdsLookup and cluster.containedIdsLookup[poiID] then
            pos = gameplay_playmodeMarkers.getMarkerForCluster(cluster).pos
            if cluster.elemData and cluster.elemData[1] and
                cluster.elemData[1].type == M.KEYS.STATION then
                typeTarget = M.KEYS.STATION
            end
        end
    end
    if not pos then
        for _, poi in ipairs(extensions.gameplay_rawPois.getRawPoiListByLevel(getCurrentLevelIdentifier())) do
            if poi.id == poiID and poi.markerInfo.bigmapMarker then
                pos = poi.markerInfo.bigmapMarker.pos
                if poi.data and poi.data.type == M.KEYS.STATION then
                    typeTarget = M.KEYS.STATION
                end
            end
        end
    end

    if pos then
        M.prependWaypoint({ key = typeTarget, pos = pos })
        extensions.hook("onNavigateToMission", poiID)
    end
end

local function onUnload()
    M.reset()
    if M.baseFunctions.navigateToMission then
        freeroam_bigMapMode.navigateToMission = M.baseFunctions.navigateToMission
    end
end

local function isClearable()
    for _, t in ipairs(M.targets) do
        if t.clearable == true then
            return true
        end
    end

    return false
end

---@param t BJIGPSWp
---@return number[] color 3 indices, values 0-1
local function getColor(t)
    if t.key == M.KEYS.STATION then
        return M.COLORS.STATION
    elseif t.key == M.KEYS.BUS_STOP then
        return M.COLORS.BUS
    elseif t.key == M.KEYS.PLAYER then
        return M.COLORS.PLAYER
    elseif t.key == M.KEYS.VEHICLE then
        return M.COLORS.VEHICLE
    end
    return M.COLORS.DEFAULT
end

local function renderTargets()
    core_groundMarkers.resetAll()
    if M.targets[1] then
        color = getColor(M.targets[1])
        core_groundMarkers.colorSets.blue.arrows = color
        core_groundMarkers.setPath(M.targets:map(function(t, i) return t.pos end),
            { color = color })
    end
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.GPS_CHANGED)
end

local function reset()
    M.targets = Table()
    renderTargets()
    gameplay_playmodeMarkers.clear()
    extensions.hook("onNavigateToMission", nil)
end

local function clear()
    M.targets = M.targets:filter(function(t) return not t.clearable end)
    renderTargets()
    if #M.targets == 0 then
        gameplay_playmodeMarkers.clear()
        extensions.hook("onNavigateToMission", nil)
    end
end

---@return BJIGPSWp?
local function getByKey(key)
    for _, t in ipairs(M.targets) do
        if t.key == key then
            return t
        end
    end
    return nil
end

local function removeByKey(key)
    M.targets = M.targets:filter(function(t) return t.key ~= key end)
    renderTargets()
end

local function _insertWaypoint(index, previousIndex, target)
    if previousIndex then
        M.targets:remove(previousIndex)
    end
    M.targets:insert(index, target)

    renderTargets()
    BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.INFO_OPEN)
end

local function createPlayerWaypoint(playerName, radius, callback, prepend)
    radius = radius or M.defaultRadius

    if not playerName then
        LogError("Invalid waypoint player name")
        return
    end

    if callback and type(callback) ~= "function" then
        LogError("Invalid waypoint callback")
        return
    end

    targetPlayer = BJI.Managers.Context.Players:find(function(p)
        return p.playerName == playerName
    end)
    if not targetPlayer or not targetPlayer.currentVehicle then
        LogError("Invalid waypoint player")
        return
    end

    veh = BJI.Managers.Veh.getMPVehicle(targetPlayer.currentVehicle)
    if not veh then
        LogError("Invalid waypoint player vehicle")
        return
    end

    if #M.targets > 0 then
        if math.horizontalDistance(M.targets[prepend and 1 or #M.targets].pos, veh.position) < M.defaultRadius then
            LogError("waypoint already exists")
            return
        end
    end

    existingIndex = nil
    M.targets:find(function(t) return t.key == M.KEYS.PLAYER end, function(_, i)
        existingIndex = i
    end)

    return veh.position, radius, existingIndex
end

local function createVehicleWaypoint(gameVehID, radius, callback, prepend)
    radius = radius or M.defaultRadius

    if callback and type(callback) ~= "function" then
        LogError("Invalid waypoint callback")
        return
    end

    veh = BJI.Managers.Veh.getMPVehicle(gameVehID)
    if not veh then
        LogError("Invalid waypoint vehicle (veh not found)")
        return
    end

    if #M.targets > 0 then
        if math.horizontalDistance(M.targets[prepend and 1 or #M.targets].pos, veh.position) < M.defaultRadius then
            LogError("waypoint already exists")
            return
        end
    end

    existingIndex = nil
    M.targets:find(function(t) return t.key == M.KEYS.VEHICLE end, function(_, i)
        existingIndex = i
    end)

    return veh.position, radius, existingIndex
end

---@param key string
---@param pos vec3
---@param radius number
---@param callback fun()?
---@param prepend boolean?
---@return vec3? pos, number? radius, integer? existingIndex
local function commonCreateWaypoint(key, pos, radius, callback, prepend)
    radius = radius or M.defaultRadius

    ok, pos = pcall(vec3, pos)
    if not ok then
        LogError("Invalid waypoint position")
        return
    end

    if callback and type(callback) ~= "function" then
        LogError("Invalid waypoint callback")
        return
    end

    if #M.targets > 0 then
        if math.horizontalDistance(M.targets[prepend and 1 or #M.targets].pos, pos) < M.defaultRadius then
            LogError("waypoint already exists")
            return
        end
    end

    existingIndex = nil
    if key then
        M.targets:find(function(t) return t.key == key end, function(_, i)
            existingIndex = i
        end)
    end

    return pos, radius, existingIndex
end

---@param wp BJIGPSWp
local function prependWaypoint(wp)
    if wp.key == M.KEYS.PLAYER then
        if not wp.playerName then
            error("Invalid waypoint player name")
        end
    elseif wp.key == M.KEYS.VEHICLE then
        if not wp.gameVehID then
            error("Invalid waypoint vehicle (no vid)")
        end
    elseif not wp.pos then
        error("Invalid waypoint")
    end

    if wp.clearable == nil then wp.clearable = true end
    if wp.key == M.KEYS.PLAYER then
        wp.pos, wp.radius, existingIndex = createPlayerWaypoint(wp.playerName, wp.radius, wp.callback, true)
    elseif wp.key == M.KEYS.VEHICLE then
        wp.pos, wp.radius, existingIndex = createVehicleWaypoint(wp.gameVehID, wp.radius, wp.callback, true)
    else
        wp.pos, wp.radius, existingIndex = commonCreateWaypoint(wp.key, wp.pos, wp.radius, wp.callback, true)
    end

    if wp.pos then
        local target = {
            key = wp.key,
            radius = wp.radius,
            callback = wp.callback or function() end,
            clearable = wp.clearable,
            pos = wp.pos,
            playerName = wp.playerName,
            gameVehID = wp.gameVehID,
        }

        _insertWaypoint(1, existingIndex, target)
    end
end

---@param wp BJIGPSWp
local function appendWaypoint(wp)
    if wp.key == M.KEYS.PLAYER then
        if not wp.playerName then
            error("Invalid waypoint player name")
        end
    elseif wp.key == M.KEYS.VEHICLE then
        if not wp.gameVehID then
            error("Invalid waypoint vehicle (no vid)")
        end
    elseif not wp.pos then
        error("Invalid waypoint")
    end

    if wp.clearable == nil then wp.clearable = true end
    if wp.key == M.KEYS.PLAYER then
        wp.pos, wp.radius, existingIndex = createPlayerWaypoint(wp.playerName, wp.radius, wp.callback)
    elseif wp.key == M.KEYS.VEHICLE then
        wp.pos, wp.radius, existingIndex = createVehicleWaypoint(wp.gameVehID, wp.radius, wp.callback)
    else
        wp.pos, wp.radius, existingIndex = commonCreateWaypoint(wp.key, wp.pos, wp.radius, wp.callback)
    end

    if wp.pos then
        target = {
            key = wp.key,
            radius = wp.radius,
            callback = wp.callback or function() end,
            clearable = wp.clearable,
            pos = wp.pos,
            playerName = wp.playerName,
            gameVehID = wp.gameVehID,
        }

        targetIndex = #M.targets
        if not existingIndex then
            targetIndex = #M.targets + 1
        end
        _insertWaypoint(targetIndex, existingIndex, target)
    end
end

local function getCurrentRouteLength()
    return #M.targets > 0 and math.round(core_groundMarkers.getPathLength(), 3) or 0
end

---@param points vec3[]
local function getRouteLength(points)
    if type(points) ~= "table" or #points < 2 then
        return 0
    end

    M.routePlanner:clear()

    wps = {}
    for _, wp in ipairs(points) do
        ok, pos, err = pcall(vec3, wp)
        if not err then
            table.insert(wps, pos)
        end
    end
    M.routePlanner:setupPathMulti(wps)

    if M.routePlanner.path and M.routePlanner.path[1] then
        length = math.round(M.routePlanner.path[1].distToTarget, 3)
    else
        length = 0
    end
    M.routePlanner:clear()
    return length
end

---@param ctxt TickContext
local function checkTargetReached(ctxt)
    target = #M.targets > 0 and M.targets[1] or nil
    if ctxt.veh and target then
        distance = ctxt.veh.position:distance(target.pos)
        if type(distance) ~= "number" then
            LogError("invalid next target distance")
            return
        end
        if type(target.radius) ~= "number" then
            LogError("invalid next target radius")
            return
        end
        if distance < target.radius then
            M.targets:remove(1)
            renderTargets()
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.INFO_OPEN)
            ok, err = pcall(target.callback, ctxt)
            if not ok then
                LogError(string.var("Error executing GPS callback: {1}", { err }))
            end
        end
    end
end

local function _onLastTargetReached()
    renderTargets()
    BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.INFO_OPEN)
end

local function deleteAndCheckLast(i)
    M.targets:remove(i)
    if #M.targets == 0 then
        _onLastTargetReached()
    end
end

local updateIndex = 0
local function updateTargets()
    updateIndex = (updateIndex + 1) % 2
    -- update around twice/sec
    if updateIndex == 0 then
        -- update player
        M.targets:find(function(t) return t.key == M.KEYS.PLAYER end,
            function(t, i)
                if not t.playerName then
                    return deleteAndCheckLast(i)
                end

                targetPlayer = BJI.Managers.Context.Players:find(function(p)
                    return p.playerName == t.playerName
                end)
                if not targetPlayer or not targetPlayer.currentVehicle then
                    -- player left or no target vehicle
                    return deleteAndCheckLast(i)
                end

                veh = BJI.Managers.Veh.getMPVehicle(targetPlayer.currentVehicle)
                if veh then
                    t.pos = veh.position
                    renderTargets()
                else
                    -- player have invalid vehicle
                    return deleteAndCheckLast(i)
                end
            end)
        -- update vehicle
        M.targets:find(function(t) return t.key == M.KEYS.VEHICLE end,
            function(t, i)
                if not t.gameVehID then
                    return deleteAndCheckLast(i)
                end

                veh = BJI.Managers.Veh.getMPVehicle(t.gameVehID)
                if veh then
                    t.pos = veh.position
                    renderTargets()
                else
                    -- invalid vehicle
                    return deleteAndCheckLast(i)
                end
            end)
    end
end

---@param ctxt TickContext
local function fastTick(ctxt)
    if #M.targets > 0 and M.targets:any(function(t)
            return table.includes({ M.KEYS.PLAYER, M.KEYS.VEHICLE }, t.key)
        end) then
        updateTargets()
    end
end

---@param ctxt TickContext
local function renderTick(ctxt)
    checkTargetReached(ctxt)
end

local function onLoad()
    if freeroam_bigMapMode then
        M.baseFunctions.navigateToMission = freeroam_bigMapMode.navigateToMission

        freeroam_bigMapMode.navigateToMission = navigateToMission
    end

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick, M._name)
end

M.isClearable = isClearable
M.reset = reset
M.clear = clear
M.getByKey = getByKey
M.removeByKey = removeByKey
M.prependWaypoint = prependWaypoint
M.appendWaypoint = appendWaypoint

M.getCurrentRouteLength = getCurrentRouteLength
M.getRouteLength = getRouteLength

M.onLoad = onLoad
M.renderTick = renderTick

return M
