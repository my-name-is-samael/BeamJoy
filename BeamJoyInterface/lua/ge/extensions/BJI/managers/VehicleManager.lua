---@class BJIVehicleData
---@field vehID integer
---@field gameVehID integer
---@field finalGameVehID integer
---@field model string
---@field engine? boolean
---@field engineStation? boolean
---@field freeze? boolean
---@field freezeStation? boolean
---@field tanks? table<string, {energyType: string, storageType: string, maxEnergy: number, currentEnergy: number}>

---@class BJIPositionRotation
---@field pos vec3
---@field rot? quat

---@class BJIPositionRotationVelocity: BJIPositionRotation
---@field vel vec3
---@field gearbox {grb_bhv: string, grb_mde: string?, grb_idx: integer?}

---@class BJIManagerVeh : BJIManager
local M = {
    _name = "Veh",

    TYPES = {
        CAR = "Car",
        TRUCK = "Truck",
        TRAILER = "Trailer",
        PROP = "Prop",
    },

    FUEL_TYPES = {
        GASOLINE = "gasoline",
        DIESEL = "diesel",
        ELECTRIC = "electricEnergy",
        KEROSIN = "kerosine",
        N2O = "n2o",
    },

    modelTypeCache = {},

    baseFunctions = {},

    tankEmergencyRefuelThreshold = .02, -- threshold for when emergency refuel button appears
    tankLowThreshold = .05,             -- threshold for when fuel amount becomes critical + warning sound
    tankMedThreshold = .15,             -- threshold for when fuel amount becomes warning

    ---@type table<integer, BJIPositionRotation> index gameVehID
    homes = {},

    DEBUG_FFB_TIMEOUT = 1500,
}

--gameplay_walk.toggleWalkingMode()

local function isGEInit()
    return MPVehicleGE ~= nil
end

---@param model string
---@return boolean
local function isAi(model)
    return type(model) == "string" and model:lower():find("traffic") ~= nil
end

---@class BJIMPVehicle
---@field gameVehicleID integer
---@field veh NGVehicle
---@field isDeleted boolean
---@field isLocal boolean
---@field isSpawned boolean
---@field jbeam string
---@field ownerID integer
---@field ownerName string
---@field type string
---@field isVehicle boolean
---@field isAi boolean
---@field remoteVehID integer
---@field serverVehicleID integer
---@field serverVehicleString string format "<ownerID>-<serverVehicleID>"
---@field spectators table<integer, true>
---@field position vec3
---@field rotation quat
---@field vehicleHeight number
---@field protected boolean

local veh, pos, rot, vehicleHeight, specs, vehType

---@param mpVehRaw table
---@param light boolean?
---@return BJIMPVehicle
local function convertVehicle(mpVehRaw, light)
    veh = M.getVehicleObject(mpVehRaw.gameVehicleID)
    pos, rot, vehicleHeight = vec3(), quat(), 0
    if not light and mpVehRaw.isSpawned and not mpVehRaw.isDeleted then
        -- BeamMP vehicle positions are inconsistent, so compute them properly
        if veh then pos, rot = M.getPositionRotation(veh) end
        if veh then vehicleHeight = veh:getInitialHeight() end
    end
    specs = not light and BJI_Context.Players:reduce(function(res, p, pid)
        -- specs system remake because a lot of desyncs with default one
        if p.currentVehicle == (BJI_Context.isSelf(mpVehRaw.ownerID) and
                mpVehRaw.gameVehicleID or mpVehRaw.remoteVehID) then
            res[pid] = true
        end
        return res
    end, {}) or {}
    vehType = M.getType(mpVehRaw.jbeam)
    return {
        gameVehicleID = mpVehRaw.gameVehicleID,
        veh = veh,
        isDeleted = mpVehRaw.isDeleted,
        isLocal = mpVehRaw.isLocal,
        isSpawned = mpVehRaw.isSpawned,
        jbeam = mpVehRaw.jbeam,
        ownerID = mpVehRaw.ownerID,
        ownerName = mpVehRaw.ownerName,
        type = vehType,
        isVehicle = mpVehRaw.jbeam ~= "unicycle" and
            not table.includes({ M.TYPES.TRAILER, M.TYPES.PROP }, vehType),
        isAi = isAi(mpVehRaw.jbeam),
        remoteVehID = mpVehRaw.remoteVehID,
        serverVehicleID = mpVehRaw.serverVehicleID,
        serverVehicleString = mpVehRaw.serverVehicleString,
        spectators = specs,
        protected = mpVehRaw.protected == "1",
        position = pos,
        rotation = rot,
        vehicleHeight = vehicleHeight
    }
end

---@param filters {ownerID: integer?, isAi: boolean?, model: string?}?
---@param light boolean?
---@return tablelib<integer, BJIMPVehicle> index 1-N
local function getMPVehicles(filters, light)
    filters = filters or {}
    return Table(MPVehicleGE.getVehicles())
        :filter(function(v) return v.isSpawned and not v.isDeleted end)
        :filter(function(v)
            if filters.ownerID and v.ownerID ~= filters.ownerID then
                return false
            end
            if filters.isAi ~= nil and filters.isAi ~= isAi(v.jbeam) then
                return false
            end
            if filters.model and v.jbeam ~= filters.model then
                return false
            end
            return true
        end)
        :map(function(v) return convertVehicle(v, light) end):values()
end

---@param light boolean?
---@return tablelib<integer, BJIMPVehicle>
local function getMPOwnVehicles(light)
    return Table(MPVehicleGE.getOwnMap())
        :filter(function(v) return v.isSpawned and not v.isDeleted end)
        :map(function(v) return convertVehicle(v, light) end):values()
end

---@param gameVehID integer
---@param own boolean?
---@param light boolean?
---@return BJIMPVehicle?
local function getMPVehicle(gameVehID, own, light)
    local selfID = BJI_Context.User.playerID
    local res = Table(MPVehicleGE.getVehicles())
        :filter(function(v) return v.isSpawned and not v.isDeleted end)
        :find(function(v)
            if own ~= nil then
                if own and v.ownerID ~= selfID then
                    return false
                elseif not own and v.ownerID == selfID then
                    return false
                end
            end
            return v.gameVehicleID == gameVehID
        end)
    if res then
        return convertVehicle(res, light)
    end
end

