---@class BJIVehicleData
---@field vehID integer
---@field gameVehID integer
---@field model string
---@field damageState number
---@field engine boolean
---@field engineStation boolean
---@field freeze boolean
---@field freezeStation boolean
---@field tanks table<string, {energyType: string, storageType: string, maxEnergy: number, currentEnergy: number}>

---@class BJIPositionRotation
---@field pos vec3
---@field rot? quat

BJI_VEHICLE_TYPES = {
    CAR = "Car",
    TRUCK = "Truck",
    TRAILER = "Trailer",
    PROP = "Prop",
}

local M = {
    _name = "BJIVeh",
    baseFunctions = {},

    tankEmergencyRefuelThreshold = .02, -- threshold for when emergency refuel button appears
    tankLowThreshold = .05,             -- threshold for when fuel amount becomes critical + warning sound
    tankMedThreshold = .15,             -- threshold for when fuel amount becomes warning
}

--gameplay_walk.toggleWalkingMode()

local function onLoad()
    -- update configs cache when saving/overwriting/deleting a config
    BJIAsync.task(function()
        return not not extensions.core_vehicle_partmgmt and not not extensions.util_screenshotCreator
    end, function()
        M.baseFunctions.saveConfigBaseFunction = extensions.util_screenshotCreator.startWork
        M.baseFunctions.removeConfigBaseFunction = extensions.core_vehicle_partmgmt.removeLocal

        extensions.util_screenshotCreator.startWork = function(...)
            M.baseFunctions.saveConfigBaseFunction(...)
            BJIAsync.delayTask(function()
                M.getAllVehicleConfigs(false, false, true)
            end, 3000, "BJIVehPostSaveConfig")
        end
        extensions.core_vehicle_partmgmt.removeLocal = function(...)
            M.baseFunctions.removeConfigBaseFunction(...)
            BJIAsync.delayTask(function()
                M.getAllVehicleConfigs(false, false, true)
            end, 1000, "BJIVehPostRemoveConfig")
        end
    end, "BJIVehSaveRemoveConfigOverride")
end

local function onUnload()
    if extensions.core_vehicle_partmgmt then
        if M.baseFunctions.saveConfigBaseFunction then
            extensions.util_screenshotCreator.startWork = M.baseFunctions.saveConfigBaseFunction
            extensions.core_vehicle_partmgmt.removeLocal = M.baseFunctions.removeConfigBaseFunction
        end
    end
end

local function isGEInit()
    return MPVehicleGE ~= nil
end

---@class BJIMPVehicle
---@field gameVehicleID integer
---@field isDeleted boolean
---@field isLocal boolean
---@field isSpawned boolean
---@field jbeam string
---@field ownerID string
---@field ownerName string
---@field remoteVehID string
---@field serverVehicleID string
---@field serverVehicleString string
---@field spectators integer[]

---@return BJIMPVehicle[]
local function getMPVehicles()
    local vehs = {}
    local mpVehs = MPVehicleGE.getVehicles()
    for _, v in pairs(mpVehs) do
        table.insert(vehs, {
            gameVehicleID = v.gameVehicleID,
            isDeleted = v.isDeleted,
            isLocal = v.isLocal,
            isSpawned = v.isSpawned,
            jbeam = v.jbeam,
            ownerID = v.ownerID,
            ownerName = v.ownerName,
            remoteVehID = v.remoteVehID,
            serverVehicleID = v.serverVehicleID,
            serverVehicleString = v.serverVehicleString,
            spectators = v.spectators,
        })
    end
    return vehs
end

---@return BJIMPVehicle[]
local function getMPOwnVehicles()
    local vehs = {}
    local mpVehs = MPVehicleGE.getOwnMap()
    for _, v in pairs(mpVehs) do
        table.insert(vehs, {
            gameVehicleID = v.gameVehicleID,
            isDeleted = v.isDeleted,
            isLocal = v.isLocal,
            isSpawned = v.isSpawned,
            jbeam = v.jbeam,
            ownerID = v.ownerID,
            ownerName = v.ownerName,
            remoteVehID = v.remoteVehID,
            serverVehicleID = v.serverVehicleID,
            serverVehicleString = v.serverVehicleString,
            spectators = v.spectators,
        })
    end
    return vehs
end

local function isVehReady(gameVehID)
    local veh = MPVehicleGE.getOwnMap()[gameVehID]
    return veh and veh.isSpawned and not veh.isDeleted
end

local function _getPlayerVehicleAndPosAndRotation(thenFn)
    local playerVehicle = M.getCurrentVehicle()
    if not playerVehicle then return end
    local pos = core_camera.getPosition()
    local camDir = core_camera.getForward()
    camDir.z = 0
    local camRot = quatFromDir(camDir, vec3(0, 0, 1))
    camRot = quat(0, 0, 1, 0) * camRot -- vehicles' forward is inverted
    thenFn(playerVehicle, pos, camRot)
end

local function dropPlayerAtCamera(withReset)
    if M.isCurrentVehicleOwn() and
        BJICam.getCamera() ~= BJICam.CAMERAS.BIG_MAP then
        local previousCam = BJICam.getCamera()
        local camPosRot = BJICam.getPositionRotation(false)
        camPosRot.rot = camPosRot.rot * quat(0, 0, 1, 0) -- vehicles' forward is inverted

        BJIVeh.setPositionRotation(camPosRot.pos, camPosRot.rot, {
            safe = false,
            saveHome = true,
            noReset = not withReset,
        })

        if previousCam == BJICam.CAMERAS.FREE then
            BJICam.setCamera(BJICam.CAMERAS.ORBIT)
            core_camera.resetCamera(0)
        end
    end
