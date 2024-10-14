local event = BJI_EVENTS.VOTEKICK

BJITx.votekick = {}

function BJITx.votekick.start(targetID)
    BJITx._send(event.EVENT, event.TX.START, targetID)
end

function BJITx.votekick.vote()
    BJITx._send(event.EVENT, event.TX.VOTE)
end

function BJITx.votekick.stop()
    BJITx._send(event.EVENT, event.TX.STOP)
end