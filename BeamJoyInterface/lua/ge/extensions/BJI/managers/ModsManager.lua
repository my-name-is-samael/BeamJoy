local M = {
    baseFunctions = {},
    state = true,
}

local function onLoad()
    BJIAsync.task(function()
        return not not extensions.core_modmanager and not not extensions.core_repository
    end, function()
        -- MODMANAGER
        M.baseFunctions.activateAll = core_modmanager.activateAllMods
        M.baseFunctions.deactivateAllMods = core_modmanager.deactivateAllMods
        M.baseFunctions.deleteAllMods = core_modmanager.deleteAllMods
        -- M.baseFunctions.deleteMod = core_modmanager.deleteMod
        -- M.baseFunctions.deactivateMod = core_modmanager.deactivateMod
        -- M.baseFunctions.deactivateModId = core_modmanager.deactivateModId
        -- M.baseFunctions.activateMod = core_modmanager.activateMod
        -- M.baseFunctions.activateModId = core_modmanager.activateModId
        -- REPOSITORY
        M.baseFunctions.modSubscribe = core_repository.modSubscribe
        M.baseFunctions.modUnsubscribe = core_repository.modUnsubscribe
    end)
end

local function onUnload()
    if tlength(M.baseFunctions) > 0 then
        core_modmanager.activateAllMods = M.baseFunctions.activateAll
        core_modmanager.deactivateAllMods = M.baseFunctions.deactivateAllMods
        core_modmanager.deleteAllMods = M.baseFunctions.deleteAllMods
        -- core_modmanager.deleteMod = M.baseFunctions.deleteMod
        -- core_modmanager.deactivateMod = M.baseFunctions.deactivateMod
        -- core_modmanager.deactivateModId = M.baseFunctions.deactivateModId
        -- core_modmanager.activateMod = M.baseFunctions.activateMod
        -- core_modmanager.activateModId = M.baseFunctions.activateModId
        core_repository.modSubscribe = M.baseFunctions.modSubscribe
        core_repository.modUnsubscribe = M.baseFunctions.modUnsubscribe
    end
end


local function update(state)
    local function updateVehicles()
        BJIVeh.getAllVehicleConfigs(false, false, true)
    end

    if tlength(M.baseFunctions) == 0 then
        BJIAsync.removeTask("BJIModsUpdate")
        BJIAsync.task(function()
            return tlength(M.baseFunctions) > 0
        end, function()
            update(state)
        end, "BJIModsUpdate")
        return
    end

    if state and not M.state then
        -- enabling
        core_modmanager.activateAllMods = function(...)
            M.baseFunctions.activateAll(...)
            updateVehicles()
        end
        core_modmanager.deactivateAllMods = function(...)
            M.baseFunctions.deactivateAllMods(...)
            updateVehicles()
        end
        core_modmanager.deleteAllMods = function(...)
            M.baseFunctions.deleteAllMods(...)
            updateVehicles()
        end
        -- core_modmanager.deleteMod = function(...)
        --     M.baseFunctions.deleteMod(...)
        --     updateVehicles()
        -- end
        -- core_modmanager.deactivateMod = function(...)
        --     M.baseFunctions.deactivateMod(...)
        --     updateVehicles()
        -- end
        -- core_modmanager.deactivateModId = function(...)
        --     M.baseFunctions.deactivateModId(...)
        --     updateVehicles()
        -- end
        -- core_modmanager.activateMod = function(...)
        --     M.baseFunctions.activateMod(...)
        --     updateVehicles()
        -- end
        -- core_modmanager.activateModId = function(...)
        --     M.baseFunctions.activateModId(...)
        --     updateVehicles()
        -- end

        core_repository.modSubscribe = function(...)
            M.baseFunctions.modSubscribe(...)
        end
        core_repository.modUnsubscribe = function(...)
            M.baseFunctions.modUnsubscribe(...)
        end
    elseif not state and M.state then
        -- disabling
        local previousCam
        if BJICam.getCamera() == BJICam.CAMERAS.FREE then
            previousCam = BJICam.getPositionRotation(true)
        end
        local function stopProcess()
            BJIToast.error(BJILang.get("errors.modManagementDisabled"))
            guihooks.trigger("app:waiting", false)
        end
        core_modmanager.activateAllMods = stopProcess
        core_modmanager.deactivateAllMods = stopProcess
        core_modmanager.deleteAllMods = stopProcess
        -- core_modmanager.deleteMod = stopProcess
        -- core_modmanager.deactivateMod = stopProcess
        -- core_modmanager.deactivateModId = stopProcess
        -- core_modmanager.activateMod = stopProcess
        -- core_modmanager.activateModId = stopProcess
        core_repository.modSubscribe = stopProcess
        core_repository.modUnsubscribe = stopProcess
        local mods = core_modmanager.getMods()
        for name, mod in pairs(mods) do
            local fileName = ssplit(mod.fullpath, "/")
            fileName = fileName[#fileName]
            if not tincludes(BJIContext.BJC.Server.ClientMods, mod.fileName, true) and
                not name:find("^multiplayer") then
                LogError(svar("Disabling user mod {1}", { name }))
                core_modmanager.deactivateMod(name, true)
            end
        end
        if tlength(mods) > 0 then
            updateVehicles()
        end
        if previousCam then
            BJIAsync.delayTask(function()
                BJICam.setPositionRotation(previousCam.pos, previousCam.rot)
            end, 200, "BJIModsDisablingCameraRestore")
        end
    end

    M.state = state
end

M.onLoad = onLoad
M.onUnload = onUnload

M.update = update

RegisterBJIManager(M)
return M
