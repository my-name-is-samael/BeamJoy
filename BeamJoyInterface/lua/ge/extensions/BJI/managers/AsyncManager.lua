local M = {
    _name = "BJIAsync",
    KEYS = {
        BASE_CACHES_POST_INPUTS = "baseCachesPostInputs",
        RESTRICTIONS_RESET_TIMER = "restrictionsResetTimer",
        RESTRICTIONS_TELEPORT_TIMER = "restrictionsTeleportTimer",
    },
    tasks = {},
    delayedTasks = {},
}

local function exists(key)
    return M.tasks[key] ~= nil or M.delayedTasks[key] ~= nil
end

local function getRemainingDelay(key)
    local task = M.delayedTasks[key]
    if task then
        return task.time - GetCurrentTimeMillis()
    end
    return nil
end

local function task(conditionFn, taskFn, key)
    if conditionFn == nil or taskFn == nil or
        type(conditionFn) ~= "function" or type(conditionFn) ~= type(taskFn) then
        error("Tasks need conditionFn and taskFn")
    end
    if key == nil then
        key = tostring(GetCurrentTimeMillis()) + tostring(math.random(100))
    end
    local existingTask = M.tasks[key]
    if not existingTask then
        M.tasks[key] = {
            conditionFn = conditionFn,
            taskFn = taskFn,
        }
    end
end

local function delayTask(taskFn, delayMs, key)
    delayMs = tonumber(delayMs)
    if taskFn == nil or delayMs == nil or type(taskFn) ~= "function" then
        error("Delayed tasks need taskFn and delay")
    end
    key = key or (tostring(GetCurrentTimeMillis()) + tostring(math.random(100)))
    local existingTask = M.delayedTasks[key]
    if existingTask then
        existingTask.time = GetCurrentTimeMillis() + delayMs
    else
        M.delayedTasks[key] = {
            taskFn = taskFn,
            time = GetCurrentTimeMillis() + delayMs,
        }
    end
end

local function programTask(taskFn, targetMs, key)
    targetMs = tonumber(targetMs)
    if taskFn == nil or targetMs == nil or type(taskFn) ~= "function" then
        error("Programmed tasks need taskFn and target time")
    end
    key = key or (tostring(GetCurrentTimeMillis()) + tostring(math.random(100)))
    local existingTask = M.delayedTasks[key]
    if existingTask then
        existingTask.time = targetMs
    else
        M.delayedTasks[key] = {
            taskFn = taskFn,
            time = targetMs,
        }
    end
end

local function removeTask(key)
    M.tasks[key] = nil
    M.delayedTasks[key] = nil
end

local function renderTick(ctxt)
    local delayed = {}
    for key, ctask in pairs(M.delayedTasks) do
        if ctask.time <= ctxt.now then
            table.insert(delayed, { key, ctask })
        end
    end
    table.sort(delayed, function(a, b)
        return a[2].time < b[2].time
    end)
    for _, data in pairs(delayed) do
        local key, ctask = data[1], data[2]
        local status, err = pcall(ctask.taskFn, ctxt)
        if not status then
            LogError(string.var("Error executing delayed task {1} :", { key }))
            PrintObj(err, "Stack trace")
        end
        M.delayedTasks[key] = nil
    end

    for key, ctask in pairs(M.tasks) do
        if ctask.conditionFn(ctxt) then
            local status, err = pcall(ctask.taskFn, ctxt)
            if not status then
                LogError(string.var("Error executing programmed task {1} :", { key }))
                PrintObj(err, "Stack trace")
            end
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

RegisterBJIManager(M)
return M
