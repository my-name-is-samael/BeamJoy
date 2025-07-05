---@class BJIWindowSelection : BJIWindow
local W = {
    name = "Selection",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    size = ImVec2(350, 125),

    LIMIT_ELEMS_THRESHOLD = 20,

    labels = {
        title = "",
        valid = "",
        cancel = "",
    },
    show = false,
    title = "",
    elems = Table(),
    ---@type any?
    selected = nil,
    ---@type fun(value: any, onClose: fun())?
    footerRender = function(line) end,
    ---@type fun(value: any)?
    callback = function(value) end,
}
--- gc prevention
local nextValue

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get(W.title, W.title)
    W.labels.cancel = BJI.Managers.Lang.get("common.buttons.cancel")
    W.labels.valid = BJI.Managers.Lang.get("common.buttons.confirm")
end

local listeners = Table()
local function onClose()
    W.show = false
    listeners:forEach(BJI.Managers.Events.removeListener)
    listeners:clear()
    W.title = ""
    W.elems = Table()
    W.selected = nil
    W.valid = ""
    W.callback = nil
    W.validIcon = nil
    W.labels = {}
end

---@param titleKey string
---@param elems ComboOption[]
---@param footerRender? fun(value: any, onClose: fun())
---@param callback? fun(value: any)
---@param permissions? string[]
local function open(titleKey, elems, footerRender, callback, permissions)
    onClose() -- cleanup listeners and values
    if type(elems) ~= "table" or #elems == 0 then
        LogError("Selection opened with invalid or empty values")
        return
    elseif not callback and not footerRender then
        LogError("Selection opened without callback or footerRender")
        return
    end

    W.title = titleKey
    W.elems = Table(elems)
    W.selected = W.elems[1] and W.elems[1].value or nil
    W.callback = callback
    W.footerRender = footerRender
    W.show = true

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SCENARIO_CHANGED, onClose, W.name))

    permissions = Table(permissions)
    if #permissions > 0 then
        listeners:insert(BJI.Managers.Events.addListener(
            BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
            function()
                if permissions:any(function(p) return not BJI.Managers.Perm.hasPermission(p) end) then
                    onClose()
                end
            end, W.name))
    end
end

local function header()
    Text(W.labels.title, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
end

local function body()
    nextValue = Combo("selectionList", W.selected, W.elems)
    if nextValue then W.selected = nextValue end
end

local function footer()
    if IconButton("selectionCancel", BJI.Utils.Icon.ICONS.exit_to_app, { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.cancel)
    if W.show then -- on close click error handling
        if W.footerRender then
            W.footerRender(W.selected, onClose)
        elseif W.callback then
            SameLine()
            if IconButton("selectionConfirm", BJI.Utils.Icon.ICONS.check, { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                W.callback(W.selected)
                onClose()
            end
            TooltipText(W.labels.valid)
        end
    end
end

W.header = header
W.body = body
W.footer = footer
W.getState = function() return W.show end
W.onClose = onClose
W.open = open

return W
