local M = {
    COMMAND_CHAR = "/",
    commands = {},
}

local function findCommand(sender, cmd, excludedCmds)
    local found
    for _, command in ipairs(M.commands) do
        if not table.includes(excludedCmds or {}, command.cmd) and (
                command.cmd == cmd or
                table.includes(command.aliases, cmd) -- command match or alias
            ) then
            if #command.permissions > 0 then          -- check permission
                local hasPerm = false
                for _, permission in ipairs(command.permissions) do
                    if BJCPerm.hasPermission(sender.playerID, permission) then
                        hasPerm = true
                        break
                    end
                end
                if hasPerm then
                    found = command
                    break
                end
            else
                found = command
                break
            end
        end
    end
    return found
end

local function printInvalidCommand(sender, cmd)
    BJCTx.player.chat(sender.playerID, BJCChat.EVENTS.SERVER_CHAT, {
        message = string.var("{1} : {2}", {
            BJCLang.getServerMessage(sender.lang, "commands.invalidCommand"),
            M.COMMAND_CHAR .. cmd,
        }),
        color = { 1, 0, 0, 1 },
    })
end

local function getAliasesLine(sender, aliases)
    if #aliases > 0 then
        aliases = M.COMMAND_CHAR .. table.join(aliases, string.var(", {1}", { M.COMMAND_CHAR }))
        return string.var(
            "{1} : {2}",
            {
                BJCLang.getServerMessage(sender.lang, "commands.aliases"),
                aliases,
            }
        )
    end
end

local function printUsage(sender, command)
    local args = BJCLang.getServerMessage(sender.lang, string.var("commands.{1}Args", { command.cmd }))
    args = #args > 0 and string.var(" {1}", { args }) or ""
    local desc = BJCLang.getServerMessage(sender.lang, string.var("commands.{1}Desc", { command.cmd }))
    local messages = {
        string.var("{1} : {2}{3}{4} : {5}", {
            BJCLang.getServerMessage(sender.lang, "commands.usage"),
            M.COMMAND_CHAR,
            command.cmd,
            args,
            desc,
        })
    }
    local aliases = getAliasesLine(sender, command.aliases)
    if aliases then
        table.insert(messages, aliases)
    end
    for _, msg in ipairs(messages) do
        BJCTx.player.chat(sender.playerID, BJCChat.EVENTS.SERVER_CHAT, {
            message = msg,
            color = { .2, 1, .2, 1 },
        })
    end
end

local function help(sender, argsStr)
    -- check if specific command help requested
    local cmd
    if #argsStr > 0 then
        cmd = string.split(argsStr, " ")[1]
        local found = findCommand(sender, cmd, { "help" })
        if found then
            printUsage(sender, found)
            return
        end
    end

    -- otherwise print help message
    local messages = { string.var("{1} :", { BJCLang.getServerMessage(sender.lang, "commands.title") }) }
    for _, command in ipairs(M.commands) do
        local hasPerm = false
        if #command.permissions == 0 then
            hasPerm = true
        else
            for _, permission in ipairs(command.permissions) do
                if BJCPerm.hasPermission(sender.playerID, permission) then
                    hasPerm = true
                    break
                end
            end
        end
        if hasPerm then
            local args = BJCLang.getServerMessage(sender.lang, string.var("commands.{1}Args", { command.cmd }))
            args = #args > 0 and string.var(" {1}", { args }) or ""
            local desc = BJCLang.getServerMessage(sender.lang, string.var("commands.{1}Desc", { command.cmd }))
            table.insert(messages, string.var(
                "{1}{2}{3} : {4}",
                {
                    M.COMMAND_CHAR, command.cmd, args, desc,
                }
            ))
            local aliases = getAliasesLine(sender, command.aliases)
            if aliases then
                table.insert(messages, aliases)
            end
        end
    end

    for _, msg in ipairs(messages) do
        BJCTx.player.chat(sender.playerID, BJCChat.EVENTS.SERVER_CHAT, {
            message = msg,
            color = { .2, 1, .2, 1 },
        })
    end
end

local function pm(sender, args)
    local target = string.split(args, " ")[1]
    local message = args:sub(#target + 2)

    -- exact target name
    for _, player in pairs(BJCPlayers.Players) do
        if player.playerID ~= sender.playerID and
            player.playerName == target then
            BJCTx.player.chat(player.playerID, BJCChat.EVENTS.DIRECT_MESSAGE, {
                playerName = sender.playerName,
                message = message,
            })
            return
        end
    end

    -- partial target name
    local founds = {}
    for _, player in pairs(BJCPlayers.Players) do
        if player.playerID ~= sender.playerID and
            player.playerName:lower():find(target:lower()) then
            table.insert(founds, player)
        end
    end

    if #founds == 0 then -- no target
        BJCTx.player.chat(sender.playerID, BJCChat.EVENTS.SERVER_CHAT, {
            message = BJCLang.getServerMessage(sender.lang, "rx.errors.invalidPlayer"):var({
                playerName = target,
            })
        })
    elseif #founds > 1 then -- too many targets
        local list = {}
        for _, player in pairs(founds) do
            table.insert(list, player.playerName)
        end
        BJCTx.player.chat(sender.playerID, BJCChat.EVENTS.SERVER_CHAT, {
            message = BJCLang.getServerMessage(sender.lang, "rx.errors.playerAmbiguity"):var({
                playerList = table.join(list, ", "),
            })
        })
    else -- target found
        target = founds[1]
        table.insert(sender.messages, {
            time = GetCurrentTime(),
            message = string.var("mp {1} : {2}", { target.playerName, message }),
        })
        Log(string.var("OnChatPrivateMessage - {1} -> {2} : {3}", { sender.playerName, target.playerName, message }),
            "BJCChat")
        BJCTx.player.chat(target.playerID, BJCChat.EVENTS.DIRECT_MESSAGE, {
            playerName = sender.playerName,
            message = message,
            color = { .6, .6, .6, 1 },
        })
        BJCTx.player.chat(sender.playerID, BJCChat.EVENTS.DIRECT_MESSAGE_SENT, {
            playerName = target.playerName,
            message = message,
            color = { .6, .6, .6, 1 },
        })

        -- staff players copy
        for _, player in pairs(BJCPlayers.Players) do
            if not table.includes({ sender.playerID, target.playerID }, player.playerID) and
                BJCPerm.isStaff(player.playerID) then
                BJCTx.player.chat(player.playerID, BJCChat.EVENTS.SERVER_CHAT, {
                    message = string.var("{1} -> {2}: {3}", { sender.playerName, target.playerName, message }),
                })
            end
        end
    end
end

local function handle(sender, commandStr)
    if #commandStr == 0 then
        return -- empty command
    end

    local cmd = string.split(commandStr, " ")[1]:lower()
    local found = findCommand(sender, cmd)
    if not found then
        printInvalidCommand(sender, cmd)
        return
    end

    local args = commandStr:sub(#cmd + 2)
    if type(found.validate) == "function" and
        not found.validate(sender, args) then
        printUsage(sender, found)
        return
    end

    found.exec(sender, args)
end

M.handle = handle

local function onInit()
    table.insert(M.commands, {
        cmd = "help",
        aliases = { "?", "commands" },
        permissions = {},
        validate = function(sender, args) return true end,
        exec = help,
    })
    table.insert(M.commands, {
        cmd = "pm",
        aliases = { "mp", "whisper", "msg", "message" },
        permissions = { BJCPerm.PERMISSIONS.SEND_PRIVATE_MESSAGE },
        validate = function(sender, args)
            return #string.split(args, " ") >= 2
        end,
        exec = pm,
    })
end
onInit()

return M