end

local function dropPlayerAtCameraNoReset()
    _getPlayerVehicleAndPosAndRotation(
        function(vehicle, pos, camRot)
            local vehRot = quat(vehicle:getClusterRotationSlow(vehicle:getRefNodeId()))
            local diffRot = vehRot:inversed() * camRot
            vehicle:setClusterPosRelRot(vehicle:getRefNodeId(), pos.x, pos.y, pos.z, diffRot.x, diffRot.y, diffRot.z,
                diffRot.w)
            vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 0, 0, 0, 0)
            core_camera.setGlobalCameraByName(nil)

            if core_camera.getActiveCamName(0) == "bigMap" then
                core_camera.setByName(0, "orbit", false)
            end
            core_camera.resetCamera(0)
            vehicle:setOriginalTransform(pos.x, pos.y, pos.z, camRot.x, camRot.y, camRot.z, camRot.w)
        end
    )
end

local function getCurrentVehicle()
    return be:getPlayerVehicle(0)
end

local function getVehicleObject(gameVehID)
    gameVehID = tonumber(gameVehID)
    if not gameVehID then
        return
    end
    local veh = be:getObjectByID(gameVehID)
    if not veh then
        local vehs = M.getMPVehicles()
        for _, v in pairs(vehs) do
            if v.remoteVehID == gameVehID then
                return be:getObjectByID(v.gameVehicleID)
            end
        end
    end
    return veh or nil
end

local function getRemoteVehID(gameVehID)
    local vehs = M.getMPVehicles()
    for _, v in pairs(vehs) do
        if v.gameVehicleID == gameVehID and v.remoteVehID ~= -1 then
            return tonumber(v.remoteVehID)
        end
    end
    return nil
end

local function getGameVehIDByRemoteVehID(remoteVehID)
    local vehs = M.getMPVehicles()
    for _, v in pairs(vehs) do
        if v.remoteVehID == remoteVehID then
            return v.gameVehicleID
        end
    end
    return nil
end

local function getVehOwnerID(gameVehID)
    local vehs = M.getMPVehicles()
    for _, v in pairs(vehs) do
        if v.gameVehicleID == gameVehID or v.remoteVehID == gameVehID then
            return tonumber(v.ownerID)
        end
    end
    return nil
end

local function getVehIDByGameVehID(gameVehID)
    if not M.isGEInit() or
        gameVehID == -1 or
        not M.getVehicleObject(gameVehID) then
        return nil
    end
    local _, veh, err = pcall(MPVehicleGE.getVehicleByGameID, gameVehID)
    if not veh or err then
        return nil
    end
    return tonumber(veh.serverVehicleID)
end

local function getGameVehicleID(playerID, vehID)
    local srvVehID = string.var("{1}-{2}", { playerID, vehID or 0 })
    if not M.getMPVehicles()[srvVehID] then
        return nil
    end
    return MPVehicleGE.getGameVehicleID(srvVehID)
end

local function isVehicleOwn(gameVehID)
    return M.isGEInit() and MPVehicleGE.isOwn(gameVehID)
end

local function isCurrentVehicleOwn()
    local vehicle = M.getCurrentVehicle()
    if vehicle then
        return M.isVehicleOwn(vehicle:getID())
    elseif BJIContext.User.currentVehicle then
        return M.isVehicleOwn(BJIContext.User.currentVehicle)
    end
    return false
end

local function getCurrentVehicleOwn()
    local veh = M.getCurrentVehicle()
    if veh and M.isVehicleOwn(veh:getID()) and M.isGEInit() then
        return veh
    end
end

local function hasVehicle()
    return table.length(MPVehicleGE.getOwnMap()) > 0
end


---@param callback fun(ctxt: TickContext)
local function waitForVehicleSpawn(callback)
    local delay = GetCurrentTimeMillis() + 100
    local timeout = delay + 20000
    BJIAsync.task(function(ctxt)
        if ctxt.now >= timeout then
            LogError("Vehicle spawn wait timeout")
            return true
        end
        if ctxt.now > delay and ui_imgui.GetIO().Framerate > 5 and ctxt.veh ~= nil then
            if BJIVeh.isUnicycle(ctxt.veh:getID()) then
                return true
            end
            return ctxt.vehData ~= nil and ctxt.vehData.damageState ~= nil and
                ctxt.vehData.damageState < BJIContext.physics.VehiclePristineThreshold
        end
        return false
    end, callback, string.var("BJIVehSpawnCallback-{1}", { delay }))
end

local function onVehicleSpawned(gameVehID)
    local vehicle = M.getVehicleObject(gameVehID)
    if vehicle then
        vehicle:queueLuaCommand('extensions.BJI_BJIPhysics.update()')
    end
end

local function focus(playerID)
    local player = BJIContext.Players[playerID]
    local veh = (player and player.currentVehicle) and M.getVehicleObject(player.currentVehicle) or nil
    if veh then
        be:enterVehicle(0, veh)
        -- _vehGE.focusCameraOnPlayer(playerName)
        if BJICam.getCamera() == BJICam.CAMERAS.FREE then
            BJICam.setCamera(BJICam.CAMERAS.ORBIT, true)
        end
    end
end

local function focusVehicle(gameVehID)
    local veh = M.getVehicleObject(gameVehID)
    if veh then
        be:enterVehicle(0, veh)
        if BJICam.getCamera() == BJICam.CAMERAS.FREE then
            BJICam.setCamera(BJICam.CAMERAS.ORBIT, true)
        end
    end
