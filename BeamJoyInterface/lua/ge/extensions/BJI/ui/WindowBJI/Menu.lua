local function drawMenu(ctxt)
    local menu = MenuBarBuilder()

    -- ME
    local meEntry = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuMe")(ctxt)
    if meEntry then
        menu:addEntry(meEntry.label, meEntry.elems)
    end

    -- VOTES
    local voteEntry = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuVote")(ctxt)
    if voteEntry then
        menu:addEntry(voteEntry.label, voteEntry.elems)
    end

    -- SCENARIO
    local scenarioEntry = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuScenario")(ctxt)
    if scenarioEntry then
        menu:addEntry(scenarioEntry.label, scenarioEntry.elems)
    end

    -- EDIT
    local editEntry = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuEdit")(ctxt)
    if editEntry then
        menu:addEntry(editEntry.label, editEntry.elems)
    end

    -- CONFIG
    local configEntry = require("ge/extensions/BJI/ui/WindowBJI/Menu/MenuConfig")(ctxt)
    if configEntry then
        menu:addEntry(configEntry.label, configEntry.elems)
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
return drawMenu
