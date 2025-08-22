---@class NGJob
---@field yield fun()
---@field sleep fun(sec: number)
---@field setExitCallback fun(cb: fun(jobData: table))

---@class BJIManagerAsync: BJIManager
local M = {
    _name = "Async",

    ---@type table<string, true> index key
    tasks = {},
    ---@type table<string, true> index key
    tasksToRemove = {},
    ---@type table<string, integer> index key, value targetTime
    delayedTasks = {},
    ---@type table<string, true> index key
    delayedToRemove = {},
}
-- gb optimization
local ctxt = { now = 0 }

---@param key string|integer
---@return boolean
local function exists(key)
    return M.tasks[key] or M.delayedTasks[key]
end

---@param key string|integer
---@return integer|nil
local function getRemainingDelay(key)
    local taskTargetTime = M.delayedTasks[key]
    if taskTargetTime then
        return taskTargetTime - GetCurrentTimeMillis()
    end
    return nil
end

---@param conditionFn fun(ctxt: TickContext): boolean
---@param taskFn fun(ctxt: TickContext)
---@param key? string|integer
local function task(conditionFn, taskFn, key)
    if conditionFn == nil or taskFn == nil or
        type(conditionFn) ~= "function" or type(conditionFn) ~= type(taskFn) then
        error("Tasks need conditionFn and taskFn")
    end
    if key == nil then
        key = UUID()
    end

    local function start()
        ---@param job NGJob
        extensions.core_jobsystem.create(function(job)
            job.setExitCallback(function()
                taskFn(ctxt)
            end)
            while not conditionFn(ctxt) and not M.tasksToRemove[key] do
                job.sleep(.01)
            end
            if M.tasksToRemove[key] then
                job.setExitCallback(function() end)
                M.tasksToRemove[key] = nil
            end
            M.tasks[key] = nil
        end, .1)
        M.tasks[key] = true
    end

    if M.tasks[key] then
        M.tasksToRemove[key] = true
        ---@param job NGJob
        extensions.core_jobsystem.create(function(job)
            job.setExitCallback(start)
            while M.tasks[key] do
                job.sleep(.01)
            end
        end, .1)
    else
        start()
    end
end

---@param taskFn fun(ctxt: TickContext)
---@param delayMs integer|number
---@param key? string|integer
local function delayTask(taskFn, delayMs, key)
    if taskFn == nil or type(delayMs) ~= "number" or type(taskFn) ~= "function" then
        error("Delayed tasks need taskFn and delay")
    end
    key = key or (tostring(GetCurrentTimeMillis()) + tostring(math.random(100)))
    local targetTime = ctxt.now + delayMs

    local function start()
        ---@param job NGJob
        extensions.core_jobsystem.create(function(job)
            job.setExitCallback(function()
                taskFn(ctxt)
            end)
            while ctxt.now < targetTime and not M.delayedToRemove[key] do
                job.sleep(.01)
            end
            if M.delayedToRemove[key] then
                job.setExitCallback(function() end)
                M.delayedToRemove[key] = nil
            end
            M.delayedTasks[key] = nil
        end, .1)
        M.delayedTasks[key] = targetTime
    end

    if M.delayedTasks[key] then
        M.delayedToRemove[key] = true
        ---@param job NGJob
        extensions.core_jobsystem.create(function(job)
            job.setExitCallback(start)
            while M.delayedTasks[key] do
                job.sleep(.01)
            end
        end, .1)
    else
        start()
    end
end

---@param taskFn fun(ctxt: TickContext)
---@param targetMs integer|number
---@param key? string|integer
local function programTask(taskFn, targetMs, key)
    delayTask(taskFn, targetMs - ctxt.now, key)
end

---@param key string
local function removeTask(key)
    if M.tasks[key] then
        M.tasksToRemove[key] = true
    end

    if M.delayedTasks[key] then
        M.delayedToRemove[key] = true
    end
end

M.exists = exists
M.getRemainingDelay = getRemainingDelay

M.task = task
M.delayTask = delayTask
M.programTask = programTask
M.removeTask = removeTask

---@param c TickContext
M.renderTick = function(c) ctxt = c end

return M
