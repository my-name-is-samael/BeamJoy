-- THIS FILE'S PURPOSE IS TO PREVENT YOUR IDE FROM GIVING ERRORS ON EACH GAME INTERFACE/METHOD

-- BEAMNG

guihooks = guihooks or {
    trigger = function(key, data) end,
}

RESET_PHYSICS = RESET_PHYSICS or 1

---@return vec3
vec3 = vec3 or function(x, y, z) return {} end
---@return quat
quat = quat or function(x, y, z, w) return {} end
---@return quat
quatFromDir = quatFromDir or function(dir, up) return quat() end
---@return quat
quatFromEuler = quatFromEuler or function(x, y, z) return quat() end
---@return point
Point2F = Point2F or function(x, y) return {} end
---@return vec4
Point4F = Point4F or function(x, y, z, w) return {} end
---@return string
String = String or function(str) return tostring(str) end

ui_imgui = ui_imgui or {}

debugDrawer = debugDrawer or {
    drawSphere = function(self, pos, r, shapeColF, useZ) end,
    drawCylinder = function(self, bottomPos, topPos, radius, shapeColF, useZ) end,
    drawSquarePrism = function(self, base, tip, baseSize, tipSize, shpaeColF, useZ) end,
    drawTextAdvanced = function(self, pos, text, textColF, useAdvancedText, twod, bgColI, shadow, useZ) end,
}

---@param r integer {0-255}
---@param g integer {0-255}
---@param b integer {0-255}
---@param a integer {0-255}
---@return integer
color = color or function(r, g, b, a) return 0 end
---@param r number {0-1}
---@param g number {0-1}
---@param b number {0-1}
---@param a number {0-1}
---@return {r: number, red: number, g: number, green: number, b: number, blue: number, a: number, alpha: number}
ColorF = ColorF or function(r, g, b, a) return {} end
---@param r integer {0-255}
---@param g integer {0-255}
---@param b integer {0-255}
---@param a integer {0-255}
---@return {r: number, red: number, g: number, green: number, b: number, blue: number, a: number, alpha: number}
ColorI = ColorI or function(r, g, b, a) return {} end

log = log or function(type, tag, msg) end
jsonReadFile = jsonReadFile or function(path) return {} end
jsonDecode = jsonDecode or function(str) return {} end
jsonEncode = jsonEncode or function(obj) return "" end
getAllVehicles = getAllVehicles or function() return {} end
getAllVehiclesByType = getAllVehiclesByType or function(types) return {} end
getCurrentLevelIdentifier = getCurrentLevelIdentifier or function() return "" end
LuaProfiler = LuaProfiler or function(msg) return {} end
createObject = createObject or function(name) return {} end
resetGameplay = resetGameplay or function(playerID) end
hptimer = hptimer or function() return {} end
setExtensionUnloadMode = setExtensionUnloadMode or function(module, type) end
getMissionFilename = getMissionFilename or function() return "/levels//[(main.level)|(info)].json" end
GetMapName = function()
    local mission = getMissionFilename()
    local map = mission:gsub("/levels/", ""):gsub("/.+%.json", "")
    return #map > 0 and map or nil
end
ui_message = ui_message or function(msg, ttl, category, icon) end
translateLanguage = translateLanguage or function(key, default) return "" end

nop = nop or {}
be = be or {}
commands = commands or {}
extensions = extensions or {}
core_modmanager = core_modmanager or {}
core_repository = core_repository or {}
core_vehicle_partmgmt = core_vehicle_partmgmt or {}
extensions.gameplay_traffic = extensions.gameplay_traffic or {}
gameplay_police = gameplay_police or {}
extensions.core_multiSpawn = extensions.core_multiSpawn or {}
gameplay_parking = gameplay_parking or {}
extensions.gameplay_rawPois = extensions.gameplay_rawPois or {}
core_camera = core_camera or {}
core_vehicle_manager = core_vehicle_manager or {}
gameplay_drift_scoring = gameplay_drift_scoring or {}
scenetree = scenetree or {}
core_environment = core_environment or {}
bullettime = bullettime or {}
gameplay_playmodeMarkers = gameplay_playmodeMarkers or {}
freeroam_bigMapMode = freeroam_bigMapMode or {}
core_groundMarkers = core_groundMarkers or {}
Lua = Lua or {}
ui_missionInfo = ui_missionInfo or {}
freeroam_bigMapPoiProvider = freeroam_bigMapPoiProvider or {}
map = map or {}
Engine = Engine or {}
spawn = spawn or {}
core_vehicles = core_vehicles or {}
core_vehicleBridge = core_vehicleBridge or {}

-- BEAMMP

AddEventHandler = AddEventHandler or function(eventname, callback) end
TriggerServerEvent = TriggerServerEvent or function(eventname, ...) end
MPTranslate = MPTranslate or function(key, default) return "" or default or key end

settings = settings or {}
MPConfig = MPConfig or {}
MPVehicleGE = MPVehicleGE or {}
MPGameNetwork = MPGameNetwork or {}
MPHelpers = MPHelpers or {}
MPCoreNetwork = MPCoreNetwork or {}

-- BEAMJOY

function RollBackNGFunctionsWrappers(baseFunctions)
    for extName, fns in pairs(baseFunctions) do
        if extensions.isExtensionLoaded(extName) then
            for fnName, fn in pairs(fns) do
                if type(extensions[extName][fnName]) == "function" and
                    type(fn) == "function" then
                    extensions[extName][fnName] = fn
                end
            end
        end
    end
end
