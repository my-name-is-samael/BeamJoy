---@class BJIManagerMods : BJIManager
local M = {
    _name = "Mods",

    baseFunctions = {},
    state = true,
}

local function updateVehicles()
    BJI.Managers.Veh.getAllVehicleConfigs(false, false, true)
end

local function initNGFunctionsWrappers()
    -- cannot be wrapped:
    -- extensions.core_repository.requestMyMods
    M.baseFunctions = {
        core_modmanager = {
            activateModId = extensions.core_modmanager.activateModId,
            deactivateModId = extensions.core_modmanager.deactivateModId,
            activateAllMods = extensions.core_modmanager.activateAllMods,
            deactivateAllMods = extensions.core_modmanager.deactivateAllMods,
            deleteAllMods = extensions.core_modmanager.deleteAllMods,
        },
        core_repository = {
            modSubscribe = extensions.core_repository.modSubscribe,
            modUnsubscribe = extensions.core_repository.modUnsubscribe,
            requestMods = extensions.core_repository.requestMods,
        },
    }

    local function stopProcess()
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.modManagementDisabled"))
        guihooks.trigger("app:waiting", false)
        BJI.Managers.UI.hideGameMenu()
    end

    Table({
        { parent = "core_modmanager", fnName = "activateModId",     updateVeh = true },
        { parent = "core_modmanager", fnName = "deactivateModId",   updateVeh = true },
        { parent = "core_modmanager", fnName = "activateAllMods",   updateVeh = true },
        { parent = "core_modmanager", fnName = "deactivateAllMods", updateVeh = true },
        { parent = "core_modmanager", fnName = "deleteAllMods",     updateVeh = true },
        { parent = "core_repository", fnName = "modSubscribe",      updateVeh = true },
        { parent = "core_repository", fnName = "modUnsubscribe",    updateVeh = true },
        { parent = "core_repository", fnName = "requestMods" },
    }):forEach(function(el)
        M.baseFunctions[el.parent][el.fnName] = extensions[el.parent][el.fnName]
        extensions[el.parent][el.fnName] = function(...)
            if M.state then
                local res = M.baseFunctions[el.parent][el.fnName](...)
                if el.updateVeh then updateVehicles() end
                return res
            else
                stopProcess()
            end
        end
    end)
end

local function onUnload()
    RollBackNGFunctionsWrappers(M.baseFunctions)
end

local function onLoad()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_POST_LOAD, initNGFunctionsWrappers, M._name)
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

            local mods = extensions.core_modmanager.getMods()
            for name, mod in pairs(mods) do
                local fileName = mod.fullpath:split2("/")
                fileName = fileName[#fileName]
                if not table.includes(BJI.Managers.Context.BJC.Server.ClientMods, mod.fileName) and
                    not name:find("^multiplayer") then
                    LogError(string.var("Disabling user mod {1}", { name }))
                    extensions.core_modmanager.deactivateMod(name, true)
                end
            end
            if table.length(mods) > 0 then
                updateVehicles()
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

M.onLoad = onLoad
M.update = update

return M
