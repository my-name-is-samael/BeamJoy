local M = {
    tasks = {},
    delayedTasks = {},
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

local function task(conditionFn, taskFn, key)
    if conditionFn == nil or taskFn == nil or
        type(conditionFn) ~= "function" or type(conditionFn) ~= type(taskFn) then
        error("Tasks need conditionFn and taskFn")
    end
    if key == nil then
        key = tostring(GetCurrentTime()) + tostring(math.random(100))
    end
    local existingTask = M.tasks[key]
    if not existingTask then
        M.tasks[key] = {
            conditionFn = conditionFn,
            taskFn = taskFn,
        }
    end
end

local function delayTask(taskFn, delaySec, key)
    delaySec = tonumber(delaySec)
    if taskFn == nil or delaySec == nil or type(taskFn) ~= "function" then
        error("Delayed tasks need taskFn and delay")
    end
    key = key or (tostring(GetCurrentTime()) + tostring(math.random(100)))
    local existingTask = M.delayedTasks[key]
    if existingTask then
        existingTask.time = GetCurrentTime() + delaySec
    else
        M.delayedTasks[key] = {
            taskFn = taskFn,
            time = GetCurrentTime() + delaySec,
        }
    end
end

local function programTask(taskFn, targetSec, key)
    targetSec = tonumber(targetSec)
    if taskFn == nil or targetSec == nil or type(taskFn) ~= "function" then
        error("Programmed tasks need taskFn and target time")
    end
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

local function renderTick()
    local time = GetCurrentTime()
    for key, ctask in pairs(M.delayedTasks) do
        if ctask.time <= time then
            pcall(ctask.taskFn)
            M.delayedTasks[key] = nil
        end
    end

    for key, ctask in pairs(M.tasks) do
        if ctask.conditionFn() then
            pcall(ctask.taskFn)
            M.tasks[key] = nil
        end
    end
end

M.exists = exists
M.getRemainingDelay = getRemainingDelay

M.task = task
M.delayTask = delayTask
M.programTask = programTask
M.removeTask = removeTask

M.renderTick = renderTick
return M
