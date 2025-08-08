-- this file is placed in root folder to reduce its path length in the game console

function LogInfo(msg, tag)
    log("I", tag or "", tostring(msg))
end

function LogWarn(msg, tag)
    log("W", tag or "", tostring(msg))
end

function LogError(msg, tag)
    log("E", tag or "", tostring(msg))
end

function LogDebug(msg, tag)
    if BJI and BJI.DEBUG then
        log("D", tag or "", tostring(msg))
    end
end