end

local function focusNextVehicle()
    be:enterNextVehicle(0, 1)
end

local function teleportToPlayer(targetID)
    if not M.isCurrentVehicleOwn() then
        return
    end

    local target = BJIContext.Players[targetID]
    local destVeh = target and M.getVehicleObject(target.currentVehicle) or nil
    if not target or not destVeh then
        LogError("Invalid target player or vehicle")
        return
    end

    -- old
    -- MPVehicleGE.teleportVehToPlayer(target.playerName)

    local posRot = destVeh and M.getPositionRotation(destVeh)
    if posRot then
        M.setPositionRotation(posRot.pos, posRot.rot)
    else
        LogError("Invalid destination position")
    end
end

local function teleportToLastRoad()
    if M.isCurrentVehicleOwn() then
        spawn.teleportToLastRoad()
    end
end

local function deleteOtherOwnVehicles()
    local vehs = BJIContext.User.vehicles
    local selfVeh = M.getCurrentVehicleOwn()
    local currentGameVehID = selfVeh and selfVeh:getID() or nil
    for _, veh in pairs(vehs) do
        if veh.gameVehID ~= currentGameVehID then
            local v = M.getVehicleObject(veh.gameVehID)
            if v then
                v:delete()
            end
        end
    end
end

local function deleteAllOwnVehicles()
    M.saveCurrentVehicle()
    local vehs = BJIContext.User.vehicles
    if table.length(vehs) > 0 then
        for _, veh in pairs(vehs) do
            local v = M.getVehicleObject(veh.gameVehID)
            if v then
                v:delete()
            end
        end
    end
end

local function deleteCurrentVehicle()
    M.saveCurrentVehicle()
    local v = M.getCurrentVehicleOwn()
    if v then
        v:delete()
    end
end

local function deleteVehicle(gameVehID)
    local v = M.getVehicleObject(gameVehID)
    if v and M.isVehicleOwn(gameVehID) then
        v:delete()
    end
end

local function deleteOtherPlayerVehicle()
    local v = M.getCurrentVehicle()
    if v and not M.isVehicleOwn(v:getID()) then
        v:delete()
    end
end

BJI_VEHICLE_EXPLODE_HINGES_DELAY = 200
local function explodeVehicle(gameVehID)
    local veh = M.getVehicleObject(gameVehID)
    if veh then
        veh:queueLuaCommand("fire.explodeVehicle()")
        BJIAsync.delayTask(function()
            veh:queueLuaCommand("beamstate.breakAllBreakgroups()")
        end, BJI_VEHICLE_EXPLODE_HINGES_DELAY, string.var("ExplodeVehicle{1}", { gameVehID }))
    end
end

---@param posRot? BJIPositionRotation
local function saveHome(posRot)
    local veh = M.getCurrentVehicleOwn()
    if veh then
        local pointStr = ""
        if posRot then
            local angle = math.angleFromQuatRotation(posRot.rot)
            local dirFront = vec3(math.rotate2DVec(vec3(0, 1, 0), angle))
            local dirUp = vec3(0, 0, 1)
            pointStr = string.var([[{
                pos = vec3({1}, {2}, {3}),
                dirFront = vec3({4}, {5}, {6}),
                dirUp = vec3({7}, {8}, {9}),
            }]], {
                posRot.pos.x, posRot.pos.y, posRot.pos.z,
                dirFront.x, dirFront.y, dirFront.z,
                dirUp.x, dirUp.y, dirUp.z
            })
        end
        veh:queueLuaCommand(string.var("recovery.saveHome({1})", { pointStr }))
    end
end

---@param callback? fun(ctxt: TickContext)
local function loadHome(callback)
    local veh = M.getCurrentVehicleOwn()
    if veh then
        veh:queueLuaCommand("recovery.loadHome()")
        if type(callback) == "function" then
            waitForVehicleSpawn(callback)
        end
    end
end

---@param veh? userdata
---@return BJIPositionRotation|nil
local function getPositionRotation(veh)
    if not veh then
        veh = M.getCurrentVehicle()
    end

    if veh then
        local nodeId = veh:getRefNodeId()
        --local pos = veh:getSpawnWorldOOBB():getCenter()
        local pos = vec3(be:getObjectOOBBCenterXYZ(veh:getID()))
        pos.z = pos.z - veh:getInitialHeight() * .5 -- center at ground
        local rot = quat(veh:getClusterRotationSlow(nodeId))

        return RoundPositionRotation({ pos = pos, rot = rot })
    end
    return nil
end

