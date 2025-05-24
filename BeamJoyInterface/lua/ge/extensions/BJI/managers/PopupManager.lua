---@class BJIPopupButton
---@field label string
---@field onClick? fun()

---@class BJIManagerPopup : BJIManager
local M = {
    _name = "Popup",

    callbacks = {},
}

local function createCallback(fn)
    local callbackName = string.var("_{1}{2}{3}", {
        GetCurrentTimeMillis(),
        math.random(100),
        math.random(100),
    })
    M.callbacks[callbackName] = function()
        if type(fn) == "function" then
            pcall(fn)
        end
        M.closeModal()
        table.clear(M.callbacks)
    end
    return callbackName
end

---@param text string
---@param buttons BJIPopupButton[]
local function createModal(text, buttons)
    if type(text) ~= "string" or
        type(buttons) ~= "table" or
        #buttons == 0 then
        LogError("Invalid modal data")
        return
    end

    for i, btn in ipairs(buttons) do
        if type(btn.label) ~= "string" or
            #btn.label == 0 or
            (btn.onClick and type(btn.onClick) ~= "function") then
            LogError(string.var("Invalid modal button {1} data", { i }))
            return
        end
    end

    local btns = {}
    for i, btn in ipairs(buttons) do
        local callbackName = createCallback(btn.onClick)
        local cmd = string.var("BJI.Managers.Popup.callbacks.{1}()", { callbackName })
        table.insert(btns, {
            action = tostring(i), -- mandatory
            text = btn.label,
            cmd = cmd,
        })
    end

    ui_missionInfo.openDialogue({
        type = "",     -- optional
        typeName = "", -- optional
        title = text,
        buttons = btns,
    })
end

---@param label string
---@param callback? fun()
---@return BJIPopupButton
local function createButton(label, callback)
    return {
        label = label,
        onClick = callback,
    }
end

local function closeModal()
    ui_missionInfo.closeDialogue()
end

M.createModal = createModal
M.createButton = createButton
M.closeModal = closeModal

return M
