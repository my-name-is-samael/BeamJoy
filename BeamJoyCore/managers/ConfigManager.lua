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
            PreserveEnergy = M.Data.Freeroam.PreserveEnergy,
            DriftGood = M.Data.Freeroam.DriftGood,
            DriftBig = M.Data.Freeroam.DriftBig,
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

        if not data.Speed then
            data.Speed = {
                PreparationTimeout = M.Data.Speed.PreparationTimeout,
                VoteTimeout = M.Data.Speed.VoteTimeout,
                BaseSpeed = M.Data.Speed.BaseSpeed,
                StepSpeed = M.Data.Speed.StepSpeed,
                StepDelay = M.Data.Speed.StepDelay,
                EndTimeout = M.Data.Speed.EndTimeout,
            }
        end
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
        elseif tincludes({ "ResetDelay", "TeleportDelay", "PreserveEnergy", "DriftGood", "DriftBig", "Nametags" }, key) then
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
    elseif tincludes({ "Race", "Hunter", "Speed", "Derby", "VehicleDelivery" }, parent, true) then
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
            return math.max(5, math.min(300, value))
        elseif key == "ThresholdRatio" then
            return math.max(0.01, math.min(1, value))
        end
    elseif parent == "MapVote" then
        if key == "Timeout" then
            return math.max(5, math.min(300, value))
        elseif key == "ThresholdRatio" then
            return math.max(0.01, math.min(1, value))
        end
    elseif parent == "Freeroam" then
        if tincludes({ "ResetDelay", "TeleportDelay" }, key) then
            return math.max(0, value)
        end
    elseif parent == "TempBan" then
        if key == "minTime" then
            return math.max(0, math.min(M.Data.TempBan.maxTime, value))
        elseif key == "maxTime" then
            if value < 0 then
                return 0
            else
                return math.max(M.Data.TempBan.minTime, value)
            end
        end
    elseif parent == "Race" then
        if tincludes({ "PreparationTimeout", "FinishTimeout", "RaceEndTimeout", "GridReadyTimeout" }, key) then
            return math.max(5, value)
        elseif tincludes({ "GridTimeout", "RaceCountdown" }, key) then
            return math.max(10, value)
        elseif key == "VoteThresholdRatio" then
            return math.max(0.01, math.min(1, value))
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

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.BJC)
end

local function consoleSetWhitelist(args)
    local value = args[1]
    if #args > 0 and (not tincludes({ "true", "false" }, value) or value == "help") then
        return svar(BJCLang.getConsoleMessage("command.errors.usage"),
            { command = "bj whitelist [true|false]" })
    end

    if value == "" then
        return svar("Whitelist.Enabled = {1}", { M.Data.Whitelist.Enabled })
    elseif value == "true" or value == "false" then
        value = value == "true"
    end

    local ctxt = {}
    BJCInitContext(ctxt)
    M.set(ctxt, "Whitelist.Enabled", value)
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.BJC, BJCPerm.PERMISSIONS.WHITELIST)
    return svar("Whitelist.Enabled = {1}", { value })
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.set = set
M.consoleSetWhitelist = consoleSetWhitelist

init()

return M