--[[
<ul>
    <li>safe?: boolean DEFAULT true</li>
    <li>saveHome?: boolean NULLABLE</li>
    <li>noReset?: boolean DEFAULT false</li>
</ul>
]]
---@param pos vec3
---@param rot? quat DEFAULT to currentVeh:rot
---@param options? { safe?: boolean, saveHome?: boolean, noReset?: boolean }
local function setPositionRotation(pos, rot, options)
    if not pos then
        return
    end
    pos = vec3(pos)
    if not rot then
        rot = M.getPositionRotation().rot or quat(0, 0, 0, 0)
    else
        rot = quat(rot)
    end
    -- default values
    if not options then options = { safe = true } end
    if options.safe == nil then options.safe = true end

    local veh = M.getCurrentVehicle()
    if veh and M.isVehicleOwn(veh:getID()) then
        pos.z = pos.z + veh:getInitialHeight() * .5 -- add half the height of vehicle

        if options.noReset then
            local vehRot = quat(veh:getClusterRotationSlow(veh:getRefNodeId()))
            local diffRot = vehRot:inversed() * rot
            veh:setClusterPosRelRot(veh:getRefNodeId(), pos.x, pos.y, pos.z, diffRot.x, diffRot.y, diffRot.z,
                diffRot.w)
            veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 0, 0, 0, 0)
        else
            -- move vehicle
            veh:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)

            -- then center it
            local center = rot * veh.initialNodePosBB:getCenter()
            local refnode = rot * veh:getInitialNodePosition(veh:getRefNodeId())
            local centerToRefnode = refnode - center
            pos = pos + centerToRefnode
            if options.safe then
                rot = rot * quat(0, 0, 1, 0) -- vehicles' forward is inverted
                spawn.safeTeleport(veh, pos, rot, false)
            else
                veh:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
                veh:resetBrokenFlexMesh()
            end
        end

        if options.saveHome then
            veh:setOriginalTransform(pos.x, pos.y, pos.z, rot.x,
                rot.y, rot.z, rot.w)
        end
    end
end

local function stopCurrentVehicle()
    local veh = M.getCurrentVehicleOwn()
    if veh then
        veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 0, 0, 0, 0)
    end
end

local function freeze(state, gameVehID)
    state = state == true and 1 or 0
    local vehicle
    if gameVehID then
        if not M.isVehicleOwn(gameVehID) then
            return
        end
        vehicle = M.getVehicleObject(gameVehID)
    else
        -- fallback to current owned vehicle
        if not M.isCurrentVehicleOwn() then
            return
        end
        vehicle = M.getCurrentVehicleOwn()
    end
    if vehicle then
        vehicle:queueLuaCommand(string.var("controller.setFreeze({1})", { state }))
    end
end

local function engine(state, gameVehID)
    state = state == true
    local vehicle
    if gameVehID then
        if not M.isVehicleOwn(gameVehID) then
            return
        end
        vehicle = M.getVehicleObject(gameVehID)
    else
        -- fallback to current owned vehicle
        if not M.isCurrentVehicleOwn() then
            return
        end
        vehicle = M.getCurrentVehicleOwn()
    end

    if vehicle then
        if state then
            vehicle:queueLuaCommand('controller.mainController.setStarter(true)')
        end
        vehicle:queueLuaCommand(string.var(
            "if controller.mainController.setEngineIgnition then controller.mainController.setEngineIgnition({1}) end",
            { state }
        ))
        if state then
            BJIAsync.delayTask(function()
                vehicle:queueLuaCommand('controller.mainController.setStarter(false)')
            end, 1000, "BJIEngineStartDelayStarter")
        end
        -- vehicle:queueLuaCommand(string.var("electrics.horn({1})", { state }))
    end
end

local function lights(state, gameVehID, allLights)
    local vehicle
    if gameVehID then
        if not M.isVehicleOwn(gameVehID) then
            return
        end
        vehicle = M.getVehicleObject(gameVehID)
    else
        -- fallback to current owned vehicle
        if not M.isCurrentVehicleOwn() then
            return
        end
        vehicle = M.getCurrentVehicleOwn()
    end

    state = state == true and 1 or 0

    if vehicle then
        if state == 1 then
            vehicle:queueLuaCommand("electrics.setLightsState(1)")
            vehicle:queueLuaCommand("electrics.setLightsState(2)")
        else
            vehicle:queueLuaCommand("electrics.setLightsState(0)")
            if allLights then
                vehicle:queueLuaCommand(string.var("electrics.set_warn_signal({1})", { state }))
                vehicle:queueLuaCommand(string.var("electrics.set_lightbar_signal({1})", { state }))
                vehicle:queueLuaCommand(string.var("electrics.set_fog_lights({1})", { state }))
            end
        end
    end
end

--[[
gearIndex:
<ul>
    <li>-1 : R</li>
    <li>0 : N</li>
    <li>1 : 1 or D</li>
    <li>...</li>
</ul>
]]
---@param vehID? integer DEFAULT to currentVeh:getID()
---@param gearIndex integer
local function setGear(vehID, gearIndex)
    local vehicle
    if vehID then
        local gameVehID = M.getGameVehicleID(BJIContext.User.playerID, vehID)
        vehicle = M.getVehicleObject(gameVehID)
    else
        -- fallback to current owned vehicle
        if not M.isCurrentVehicleOwn() then
            return
        end
        vehicle = M.getCurrentVehicleOwn()
    end
    if vehicle then
        vehicle:queueLuaCommand(string.var("controller.mainController.shiftToGearIndex({1})", { gearIndex }))
    end
end

local function shiftUp(vehID)
    local vehicle
    if vehID then
        local gameVehID = M.getGameVehicleID(BJIContext.User.playerID, vehID)
        vehicle = M.getVehicleObject(gameVehID)
    else
        -- fallback to current owned vehicle
        if not M.isCurrentVehicleOwn() then
            return
        end
        vehicle = M.getCurrentVehicleOwn()
    end
    if vehicle then
        vehicle:queueLuaCommand(
            "if controller.mainController.shiftUpOnDown then controller.mainController.shiftUpOnDown() else controller.mainController.shiftUp() end"
        )
    end
end

