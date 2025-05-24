local M = {
    _dbPath = nil,
}

local function init(dbPath)
    M._dbPath = string.var("{1}/bjc.json", { dbPath })

    if not FS.Exists(M._dbPath) then
        BJCDao._saveFile(M._dbPath, BJCDefaults.config())
    end
end

local function findAll()
    local file, error = io.open(M._dbPath, "r")
    if file and not error then
        local data = file:read("*a")
        file:close()
        return JSON.parse(data)
    end
    return {}
end

local function save(parent, key, value)
    if not parent or not key then
        error()
    end

    local config = findAll()
    if config[parent] then
        config[parent][key] = value
    end
    BJCDao._saveFile(M._dbPath, config)
end

M.init = init

M.findAll = findAll
M.save = save

return M
