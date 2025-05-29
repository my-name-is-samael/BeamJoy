---@class BJIManagerGPS : BJIManager
local M = {
    _name = "GPS",

    baseFunctions = {},
    targets = Table(),
    defaultRadius = 5,

    KEYS = {
        STATION = "gasStation",
        DELIVERY_TARGET = "deliveryTarget",
        PLAYER = "player",
        BUS_STOP = "busStop",
        HUNTER = "hunter",
        MANUAL = "manual",
        TAGGED = "tagged",
    },

    COLORS = {
        DEFAULT = { .4, .4, 1 },
        STATION = { 1, .4, 0 },
        BUS = { 1, 1, 0 },
        PLAYER = { 1, .5, .5 },
    },

    routePlanner = require('/lua/ge/extensions/gameplay/route/route')(),
}

local function navigateToMission(poiID)
    -- call default to have line animation on bigmap
    M.baseFunctions.navigateToMission(poiID)

    -- manually create waypoint
    local pos, type = nil, M.KEYS.MANUAL
    for _, cluster in ipairs(gameplay_playmodeMarkers.getPlaymodeClusters()) do
        if cluster.containedIdsLookup and cluster.containedIdsLookup[poiID] then
            local marker = gameplay_playmodeMarkers.getMarkerForCluster(cluster)
            pos = marker.pos
            if cluster.elemData and cluster.elemData[1] and
                cluster.elemData[1].type == M.KEYS.STATION then
                type = M.KEYS.STATION
            end
        end
    end
    if not pos then
        for _, poi in ipairs(extensions.gameplay_rawPois.getRawPoiListByLevel(getCurrentLevelIdentifier())) do
            if poi.id == poiID and poi.markerInfo.bigmapMarker then
                pos = poi.markerInfo.bigmapMarker.pos
                if poi.data and poi.data.type == M.KEYS.STATION then
                    type = M.KEYS.STATION
                end
            end
        end
    end

    if pos then
        M.prependWaypoint(type, pos, M.defaultRadius)
        extensions.hook("onNavigateToMission", poiID)
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

local function getColor(t)
    if t.key == M.KEYS.STATION then
        return M.COLORS.STATION
    elseif t.key == M.KEYS.BUS_STOP then
        return M.COLORS.BUS
    elseif t.key == M.KEYS.PLAYER then
        return M.COLORS.PLAYER
    end
    return M.COLORS.DEFAULT
end

local function renderTargets()
    core_groundMarkers.resetAll()
    if #M.targets > 0 then
        core_groundMarkers.setPath(M.targets:map(function(t, i) return t.pos end),
            { color = M.targets[1] and getColor(M.targets[1]) or nil })
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

local function _commonCreateWaypoint(key, pos, radius, callback, playerName, prepend)
    radius = radius or M.defaultRadius

    if key == M.KEYS.PLAYER then
        if not playerName then
            LogError("Invalid waypoint player name")
            return
        end

        local targetPlayer = nil
        for _, player in pairs(BJI.Managers.Context.Players) do
            if player.playerName == playerName then
                targetPlayer = player
                break
            end
        end
        if not targetPlayer or not targetPlayer.currentVehicle then
            LogError("Invalid waypoint player")
            return
        end

        local veh = BJI.Managers.Veh.getVehicleObject(targetPlayer.currentVehicle)
        local posrot = BJI.Managers.Veh.getPositionRotation(veh)
        if posrot then
            pos = posrot.pos
        else
            LogError("Invalid waypoint player vehicle")
            return
        end
    else
        local status
        status, pos = pcall(vec3, pos)
        if not status then
            LogError("Invalid waypoint position")
            return
        end
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

    local existingIndex
    if key then
        for i, t in ipairs(M.targets) do
            if t.key == key then
                -- existing by key, so replace its data
                existingIndex = i
                break
            end
        end
    end

    return pos, radius, existingIndex
end

