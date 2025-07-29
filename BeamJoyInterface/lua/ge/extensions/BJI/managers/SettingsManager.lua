---@class BJISettingConfig
---@field key string
---@field value any?
---@field min number?
---@field max number?
---@field onChange fun()?
---@field customBehavior {extensionName: string, fnName: string, override: fun(...)}?

---@class BJIManagerSettings: BJIManager
local M = {
    _name = "Settings",

    baseFunctions = {},

    ---@type tablelib<integer, BJISettingConfig>
    config = Table({
        -- Traffic
        {
            key = "trafficEnableSwitching",
            value = false,
            onChange = extensions.gameplay_traffic.onSettingsChanged,
        },
        {
            key = "trafficMinimap",
            value = false,
            onChange = extensions.gameplay_traffic.onSettingsChanged,
        },
        {
            key = "trafficSimpleVehicles",
            value = true,
        },
        {
            key = "trafficAllowMods",
            value = false,
        },
        {
            key = "trafficAmount",
            min = 2,
            max = 10,
        },
        {
            key = "trafficParkedAmount",
            max = 5,
        },
        {
            key = "trafficExtraAmount",
            max = 5,
        },

        -- General
        {
            key = "disableDynamicCollision",
            value = false,
            onChange = function() be:setDynamicCollisionEnabled(true) end,
        },
        -- MP
        {
            key = "fadeVehicles",
            value = false,
        },
        {
            key = "skipOtherPlayersVehicles",
            value = false,
        },
        {
            key = "simplifyRemoteVehicles",
            value = false,
        },
    }),
}

--- Force apply all configs
---@param ctxt TickContext
local function slowTick(ctxt)
    ---@param cfg BJISettingConfig
    M.config:forEach(function(cfg)
        local val = settings.getValue(cfg.key)
        local changed = false
        if tonumber(val) then
            val = tonumber(val) or 0
            if cfg.value then
                if val ~= cfg.value then
                    settings.setValue(cfg.key, cfg.value)
                    changed = true
                end
            elseif cfg.min or cfg.max then
                local clamped = math.clamp(val, cfg.min, cfg.max)
                if clamped ~= val then
                    settings.setValue(cfg.key, clamped)
                    changed = true
                end
            end
        elseif type(val) == "boolean" or val == "true" or val == "false" then
            if type(val) ~= "boolean" then
                val = val == "true"
            end
            if cfg.value ~= nil and cfg.value ~= val then
                settings.setValue(cfg.key, cfg.value)
                changed = true
            end
        end

        if changed then
            LogWarn(string.var("Setting {1} changed from {2} to {3}", { cfg.key, val, settings.getValue(cfg.key) }))
        end

        if changed and cfg.onChange then
            cfg.onChange()
        end
    end)
end

local function onUnload()
    RollBackNGFunctionsWrappers(M.baseFunctions)
end

local function onLoad()
    BJI_Events.addListener(BJI_Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)

    ---@param cfg BJISettingConfig
    M.config:filter(function(cfg)
        return cfg.customBehavior ~= nil
    end)
    ---@param cfg BJISettingConfig
        :forEach(function(cfg)
            if not M.baseFunctions[cfg.customBehavior.extensionName] then
                M.baseFunctions[cfg.customBehavior.extensionName] = {}
            end
            M.baseFunctions[cfg.customBehavior.extensionName][cfg.customBehavior.fnName] =
                cfg.customBehavior.override
        end)
end

M.onLoad = onLoad

return M
