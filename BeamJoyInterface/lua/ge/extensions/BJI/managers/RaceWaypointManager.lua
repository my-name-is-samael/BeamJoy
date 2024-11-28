local tag = "BJIWaypoint"

local M = {
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

--[[
<ul>
    <li> waypoints = (array)</li>
    <ul>
        <li>name: string NULLABLE</li>
        <li>pos: vec3</li>
        <li>rot: vec3</li>
        <li>radius: float</li>
        <li>parents: array</li>
        <li>lap: boolean NULLABLE</li>
        <li>stand: boolean NULLABLE</li>
    </ul>
</ul>
]]
local function addRaceStep(step)
    if M._race._started then
        LogError("already started", tag)
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
                if tincludes(wp.parents, wpName, true) and           -- is child
                    not (wp.stand and iStep == #M._race._steps) then -- disable stand if last step
                    table.insert(M._targets, {
                        step = iStep,
                        wp = iWp,
                    })

                    table.insert(M._markers, {
                        name = wp.name,
                        pos = wp.pos,
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
                        if tincludes(wp.parents, wpPrevious.name) and
                            (not wp.stand or iStep < #M._race._steps) then -- disable stand if last step
                            if M._modes[wp.name] == nil then
                                table.insert(M._markers, {
                                    name = wp.name,
                                    pos = wp.pos,
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
        pcall(M._race._onWaypoint, waypoint, #M._race._steps)
    end
end

local function onRaceFinishReached()
    if M._race._onFinish then
        pcall(M._race._onFinish)
    end

    M.resetAll()
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

    local vehpos, vehRadius = vec3(ctxt.vehPosRot.pos), ctxt.veh:getInitialWidth() / 2
    vehpos.z = vehpos.z + (ctxt.veh:getInitialHeight() / 2)

    for _, target in ipairs(M._targets) do
        local wp = M._race._steps[target.step][target.wp]

        local distance = GetHorizontalDistance(vehpos, wp.pos)
        local hitboxBottom = wp.pos.z - (wp.zOffset or 1) -- 1 meter under the waypoint by default
        local hitboxTop = wp.pos.z + (wp.radius * 2)      -- the diameter high over the waypoint

        if distance <= wp.radius + vehRadius and
            vehpos.z >= hitboxBottom and
            vehpos.z <= hitboxTop then
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

local function addWaypoint(name, pos, radius, color)
    local _, err
    _, pos, err = pcall(vec3, pos)
    if err then
        LogError("invalid position", tag)
        return
    end

    name = name or svar("raceWaypoint{1}", { GetCurrentTimeMillis() })
    radius = tonumber(radius) or 1
    color = color or M.COLORS.RED

    table.insert(M._targets, {
        name = name,
        pos = pos,
        radius = radius,
        color = color,
    })
    table.insert(M._markers, {
        name = name,
        pos = pos,
        radius = radius,
        fadeNear = false,
        fadeFar = false,
    })
    M._modes[name] = color

    M._raceMarker.setupMarkers(M._markers, M._markerType)
end

local function renderTick(ctxt)
    if M.isRacing() then
        if #M._race._steps == 0 then
            M._race._started = false
        else
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

M.resetAll = resetAll

M.setRaceWaypointHandler = setRaceWaypointHandler
M.setRaceFinishHandler = setRaceFinishHandler
M.isRacing = isRacing
M.addRaceStep = addRaceStep
M.startRace = startRace

M.addWaypoint = addWaypoint

M.renderTick = renderTick

M.onUnload = onUnload

RegisterBJIManager(M)
return M
