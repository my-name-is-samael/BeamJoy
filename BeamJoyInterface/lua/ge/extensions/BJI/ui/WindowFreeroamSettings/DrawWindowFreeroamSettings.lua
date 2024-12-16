local M = {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    onClose = function()
        BJIContext.Scenario.FreeroamSettingsOpen = false
    end,
}

local labelsConf = {
    { key = "freeroamSettings.resetDelay",              colon = true },
    { key = "freeroamSettings.teleportDelay",           colon = true },
    { key = "freeroamSettings.nametags",                colon = true },
    { key = "freeroamSettings.driftGood",               colon = true },
    { key = "freeroamSettings.driftBig",                colon = true },
    { key = "freeroamSettings.preserveEnergy",          colon = true },
    { key = "freeroamSettings.vehicleSpawning",         colon = true, minimumGroup = BJI_GROUP_NAMES.ADMIN },
    { key = "freeroamSettings.quickTravel",             colon = true, minimumGroup = BJI_GROUP_NAMES.ADMIN },
    { key = "freeroamSettings.emergencyRefuelDuration", colon = true, tooltip = true },
    { key = "freeroamSettings.emergencyRefuelPercent",  colon = true, tooltip = true },
}

local DEFAULT_DRIFT_GOOD = 2000
local DEFAULT_DRIFT_BIG = 10000

