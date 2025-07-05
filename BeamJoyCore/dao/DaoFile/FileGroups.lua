local M = {
    _dbPath = nil,
}

local function init(dbPath)
    M._dbPath = string.var("{1}/groups.json", { dbPath })

    if not FS.Exists(M._dbPath) then
        BJCDao._saveFile(M._dbPath, BJCDefaults.groups())
    end
end

local function findAll()
    local file, err = io.open(M._dbPath, "r")
    if file and not err then
        local data = file:read("*a")
        file:close()
        data = JSON.parse(data)
        if type(data) ~= "table" then
            LogError("Cannot read file groups.json: Invalid content data")
            data = BJCDefaults.groups()
        end
        return data
    end
    return BJCDefaults.groups()
end

local function save(data)
    BJCDao._saveFile(M._dbPath, data)
end

local function saveByName(groupName, group)
    local groups = findAll()
    groups[groupName] = group
    save(groups)
end

M.init = init

M.findAll = findAll
M.save = save
M.saveByName = saveByName

return M