local function prependWaypoint(key, pos, radius, callback, playerName, clearable)
    if clearable == nil then clearable = true end
    local existingIndex
    pos, radius, existingIndex = _commonCreateWaypoint(key, pos, radius, callback, playerName, true)

    if pos then
        local target = {
            key = key,
            playerName = playerName,
            pos = pos,
            radius = radius,
            callback = callback or function() end,
            clearable = clearable
        }

        _insertWaypoint(1, existingIndex, target)
    end
end

local function appendWaypoint(key, pos, radius, callback, playerName, clearable)
    if clearable == nil then clearable = true end
    local existingIndex
    pos, radius, existingIndex = _commonCreateWaypoint(key, pos, radius, callback, playerName, false)

    if pos then
        local target = {
            key = key,
            playerName = playerName,
            pos = pos,
            radius = radius,
            callback = callback or function() end,
            clearable = clearable
        }

        local targetIndex = #M.targets
        if not existingIndex then
            targetIndex = #M.targets + 1
        end
        _insertWaypoint(targetIndex, existingIndex, target)
    end
end

local function getCurrentRouteLength()
    return #M.targets > 0 and math.round(core_groundMarkers.getPathLength(), 3) or 0
end

--[[
<ul>
    <li>points: array of vec3</li>
</ul>
]]
local function getRouteLength(points)
    if type(points) ~= "table" or #points < 2 then
        return 0
    end

    M.routePlanner:clear()

    local wps = {}
    for _, wp in ipairs(points) do
        local _, pos, err = pcall(vec3, wp)
        if not err then
            table.insert(wps, pos)
        end
    end
    M.routePlanner:setupPathMulti(wps)

    local length
    if M.routePlanner.path and M.routePlanner.path[1] then
        length = math.round(M.routePlanner.path[1].distToTarget, 3)
    else
        length = 0
    end
    M.routePlanner:clear()
    return length
end

local function fastTick(ctxt)
    local wp = #M.targets > 0 and M.targets[1] or nil
    if ctxt.vehPosRot and wp then
        local distance = ctxt.vehPosRot.pos:distance(wp.pos)
        if type(distance) ~= "number" then
            LogError("invalid next target distance")
            return
        end
        if type(wp.radius) ~= "number" then
            LogError("invalid next target radius")
            return
        end
        if distance < wp.radius then
            M.targets:remove(1)
            renderTargets()
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.INFO_OPEN)
            pcall(wp.callback, ctxt)
        end
    end
end

local function _onLastTargetReached()
    renderTargets()
    BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.INFO_OPEN)
end

local function slowTick()
    local function deleteAndCheckLast(i)
        M.targets:remove(i)
        if #M.targets == 0 then
            _onLastTargetReached()
        end
    end
    M.targets:find(function(t) return t.key == M.KEYS.PLAYER end,
        function(t, i)
            if not t.playerName then
                return deleteAndCheckLast(i)
            end

            local player = Table(BJI.Managers.Context.Players)
                :find(function(p) return p.playerName == t.playerName end)
            if not player then
                -- player left
                return deleteAndCheckLast(i)
            end

            if not player.currentVehicle then
                -- player doesn't have a vehicle
                return deleteAndCheckLast(i)
            end

            local veh = BJI.Managers.Veh.getVehicleObject(player.currentVehicle)
            local posrot = veh and BJI.Managers.Veh.getPositionRotation(veh) or nil
            if veh and posrot then
                t.pos = posrot.pos
                renderTargets()
            else
                -- player have invalid vehicle
                return deleteAndCheckLast(i)
            end
        end)
end

local listeners = Table()
local function onLoad()
    if freeroam_bigMapMode then
        M.baseFunctions.navigateToMission = freeroam_bigMapMode.navigateToMission

        freeroam_bigMapMode.navigateToMission = navigateToMission
    end

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick, M._name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    M.reset()
    if M.baseFunctions.navigateToMission then
        freeroam_bigMapMode.navigateToMission = M.baseFunctions.navigateToMission
    end
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
M.onUnload = onUnload

return M
