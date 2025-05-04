local im = ui_imgui
local imUtils = require('ui/imguiUtils')

local M = {
    preview = nil, -- image path
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
    M.preview = nil
    M.cached = nil
end

local function open(imagePath)
    local img = imUtils.texObj(imagePath)
    if img.size.x > 0 and img.size.y > 0 then
        M.preview = imagePath
        M.cached = img
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
                file:write(jpgFile:read("*all"))
                jpgFile:close()
                file:close()
            end
            open(pngPath)
        else -- already a png, no solution :(
            LogDebug(string.var("Invalid vehicle image : \"{1}\"", { imagePath }))
            BJIToast.error("Invalid vehicle image")
            M.onClose()
        end
    end
end

local function drawBody(ctxt)
    -- forced window size
    local size = im.GetWindowSize()
    local scale = BJILocalStorage.get(BJILocalStorage.VALUES.UI_SCALE)
    if size.x ~= math.floor((M.imageSize.x + M.windowSizeOffset.x) * scale) or
        size.y ~= math.floor((M.imageSize.y + M.windowSizeOffset.y) * scale) then
        im.SetWindowSize2(BJILang.get("windows.BJIVehicleSelectorPreview"), im.ImVec2(
            math.floor((M.imageSize.x + M.windowSizeOffset.x) * scale),
            math.floor((M.imageSize.y + M.windowSizeOffset.y) * scale)
        ), im.Cond_Always)
    end

    if M.preview and M.cached then
        -- forced image size
        im.Image(
            M.cached.texId,
            im.ImVec2(
                math.floor(M.imageSize.x * scale),
                math.floor(M.imageSize.y * scale)
            ),
            im.ImVec2Zero,
            im.ImVec2One,
            im.ImColorByRGB(255, 255, 255, 255).Value,
            im.ImColorByRGB(255, 255, 255, 255).Value
        )
    end
end

M.open = open
M.body = drawBody
M.onClose = onClose
M.flags = {
    WINDOW_FLAGS.NO_RESIZE,
    WINDOW_FLAGS.NO_SCROLLBAR,
    WINDOW_FLAGS.NO_SCROLL_WITH_MOUSE
}

return M