local function shiftDown(vehID)
    local vehicle
    if vehID then
        local gameVehID = M.getGameVehicleID(BJIContext.User.playerID, vehID)
        vehicle = M.getVehicleObject(gameVehID)
    else
        -- fallback to current owned vehicle
        if not M.isCurrentVehicleOwn() then
            return
        end
        vehicle = M.getCurrentVehicleOwn()
    end
    if vehicle then
        vehicle:queueLuaCommand(
            "if controller.mainController.shiftDownOnDown then controller.mainController.shiftDownOnDown() else controller.mainController.shiftDown() end"
        )
    end
end

-- return the current vehicle model key
local function getCurrentModel()
    local veh = M.getCurrentVehicle()
    if not veh then
        return nil
    end

    return veh.JBeam
end

local function getDefaultModelAndConfig()
    local config = jsonReadFile("settings/default.pc")
    if config then
        return {
            model = config.model,
            config = config,
        }
    end
    return nil
end

local function isDefaultModelVehicle()
    local default = M.getDefaultModelAndConfig()
    return default and M.getAllVehicleConfigs(true, true)[default.model] ~= nil or false
end

local function saveCurrentVehicle()
    local veh = M.getCurrentVehicleOwn() or nil
    if veh or table.length(BJIContext.User.vehicles) > 0 then
        if not veh then
            local gameVehID
            for _, v in pairs(BJIContext.User.vehicles) do
                if not table.includes({ BJI_VEHICLE_TYPES.TRAILER, BJI_VEHICLE_TYPES.PROP }, M.getType(v.model)) then
                    gameVehID = v.gameVehID
                    break
                end
            end
            veh = gameVehID and M.getVehicleObject(gameVehID) or nil
        end
        if veh then
            BJIContext.User.previousVehConfig = M.getFullConfig(veh.partConfig)
        end
    end
end

---@param model? string
---@param withTechName? boolean
local function getModelLabel(model, withTechName)
    model = model or M.getCurrentModel()
    if type(model) ~= "string" then
        return nil
    end

    if not M.allVehicleConfigs then
        M.getAllVehicleConfigs()
    end

    local label
    if M.allVehicleLabels[model] then
        label = M.allVehicleLabels[model]
    elseif M.allTrailerLabels[model] then
        label = M.allTrailerLabels[model]
    elseif M.allPropLabels[model] then
        label = M.allPropLabels[model]
    end
    if label == model then
        return model
    elseif not withTechName then
        return label
    else
        return string.var("{1} - {2}", { model, label })
    end
end

---@param model string
---@param configKey string
local function getConfigLabel(model, configKey)
    if type(model) ~= "string" or type(configKey) ~= "string" then
        return "?"
    end

    local modelData = M.getAllVehicleConfigs(true, true)[model] or {}
    return (modelData.configs and modelData.configs[configKey]) and modelData.configs[configKey].label or "?"
end

-- config is optionnal
local function isConfigCustom(config)
    local veh = M.getCurrentVehicle()
    if not config and not veh then
        return false
    end

    config = config or veh.partConfig
    return not config:endswith(".pc")
end

local function isModelBlacklisted(model)
    return #BJIContext.Database.Vehicles.ModelBlacklist > 0 and
        table.includes(BJIContext.Database.Vehicles.ModelBlacklist, model)
end

--- return the full config raw data
---@param config? string|table
---@return table|nil
local function getFullConfig(config)
    local veh = M.getCurrentVehicle()
    if not config and not veh then
        return nil
    end

    config = config or veh.partConfig
    if isConfigCustom(config) then
        local fn = load(string.var("return {1}", { tostring(config):gsub("'", "") }))
        if type(fn) == "function" then
            local status, data = pcall(fn)
            return status and data or nil
        end
    else
        return jsonReadFile(config)
    end
end

---@param model string
---@return string?
local function getType(model)
    if not M.allVehicleConfigs then
        M.getAllVehicleConfigs()
    end

    if M.allVehicleConfigs[model] then
        return M.allVehicleConfigs[model].Type
    elseif M.allTrailerConfigs[model] then
        return M.allTrailerConfigs[model].Type
    elseif M.allPropConfigs[model] then
        return M.allPropConfigs[model].Type
    end
    return nil
end

local function isUnicycle(gameVehID)
    local veh = gameVehID and M.getVehicleObject(gameVehID) or M.getCurrentVehicle()
    if not veh then
        return false
    end

    return veh.partConfig:find("unicycle") ~= nil
end

local function getConfigByModelAndKey(model, configKey)
    return string.var("vehicles/{1}/{2}.pc", { model, configKey })
end

---@return string?
local function getCurrentConfigKey()
    local veh = M.getCurrentVehicle()
    if not veh or isConfigCustom() then
        return nil
    end

    return veh.partConfig:gsub("^vehicles/.*/", ""):gsub(".pc", "")
end

local function getCurrentConfigLabel()
    local veh = M.getCurrentVehicle()
    if not veh then
        return nil
    end
    local configKey = getCurrentConfigKey()

    if configKey then
        local model = M.getCurrentModel()
        local data = M.getAllVehicleConfigs(true, true)[model] or {}
        if data.configs and data.configs[configKey] then
            return data.configs[configKey].label
        end
        return nil
    end
    return "Custom"
end