local function dropPlayerAtCamera(withReset)
    if M.isCurrentVehicleOwn() and
        BJI_Cam.getCamera() ~= BJI_Cam.CAMERAS.BIG_MAP then
        local previousCam = BJI_Cam.getCamera()
        local camPosRot = BJI_Cam.getPositionRotation(false)
        camPosRot.rot = camPosRot.rot * quat(0, 0, 1, 0) -- vehicles' forward is inverted

        M.setPositionRotation(camPosRot.pos, camPosRot.rot, {
            safe = false,
            saveHome = true,
            noReset = not withReset,
        })

        if previousCam == BJI_Cam.CAMERAS.FREE then
            BJI_Cam.setCamera(BJI_Cam.CAMERAS.ORBIT)
            core_camera.resetCamera(0)
        end
    end
end

---@return NGVehicle?
local function getCurrentVehicle()
    return getPlayerVehicle(0)
end

---@param gameVehID integer?
---@return NGVehicle?
local function getVehicleObject(gameVehID)
    gameVehID = tonumber(gameVehID)
    if not gameVehID then
        return
    end
    local veh = be:getObjectByID(gameVehID)
    if not veh then
        ---@type BJIMPVehicle?
        local remote = M.getMPVehicles():find(function(v)
            return v.remoteVehID == gameVehID
        end)
        return remote and remote.veh or nil
    end
    return veh
end

---@param gameVehID integer
---@return integer?
local function getRemoteVehID(gameVehID)
    local veh = M.getMPVehicle(gameVehID)
    if veh and veh.remoteVehID ~= -1 then
        return veh.remoteVehID
    end
end

---@param remoteVehID integer
---@return integer?
local function getGameVehIDByRemoteVehID(remoteVehID)
    local veh = M.getMPVehicles():find(function(v)
        return v.remoteVehID == remoteVehID
    end)
    if veh then
        return veh.gameVehicleID
    end
end

---@param gameVehID integer
---@return integer?
local function getVehOwnerID(gameVehID)
    local veh = M.getMPVehicle(gameVehID)
    if veh then
        return veh.ownerID
    end
end

---@param gameVehID integer
---@return integer?
local function getVehIDByGameVehID(gameVehID)
    local veh = M.getMPVehicle(gameVehID)
    if veh then
        return veh.serverVehicleID
    end
end

---@param playerID integer
---@param vehID integer?
---@return integer?
local function getGameVehicleID(playerID, vehID)
    local srvVehID = string.var("{1}-{2}", { playerID, vehID or 0 })
    return MPVehicleGE.getGameVehicleID(srvVehID)
end

---@param gameVehID integer
---@return boolean
local function isVehProtected(gameVehID)
    local veh = M.getMPVehicle(gameVehID)
    return veh and veh.protected or false
end

local function getSelfVehiclesCount()
    return Table(M.getMPOwnVehicles())
        ---@param v BJIMPVehicle
        :filter(function(v)
            return v.jbeam ~= "unicycle" and not v.isAi
        end):length()
end

---@param gameVehID integer
---@return boolean
local function isVehicleOwn(gameVehID)
    return MPVehicleGE.isOwn(gameVehID)
end

---@return boolean
local function isCurrentVehicleOwn()
    local vehicle = M.getCurrentVehicle()
    if vehicle then
        return M.isVehicleOwn(vehicle:getID())
    elseif BJI_Context.User.currentVehicle then
        return M.isVehicleOwn(BJI_Context.User.currentVehicle)
    end
    return false
end

---@return NGVehicle?
local function getCurrentVehicleOwn()
    local veh = M.getCurrentVehicle()
    if veh and M.isVehicleOwn(veh:getID()) and M.isGEInit() then
        return veh
    end
end

local function hasVehicle()
    return table.length(MPVehicleGE.getOwnMap()) > 0
end

local function isVehReady(gameVehID)
    local veh = MPVehicleGE.getOwnMap()[gameVehID]
    return veh and veh.isSpawned and not veh.isDeleted
end

---@param callback fun(ctxt: TickContext)
local function waitForVehicleSpawn(callback)
    local delay = GetCurrentTimeMillis() + 200
    local timeout = delay + 20000
    BJI_Async.task(function(ctxt)
        if ctxt.now >= timeout then
            LogError("Vehicle spawn wait timeout")
            return true
        end
        if ctxt.now > delay and ui_imgui.GetIO().Framerate > 5 and ctxt.veh ~= nil then
            if M.isUnicycle(ctxt.veh.gameVehicleID) then
                return true
            end
            local damages = ctxt.veh and tonumber(ctxt.veh.veh.damageState) or nil
            if damages == nil or damages >= BJI_Context.VehiclePristineThreshold then
                return false
            end
            local speed = ctxt.veh and tonumber(ctxt.veh.veh.speed) or nil
            if speed == nil or speed > .5 then
                return false
            end
            return isVehReady(ctxt.veh.gameVehicleID)
        end
        return false
    end, callback, string.var("BJIVehSpawnCallback-{1}", { delay }))
end

