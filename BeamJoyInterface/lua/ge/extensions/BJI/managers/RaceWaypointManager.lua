---@class BJIManagerRaceWaypoint : BJIManager
local M = {
    _name = "RaceWaypoint",

    _race = {
        _started = false,
        _countWp = 0,
        _onWaypoint = nil,
        _onFinish = nil,
        _steps = {},
    },
    _raceMarker = require("scenario/race_marker"),
    _targets = {},
    _markers = {},
    _modes = {},
    _markerType = "sideColumnMarker",
    --[[TYPES = { -- only sideColumnMarker is not crashing the game on disconnect, so disabling TYPES
        DEFAULT = "sideColumnMarker",
        SIDE = "sideMarker", -- avoid using it, crashes the game on disconnect
        CYLINDER = "cylinderMarker", -- avoid using it, crashes the game on disconnect
        RING = "ringMarker", -- avoid using it, crashes the game on disconnect
        MARKER_SMALL = "overhead", -- avoid using it, crashes the game on disconnect
        MARKER_BIG = "attention", -- avoid using it, crashes the game on disconnect
        NONE = "noneMarker", -- do not use
    },]]
    COLORS = {
        DEFAULT = "default",
        RED = "default",     -- 1, 0.07, 0
        BLACK = "next",      -- 0, 0, 0
        GREEN = "lap",       -- 0.4, 1, 0.2
        YELLOW = "recovery", -- 1, 0.85, 0
        BLUE = "final",      -- 0.1, 0.3, 1
        ORANGE = "branch",   -- 1, 0.6, 0
        --[[M.TYPES.DEFAULT] = {
            DEFAULT = "default",
            RED = "default",     -- 1, 0.07, 0
            BLACK = "next",      -- 0, 0, 0
            GREEN = "lap",       -- 0.4, 1, 0.2
            YELLOW = "recovery", -- 1, 0.85, 0
            BLUE = "final",      -- 0.1, 0.3, 1
            ORANGE = "branch",   -- 1, 0.6, 0
        },
        [M.TYPES.SIDE] = {
            DEFAULT = "default",
            RED = "default",   -- 1, 0.07, 0
            BLACK = "next",    -- 0, 0, 0
            GREEN = "lap",     -- 0.4, 1, 0.2
            BLUE = "final",    -- 0.1, 0.3, 1
            ORANGE = "branch", -- 1, 0.6, 0
        },
        [M.TYPES.CYLINDER] = {
            DEFAULT = "default",
            RED = "default",     -- 1, 0.07, 0
            BLACK = "next",       -- 0.3, 0.3, 0.3
            GREEN = "lap",       -- 0.4, 1, 0.2
            YELLOW = "recovery", -- 1, 0.85, 0
            BLUE = "final",      -- 0.1, 0.3, 1
            ORANGE = "branch",   -- 1, 0.6, 0
        },
        [M.TYPES.RING] = {
            DEFAULT = "default",
            RED = "default",   -- 1, 0.07, 0
            BLACK = "next",    -- 0, 0, 0
            GREEN = "lap",     -- 0.4, 1, 0.2
            BLUE = "final",    -- 0.1, 0.3, 1
            ORANGE = "branch", -- 1, 0.6, 0
        },
        [M.TYPES.MARKER_BIG] = {
            DEFAULT = "default", -- anything but "hidden"
        },
        [M.TYPES.MARKER_SMALL] = {
            DEFAULT = "default",
            RED = "default",   -- 1, 0.333, 0
            BLACK = "next",    -- 0, 0, 0
            GREEN = "lap",     -- 0.4, 1, 0.2
            BLUE = "final",    -- 0.1, 0.3, 1
            ORANGE = "branch", -- 1, 0.6, 0.07
        },]]
    },
    _defaultRadius = 1,
    _radiusMargin = 1,
}
-- MarkerTypes that require a rotation value
M.MARKER_TYPES_ROT = { --[[M.TYPES.RING]] }
M._raceMarker.init()

local function resetAll()
    M._race._started = false
    M._race._countWp = 0
    M._race._onWaypoint = nil
    M._race._onFinish = nil
    table.clear(M._race._steps)

    table.clear(M._targets)
    table.clear(M._markers)
    table.clear(M._modes)

    M._raceMarker.setupMarkers({})
end

-- RACE

-- fn: function(currentWaypoint, amountRemaining)
local function setRaceWaypointHandler(fn)
    M._race._onWaypoint = fn
    return M
end