-- vehicles banned from cache
local INVALID_VEHICLES = {
    "unicycle",
    "roof_crush_tester"
}
-- cache spawnable data
local function getAllVehicleConfigs(withTrailers, withProps, forced)
    if not forced and M.allVehicleConfigs then
        -- cached data
        local configs = table.clone(M.allVehicleConfigs)
        if withTrailers then
            for k, v in pairs(M.allTrailerConfigs) do
                configs[k] = table.clone(v)
            end
        end
        if withProps then
            for k, v in pairs(M.allPropConfigs) do
                configs[k] = table.clone(v)
            end
        end
        return configs
    end

    if not forced then
        -- first loading
        BJIMessage.message("Caching all vehicles...")
    end
    -- data gathering
    local vehicles = {}
    local trailers = {}
    local props = {}
    local vehs = core_vehicles.getVehicleList().vehicles
    for _, veh in ipairs(vehs) do
        if veh.model then
            local isVeh = true -- Truck | Car
            if table.includes({ BJI_VEHICLE_TYPES.TRAILER, BJI_VEHICLE_TYPES.PROP }, veh.model.Type) then
                isVeh = false
            end

            if isVeh and veh.model.preview == "/ui/images/appDefault.png" then
                -- not loaded vehicle
                goto skipVeh
            elseif table.includes(INVALID_VEHICLES, veh.model.key) then
                -- do not use
                goto skipVeh
            end

            local target
            if isVeh then
                target = vehicles
            elseif veh.model.Type == BJI_VEHICLE_TYPES.TRAILER then
                target = trailers
            elseif veh.model.Type == BJI_VEHICLE_TYPES.PROP then
                target = props
            end
            local brandPrefix = ""
            if veh.model.Brand then
                brandPrefix = string.var("{1} ", { veh.model.Brand })
            end
            local yearsPrefix = ""
            if veh.model.Years and veh.model.Years.min then
                yearsPrefix = string.var(" ({1})", { veh.model.Years.min })
            end

            target[veh.model.key] = table.clone(veh.model)
            table.assign(target[veh.model.key], {
                label = string.var("{1}{2}{3}", { brandPrefix, veh.model.Name, yearsPrefix }),
                custom = veh.model.aggregates.Source.Mod,
                paints = target[veh.model.key].paints or {},
                configs = {},
                preview = veh.model.preview,
            })

            local configs = target[veh.model.key].configs
            for key, config in pairs(veh.configs) do
                if config.key then
                    local label = (config.Configuration or config.key):gsub("_", " ")
                    if not label:lower():find("simple traffic") then
                        configs[key] = table.clone(config)
                        table.assign(configs[key], {
                            label = label,
                            custom = not target[veh.model.key].custom and
                                config.Source ~= "BeamNG - Official",
                        })
                    end
                end
            end
        end
        ::skipVeh::
    end
    M.allVehicleConfigs = vehicles
    M.allTrailerConfigs = trailers
    M.allPropConfigs = props

    -- LABELS
    M.allVehicleLabels = {}
    for model, d in pairs(vehicles) do
        M.allVehicleLabels[model] = d.label or model
    end
    M.allTrailerLabels = {}
    for model, d in pairs(trailers) do
        M.allTrailerLabels[model] = d.label or model
    end
    M.allPropLabels = {}
    for model, d in pairs(props) do
        M.allPropLabels[model] = d.label or model
    end

    if not forced then
        -- first loading
        BJIMessage.message("All vehicles cached !")
    end
    -- return cached data
    return M.getAllVehicleConfigs(withTrailers, withProps)
end

local function getAllVehicleLabels(withTrailers, withProps, forced)
    if forced or not M.allVehicleConfigs then
        M.getAllVehicleConfigs(false, false, true)
    end
    local labels = table.clone(M.allVehicleLabels)
    if withTrailers then
        for k, v in pairs(M.allTrailerLabels) do
            labels[k] = v
        end
    end
    if withProps then
        for k, v in pairs(M.allPropLabels) do
            labels[k] = v
        end
    end
    return labels
end

local function getAllTrailerConfigs(forced)
    if forced or not M.allVehicleConfigs then
        M.getAllVehicleConfigs(false, false, true)
    end
    return table.clone(M.allTrailerConfigs)
end

local function getAllPropConfigs(forced)
    if forced or not M.allVehicleConfigs then
        M.getAllVehicleConfigs(false, false, true)
    end
    return table.clone(M.allPropConfigs)
end

-- return all configs keys and labels for current vehicle
local function getAllConfigsForModel(model)
    if not model and not M.isCurrentVehicleOwn() then
        return {}
    end
    model = model or M.getCurrentModel()

    local data = M.getAllVehicleConfigs(true, true)[model]
    return (data or {}).configs or {}
end

-- return all paints labels and data for model (or current vehicle)
local function getAllPaintsForModel(model)
    if not model then
        if not M.isCurrentVehicleOwn() then
            return {}
        end
        model = M.getCurrentModel()
    end

    local data = M.getAllVehicleConfigs(true, true)[model]
    return (data or {}).paints or {}
end

---@param model string
---@param config? string|table
---@param posrot? BJIPositionRotation
local function replaceOrSpawnVehicle(model, config, posrot)
    local newVehicle = not M.isCurrentVehicleOwn()

    local opts = {}
    if config then
        opts.config = config
        if config.paints and config.paints[1] then
            opts.paint = config.paints[1]
        end
    end
    if posrot then
        opts.pos = posrot.pos
        opts.rot = posrot.rot * quat(0, 0, 1, 0) -- vehicles' forward is inverted
        if not newVehicle then
            M.setPositionRotation(opts.pos, opts.rot)
        end
    elseif not newVehicle and BJICam.getCamera() == BJICam.CAMERAS.FREE then
        local vehPos = M.getPositionRotation()
        if vehPos then
            opts.pos = vehPos.pos
            opts.rot = vehPos.rot * quat(0, 0, 1, 0) -- vehicles' forward is inverted
        end
    end
    if newVehicle then
        core_vehicles.spawnNewVehicle(model, opts)
    else
        core_vehicles.replaceVehicle(model, opts)
    end
    if BJICam.getCamera() == BJICam.CAMERAS.FREE then
        BJICam.toggleFreeCam()
    end
