local logTag = "Rx"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.LIGHT_GREEN)

-- RX Util Functions
BJCRx = {}

local function controllerDispatch(self, ctxt)
    local fn = self[ctxt.endpoint]
    if fn and type(fn) == "function" then
        fn(ctxt)
    else
        error({ key = "rx.errors.invalidEndpoint", data = { endpoint = ctxt.endpoint } })
    end
end

local function checkSenderAndData(senderID, data)
    if data == nil or not data.id then
        error({ key = "rx.errors.invalidData" })
    elseif not data.parts and not data.part then
        error({ key = "rx.errors.invalidData" })
    elseif data.parts and (not data.controller or not data.endpoint) then
        error({ key = "rx.errors.invalidData" })
    elseif data.part and not data.data then
        error({ key = "rx.errors.invalidData" })
    end
    local sender = BJCPlayers.Players[senderID]
    if not sender then
        error({ key = "rx.errors.senderIDInvalid", data = { senderID = senderID } })
    end
    return sender
end

local function logAndToastError(senderID, key, data)
    key = key or "rx.errors.serverError"
    data = data or {}

    local srvLang = BJCConfig.Data.Server.Lang

    -- srv log
    LogError(BJCLang.getServerMessage(srvLang, key):var(data), logTag)
    -- player toast
    if senderID then
        BJCTx.player.toast(senderID, BJC_TOAST_TYPES.ERROR, key, data)
    end
end

local ctrls = {}
-- route events categories to controller files
for k, v in pairs(BJC_EVENTS) do
    if type(v) == "table" and type(v.RX) == "table" and table.length(v.RX) > 0 then
        ctrls[k] = require("rx/" .. k .. "Rx")
        ctrls[k].dispatchEvent = controllerDispatch
    end
end

---@type table<string, {senderID: integer, created: integer, parts?: integer, controller?: string, endpoint?: string, data?: table}>
local _queue = Table()
local function finalizeCommunication(id)
    local event = _queue[id]
    if event and event.parts and event.parts == #event.data then
        local rawData = table.join(event.data)
        rawData = #rawData > 0 and JSON.parse(rawData) or {}
        local ctxt = {
            senderID = event.senderID,
            sender = BJCPlayers.Players[event.senderID] or {},
            event = event.controller,
            endpoint = event.endpoint,
            data = rawData,
        }
        BJCInitContext(ctxt)

        local ctrl
        for e, controller in pairs(ctrls) do
            if type(BJC_EVENTS[e]) == "table" and
                BJC_EVENTS[e].EVENT == ctxt.event then
                ctrl = controller
                break
            end
        end
        if ctrl then
            if BJCCore.Data.General.Debug then
                Log(BJCLang.getConsoleMessage("rx.eventReceived")
                    :var({
                        eventName = ctxt.event,
                        endpoint = ctxt.endpoint,
                        playerName = ctxt.sender.playerName,
                    }),
                    logTag)
                if table.length(ctxt.data) > 0 then
                    PrintObj(ctxt.data, string.var("{1}.{2} ({3} parts data)",
                        { ctxt.event, ctxt.endpoint, event.parts }))
                end
            end

            local _, err = pcall(ctrl.dispatchEvent, ctrl, ctxt)
            if err then
                if type(err) ~= "table" then
                    PrintObj(err, "Error Detail")
                end
                err = type(err) == "table" and err or {}
                logAndToastError(ctxt.sender, err.key, err.data)
            end
        else
            logAndToastError(ctxt.sender, "rx.errors.invalidEvent", { eventName = ctxt.event })
        end
        _queue[id] = nil
    end
end

function _BJCRxEvent(senderID, dataSent)
    local data = JSON.parse(dataSent)
    local ok, err = pcall(checkSenderAndData, senderID, data)
    if not ok then
        logAndToastError(BJCPlayers.Players[senderID] and senderID, err.key, err.data)
        return
    end

    if _queue[data.id] then
        table.assign(_queue[data.id], {
            senderID = senderID,
            parts = data.parts,
            controller = data.controller,
            endpoint = data.endpoint,
        })
    else
        _queue[data.id] = {
            senderID = senderID,
            created = GetCurrentTime(),
            parts = data.parts,
            controller = data.controller,
            endpoint = data.endpoint,
            data = Table(),
        }
    end
end

function _BJCRxEventParts(senderID, dataSent)
    local data = JSON.parse(dataSent)
    local ok, err = pcall(checkSenderAndData, senderID, data)
    if not ok then
        logAndToastError(BJCPlayers.Players[senderID] and senderID, err.key, err.data)
        return
    end

    if _queue[data.id] then
        _queue[data.id].data = table.assign(_queue[data.id].data or {}, {
            [data.part] = data.data
        })
    else
        _queue[data.id] = {
            senderID = senderID,
            created = GetCurrentTime(),
            data = Table({ [data.part] = data.data })
        }
    end
end

BJCEvents.addListener(BJCEvents.EVENTS.FAST_TICK, function(time)
    _queue:forEach(function(el, id)
        if el.parts and el.parts == #el.data then
            finalizeCommunication(id)
        elseif el.created + 30 < time then
            LogError(string.var("Communication timed out : {1} - {2}.{3}", { el.senderID, el.controller, el.endpoint }),
                logTag)
            _queue[id] = nil
        end
    end)
end)

MP.RegisterEvent(BJC_EVENTS.SERVER_EVENT, "_BJCRxEvent")
MP.RegisterEvent(BJC_EVENTS.SERVER_EVENT_PARTS, "_BJCRxEventParts")
