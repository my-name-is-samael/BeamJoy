local M = {
    _dbPath = nil,
    _fields = {
        label = "string",
        custom = "boolean",
        archive = "string",
        enabled = "boolean",
    }
}

local function init(dbPath)
    M._dbPath = string.var("{1}/maps.json", { dbPath })

    if not FS.Exists(M._dbPath) then
        BJCDao._saveFile(M._dbPath, BJCDefaults.maps())
    end
end

---@return table
local function findAll()
    local file, error = io.open(M._dbPath, "r")
    if file and not error then
        local data = file:read("*a")
        file:close()
        return #data > 0 and JSON.parse(data) or {}
    end
    return {}
end

local function saveMap(mapName, mapData)
    if mapData.custom and not mapData.archive then
        return
    end
    local data = {}
    for k,v in pairs(M._fields) do
        if type(mapData[k]) == v then
            data[k] = mapData[k]
        end
    end
    if not data.label or data.custom == nil then
        return
    end

    local maps = findAll()
    maps[mapName] = data

    BJCDao._saveFile(M._dbPath, maps)
end

local function remove(mapName)
    local maps = findAll()
    maps[mapName] = nil
    BJCDao._saveFile(M._dbPath, maps)
end

M.init = init

M.findAll = findAll
M.saveMap = saveMap
M.remove = remove

return M