---@class BJIManagerAsync: BJIManager
local M = {
    _name = "Async",

    tasks = Table(),
    delayedTasks = Table(),
    delayedOrder = Table(),
}

---@param key string|integer
---@return boolean
local function exists(key)
    return M.tasks[key] ~= nil or M.delayedTasks[key] ~= nil
end

---@param key string|integer
---@return integer|nil
local function getRemainingDelay(key)
    local task = M.delayedTasks[key]
    if task then
        return task.time - GetCurrentTimeMillis()
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
    local existingTask = M.tasks[key]
    if not existingTask then
        M.tasks[key] = {
            conditionFn = conditionFn,
            taskFn = taskFn,
        }
    else
        LogWarn("Task " .. key .. " already exists")
    end
end

local function sortDelayedTasks()
    M.delayedOrder = M.delayedTasks:map(function(el, k)
        return { key = k, time = el.time }
    end):sort(function(a, b)
        if a.time == b.time then
            return a.key < b.key
        end
        return a.time < b.time
    end):map(function(el)
        return el.key
    end)
end

---@param taskFn fun(ctxt: TickContext)
---@param delayMs integer|number
---@param key? string|integer
local function delayTask(taskFn, delayMs, key)
    if taskFn == nil or type(delayMs) ~= "number" or type(taskFn) ~= "function" then
        error("Delayed tasks need taskFn and delay")
    end
    key = key or (tostring(GetCurrentTimeMillis()) + tostring(math.random(100)))
    local existingTask = M.delayedTasks[key]
    if existingTask then
        existingTask.time = GetCurrentTimeMillis() + delayMs
        existingTask.taskFn = taskFn
    else
        M.delayedTasks[key] = {
            taskFn = taskFn,
            time = GetCurrentTimeMillis() + delayMs,
        }
    end
    sortDelayedTasks()
end

---@param taskFn fun(ctxt: TickContext)
---@param targetMs integer|number
---@param key? string|integer
local function programTask(taskFn, targetMs, key)
    if taskFn == nil or type(targetMs) ~= "number" or type(taskFn) ~= "function" then
        error("Programmed tasks need taskFn and target time")
    end
    key = key or (tostring(GetCurrentTimeMillis()) + tostring(math.random(100)))
    local existingTask = M.delayedTasks[key]
    if existingTask then
        existingTask.time = targetMs
        existingTask.taskFn = taskFn
    else
        M.delayedTasks[key] = {
            taskFn = taskFn,
            time = targetMs,
        }
    end
    sortDelayedTasks()
end

---@param key string
local function removeTask(key)
    M.tasks[key] = nil
    M.delayedTasks[key] = nil
    if M.delayedOrder:includes(key) then
        M.delayedOrder:remove(M.delayedOrder:indexOf(key))
    end
end

local renderTimeout = 4
local function renderTick(ctxt)
    if M.delayedOrder[1] then
        local key = M.delayedOrder[1]
        if not M.delayedTasks[key] then
            M.delayedOrder:remove(1)
        elseif M.delayedTasks[key].time <= ctxt.now then
            local start = GetCurrentTimeMillis()
            local ctask = M.delayedTasks[key]
            local status, err = pcall(ctask.taskFn, ctxt)
            if not status then
                LogError(string.var("Error executing delayed task {1} :", { key }))
                dump(err)
            end
            local benchTime = GetCurrentTimeMillis() - start
            M.delayedTasks[key] = nil
            M.delayedOrder:remove(1)
            if benchTime > renderTimeout / 2 then
                LogWarn(string.var("Delayed task {1} took {2}ms", { key, benchTime }))
                return
            end
        end
    end

    M.tasks:forEach(function(ctask, key)
        if GetCurrentTimeMillis() - ctxt.now > renderTimeout then
            LogDebug("Skipping async tasks (timeout)", M._name)
            return
        end
        if ctask.conditionFn(ctxt) then
            local status, err = pcall(ctask.taskFn, ctxt)
            if not status then
                LogError(string.var("Error executing programmed task {1} :", { key }))
                PrintObj(err)
            end
            M.tasks[key] = nil
        end
    end)
end

M.exists = exists
M.getRemainingDelay = getRemainingDelay

M.task = task
M.delayTask = delayTask
M.programTask = programTask
M.removeTask = removeTask

M.renderTick = renderTick

return M
