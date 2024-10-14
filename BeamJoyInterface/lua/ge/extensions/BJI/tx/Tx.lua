local _encode = jsonEncode
local _Trigger = TriggerServerEvent

local tag = "BJITX"

BJITx = {
    PAYLOAD_LIMIT_SIZE = 20000,
}

function BJITx._send(controller, endpoint, data)
    local logData = BJIContext.DEBUG and data ~= nil
    if type(data) ~= "table" then
        data = { data }
    end

    local id = UUID()
    local parts = {}
    local payload = _encode(data)
    while #payload > 0 do
        table.insert(parts, payload:sub(1, BJITx.PAYLOAD_LIMIT_SIZE))
        payload = payload:sub(BJITx.PAYLOAD_LIMIT_SIZE + 1)
    end

    _Trigger(BJI_EVENTS.SERVER_EVENT, _encode({
        id = id,
        parts = #parts,
        controller = controller,
        endpoint = endpoint,
    }))
    for i, p in ipairs(parts) do
        _Trigger(BJI_EVENTS.SERVER_EVENT_PARTS, _encode({
            id = id,
            part = i,
            data = p,
        }))
    end

    LogDebug(svar("Event {1}.{2} sent ({3} parts data)", { controller, endpoint, #parts }), tag)
    if logData then
        PrintObj(data, endpoint)
    end
end

require("ge/extensions/BJI/tx/CacheTx")
require("ge/extensions/BJI/tx/PlayerTx")
require("ge/extensions/BJI/tx/ModerationTx")
require("ge/extensions/BJI/tx/ConfigTx")
require("ge/extensions/BJI/tx/DatabaseTx")
require("ge/extensions/BJI/tx/VoteKickTx")
require("ge/extensions/BJI/tx/VoteMapTx")
require("ge/extensions/BJI/tx/VoteRaceTx")
require("ge/extensions/BJI/tx/ScenarioTx")

RegisterBJIManager(BJITx)