local function draw(ctxt)
    if not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CONFIG) then
        M.onClose()
        return
    end

    local labelWidth = 0
    for _, labelConf in ipairs(labelsConf) do
        if not labelConf.minimumGroup or BJIPerm.hasMinimumGroup(labelConf.minimumGroup) then
            local label = BJILang.get(labelConf.key)
            if labelConf.colon then
                label = svar("{1}:", { label })
            end
            if labelConf.tooltip then
                label = svar("{1} {2}", { label, HELPMARKER_TEXT })
            end
            local w = GetColumnTextWidth(label)
            if w > labelWidth then
                labelWidth = w
            end
        end
    end
    local cols = ColumnsBuilder("freeroamSettings", { labelWidth, -1, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.resetDelay") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "freeroamResetDelay",
                            type = "int",
                            value = BJIContext.BJC.Freeroam.ResetDelay,
                            min = 0,
                            step = 1,
                            stepFast = 5,
                            onUpdate = function(val)
                                BJIContext.BJC.Freeroam.ResetDelay = val
                                BJITx.config.bjc("Freeroam.ResetDelay", val)
                            end,
                        })
                        :build()
                end,
                function()
                    LineBuilder()
                        :text(PrettyDelay(BJIContext.BJC.Freeroam.ResetDelay))
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.teleportDelay") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "freeroamTeleportDelay",
                            type = "int",
                            value = BJIContext.BJC.Freeroam.TeleportDelay,
                            min = 0,
                            step = 1,
                            stepFast = 5,
                            onUpdate = function(val)
                                BJIContext.BJC.Freeroam.TeleportDelay = val
                                BJITx.config.bjc("Freeroam.TeleportDelay", val)
                            end,
                        })
                        :build()
                end,
                function()
                    LineBuilder()
                        :text(PrettyDelay(BJIContext.BJC.Freeroam.TeleportDelay))
                        :build()
                end
            }
        })
    if BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.ADMIN) then
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.vehicleSpawning") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIconToggle({
                            id = "freeroamVehicleSpawning",
                            state = BJIContext.BJC.Freeroam.VehicleSpawning,
                            coloredIcon = true,
                            onClick = function()
                                BJITx.config.bjc("Freeroam.VehicleSpawning", not BJIContext.BJC.Freeroam.VehicleSpawning)
                                BJIContext.BJC.Freeroam.VehicleSpawning = not BJIContext.BJC.Freeroam.VehicleSpawning
                            end,
                        })
                        :build()
                end
            }
        })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(svar("{1}:", { BJILang.get("freeroamSettings.quickTravel") }))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :btnIconToggle({
                                id = "freeroamQuickTravel",
                                state = BJIContext.BJC.Freeroam.QuickTravel,
                                coloredIcon = true,
                                onClick = function()
                                    BJITx.config.bjc("Freeroam.QuickTravel", not BJIContext.BJC.Freeroam.QuickTravel)
                                    BJIContext.BJC.Freeroam.QuickTravel = not BJIContext.BJC.Freeroam.QuickTravel
                                end,
                            })
                            :build()
                    end
                }
            })
    end
    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(svar("{1}:", { BJILang.get("freeroamSettings.nametags") }))
                    :build()
            end,
            function()
                LineBuilder()
                    :btnIconToggle({
                        id = "freeroamNametags",
                        state = BJIContext.BJC.Freeroam.Nametags,
                        coloredIcon = true,
                        onClick = function()
                            BJITx.config.bjc("Freeroam.Nametags", not BJIContext.BJC.Freeroam.Nametags)
                            BJIContext.BJC.Freeroam.Nametags = not BJIContext.BJC.Freeroam.Nametags
                        end,
                    })
                    :build()
            end
        }
    })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.allowUnicycle") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIconToggle({
                            id = "freeroamAllowUnicycle",
                            state = BJIContext.BJC.Freeroam.AllowUnicycle,
                            coloredIcon = true,
                            onClick = function()
                                BJITx.config.bjc("Freeroam.AllowUnicycle", not BJIContext.BJC.Freeroam.AllowUnicycle)
                                BJIContext.BJC.Freeroam.AllowUnicycle = not BJIContext.BJC.Freeroam.AllowUnicycle
                            end,
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.driftGood") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "driftGoodThreshold",
                            type = "int",
                            value = BJIContext.BJC.Freeroam.DriftGood,
                            min = 50,
                            max = BJIContext.BJC.Freeroam.DriftBig - 1,
                            onUpdate = function(val)
                                BJIContext.BJC.Freeroam.DriftGood = val
                                BJITx.config.bjc("Freeroam.DriftGood", val)
                            end
                        })
                        :build()
                end,
                function()
                    local defaultDriftGood = 1000
                    LineBuilder()
                        :btnIcon({
                            id = "resetDriftGood",
                            icon = ICONS.refresh,
                            style = BTN_PRESETS.WARNING,
                            disabled = BJIContext.BJC.Freeroam.DriftGood == DEFAULT_DRIFT_GOOD,
                            onClick = function()
                                BJITx.config.bjc("Freeroam.DriftGood", DEFAULT_DRIFT_GOOD)
                                if BJIContext.BJC.Freeroam.DriftBig <= DEFAULT_DRIFT_GOOD then
                                    BJITx.config.bjc("Freeroam.DriftBig", DEFAULT_DRIFT_BIG)
                                end
                            end,
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.driftBig") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "driftBigThreshold",
                            type = "int",
                            value = BJIContext.BJC.Freeroam.DriftBig,
                            min = BJIContext.BJC.Freeroam.DriftGood + 1,
                            max = 10000,
                            onUpdate = function(val)
                                BJIContext.BJC.Freeroam.DriftBig = val
                                BJITx.config.bjc("Freeroam.DriftBig", val)
                            end
                        })
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = "resetDriftBig",
                            icon = ICONS.refresh,
                            style = BTN_PRESETS.WARNING,
                            disabled = BJIContext.BJC.Freeroam.DriftBig == DEFAULT_DRIFT_BIG,
                            onClick = function()
                                BJITx.config.bjc("Freeroam.DriftBig", DEFAULT_DRIFT_BIG)
                                if BJIContext.BJC.Freeroam.DriftGood >= DEFAULT_DRIFT_BIG then
                                    BJITx.config.bjc("Freeroam.DriftGood", DEFAULT_DRIFT_GOOD)
                                end
                            end,
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.preserveEnergy") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIconToggle({
                            id = "freeroamPreserveEnergy",
                            state = BJIContext.BJC.Freeroam.PreserveEnergy,
                            coloredIcon = true,
                            onClick = function()
                                BJITx.config.bjc("Freeroam.PreserveEnergy", not BJIContext.BJC.Freeroam.PreserveEnergy)
                                BJIContext.BJC.Freeroam.PreserveEnergy = not BJIContext.BJC.Freeroam.PreserveEnergy
                            end,
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.emergencyRefuelDuration") }))
                        :helpMarker(BJILang.get("freeroamSettings.emergencyRefuelDurationTooltip"))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "freeroamEmergencyRefuelDuration",
                            type = "int",
                            value = BJIContext.BJC.Freeroam.EmergencyRefuelDuration,
                            min = 5,
                            max = 60,
                            disabled = not BJIContext.BJC.Freeroam.PreserveEnergy,
                            onUpdate = function(val)
                                BJIContext.BJC.Freeroam.EmergencyRefuelDuration = val
                                BJITx.config.bjc("Freeroam.EmergencyRefuelDuration", val)
                            end
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("freeroamSettings.emergencyRefuelPercent") }))
                        :helpMarker(BJILang.get("freeroamSettings.emergencyRefuelPercentTooltip"))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "freeroamEmergencyRefuelPercent",
                            type = "int",
                            value = BJIContext.BJC.Freeroam.EmergencyRefuelPercent,
                            min = 5,
                            max = 100,
                            disabled = not BJIContext.BJC.Freeroam.PreserveEnergy,
                            onUpdate = function(val)
                                BJIContext.BJC.Freeroam.EmergencyRefuelPercent = val
                                BJITx.config.bjc("Freeroam.EmergencyRefuelPercent", val)
                            end
                        })
                        :build()
                end
            }
        })
        :build()
end

local function drawFooter(ctxt)
    LineBuilder()
        :btnIcon({
            id = "closeFreeroamSettings",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.Scenario.FreeroamSettingsOpen = false
            end
        })
        :build()
end

M.body = draw
M.footer = drawFooter

return M
