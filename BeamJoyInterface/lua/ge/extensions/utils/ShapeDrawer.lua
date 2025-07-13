local drawer = {}
--- gc prevention
local col, meta, contrast, err, _, errBottom, errTop, errA, errB, errC, errPos, errRot,
forward, base, tip

---@class BJIColor
---@field r number 0-1
---@field g number 0-1
---@field b number 0-1
---@field a number 0-1
---@field fromRaw fun(self: BJIColor, rawColor: {r: number?, g: number?, b: number?, a: number?}): BJIColor -- self mutable
---@field fromVec4 fun(self: BJIColor, vec4, vec4): BJIColor -- self mutable
---@field vec4 fun(self: BJIColor): vec4
---@field colorI ColorI
---@field colorF ColorF
---@field compare fun(self: BJIColor, color2: BJIColor): boolean

---@param r number? 0-1
---@param g number? 0-1
---@param b number? 0-1
---@param a number? 0-1
---@return BJIColor
local function Color(r, g, b, a)
    col = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }
    meta = {
        fromRaw = function(self, rawColor)
            if not rawColor or not rawColor.r then return end
            self.r, self.g, self.b, self.a = rawColor.r or 0, rawColor.g or 0, rawColor.b or 0, rawColor.a or 1
            return self
        end,
        fromVec4 = function(self, vec4)
            if not vec4 or not vec4.x then return end
            self.r, self.g, self.b, self.a = vec4.x, vec4.y, vec4.z, vec4.w
            return self
        end,
        vec4 = function(self)
            return ImVec4(self.r, self.g, self.b, self.a)
        end,
        colorI = function(self)
            return ColorI(self.r * 255, self.g * 255, self.b * 255, self.a * 255)
        end,
        colorF = function(self)
            return ColorF(self.r, self.g, self.b, self.a)
        end,
        compare = function(self, color2)
            if not color2 then return false end
            return self.r == color2.r and self.g == color2.g and self.b == color2.b and self.a == color2.a
        end
    }

    return setmetatable(col, { __index = meta })
end

---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a? number 0-1
---@return BJIColor
local function ColorContrasted(r, g, b, a)
    contrast = 0.2126 * r * r + 0.7152 * g * g + 0.0722 * b * b
    if contrast > .3 then
        return Color(0, 0, 0, a)
    else
        return Color(1, 1, 1, a)
    end
end

---@param pos vec3
---@param radius number
---@param shapeColor BJIColor?
local function Sphere(pos, radius, shapeColor)
    _, pos, err = pcall(vec3, pos)
    if err or not tonumber(radius) then
        -- invalid position or radius
        return
    end
    shapeColor = shapeColor or Color(1, 1, 1, .5)

    debugDrawer:drawSphere(vec3(pos), radius, ColorF(shapeColor.r, shapeColor.g, shapeColor.b, shapeColor.a), true)
end

---@param text string
---@param pos vec3
---@param textColor BJIColor?
---@param bgColor BJIColor?
---@param shadow? boolean
local function Text(text, pos, textColor, bgColor, shadow)
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
        shadow == true, true)
end

---@param fromPos vec3
---@param fromWidth number
---@param toPos vec3
---@param toWidth number
---@param shapeColor BJIColor?
local function SquarePrism(fromPos, fromWidth, toPos, toWidth, shapeColor)
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

---@param bottomPos vec3
---@param topPos vec3
---@param radius number
---@param shapeColor BJIColor?
local function Cylinder(bottomPos, topPos, radius, shapeColor)
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

---@param posA vec3
---@param posB vec3
---@param posC vec3
---@param shapeColor BJIColor?
local function Triangle(posA, posB, posC, shapeColor)
    _, posA, errA = pcall(vec3, posA)
    _, posB, errB = pcall(vec3, posB)
    _, posC, errC = pcall(vec3, posC)
    if errA or errB or errC then
        -- invalid position
        return
    end
    shapeColor = shapeColor or Color(1, 1, 1, .5)

    col = color(shapeColor.r * 255, shapeColor.g * 255, shapeColor.b * 255, shapeColor.a * 255)
    debugDrawer:drawTriSolid(posA, posB, posC, col)
    debugDrawer:drawTriSolid(posC, posB, posA, col)
end

---@param pos vec3
---@param rot quat
---@param radius number
---@param shapeColor BJIColor?
local function Arrow(pos, rot, radius, shapeColor)
    _, pos, errPos = pcall(vec3, pos)
    _, rot, errRot = pcall(quat, rot)
    if errPos or errRot or not tonumber(radius) then
        -- invalid position or rotation or radius
        return
    end
    shapeColor = shapeColor or Color(1, 1, 1, .5)

    forward = math.quatToForwardVector(rot) * radius
    tip = vec3(pos) + forward
    base = vec3(pos) - forward
    debugDrawer:drawArrow(base, tip,
        ColorI(shapeColor.r * 255, shapeColor.g * 255, shapeColor.b * 255, shapeColor.a * 255), false)
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
