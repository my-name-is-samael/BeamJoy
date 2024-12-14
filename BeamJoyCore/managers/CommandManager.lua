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

local function Help()
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

local function Say(message)
    if #message == 0 then
        return svar(BJCLang.getConsoleMessage("command.errors.usage"), {
            command = "say <message>",
        })
    else
        BJCChat.onServerChat(BJCTx.ALL_PLAYERS, svar("SERVER : {1}", { message }), { 1, .33, 1, 1 })
    end
end

local function List()
    local function getReputationLevelAmount(level) -- from client ReputationManager.lua:getReputationLevelAmount
        return (20 * (level ^ 2)) - (40 * level) + 20
    end
    local function getReputationLevel(reputation) -- from client ReputationManager.lua:getReputationLevel
        local level = 1
        while getReputationLevelAmount(level + 1) < reputation do
            level = level + 1
        end
        return level
    end

    for _, p in pairs(BJCPlayers.Players) do
        local vehicles = {}
        for _, v in pairs(p.vehicles) do
            table.insert(vehicles, { id = v.vehicleID, name = v.name, current = p.currentVehicle == v.vid })
        end
        table.sort(vehicles, function(a, b) return a.id < b.id end)
        local out = svar("{id} - [{group}|{level}] {name} ({lang} | {muted} | {traffic}) -", {
            id = p.playerID,
            group = p.group,
            level = getReputationLevel(p.reputation),
            name = p.playerName,
            lang = p.lang:upper(),
            muted = p.muted and
                svar("Muted because : {1}", {
                    (p.muteReason and #p.muteReason > 0) and p.muteReason or "No reason"
                }) or "Not muted",
            traffic = #p.ai > 0 and svar("{1} traffics", { #p.ai }) or "No traffic",
        })
        if #vehicles == 0 then
            out = svar("{1} No vehicle", { out })
        else
            out = svar("{1} {2} vehicle{3} (", { out, #vehicles, #vehicles > 1 and "s" or "" })
            for i, v in ipairs(vehicles) do
                out = svar("{out}{spacer}{id} - {name}", {
                    out = out,
                    spacer = i == 1 and "" or " | ",
                    id = v.id,
                    name = v.name,
                })
            end
            out = svar("{1})", { out })
        end
        Log(out)
    end
end

local function Settings(args)
    local settings = {}
    for parentK, parentV in pairs(BJCCore.Data) do
        for childK, childV in pairs(parentV) do
            local key = svar("{1}.{2}", { parentK, childK })
            if not tincludes({ "General.AuthKey", "General.ResourceFolder" }, key, true) then
                table.insert(settings, {
                    key = key,
                    value = childV
                })
            end
        end
    end
    table.sort(settings, function(a, b) return a.key < b.key end)

    if #args == 0 then -- print all settings
        local out = "Settings :"
        for _, s in ipairs(settings) do
            out = svar("{1}\n    {2} = {3}", { out, s.key, s.value })
        end
        return out
    end

    -- print or assign specific setting
    local found = false
    for _, s in ipairs(settings) do
        if s.key == args[1] then
            found = true
            break
        end
    end
    if not found then -- invalid setting key
        local list = {}
        for _, s in ipairs(settings) do
            table.insert(list, s.key)
        end
        return svar(BJCLang.getConsoleMessage("command.errors.usage"), {
            command = svar("settings [<setting> [value]], available settings : {1}", {
                tconcat(list, ", ")
            })
        })
    end

    local currentValue = GetSubobject(svar("BJCCore.Data.{1}", { args[1] }))
    if not args[2] then -- print current setting value
        return svar("{1} = {2}", { args[1], currentValue })
    end

    -- assign new setting value
    local newValue
    newValue = args[2] or ""
    for i = 3, #args do
        newValue = svar("{1} {2}", { newValue, args[i] })
    end

    local fieldType = "string"
    if tincludes({ "true", "false" }, currentValue, true) then
        fieldType = "boolean"
        if tincludes({ "true", "false" }, newValue, true) == newValue then
            newValue = newValue == "true"
        end
    elseif tonumber(currentValue) then
        fieldType = "number"
        newValue = tonumber(newValue)
    end

    if type(newValue) ~= fieldType then -- invalid data type
        return "Invalid setting type"
    end

    local status, err = pcall(BJCCore.consoleSet, args[1], newValue)
    if status then
        return svar("{1} = {2}", { args[1], newValue })
    elseif err then
        return svar(BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key), err.data or {})
    end
end

local function overrideDefaultCommands(message)
    local args = ssplit(message, " ")
    local nextArgs = {}
    for i = 2, #args do
        table.insert(nextArgs, args[i])
    end
    if args[1] == "help" then
        return Help()
    elseif args[1] == "say" then
        return Say(tconcat(nextArgs, " "))
    elseif args[1] == "list" then
        return List()
    elseif args[1] == "settings" then
        return Settings(nextArgs)
    end
end

function _OnConsoleInput(message)
    if message:sub(1, #M.commandPrefix) ~= M.commandPrefix then
        -- not bj command
        return overrideDefaultCommands(message)
    end
    message = message:sub(#M.commandPrefix + 1)

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
