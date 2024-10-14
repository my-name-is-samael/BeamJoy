local event = BJI_EVENTS.VOTERACE

BJITx.voterace = {}

function BJITx.voterace.start(raceID, isVote, settings)
    BJITx._send(event.EVENT, event.TX.START, { raceID, isVote, settings })
end

function BJITx.voterace.vote()
    BJITx._send(event.EVENT, event.TX.VOTE)
end

function BJITx.voterace.stop()
    BJITx._send(event.EVENT, event.TX.STOP)
end
