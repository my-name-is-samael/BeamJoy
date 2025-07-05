local U = {
    MARGINS = { -- absolute values
        WINDOW_TOP = 9,
        WINDOW_LEFT = 17,
        WINDOW_RIGHT = 17,
        WINDOW_BOTTOM = 13,

        CHILD = 4,
        INPUT = 5,
    },
    SIZES = { -- based on scale values
        WINDOW_TITLE_HEIGHT = 21,
        COMBO_BUTTON = 20,
    },
}
local scale

-- SIZES

---@param text string
---@return integer
function U.GetTextWidth(text)
    scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE) or 1
    return math.round(ui_imgui.CalcTextSize(text and tostring(text) or "").x * scale)
end

---@param content any
---@return integer
function U.GetColumnTextWidth(content)
    return U.GetTextWidth(tostring(content)) + U.MARGINS.INPUT * 2
end

---@param content any
---@param typeNumber? boolean
---@return integer
function U.GetInputWidthByContent(content, typeNumber)
    if typeNumber then
        return U.GetInputWidthByContent(content) + U.GetInputWidthByContent("-") + U.GetInputWidthByContent("+")
    else
        return U.GetTextWidth(tostring(content)) + U.MARGINS.INPUT * 4
    end
end

---@param content any
---@return integer
function U.GetComboWidthByContent(content)
    scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE) or 1
    return U.GetTextWidth(tostring(content)) + U.MARGINS.INPUT * 2 + U.SIZES.COMBO_BUTTON * scale
end

---@param big boolean?
---@return integer
function U.GetIconSize(big)
    scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE) or 1
    return math.round((big and 32 or 20) * scale)
end

---@param big boolean?
---@return integer
function U.GetBtnIconSize(big)
    return U.GetIconSize(big) + U.MARGINS.INPUT * 2
end

-- FORMATTING

---@param secs number
---@return string
function U.PrettyDelay(secs)
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
        local monthLabel = BJI.Managers.Lang.get("common.time.months")
        return string.var("{months} {monthLabel}", { months = months, monthLabel = monthLabel })
    elseif months == 1 then
        local monthLabel = BJI.Managers.Lang.get("common.time.month")
        local dayLabel = BJI.Managers.Lang.get("common.time.day")
        local andLabel = BJI.Managers.Lang.get("common.time.and")
        if days > 1 then
            dayLabel = BJI.Managers.Lang.get("common.time.days")
        end
        if days > 0 then
            return string.var("{months} {monthLabel} {andLabel} {days} {dayLabel}",
                { months = months, monthLabel = monthLabel, andLabel = andLabel, days = days, dayLabel = dayLabel })
        else
            return string.var("{months} {monthLabel}", { months = months, monthLabel = monthLabel })
        end
    end

    if days > 1 then
        local dayLabel = BJI.Managers.Lang.get("common.time.days")
        return string.var("{days} {dayLabel}", { days = days, dayLabel = dayLabel })
    elseif days == 1 then
        local dayLabel = BJI.Managers.Lang.get("common.time.day")
        local hourLabel = BJI.Managers.Lang.get("common.time.hour")
        local andLabel = BJI.Managers.Lang.get("common.time.and")
        if hours > 1 then
            hourLabel = BJI.Managers.Lang.get("common.time.hours")
        end
        if hours > 0 then
            return string.var("{days} {dayLabel} {andLabel} {hours} {hourLabel}",
                { days = days, dayLabel = dayLabel, andLabel = andLabel, hours = hours, hourLabel = hourLabel })
        else
            return string.var("{days} {dayLabel}", { days = days, dayLabel = dayLabel })
        end
    end

    if hours > 1 then
        local hourLabel = BJI.Managers.Lang.get("common.time.hours")
        return string.var("{hours} {hourLabel}", { hours = hours, hourLabel = hourLabel })
    elseif hours == 1 then
        local hourLabel = BJI.Managers.Lang.get("common.time.hour")
        local minuteLabel = BJI.Managers.Lang.get("common.time.minute")
        local andLabel = BJI.Managers.Lang.get("common.time.and")
        if mins > 1 then
            minuteLabel = BJI.Managers.Lang.get("common.time.minutes")
        end
        if mins > 0 then
            return string.var("{hours} {hourLabel} {andLabel} {mins} {minuteLabel}",
                { hours = hours, hourLabel = hourLabel, andLabel = andLabel, mins = mins, minuteLabel = minuteLabel })
        else
            return string.var("{hours} {hourLabel}", { hours = hours, hourLabel = hourLabel })
        end
    end

    if mins > 1 then
        local minLabel = BJI.Managers.Lang.get("common.time.minutes")
        return string.var("{mins} {minLabel}", { mins = mins, minLabel = minLabel })
    elseif mins == 1 then
        local minLabel = BJI.Managers.Lang.get("common.time.minute")
        local secLabel = BJI.Managers.Lang.get("common.time.second")
        local andLabel = BJI.Managers.Lang.get("common.time.and")
        if secs > 0 then
            return string.var("{mins} {minLabel} {andLabel} {secs} {secLabel}",
                { mins = mins, minLabel = minLabel, andLabel = andLabel, secs = secs, secLabel = secLabel })
        else
            return string.var("{mins} {minLabel}", { mins = mins, minLabel = minLabel })
        end
    end

    local secondLabel = BJI.Managers.Lang.get("common.time.second")
    if secs > 1 then
        secondLabel = BJI.Managers.Lang.get("common.time.seconds")
    end
    return string.var("{secs} {secondLabel}", { secs = secs, secondLabel = secondLabel })
