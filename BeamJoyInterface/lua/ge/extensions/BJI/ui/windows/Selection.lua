---@class BJIWindowSelection : BJIWindow
local W = {
    name = "Selection",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    w = 350,
    h = 125,

    LIMIT_ELEMS_THRESHOLD = 15,

    labels = {
        title = "",
        valid = "",
        cancel = "",
    },
    show = false,
    title = "",
    elems = Table(),
    ---@type {label: string, value: any}
    selected = nil,
    ---@type fun(line: LineBuilder, value: any, onClose: fun())?
    footerRender = function(line) end,
    ---@type fun(value: any)?
    callback = function(value) end,
}

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get(W.title, W.title)
    W.labels.cancel = BJI.Managers.Lang.get("common.buttons.cancel")
    W.labels.valid = BJI.Managers.Lang.get("common.buttons.confirm")
end

local listeners = Table()
local function onClose()
    W.show = false
    listeners:forEach(BJI.Managers.Events.removeListener)
    W.title = ""
    W.elems = Table()
    W.selected = nil
    W.valid = ""
    W.callback = function(value) end
    W.validIcon = nil
    W.labels = {}
end

---@param titleKey string
---@param elems {label: string, value: any}[]
---@param footerRender? fun(line: LineBuilder, value: any, onClose: fun())
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
    W.selected = W.elems[1]
    W.callback = callback
    W.footerRender = footerRender
    W.show = true

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SCENARIO_CHANGED, onClose))

    permissions = Table(permissions)
    if #permissions > 0 then
        listeners:insert(BJI.Managers.Events.addListener(
            BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
            function()
                if permissions:any(function(p) return not BJI.Managers.Perm.hasPermission(p) end) then
                    onClose()
                end
            end))
    end
end

local function header()
    LineLabel(W.labels.title, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
end

local function body()
    LineBuilder():inputCombo({
        id = "selectionList",
        items = W.elems,
        value = W.selected,
        getLabelFn = function(item)
            return item.label
        end,
        ---@param item {label: string, value: any}
        onChange = function(item)
            W.selected = item
        end
    }):build()
end

local function footer()
    local line = LineBuilder():btnIcon({
        id = "selectionCancel",
        icon = ICONS.exit_to_app,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = W.labels.cancel,
        onClick = onClose,
    })
    if W.show then -- on close click error handling
        if W.footerRender then
            W.footerRender(line, W.selected.value, onClose)
        elseif W.callback then
            line:btnIcon({
                id = "selectionConfirm",
                icon = ICONS.check,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                tooltip = W.labels.valid,
                onClick = function()
                    W.callback(W.selected.value)
                    onClose()
                end,
            })
        end
    end
    line:build()
end

W.header = header
W.body = body
W.footer = footer
W.getState = function() return W.show end
W.onClose = onClose
W.open = open

return W
