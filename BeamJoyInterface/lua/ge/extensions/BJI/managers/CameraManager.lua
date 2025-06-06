---@class BJIManagerCam : BJIManager
local M = {
    _name = "Cam",

    DEFAULT_FREECAM_FOV = 65,
    CAMERAS = {
        ORBIT = "orbit",
        BIG_MAP = "bigMap",
        EXTERNAL = "external",
        DRIVER = "driver",
        PASSENGER = "passenger",
        FREE = "free",
    },
    NEED_RESET = {
        orbit = true,
        driver = true,
    },
    forced = {
        cam = nil,
        posrot = nil,
        previouscam = nil,
        previousposrot = nil,
    },
    restricted = {},
    lastCamera = nil,
}

---@return string
local function getCamera()
    return core_camera.getActiveCamName()
end

---@param cameraName string
---@param withTransition? boolean
local function setCamera(cameraName, withTransition)
    if withTransition == nil then
        withTransition = true
    end

    if cameraName == M.CAMERAS.PASSENGER then
        if BJI.Managers.Veh.isCurrentVehicleOwn() then
            -- You can't be passenger in your own vehicle
            cameraName = M.CAMERAS.DRIVER
        end
    elseif cameraName == M.CAMERAS.DRIVER then
        if not BJI.Managers.Veh.isCurrentVehicleOwn() then
            -- You can't be driver in another vehicle
            cameraName = M.CAMERAS.PASSENGER
        end
    end

    core_camera.setByName(0, cameraName, withTransition)
    if M.NEED_RESET[cameraName] then
        core_camera.resetCamera(0)
    end
end

local function getPositionRotation(keepOrientation)
    local camDir = core_camera.getForward()
    if not keepOrientation then
        camDir.z = 0
    end
    return math.roundPositionRotation({
        pos = core_camera.getPosition(),
        rot = quatFromDir(camDir, vec3(0, 0, 1))
    })
end

--[[
<ul>
    <li>pos: vec3</li>
    <li>rot: quat DEFAULT self:rot</li>
</ul>
]]
local function setPositionRotation(pos, rot)
    rot = rot or M.getPositionRotation().rot

    core_camera.setPosRot(
        BJI.Managers.Context.User.playerID,
        pos.x, pos.y, pos.z,
        rot.x, rot.y, rot.z, rot.w
    )
end

local function toggleFreeCam()
    if M.getCamera() == M.CAMERAS.FREE then
        if BJI.Managers.Veh.getCurrentVehicle() then
            commands.toggleCamera()
        end
    else
        if not M.isRestrictedCamera(M.CAMERAS.FREE) then
            commands.toggleCamera()
        end
    end
end

local function isForcedCamera()
    return M.forced.cam ~= nil
end

local function forceCamera(cam)
    -- if already forced, do not override back camera
    if not M.isForcedCamera() then
        M.forced.previouscam = M.getCamera()
        if M.forced.previouscam == M.CAMERAS.FREE then
            -- if previous cam is freecam, then keep its position
            M.forced.previousposrot = M.getPositionRotation()
        end
    end

    M.forced.cam = cam
end

---@param rollback? boolean
local function resetForceCamera(rollback)
    if not M.isForcedCamera() then
        return
    end

    M.forced.cam = nil
    M.forced.posrot = nil
    if rollback and M.forced.previouscam then
        M.setCamera(M.forced.previouscam)

        if M.forced.previouscam == M.CAMERAS.FREE then
            if M.forced.previousposrot then
                M.setPositionRotation(M.forced.previousposrot.pos, M.forced.previousposrot.rot)
            end
        end
    end
    M.forced.previouscam = nil
    M.forced.previousposrot = nil
end

---@param pos? vec3
---@param rot? quat
local function forceFreecamPos(pos, rot)
    M.forced.previouscam = M.getCamera()
    M.forced.cam = M.CAMERAS.FREE
    if not pos or not rot then
        local base = M.getPositionRotation(true)
        pos = pos or base.pos
        rot = rot or base.rot
    end
    M.forced.posrot = { pos = pos, rot = rot }
end

local function isRestrictedCamera(cam)
    return table.includes(M.restricted, cam)
end

local function addRestrictedCamera(cam)
    if not M.isRestrictedCamera(cam) then
        table.insert(M.restricted, cam)
    end
end

local function removeRestrictedCamera(cam)
    if M.isRestrictedCamera(cam) then
        local pos = table.indexOf(M.restricted, cam)
        if pos then
            table.remove(M.restricted, pos)
        end
    end