---@param config string|table
local function isVehPolice(config)
    local policeMarkers = Table({ "police", "polizei", "polizia", "gendarmerie" })
    local conf = BJI_Veh.getFullConfig(config) or { parts = {} }
    return policeMarkers:any(function(str) return conf.model:lower():find(str) ~= nil end) or
        Table(conf.parts):any(function(v, k)
            return policeMarkers:any(function(str)
                return (tostring(k):lower():find(str) ~= nil and #v > 0) or
                    tostring(v):lower():find(str) ~= nil
            end)
        end)
end

---@param gameVehID integer
local function onVehicleSpawned(gameVehID)
    local timeout = GetCurrentTimeMillis() + 1000
    BJI_Async.task(function(ctxt)
        return ctxt.now > timeout or
            Table(MPVehicleGE.getVehicles()):any(function(v) return v.gameVehicleID == gameVehID end)
    end, function()
        local mpVeh = M.getMPVehicle(gameVehID)
        if not mpVeh then
            error("Invalid vehicle spawned " .. tostring(gameVehID))
        end
        mpVeh.veh:queueLuaCommand('extensions.BeamJoyInterface_BJIPhysics.update()')
        if mpVeh.isLocal then
            mpVeh.veh:queueLuaCommand(
                "recovery.saveHome = function() obj:queueGameEngineLua('BJI_Scenario.saveHome('..tostring(obj:getID())..')') end")
            mpVeh.veh:queueLuaCommand(
                "recovery.loadHome = function() obj:queueGameEngineLua('BJI_Scenario.loadHome('..tostring(obj:getID())..')') end")
        end

        -- also works for vehicle replacement
        if isVehPolice(mpVeh.veh.partConfig) then
            mpVeh.veh:setDynDataFieldbyName("isPatrol", 0, "true")
        else
            mpVeh.veh:setDynDataFieldbyName("isPatrol", 0, "")
        end

        if mpVeh.jbeam == "unicycle" and not mpVeh.isLocal then
            mpVeh.veh.playerUsable = false
        elseif mpVeh.isAi then
            mpVeh.veh.uiState = 0
            mpVeh.veh.playerUsable = false
        end
        BJI_Events.trigger(BJI_Events.EVENTS.VEHICLE_INITIALIZED, mpVeh)
        BJI_Restrictions.update()
    end)
end

---@param gameVehID integer
local function onVehicleDestroyed(gameVehID)
    M.homes[gameVehID] = nil
    BJI_Restrictions.update()
end

---@param playerID integer
local function focus(playerID)
    local player = BJI_Context.Players[playerID]
    veh = (player and player.currentVehicle) and M.getVehicleObject(player.currentVehicle) or nil
    if veh then
        be:enterVehicle(0, veh)
        -- _vehGE.focusCameraOnPlayer(playerName)
        if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
            BJI_Cam.setCamera(BJI_Cam.CAMERAS.ORBIT, true)
        end
    end
end

---@param gameVehID integer
local function focusVehicle(gameVehID)
    veh = M.getVehicleObject(gameVehID)
    if veh then
        be:enterVehicle(0, veh)
        if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
            BJI_Cam.setCamera(BJI_Cam.CAMERAS.ORBIT, true)
        end
    end
end

local function focusNextVehicle()
    be:enterNextVehicle(0, 1)
end

---@param data {veh: NGVehicle?, gameVehID: integer?, state: boolean?}
local function toggleVehicleFocusable(data)
    if not data.veh and not data.gameVehID then
        error("Invalid vehicle")
        return
    end

    veh = M.getVehicleObject(data.veh and data.veh:getID() or data.gameVehID)
    if not veh or BJI_AI.isAIVehicle(veh:getID()) then
        error("Invalid vehicle")
        return
    end

    if data.state == nil then
        data.state = not veh.playerUsable
    end
    veh.playerUsable = data.state

    if not data.state then
        local currVeh = M.getCurrentVehicle()
        if currVeh and currVeh:getID() == veh:getID() then
            focusNextVehicle()
        end
    end
end

---@param targetID integer
local function teleportToPlayer(targetID)
    if not M.isCurrentVehicleOwn() then
        return
    end

    local target = BJI_Context.Players[targetID]
    local destVeh = target and M.getVehicleObject(target.currentVehicle) or nil
    if not target or not destVeh then
        LogError("Invalid target player or vehicle")
        return
    end

    -- old
    -- MPVehicleGE.teleportVehToPlayer(target.playerName)

    local pos, rot
    if destVeh then
        pos, rot = M.getPositionRotation(destVeh)
    end
    if pos and rot then
        M.setPositionRotation(pos, rot)
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
    local vehs = BJI_Context.User.vehicles
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
    BJI_AI.stopTraffic()
end

local function deleteAllOwnVehicles()
    M.saveCurrentVehicle()
    local vehs = BJI_Context.User.vehicles
    if table.length(vehs) > 0 then
        for _, veh in pairs(vehs) do
            local v = M.getVehicleObject(veh.gameVehID)
            if v then
                v:delete()
            end
        end
    end
    BJI_AI.stopTraffic()
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
---@param gameVehID integer
local function explodeVehicle(gameVehID)
    local mpVeh = M.getMPVehicle(gameVehID)
    if mpVeh then
        if mpVeh.isLocal then -- throw up a bit
            mpVeh.veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 1, 0, 0, 3)
        end
        mpVeh.veh:queueLuaCommand("fire.explodeVehicle()")
        BJI_Async.delayTask(function()
            mpVeh.veh:queueLuaCommand("beamstate.breakAllBreakgroups()")
        end, BJI_VEHICLE_EXPLODE_HINGES_DELAY, string.var("ExplodeVehicle{1}", { mpVeh.gameVehicleID }))
    end
end

---@param posRot? BJIPositionRotation
local function saveHome(posRot)
    veh = M.getCurrentVehicleOwn()
    if veh then
        local finalPoint = {}
        if posRot then
            finalPoint = {
                pos = vec3(posRot.pos),
                rot = quat(posRot.rot),
            }
        else
            finalPoint.pos, finalPoint.rot = M.getPositionRotation(veh)
        end
        M.homes[veh:getID()] = finalPoint
        if BJI_Scenario.isFreeroam() and finalPoint then
            guihooks.message("vehicle.recovery.saveHome", 5, "recovery")
        end
    end
end

---@param callback? fun(ctxt: TickContext)
local function loadHome(callback)
    veh = M.getCurrentVehicleOwn()
    if veh and M.homes[veh:getID()] then
        local home = M.homes[veh:getID()]
        veh:requestReset(RESET_PHYSICS)
        local pos, rot = vec3(home.pos) + vec3(0, 0, veh:getInitialHeight() / 2), quat(home.rot)
        M.setPositionRotation(pos, rot)
        if BJI_Scenario.isFreeroam() then
            guihooks.message("vehicle.recovery.loadHome", 5, "recovery")
        end
        if type(callback) == "function" then
            waitForVehicleSpawn(callback)
        end
    end
end

---@param callback? fun(ctxt: TickContext)
local function recoverInPlace(callback)
    veh = M.getCurrentVehicleOwn()
    if veh then
        veh:queueLuaCommand("recovery.recoverInPlace()")
        if type(callback) == "function" then
            waitForVehicleSpawn(callback)
        end
    end
end

---@param veh NGVehicle?
---@param callback fun(pos: vec3, rot: quat)?
---@return vec3?, quat?
local function getPositionRotation(veh, callback)
    if not veh then
        veh = M.getCurrentVehicle()
    end

    if veh then
        local nodeId = veh:getRefNodeId()
        pos = vec3(be:getObjectOOBBCenterXYZ(veh:getID())) -
            veh:getDirectionVectorUp() * veh:getInitialHeight() / 2 -- center at ground
        rot = quat(veh:getClusterRotationSlow(nodeId))

        local res = math.roundPositionRotation({ pos = pos, rot = rot })
        if type(callback) == "function" then
            callback(res.pos, res.rot)
        end
        return res.pos, res.rot
    end
    return nil
