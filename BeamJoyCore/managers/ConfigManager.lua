local M = {
    Data = {},
    ClientMods = nil,
}

local function sanitizeTheme(themeData)
    local removedFields = {
        { "Fields", "BUTTON" },
        { "Fields", "BUTTON_HOVERED" },
        { "Fields", "BUTTON_ACTIVE" },
        { "Fields", "TEXT_COLOR" },
    }
    local changed = false
    for _, path in ipairs(removedFields) do
        if themeData[path[1]] and themeData[path[1]][path[2]] then
            themeData[path[1]][path[2]] = nil
            changed = true
        end
    end
    return changed
end

local function init()
    M.Data = BJCDefaults.config()
    table.assign(M.Data, BJCDao.config.findAll())

    if sanitizeTheme(M.Data.Server.Theme) then
        BJCDao.config.save("Server", "Theme", M.Data.Server.Theme)
    end

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

    data.Freeroam = {
        Nametags = M.Data.Freeroam.Nametags,
    }
    if BJCPerm.canSpawnVehicle(senderID) then
        table.assign(data.Freeroam, {
            AllowUnicycle = M.Data.Freeroam.AllowUnicycle,
            ResetDelay = M.Data.Freeroam.ResetDelay,
            TeleportDelay = M.Data.Freeroam.TeleportDelay,
            QuickTravel = M.Data.Freeroam.QuickTravel,
            DriftGood = M.Data.Freeroam.DriftGood,
            DriftBig = M.Data.Freeroam.DriftBig,
            PreserveEnergy = M.Data.Freeroam.PreserveEnergy,
            EmergencyRefuelDuration = M.Data.Freeroam.EmergencyRefuelDuration,
            EmergencyRefuelPercent = M.Data.Freeroam.EmergencyRefuelPercent,
        })
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
        Theme = table.deepcopy(M.Data.Server.Theme),
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

        data.Derby = {
            PreparationTimeout = M.Data.Derby.PreparationTimeout,
            StartCountdown = M.Data.Derby.StartCountdown,
            DestroyedTimeout = M.Data.Derby.DestroyedTimeout
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
        if table.includes({ "Timeout", "ThresholdRatio" }, key) then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG)
        end
    elseif parent == "VoteMap" then
        if table.includes({ "Timeout", "ThresholdRatio" }, key) then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG)
        end
    elseif parent == "Freeroam" then
        if table.includes({ "VehicleSpawning", "VehicleReset", "QuickTravel", "AllowUnicycle" }, key) then
            return BJCPerm.hasMinimumGroup(senderID, BJCGroups.GROUPS.ADMIN)
        elseif table.includes({ "ResetDelay", "TeleportDelay", "PreserveEnergy", "DriftGood",
                "DriftBig", "Nametags", "EmergencyRefuelDuration", "EmergencyRefuelPercent" }, key) then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG)
        end
    elseif parent == "Reputation" then
        return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CONFIG)
    elseif parent == "TempBan" then
        if table.includes({ "minTime", "maxTime" }, key) then
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
    elseif table.includes({ "Race", "Speed", "Hunter", "Derby", "VehicleDelivery" }, parent) then
        return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SCENARIO)
    elseif parent == "Server" then
        if table.includes({ "Lang", "AllowClientMods", "Theme" }, key) then
            return BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_CORE)
        elseif table.includes({ "DriftBigBroadcast", "Broadcasts", "WelcomeMessage" }, key) then
            return BJCPerm.hasMinimumGroup(senderID, BJCGroups.GROUPS.OWNER)
        end
    end
    error({ key = "rx.errors.invalidKey", data = { key = key } })
end

local function clampValue(parent, key, value)
    if parent == "VoteKick" then
        if key == "Timeout" then
            return math.clamp(value, 5, 300)
        elseif key == "ThresholdRatio" then
            return math.clamp(value, 0.01, 1)
        end
    elseif parent == "MapVote" then
        if key == "Timeout" then
            return math.clamp(value, 5, 300)
        elseif key == "ThresholdRatio" then
            return math.clamp(value, 0.01, 1)
        end
    elseif parent == "Freeroam" then
        if table.includes({ "ResetDelay", "TeleportDelay" }, key) then
            return math.clamp(value, 0, 120)
        elseif key == "EmergencyRefuelDuration" then
            return math.clamp(value, 5, 60)
        elseif key == "EmergencyRefuelPercent" then
            return math.clamp(value, 5, 100)
        end
    elseif parent == "TempBan" then
        if key == "minTime" then
            return math.max(0, math.min(M.Data.TempBan.maxTime, value))
        elseif key == "maxTime" then
            return math.clamp(value, M.Data.TempBan.minTime or 0)
        end
    elseif parent == "Race" then
        if table.includes({ "PreparationTimeout", "FinishTimeout", "RaceEndTimeout", "GridReadyTimeout" }, key) then
            return math.clamp(value, 5)
        elseif table.includes({ "GridTimeout", "RaceCountdown" }, key) then
            return math.clamp(value, 10)
        elseif key == "VoteThresholdRatio" then
            return math.clamp(value, 0.01, 1)
        end
    elseif table.includes({ "Hunter", "Derby" }, parent) then
        if key == "PreparationTimeout" then
            return math.clamp(value, 5, 180)
        elseif table.includes({ "HuntedStartDelay", "HuntersStartDelay" }, key) then
            return math.clamp(value, 0, 60)
        elseif table.includes({ "HuntedStuckTimeout", "DestroyedTimeout" }, key) then
            return math.clamp(value, 3, 20)
        elseif key == "StartCountdown" then
            return math.clamp(value, 10, 60)
        elseif key == "HuntersRespawnDelay" then
            return math.clamp(value, 0, 60)
        end
    end
    return value
