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
    elseif data.parts and not data.data then
        error({ key = "rx.errors.invalidData" })
    end
    local sender = BJCPlayers.Players[senderID]
    if not sender then
        error({ key = "rx.errors.senderIDInvalid", data = { senderID = senderID } })
    end
    return sender
end

local function logAndToastError(sender, key, data)
    key = key or "rx.errors.serverError"
    data = data or {}

    local srvLang = BJCConfig.Data.Server.Lang

    -- srv log
    LogError(svar(BJCLang.getServerMessage(srvLang, key), data), logTag)
    -- player toast
    if sender then
        BJCTx.player.toast(sender.playerID, BJC_TOAST_TYPES.ERROR, key, data)
    end
end

local ctrls = {}
-- route events categories to controller files
for k, v in pairs(BJC_EVENTS) do
    if type(v) == "table" and type(v.RX) == "table" and tlength(v.RX) > 0 then
        ctrls[k] = require("rx/" .. k .. "Rx")
        ctrls[k].dispatchEvent = controllerDispatch
    end
end

local retrievingEvents = {}
local function tryFinalizeEvent(id)
    local event = retrievingEvents[id]
    if event and BJCPlayers.Players[event.senderID] then
        if event.parts > #event.data or not event.controller then
            -- not ready yet
            return
        end

        local rawData = table.concat(event.data)
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
                Log(
                    svar(
                        BJCLang.getConsoleMessage("rx.eventReceived"),
                        {
                            eventName = ctxt.event,
                            endpoint = ctxt.endpoint,
                            playerName = ctxt.sender.playerName,
                        }),
                    logTag)
                if tlength(ctxt.data) > 0 then
                    PrintObj(ctxt.data, svar("{1}.{2} ({3} parts data)",
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
        BJCAsync.removeTask(svar("BJCRxEventTimeout-{1}", { id }))
    end

    retrievingEvents[id] = nil
end

function _BJCRxEvent(senderID, dataSent)
    local data = JSON.parse(dataSent)
    local _, sender, err = pcall(checkSenderAndData, senderID, data)
    if err then
        err = type(err) == "table" and err or {}
        logAndToastError(sender, err.key, err.data)
        return
    end

    local event = retrievingEvents[data.id]
    if event then
        event.senderID = senderID
        event.parts = data.parts
        event.controller = data.controller
        event.endpoint = data.endpoint
        if not event.data then
            event.data = {}
        end
    else
        retrievingEvents[data.id] = {
            senderID = senderID,
            parts = data.parts,
            controller = data.controller,
            endpoint = data.endpoint,
            data = {},
        }
    end
    if data.parts == 0 then
        tryFinalizeEvent(data.id)
    end
    if retrievingEvents[data.id] then
        BJCAsync.delayTask(function()
            retrievingEvents[data.id] = nil
        end, 30, svar("BJCRxEventTimeout-{1}", { data.id }))
    end
end

function _BJCRxEventParts(senderID, dataSent)
    local data = JSON.parse(dataSent)
    local _, sender, err = pcall(checkSenderAndData, senderID, data)
    if err then
        err = type(err) == "table" and err or {}
        logAndToastError(sender, err.key, err.data)
        return
    end

    local event = retrievingEvents[data.id]
    if event then
        if event.data then
            event.data[data.part] = data.data
        else
            event.data = { [data.part] = data.data }
        end
    else
        retrievingEvents[data.id] = {
            senderID = senderID,
            data = { [data.part] = data.data }
        }
    end
    tryFinalizeEvent(data.id)
    if retrievingEvents[data.id] then
        BJCAsync.delayTask(function()
            retrievingEvents[data.id] = nil
        end, 30, svar("BJCRxEventTimeout-{1}", { data.id }))
    end
end

MP.RegisterEvent(BJC_EVENTS.SERVER_EVENT, "_BJCRxEvent")
MP.RegisterEvent(BJC_EVENTS.SERVER_EVENT_PARTS, "_BJCRxEventParts")