end

---@param veh NGVehicle?
---@param callback fun(posRotVel: BJIPositionRotationVelocity)
local function getPosRotVel(veh, callback)
    if not veh then
        veh = M.getCurrentVehicle()
    end
    if veh then
        local pos, rot = M.getPositionRotation(veh)
        ---@type table
        local res = math.roundPositionRotation({ pos = pos or vec3(), rot = rot })
        local vel = vec3(veh:getVelocity())
        ---@type table
        table.assign(res, {
            vel = vec3(
                math.round(vel.x, 2),
                math.round(vel.y, 2),
                math.round(vel.z, 2)
            )
        })
        ---@param bhv string
        ---@param mde string
        ---@param idx string
        M.TMP_SET_GEARBOX = function(bhv, mde, idx)
            res.gearbox = {
                grb_bhv = bhv,
                grb_mde = #mde > 0 and mde or nil,
                grb_idx = #idx > 0 and tonumber(idx) or nil,
            }
            M.TMP_SET_GEARBOX = nil
            callback(res)
        end
        veh:queueLuaCommand([[
            local state = controller.mainController.getState()
            obj:queueGameEngineLua("BJI_Veh.TMP_SET_GEARBOX('"..state.grb_bhv.."', '"..(state.grb_mde or "").."', '"..(tostring(state.grb_idx) or "").."')")
        ]])
    end
end

---@param pos vec3
---@param rot? quat DEFAULT to currentVeh:rot
---@param options? { safe?: boolean, saveHome?: boolean, noReset?: boolean } safe default true, noReset default false
local function setPositionRotation(pos, rot, options)
    if not pos then
        return
    end
    local _
    pos = vec3(pos)
    if not rot then
        _, rot = M.getPositionRotation()
        rot = rot or quat(0, 0, 0, 0)
    else
        rot = quat(rot)
    end
    -- default values
    if not options then options = { safe = true } end
    if options.safe == nil then options.safe = true end

    veh = M.getCurrentVehicleOwn()
    if veh then
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
            M.saveHome()
        end
    end
end