end

-- optionnal config and posrot
local function spawnNewVehicle(model, config, posrot)
    local opts = {}
    if config then
        opts.config = config
        if config.paints and config.paints[1] then
            opts.paint = config.paints[1]
        end
    end
    if posrot then
        opts.pos = posrot.pos
        opts.rot = posrot.rot * quat(0, 0, 1, 0) -- vehicles' forward is inverted
    end
    core_vehicles.spawnNewVehicle(model, opts)
    if BJICam.getCamera() == BJICam.CAMERAS.FREE then
        BJICam.toggleFreeCam()
    end
end

-- See M.getAllPaintsForModel for paint data
local function paintVehicle(paint, paintNumber)
    local veh = M.getCurrentVehicleOwn()
    if not veh or type(paint) ~= "table" then
        return
    end

    local config = M.getFullConfig(veh.partConfig)
    config = config or {}

    if not config.paints then
        config.paints = {}
    end
    if paintNumber == 2 then
        config.paints[2] = paint
    elseif paintNumber == 3 then
        config.paints[3] = paint
    else
        config.paints[1] = paint
    end

    core_vehicles.replaceVehicle(M.getCurrentModel(), { config = config, paint = paint })
end

local factorMJToReadable = {
    gasoline = 31.125,
    diesel = 36.112,
    kerosine = 34.4,
    n2o = 8.3,
    electricEnergy = 3.6,
}
---@param value number
---@param energyType string
---@return number
local function jouleToReadableUnit(value, energyType)
    if not energyType then
        error("jouleToReadableUnit requires energyType")
    elseif not factorMJToReadable[energyType] then
        error("jouleToReadableUnit unknown energyType " .. energyType)
    end
    return value / 1000000 / factorMJToReadable[energyType]
end

local lastConfig
local function onVehicleResetted(gameVehID)
    if M.isVehicleOwn(gameVehID) then
        local config = M.getFullConfig() or {}
        if not table.compare(config, lastConfig or {}, true) then
            -- detects veh edition
            for _, v in pairs(BJIContext.User.vehicles) do
                if v.gameVehID == gameVehID then
                    v.tanks = {}
                end
            end
        end
        lastConfig = config
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if oldGameVehID ~= -1 or newGameVehID ~= -1 then
        BJIEvents.trigger(BJIEvents.EVENTS.VEHICLE_SPEC_CHANGED, {
            self = true,
            playerID = BJIContext.User.playerID,
            previousGameVehID = oldGameVehID,
            previousOwner = M.getVehOwnerID(oldGameVehID),
            currentGameVehID = newGameVehID,
            currentOwner = M.getVehOwnerID(newGameVehID),
        })
    end
end

local function updateVehFuelState(ctxt, data)
    local tanks = {}
    for _, tank in ipairs(data[1]) do
        if tank.energyType ~= "air" then
            if ctxt.vehData.tanks and
                ctxt.vehData.tanks[tank.name] then
                if BJIScenario.isFreeroam() and
                    BJIContext.BJC.Freeroam.PreserveEnergy and
                    ctxt.vehData.tanks[tank.name].currentEnergy < tank.currentEnergy and
                    not BJIContext.User.stationProcess then
                    -- keep fuel amount after reset
                    M.setFuel(tank.name, ctxt.vehData.tanks[tank.name].currentEnergy)
                else
                    -- critical fuel amount trigger
                    if table.includes(BJI_ENERGY_STATION_TYPES, ctxt.vehData.tanks[tank.name].energyType) and
                        ctxt.vehData.tanks[tank.name].currentEnergy and
                        ctxt.vehData.tanks[tank.name].currentEnergy > tank.maxEnergy * M.tankLowThreshold and
                        tank.currentEnergy < tank.maxEnergy * M.tankLowThreshold then
                        BJISound.play(BJISound.SOUNDS.FUEL_LOW)
                    end

                    ctxt.vehData.tanks[tank.name].currentEnergy = tank.currentEnergy
                end
            end
            tanks[tank.name] = {
                energyType = tank.energyType,
                storageType = tank.storageType,
                currentEnergy = tank.currentEnergy,
                maxEnergy = tank.maxEnergy,
            }
        end
    end
    if not ctxt.vehData.tanks or
        not table.compare(table.keys(tanks), table.keys(ctxt.vehData.tanks)) then
        ctxt.vehData.tanks = tanks
        BJIEvents.trigger(BJIEvents.EVENTS.VEHDATA_UPDATED, ctxt.vehData)
    end
end

local function updateVehDamages(vehID, damageState)
    if BJIContext.User.vehicles[vehID] then
        BJIContext.User.vehicles[vehID].damageState = damageState
    end
end

