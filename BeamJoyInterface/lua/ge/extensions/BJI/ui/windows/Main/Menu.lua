local menuMe = require("ge/extensions/BJI/ui/windows/Main/Menu/Me")
local menuVote = require("ge/extensions/BJI/ui/windows/Main/Menu/Vote")
local menuScenario = require("ge/extensions/BJI/ui/windows/Main/Menu/Scenario")
local menuEdit = require("ge/extensions/BJI/ui/windows/Main/Menu/Edit")
local menuConfig = require("ge/extensions/BJI/ui/windows/Main/Menu/Config")
local allMenus = {
    menuMe,
    menuVote,
    menuScenario,
    menuEdit,
    menuConfig
}

local function onLoad()
    table.forEach(allMenus, function(menu) return menu.onLoad() end)
end
local function onUnload()
    table.forEach(allMenus, function(menu) return menu.onUnload() end)
end

---@param ctxt TickContext
local function draw(ctxt)
    menuMe.draw(ctxt)
    menuVote.draw(ctxt)
    menuScenario.draw(ctxt)
    menuEdit.draw(ctxt)
    menuConfig.draw(ctxt)

    RenderMenuDropdown(BJI_Lang.get("menu.about.title"), {
        { type = "item", label = string.var("BeamJoy v{1}", { BJI.VERSION }) },
        { type = "item", label = BJI_Lang.get("menu.about.createdBy"):var({ author = "TontonSamael" }) },
        { type = "item", label = string.var("{1} : {2}", { BJI_Lang.get("menu.about.computerTime"), math.floor(ctxt.now / 1000) }) },
    })
end

return {
    onLoad = onLoad,
    onUnload = onUnload,
    draw = draw,
}
