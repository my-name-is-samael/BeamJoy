local dbPath = BJCPluginPath:gsub("BeamJoyCore", "BeamJoyData/db")

BJCDao = {
    config = require("dao/DaoFile/FileConfig"),
    groups = require("dao/DaoFile/FileGroups"),
    permissions = require("dao/DaoFile/FilePermissions"),
    players = require("dao/DaoFile/FilePlayers"),
    vehicles = require("dao/DaoFile/FileVehicles"),
    environment = require("dao/DaoFile/FileEnvironment"),
    maps = require("dao/DaoFile/FileMaps"),
    scenario = require("dao/DaoFile/FileScenario"),
}

local function init()
    if not FS.Exists(dbPath) then
        FS.CreateDirectory(dbPath)
    end

    for _, dao in pairs(BJCDao) do
        if type(dao) == "table" and
            type(dao.init) == "function" then
            dao.init(dbPath)
        end
    end
end

function BJCDao._saveFile(filePath, data)
    local tempFilePath = string.var("{1}.temp", { filePath })
    local tmpfile, error = io.open(tempFilePath, "w")
    if tmpfile and not error then
        tmpfile:write(JSON.stringify(data))
        tmpfile:close()

        if FS.Exists(filePath) then
            FS.Remove(filePath)
        end
        FS.Rename(tempFilePath, filePath)
        return true
    end
    return false
end

init()

return BJCDao
