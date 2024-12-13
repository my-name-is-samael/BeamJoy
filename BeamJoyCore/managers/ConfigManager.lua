local M = {
    Data = {},
    ClientMods = nil,
}

local function init()
    M.Data = BJCDefaults.config()
    tdeepassign(M.Data, BJCDao.config.findAll())

    if not M.ClientMods then
        local folder = BJCPluginPath:gsub("Server/BeamJoyCore", "Client")
        M.ClientMods = {}
        for _, filename in pairs(FS.ListFiles(folder)) do
            if filename:find(".zip") and not filename:find("/") then
                table.insert(M.ClientMods, filename)
            end
        end
    end
end

local function getCache(senderID)
    local data = {}

    data.CEN = {
        Console = M.Data.CEN.Console,
        Editor = M.Data.CEN.Editor,
        NodeGrabber = M.Data.CEN.NodeGrabber,
    }

    if BJCPerm.canSpawnVehicle(senderID) then
        data.Freeroam = {
            AllowUnicycle = M.Data.Freeroam.AllowUnicycle,
            ResetDelay = M.Data.Freeroam.ResetDelay,
            TeleportDelay = M.Data.Freeroam.TeleportDelay,
            QuickTravel = M.Data.Freeroam.QuickTravel,
            Nametags = M.Data.Freeroam.Nametags,
            DriftGood = M.Data.Freeroam.DriftGood,
            DriftBig = M.Data.Freeroam.DriftBig,
            PreserveEnergy = M.Data.Freeroam.PreserveEnergy,
            EmergencyRefuelDuration = M.Data.Freeroam.EmergencyRefuelDuration,
            EmergencyRefuelPercent = M.Data.Freeroam.EmergencyRefuelPercent,
        }
    end

    if BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.TEMP_BAN) or
        BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.BAN) then
        data.TempBan = {
            minTime = M.Data.TempBan.minTime,
            maxTime = M.Data.TempBan.maxTime,
        }
    end

    if BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.WHITELIST) then
        data.Whitelist = {
            Enabled = M.Data.Whitelist.Enabled,
            PlayerNames = M.Data.Whitelist.PlayerNames,
        }
    end

    if BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG) then
        data.VoteKick = {
            Timeout = M.Data.VoteKick.Timeout,
            ThresholdRatio = M.Data.VoteKick.ThresholdRatio,
        }

        data.VoteMap = {
            Timeout = M.Data.VoteMap.Timeout,
            ThresholdRatio = M.Data.VoteMap.ThresholdRatio,
        }

        if not data.Freeroam then
            data.Freeroam = {}
        end
        data.Freeroam.VehicleSpawning = M.Data.Freeroam.VehicleSpawning

        data.Reputation = {}
        for k, v in pairs(M.Data.Reputation) do
            data.Reputation[k] = v
        end
    end

    data.Server = {
        AllowClientMods = M.Data.Server.AllowClientMods,
        ClientMods = M.ClientMods,
        Theme = tdeepcopy(M.Data.Server.Theme),
    }
    if BJCPerm.hasMinimumGroup(senderID, BJCGroups.GROUPS.OWNER) then
        data.Server.Lang = M.Data.Server.Lang
        data.Server.DriftBigBroadcast = M.Data.Server.DriftBigBroadcast
        data.Server.Broadcasts = M.Data.Server.Broadcasts
        data.Server.WelcomeMessage = M.Data.Server.WelcomeMessage
    end

    if BJCPerm.canSpawnVehicle(senderID) then
        data.Race = {
            FinishTimeout = M.Data.Race.FinishTimeout,
        }
    end

    if BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        if not data.Race then
            data.Race = {}
        end
        data.Race.VoteThresholdRatio = M.Data.Race.VoteThresholdRatio
        data.Race.PreparationTimeout = M.Data.Race.PreparationTimeout
        data.Race.VoteTimeout = M.Data.Race.VoteTimeout
        data.Race.VoteThresholdRatio = M.Data.Race.VoteThresholdRatio
        data.Race.GridReadyTimeout = M.Data.Race.GridReadyTimeout
        data.Race.GridTimeout = M.Data.Race.GridTimeout
        data.Race.RaceCountdown = M.Data.Race.RaceCountdown
        data.Race.FinishTimeout = M.Data.Race.FinishTimeout
        data.Race.RaceEndTimeout = M.Data.Race.RaceEndTimeout
        data.Race.RaceSoloTimeBroadcast = M.Data.Race.RaceSoloTimeBroadcast

        data.Speed = {
            PreparationTimeout = M.Data.Speed.PreparationTimeout,
            VoteTimeout = M.Data.Speed.VoteTimeout,
            BaseSpeed = M.Data.Speed.BaseSpeed,
            StepSpeed = M.Data.Speed.StepSpeed,
            StepDelay = M.Data.Speed.StepDelay,
            EndTimeout = M.Data.Speed.EndTimeout,
        }

        data.Hunter = {
            PreparationTimeout = M.Data.Hunter.PreparationTimeout,
            HuntedStartDelay = M.Data.Hunter.HuntedStartDelay,
            HuntersStartDelay = M.Data.Hunter.HuntersStartDelay,
            HuntedStuckTimeout = M.Data.Hunter.HuntedStuckTimeout,
            HuntersRespawnDelay = M.Data.Hunter.HuntersRespawnDelay,
        }
    end

    if BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) or
        BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        data.VehicleDelivery = {
            ModelBlacklist = M.Data.VehicleDelivery.ModelBlacklist
        }
    end

    return data, M.getCacheHash()
