local logTag = "BJCCommands"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.LIGHT_RED)

local M = {
    commandPrefix = "bj ",
    COMMANDS = {}
}

local function addCommand(cmd, fnName)
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
    ---@type {command: string, description: string}[]
    local helpContent = {}
    for _, v in ipairs(M.COMMANDS) do
        local commandStr = string.var("{1}{2} {3}",
            { M.commandPrefix, v.cmd, BJCLang.getConsoleMessage(string.var("command.help.{1}Args", { v.cmd })) })
        local commandDesc = BJCLang.getConsoleMessage(string.var("command.help.{1}Description", { v.cmd }))
        if #commandStr + 2 > cmdLen then
            cmdLen = #commandStr + 2
        end
        table.insert(helpContent, {
            command = commandStr,
            description = commandDesc,
        })
    end
    for _, v in ipairs(helpContent) do
        out = string.var("{1}\n\t{2} {3}", { out, v.command:normalize(cmdLen), v.description })
    end
    return out
end

local function Say(message)
    if #message == 0 then
        return BJCLang.getConsoleMessage("command.errors.usage"):var({
            command = "say <message>",
        })
    else
        BJCChat.onServerChat(BJCTx.ALL_PLAYERS, string.var("SERVER : {1}", { message }), { 1, .33, 1, 1 })
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
        local trafficCount = table.filter(p.vehicles, function(v) return v.isAi end):length()
        local out = string.var("{id} - [{group}|{level}] {name} ({lang} | {muted} | {traffic}) -", {
            id = p.playerID,
            group = p.group,
            level = getReputationLevel(p.reputation),
            name = p.playerName,
            lang = p.lang:upper(),
            muted = p.muted and
                string.var("Muted because : {1}", {
                    (p.muteReason and #p.muteReason > 0) and p.muteReason or "No reason"
                }) or "Not muted",
            traffic = trafficCount > 0 and string.var("{1} traffics", { trafficCount }) or "No traffic",
        })
        if #vehicles == 0 then
            out = string.var("{1} No vehicle", { out })
        else
            out = string.var("{1} {2} vehicle{3} (", { out, #vehicles, #vehicles > 1 and "s" or "" })
            for i, v in ipairs(vehicles) do
                out = string.var("{out}{spacer}{id} - {name}", {
                    out = out,
                    spacer = i == 1 and "" or " | ",
                    id = v.id,
                    name = v.name,
                })
            end
            out = string.var("{1})", { out })
        end
        Log(out)
    end
end

local function Settings(args)
    local settings = BJC_CORE_CONFIG:filter(function(k) return not k.prevent end):map(function(_, k)
        return {
            key = k,
            value = BJCCore.Data[k],
        }
    end):sort(function(a, b) return a.key < b.key end) or Table()

    if #args == 0 then -- print all settings
        return string.var("Settings :\n    {1}", {
            settings:map(function(el) return el.key .. " = " .. tostring(el.value) end):join("\n    ")
        })
    end

    -- print or assign specific setting
    if not settings:any(function(el) return el.key == args[1] end) then
        return BJCLang.getConsoleMessage("command.errors.usage"):var({
            command = string.var("settings [<setting> [value]], available settings : {1}", {
                settings:map(function(el) return el.key end):join(", ")
            })
        })
    end

    local currentValue = GetSubobject(string.var("BJCCore.Data.{1}", { args[1] }))
    if not args[2] then -- print current setting value
        return string.var("{1} = {2}", { args[1], currentValue })
    end

    -- assign new setting value
    local newValue
    newValue = args[2] or ""
    for i = 3, #args do
        newValue = string.var("{1} {2}", { newValue, args[i] })
    end

    local fieldType = "string"
    if table.includes({ "true", "false" }, currentValue) then
        fieldType = "boolean"
        if table.includes({ "true", "false" }, newValue) == newValue then
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
        return string.var("{1} = {2}", { args[1], newValue })
    elseif err then
        return BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key):var(err.data or {})
    end
end

local function overrideDefaultCommands(message)
    local args = message:split(" ")
    local nextArgs = {}
    for i = 2, #args do
        table.insert(nextArgs, args[i])
    end
    if args[1] == "help" then
        return Help()
    elseif args[1] == "say" then
        return Say(table.join(nextArgs, " "))
    elseif args[1] == "list" then
        return List()
    elseif args[1] == "settings" then
        return Settings(nextArgs)
    end
end

local function onConsoleInput(message)
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
        args = args:trim()
        if args:find(" ") then
            args = args:split(" ")
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
        return BJCLang.getConsoleMessage("command.errors.invalidCommand"):var({ command = command })
    end

    -- allow calling subfunctions like "BJCPlayerManager.onConsoleSetGroup(args)"
    local fn = GetSubobject(cmd.fnName)
    if fn then
        return fn(args) or BJCLang.getConsoleMessage("command.defaultReturn")
    else
        return BJCLang.getConsoleMessage("command.errors.invalidFunctionName"):var({ functionName = cmd.fnName })
    end
end

local function _init()
    BJCEvents.addListener(BJCEvents.EVENTS.MP_CONSOLE_INPUT, onConsoleInput, "CommandManager")

    -- Registering Console Commands
    M.addCommand("lang", "BJCCore.consoleSetLang")
    M.addCommand("map", "BJCCore.consoleSetMap")
    M.addCommand("env", "BJCEnvironment.consoleEnv")
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

M.addCommand = addCommand
_init()

return M
