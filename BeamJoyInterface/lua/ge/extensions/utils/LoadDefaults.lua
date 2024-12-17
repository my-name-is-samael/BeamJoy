-- THIS FILE'S PURPOSE IS TO PREVENT YOUR IDE FROM GIVVING ERRORS ON EACH GAME INTERRFACE/METHOD

-- BEAMNG

guihooks = guihooks or {
    trigger = function(key, data) end,
}

vec3 = vec3 or function(x, y, z) return {} end
quat = quat or function(x, y, z, w) return {} end
quatFromDir = quatFromDir or function(dir, up) return quat() end
quatFromEuler = quatFromEuler or function(x, y, a) return quat() end
Point2F = Point2F or function(x, y) return {} end
String = String or function(str) return tostring(str) end

ui_imgui = ui_imgui or {}

debugDrawer = debugDrawer or {
    drawSphere = function(self, pos, r, shapeColF, useZ) end,
    drawCylinder = function(self, bottomPos, topPos, radius, shapeColF, useZ) end,
    drawSquarePrism = function(self, base, tip, baseSize, tipSize, shpaeColF, useZ) end,
    drawTextAdvanced = function(self, pos, text, textColF, useAdvancedText, twod, bgColI, shadow, useZ) end,
}

color = color or function(r, g, b, a) return {} end
ColorF = ColorF or function(r, g, b, a) return {} end
ColorI = ColorI or function(r, g, b, a) return {} end

log = log or function(type, tag, msg) end
jsonReadFile = jsonReadFile or function(path) return {} end
jsonDecode = jsonDecode or function(str) return {} end
jsonEncode = jsonEncode or function(obj) return "" end
getAllVehicles = getAllVehicles or function() return {} end
getCurrentLevelIdentifier = getCurrentLevelIdentifier or function() return "" end
LuaProfiler = LuaProfiler or function(msg) return {} end
createObject = createObject or function(name) return {} end
hptimer = hptimer or function() return {} end
setExtensionUnloadMode = setExtensionUnloadMode or function(module, type) end

nop = nop or {}
be = be or {}
commands = commands or {}
extensions = extensions or {}
core_modmanager = core_modmanager or {}
core_repository = core_repository or {}
core_vehicle_partmgmt = core_vehicle_partmgmt or {}
gameplay_traffic = gameplay_traffic or {}
core_multiSpawn = core_multiSpawn or {}
gameplay_parking = gameplay_parking or {}
gameplay_rawPois = gameplay_rawPois or {}
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
