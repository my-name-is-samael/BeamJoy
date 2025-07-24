local M = {
    _dbPath = nil,

    -- No server config issue => https://github.com/my-name-is-samael/BeamJoy/issues/111
    serverConfigAccess = true,
}

local function getDefaultConfig()
    return BJC_CORE_CONFIG:map(function(v, k)
        if MP.Get and MP.Settings[k] then
            return MP.Get(MP.Settings[k])
        end
        return v.env and os.getenv(v.env) or v.default
    end)
end

---@return table?
local function getServerConfigData()
    if not M.serverConfigAccess then return end

    local file, error = io.open("ServerConfig.toml", "r")
    if not file or error then
        M.serverConfigAccess = false
        return
    end

    local raw = file:read("*a")
    file:close()
    local data = TOML.parse(raw)
    if type(data) ~= "table" or not data.General then
        return
    end

    return data
end

local function init(dbPath)
    M._dbPath = string.var("{1}/core.json", { dbPath })
    if not FS.Exists(M._dbPath) then
        local configData = getServerConfigData()
        if not MP.Get and not M.serverConfigAccess and
            not BJC_CORE_CONFIG:any(function(v) return os.getenv(v.env) ~= nil end) then
            LogWarn(
                "Your BeamMP server version and your hosting provider prevent BeamJoy from reading the configuration. It will be reset to default, and you will need to update it manually using the interface or by editing the core.json file. Any further change in ServerConfig.toml will be ignored until you remove the mod or the core.json file."
            )
        elseif not configData then
            LogWarn(
                "Your current server configuration is invalid. It will be reset to default values and you will need to update it manually using the interface or by editing the core.json file.")
        end
        if M.serverConfigAccess and configData then
            BJCDao._saveFile(M._dbPath, configData.General)
        else
            BJCDao._saveFile(M._dbPath, getDefaultConfig())
        end
    end
end

---@return BJCoreConfig
local function findAll()
    local configData = getServerConfigData()
    if M.serverConfigAccess and configData then
        local res = configData.General
        if res.MaxCars < 200 then
            -- applies fixed value and lets the mod handle the rest
            res.MaxCars = 200
            M.save(res)
        end
        return res
    end

    -- fallback, based on the core.json file
    local file, error = io.open(M._dbPath, "r")
    if file and not error then
        local data = file:read("*a")
        file:close()
        data = JSON.parse(data)
        if type(data) ~= "table" then
            LogError("Cannot read file core.json: Invalid content data")
            data = getDefaultConfig()
        else
            -- sanitizing
            BJC_CORE_CONFIG:forEach(function(v, k)
                if v.type == "boolean" then
                    data[k] = data[k] == true
                elseif v.type == "number" then
                    data[k] = math.clamp(tonumber(data[k]) or 0, v.min, v.max)
                    if k == "MaxCars" and data[k] < 200 then
                        data[k] = 200
                    end
                else -- string
                    data[k] = tostring(data[k])
                    if v.maxLength and #data > v.maxLength then
                        data[k] = data[k]:sub(1, v.maxLength)
                    end
                end
            end)
        end

        return data
    end
    return getDefaultConfig()
end

---@param data BJCoreConfig
local function save(data)
    if M.serverConfigAccess then
        -- ServerConfig.toml save
        local configData = getServerConfigData()
        if configData then
            table.assign(configData.General, data)
        end
        local tmpfile, error = io.open("ServerConfig.temp", "w")
        if tmpfile and not error then
            tmpfile:write(TOML.encode(configData))
            tmpfile:close()

            FS.Remove("ServerConfig.toml")
            FS.Rename("ServerConfig.temp", "ServerConfig.toml")
        end
    end

    -- core.json save
    BJCDao._saveFile(M._dbPath, data)
end

M.init = init

M.findAll = findAll
M.save = save

return M