end

local function getCacheHash()
    return Hash(M.Data)
end

local function hasPermissionByParentAndKey(senderID, parent, key)
    if parent == "VoteKick" then
        if tincludes({ "Timeout", "ThresholdRatio" }, key) then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG)
        end
    elseif parent == "VoteMap" then
        if tincludes({ "Timeout", "ThresholdRatio" }, key) then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG)
        end
    elseif parent == "Freeroam" then
        if tincludes({ "VehicleSpawning", "VehicleReset", "QuickTravel", "AllowUnicycle" }, key) then
            return BJCPerm.hasMinimumGroup(senderID, BJCGroups.GROUPS.ADMIN)
        elseif tincludes({ "ResetDelay", "TeleportDelay", "PreserveEnergy", "DriftGood",
                "DriftBig", "Nametags", "EmergencyRefuelDuration", "EmergencyRefuelPercent" }, key) then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG)
        end
    elseif parent == "Reputation" then
        return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG)
    elseif parent == "TempBan" then
        if tincludes({ "minTime", "maxTime" }, key) then
            return BJCPerm.hasMinimumGroup(senderID, BJCGroups.GROUPS.ADMIN)
        end
    elseif parent == "Whitelist" then
        if key == "PlayerNames" then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.WHITELIST)
        elseif key == "Enabled" then
            return BJCPerm.hasMinimumGroup(senderID, BJCGroups.GROUPS.ADMIN)
        end
    elseif parent == "CEN" then
        return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CEN)
    elseif tincludes({ "Race", "Speed", "Hunter", "Derby", "VehicleDelivery" }, parent, true) then
        return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SCENARIO)
    elseif parent == "Server" then
        if tincludes({ "Lang", "AllowClientMods", "Theme" }, key, true) then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CORE)
        elseif tincludes({ "DriftBigBroadcast", "Broadcasts", "WelcomeMessage" }, key) then
            return BJCPerm.hasMinimumGroup(senderID, BJCGroups.GROUPS.OWNER)
        end
    end
    error({ key = "rx.errors.invalidKey", data = { key = key } })
end

local function clampValue(parent, key, value)
    if parent == "VoteKick" then
        if key == "Timeout" then
            return Clamp(value, 5, 300)
        elseif key == "ThresholdRatio" then
            return Clamp(value, 0.01, 1)
        end
    elseif parent == "MapVote" then
        if key == "Timeout" then
            return Clamp(value, 5, 300)
        elseif key == "ThresholdRatio" then
            return Clamp(value, 0.01, 1)
        end
    elseif parent == "Freeroam" then
        if tincludes({ "ResetDelay", "TeleportDelay" }, key) then
            return Clamp(value, 0)
        elseif key == "EmergencyRefuelDuration" then
            return Clamp(value, 5, 60)
        elseif key == "EmergencyRefuelPercent" then
            return Clamp(value, 5, 100)
        end
    elseif parent == "TempBan" then
        if key == "minTime" then
            return math.max(0, math.min(M.Data.TempBan.maxTime, value))
        elseif key == "maxTime" then
            return Clamp(value, M.Data.TempBan.minTime or 0)
        end
    elseif parent == "Race" then
        if tincludes({ "PreparationTimeout", "FinishTimeout", "RaceEndTimeout", "GridReadyTimeout" }, key) then
            return Clamp(value, 5)
        elseif tincludes({ "GridTimeout", "RaceCountdown" }, key) then
            return Clamp(value, 10)
        elseif key == "VoteThresholdRatio" then
            return Clamp(value, 0.01, 1)
        end
    end
    return value
end

