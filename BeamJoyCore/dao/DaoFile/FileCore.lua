local M = {
    _dbPath = nil,
}

local function getDefaultConfig()
    return BJC_CORE_CONFIG:map(function(v, k)
        if MP.Get and MP.Settings[k] then
            return MP.Get(MP.Settings[k])
        end
        return v.env and os.getenv(v.env) or v.default
    end)
end

local function init(dbPath)
    M._dbPath = string.var("{1}/core.json", { dbPath })

    if not FS.Exists(M._dbPath) then
        if not MP.Get and
            not BJC_CORE_CONFIG:any(function(v) return os.getenv(v.env) ~= nil end) then
            LogWarn(
                "Your BeamMP server version prevents BeamJoy from reading the configuration. It will be reset to default, and you will need to update it manually using the interface or by editing the core.json file."
            )
        end
        BJCDao._saveFile(M._dbPath, getDefaultConfig())
    end
end

---@return BJCoreConfig
local function findAll()
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
    BJCDao._saveFile(M._dbPath, data)
end

M.init = init

M.findAll = findAll
M.save = save

return M
