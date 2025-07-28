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

    resetBypass = false,
}
--- gc prevention
local color, pos, targetPlayer, veh, existingIndex, ok, err, target,
targetIndex, length, wps, distance

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
    extensions.core_groundMarkers.resetAll()
    if M.targets[1] then
        color = getColor(M.targets[1])
        extensions.core_groundMarkers.colorSets.blue.arrows = color
        M.baseFunctions.core_groundMarkers.setPath(M.targets:map(function(t, i) return t.pos end),
            { color = color })
    end
    BJI_Events.trigger(BJI_Events.EVENTS.GPS_CHANGED)
end

local function reset()
    M.targets = Table()
    renderTargets()
    extensions.gameplay_playmodeMarkers.clear()
    M.resetBypass = true
    extensions.freeroam_bigMapMode.setNavFocus()
    extensions.hook("onNavigateToMission", nil)
end

local function clear()
    M.targets = M.targets:filter(function(t) return not t.clearable end)
    renderTargets()
    if #M.targets == 0 then
        extensions.gameplay_playmodeMarkers.clear()
        M.resetBypass = true
        extensions.freeroam_bigMapMode.setNavFocus()
        extensions.hook("onNavigateToMission", nil)
    end
end

---@param key string
---@return BJIGPSWp?
local function getByKey(key)
    for _, t in ipairs(M.targets) do
        if t.key == key then
            return t
        end
    end
    return nil
end

---@param key string
local function removeByKey(key)
    M.targets = M.targets:filter(function(t) return t.key ~= key end)
    renderTargets()
end

---@param index integer
---@param previousIndex integer?
---@param target BJIGPSWp
local function _insertWaypoint(index, previousIndex, target)
    if previousIndex then
        M.targets:remove(previousIndex)
    end
    M.targets:insert(index, target)

    renderTargets()
    BJI_Sound.play(BJI_Sound.SOUNDS.INFO_OPEN)
end

---@param wp BJIGPSWp
---@return boolean ok
local function createPlayerWaypoint(wp)
    if not wp.playerName then
        LogError("Invalid waypoint player name")
        return false
    end

    targetPlayer = BJI_Context.Players:find(function(p)
        return p.playerName == wp.playerName
    end)
    if not targetPlayer or not targetPlayer.currentVehicle then
        LogError("Invalid waypoint player")
        return false
    end

    veh = BJI_Veh.getMPVehicles({ ownerID = targetPlayer.playerID }):find(function(v)
        return (v.isLocal and v.gameVehicleID or v.remoteVehID) == targetPlayer.currentVehicle
    end)
    if not veh then
        LogError("Invalid waypoint player vehicle " .. tostring(targetPlayer.currentVehicle))
        return false
    end

    wp.pos = veh.position
    return true
end

---@param wp BJIGPSWp
---@return boolean ok
local function createVehicleWaypoint(wp)
    if not wp.gameVehID then
        LogError("Invalid waypoint vehicle (no vid)")
        return false
    end

    veh = BJI_Veh.getMPVehicle(wp.gameVehID)
    if not veh then
        LogError("Invalid waypoint vehicle (veh not found)")
        return false
    end

    wp.pos = veh.position
    return true
end

---@param wp BJIGPSWp
---@param prepend boolean?
---@return integer? existingIndex
local function commonCreateWaypoint(wp, prepend)
    if wp.clearable == nil then wp.clearable = true end
    wp.radius = wp.radius or M.defaultRadius

    if wp.callback and type(wp.callback) ~= "function" then
        LogError("Invalid waypoint callback")
        return
    end

    if wp.key == M.KEYS.PLAYER then
        if not createPlayerWaypoint(wp) then return end
    elseif wp.key == M.KEYS.VEHICLE then
        if not createVehicleWaypoint(wp) then return end
    else
        ok, wp.pos = pcall(vec3, wp.pos)
        if not ok then
            LogError("Invalid waypoint position")
            return
        end
    end

    if #M.targets > 0 then
        if math.horizontalDistance(M.targets[prepend and 1 or #M.targets].pos, wp.pos) < M.defaultRadius then
            LogError("waypoint already exists")
            return
        end
    end

    existingIndex = nil
    if wp.key then
        M.targets:find(function(t) return t.key == wp.key end, function(_, i)
            existingIndex = i
        end)
    end

    return existingIndex
end

---@param wp BJIGPSWp
local function prependWaypoint(wp)
    existingIndex = commonCreateWaypoint(wp, true)

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

        _insertWaypoint(1, existingIndex, target)
    end
end

---@param wp BJIGPSWp
local function appendWaypoint(wp)
    existingIndex = commonCreateWaypoint(wp)

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
    return #M.targets > 0 and math.round(extensions.core_groundMarkers.getPathLength(), 3) or 0
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
            BJI_Sound.play(BJI_Sound.SOUNDS.INFO_OPEN)
            ok, err = pcall(target.callback, ctxt)
            if not ok then
                LogError(string.var("Error executing GPS callback: {1}", { err }))
            end
        end
    end
end

local function _onLastTargetReached()
    renderTargets()
    BJI_Sound.play(BJI_Sound.SOUNDS.INFO_OPEN)
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

                targetPlayer = BJI_Context.Players:find(function(p)
                    return p.playerName == t.playerName
                end)
                if not targetPlayer or not targetPlayer.currentVehicle then
                    -- player left or no target vehicle
                    return deleteAndCheckLast(i)
                end

                veh = BJI_Veh.getMPVehicles({ ownerID = targetPlayer.playerID }):find(function(v)
                    return (v.isLocal and v.gameVehicleID or v.remoteVehID) == targetPlayer.currentVehicle
                end)
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

                veh = BJI_Veh.getMPVehicle(t.gameVehID)
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

local function coreSetPath(wps, options)
    if M.resetBypass then
        M.resetBypass = false
        return
    end

    if not wps then
        return M.clear()
    end

    if type(wps) ~= "table" then
        wps = { wps }
    end

    table.forEach(wps, function(pos)
        local key, radius = M.KEYS.MANUAL, 3
        BJI_Stations.Data.Garages:find(function(g)
            return g.pos:distance(pos) < .1
        end, function(g)
            key = M.KEYS.STATION
            radius = g.radius
        end)

        if key == M.KEYS.MANUAL then
            BJI_Stations.Data.EnergyStations:find(function(es)
                return es.pos:distance(pos) < .1
            end, function(es)
                key = M.KEYS.STATION
                radius = es.radius
            end)
        end

        M.appendWaypoint({
            key = key,
            pos = pos,
            radius = radius,
            clearable = true,
        })
    end)
end

local function onUnload()
    M.reset()
    RollBackNGFunctionsWrappers(M.baseFunctions)
end

local function onLoad()
    if freeroam_bigMapMode then
        extensions.load("core_groundMarkers", "gameplay_playmodeMarkers", "freeroam_bigMapMode")
        M.baseFunctions = {
            core_groundMarkers = {
                setPath = extensions.core_groundMarkers.setPath
            }
        }

        extensions.core_groundMarkers.setPath = coreSetPath
    end

    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.FAST_TICK, fastTick, M._name)
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
