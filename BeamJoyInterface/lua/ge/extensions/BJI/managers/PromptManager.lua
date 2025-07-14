---@class BJIManagerPrompt: BJIManager
local M = {
    _name = "Prompt",

    ICONS = require("ge/extensions/utils/IconsPrompt"),

    data = {},
    active = false,
    process = false,

    clickDelay = 10,
    processDelayOffset = 100,
}
M.quickIcons = {
    -- common

    previous = M.ICONS.undo,
    settings = M.ICONS.adjust,
    cancel = M.ICONS.abandon,

    -- race icons

    lap = M.ICONS.replay,
    allResets = M.ICONS.car,
    lastCheckpoint = M.ICONS.carsWrench,
    lastStand = M.ICONS.carDealer,
    forbidden = M.ICONS.circleSlashed,
    all_models = M.ICONS.cars,
    model = M.ICONS.car,
    config = M.ICONS.carStarred,
    collisions = M.ICONS.carOffroadSide,
    no_collisions = M.ICONS.carOffroadOutlineSide,

    -- bus icons

    busline = M.ICONS.routeComplex,
    bus = M.ICONS.bus,

    -- derby

    derby_lives = "carNumber{amount}",

    -- common scenarios end

    vote = M.ICONS.peopleOutline,
    start = M.ICONS.gamepad,
}

---@param newState boolean
local function changeState(newState)
    if not M.active and newState then
        BJI_Async.removeTask("BJIPromptProcessOff")
        M.active = true
        M.process = true
    elseif M.active and not newState then
        M.active = false
        BJI_Async.delayTask(function()
            M.process = false
        end, M.processDelayOffset, "BJIPromptProcessOff")
    end
end

local function reset()
    M.data = {
        title = "",
        buttons = {},
    }
end

local function onCancel()
    M.data.cancelButton.onClick()
    changeState(false)
    reset()
end

---@param iBtn integer
local function onButtonPressed(iBtn)
    if M.data.buttons[iBtn] then
        M.data.buttons[iBtn].onClick()
    end
    changeState(false)
    reset()
end

local function getUIData()
    return M.data
end

---@class PromptButton
---@field label string
---@field onClick fun(ctxt: TickContext)
---@field disabled boolean?
---@field icon string?
---@field needConfirm boolean?

---@param title string
---@param buttons PromptButton[]
---@param cancelButtonLabel string?
---@param cancelCallback fun(ctxt: TickContext)?
local function show(title, buttons, cancelButtonLabel, cancelCallback)
    if M.active then return LogError("Prompt is already active") end
    reset()
    M.data.title = title
    if cancelButtonLabel then
        M.data.cancelButton = {
            label = cancelButtonLabel,
            onClick = cancelCallback and
                function() BJI_Async.delayTask(cancelCallback, M.clickDelay) end or
                TrueFn,
        }
    end
    for i, btn in ipairs(buttons) do
        M.data.buttons[i] = {
            label = btn.label,
            onClick = function() BJI_Async.delayTask(btn.onClick, M.clickDelay) end,
            enabled = not btn.disabled,
            icon = btn.icon or "",
            confirmationText = btn.needConfirm and "1" or nil
        }
    end
    guihooks.trigger("OpenRecoveryPrompt")
    changeState(true)
end

---@class PromptFlowStepButton: PromptButton
---@field onClick fun(ctxt: TickContext, nextStep: fun(idStep: integer))

---@class PromptFlowStep
---@field id integer
---@field title string
---@field cancelButton {label: string, cancelCallback: fun(ctxt: TickContext, nextStep: fun(idStep: integer))?}?
---@field buttons PromptFlowStepButton[]

---@param steps PromptFlowStep[]
local function createFlow(steps)
    if #steps == 0 then return LogError("Invalid prompt flow (empty)") end
    local showStep
    showStep = function(id)
        local step = table.find(steps, function(s) return s.id == id end)
        if step then
            M.show(step.title, table.map(step.buttons, function(btn)
                return {
                    label = btn.label,
                    onClick = btn.onClick and function(ctxt)
                        btn.onClick(ctxt, showStep)
                    end,
                    icon = btn.icon,
                    disabled = btn.disabled,
                    needConfirm = btn.needConfirm,
                }
            end), step.cancelButton.label, step.cancelButton.cancelCallback and function(ctxt)
                step.cancelButton.cancelCallback(ctxt, showStep)
            end)
        end
    end
    showStep(table.find(steps, TrueFn).id)
end

M.onLoad = function()
    reset()
    extensions.core_recoveryPrompt.uiPopupCancelPressed = onCancel
    extensions.core_recoveryPrompt.uiPopupButtonPressed = onButtonPressed
    extensions.core_recoveryPrompt.getUIData = getUIData
end

M.show = show
M.createFlow = createFlow

return M
