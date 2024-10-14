local logTag = "BJCCommands"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.LIGHT_RED)

local M = {
    commandPrefix = "bj ",
    COMMANDS = {}
}

function M.addCommand(cmd, helpCmd, helpDescription, fnName)
    if not cmd or not fnName or cmd:find(" ") then
        LogError(BJCLang.getConsoleMessage("errors.invalidCommandData"), logTag)
        return
    end

    M.COMMANDS[#M.COMMANDS + 1] = {
        cmd = cmd,
        helpCmd = helpCmd,
        helpDescription = helpDescription,
        fnName = fnName
    }
end

M.addCommand("setgroup", "bj setgroup <player_name> [group_name]",
    BJCLang.getConsoleMessage("command.help.setgroup"), "BJCPlayers.consoleSetGroup")
M.addCommand("setenv", "bj setenv <env_key> [env_value]",
    BJCLang.getConsoleMessage("command.help.setenv"), "BJCEnvironment.consoleSet")
M.addCommand("whitelist", "bj whitelist [true|false]",
    BJCLang.getConsoleMessage("command.help.whitelist"), "BJCConfig.consoleWhitelist")

local function _printHelp()
    local out = "BeamJoy commands :"
    local cmdLen = 0
    for _, v in ipairs(M.COMMANDS) do
        if #v.helpCmd > cmdLen then
            cmdLen = #v.helpCmd
        end
    end
    for _, v in ipairs(M.COMMANDS) do
        out = svar("{1}\n\t{2} = {3}", { out, snormalize(v.helpCmd, cmdLen), v.helpDescription })
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
        return svar("ERROR Invalid command : \"{1}\"", { command })
    end

    -- allow calling subfunctions like "BJCPlayerManager.onConsoleSetGroup(args)"
    local fn = GetSubobject(cmd.fnName)
    if fn then
        return fn(args)
    else
        return svar(BJCLang.getConsoleMessage("command.errors.invalidFunctionName"), { functionName = cmd.fnName })
    end
end

function _StopServer(source)
    MP.TriggerGlobalEvent("onServerStop")

    Exit()
end

local function _init()
    MP.RegisterEvent("onConsoleInput", "_OnConsoleInput")

    MP.RegisterEvent("stop", "_StopServer")
end
_init()

return M
