local M = {
    _wpColor = ShapeDrawer.Color(.66, .66, 1, .5),
    _segmentColor = ShapeDrawer.Color(1, 1, 1, .5),
    _textColor = ShapeDrawer.Color(1, 1, 1, 1),
    _textBgColor = ShapeDrawer.Color(0, 0, 0, .5),
}

local function reset()
    M.waypoints = {}
    M.segments = {}
end

local function setWaypoints(waypoints)
    M.reset()

    for _, wp in ipairs(waypoints) do
        table.insert(M.waypoints, {
            name = wp.name,
            pos = wp.pos,
            radius = wp.radius,
            color = wp.color or M._wpColor,
        })
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
        })
        wpIndices[wp.name] = #flatWps

        table.insert(M.waypoints, {
            name = wp.name,
            pos = wp.pos,
            radius = wp.radius,
            color = wp.color or M._wpColor
        })
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
                                local fromPos = vec3(flatWps[iFin].pos)
                                fromPos.z = fromPos.z + flatWps[iFin].radius
                                local toPos = vec3(wp.pos)
                                toPos.z = toPos.z + wp.radius
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
                            fromPos.z = fromPos.z + parent.radius
                            local toPos = vec3(wp.pos)
                            toPos.z = toPos.z + wp.radius
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

    for _, wp in ipairs(M.waypoints) do
        ShapeDrawer.Sphere(
            wp.pos, wp.radius,
            wp.color
        )
        ShapeDrawer.Text(wp.name, wp.pos, M._textColor, M._textBgColor, true)
    end
end

M.reset = reset
M.setWaypoints = setWaypoints
M.setWaypointsWithSegments = setWaypointsWithSegments

M.renderTick = renderTick

reset()
RegisterBJIManager(M)
return M