-- TO REWORK : BREAKS GEARBOX with some modes
---@param posRotVel BJIPositionRotationVelocity
local function setPosRotVel(posRotVel)
    local veh = M.getCurrentVehicleOwn()
    if veh then
        M.TMP_GET_FFB = function(ffb)
            local previousSmoothing = ffb.smoothing
            local previousForce = ffb.forceCoef
            ffb.smoothing = ffb.smoothing * 2
            ffb.forceCoef = ffb.forceCoef / 2
            getPlayerVehicle(0):queueLuaCommand([[
                hydros.setFFBConfig({
                    forceCoef=]] .. tostring(ffb.forceCoef) .. [[,
                    gforceCoef=]] .. tostring(ffb.gforceCoef) .. [[,
                    smoothing=]] .. tostring(ffb.smoothing) .. [[,
                    smoothing2=]] .. tostring(ffb.smoothing2) .. [[,
                    smoothing2automatic=]] .. tostring(ffb.smoothing2automatic) .. [[,
                    softlockForce=]] .. tostring(ffb.softlockForce) .. [[
                })
            ]]);

            M.setPositionRotation(posRotVel.pos, posRotVel.rot, { safe = false })
            veh:resetBrokenFlexMesh()
            veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 0, 0, 0, 0)
            veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 1, posRotVel.vel.x, posRotVel.vel.y, posRotVel.vel.z)
            local cmd = [[controller.mainController.setState({]] ..
                Table(posRotVel.gearbox):map(function(v, k)
                    if type(v) == "string" then
                        return string.var('{1}="{2}"', { k, v })
                    else
                        return string.var("{1}={2}", { k, v })
                    end
                end):join(",") ..
                "})"
            veh:queueLuaCommand(cmd)

            BJI_Async.delayTask(function()
                ffb.smoothing = previousSmoothing
                ffb.forceCoef = previousForce
                getPlayerVehicle(0):queueLuaCommand([[
                hydros.setFFBConfig({
                    forceCoef=]] .. tostring(ffb.forceCoef) .. [[,
                    gforceCoef=]] .. tostring(ffb.gforceCoef) .. [[,
                    smoothing=]] .. tostring(ffb.smoothing) .. [[,
                    smoothing2=]] .. tostring(ffb.smoothing2) .. [[,
                    smoothing2automatic=]] .. tostring(ffb.smoothing2automatic) .. [[,
                    softlockForce=]] .. tostring(ffb.softlockForce) .. [[
                })
            ]]);
            end, 1500)

            M.TMP_GET_FFB = nil
        end

        local params = Table({
            'forceCoef="..tostring(ffb.forceCoef).."',
            'gforceCoef="..tostring(ffb.gforceCoef).."',
            'smoothing="..tostring(ffb.smoothing).."',
            'smoothing2="..tostring(ffb.smoothing2).."',
            'smoothing2automatic="..tostring(ffb.smoothing2automatic).."',
            'softlockForce="..tostring(ffb.softlockForce).."',
        }):join(",")
        getPlayerVehicle(0):queueLuaCommand([[
            local ffb = hydros.getFFBConfig()
            obj:queueGameEngineLua("BJI_Veh.TMP_GET_FFB({]] .. params .. [[})")
        ]]);
    end
end


---@param mpVeh BJIMPVehicle
local function stopVehicle(mpVeh)
    if mpVeh.isLocal then
        mpVeh.veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 0, 0, 0, 0)
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
            BJI_Async.delayTask(function()
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
        local gameVehID = M.getGameVehicleID(BJI_Context.User.playerID, vehID)
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
        local gameVehID = M.getGameVehicleID(BJI_Context.User.playerID, vehID)
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
        local gameVehID = M.getGameVehicleID(BJI_Context.User.playerID, vehID)
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
---@return string?
local function getCurrentModel()
    local veh = M.getCurrentVehicle()
    if not veh then
        return nil
    end

    return veh.jbeam
end

---@return {model: string, config: ClientVehicleConfig}?
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

---@return boolean
local function isDefaultModelVehicle()
    local default = M.getDefaultModelAndConfig()
    return default and M.getAllVehicleConfigs(true, true)[default.model] ~= nil or false
end

local function saveCurrentVehicle()
    local veh = M.getCurrentVehicleOwn() or nil
    if veh or table.length(BJI_Context.User.vehicles) > 0 then
        if not veh then
            local gameVehID
            for _, v in pairs(BJI_Context.User.vehicles) do
                if not table.includes({ M.TYPES.TRAILER, M.TYPES.PROP }, M.getType(v.model)) then
                    gameVehID = v.gameVehID
                    break
                end
            end
            veh = gameVehID and M.getVehicleObject(gameVehID) or nil
        end
        if veh then
            BJI_Context.User.previousVehConfig = M.getFullConfig(veh.partConfig)
            if BJI_Context.User.previousVehConfig and
                not BJI_Context.User.previousVehConfig.model then
                -- a very low amount of configs have no model, don't know why
                LogWarn("Last vehicle doesn't have model in its config, safe adding it")
                BJI_Context.User.previousVehConfig.model = veh.jbeam
            end
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
---@param config string?
---@return boolean
local function isConfigCustom(config)
    local veh = M.getCurrentVehicle()
    if not config and not veh then
        return false
    end

    config = config or (veh and veh.partConfig or "")
    return not config:endswith(".pc")
end

---@param model string
---@return boolean
local function isModelBlacklisted(model)
    return #BJI_Context.Database.Vehicles.ModelBlacklist > 0 and
        table.includes(BJI_Context.Database.Vehicles.ModelBlacklist, model)
end

---@param tree table
---@return table<string, string>
local function convertPartsTree(tree)
    local parts = {}
    local function recursParts(data)
        for k, v in pairs(data) do
            if v.chosenPartName then
                parts[k] = v.chosenPartName
            end
            if v.children then
                recursParts(v.children)
            end
        end
    end
    local start = GetCurrentTimeMillis()
    recursParts(tree.children)
    LogWarn(string.var("Converted manually modified veh config to standard parts in {1}ms",
        { GetCurrentTimeMillis() - start }))
    return parts
end

--- return the full config raw data
---@param config? string|table
---@return ClientVehicleConfig?
local function getFullConfig(config)
    local veh = M.getCurrentVehicle()
    if not config and not veh then
        return nil
    end

    config = config or (veh and veh.partConfig or "")
    local res, status
    if isConfigCustom(tostring(config)) then
        local fn = load(string.var("return {1}", { tostring(config):gsub("'", "") }))
        if type(fn) == "function" then
            status, res = pcall(fn)
            if not status then
                return nil
            end
            if res.partsTree then -- vehicle has been manually modified = > simplify parts
                res.parts = convertPartsTree(res.partsTree)
                res.partsTree = nil
            end
            res.label = M.getModelLabel(res.model)
        end
    else
        res = jsonReadFile(config)
        res.key = tostring(config):gsub("^vehicles/.*/", ""):gsub("%.pc$", "")
        if not res.model then
            -- some configs are malformed and do not have model value (eg barstow-awful)
            res.model = tostring(config):gsub("^vehicles/", ""):gsub("/.+%.pc$", "")
        end
        res.label = string.var("{1} {2}", { M.getModelLabel(res.model),
            M.getConfigLabel(res.model, res.key) })
    end

    return res
end

---@param gameVehID integer
---@return tablelib<integer, integer> attachedVehiclesIDs index 1-N, value gameVehID
local function findAttachedVehicles(gameVehID)
    local res = Table()
    local function _processAttached(vehData, level)
        level = level or 0
        if level > 10 then return end
        if vehData.vehId ~= gameVehID and
            not res:includes(vehData.vehId) then
            res:insert(vehData.vehId)
        end
        if vehData.children and #vehData.children > 0 then
            for _, c in ipairs(vehData.children) do
                _processAttached(c, level + 1)
            end
        end
    end
    _processAttached(core_vehicles.generateAttachedVehiclesTree(gameVehID))
    return res
end

---@param model string
---@return string?
local function getType(model)
    if M.modelTypeCache[model] then
        return M.modelTypeCache[model]
    end

    if not M.allVehicleConfigs then
        M.getAllVehicleConfigs()
    end

    local finalType
    if M.allVehicleConfigs[model] then
        finalType = M.allVehicleConfigs[model].Type
    elseif M.allTrailerConfigs[model] then
        finalType = M.allTrailerConfigs[model].Type
    elseif M.allPropConfigs[model] then
        finalType = M.allPropConfigs[model].Type
    end
    M.modelTypeCache[model] = finalType
    return finalType
end

---@param gameVehID integer?
---@return boolean
local function isUnicycle(gameVehID)
    local veh = gameVehID and M.getVehicleObject(gameVehID) or M.getCurrentVehicle()
    if not veh then
        return false
    end

    return veh.partConfig:find("unicycle") ~= nil
end

---@param model string
---@param configKey string
---@return string
local function getConfigByModelAndKey(model, configKey)
    return string.var("vehicles/{1}/{2}.pc", { model, configKey })
end

---@return string?
local function getCurrentConfigKey()
    veh = M.getCurrentVehicle()
    if not veh or isConfigCustom() then
        return nil
    end

    local res = veh.partConfig:gsub("^vehicles/.*/", ""):gsub(".pc", "")
    return res
end

---@return string?
local function getCurrentConfigLabel()
    veh = M.getCurrentVehicle()
    if not veh then return end
    local configKey = getCurrentConfigKey()

    if configKey then
        local model = M.getCurrentModel()
        local data = M.getAllVehicleConfigs(true, true)[model] or {}
        if data.configs and data.configs[configKey] then
            return data.configs[configKey].label
        end
        return
    end
    return "Custom"
end

-- vehicles banned from cache
local INVALID_VEHICLES = {
    "unicycle",
    "roof_crush_tester"
}
-- cache spawnable data
---@param withTrailers boolean?
---@param withProps boolean?
---@param forced boolean?
local function getAllVehicleConfigs(withTrailers, withProps, forced)
    if not forced and M.allVehicleConfigs then
        -- cached data
        local configs = table.clone(M.allVehicleConfigs)
        if withTrailers then
            table.assign(configs, Table(M.allTrailerConfigs):clone())
        end
        if withProps then
            table.assign(configs, Table(M.allPropConfigs):clone())
        end
        return configs
    end

    if not forced then
        -- first loading
        BJI_Message.message("Caching all vehicles...")
    end
    -- data gathering
    local vehicles = {}
    local trailers = {}
    local props = {}
    local bench = {
        all = 0,
        gather = 0,
        checkModded = 0,
        parse = 0,
        labels = 0,
    }
    local start = GetCurrentTimeMillis()
    bench.all = start
    local vehs = core_vehicles.getVehicleList().vehicles
    bench.gather = GetCurrentTimeMillis() - start
    for _, veh in ipairs(vehs) do
        if veh.model then
            local isVeh = true -- Truck | Car
            if not M.modelTypeCache[veh.model.key] then
                M.modelTypeCache[veh.model.key] = veh.model.Type
            end
            if table.includes({ M.TYPES.TRAILER, M.TYPES.PROP }, M.modelTypeCache[veh.model.key]) then
                isVeh = false
            end

            if table.includes(INVALID_VEHICLES, veh.model.key) or
                veh.model.key:find("traffic") then
                -- do not use
                goto skipVeh
            end

            start = GetCurrentTimeMillis()
            if veh.model.aggregates.Source.Mod then
                local jbeamIO = require('jbeam/io')
                local function tryLoadVeh()
                    if not jbeamIO.getMainPartName(jbeamIO.startLoading({
                            string.var("/vehicles/{1}/", { veh.model.key }),
                            "/vehicles/common/"
                        })) then
                        error()
                    end
                end
                if not pcall(tryLoadVeh) then
                    -- vehicle lot loaded
                    goto skipVeh
                end
            end
            bench.checkModded = bench.checkModded + (GetCurrentTimeMillis() - start)

            start = GetCurrentTimeMillis()
            local target
            if isVeh then
                target = vehicles
            elseif veh.model.Type == M.TYPES.TRAILER then
                target = trailers
            elseif veh.model.Type == M.TYPES.PROP then
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
                    if not config.key:lower():endswith("_parked") then
                        configs[key] = table.clone(config)
                        table.assign(configs[key], {
                            label = label,
                            custom = not target[veh.model.key].custom and
                                config.Source ~= "BeamNG - Official",
                        })
                    end
                end
            end
            bench.parse = bench.parse + (GetCurrentTimeMillis() - start)
        end
        ::skipVeh::
    end
    M.allVehicleConfigs = vehicles
    M.allTrailerConfigs = trailers
    M.allPropConfigs = props

    -- LABELS
    start = GetCurrentTimeMillis()
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
    bench.labels = GetCurrentTimeMillis() - start
    bench.all = GetCurrentTimeMillis() - bench.all

    BJI_Async.delayTask(function()
        LogInfo("BJI Vehicles Configurations Bechmark :")
        LogInfo(string.var("    Vehicles gathered in {1}ms", { bench.gather }))
        LogInfo(string.var("    Modded vehicles checked in {1}ms", { bench.checkModded }))
        LogInfo(string.var("    Data parsed in {1}ms", { bench.parse }))
        LogInfo(string.var("    Complete process done in {1}ms", { bench.all }))
    end, 0, "VehConfigsCacheBench")

    if not forced then
        -- first loading
        BJI_Message.message("All vehicles cached !")
    else
        -- update potentially already opened veh selector
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
    end
    -- return cached data
    return M.getAllVehicleConfigs(withTrailers, withProps)
end

---@param withTrailers? boolean
---@param withProps? boolean
---@param forced? boolean
---@return table<string, string>
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

---@return table<string, NGPaint>
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
    if M.getCurrentModel() == "unicycle" then
        -- replace walking case
        M.deleteCurrentOwnVehicle()
        return BJI_Async.delayTask(function()
            M.replaceOrSpawnVehicle(model, config, posrot)
        end, 100)
    end

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
    elseif not newVehicle and BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
        local pos, rot = M.getPositionRotation()
        if pos and rot then
            opts.pos = pos
            opts.rot = rot * quat(0, 0, 1, 0) -- vehicles' forward is inverted
        end
    end
    if newVehicle then
        core_vehicles.spawnNewVehicle(model, opts)
    else
        core_vehicles.replaceVehicle(model, opts)
    end
    if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
        BJI_Cam.toggleFreeCam()
    end
end

-- optionnal config and posrot
local function spawnNewVehicle(model, config, posrot)
    if M.getCurrentModel() == "unicycle" then
        -- spawn veh when walking case
        M.deleteCurrentOwnVehicle()
        return BJI_Async.delayTask(function()
            M.spawnNewVehicle(model, config, posrot)
        end, 100)
    end

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
    if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
        BJI_Cam.toggleFreeCam()
    end
end

-- flags to prevent sound spamming
local paintSoundProcess

---@param veh NGVehicle
---@param paintIndex integer 1-3
---@param paint NGPaint
local function paintVehicle(veh, paintIndex, paint)
    veh = veh or M.getCurrentVehicleOwn()
    if not veh or type(paint) ~= "table" then
        return
    end

    paintIndex = paintIndex == math.clamp(paintIndex or 0, 1, 3) and paintIndex or 1
    extensions.core_vehicle_manager.liveUpdateVehicleColors(veh:getID(), veh, paintIndex, paint)

    local currentVehicle = M.getCurrentVehicle()
    if not paintSoundProcess and currentVehicle and
        currentVehicle:getID() == veh:getID() and
        BJI_Cam.getCamera() ~= BJI_Cam.CAMERAS.FREE then
        BJI_Sound.play(BJI_Sound.SOUNDS.PAINT)
        paintSoundProcess = true
        BJI_Async.delayTask(function()
            paintSoundProcess = nil
        end, 3000, string.var("paintSoundProcess-{1}", { veh:getID() }))
    end
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
    local veh = M.getCurrentVehicleOwn()
    if veh and veh:getID() == gameVehID then
        local config = M.getFullConfig() or {}
        if not table.compare(config, lastConfig or {}, true) then
            -- detects veh edition
            for _, v in pairs(BJI_Context.User.vehicles) do
                if v.gameVehID == gameVehID then
                    v.tanks = {}
                end
            end
        end
        lastConfig = config
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    local previousMpVeh, currentMpVeh
    -- anti unicycle-spam
    if oldGameVehID ~= -1 then
        previousMpVeh = M.getMPVehicle(oldGameVehID, true)
        if previousMpVeh and previousMpVeh.isLocal then
            if previousMpVeh.jbeam == "unicycle" then
                M.deleteVehicle(previousMpVeh.gameVehicleID)
            end
            if previousMpVeh.isLocal and M.getVehicleObject(previousMpVeh.gameVehicleID) then
                -- if own vehicle and not deleted, resets currently pressed inputs (except parkingbrake)
                previousMpVeh.veh:queueLuaCommand([[
                    local parkingbrake = input.state.parkingbrake.val
                    input.init()
                    input.state.parkingbrake.val = parkingbrake
                ]])
            end
        end
    end

    -- current vehicle update
    if newGameVehID ~= -1 then
        currentMpVeh = BJI_Veh.getMPVehicle(newGameVehID)

        local function process()
            local finalID
            if not currentMpVeh or currentMpVeh.isLocal then
                finalID = newGameVehID
            else
                finalID = currentMpVeh.remoteVehID
            end
            BJI_Tx_player.switchVehicle(finalID)
        end

        if not currentMpVeh then
            BJI_Async.task(function()
                currentMpVeh = BJI_Veh.getMPVehicle(newGameVehID)
                return currentMpVeh ~= nil
            end, process)
        else
            process()
        end
        BJI_Context.User.currentVehicle = newGameVehID
    else
        BJI_Tx_player.switchVehicle(nil)
        BJI_Context.User.currentVehicle = nil
    end

    -- event
    if oldGameVehID ~= -1 or newGameVehID ~= -1 then
        BJI_Events.trigger(BJI_Events.EVENTS.VEHICLE_SPEC_CHANGED, {
            previousMPVeh = previousMpVeh,
            currentMPVeh = currentMpVeh
        })
        BJI_Restrictions.update()
    end
end

local function updateVehFuelState(ctxt, data)
    local tanks = {}
    for _, tank in ipairs(data[1]) do
        if tank.energyType ~= "air" then
            if ctxt.vehData.tanks and
                ctxt.vehData.tanks[tank.name] then
                if BJI_Scenario.isFreeroam() and
                    BJI_Context.BJC.Freeroam.PreserveEnergy and
                    ctxt.vehData.tanks[tank.name].currentEnergy < tank.currentEnergy then
                    -- keep fuel amount after reset
                    M.setFuel(tank.name, ctxt.vehData.tanks[tank.name].currentEnergy)
                else
                    -- critical fuel amount trigger
                    if table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, ctxt.vehData.tanks[tank.name].energyType) and
                        ctxt.vehData.tanks[tank.name].currentEnergy and
                        ctxt.vehData.tanks[tank.name].currentEnergy > tank.maxEnergy * M.tankLowThreshold and
                        tank.currentEnergy < tank.maxEnergy * M.tankLowThreshold then
                        BJI_Sound.play(BJI_Sound.SOUNDS.FUEL_LOW)
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
        BJI_Events.trigger(BJI_Events.EVENTS.VEHDATA_UPDATED, ctxt.vehData)
    end
end

local lastConfigProtectionState = settings.getValue("protectConfigFromClone", false)
---@param ctxt TickContext
local function slowTick(ctxt)
    if not ctxt.vehData then
        return
    end

    -- get current fuel
    if core_vehicleBridge and ctxt.veh then
        -- update fuel
        core_vehicleBridge.requestValue(ctxt.veh.veh, function(data)
            updateVehFuelState(ctxt, data)
        end, 'energyStorage')
    end

    -- delete corrupted vehs
    for _, vehData in pairs(BJI_Context.User.vehicles) do
        veh = M.getVehicleObject(vehData.gameVehID)
        if not veh then
            BJI_Tx_moderation.deleteVehicle(BJI_Context.User.playerID, vehData.gameVehID)
        end
    end

    -- check for config protection changed
    local configProtection = settings.getValue("protectConfigFromClone", false)
    if configProtection ~= lastConfigProtectionState then
        lastConfigProtectionState = configProtection
        BJI_Events.trigger(BJI_Events.EVENTS.CONFIG_PROTECTION_UPDATED)
    end
end

local function fastTick(ctxt)
    ---@param v BJIMPVehicle
    M.getMPVehicles({ isAi = false }, true):forEach(function(v)
        veh = M.getVehicleObject(v.gameVehicleID)
        if veh then
            veh:queueLuaCommand(string.var([[
                    local speed = tostring(obj:getAirflowSpeed())
                    obj:queueGameEngineLua("BJI_Veh.updateVehCustomAttribute('speed', {1}, "..speed..")")

                    local damaged = serialize(beamstate.damage)
                    obj:queueGameEngineLua("BJI_Veh.updateVehCustomAttribute('damageState', {1}, "..damaged..")")
                ]], { veh:getID() }))
        end
    end)
end

local function setFuel(tankName, targetEnergy)
    if not M.isCurrentVehicleOwn() then
        return
    end

    local vehs = BJI_Context.User.vehicles
    local vehID = BJI_Context.User.currentVehicle and
        M.getVehIDByGameVehID(BJI_Context.User.currentVehicle) or nil
    local vehData = (vehs and vehID) and vehs[vehID] or nil
    if vehData and vehData.tanks then
        veh = M.getCurrentVehicle()
        local tank = vehData.tanks[tankName]
        if tank then
            core_vehicleBridge.executeAction(veh, 'setEnergyStorageEnergy', tankName,
                math.min(tank.maxEnergy, targetEnergy))
            tank.currentEnergy = targetEnergy
        end
    end
end

local function postResetPreserveEnergy(gameVehID)
    if not M.isCurrentVehicleOwn() or not M.isVehicleOwn(gameVehID) then
        return
    end

    local veh
    for _, v in pairs(BJI_Context.User.vehicles) do
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
            M.setFuel(tankName, fuel)
        end
    end
end

--- Vehicle comparison approximation (>= 90% match)
---@param conf1 { model: string, parts: table<string, string>}
---@param conf2 any
local function compareConfigs(conf1, conf2)
    if conf1.model == conf2.model then
        local larger, smaller
        if table.length(conf1.parts) > table.length(conf2.parts) then
            larger = conf1.parts
            smaller = conf2.parts
        else
            larger = conf2.parts
            smaller = conf1.parts
        end

        local matches = Table(larger):reduce(function(acc, v, k)
            if smaller[k] then
                acc = acc + .5
                if v == smaller[k] then
                    acc = acc + .5
                end
            end
            return acc
        end, 0)
        local ratio = matches / table.length(larger)
        local logFn = ratio > .9 and LogInfo or LogWarn
        logFn(string.var("Vehicle configs match up to {1}%%", { math.round(ratio * 100, 1) }))
        return ratio > .9
    end
    return false
end

---@param ctxt TickContext
local function forceVehsSync(ctxt)
    BJI_Async.task(function()
        return BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.PLAYERS)
    end, function()
        local listIDs = Table(ctxt.user.vehicles)
            :filter(function(v) return M.getVehicleObject(v.gameVehID) == nil end)
            :map(function(v) return v.gameVehID end)
            :values()
            :addAll(
                ctxt.players[ctxt.user.playerID].vehicles
                :filter(function(v) return M.getVehicleObject(v.gameVehID) == nil end)
                :map(function(v) return v.gameVehID end)
                :values(),
                true)
        if #listIDs > 0 then
            BJI_Tx_player.markInvalidVehs(listIDs)
        end
    end)
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    if not BJI_Cache.areBaseCachesFirstLoaded() or not BJI.CLIENT_READY then
        return {}
    end

    local stateWalking = BJI_Perm.canSpawnVehicle() and BJI_Scenario.canWalk()
    if not stateWalking and ctxt.isOwner and ctxt.veh.jbeam == "unicycle" then
        M.deleteCurrentOwnVehicle()
    end
    return stateWalking and {} or BJI_Restrictions._SCENARIO_DRIVEN.WALKING
