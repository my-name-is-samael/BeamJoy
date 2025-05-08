-- GLOBAL FUNCTIONS --------------------------------------------------------
MP = MP or {
    Settings = {
        Debug = 0,
        Private = 1,
        MaxCars = 2,
        MaxPlayers = 3,
        Map = 4,
        Name = 5,
        Description = 6,
    },
    RegisterEvent = function(eventName, functionNameString) end,
    TriggerGlobalEvent = function(eventName, ...) end,
    TriggerClientEventJson = function(playerID, eventName, json) end,
    TriggerClientEvent = function(playerID, eventName, dataStr) return true end,
    CreateEventTimer = function(eventName, delay) end,
    CreateTimer = function() return { GetCurrent = function() return 0 end } end,
    GetPlayerName = function(playerID) return "" end,
    GetPlayerCount = function() return 0 end,
    SendChatMessage = function(playerID, message) end,
    DropPlayer = function(playerID, reason) end,
    RemoveVehicle = function(playerID, vehID) end,
    Set = function(mpSettingsKey, value) end,
    Sleep = function(ms) end,
}
FS = FS or {
    ListDirectories = function(path) end,
    ListFiles = function(path) return {} end,
    IsDirectory = function(path) end,
    IsFile = function(path) end,
    Exists = function(path) end,
    GetParentFolder = function(path) end,
    ConcatPaths = function(path1, path2) end,
    CreateDirectory = function(path) end,
    GetFilename = function(path) end,
    GetExtension = function(path) end,
    Rename = function(currentPath, newPath) end,
    Copy = function(srcPath, destPath) end,
    Remove = function(path) end,
}
Util = Util or {}
Exit = exit or function() end ---@diagnostic disable-line
-------------------------------------------------------------------------

CONSOLE_COLORS = {
    STYLES = {
        RESET = 0,
        BOLD = 1,
        UNDERLINE = 4,
        INVERSE = 7
    },
    FOREGROUNDS = {
        BLACK = 30,
        RED = 31,
        GREEN = 32,
        YELLOW = 33,
        BLUE = 34,
        MAGENTA = 35,
        CYAN = 36,
        LIGHT_GREY = 37,
        GREY = 90,
        LIGHT_RED = 91,
        LIGHT_GREEN = 92,
        LIGHT_YELLOW = 93,
        LIGHT_BLUE = 94,
        LIGHT_MAGENTA = 95,
        LIGHT_CYAN = 96,
        WHITE = 97,
    },
    BACKGROUNDS = {
        BLACK = 40,
        RED = 41,
        GREEN = 42,
        YELLOW = 43,
        BLUE = 44,
        MAGENTA = 45,
        CYAN = 46,
        LIGHT_GREY = 47,
        GREY = 100,
        LIGHT_RED = 101,
        LIGHT_GREEN = 102,
        LIGHT_YELLOW = 103,
        LIGHT_BLUE = 104,
        LIGHT_MAGENTA = 105,
        LIGHT_CYAN = 106,
        WHITE = 107,
    }
}
local function _getConsoleColor(fg, bg)
    local strColor = string.var("{1}[{2}", { string.char(27), tostring(fg) })
    if bg then
        strColor = string.var("{1};{2}", { strColor, tostring(bg) })
    end
    return string.var('{1}m', { strColor })
end

local logTypes = {}
function SetLogType(tag, tagColor, tagBgColor, stringColor, stringBgColor)
    tagColor = tagColor or 0
    stringColor = stringColor or 0
    logTypes[tag] = {
        headingColor = _getConsoleColor(tagColor, tagBgColor),
        stringColor = _getConsoleColor(stringColor, stringBgColor)
    }
end

function Log(content, tag)
    tag = tag or "BJC"

    local resetColor = _getConsoleColor(0)
    local prefix = ""

    local tagColor = resetColor
    local stringColor = resetColor
    if logTypes[tag] then
        tagColor = logTypes[tag].headingColor
        stringColor = logTypes[tag].stringColor
    end
    prefix = string.var("{1}[{2}{3}{4}] {5}", { prefix, tagColor, tag, resetColor, stringColor })

    if content == nil then
        content = "nil"
    elseif type(content) == "boolean" or type(content) == "number" then
        content = tostring(content)
    elseif type(content) == 'table' then
        content = string.var("table ({1} children)", { table.length(content) })
    end

    print(string.var("{1}{2}{3}", { prefix, content, _getConsoleColor(0) }))