end

---@param ms integer
---@return string
function U.RaceDelay(ms)
    ms = math.round(ms or 0)
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

---@param meter? number
---@return string
function U.PrettyDistance(meter)
    meter = tonumber(meter)
    if not meter then
        return "0m"
    end
    if settings.getValue("uiUnitLength") == "imperial" then
        local foot = meter * 3.28084
        local miles = foot / 5280
        if miles >= .5 then
            return string.var("{1}mi", { math.round(miles, 1) })
        else
            return string.var("{1}ft", { math.round(foot) })
        end
    else
        local kms = meter / 1000
        if kms >= .5 then
            return string.var("{1}km", { math.round(kms, 1) })
        else
            return string.var("{1}m", { math.round(meter) })
        end
    end
end

---@param ToD integer
---@return string
function U.PrettyTime(ToD)
    local secs = ToD * 86400
    if ToD >= 0 and ToD < .5 then
        secs = secs + 43200
    elseif ToD >= .5 and ToD <= 1 then
        secs = secs - 43200
    end
    local curHours = math.floor(secs / 3600)
    secs = secs - curHours * 3600
    local curMins = math.floor(secs / 60)
    return string.format("%02d:%02d", curHours, curMins)
end

-- DRAWERS

---@param id string
---@param value integer
---@param min? integer
---@param max? integer
---@param resetValue integer
---@param disabled? boolean
---@return integer? changedValue
function U.DrawLineDurationModifiers(id, value, min, max, resetValue, disabled)
    local showMonth = true
    if max and max < 60 * 60 * 24 * 30 then
        showMonth = false
    end
    local showDay = true
    if max and max < 60 * 60 * 24 then
        showDay = false
    end
    local showHour = true
    if max and max < 60 * 60 then
        showHour = false
    end

    local res, drawn
    if showMonth then
        if Button(id .. "M1M", "-1" .. BJI.Managers.Lang.get("common.durationModifiers.month"),
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = disabled }) then
            res = math.clamp(value - (60 * 60 * 24 * 30), min, max)
        end
        drawn = true
    end
    if showDay then
        if drawn then SameLine() end
        if Button(id .. "M1d", "-1" .. BJI.Managers.Lang.get("common.durationModifiers.day"),
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = disabled }) then
            res = math.clamp(value - (60 * 60 * 24), min, max)
        end
        drawn = true
    end
    if showHour then
        if drawn then SameLine() end
        if Button(id .. "M1h", "-1" .. BJI.Managers.Lang.get("common.durationModifiers.hour"),
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = disabled }) then
            res = math.clamp(value - (60 * 60), min, max)
        end
        drawn = true
    end
    if drawn then SameLine() end
    if Button(id .. "M1m", "-1" .. BJI.Managers.Lang.get("common.durationModifiers.minute"),
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = disabled }) then
        res = math.clamp(value - 60, min, max)
    end
    SameLine()
    if Button(id .. "P1m", "+1" .. BJI.Managers.Lang.get("common.durationModifiers.minute"),
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = disabled }) then
        res = math.clamp(value + 60, min, max)
    end
    if showHour then
        SameLine()
        if Button(id .. "P1h", "+1" .. BJI.Managers.Lang.get("common.durationModifiers.hour"),
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = disabled }) then
            res = math.clamp(value + (60 * 60), min, max)
        end
    end
    if showDay then
        SameLine()
        if Button(id .. "P1d", "+1" .. BJI.Managers.Lang.get("common.durationModifiers.day"),
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = disabled }) then
            res = math.clamp(value + (60 * 60 * 24), min, max)
        end
    end
    if showMonth then
        SameLine()
        if Button(id .. "P1M", "+1" .. BJI.Managers.Lang.get("common.durationModifiers.month"),
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = disabled }) then
            res = math.clamp(value + (60 * 60 * 24 * 30), min, max)
        end
    end
    SameLine()
    if IconButton(id .. "reset", BJI.Utils.Icon.ICONS.refresh, {
            btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = disabled }) then
        res = resetValue
    end
    TooltipText(BJI.Managers.Lang.get("common.buttons.reset"))
    return res