end

---@param attr string
---@param gameVehID integer
---@param value number
local function updateVehCustomAttribute(attr, gameVehID, value)
    local veh = M.getVehicleObject(gameVehID)
    if veh and value then
        veh:setDynDataFieldbyName(attr, 0, tostring(value))
    end
end

local function onUnload()
    M.baseFunctions:forEach(function(fns, extName)
        table.assign(extensions[extName], fns)
    end)
end

M.onLoad = function()
    M.baseFunctions = Table({
        util_screenshotCreator = {
            startWork = extensions.util_screenshotCreator.startWork,
        },
        core_vehicle_partmgmt = {
            removeLocal = extensions.core_vehicle_partmgmt.removeLocal,
        },
        core_vehicle_manager = {
            liveUpdateVehicleColors = extensions.core_vehicle_manager.liveUpdateVehicleColors,
        },
    })

    extensions.util_screenshotCreator.startWork = function(...)
        M.baseFunctions.util_screenshotCreator.saveConfigBaseFunction(...)
        BJI_Async.delayTask(function()
            M.getAllVehicleConfigs(false, false, true)
            BJI_Events.trigger(BJI_Events.EVENTS.CONFIG_SAVED)
        end, 3000, "BJIVehPostSaveConfig")
    end
    extensions.core_vehicle_partmgmt.removeLocal = function(...)
        M.baseFunctions.core_vehicle_partmgmt.removeConfigBaseFunction(...)
        BJI_Async.delayTask(function()
            M.getAllVehicleConfigs(false, false, true)
            BJI_Events.trigger(BJI_Events.EVENTS.CONFIG_REMOVED)
        end, 1000, "BJIVehPostRemoveConfig")
    end
    ---@param vehID integer
    ---@param veh NGVehicle?
    ---@param paintIndex integer
    ---@param paint NGPaint
    extensions.core_vehicle_manager.liveUpdateVehicleColors = function(vehID, veh, paintIndex, paint)
        if M.isVehicleOwn(vehID) then
            -- send live update to all players
            local taskKey = string.var("syncPaint-{1}-{2}", { vehID, paintIndex })
            BJI_Async.removeTask(taskKey)
            BJI_Async.delayTask(function()
                local v = veh or M.getVehicleObject(vehID)
                if v then
                    BJI_Tx_player.syncPaint(vehID, paintIndex, paint)
                end
            end, 1000, taskKey)
        end
        M.baseFunctions.core_vehicle_manager.liveUpdateVehicleColors(vehID, veh, paintIndex, paint)
    end

    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_SPAWNED, onVehicleSpawned, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_DESTROYED, onVehicleDestroyed, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_RESETTED, onVehicleResetted, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_SWITCHED, onVehicleSwitched, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.FAST_TICK, fastTick, M._name)

    BJI_Events.addListener(BJI_Events.EVENTS.SCENARIO_CHANGED, forceVehsSync, M._name)