end

local function resetRestrictedCameras()
    M.restricted = {}
end

local function isFreeCamSmooth()
    local infos = core_camera.getGlobalCameras().free

    return infos.angularForce == 150 and
        infos.angularDrag == 2.5 and
        infos.mass == 10 and
        infos.translationForce == 600 and
        infos.translationDrag == 2
end

local function setFreeCamSmooth(state)
    core_camera.setSmoothedCam(0, state)
end

local function getFOV()
    return core_camera.getFovDeg()
end

-- default: float DEFAULT 65, 10-120 range
local function setFOV(deg)
    if deg == nil then
        deg = 65
    elseif type(deg) ~= "number" then
        return
    end

    core_camera.setFOV(0, deg)
end

local initKey
--- Called when self player is connected and every vehicle is ready
local function onConnection()
    local vehs = Table(BJI.Managers.Context.Players)
        :reduce(function(vehs, p)
            return vehs:addAll(Table(p.vehicles)
                :map(function(v)
                    return v.finalGameVehID
                end)
                :filter(function(vid)
                    return not BJI.Managers.AI.isAIVehicle(vid)
                end))
        end, Table())
    if #vehs > 0 then
        local vid = vehs:random()
        BJI.Managers.Veh.focusVehicle(vid)
    end
    BJI.Managers.Events.removeListener(tostring(initKey))
end

local function renderTick(ctxt)
    if ctxt.camera ~= M.lastCamera then
        M.onCameraChange(ctxt.camera)
        ctxt.camera = M.getCamera()
        M.lastCamera = ctxt.camera
    end
end

local function fastTick(ctxt)
    -- Update forced camera
    if M.isForcedCamera() then
        if ctxt.camera ~= M.forced.cam then
            M.setCamera(M.forced.cam, false)
            ctxt.camera = M.getCamera()
        end

        if M.forced.cam == M.CAMERAS.FREE and M.forced.posrot then
            M.setPositionRotation(M.forced.posrot.pos, M.forced.posrot.rot)
        end
    end

    if ctxt.camera == M.CAMERAS.FREE then
        local isSmoothed = M.isFreeCamSmooth()
        local state = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_SMOOTH)
        if state and not isSmoothed then
            M.setFreeCamSmooth(true)
        elseif not state and isSmoothed then
            M.setFreeCamSmooth(false)
        end
    end
end

local function slowTick(ctxt)
    if ctxt.camera == M.CAMERAS.FREE and
        M.getFOV() ~= BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_FOV) then
        -- update FOV
        BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_FOV, M.getFOV())
    end
end

local function switchToNextCam()
    core_camera.setVehicleCameraByIndexOffset(0, 1)
end

local function onCameraChange(newCamera)
    if #M.restricted > 0 then
        if table.includes(M.restricted, newCamera) then
            switchToNextCam()
            return
        end
    end

    if newCamera == M.CAMERAS.DRIVER and not BJI.Managers.Veh.isCurrentVehicleOwn() then
        switchToNextCam()
        return
    elseif newCamera == M.CAMERAS.PASSENGER and BJI.Managers.Veh.isCurrentVehicleOwn() then
        switchToNextCam()
        return
    end

    if newCamera == M.CAMERAS.FREE then
        M.setFOV(BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_FOV))
    end
end

local function onLoad()
    if M.getCamera() == M.CAMERAS.FREE then
        M.setFOV(BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.FREECAM_FOV))
    end

    initKey = BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.VEHICLES_UPDATED, onConnection)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick, M._name)
end

M.getCamera = getCamera
M.setCamera = setCamera
M.getPositionRotation = getPositionRotation
M.setPositionRotation = setPositionRotation
M.toggleFreeCam = toggleFreeCam

M.isForcedCamera = isForcedCamera
M.forceCamera = forceCamera
M.resetForceCamera = resetForceCamera
M.forceFreecamPos = forceFreecamPos

M.isRestrictedCamera = isRestrictedCamera
M.addRestrictedCamera = addRestrictedCamera
M.removeRestrictedCamera = removeRestrictedCamera
M.resetRestrictedCameras = resetRestrictedCameras

M.isFreeCamSmooth = isFreeCamSmooth
M.setFreeCamSmooth = setFreeCamSmooth

M.getFOV = getFOV
M.setFOV = setFOV

M.onCameraChange = onCameraChange

M.onLoad = onLoad
M.renderTick = renderTick

return M
