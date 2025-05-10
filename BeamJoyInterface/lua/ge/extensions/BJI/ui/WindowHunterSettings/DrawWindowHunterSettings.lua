local hs

local function onClose()
    BJIContext.Scenario.HunterSettings = nil
end

local function drawHeader(ctxt)
    hs = BJIContext.Scenario.HunterSettings
    local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
    local minimumParticipants = BJIScenario.get(BJIScenario.TYPES.HUNTER).MINIMUM_PARTICIPANTS
    if potentialPlayers < minimumParticipants then
        -- when a player leaves then there are not enough players to start
        BJIToast.warning(BJILang.get("hunter.settings.notEnoughPlayers"))
        onClose()
    end

    LineBuilder()
        :text(BJILang.get("hunter.settings.title"))
        :build()
end

local function drawBody(ctxt)
    if not BJIContext.Scenario.HunterSettings then
        return
    end
    local labelWidth = 0
    for _, key in ipairs({
        "hunter.settings.huntedWaypoints",
        "hunter.settings.huntedConfigs",
        "hunter.settings.hunterConfigs",
    }) do
        local w = GetColumnTextWidth(string.var("{1}{2}", { BJILang.get(key), HELPMARKER_TEXT }))
        if w > labelWidth then
            labelWidth = w
        end
    end

    local btnsWidth = GetBtnIconSize() * 3

    local cols = ColumnsBuilder("BJIHunterSettings", { labelWidth, -1, btnsWidth })
        -- WAYPOINTS
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("hunter.settings.huntedWaypoints"))
                        :helpMarker(BJILang.get("hunter.settings.huntedWaypointsTooltip"))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "huntedWaypoints",
                            type = "int",
                            value = hs.waypoints,
                            min = 2,
                            max = 50,
                            step = 1,
                            onUpdate = function(val)
                                hs.waypoints = val
                            end
                        })
                        :build()
                end,
            }
        })

    local function getConfig()
        if not ctxt.veh then
            return
        end

        return {
            model = ctxt.veh.jbeam,
            label = BJIVeh.isConfigCustom(ctxt.veh.partConfig) and
                BJILang.get("hunter.settings.specificConfig")
                :var({ model = BJIVeh.getModelLabel(ctxt.veh.jbeam) }) or
                string.var("{1} {2}", { BJIVeh.getModelLabel(ctxt.veh.jbeam), BJIVeh.getCurrentConfigLabel() }),
            config = BJIVeh.getFullConfig(ctxt.veh.partConfig),
        }
    end

    -- HUNTED CONFIG
    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(BJILang.get("hunter.settings.huntedConfig"))
                    :helpMarker(BJILang.get("hunter.settings.huntedConfigTooltip"))
                    :build()
            end,
            function()
                local line = LineBuilder()
                if hs.huntedConfig then
                    line:text(hs.huntedConfig.label)
                else
                    line:btnIcon({
                        id = "addHuntedConfig",
                        icon = ICONS.addListItem,
                        style = BTN_PRESETS.SUCCESS,
                        disabled = not ctxt.veh,
                        onClick = function()
                            if BJIVeh.isModelBlacklisted(ctxt.veh.jbeam) then
                                BJIToast.error(BJILang.get("errors.toastModelBlacklisted"))
                            else
                                hs.huntedConfig = getConfig()
                            end
                        end,
                    })
                end
                line:build()
            end,
            function()
                if hs.huntedConfig then
                    LineBuilder()
                        :btnIcon({
                            id = "showHuntedConfig",
                            icon = ICONS.visibility,
                            style = BTN_PRESETS.INFO,
                            disabled = not ctxt.isOwner,
                            onClick = function()
                                BJIVeh.replaceOrSpawnVehicle(hs.huntedConfig.model,
                                    hs.huntedConfig.config, ctxt.vehPosRot)
                            end,
                        })
                        :btnIcon({
                            id = "refreshHuntedConfig",
                            icon = ICONS.refresh,
                            style = BTN_PRESETS.WARNING,
                            disabled = not ctxt.veh,
                            onClick = function()
                                if BJIVeh.isModelBlacklisted(ctxt.veh.jbeam) then
                                    BJIToast.error(BJILang.get("errors.toastModelBlacklisted"))
                                else
                                    hs.huntedConfig = getConfig()
                                end
                            end,
                        })
                        :btnIcon({
                            id = "removeHuntedConfig",
                            icon = ICONS.delete_forever,
                            style = BTN_PRESETS.ERROR,
                            onClick = function()
                                hs.huntedConfig = nil
                            end,
                        })
                        :build()
                end
            end,
        }
    })

    -- HUNTERS CONFIGS
    for i, confData in ipairs(hs.hunterConfigs) do
        cols:addRow({
            cells = {
                function()
                    if i == 1 then
                        LineBuilder()
                            :text(BJILang.get("hunter.settings.hunterConfigs"))
                            :helpMarker(BJILang.get("hunter.settings.hunterConfigsTooltip"))
                            :build()
                    end
                end,
                function()
                    LineBuilder()
                        :text(confData.label)
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = string.var("showHunterConfig{1}", { i }),
                            icon = ICONS.visibility,
                            style = BTN_PRESETS.INFO,
                            disabled = not ctxt.isOwner,
                            onClick = function()
                                BJIVeh.replaceOrSpawnVehicle(confData.model, confData.config)
                            end,
                        })
                        :btnIcon({
                            id = string.var("removeHunterConfig{1}", { i }),
                            icon = ICONS.delete_forever,
                            style = BTN_PRESETS.ERROR,
                            onClick = function()
                                table.remove(hs.hunterConfigs, i)
                            end,
                        })
                        :build()
                end,
            }
        })
    end
    if #hs.hunterConfigs < 5 then -- 5 configs max for hunters
        cols:addRow({
            cells = {
                function()
                    if #hs.hunterConfigs == 0 then
                        LineBuilder()
                            :text(BJILang.get("hunter.settings.hunterConfigs"))
                            :helpMarker(BJILang.get("hunter.settings.hunterConfigsTooltip"))
                            :build()
                    end
                end,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = "addHunterConfig",
                            icon = ICONS.addListItem,
                            style = BTN_PRESETS.SUCCESS,
                            disabled = not ctxt.veh,
                            onClick = function()
                                local config = getConfig() or {}
                                for _, c in ipairs(hs.hunterConfigs) do
                                    if table.compare(config, c, true) then
                                        BJIToast.error(BJILang.get("hunter.settings.toastConfigAlreadySaved"))
                                        return
                                    end
                                end
                                table.insert(hs.hunterConfigs, config)
                            end,
                        })
                        :build()
                end,
            }
        })
    end
    cols:build()
end

local function drawFooter(ctxt)
    if not BJIContext.Scenario.HunterSettings then
        return
    end
    LineBuilder()
        :btnIcon({
            id = "closeHunterSettings",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :btnIcon({
            id = "startHunter",
            icon = ICONS.videogame_asset,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                local status = pcall(BJITx.scenario.HunterStart, {
                    waypoints = hs.waypoints,
                    huntedConfig = hs.huntedConfig,
                    hunterConfigs = hs.hunterConfigs,
                })
                if status then
                    onClose()
                end
            end
        })
        :build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE,
    },
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
    onClose = onClose,
}
