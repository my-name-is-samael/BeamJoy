local tabDraw = nil
local cacheData = {
    -- performance cache
    models = nil,
}

local function drawHeader(ctxt)
    local tabs = {}

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DATABASE_PLAYERS) then
        table.insert(tabs, {
            label = BJILang.get("database.players.title"),
            draw = require("ge/extensions/BJI/ui/WindowDatabase/Players"),
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DATABASE_VEHICLES) then
        table.insert(tabs, {
            label = BJILang.get("database.vehicles.title"),
            draw = require("ge/extensions/BJI/ui/WindowDatabase/Vehicles"),
        })
    end

    if #tabs == 0 then
        BJIContext.DatabaseEditorOpen = false
        cacheData = {}
    elseif #tabs == 1 then
        tabs[1].draw()
    else
        local tabBar = TabBarBuilder("BJIDatabaseTabs")
        for _, t in ipairs(tabs) do
            tabBar:addTab(t.label, function()
                tabDraw = t.draw
            end)
        end
        tabBar:build()
    end
end

local function drawBody(ctxt)
    if type(tabDraw) == "function" then
        tabDraw(cacheData)
    end
end

local function drawFooter(ctxt)
    LineBuilder()
        :btnIcon({
            id = "databaseEditorClose",
            icon = ICONS.exit_to_app,
            background = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.DatabaseEditorOpen = false
                cacheData = {}
            end
        })
        :build()
end

return {
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
    onClose = function()
        BJIContext.DatabaseEditorOpen = false
        cacheData = {}
    end,
}