local function set(ctxt, key, value)
    local parent = nil
    local keyParts = ssplit(key, ".")
    if #keyParts ~= 2 then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    else
        parent = keyParts[1]
        key = keyParts[2]
    end

    local target = M.Data[parent][key]
    if target == nil then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    end

    if ctxt.origin == "player" and not hasPermissionByParentAndKey(ctxt.senderID, parent, key) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    if value ~= nil then
        value = clampValue(parent, key, value)
    else
        -- if nil then default value
        value = BJCDefaults.config()[parent][key]
    end

    if type(target) ~= type(value) then
        error({ key = "rx.errors.invalidValue", data = { value = value } })
    elseif not parent and key == "Lang" and not tincludes(BJCLang.getLangsList(), value) then
        error({ key = "rx.errors.invalidValue", data = { value = value } })
    end

    M.Data[parent][key] = value
    BJCDao.config.save(parent, key, value)

    if BJCTx then
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.BJC)
    end
end

local function consoleSetWhitelist(args)
    local ctxt = {}
    BJCInitContext(ctxt)
    if #args == 0 then -- print whitelist status
        return svar("{1}\n{2}", {
            svar(BJCLang.getConsoleMessage("command.showWhitelistState"),
                {
                    state = BJCLang.getConsoleMessage(svar("common.{1}", {
                        M.Data.Whitelist.Enabled and "enabled" or "disabled"
                    }))
                }),
            svar(BJCLang.getConsoleMessage("command.showWhitelistedPlayers"),
                {
                    playerList = #M.Data.Whitelist.PlayerNames > 0 and
                        tconcat(M.Data.Whitelist.PlayerNames, ", ") or
                        BJCLang.getConsoleMessage("common.empty")
                }),
        })
    elseif args[1] == "set" then                                                 -- set whitelist status
        if not args[2] or not tincludes({ "true", "false" }, args[2], true) then -- invalid arg
            return svar("{1}whitelist set {2}", {
                BJCCommand.commandPrefix,
                BJCLang.getConsoleMessage("command.help.whitelistSetArgs")
            })
        else -- change whitelist state
            local newState = args[2] == "true"
            M.set(ctxt, "Whitelist.Enabled", newState)
            BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.BJC, BJCPerm.PERMISSIONS.WHITELIST)
            return svar(BJCLang.getConsoleMessage("command.newWhitelistState"), { state = newState })
        end
    elseif args[1] == "add" then             -- add player to whitelist
        if not args[2] or args[2] == "" then -- invalid arg
            return svar("{1}whitelist add {2}", {
                BJCCommand.commandPrefix,
                BJCLang.getConsoleMessage("command.help.whitelistAddRemoveArgs")
            })
        elseif tincludes(M.Data.Whitelist.PlayerNames, args[2], true) then -- already whitelisted
            return svar(BJCLang.getConsoleMessage("command.alreadyWhitelistedPlayer"), { playerName = args[2] })
        else                                                               -- proceed
            BJCPlayers.whitelist(ctxt, args[2])
            return svar(BJCLang.getConsoleMessage("command.whitelistAddedPlayer"), { playerName = args[2] })
        end
    elseif args[1] == "remove" then -- remove player from whitelist
        if not args[2] then         -- invalid arg
            return svar("{1}whitelist remove {2}", {
                BJCCommand.commandPrefix,
                BJCLang.getConsoleMessage("command.help.whitelistAddRemoveArgs")
            })
        else -- valid arg
            local matches = {}
            local list = tdeepcopy(M.Data.Whitelist.PlayerNames)
            for i, pname in ipairs(list) do -- find matches
                if pname == args[2] then    -- exact match
                    matches = { pos = i, playerName = args[2] }
                    break
                elseif pname:lower():find(args[2]:lower()) then -- approximate match
                    table.insert(matches, { pos = i, playerName = pname })
                end
            end
            if #matches == 0 then    -- not whitelisted
                return svar(BJCLang.getConsoleMessage("command.notWhitelistedPlayer"), { playerName = args[2] })
            elseif #matches > 1 then -- ambiguity
                local playerList = {}
                for _, m in ipairs(matches) do
                    table.insert(playerList, m.playerName)
                end
                table.sort(playerList)
                return svar(BJCLang.getConsoleMessage("command.errors.playerAmbiguity"),
                    { playerName = args[2], playerList = tconcat(playerList, ", ") })
            else -- proceed
                BJCPlayers.whitelist(ctxt, matches[1].playerName)
                return svar(BJCLang.getConsoleMessage("command.whitelistRemovedPlayer"),
                    { playerName = matches[1].playerName })
            end
        end
    else -- invalid args
        return svar(BJCLang.getConsoleMessage("command.errors.usage"),
            {
                command = svar(
                    "{1}whitelist {2}",
                    { BJCCommand.commandPrefix, BJCLang.getConsoleMessage("command.help.whitelistArgs") }
                )
            })
    end
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.set = set
M.consoleSetWhitelist = consoleSetWhitelist

init()

return M
