-- this file is placed in root folder to reduce its path length in the game console

function LogInfo(msg, tag)
    log("I", tag or "", msg)
end

function LogWarn(msg, tag)
    log("W", tag or "", msg)
end

function LogError(msg, tag)
    log("E", tag or "", msg)
end

function LogDebug(msg, tag)
    log("D", tag or "", msg)
end