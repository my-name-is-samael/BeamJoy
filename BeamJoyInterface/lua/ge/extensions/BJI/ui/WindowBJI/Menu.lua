local menuMe = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuMe")
local menuVote = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuVote")
local menuScenario = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuScenario")
local menuEdit = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuEdit")
local menuConfig = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuConfig")
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

    menu:addEntry(BJILang.get("menu.about.title"), {
        {
            label = string.var("BeamJoy v{1}", { BJIVERSION }),
        },
        {
            label = BJILang.get("menu.about.createdBy"):var({ author = "TontonSamael" }),
        },
        {
            label = string.var("{1} : {2}", { BJILang.get("menu.about.computerTime"), math.floor(ctxt.now / 1000) })
        }
    })
        :build()
end

return {
    onLoad = onLoad,
    onUnload = onUnload,
    draw = draw,
}