end

---@param id string
---@param withUpdate? boolean
---@param disabled? boolean
function U.DrawTimePlayPauseButtons(id, withUpdate, disabled)
    if IconButton(id .. "-pause", BJI.Utils.Icon.ICONS.pause, {
            btnStyle = not BJI.Managers.Env.Data.timePlay and BJI.Utils.Style.BTN_PRESETS.ERROR or
                BJI.Utils.Style.BTN_PRESETS.INFO,
            disabled = disabled,
            bgLess = not BJI.Managers.Env.Data.timePlay,
        }) then
        local hasRight = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT_PRESET)
        if hasRight and withUpdate and BJI.Managers.Env.Data.timePlay then
            BJI.Managers.Env.Data.timePlay = not BJI.Managers.Env.Data.timePlay
            BJI.Tx.config.env("timePlay", BJI.Managers.Env.Data.timePlay)
        end
    end
    TooltipText(BJI.Managers.Lang.get("common.buttons.stop"))
    SameLine()
    if IconButton(id .. "-play", BJI.Utils.Icon.ICONS.play, {
            btnStyle = BJI.Managers.Env.Data.timePlay and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                BJI.Utils.Style.BTN_PRESETS.INFO,
            disabled = disabled,
            bgLess = BJI.Managers.Env.Data.timePlay,
        }) then
        local hasRight = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT_PRESET)
        if hasRight and withUpdate and not BJI.Managers.Env.Data.timePlay then
            BJI.Managers.Env.Data.timePlay = not BJI.Managers.Env.Data.timePlay
            BJI.Tx.config.env("timePlay", BJI.Managers.Env.Data.timePlay)
        end
    end
    TooltipText(BJI.Managers.Lang.get("common.buttons.play"))
end

function U.AddPlayerActionVoteKick(actions, playerID)
    table.insert(actions, {
        id = string.var("voteKick{1}", { playerID }),
        icon = BJI.Utils.Icon.ICONS.event_busy,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = BJI.Managers.Lang.get("playersBlock.buttons.voteKick"),
        onClick = function()
            BJI.Managers.Votes.Kick.start(playerID)
        end
    })
end

return U