end

local function set(ctxt, key, value)
    local parent = nil
    local keyParts = key:split(".")
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
    elseif not parent and key == "Lang" and not table.includes(BJCLang.getLangsList(), value) then
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
        local wlGroups = {}
        for k, g in pairs(BJCGroups.Data) do
            if g.whitelisted or g.staff then
                table.insert(wlGroups, k)
            end
        end
        table.sort(wlGroups, function(a, b) return a:lower() < b:lower() end)
        return string.var("{1}\n{2}\n{3}", {
            BJCLang.getConsoleMessage("command.showWhitelistState"):var({
                state = BJCLang.getConsoleMessage(string.var("common.{1}", {
                    M.Data.Whitelist.Enabled and "enabled" or "disabled"
                }))
            }),
            BJCLang.getConsoleMessage("command.showWhitelistedGroups"):var({
                groupList = #wlGroups > 0 and
                    table.join(wlGroups, ", ") or
                    BJCLang.getConsoleMessage("common.empty")
            }),
            BJCLang.getConsoleMessage("command.showWhitelistedPlayers"):var({
                playerList = #M.Data.Whitelist.PlayerNames > 0 and
                    table.join(M.Data.Whitelist.PlayerNames, ", ") or
                    BJCLang.getConsoleMessage("common.empty")
            }),
        })
    elseif args[1] == "set" then                                                -- set whitelist status
        if not args[2] or not table.includes({ "true", "false" }, args[2]) then -- invalid arg
            return string.var("{1}whitelist set {2}", {
                BJCCommand.commandPrefix,
                BJCLang.getConsoleMessage("command.help.whitelistSetArgs")
            })
        else -- change whitelist state
            local newState = args[2] == "true"
            M.set(ctxt, "Whitelist.Enabled", newState)
            BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.BJC, BJCPerm.PERMISSIONS.WHITELIST)
            return BJCLang.getConsoleMessage("command.newWhitelistState"):var({ state = newState })
        end
    elseif args[1] == "add" then             -- add player to whitelist
        if not args[2] or args[2] == "" then -- invalid arg
            return string.var("{1}whitelist add {2}", {
                BJCCommand.commandPrefix,
                BJCLang.getConsoleMessage("command.help.whitelistAddRemoveArgs")
            })
        elseif table.includes(M.Data.Whitelist.PlayerNames, args[2]) then -- already whitelisted
            return BJCLang.getConsoleMessage("command.alreadyWhitelistedPlayer"):var({ playerName = args[2] })
        else                                                              -- proceed
            BJCPlayers.whitelist(ctxt, args[2])
            return BJCLang.getConsoleMessage("command.whitelistAddedPlayer"):var({ playerName = args[2] })
        end
    elseif args[1] == "remove" then -- remove player from whitelist
        if not args[2] then         -- invalid arg
            return string.var("{1}whitelist remove {2}", {
                BJCCommand.commandPrefix,
                BJCLang.getConsoleMessage("command.help.whitelistAddRemoveArgs")
            })
        else -- valid arg
            local matches = {}
            local list = table.deepcopy(M.Data.Whitelist.PlayerNames)
            for i, pname in ipairs(list) do -- find matches
                if pname == args[2] then    -- exact match
                    matches = { pos = i, playerName = args[2] }
                    break
                elseif pname:lower():find(args[2]:lower()) then -- approximate match
                    table.insert(matches, { pos = i, playerName = pname })
                end
            end
            if #matches == 0 then    -- not whitelisted
                return BJCLang.getConsoleMessage("command.notWhitelistedPlayer"):var({ playerName = args[2] })
            elseif #matches > 1 then -- ambiguity
                local playerList = {}
                for _, m in ipairs(matches) do
                    table.insert(playerList, m.playerName)
                end
                table.sort(playerList, function(a, b) return a:lower() < b:lower() end)
                return BJCLang.getConsoleMessage("command.errors.playerAmbiguity"):var({
                    playerName = args[2],
                    playerList = table.join(playerList, ", ")
                })
            else -- proceed
                BJCPlayers.whitelist(ctxt, matches[1].playerName)
                return BJCLang.getConsoleMessage("command.whitelistRemovedPlayer"):var({
                    playerName = matches[1].playerName
                })
            end
        end
    else -- invalid args
        return BJCLang.getConsoleMessage("command.errors.usage"):var({
            command = string.var(
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
