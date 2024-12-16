return function(ctxt)
    local minTime = BJIContext.BJC.TempBan.minTime
    local maxTime = BJIContext.BJC.TempBan.maxTime
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.tempban.minTime") }))
        :helpMarker(BJILang.get("serverConfig.bjc.tempban.zeroTooltip"))
        :inputNumeric({
            id = "tempbanMinTime",
            type = "int",
            value = minTime,
            min = 0,
            step = 5,
            stepFast = 60,
            width = 120,
            onUpdate = function(val)
                BJIContext.BJC.TempBan.minTime = val
            end
        })
        :text(PrettyDelay(minTime))
        :build()
    DrawLineDurationModifiers("tempBanMinTime", minTime, 0, nil, 300, function(val)
        BJIContext.BJC.TempBan.minTime = val
    end)

    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.tempban.maxTime") }))
        :helpMarker(BJILang.get("serverConfig.bjc.tempban.zeroTooltip"))
        :inputNumeric({
            id = "tempbanMaxTime",
            type = "int",
            value = maxTime,
            min = 0,
            step = 5,
            stepFast = 60,
            width = 120,
            onUpdate = function(val)
                BJIContext.BJC.TempBan.maxTime = val
            end
        })
        :text(PrettyDelay(maxTime))
        :build()
    DrawLineDurationModifiers("tempBanMaxTime", maxTime, 0, nil, 31536000, function(val)
        BJIContext.BJC.TempBan.maxTime = val
    end)

    local canSave = minTime >= 0 and maxTime >= 0 and minTime <= maxTime
    LineBuilder()
        :btnIcon({
            id = "tempBanLimitsSave",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            disabled = not canSave,
            onClick = function()
                BJITx.config.bjc("TempBan.minTime", minTime)
                BJITx.config.bjc("TempBan.maxTime", maxTime)
            end
        })
end