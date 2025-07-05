---@class BJIWindowMain : BJIWindow
local W = {
    name = "Main",
    getState = TrueFn,
    minSize = ImVec2(337, 420),
}

local menu = require("ge/extensions/BJI/ui/windows/Main/Menu")
local header = require("ge/extensions/BJI/ui/windows/Main/Header")
local body = require("ge/extensions/BJI/ui/windows/Main/Body")

local function onLoad()
    menu.onLoad()
    header.onLoad()
    body.onLoad()
end

local function onUnload()
    menu.onUnload()
    header.onUnload()
    body.onUnload()
end

W.onLoad = onLoad
W.onUnload = onUnload

W.menu = menu.draw

W.header = header.draw

W.body = body.draw

return W
