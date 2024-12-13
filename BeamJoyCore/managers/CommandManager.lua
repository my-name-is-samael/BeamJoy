local logTag = "BJCCommands"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.LIGHT_RED)

local M = {
    commandPrefix = "bj ",
    COMMANDS = {}
}

function M.addCommand(cmd, fnName)
    if not cmd or not fnName or cmd:find(" ") then
        LogError(BJCLang.getConsoleMessage("errors.invalidCommandData"), logTag)
        return
    end

    table.insert(M.COMMANDS, {
        cmd = cmd,
        fnName = fnName
    })
end

local function _printHelp()
    local out = BJCLang.getConsoleMessage("command.help.title")
    local cmdLen = 0
    local helpContent = {}
    for _, v in ipairs(M.COMMANDS) do
        local commandStr = svar("{1}{2} {3}",
            { M.commandPrefix, v.cmd, BJCLang.getConsoleMessage(svar("command.help.{1}Args", { v.cmd })) })
        local commandDesc = BJCLang.getConsoleMessage(svar("command.help.{1}Description", { v.cmd }))
        if #commandStr > cmdLen then
            cmdLen = #commandStr
        end
        table.insert(helpContent, {
            command = commandStr,
            description = commandDesc,
        })
    end
    for _, v in ipairs(helpContent) do
        out = svar("{1}\n\t{2} {3}", { out, snormalize(v.command, cmdLen), v.description })
    end
    return out
end

function _OnConsoleInput(message)
    if message == "help" then
        return _printHelp()
    end

    local prefixLen = M.commandPrefix:len()
    if message:sub(1, prefixLen) ~= M.commandPrefix then
        -- not bj command
        return nil
    end
    message = message:sub(prefixLen + 1)

    local command, args = message, nil
    local s, e = message:find(" ")
    if s then
        command = message:sub(1, s - 1)
        args = message:sub(s + 1)
    end
    if not args or type(args) ~= "string" then
        args = {}
    else
        while args:find("  ") do
            args = args:gsub("  ", " ")
        end
        args = strim(args)
        if args:find(" ") then
            args = ssplit(args, " ")
        else
            args = { args }
        end
    end

    local cmd
    for _, v in ipairs(M.COMMANDS) do
        if v.cmd == command then
            cmd = v
        end
    end
    if not cmd then
        return svar(BJCLang.getConsoleMessage("command.errors.invalidCommand"), { command = command })
    end

    -- allow calling subfunctions like "BJCPlayerManager.onConsoleSetGroup(args)"
    local fn = GetSubobject(cmd.fnName)
    if fn then
        return fn(args) or BJCLang.getConsoleMessage("command.defaultReturn")
    else
        return svar(BJCLang.getConsoleMessage("command.errors.invalidFunctionName"), { functionName = cmd.fnName })
    end
end

local function _init()
    MP.RegisterEvent("onConsoleInput", "_OnConsoleInput")

    -- Registering Console Commands
    M.addCommand("map", "BJCCore.consoleSetMap")
    M.addCommand("setenv", "BJCEnvironment.consoleSet")
    M.addCommand("whitelist", "BJCConfig.consoleSetWhitelist")

    M.addCommand("setgroup", "BJCPlayers.consoleSetGroup")
    M.addCommand("kick", "BJCPlayers.consoleKick")
    M.addCommand("ban", "BJCPlayers.consoleBan")
    M.addCommand("tempban", "BJCPlayers.consoleTempBan")
    M.addCommand("unban", "BJCPlayers.consoleUnban")
    M.addCommand("mute", "BJCPlayers.consoleMute")
    M.addCommand("unmute", "BJCPlayers.consoleUnmute")

    M.addCommand("stop", "BJCCore.stop")
end
_init()

return M
