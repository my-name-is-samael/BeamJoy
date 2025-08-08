local M = {
    _dbPath = nil,
}

local function init(dbPath)
    M._dbPath = string.var("{1}/vehicles.json", { dbPath })

    if not FS.Exists(M._dbPath) then
        BJCDao._saveFile(M._dbPath, BJCDefaults.vehicles())
    end
end

local function findAll()
    local file, error = io.open(M._dbPath, "r")
    if file and not error then
        local data = file:read("*a")
        file:close()
        data = JSON.parse(data)
        if type(data) ~= "table" then
            LogError("Cannot read file vehicles.json: Invalid content data")
            data = BJCDefaults.vehicles()
        end
        return data
    end
    return BJCDefaults.vehicles()
end

local function save(data)
    BJCDao._saveFile(M._dbPath, data)
end

M.init = init

M.findAll = findAll
M.save = save

return M