end

function LogDebug(content, tag)
    local show = true
    if BJCCore then
        show = BJCCore.Data.General.Debug
    end
    if not show then
        return
    end

    Log(string.var("DEBUG | {1}", { content }), tag)
end

SetLogType("ERROR", CONSOLE_COLORS.FOREGROUNDS.RED, nil, CONSOLE_COLORS.FOREGROUNDS.LIGHT_RED)
function LogError(content)
    Log(content, "ERROR")
end

SetLogType("WARN", CONSOLE_COLORS.FOREGROUNDS.YELLOW, nil, CONSOLE_COLORS.FOREGROUNDS.LIGHT_YELLOW)
function LogWarn(content)
    Log(content, "WARN")
end

-- DISTANCE / POSITIONS

function GetHorizontalDistance(pos1, pos2)
    if not pos1.x or not pos1.y or
        not pos2.x or not pos2.y then
        LogError("invalid position")
        return 0
    end

    return math.sqrt((pos1.x - pos2.x) ^ 2 + (pos1.y - pos2.y) ^ 2)
end

-- FORMAT
function PrettyDelay(secs)
    local mins, hours, days, months = 0, 0, 0, 0
    if secs >= 60 then
        mins = math.floor(secs / 60)
        secs = secs - mins * 60
    end
    if mins >= 60 then
        hours = math.floor(mins / 60)
        mins = mins - hours * 60
    end
    if hours >= 24 then
        days = math.floor(hours / 24)
        hours = hours - days * 24
    end
    if days >= 30 then
        months = math.floor(days / 30)
        days = days - months * 30
    end

    if months > 1 then
        local monthLabel = BJCLang.getConsoleMessage("common.time.months")
        return string.var("{months} {monthLabel}", { months = months, monthLabel = monthLabel })
    elseif months == 1 then
        local monthLabel = BJCLang.getConsoleMessage("common.time.month")
        local dayLabel = BJCLang.getConsoleMessage("common.time.day")
        local andLabel = BJCLang.getConsoleMessage("common.time.and")
        if days > 1 then
            dayLabel = BJCLang.getConsoleMessage("common.time.days")
        end
        if days > 0 then
            return string.var("{months} {monthLabel} {andLabel} {days} {dayLabel}",
                { months = months, monthLabel = monthLabel, andLabel = andLabel, days = days, dayLabel = dayLabel })
        else
            return string.var("{months} {monthLabel}", { months = months, monthLabel = monthLabel })
        end
    end

    if days > 1 then
        local dayLabel = BJCLang.getConsoleMessage("common.time.days")
        return string.var("{days} {dayLabel}", { days = days, dayLabel = dayLabel })
    elseif days == 1 then
        local dayLabel = BJCLang.getConsoleMessage("common.time.day")
        local hourLabel = BJCLang.getConsoleMessage("common.time.hour")
        local andLabel = BJCLang.getConsoleMessage("common.time.and")
        if hours > 1 then
            hourLabel = BJCLang.getConsoleMessage("common.time.hours")
        end
        if hours > 0 then
            return string.var("{days} {dayLabel} {andLabel} {hours} {hourLabel}",
                { days = days, dayLabel = dayLabel, andLabel = andLabel, hours = hours, hourLabel = hourLabel })
        else
            return string.var("{days} {dayLabel}", { days = days, dayLabel = dayLabel })
        end
    end

    if hours > 1 then
        local hourLabel = BJCLang.getConsoleMessage("common.time.hours")
        return string.var("{hours} {hourLabel}", { hours = hours, hourLabel = hourLabel })
    elseif hours == 1 then
        local hourLabel = BJCLang.getConsoleMessage("common.time.hour")
        local minuteLabel = BJCLang.getConsoleMessage("common.time.minute")
        local andLabel = BJCLang.getConsoleMessage("common.time.and")
        if mins > 1 then
            minuteLabel = BJCLang.getConsoleMessage("common.time.minutes")
        end
        if mins > 0 then
            return string.var("{hours} {hourLabel} {andLabel} {mins} {minuteLabel}",
                { hours = hours, hourLabel = hourLabel, andLabel = andLabel, mins = mins, minuteLabel = minuteLabel })
        else
            return string.var("{hours} {hourLabel}", { hours = hours, hourLabel = hourLabel })
        end
    end

    if mins > 1 then
        local minLabel = BJCLang.getConsoleMessage("common.time.minutes")
        return string.var("{mins} {minLabel}", { mins = mins, minLabel = minLabel })
    elseif mins == 1 then
        local minLabel = BJCLang.getConsoleMessage("common.time.minute")
        local secLabel = BJCLang.getConsoleMessage("common.time.second")
        local andLabel = BJCLang.getConsoleMessage("common.time.and")
        if secs > 0 then
            return string.var("{mins} {minLabel} {andLabel} {secs} {secLabel}",
                { mins = mins, minLabel = minLabel, andLabel = andLabel, secs = secs, secLabel = secLabel })
        else
            return string.var("{mins} {minLabel}", { mins = mins, minLabel = minLabel })
        end
    end

    local secondLabel = BJCLang.getConsoleMessage("common.time.second")
    if secs > 1 then
        secondLabel = BJCLang.getConsoleMessage("common.time.seconds")
    end
    return string.var("{secs} {secondLabel}", { secs = secs, secondLabel = secondLabel })
