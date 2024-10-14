debugDrawer = debugDrawer or {
    drawSphere = function(self, pos, r, shapeColF, useZ) end,
    drawSquarePrism = function(self, base, tip, baseSize, tipSize, shpaeColF, useZ) end,
    drawTextAdvanced = function(self, pos, text, textColF, useAdvancedText, twod, bgColI, shadow, useZ) end,
}

local drawer = {}

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a }
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

drawer.Color = Color
drawer.Sphere = Sphere
drawer.Text = Text
drawer.SquarePrism = SquarePrism

return drawer
