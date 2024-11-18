local M = {
    _startColor = ShapeDrawer.Color(1, 1, 0, .5),
    _wpColor = ShapeDrawer.Color(.66, .66, 1, .5),
    _segmentColor = ShapeDrawer.Color(1, 1, 1, .5),
    _textColor = ShapeDrawer.Color(1, 1, 1, .8),
    _textBgColor = ShapeDrawer.Color(0, 0, 0, .5),

    TYPES = {
        SPHERE = "start",
        CYLINDER = "wp",
    }
}

local function reset()
    M.spheres = {}
    M.cylinders = {}
    M.segments = {}
end

local function setWaypoints(points)
    M.reset()

    for _, wp in ipairs(points) do
        if wp.type == M.TYPES.CYLINDER then
            table.insert(M.cylinders, {
                name = wp.name,
                pos = wp.pos,
                radius = wp.radius,
                color = wp.color or M._wpColor,
            })
        else
            -- SPHERE
            table.insert(M.spheres, {
                name = wp.name,
                pos = wp.pos,
                radius = wp.radius,
                color = wp.color or M._wpColor,
            })
        end
    end
end

local function setWaypointsWithSegments(waypoints, loopable)
    M.reset()

    local flatWps = {}
    local wpIndices = {}
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
        if wp.type == M.TYPES.CYLINDER then
            table.insert(M.cylinders, {
                name = wp.name,
                pos = wp.pos,
                zMinOffset = wp.zMinOffset or 0,
                radius = wp.radius,
                color = wp.color or M._wpColor
            })
        else
            -- SPHERE
            table.insert(M.spheres, {
                name = wp.name,
                pos = wp.pos,
                radius = wp.radius,
                color = wp.color or M._wpColor,
            })
        end
    end

    if #waypoints > 1 then
        for _, wp in ipairs(flatWps) do
            if wp.parents then
                for _, parentName in ipairs(wp.parents) do
                    if parentName == "start" then
                        if loopable then
                            local finIndices = {}
                            for i, s2 in ipairs(flatWps) do
                                if s2.finish then
                                    table.insert(finIndices, i)
                                end
                            end
                            for _, iFin in ipairs(finIndices) do
                                -- place segments on top of cylinder or sphere
                                local fromPos = vec3(flatWps[iFin].pos)
                                fromPos.z = fromPos.z + (flatWps[iFin].radius *
                                    (flatWps[iFin].type == M.TYPES.CYLINDER and 2 or 1))
                                local toPos = vec3(wp.pos)
                                toPos.z = toPos.z + (wp.radius *
                                    (wp.type == M.TYPES.CYLINDER and 2 or 1))
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
                                (parent.type == M.TYPES.CYLINDER and 2 or 1))
                            local toPos = vec3(wp.pos)
                            toPos.z = toPos.z + (wp.radius *
                                (wp.type == M.TYPES.CYLINDER and 2 or 1))
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

local function renderTick(ctxt)
    for _, segment in ipairs(M.segments) do
        ShapeDrawer.SquarePrism(
            segment.from, segment.fromWidth,
            segment.to, segment.toWidth,
            segment.color
        )
    end

    for _, start in ipairs(M.spheres) do
        ShapeDrawer.Sphere(start.pos, start.radius, start.color)
        ShapeDrawer.Text(start.name, start.pos, M._textColor, M._textBgColor, true)
    end

    for _, wp in ipairs(M.cylinders) do
        local bottomPos = vec3(wp.pos.x, wp.pos.y, wp.pos.z - wp.zMinOffset)
        local topPos = vec3(wp.pos.x, wp.pos.y, wp.pos.z + (wp.radius * 2))
        ShapeDrawer.Cylinder(bottomPos, topPos, wp.radius, wp.color)
        ShapeDrawer.Text(wp.name, wp.pos, M._textColor, M._textBgColor, true)
    end
end

local function onUnload()
    M.reset()
end

M.reset = reset
M.setWaypoints = setWaypoints
M.setWaypointsWithSegments = setWaypointsWithSegments

M.renderTick = renderTick

M.onUnload = onUnload

reset()
RegisterBJIManager(M)
return M