end

BJC_TOAST_TYPES = {
    SUCCESS = "success",
    INFO = "info",
    WARNING = "warning",
    ERROR = "error"
}

function BJCInitContext(data)
    table.assign(data, {
        time = GetCurrentTime(),
        origin = data.senderID and "player" or "cmd",
    })
end

-- FORMAT

function RaceDelay(ms)
    local hours = math.floor(ms / 1000 / 60 / 60)
    ms = ms - hours * 60 * 60 * 1000
    local mins = math.floor(ms / 1000 / 60)
    ms = ms - mins * 60 * 1000
    local secs = math.floor(ms / 1000)
    ms = ms - secs * 1000

    if hours > 0 then
        return string.var("{1}:{2}:{3}.{4}",
            {
                tostring(hours),
                string.normalizeInt(mins, 2),
                string.normalizeInt(secs, 2),
                string.normalizeInt(ms, 3)
            })
    elseif mins > 0 then
        return string.var("{1}:{2}.{3}",
            {
                mins,
                string.normalizeInt(secs, 2),
                string.normalizeInt(ms, 3)
            })
    else
        return string.var("{1}.{2}", {
            secs,
            string.normalizeInt(ms, 3)
        })
    end
end

---@return Timer
function TimerCreate()
    return {
        _timer = MP.CreateTimer(),
        get = function(self)
            local secTime = self._timer:GetCurrent()
            return math.round(secTime * 1000)
        end,
        reset = function(self)
            self._timer:Start()
        end
    }
end

---@param delaySec integer 2-60
---@param getMessage fun(player: table, delaySec: integer): string
---@param kickReasonKey string
---@param callback? fun()
function CountdownKickAll(delaySec, getMessage, kickReasonKey, callback)
    delaySec = math.clamp(tonumber(delaySec) or 2, 2, 60)
    if MP.GetPlayerCount() == 0 then
        MP.Sleep(500)
        if callback then callback() end
        return
    end

    local asyncKey = "CountdownKickAll-{1}"
    if BJCAsync.exists(asyncKey:var({ 1 })) then
        Range(1, 60):forEach(function(i)
            BJCAsync.removeTask(asyncKey:var({ i }))
        end)
    end

    Range(delaySec - 1, 1)
        :forEach(function(i)
            BJCAsync.delayTask(function()
                if MP.GetPlayerCount() == 0 then
                    Range(1, delaySec):forEach(function(j)
                        BJCAsync.removeTask(asyncKey:var({ j }))
                    end)
                    if callback then callback() end
                else
                    Table(BJCPlayers.Players):forEach(function(player, playerID)
                        BJCChat.onServerChat(playerID, getMessage(player, i))
                    end)
                end
            end, delaySec - i, asyncKey:var({ i }))
        end)
    BJCAsync.delayTask(function()
        if MP.GetPlayerCount() > 0 then
            BJCPlayers.dropMultiple(Table(BJCPlayers.Players):keys(), kickReasonKey)
        end
        if callback then callback() end
    end, delaySec, asyncKey:var({ delaySec }))
end