end

M.isGEInit = isGEInit
M.getMPVehicles = getMPVehicles
M.getMPOwnVehicles = getMPOwnVehicles
M.getMPVehicle = getMPVehicle

M.dropPlayerAtCamera = dropPlayerAtCamera

M.getCurrentVehicle = getCurrentVehicle
M.getVehicleObject = getVehicleObject
M.getRemoteVehID = getRemoteVehID
M.getGameVehIDByRemoteVehID = getGameVehIDByRemoteVehID
M.getVehOwnerID = getVehOwnerID
M.getVehIDByGameVehID = getVehIDByGameVehID
M.getGameVehicleID = getGameVehicleID
M.isVehProtected = isVehProtected
M.getSelfVehiclesCount = getSelfVehiclesCount

M.isVehicleOwn = isVehicleOwn
M.isCurrentVehicleOwn = isCurrentVehicleOwn
M.getCurrentVehicleOwn = getCurrentVehicleOwn
M.hasVehicle = hasVehicle

M.isVehReady = isVehReady
M.waitForVehicleSpawn = waitForVehicleSpawn

M.focus = focus
M.focusVehicle = focusVehicle
M.focusNextVehicle = focusNextVehicle
M.toggleVehicleFocusable = toggleVehicleFocusable
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
M.recoverInPlace = recoverInPlace

M.getPositionRotation = getPositionRotation
M.getPosRotVel = getPosRotVel
M.setPositionRotation = setPositionRotation
M.setPosRotVel = setPosRotVel
M.stopVehicle = stopVehicle

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
M.findAttachedVehicles = findAttachedVehicles
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

M.updateVehCustomAttribute = updateVehCustomAttribute

M.postResetPreserveEnergy = postResetPreserveEnergy
M.compareConfigs = compareConfigs

M.getRestrictions = getRestrictions

return M
