local ds

local function onClose()
    BJIContext.Scenario.DerbySettings = nil
end

local function drawHeader(ctxt)
    ds = BJIContext.Scenario.DerbySettings
    local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
    local minimumParticipants = BJIScenario.get(BJIScenario.TYPES.DERBY).MINIMUM_PARTICIPANTS
    if potentialPlayers < minimumParticipants then
        -- when a player leaves then there are not enough players to start
        BJIToast.warning(BJILang.get("derby.settings.notEnoughPlayers"))
        onClose()
    end

    LineBuilder()
        :text(BJILang.get("derby.settings.title"))
        :build()

    LineBuilder()
        :text(ds.arena.name)
        :text(string.var("({1})", { BJILang.get("derby.settings.places"):var({ places = #ds.arena.startPositions }) }))
        :build()
end

local function drawBody(ctxt)
    if not BJIContext.Scenario.DerbySettings then
        return
    end
    local labelWidth = 0
    for _, key in ipairs({
        "derby.settings.lives",
        "derby.settings.configs",
    }) do
        local w = GetColumnTextWidth(BJILang.get(key) .. HELPMARKER_TEXT)
        if w > labelWidth then
            labelWidth = w
        end
    end

    local btnsWidth = GetBtnIconSize() * 3

    local cols = ColumnsBuilder("BJIDerbySettings", { labelWidth, -1, btnsWidth })
        -- LIVES
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("derby.settings.lives"))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "derbyLives",
                            type = "int",
                            value = ds.lives,
                            min = 0,
                            max = 5,
                            step = 1,
                            onUpdate = function(val)
                                ds.lives = val
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
                BJILang.get("derby.settings.specificConfig")
                :var({ model = BJIVeh.getModelLabel(ctxt.veh.jbeam) }) or
                string.var("{1} {2}", { BJIVeh.getModelLabel(ctxt.veh.jbeam), BJIVeh.getCurrentConfigLabel() }),
            config = BJIVeh.getFullConfig(ctxt.veh.partConfig),
        }
    end

    -- CONFIGS
    for i, confData in ipairs(ds.configs) do
        cols:addRow({
            cells = {
                function()
                    if i == 1 then
                        LineBuilder()
                            :text(BJILang.get("derby.settings.configs"))
                            :helpMarker(BJILang.get("derby.settings.configsTooltip"))
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
                            id = string.var("showDerbyConfig{1}", { i }),
                            icon = ICONS.visibility,
                            style = BTN_PRESETS.INFO,
                            disabled = not ctxt.isOwner,
                            onClick = function()
                                BJIVeh.replaceOrSpawnVehicle(confData.model, confData.config)
                            end,
                        })
                        :btnIcon({
                            id = string.var("removeDerbyConfig{1}", { i }),
                            icon = ICONS.delete_forever,
                            style = BTN_PRESETS.ERROR,
                            onClick = function()
                                table.remove(ds.configs, i)
                            end,
                        })
                        :build()
                end,
            }
        })
    end
    if #ds.configs < 5 then -- 5 configs max
        cols:addRow({
            cells = {
                function()
                    if #ds.configs == 0 then
                        LineBuilder()
                            :text(BJILang.get("derby.settings.configs"))
                            :helpMarker(BJILang.get("derby.settings.configsTooltip"))
                            :build()
                    end
                end,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = "addDerbyConfig",
                            icon = ICONS.addListItem,
                            style = BTN_PRESETS.SUCCESS,
                            disabled = not ctxt.veh,
                            onClick = function()
                                local config = getConfig() or {}
                                for _, c in ipairs(ds.configs) do
                                    if table.compare(config, c, true) then
                                        BJIToast.error(BJILang.get("derby.settings.toastConfigAlreadySaved"))
                                        return
                                    end
                                end
                                table.insert(ds.configs, config)
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
    if not BJIContext.Scenario.DerbySettings then
        return
    end
    LineBuilder()
        :btnIcon({
            id = "closeDerbySettings",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :btnIcon({
            id = "startDerby",
            icon = ICONS.check,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                local status = pcall(BJITx.scenario.DerbyStart, ds.arenaIndex, ds.lives, ds.configs)
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