-- fn: function()
local function setRaceFinishHandler(fn)
    M._race._onFinish = fn
    return M
end

local function isRacing()
    return M._race._started
end

---@param step {name: string, pos: vec3, zOffset?:number, rot: vec3, radius: number, parents: string[], lap?: boolean, stand?: boolean}[]
local function addRaceStep(step)
    if M._race._started then
        LogError("already started", M._name)
        return
    elseif type(step) ~= "table" or #step == 0 then
        return
    end

    local target = {}

    for _, wp in ipairs(step) do
        table.insert(target, {
            name = wp.name,
            pos = wp.pos,
            zOffset = wp.zOffset,
            rot = wp.rot,
            radius = wp.radius,
            parents = wp.parents,
            lap = wp.lap == true,
            stand = wp.stand == true,
        })
    end


    table.insert(M._race._steps, target)
end

local function updateRaceMarkers(lastWp)
    if not M.isRacing() then
        return
    end

    local wpName = "start"
    if lastWp then
        wpName = lastWp.name
    end

    table.clear(M._targets)
    table.clear(M._markers)
    table.clear(M._modes)

    if #M._race._steps > 0 then
        -- next marker
        for iStep, step in ipairs(M._race._steps) do
            for iWp, wp in ipairs(step) do
                if table.includes(wp.parents, wpName) and            -- is child
                    not (wp.stand and iStep == #M._race._steps) then -- disable stand if last step
                    table.insert(M._targets, {
                        step = iStep,
                        wp = iWp,
                    })

                    local normal
                    if not wp.stand then
                        local angle = math.angleFromQuatRotation(wp.rot)
                        normal = math.rotate2DVec(vec3(0, wp.radius, 0), angle - math.rad(1))
                        normal = normal:normalized()
                    end

                    table.insert(M._markers, {
                        name = wp.name,
                        pos = wp.pos,
                        normal = normal,
                        radius = wp.radius,
                        fadeNear = false,
                        fadeFar = false,
                    })

                    local color = M.COLORS.RED  -- base
                    if wp.stand then
                        color = M.COLORS.ORANGE -- stand stop
                    elseif iStep == #M._race._steps then
                        color = M.COLORS.BLUE   -- finish
                    elseif wp.lap then
                        color = M.COLORS.GREEN  -- lap
                    end
                    M._modes[wp.name] = color
                end
            end
        end

        if #M._race._steps > 1 then
            -- following
            local color = M.COLORS.BLACK
            for _, target in ipairs(M._targets) do
                local wpPrevious = M._race._steps[target.step][target.wp]
                for iStep, step in ipairs(M._race._steps) do
                    for _, wp in ipairs(step) do
                        if table.includes(wp.parents, wpPrevious.name) and
                            (not wp.stand or iStep < #M._race._steps) then -- disable stand if last step
                            if M._modes[wp.name] == nil then
                                local normal
                                if not wp.stand then
                                    local angle = math.angleFromQuatRotation(wp.rot)
                                    normal = math.rotate2DVec(vec3(0, wp.radius, 0), angle - math.rad(1))
                                    normal = normal:normalized()
                                end

                                table.insert(M._markers, {
                                    name = wp.name,
                                    pos = wp.pos,
                                    normal = normal,
                                    radius = wp.radius,
                                    fadeNear = false,
                                    fadeFar = false,
                                })
                                M._modes[wp.name] = color
                            end
                        end
                    end
                end
            end
        end
    end

    M._raceMarker.setupMarkers(M._markers, M._markerType)
end

local function startRace()
    M._race._started = true
    updateRaceMarkers()
    if #M._race._steps > 0 and #M._targets == 0 then
        updateRaceMarkers()
    end
end

local function onRaceWaypointReached(waypoint)
    if M._race._onWaypoint then
        local ok, err = pcall(M._race._onWaypoint, waypoint, #M._race._steps)
        if not ok then
            LogError(string.var("Error while handling waypoint : {1}", { err }))
        end
    end
end

local function onRaceFinishReached()
    if M._race._onFinish then
        local ok, err = pcall(M._race._onFinish)
        if not ok then
            LogError(string.var("Error while handling finish : {1}", { err }))
        end
    end

    M.resetAll()
end

-- Retrieve vehicle corners positions
local function getVehCorners(ctxt)
    if not ctxt.veh then return end

    local origin = vec3(ctxt.vehPosRot.pos);
    local len = vec3(ctxt.veh:getInitialLength() / 2, 0, 0);
    local vdata = map.objects[ctxt.veh:getID()];
    local dir = vdata.dirVec;
    local angle = math.atan2(dir:dot(vec3(1, 0, 0)), dir:dot(vec3(0, -1, 0)));
    angle = math.scale(angle, -math.pi, math.pi, 0, math.pi * 2);
    angle = (angle + math.pi / 2) % (math.pi * 2);

    local w = vec3(0, ctxt.veh:getInitialWidth() / 2, 0);
    return {
        fl = origin + math.rotate2DVec(len, angle) + math.rotate2DVec(w, angle),
        fr = origin + math.rotate2DVec(len, angle) + math.rotate2DVec(w, angle + math.pi),
        bl = origin + math.rotate2DVec(len, angle + math.pi) + math.rotate2DVec(w, angle),
        br = origin + math.rotate2DVec(len, angle + math.pi) + math.rotate2DVec(w, angle + math.pi),
    }
end

local function checkMatchingHeight(ctxt, wp)
    if not ctxt.veh then return end

    local wpBottom = wp.pos.z - (wp.zOffset or 1) -- 1 meter under the waypoint by default
    local wpTop = wp.pos.z + (wp.radius * 2)      -- the diameter high over the waypoint
    local currentTop = ctxt.vehPosRot.pos.z + ctxt.veh:getInitialHeight()
    return currentTop >= wpBottom and ctxt.vehPosRot.pos.z <= wpTop
end

-- check collision for radius checkpoint
local function checkVehInRadius(ctxt, wp)
    local vehRadius = ctxt.veh:getInitialWidth() / 2
    return vec3(ctxt.vehPosRot.pos):distance(vec3(wp.pos)) <= (vehRadius + wp.radius)
end

local function ccw_intersect(a, b, c)
    return (c.y - a.y) * (b.x - a.x) > (b.y - a.y) * (c.x - a.x)
end

-- check collision for gate checkpoint
local function checkSegmentCrossed(ctxt, wp, vehCorners)
    if not ctxt.veh then return end

    local angle = math.angleFromQuatRotation(wp.rot)
    local len = math.rotate2DVec(vec3(0, wp.radius, 0), angle)
    local wpLeft = vec3(wp.pos) + math.rotate2DVec(len, math.pi / 2)
    local wpRight = vec3(wp.pos) + math.rotate2DVec(len, -math.pi / 2)

    for _, segment in ipairs({
        { vehCorners.fl, vehCorners.br },
        { vehCorners.fr, vehCorners.bl },
    }) do
        -- https://stackoverflow.com/questions/3838329/how-can-i-check-if-two-segments-intersect
        if ccw_intersect(wpLeft, segment[1], segment[2]) ~= ccw_intersect(wpRight, segment[1], segment[2]) and
            ccw_intersect(wpLeft, wpRight, segment[1]) ~= ccw_intersect(wpLeft, wpRight, segment[2]) then
            return true
        end
    end
    return false
end

local function checkRaceTargetReached(ctxt)
    if not M.isRacing() then
        return
    elseif #M._race._steps == 0 then
        M._race._started = false
        return
    elseif not ctxt.isOwner then
        return
    end

    local vehCorners = getVehCorners(ctxt) or {}
    if BJI.DEBUG then
        for _, segment in ipairs({
            { vehCorners.fl, vehCorners.br },
            { vehCorners.fr, vehCorners.bl },
        }) do
            BJI.Utils.ShapeDrawer.Cylinder(
                vec3(segment[1].x, segment[1].y, segment[1].z),
                vec3(segment[2].x, segment[2].y, segment[2].z),
                .1, BJI.Utils.ShapeDrawer.Color(1, 0, 0, .7))
        end
    end

    for _, target in ipairs(M._targets) do
        local wp = M._race._steps[target.step][target.wp]

        if BJI.DEBUG then
            local angle = math.angleFromQuatRotation(wp.rot)
            local len = math.rotate2DVec(vec3(0, wp.radius, 0), angle)
            local wpLeft = vec3(wp.pos) + math.rotate2DVec(len, math.pi / 2)
            local wpRight = vec3(wp.pos) + math.rotate2DVec(len, -math.pi / 2)

            local gateColor = BJI.Utils.ShapeDrawer.Color(1, 0, 1, .33)
            local a = vec3(wpLeft.x, wpLeft.y, wpLeft.z)
            local b = vec3(wpLeft.x, wpLeft.y, wpLeft.z + wp.radius * 2)
            local c = vec3(wpRight.x, wpRight.y, wpRight.z)
            BJI.Utils.ShapeDrawer.Triangle(a, b, c, gateColor)
            local d = vec3(wpRight.x, wpRight.y, wpRight.z)
            local e = vec3(wpRight.x, wpRight.y, wpRight.z + wp.radius * 2)
            local f = vec3(wpLeft.x, wpLeft.y, wpLeft.z + wp.radius * 2)
            BJI.Utils.ShapeDrawer.Triangle(d, e, f, gateColor)
        end

        if checkMatchingHeight(ctxt, wp) then
            if wp.stand and checkVehInRadius(ctxt, wp) or checkSegmentCrossed(ctxt, wp, vehCorners) then
                local i = target.step
                while i > 0 and #M._race._steps > 0 do
                    table.remove(M._race._steps, 1)
                    i = i - 1
                end
                M._race._countWp = M._race._countWp + 1
                onRaceWaypointReached(wp)
                if #M._race._steps == 0 then
                    onRaceFinishReached()
                else
                    updateRaceMarkers(wp)
                end
                break
            end
        end
    end
end

---@param wp {name: string, pos: vec3, rot?: quat, radius?: number, color?: string}
local function addWaypoint(wp)
    local _, err
    _, wp.pos, err = pcall(vec3, wp.pos)
    if err then
        LogError("invalid position", M._name)
        return
    end

    wp.name = wp.name or string.var("raceWaypoint{1}", { GetCurrentTimeMillis() })
    wp.radius = tonumber(wp.radius) or 1
    wp.color = wp.color or M.COLORS.RED

    local normal
    if wp.rot then
        local angle = math.angleFromQuatRotation(wp.rot)
        normal = math.rotate2DVec(vec3(0, wp.radius, 0), angle - math.rad(1))
        normal = normal:normalized()
    end

    table.insert(M._targets, {
        name = wp.name,
        pos = wp.pos,
        radius = wp.radius,
        color = wp.color,
    })
    table.insert(M._markers, {
        name = wp.name,
        pos = wp.pos,
        normal = normal,
        radius = wp.radius,
        fadeNear = false,
        fadeFar = false,
    })
    M._modes[wp.name] = wp.color

    M._raceMarker.setupMarkers(M._markers, M._markerType)
end

local function renderTick(ctxt)
    if M.isRacing() then
        if #M._race._steps == 0 then
            M._race._started = false
        elseif ctxt.isOwner then
            checkRaceTargetReached(ctxt)
        end
    end

    if #M._targets > 0 then
        M._raceMarker.setModes(M._modes)
    end
end

local function onUnload()
    M.resetAll()
end

---@param raceHash string
---@return MapRacePBWP[]|nil, integer?
local function getPB(raceHash)
    if type(raceHash) ~= "string" then
        LogError("getPB invalid raceHash")
        dump(raceHash)
        return
    end
    local pbs = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.VALUES.RACES_PB)
        [GetMapName() or BJI.Managers.Context.UI.mapName]
    if pbs then
        local pb = pbs[raceHash]
        if pb and table.maxn(pb) == 0 then
            -- pb is coming from cookies and has string indices
            local parsedPb = {}
            Table(pb):forEach(function(v, k) parsedPb[tonumber(k) or k] = v end)
            pb = parsedPb
        end
        local time
        if pb then
            time = pb[table.maxn(pb)].time
        end
        return pb, time
    end
end

---@param raceHash string
---@param newPb MapRacePBWP[]|nil
local function setPB(raceHash, newPb)
    if type(raceHash) ~= "string" then
        LogError("setPB invalid raceHash")
        dump(raceHash)
        return
    elseif not table.includes({ "table", "nil" }, type(newPb)) then
        LogError("setPB invalid newPb")
        dump(newPb)
        return
    end
    local pbs = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.VALUES.RACES_PB)
    local mapPbs = pbs[GetMapName() or BJI.Managers.Context.UI.mapName]
    if not mapPbs then
        mapPbs = {}
        pbs[GetMapName() or BJI.Managers.Context.UI.mapName] = mapPbs
    end
    mapPbs[raceHash] = newPb
    BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.VALUES.RACES_PB, pbs)
end

M.resetAll = resetAll

M.setRaceWaypointHandler = setRaceWaypointHandler
M.setRaceFinishHandler = setRaceFinishHandler
M.isRacing = isRacing
M.addRaceStep = addRaceStep
M.startRace = startRace

M.addWaypoint = addWaypoint

M.getPB = getPB
M.setPB = setPB

M.renderTick = renderTick

M.onUnload = onUnload

return M
