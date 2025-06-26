---@class BJIManagerWaypointEdit : BJIManager
local M = {
    _name = "WaypointEdit",

    _startColor = BJI.Utils.ShapeDrawer.Color(1, 1, 0, .5),
    _wpColor = BJI.Utils.ShapeDrawer.Color(.66, .66, 1, .5),
    _segmentColor = BJI.Utils.ShapeDrawer.Color(1, 1, 1, .5),
    _textColor = BJI.Utils.ShapeDrawer.Color(1, 1, 1, .8),
    _textBgColor = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5),

    TYPES = {
        SPHERE = "start",
        CYLINDER = "cylinder",
        RACE_GATE = "race_gate",
        ARROW = "arrow",
    }
}

local function reset()
    M.spheres = {}
    M.cylinders = {}
    M.raceGates = {}
    M.arrows = {}
    M.segments = {}
end

local function _insertWaypoint(wp)
    if wp.type == M.TYPES.SPHERE then
        table.insert(M.spheres, {
            name = wp.name,
            pos = wp.pos,
            radius = wp.radius,
            color = wp.color or M._wpColor,
            textColor = wp.textColor,
            textBg = wp.textBg,
        })
    elseif wp.type == M.TYPES.CYLINDER then
        wp.bottom = wp.bottom or 0
        wp.top = wp.top or wp.radius*2
        table.insert(M.cylinders, {
            name = wp.name,
            pos = wp.pos,
            top = wp.top,
            bottom = wp.bottom,
            rot = wp.rot,
            radius = wp.radius,
            color = wp.color or M._wpColor,
            textColor = wp.textColor,
            textBg = wp.textBg,
        })
    elseif wp.type == M.TYPES.RACE_GATE then
        local zOffset = wp.zOffset or 1
        local angle = math.angleFromQuatRotation(wp.rot)
        local len = math.rotate2DVec(vec3(0, wp.radius, 0), angle)
        local left = vec3(wp.pos) + math.rotate2DVec(len, math.pi / 2)
        left = quat(left.x, left.y, left.z - zOffset, left.z + wp.radius * 2)
        local right = vec3(wp.pos) + math.rotate2DVec(len, -math.pi / 2)
        right = quat(right.x, right.y, right.z - zOffset, right.z + wp.radius * 2)
        local textPos = vec3(wp.pos)
        textPos.z = ((wp.pos.z - zOffset) + (wp.pos.z + wp.radius * 2)) / 2
        table.insert(M.raceGates, {
            name = wp.name,
            pos = wp.pos,
            rot = wp.rot,
            left = left,
            right = right,
            textPos = textPos,
            radius = wp.radius,
            color = wp.color or M._wpColor,
            textColor = wp.textColor,
            textBg = wp.textBg,
        })
    elseif wp.type == M.TYPES.ARROW then
        table.insert(M.arrows, {
            name = wp.name,
            pos = wp.pos,
            rot = wp.rot,
            radius = wp.radius,
            color = wp.color or M._wpColor,
            textColor = wp.textColor,
            textBg = wp.textBg,
        })
    end
end

local function setWaypoints(points)
    M.reset()

    for _, wp in ipairs(points) do
        _insertWaypoint(wp)
    end
end

local function setWaypointsWithSegments(waypoints, loopable)
    local flatWps = {}
    local wpIndices = {}

    M.reset()
    for _, wp in ipairs(waypoints) do
        table.insert(flatWps, {
            name = wp.name,
            pos = wp.pos,
            radius = wp.radius,
            parents = wp.parents,
            finish = wp.finish,
            type = wp.type,
        })
        wpIndices[wp.name] = #flatWps
        _insertWaypoint(wp)
    end

    if #waypoints > 1 then
        for _, wp in ipairs(flatWps) do
            if wp.parents then
                for _, parentName in ipairs(wp.parents) do
                    if parentName == "start" then
                        if loopable then
                            local finishIndices = {}
                            for i, s2 in ipairs(flatWps) do
                                if s2.finish then
                                    table.insert(finishIndices, i)
                                end
                            end
                            for _, iFin in ipairs(finishIndices) do
                                -- place segments on top of gate
                                local fromPos = vec3(flatWps[iFin].pos)
                                fromPos.z = fromPos.z + (flatWps[iFin].radius *
                                    (table.includes({ M.TYPES.CYLINDER, M.TYPES.RACE_GATE }, flatWps[iFin].type) and 2 or 1))
                                local toPos = vec3(wp.pos)
                                toPos.z = toPos.z + (wp.radius *
                                    (table.includes({ M.TYPES.CYLINDER, M.TYPES.RACE_GATE }, wp.type) and 2 or 1))
                                table.insert(M.segments, {
                                    from = fromPos,
                                    to = toPos,
                                    fromWidth = math.ceil(flatWps[iFin].radius / 2),
                                    toWidth = .5,
                                    color = M._segmentColor,
                                })
                            end
                        end
                    else
                        local parent = flatWps[wpIndices[parentName]]
                        if parent then
                            local fromPos = vec3(parent.pos)
                            fromPos.z = fromPos.z + (parent.radius *
                                (table.includes({ M.TYPES.CYLINDER, M.TYPES.RACE_GATE }, parent.type) and 2 or 1))
                            local toPos = vec3(wp.pos)
                            toPos.z = toPos.z + (wp.radius *
                                (table.includes({ M.TYPES.CYLINDER, M.TYPES.RACE_GATE }, wp.type) and 2 or 1))
                            table.insert(M.segments, {
                                from = fromPos,
                                to = toPos,
                                fromWidth = math.ceil(parent.radius / 2),
                                toWidth = .5,
                                color = M._segmentColor,
                            })
                        end
                    end
                end
            end
        end
    end
