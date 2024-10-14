local event = BJI_EVENTS.DATABASE

BJITx.database = {}

function BJITx.database.Vehicle(modelName, state)
    BJITx._send(event.EVENT, event.TX.VEHICLE, { modelName, state })
end
