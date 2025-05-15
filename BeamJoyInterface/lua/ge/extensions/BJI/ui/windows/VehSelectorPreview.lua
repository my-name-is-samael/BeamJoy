local im = ui_imgui
local imUtils = require('ui/imguiUtils')

---@class BJIWindowVehSelectorPreview : BJIWindow
local W = {
    name = "VehSelectorPreview",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_RESIZE,
        BJI.Utils.Style.WINDOW_FLAGS.NO_SCROLLBAR,
        BJI.Utils.Style.WINDOW_FLAGS.NO_SCROLL_WITH_MOUSE
    },

    preview = nil, -- image path
    ---@type {texId: any}?
    cached = nil,  -- cached image texture
    imageSize = {
        x = 356,
        y = 200,
    },
    windowSizeOffset = {
        x = 24,
        y = 48,
    }
}

local function onClose()
    W.preview = nil
    W.cached = nil
end

---@param imagePath string
local function open(imagePath)
    local img = imUtils.texObj(imagePath)
    if img.size.x > 0 and img.size.y > 0 then
        W.preview = imagePath
        W.cached = img
    else -- invalid image
        -- test if its a png file with a jpg extension
        -- https://github.com/my-name-is-samael/BeamJoy/issues/18#issuecomment-2508961479
        if imagePath:find(".jpg$") then
            local pngPath = imagePath:gsub(".jpg$", ".png")
            local file = io.open(pngPath, "r")
            if file then
                file:close()
            else
                local jpgFile = io.open(imagePath, "r")
                file = io.open(pngPath, "w")
                if jpgFile and file then
                    file:write(jpgFile:read("*all"))
                    jpgFile:close()
                    file:close()
                end
            end
            open(pngPath)
        else -- already a png, no solution :(
            LogDebug(string.var("Invalid vehicle image : \"{1}\"", { imagePath }))
            BJI.Managers.Toast.error("Invalid vehicle image")
            W.onClose()
        end
    end
end

---@param ctxt TickContext
local function drawBody(ctxt)
    -- forced window size
    local size = im.GetWindowSize()
    local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
    if size.x ~= math.floor((W.imageSize.x + W.windowSizeOffset.x) * scale) or
        size.y ~= math.floor((W.imageSize.y + W.windowSizeOffset.y) * scale) then
        im.SetWindowSize2(BJI.Managers.Lang.get("windows." .. W.name), im.ImVec2(
            math.floor((W.imageSize.x + W.windowSizeOffset.x) * scale),
            math.floor((W.imageSize.y + W.windowSizeOffset.y) * scale)
        ), im.Cond_Always)
    end

    if W.preview and W.cached then
        -- forced image size
        im.Image(
            W.cached.texId,
            im.ImVec2(
                math.floor(W.imageSize.x * scale),
                math.floor(W.imageSize.y * scale)
            ),
            im.ImVec2Zero,
            im.ImVec2One,
            im.ImColorByRGB(255, 255, 255, 255).Value,
            im.ImColorByRGB(255, 255, 255, 255).Value
        )
    end
end

W.open = open
W.body = drawBody
W.onClose = onClose
W.w = W.imageSize.x + W.windowSizeOffset.x
W.h = W.imageSize.y + W.windowSizeOffset.y
W.getState = function() return W.preview end

return W