end

---@param ctxt TickContext
local function renderTick(ctxt)
    for _, segment in ipairs(M.segments) do
        BJI.Utils.ShapeDrawer.SquarePrism(
            segment.from, segment.fromWidth,
            segment.to, segment.toWidth,
            segment.color
        )
    end

    for _, wp in ipairs(M.spheres) do
        BJI.Utils.ShapeDrawer.Sphere(wp.pos, wp.radius, wp.color)
        if #wp.name:trim() > 0 then
            BJI.Utils.ShapeDrawer.Text(wp.name, wp.pos, wp.textColor or M._textColor,
                wp.textBg or M._textBgColor, true)
        end
    end

    for _, wp in ipairs(M.cylinders) do
        local bottomPos = vec3(wp.pos.x, wp.pos.y, wp.pos.z + wp.bottom)
        local topPos = vec3(wp.pos.x, wp.pos.y, wp.pos.z + wp.top)
        BJI.Utils.ShapeDrawer.Cylinder(bottomPos, topPos, wp.radius, wp.color)
        if #wp.name:trim() > 0 then
            BJI.Utils.ShapeDrawer.Text(wp.name, wp.pos, wp.textColor or M._textColor,
                wp.textBg or M._textBgColor, true)
        end
        if wp.rot then
            local radius = ctxt.veh and ctxt.veh.veh:getInitialLength() / 2 or wp.radius
            BJI.Utils.ShapeDrawer.Arrow(wp.pos, wp.rot, radius,
                BJI.Utils.ShapeDrawer.ColorContrasted(wp.color.r, wp.color.g, wp.color.b, 1))
        end
    end

    for _, wp in ipairs(M.raceGates) do
        local a = vec3(wp.left.x, wp.left.y, wp.left.z)
        local b = vec3(wp.left.x, wp.left.y, wp.left.w)
        local c = vec3(wp.right.x, wp.right.y, wp.right.z)
        BJI.Utils.ShapeDrawer.Triangle(a, b, c, wp.color)
        local d = vec3(wp.right.x, wp.right.y, wp.right.z)
        local e = vec3(wp.right.x, wp.right.y, wp.right.w)
        local f = vec3(wp.left.x, wp.left.y, wp.left.w)
        BJI.Utils.ShapeDrawer.Triangle(d, e, f, wp.color)
        if wp.name and #wp.name:trim() > 0 then
            BJI.Utils.ShapeDrawer.Text(wp.name, wp.textPos, wp.textColor or M._textColor,
                wp.textBg or M._textBgColor, true)
        end
        local arrowPos = wp.pos + vec3(0, 0, ctxt.veh and ctxt.veh.veh:getInitialHeight() or wp.radius / 2)
        local radius = ctxt.veh and ctxt.veh.veh:getInitialLength() / 2 or wp.radius
        BJI.Utils.ShapeDrawer.Arrow(arrowPos, wp.rot, radius,
            BJI.Utils.ShapeDrawer.Color(wp.color.r, wp.color.g, wp.color.b, 1))
    end

    for _, wp in ipairs(M.arrows) do
        local angle = math.angleFromQuatRotation(wp.rot)
        local len = math.rotate2DVec(vec3(0, ctxt.veh and ctxt.veh.veh:getInitialLength() / 2 or wp.radius, 0), angle)
        local tip = vec3(wp.pos) + len
        local base = vec3(wp.pos) + math.rotate2DVec(len, math.pi)
        BJI.Utils.ShapeDrawer.SquarePrism(
            base, ctxt.veh and ctxt.veh.veh:getInitialWidth() or wp.radius * 1.2,
            tip, 0,
            wp.color
        )
        if #wp.name:trim() > 0 then
            BJI.Utils.ShapeDrawer.Text(wp.name, wp.pos, wp.textColor or M._textColor,
                wp.textBg or M._textBgColor, true)
        end
    end
end

local function onUnload()
    M.reset()
end

M.reset = reset
M.setWaypoints = setWaypoints
M.setWaypointsWithSegments = setWaypointsWithSegments

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)
end
M.renderTick = renderTick

reset()
return M
