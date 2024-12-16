local tabs = {
    {
        labelKey = "environment.sun",
        draw = require("ge/extensions/BJI/ui/WindowEnvironment/Sun"),
    },
    {
        labelKey = "environment.weather",
        draw = require("ge/extensions/BJI/ui/WindowEnvironment/Weather"),
    },
    {
        labelKey = "environment.gravity",
        draw = require("ge/extensions/BJI/ui/WindowEnvironment/Gravity"),
    },
    {
        labelKey = "environment.temperature",
        draw = require("ge/extensions/BJI/ui/WindowEnvironment/Temperature"),
    },
    {
        labelKey = "environment.speed",
        draw = require("ge/extensions/BJI/ui/WindowEnvironment/Speed"),
    }
}
local currentTab = 1

local function drawHeader(ctxt)
    local t = TabBarBuilder("BJIEnvironmentTabs")
    for i, tab in pairs(tabs) do
        t:addTab(BJILang.get(tab.labelKey), function()
            currentTab = i
        end)
    end
    t:build()
end

local function drawBody(ctxt)
    local tab = tabs[currentTab]
    if tab then
        tab.draw()
    end
end

local function drawFooter(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeEnvironment",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.EnvironmentEditorOpen = false
            end
        })
        :build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
    onClose = function()
        BJIContext.EnvironmentEditorOpen = false
    end,
}
