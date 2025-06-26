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
        local res = JSON.parse(data) or {}

        -- sanitizing
        BJC_CORE_CONFIG:forEach(function(v, k)
            if v.type == "boolean" then
                res[k] = res[k] == true
            elseif v.type == "number" then
                res[k] = math.clamp(tonumber(res[k]) or 0, v.min, v.max)
            else -- string
                res[k] = tostring(res[k])
                if v.maxLength and #res > v.maxLength then
                    res[k] = res[k]:sub(1, v.maxLength)
                end
            end
        end)

        return res
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