local function slowTick(ctxt)
    if not ctxt.vehData then
        return
    end

    local vehID = ctxt.vehData and ctxt.vehData.vehID or nil

    -- get current fuel
    if core_vehicleBridge then
        -- update fuel
        core_vehicleBridge.requestValue(ctxt.veh, function(data)
            updateVehFuelState(ctxt, data)
        end, 'energyStorage')
    end

    -- get current damages
    if ctxt.veh then
        ctxt.veh:queueLuaCommand(string.var([[
                obj:queueGameEngineLua(
                    "BJIVeh.updateVehDamages({1}, " ..
                        serialize(beamstate.damage) ..
                    ")"
                )
        ]], { vehID }))
    end

    -- delete corrupted vehs
    for _, vehData in pairs(BJIContext.User.vehicles) do
        local v = M.getVehicleObject(vehData.gameVehID)
        if not v then
            BJITx.moderation.deleteVehicle(BJIContext.User.playerID, vehData.gameVehID)
        end
    end
end

local function setFuel(tankName, targetEnergy)
    if not M.isCurrentVehicleOwn() then
        return
    end

    local vehs = BJIContext.User.vehicles
    local vehID = BJIContext.User.currentVehicle and M.getVehIDByGameVehID(BJIContext.User.currentVehicle) or nil
    local vehData = (vehs and vehID) and vehs[vehID] or nil
    if vehData and vehData.tanks then
        local veh = M.getCurrentVehicle()
        local tank = vehData.tanks[tankName]
        if tank then
            core_vehicleBridge.executeAction(veh, 'setEnergyStorageEnergy', tankName,
                math.min(tank.maxEnergy, targetEnergy))
        end
    end
end

local function postResetPreserveEnergy(gameVehID)
    if not M.isCurrentVehicleOwn() or not M.isVehicleOwn(gameVehID) then
        return
    end

    local veh
    for _, v in pairs(BJIContext.User.vehicles) do
        if v.gameVehID ~= gameVehID then
            veh = v
            break
        end
    end
    if not veh then
        return
    end

    if veh and veh.tanks then
        local tanks = veh.tanks
        for tankName, tank in pairs(tanks) do
            local fuel = tank.currentEnergy
            BJIVeh.setFuel(tankName, fuel)
        end
    end
end

M.onLoad = onLoad
M.onUnload = onUnload

M.isGEInit = isGEInit
M.getMPVehicles = getMPVehicles
M.getMPOwnVehicles = getMPOwnVehicles
M.isVehReady = isVehReady

M.dropPlayerAtCamera = dropPlayerAtCamera
M.dropPlayerAtCameraNoReset = dropPlayerAtCameraNoReset

M.getCurrentVehicle = getCurrentVehicle
M.getVehicleObject = getVehicleObject
M.getRemoteVehID = getRemoteVehID
M.getGameVehIDByRemoteVehID = getGameVehIDByRemoteVehID
M.getVehOwnerID = getVehOwnerID
M.getVehIDByGameVehID = getVehIDByGameVehID
M.getGameVehicleID = getGameVehicleID

M.isVehicleOwn = isVehicleOwn
M.isCurrentVehicleOwn = isCurrentVehicleOwn
M.getCurrentVehicleOwn = getCurrentVehicleOwn
M.hasVehicle = hasVehicle

M.waitForVehicleSpawn = waitForVehicleSpawn
M.onVehicleSpawned = onVehicleSpawned

M.focus = focus
M.focusVehicle = focusVehicle
M.focusNextVehicle = focusNextVehicle
M.teleportToPlayer = teleportToPlayer
M.teleportToLastRoad = teleportToLastRoad
M.deleteOtherOwnVehicles = deleteOtherOwnVehicles
M.deleteAllOwnVehicles = deleteAllOwnVehicles
M.deleteCurrentOwnVehicle = deleteCurrentVehicle
M.deleteVehicle = deleteVehicle
M.deleteOtherPlayerVehicle = deleteOtherPlayerVehicle
M.explodeVehicle = explodeVehicle
M.saveHome = saveHome
M.loadHome = loadHome

M.getPositionRotation = getPositionRotation
M.setPositionRotation = setPositionRotation
M.stopCurrentVehicle = stopCurrentVehicle

M.freeze = freeze
M.engine = engine
M.lights = lights
M.setGear = setGear
M.shiftUp = shiftUp
M.shiftDown = shiftDown

M.getCurrentModel = getCurrentModel
M.getDefaultModelAndConfig = getDefaultModelAndConfig
M.isDefaultModelVehicle = isDefaultModelVehicle
M.saveCurrentVehicle = saveCurrentVehicle
M.getModelLabel = getModelLabel
M.getConfigLabel = getConfigLabel
M.isConfigCustom = isConfigCustom
M.isModelBlacklisted = isModelBlacklisted
M.getFullConfig = getFullConfig
M.getType = getType
M.isUnicycle = isUnicycle
M.getConfigByModelAndKey = getConfigByModelAndKey
M.getCurrentConfigKey = getCurrentConfigKey
M.getCurrentConfigLabel = getCurrentConfigLabel
M.getAllVehicleConfigs = getAllVehicleConfigs
M.getAllVehicleLabels = getAllVehicleLabels
M.getAllTrailerConfigs = getAllTrailerConfigs
M.getAllPropConfigs = getAllPropConfigs
M.getAllConfigsForModel = getAllConfigsForModel
M.getAllPaintsForModel = getAllPaintsForModel
M.replaceOrSpawnVehicle = replaceOrSpawnVehicle
M.spawnNewVehicle = spawnNewVehicle
M.paintVehicle = paintVehicle

M.jouleToReadableUnit = jouleToReadableUnit
M.setFuel = setFuel

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.slowTick = slowTick
M.updateVehDamages = updateVehDamages

M.postResetPreserveEnergy = postResetPreserveEnergy

RegisterBJIManager(M)
return M
