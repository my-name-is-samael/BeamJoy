local M = {
    tasks = Table(),
    delayedTasks = Table(),
}

local function exists(key)
    return M.tasks[key] ~= nil or M.delayedTasks[key] ~= nil
end

local function getRemainingDelay(key)
    local task = M.delayedTasks[key]
    if task then
        return task.time - GetCurrentTime()
    end
    return nil
end

---@param conditionFn fun(time: integer): boolean
---@param taskFn fun(time: integer)
---@param key? string
local function task(conditionFn, taskFn, key)
    if type(conditionFn) ~= "function" or type(taskFn) ~= "function" then
        error("Tasks need conditionFn and taskFn")
    end
    key = key or UUID()
    if not M.tasks[key] then
        M.tasks[key] = {
            conditionFn = conditionFn,
            taskFn = taskFn,
        }
    end
end

---@param taskFn fun(time: integer)
---@param delaySec integer 0-N
---@param key? string
local function delayTask(taskFn, delaySec, key)
    if type(taskFn) ~= "function" or type(delaySec) ~= "number" then
        error("Delayed tasks need taskFn and delay")
    end
    delaySec = math.round(delaySec)
    key = key or (tostring(GetCurrentTime()) + tostring(math.random(100)))
    M.delayedTasks[key] = table.assign(
        M.delayedTasks[key] or {}, {
            taskFn = taskFn,
            time = GetCurrentTime() + delaySec,
        }
    )
end

---@param taskFn fun(time: integer)
---@param targetSec integer
---@param key? string
local function programTask(taskFn, targetSec, key)
    if type(taskFn) ~= "function" or type(targetSec) ~= "number" then
        error("Programmed tasks need taskFn and target time")
    end
    targetSec = math.round(targetSec)
    key = key or (tostring(GetCurrentTime()) + tostring(math.random(100)))
    local existingTask = M.delayedTasks[key]
    if existingTask then
        existingTask.time = targetSec
    else
        M.delayedTasks[key] = {
            taskFn = taskFn,
            time = targetSec,
        }
    end
end

local function removeTask(key)
    M.tasks[key] = nil
    M.delayedTasks[key] = nil
end

local function fastTick(time)
    M.delayedTasks:filter(function(el)
        return el.time < time
    end):forEach(function(el, key)
        local ok, err = pcall(el.taskFn, time)
        if not ok then
            LogError(string.var("Error executing delayed task {1} :", { key }))
            dump(err)
        end
        M.delayedTasks[key] = nil
    end)

    if type(M.tasks) == "number" then
        LogError("Async tasks became a number ???")
        return
    end
    M.tasks:filter(function(el)
        return el.conditionFn()
    end):forEach(function(el, key)
        local ok, err = pcall(el.taskFn, time)
        if not ok then
            LogError(string.var("Error executing async task {1} :", { key }))
            dump(err)
        end
        M.tasks[key] = nil
    end)
end

M.exists = exists
M.getRemainingDelay = getRemainingDelay

M.task = task
M.delayTask = delayTask
M.programTask = programTask
M.removeTask = removeTask

BJCEvents.addListener(BJCEvents.EVENTS.FAST_TICK, fastTick, "AsyncManager")

return M
