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

local function draw(ctxt)
    local menu = MenuBarBuilder()

    -- ME
    if #menuMe.cache.elems > 0 then
        menu:addEntry(menuMe.cache.label, menuMe.cache.elems)
    end

    -- VOTES
    if #menuVote.cache.elems > 0 then
        menu:addEntry(menuVote.cache.label, menuVote.cache.elems)
    end

    -- SCENARIO
    if #menuScenario.cache.elems > 0 then
        menu:addEntry(menuScenario.cache.label, menuScenario.cache.elems)
    end

    -- EDIT
    if #menuEdit.cache.elems > 0 then
        menu:addEntry(menuEdit.cache.label, menuEdit.cache.elems)
    end

    -- CONFIG
    if #menuConfig.cache.elems > 0 then
        menu:addEntry(menuConfig.cache.label, menuConfig.cache.elems)
    end

    menu:addEntry(BJI.Managers.Lang.get("menu.about.title"), {
        {
            label = string.var("BeamJoy v{1}", { BJI.VERSION }),
        },
        {
            label = BJI.Managers.Lang.get("menu.about.createdBy"):var({ author = "TontonSamael" }),
        },
        {
            label = string.var("{1} : {2}", { BJI.Managers.Lang.get("menu.about.computerTime"), math.floor(ctxt.now / 1000) })
        }
    })
        :build()
end

return {
    onLoad = onLoad,
    onUnload = onUnload,
    draw = draw,
}
