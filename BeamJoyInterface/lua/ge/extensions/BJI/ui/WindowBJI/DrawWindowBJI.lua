local menu = require("ge/extensions/BJI/ui/WindowBJI/Menu")
local header = require("ge/extensions/BJI/ui/WindowBJI/Header")
local body = require("ge/extensions/BJI/ui/WindowBJI/Body/DrawBody")

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

return {
    onLoad = onLoad,
    onUnload = onUnload,
    menu = menu.draw,
    header = header.draw,
    body =  body.draw,
}
