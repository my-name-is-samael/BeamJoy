local drawer = {}

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a }
end

local function ColorContrasted(r, g, b, a)
    local contrast = 0.2126 * r * r + 0.7152 * g * g + 0.0722 * b * b
    if contrast > .3 then
        return Color(0, 0, 0, a)
    else
        return Color(1, 1, 1, a)
    end
end

local function Sphere(pos, radius, shapeColor)
    local err, _
    _, pos, err = pcall(vec3, pos)
    if err or not tonumber(radius) then
        -- invalid position or radius
        return
    end
    shapeColor = shapeColor or Color(1, 1, 1, .5)

    debugDrawer:drawSphere(vec3(pos), radius, ColorF(shapeColor.r, shapeColor.g, shapeColor.b, shapeColor.a), true)
end

local function Text(text, pos, textColor, bgColor, shadow)
    local err, _
    _, pos, err = pcall(vec3, pos)
    if err then
        -- invalid position
        return
    end
    textColor = textColor or Color(1, 1, 1, 1)
    bgColor = bgColor or Color(0, 0, 0, 1)

    debugDrawer:drawTextAdvanced(pos, String(text),
        ColorF(textColor.r, textColor.g, textColor.b, textColor.a),
        true, false,
        ColorI(bgColor.r * 255, bgColor.g * 255, bgColor.b * 255, bgColor.a * 255),
        shadow, true)
end

local function SquarePrism(fromPos, fromWidth, toPos, toWidth, shapeColor)
    local err, _
    _, fromPos, err = pcall(vec3, fromPos)
    if err or not tonumber(fromWidth) then
        -- invalid from position or width
        return
    end
    _, toPos, err = pcall(vec3, toPos)
    if err or not tonumber(toWidth) then
        -- invalid to position or width
        return
    end
    shapeColor = shapeColor or Color(1, 1, 1, .5)

    debugDrawer:drawSquarePrism(fromPos, toPos,
        Point2F(fromWidth, fromWidth), Point2F(toWidth, toWidth),
        ColorF(shapeColor.r, shapeColor.g, shapeColor.b, shapeColor.a),
        true)
end

local function Cylinder(bottomPos, topPos, radius, shapeColor)
    local errBottom, errTop, _
    _, bottomPos, errBottom = pcall(vec3, bottomPos)
    _, topPos, errTop = pcall(vec3, topPos)
    if errBottom or errTop or
        not tonumber(radius) then
        -- invalid position or radius
        return
    end
    shapeColor = shapeColor or Color(1, 1, 1, .5)

    debugDrawer:drawCylinder(bottomPos, topPos, radius,
        ColorF(shapeColor.r, shapeColor.g, shapeColor.b, shapeColor.a))
end

local function Triangle(posA, posB, posC, shapeColor)
    local errA, errB, errC, _
    _, posA, errA = pcall(vec3, posA)
    _, posB, errB = pcall(vec3, posB)
    _, posC, errC = pcall(vec3, posC)
    if errA or errB or errC then
        -- invalid position
        return
    end
    shapeColor = shapeColor or Color(1, 1, 1, .5)

    local col = color(shapeColor.r * 255, shapeColor.g * 255, shapeColor.b * 255, shapeColor.a * 255)
    debugDrawer:drawTriSolid(posA, posB, posC, col)
    debugDrawer:drawTriSolid(posC, posB, posA, col)
end

local function Arrow(pos, rot, radius, shapeColor)
    local errPos, errRot, _
    _, pos, errPos = pcall(vec3, pos)
    _, rot, errRot = pcall(quat, rot)
    if errPos or errRot or not tonumber(radius) then
        -- invalid position or rotation or radius
        return
    end
    shapeColor = shapeColor or Color(1, 1, 1, .5)

    local angle = math.angleFromQuatRotation(rot)
    local len = math.rotate2DVec(vec3(0, radius, 0), angle)
    local tip = vec3(pos) + len
    local base = vec3(pos) + math.rotate2DVec(len, math.pi)
    debugDrawer:drawArrow(base, tip, ColorI(shapeColor.r * 255, shapeColor.g * 255, shapeColor.b * 255, shapeColor.a * 255), false)
end

drawer.Color = Color
drawer.ColorContrasted = ColorContrasted
drawer.Sphere = Sphere
drawer.Text = Text
drawer.SquarePrism = SquarePrism
drawer.Cylinder = Cylinder
drawer.Triangle = Triangle
drawer.Arrow = Arrow

return drawer
