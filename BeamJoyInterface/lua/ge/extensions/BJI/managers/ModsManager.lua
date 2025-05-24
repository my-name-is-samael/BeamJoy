---@class BJIManagerMods : BJIManager
local M = {
    _name = "Mods",

    baseFunctions = {},
    state = true,
}

local function _updateVehicles()
    BJI.Managers.Veh.getAllVehicleConfigs(false, false, true)
end

local function onUnload()
    if table.length(M.baseFunctions) > 0 then
        core_modmanager.activateModId = M.baseFunctions.activateModId
        core_modmanager.deactivateModId = M.baseFunctions.deactivateModId
        core_modmanager.activateAllMods = M.baseFunctions.activateAll
        core_modmanager.deactivateAllMods = M.baseFunctions.deactivateAllMods
        core_modmanager.deleteAllMods = M.baseFunctions.deleteAllMods
        core_repository.modSubscribe = M.baseFunctions.modSubscribe
        core_repository.modUnsubscribe = M.baseFunctions.modUnsubscribe

        core_repository.requestMods = M.baseFunctions.requestMods
    end
end

local function onLoad()
    BJI.Managers.Async.task(function()
        return not not extensions.core_modmanager and not not extensions.core_repository
    end, function()
        -- already blocked by BeamMP
        -- M.baseFunctions.deleteMod = core_modmanager.deleteMod
        -- M.baseFunctions.activateMod = core_modmanager.activateMod
        -- M.baseFunctions.deactivateMod = core_modmanager.deactivateMod
        M.baseFunctions.activateModId = core_modmanager.activateModId
        M.baseFunctions.deactivateModId = core_modmanager.deactivateModId
        M.baseFunctions.activateAll = core_modmanager.activateAllMods
        M.baseFunctions.deactivateAllMods = core_modmanager.deactivateAllMods
        M.baseFunctions.deleteAllMods = core_modmanager.deleteAllMods
        M.baseFunctions.modSubscribe = core_repository.modSubscribe
        M.baseFunctions.modUnsubscribe = core_repository.modUnsubscribe
        M.baseFunctions.requestMods = core_repository.requestMods

        local function stopProcess()
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.modManagementDisabled"))
            guihooks.trigger("app:waiting", false)
            BJI.Managers.UI.hideGameMenu()
        end

        core_modmanager.activateModId = function(...)
            if M.state then
                local res = M.baseFunctions.activateModId(...)
                _updateVehicles()
                return res
            else
                stopProcess()
            end
        end
        core_modmanager.deactivateModId = function(...)
            if M.state then
                local res = M.baseFunctions.deactivateModId(...)
                _updateVehicles()
                return res
            else
                stopProcess()
            end
        end
        core_modmanager.activateAllMods = function(...)
            if M.state then
                local res = M.baseFunctions.activateAll(...)
                _updateVehicles()
                return res
            else
                stopProcess()
            end
        end
        core_modmanager.deactivateAllMods = function(...)
            if M.state then
                local res = M.baseFunctions.deactivateAllMods(...)
                _updateVehicles()
                return res
            else
                stopProcess()
            end
        end
        core_modmanager.deleteAllMods = function(...)
            if M.state then
                local res = M.baseFunctions.deleteAllMods(...)
                _updateVehicles()
                return res
            else
                stopProcess()
            end
        end
        core_repository.modSubscribe = function(...)
            if M.state then
                local res = M.baseFunctions.modSubscribe(...)
                _updateVehicles()
                return res
            else
                stopProcess()
            end
        end
        core_repository.modUnsubscribe = function(...)
            if M.state then
                local res = M.baseFunctions.modUnsubscribe(...)
                _updateVehicles()
                return res
            else
                stopProcess()
            end
        end

        core_repository.requestMods = function(...)
            LogWarn("Requesting mods")
            if not M.state then
                stopProcess()
            end
            return M.baseFunctions.requestMods(...)
        end
    end, "BJIModsInit")
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)
end


local function update(state)
    if table.length(M.baseFunctions) == 0 then
        BJI.Managers.Async.task(function()
            return table.length(M.baseFunctions) > 0
        end, function()
            update(state)
        end)
        return
    end

    if not state and M.state then
        -- disabling
        BJI.Managers.UI.applyLoading(true, function()
            local previousCam, previousFov
            if BJI.Managers.Cam.getCamera() == BJI.Managers.Cam.CAMERAS.FREE then
                previousCam = BJI.Managers.Cam.getPositionRotation(true)
                previousFov = BJI.Managers.Cam.getFOV()
            end

            local mods = core_modmanager.getMods()
            for name, mod in pairs(mods) do
                local fileName = mod.fullpath:split2("/")
                fileName = fileName[#fileName]
                if not table.includes(BJI.Managers.Context.BJC.Server.ClientMods, mod.fileName) and
                    not name:find("^multiplayer") then
                    LogError(string.var("Disabling user mod {1}", { name }))
                    core_modmanager.deactivateMod(name, true)
                end
            end
            if table.length(mods) > 0 then
                _updateVehicles()
            end
            if previousCam then
                BJI.Managers.Async.delayTask(function()
                    BJI.Managers.Cam.setPositionRotation(previousCam.pos, previousCam.rot)
                    BJI.Managers.Cam.setFOV(previousFov)
                end, 200, "BJIModsDisablingCameraRestore")
            end
            BJI.Managers.UI.applyLoading(false)
        end)
    end

    M.state = state
end

M.update = update

M.onLoad = onLoad

return M
