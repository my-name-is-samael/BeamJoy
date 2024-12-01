local M = {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    onClose = function()
        BJIContext.ServerEditorOpen = false
    end,
}

local tabs = {}
local currentTab
local function updateTabs()
    tabs = {}

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CONFIG) then
        table.insert(tabs, {
            labelKey = "serverConfig.bjc.title",
            draw = require("ge/extensions/BJI/ui/WindowServer/BJC"),
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_REPUTATION) then
        table.insert(tabs, {
            labelKey = "serverConfig.reputation.title",
            draw = require("ge/extensions/BJI/ui/WindowServer/Reputation"),
        })
    end


    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_PERMISSIONS) then
        table.insert(tabs, {
            labelKey = "serverConfig.permissions.title",
            draw = require("ge/extensions/BJI/ui/WindowServer/Permissions"),
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_MAPS) then
        table.insert(tabs, {
            labelKey = "serverConfig.maps.title",
            draw = require("ge/extensions/BJI/ui/WindowServer/Maps"),
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CEN) then
        table.insert(tabs, {
            labelKey = "serverConfig.core.title",
            draw = require("ge/extensions/BJI/ui/WindowServer/CoreCEN"),
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) and
        BJIContext.Core.Debug then
        table.insert(tabs, {
            labelKey = "serverConfig.icons.title",
            draw = require("ge/extensions/BJI/ui/WindowServer/Icons"),
        })
    end

    -- current tab fallback safe
    if not currentTab then
        currentTab = tabs[1].labelKey
    else
        local found = false
        for _, t in ipairs(tabs) do
            if t.labelKey == currentTab then
                found = true
                break
            end
        end
        if not found then
            currentTab = tabs[1].labelKey
        end
    end
end

local function drawHeader(ctxt)
    if not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CONFIG) and
        not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) and
        not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CEN) and
        not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_MAPS) and
        not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_PERMISSIONS) then
        M.onClose()
        return
    end
    updateTabs()

    if #tabs == 0 then
        currentTab = nil
    elseif #tabs == 1 then
        currentTab = tabs[1].labelKey
        LineBuilder()
            :text(BJILang.get(currentTab))
            :build()
    else
        local bar = TabBarBuilder("BJIServerTabs")
        for _, tab in ipairs(tabs) do
            bar:addTab(BJILang.get(tab.labelKey), function()
                currentTab = tab.labelKey
            end)
        end
        bar:build()
    end
end

local function drawBody(ctxt)
    local tab
    for _, t in ipairs(tabs) do
        if t.labelKey == currentTab then
            tab = t
            break
        end
    end

    if tab then
        tab.draw(ctxt)
    end
end

local function drawFooter(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeServer",
            icon = ICONS.exit_to_app,
            background = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.ServerEditorOpen = false
            end
        })
        :build()
end

M.header = drawHeader
M.body = drawBody
M.footer = drawFooter

return M
