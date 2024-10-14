local event = BJI_EVENTS.VOTEMAP

BJITx.votemap = {}

function BJITx.votemap.start(mapName)
    BJITx._send(event.EVENT, event.TX.START, mapName)
end

function BJITx.votemap.vote()
    BJITx._send(event.EVENT, event.TX.VOTE)
end

function BJITx.votemap.stop()
    BJITx._send(event.EVENT, event.TX.STOP)
end