---@class BJIManagerMessage : BJIManager
local M = {
    _name = "Message",

    flashQueue = Table(),
    currentFlash = {
        ---@type string?
        msg = nil,
        ---@type integer?
        timeEnd = nil,
        big = false,
    },

    realtimeData = {
        context = nil,
        msg = "",
    },
}

local function _clearFlash()
    guihooks.trigger('ScenarioFlashMessageReset')
end

---@param msg string
---@param delaySec integer
---@param big boolean
local function _flash(msg, delaySec, big)
    _clearFlash()
    guihooks.trigger('ScenarioFlashMessage', { { msg, delaySec, nil, big } })
    M.currentFlash = {
        msg = msg,
        timeEnd = GetCurrentTimeMillis() + delaySec * 1000,
        big = big,
    }
end

local function _getNextAvailableTime()
    if #M.flashQueue == 0 then
        return GetCurrentTimeMillis()
    end
    return M.flashQueue:reduce(function(res, f)
        local target = f.time + f.delay * 1000 + 1
        return res < target and target or res
    end, GetCurrentTimeMillis())
end

---@param key string
---@param msg string
---@param delaySec? integer
---@param big? boolean
---@param targetTime? integer
---@param callback? fun()
---@param sound? string
local function flash(key, msg, delaySec, big, targetTime, callback, sound)
    msg = tostring(msg)
    delaySec = tonumber(delaySec) or 3
    targetTime = targetTime or _getNextAvailableTime()

    M.flashQueue:forEach(function(f, i)
        if f.time < targetTime and f.time + f.delay * 1000 > targetTime then
            -- overlap before
            f.delay = math.round((targetTime - f.time) / 1000)
        elseif f.time > targetTime and f.time < targetTime + delaySec * 1000 then
            -- overlap after
            delaySec = math.floor((f.time - targetTime) / 1000)
        end
    end)

    M.flashQueue:insert({
        key = key,
        time = targetTime,
        msg = msg,
        delay = delaySec,
        big = big == true,
        callback = callback,
        sound = sound,
    })
    M.flashQueue:sort(function(a, b)
        if a.time ~= b.time then
            return a.time < b.time
        end
        return a.delay < b.delay
    end)
end

---@param key string
local function cancelFlash(key)
    M.flashQueue = M.flashQueue:filter(function(f)
        if f.key == key then
            if M.currentFlash.msg == f.msg then
                M.currentFlash = {}
            end
        end
        return f.key ~= key
    end)
end

---@param key string
---@param targetTimeMs integer
---@param big? boolean
---@param zeroLabel? string
---@param max? integer
---@param callback? fun()
---@param countdownSounds? boolean
local function flashCountdown(key, targetTimeMs, big, zeroLabel, max, callback, countdownSounds)
    local now = GetCurrentTimeMillis()
    if not zeroLabel and callback then
        zeroLabel = ""
    end

    local time = targetTimeMs

    local i = 0
    while time > now and (not max or i <= max) do
        if i > 0 or zeroLabel then
            local label = tostring(i)
            if i == 0 then
                label = zeroLabel or ""
            end
            local sound = nil
            if countdownSounds and i <= 3 then
                if i == 0 then
                    sound = BJI.Managers.Sound.SOUNDS.RACE_START
                else
                    sound = BJI.Managers.Sound.SOUNDS.RACE_COUNTDOWN
                end
            end
            M.flash(key, label, i == 0 and 2 or 1, big, time, i == 0 and callback or nil, sound)
        end
        time = time - 1000
        i = i + 1
    end
end

local function renderTick(ctxt)
    local msgIndices = M.flashQueue:reduce(function(res, f, i)
        if f.time <= ctxt.now then
            res:insert(i)
        end
        return res
    end, Table())

    if #msgIndices == 0 then
        return
    end
    -- keep only last index
    while #msgIndices > 1 do
        msgIndices:remove(1)
    end

    local el = M.flashQueue[msgIndices[1]]
    if el then
        if #el.msg > 0 then
            _flash(el.msg, el.delay, el.big)
        end
        if el.sound then
            BJI.Managers.Sound.play(el.sound)
        end
        if type(el.callback) == "function" then
            el.callback(ctxt)
        end
        M.flashQueue:remove(msgIndices[1])
    end
end

local function realtimeDisplay(context, msg)
    M.realtimeData = {
        context = context or "",
        msg = msg or "",
    }
    guihooks.trigger('ScenarioRealtimeDisplay', M.realtimeData)
end

local function stopRealtimeDisplay()
    M.realtimeData = {
        context = nil,
        msg = "",
    }
    guihooks.trigger('ScenarioRealtimeDisplay', M.realtimeData)
end

local function message(msg)
    guihooks.trigger('Message', { ttl = 1, msg = msg, category = "" })
end

local function postLayoutUpdate()
    local now = GetCurrentTimeMillis()
    if M.currentFlash.timeEnd and M.currentFlash.timeEnd > now then
        local remainingSec = math.round((M.currentFlash.timeEnd - now) / 1000)
        if remainingSec > 0 then
            _flash(M.currentFlash.msg, remainingSec, M.currentFlash.big)
        end
    end
    if M.realtimeData.msg and #M.realtimeData.msg > 0 then
        realtimeDisplay(M.realtimeData.context, M.realtimeData.msg)
    end
end

M.flash = flash
M.flashCountdown = flashCountdown
M.cancelFlash = cancelFlash

M.realtimeDisplay = realtimeDisplay
M.stopRealtimeDisplay = stopRealtimeDisplay

M.message = message

M.postLayoutUpdate = postLayoutUpdate

M.renderTick = renderTick

return M
