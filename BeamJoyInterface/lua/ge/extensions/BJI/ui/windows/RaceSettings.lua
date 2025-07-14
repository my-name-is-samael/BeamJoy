---@class RaceSettings
---@field multi boolean
---@field raceID integer
---@field raceName string
---@field loopable boolean
---@field laps integer?
---@field defaultRespawnStrategy string?
---@field respawnStrategies string[]
---@field collisions boolean?
---@field vehicleMode string|nil

---@class BJIWindowRaceSettings : BJIWindow
local W = {
    name = "RaceSettings",
    minSize = ImVec2(470, 260),
    maxSize = ImVec2(700, 260),

    VEHICLE_MODES = {
        ALL = nil,
        MODEL = "model",
        CONFIG = "config",
    },
    show = false,

    ---@type RaceSettings
    settings = {
        multi = false,
        raceID = -1,
        raceName = "",
        loopable = false,
        laps = 1,
        defaultRespawnStrategy = nil,
        respawnStrategies = {},
        collisions = true,
        vehicleMode = nil,
    },

    data = {
        currentVeh = {
            model = nil,
            modelLabel = nil,
            config = nil,
        },

        comboRespawnStrategies = {},
        respawnStrategySelected = nil,

        currentVehicleProtected = false,
        selfProtected = false,
        ---@type {value?: string, label: string}[]
        comboVehicle = {},
        ---@type {value?: string, label: string}?
        vehicleSelected = nil,

        showVoteBtn = false,
        showStartBtn = false,
    },
    labels = {
        unknown = "",
        title = "",
        raceName = "",
        laps = "",
        manyLapsWarning = "",
        respawnStrategies = {
            title = "",
            all = "",
            norespawn = "",
            lastcheckpoint = "",
            stand = "",
        },
        collisions = "",
        vehicle = {
            title = "",
            all = "",
            currentModel = "",
            currentConfig = "",
            vehicleProtected = "",
            selfProtected = "",
        },
        cancel = "",
        startVote = "",
        startRace = "",
    },
}
--- gc prevention
local ctxt, configLabel, nextValue

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.unknown = BJI_Lang.get("common.unknown")

    W.labels.title = W.settings.multi and
        BJI_Lang.get("races.preparation.multiplayer") or
        BJI_Lang.get("races.preparation.singleplayer")
    W.labels.raceName = string.var("{1} \"{2}\"", { BJI_Lang.get("races.play.race"), W.settings.raceName })

    W.labels.laps = BJI_Lang.get("races.edit.laps")
    W.labels.manyLapsWarning = BJI_Lang.get("races.settings.manyLapsWarning")

    W.labels.respawnStrategies.title = BJI_Lang.get("races.settings.respawnStrategies.title")
    W.labels.respawnStrategies.all = BJI_Lang.get("races.settings.respawnStrategies.all")
    W.labels.respawnStrategies.norespawn = BJI_Lang.get("races.settings.respawnStrategies.norespawn")
    W.labels.respawnStrategies.lastcheckpoint = BJI_Lang.get(
        "races.settings.respawnStrategies.lastcheckpoint")
    W.labels.respawnStrategies.stand = BJI_Lang.get("races.settings.respawnStrategies.stand")

    W.labels.collisions = BJI_Lang.get("races.settings.collisions")

    W.labels.vehicle.title = BJI_Lang.get("races.settings.vehicles.playerVehicle")
    W.labels.vehicle.all = BJI_Lang.get("races.settings.vehicles.all")
    W.labels.vehicle.currentModel = BJI_Lang.get("races.settings.vehicles.currentModel")
    W.labels.vehicle.currentConfig = BJI_Lang.get("races.settings.vehicles.currentConfig")
    W.labels.vehicle.vehicleProtected = BJI_Lang.get("vehicleSelector.protectedVehicle")
    W.labels.vehicle.selfProtected = BJI_Lang.get("vehicleSelector.selfProtected")

    W.labels.cancel = BJI_Lang.get("common.buttons.cancel")
    W.labels.startVote = BJI_Lang.get("common.buttons.startVote")
    W.labels.startRace = BJI_Lang.get("common.buttons.start")
end

local function updateCache()
    ctxt = BJI_Tick.getContext()

    W.data.currentVeh.model = nil
    W.data.currentVeh.modelLabel = nil
    W.data.currentVeh.config = nil
    W.data.comboRespawnStrategies = {}
    W.data.comboVehicle = {}
    W.data.showVoteBtn = false
    W.data.showStartBtn = false

    -- autoclose checks
    if W.show and (not BJI_Scenario.isFreeroam() or (
            not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) and
            not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) and
            not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO)
        )) then
        onClose()
        return
    elseif not W.settings.multi and not ctxt.isOwner then
        onClose()
        return
    elseif W.settings.multi and BJI_Perm.getCountPlayersCanSpawnVehicle() < BJI_Scenario.get(BJI_Scenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS then
        -- when a player leaves then there are not enough players to start
        BJI_Toast.warning(BJI_Lang.get("races.preparation.notEnoughPlayers"))
        onClose()
        return
    end

    -- respawn strategies
    W.data.comboRespawnStrategies = Table(W.settings.respawnStrategies)
        :map(function(rs)
            return {
                value = rs,
                label = W.labels.respawnStrategies[rs],
            }
        end)
    if not table.any(W.data.comboRespawnStrategies, function(option)
            return option.value == W.data.respawnStrategySelected
        end) then
        W.data.respawnStrategySelected = W.data.comboRespawnStrategies[1].value
    end

    if W.settings.multi then
        W.data.currentVehicleProtected = ctxt.veh and not ctxt.isOwner and ctxt.veh.protected
        W.data.selfProtected = ctxt.isOwner and settings.getValue("protectConfigFromClone", false) == true
        -- vehicle combo
        table.insert(W.data.comboVehicle, {
            value = W.VEHICLE_MODES.ALL,
            label = W.labels.vehicle.all,
        })
        if ctxt.veh and ctxt.veh.isVehicle and not BJI_Veh.isModelBlacklisted(ctxt.veh.jbeam) then
            table.insert(W.data.comboVehicle, {
                value = W.VEHICLE_MODES.MODEL,
                label = W.labels.vehicle.currentModel,
            })
            if not W.data.currentVehicleProtected and not W.data.selfProtected then
                table.insert(W.data.comboVehicle, {
                    value = W.VEHICLE_MODES.CONFIG,
                    label = W.labels.vehicle.currentConfig,
                })
            end
            if not W.data.vehicleSelected then
                if W.settings.vehicleMode then
                    W.data.vehicleSelected = table.find(W.data.comboVehicle, function(v)
                        return v.value == W.settings.vehicleMode
                    end) or W.data.comboVehicle[1]
                end
            end
        end
        if not table.find(W.data.comboVehicle, function(option)
                return option.value == W.data.vehicleSelected
            end) then
            W.data.vehicleSelected = W.data.comboVehicle[1].value
        end
    end

    -- current veh
    if ctxt.veh then
        W.data.currentVeh.model = ctxt.veh.jbeam
        W.data.currentVeh.modelLabel = BJI_Veh.getModelLabel(W.data.currentVeh.model) or
            W.labels.unknown

        W.data.currentVeh.config = BJI_Veh.getFullConfig(ctxt.veh.veh.partConfig)
        configLabel = BJI_Veh.getCurrentConfigLabel()
        W.data.currentVeh.configLabel = configLabel and string.var("{1} {2}",
            { W.data.currentVeh.modelLabel, configLabel }) or W.labels.unknown
    else
        W.data.currentVeh.model = nil
        W.data.currentVeh.modelLabel = nil
        W.data.currentVeh.config = nil
        W.data.currentVeh.configLabel = nil
    end

    W.data.showVoteBtn = W.settings.multi and not BJI_Tournament.state and
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)
    W.data.showStartBtn = (W.settings.multi and BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO)) or
        (not W.settings.multi and BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO))
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels,
        W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.VEHICLE_SPAWNED,
        BJI_Events.EVENTS.NG_VEHICLE_REPLACED,
        BJI_Events.EVENTS.VEHICLE_REMOVED,
        BJI_Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.CONFIG_PROTECTION_UPDATED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI_Cache.CACHES.RACES or data.cache == BJI_Cache.CACHES.PLAYERS then
            updateCache()
        end
    end, W.name .. "Cache"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function drawHeader()
    Text(W.labels.title, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
    Text(W.labels.raceName)
end

local function drawBody(ctxt)
    if BeginTable("BJIRaceSettings", {
            { label = "##race-settings-labels" },
            { label = "##race-settings-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        if W.settings.loopable then
            TableNewRow()
            Text(W.labels.laps)
            TableNextColumn()
            nextValue = SliderInt("raceSettingsLaps", W.settings.laps, 1, 50)
            if nextValue then W.settings.laps = nextValue end
            if W.settings.laps >= 20 then
                Text(W.labels.manyLapsWarning, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
            end
        end

        TableNewRow()
        Text(W.labels.respawnStrategies.title)
        TableNextColumn()
        nextValue = Combo("respawnStrategies", W.data.respawnStrategySelected,
            W.data.comboRespawnStrategies, { width = -1 })
        if nextValue then W.data.respawnStrategySelected = nextValue end

        if W.settings.multi then
            TableNewRow()
            Text(W.labels.collisions)
            TableNextColumn()
            if IconButton("raceSettingsCollisions", W.settings.collisions and BJI.Utils.Icon.ICONS.check_circle or
                    BJI.Utils.Icon.ICONS.cancel, { btnStyle = W.settings.collisions and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                        BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
                W.settings.collisions = not W.settings.collisions
            end

            TableNewRow()
            Text(W.labels.vehicle.title)
            TableNextColumn()
            if W.data.selfProtected then
                ShowHelpMarker(W.labels.vehicle.selfProtected)
                SameLine()
            elseif W.data.currentVehicleProtected then
                ShowHelpMarker(W.labels.vehicle.vehicleProtected)
                SameLine()
            end
            nextValue = Combo("settingsVehicle", W.data.vehicleSelected, W.data.comboVehicle, { width = -1 })
            if nextValue then W.data.vehicleSelected = nextValue end

            if W.data.vehicleSelected ~= W.VEHICLE_MODES.ALL then
                TableNewRow()
                TableNextColumn()
                Text(W.data.vehicleSelected == W.VEHICLE_MODES.MODEL and
                    W.data.currentVeh.modelLabel or W.data.currentVeh.configLabel)
            end
        end

        EndTable()
    end
end

local function getPayloadSettings()
    return {
        laps = W.settings.loopable and W.settings.laps or nil,
        model = W.data.vehicleSelected ~= W.VEHICLE_MODES.ALL and W.data.currentVeh.model or nil,
        config = W.data.vehicleSelected == W.VEHICLE_MODES.CONFIG and W.data.currentVeh.config or nil,
        respawnStrategy = W.data.respawnStrategySelected,
        collisions = W.settings.collisions
    }
end

local function startVote()
    local settings = getPayloadSettings()
    BJI_Tx_vote.ScenarioStart(BJI_Votes.SCENARIO_TYPES.RACE, true, {
        raceID = W.settings.raceID,
        laps = settings.laps,
        model = settings.model,
        config = settings.config,
        respawnStrategy = settings.respawnStrategy,
        collisions = settings.collisions,
    })
    onClose()
end

---@param ctxt TickContext
local function start(ctxt)
    if W.settings.multi then
        local settings = getPayloadSettings()
        BJI_Tx_vote.ScenarioStart(BJI_Votes.SCENARIO_TYPES.RACE, false, {
            raceID = W.settings.raceID,
            laps = settings.laps,
            model = settings.model,
            config = settings.config,
            respawnStrategy = settings.respawnStrategy,
            collisions = settings.collisions,
        })
        onClose()
    else
        BJI_Tx_scenario.RaceDetails(W.settings.raceID, function(raceData)
            if raceData then
                if BJI_Scenario.isFreeroam() then
                    BJI_Scenario.get(BJI_Scenario.TYPES.RACE_SOLO).initRace(
                        ctxt,
                        {
                            laps = raceData.loopable and W.settings.laps or nil,
                            respawnStrategy = W.data.respawnStrategySelected,
                        },
                        raceData
                    )
                end
                onClose()
            else
                BJI_Toast.error(BJI_Lang.get("errors.invalidData"))
            end
        end)
    end
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    if not W.settings then return end
    if IconButton("cancelRaceStart", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.cancel)
    if W.data.showVoteBtn then
        SameLine()
        if IconButton("voteRaceStart", BJI.Utils.Icon.ICONS.event_available,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            startVote()
        end
        TooltipText(W.labels.startVote)
    end
    if W.data.showStartBtn then
        SameLine()
        if IconButton("raceStart", BJI.Utils.Icon.ICONS.videogame_asset,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            start(ctxt)
        end
        TooltipText(W.labels.startRace)
    end
end

local function commonHandleSettings(raceSettings)
    if #raceSettings.respawnStrategies == 0 then
        LogError("No respawn strategies found")
        return false
    end

    if raceSettings.loopable then
        raceSettings.laps = raceSettings.laps or W.settings.laps or 1
    else
        raceSettings.laps = 1
    end
    raceSettings.collisions = raceSettings.collisions or W.settings.collisions
    W.settings = raceSettings
    return true
end

---@param raceSettings RaceSettings
local function open(raceSettings)
    if not commonHandleSettings(raceSettings) then
        return
    end

    if not W.data.respawnStrategySelected then
        W.data.respawnStrategySelected = W.settings.defaultRespawnStrategy
    end
    W.data.vehicleSelected = W.data.vehicleSelected or W.VEHICLE_MODES.ALL

    if BJI_Scenario.isFreeroam() and
        (BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) or
            BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO)) then
        if W.show then
            --if already open, update data
            updateLabels()
            updateCache()
        end
        W.show = true
    else
        onClose()
    end
end

---@param raceSettings RaceSettings
local function openPromptFlow(raceSettings)
    if not commonHandleSettings(raceSettings) then
        return
    end
    updateLabels()
    updateCache()

    local cancelButton = {
        label = W.labels.cancel,
    }
    local settingsButton = {
        icon = BJI_Prompt.quick.settings,
        label = BJI_Lang.get("races.settings.title"),
        needConfirm = true,
        onClick = function()
            open(raceSettings)
        end,
    }
    updateLabels()
    local buttons
    local titlePrefix = string.format("%s (%s) - ",
        BJI_Lang.get("races.settings.title"),
        BJI_Lang.get(raceSettings.multi and
            "interactiveMarkers.multiRace.type" or
            "interactiveMarkers.soloRace.type"))
    local steps = Table()
    local stepOffset = 0

    -- laps
    if raceSettings.loopable then
        buttons = Table()
        for _, lapAmount in ipairs({ 1, 2, 3, 5, 10 }) do
            buttons:insert(
                {
                    icon = BJI_Prompt.quick.lap,
                    label = BJI_Lang.get("races.settings.lap" .. (lapAmount > 1 and "s" or ""))
                        :var({ lap = lapAmount, laps = lapAmount }),
                    onClick = function()
                        W.settings.laps = lapAmount
                    end,
                    clickToStep = 2,
                })
        end
        buttons:insert(settingsButton)
        steps:insert({
            title = string.format("%s%s", titlePrefix, W.labels.laps),
            cancelButton = cancelButton,
            buttons = buttons,
        })
    else
        stepOffset = -1
    end

    -- respawn strategy
    local function getIconByRespawnStrategy(key)
        if key == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key then
            return BJI_Prompt.quick.allResets
        elseif key == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key then
            return BJI_Prompt.quick.lastCheckpoint
        elseif key == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
            return BJI_Prompt.quick.forbidden
        elseif key == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key then
            return BJI_Prompt.quick.lastStand
        end
        return ""
    end
    buttons = table.map(raceSettings.respawnStrategies, function(rsKey)
        return {
            icon = getIconByRespawnStrategy(rsKey),
            label = W.labels.respawnStrategies[rsKey],
            needConfirm = not raceSettings.multi,
            onClick = function(ctxt)
                W.data.respawnStrategySelected = rsKey
                if not raceSettings.multi then
                    start(ctxt)
                end
            end,
            clickToStep = raceSettings.multi and (3 + stepOffset) or nil,
        }
    end)
    buttons:insert(settingsButton)
    steps:insert({
        title = string.format("%s%s", titlePrefix, W.labels.respawnStrategies.title),
        cancelButton = cancelButton,
        buttons = buttons,
    })

    if raceSettings.multi then
        -- collisions
        steps:insert({
            title = string.format("%s%s", titlePrefix, W.labels.collisions),
            cancelButton = cancelButton,
            buttons = {
                {
                    icon = BJI_Prompt.quick.collisions,
                    label = string.format("%s %s", W.labels.collisions, BJI_Lang.get("common.enabled")),
                    onClick = function(ctxt)
                        W.settings.collisions = true
                    end,
                    clickToStep = 4 + stepOffset,
                },
                {
                    icon = BJI_Prompt.quick.no_collisions,
                    label = string.format("%s %s", W.labels.collisions, BJI_Lang.get("common.disabled")),
                    onClick = function(ctxt)
                        W.settings.collisions = false
                    end,
                    clickToStep = 4 + stepOffset,
                },
                settingsButton,
            },
        })

        -- vehicle
        buttons = Table({
            {
                icon = BJI_Prompt.quick.all_models,
                label = W.labels.vehicle.all,
                onClick = function(ctxt)
                    W.data.vehicleSelected = W.VEHICLE_MODES.ALL
                end,
                clickToStep = 5 + stepOffset,
            }
        })
        ctxt = BJI_Tick.getContext()
        if ctxt.veh and ctxt.veh.isVehicle then
            buttons:insert({
                icon = BJI_Prompt.quick.model,
                label = string.format("%s (%s)", W.labels.vehicle.currentModel,
                    ctxt.veh.jbeam),
                onClick = function(ctxt)
                    W.data.vehicleSelected = W.VEHICLE_MODES.MODEL
                end,
                clickToStep = 5 + stepOffset,
            })
            buttons:insert({
                icon = BJI_Prompt.quick.config,
                label = string.format("%s (%s)", W.labels.vehicle.currentConfig,
                    BJI_Veh.getCurrentConfigLabel()),
                disabled = ctxt.isOwner and W.data.selfProtected or W.data.currentVehicleProtected,
                onClick = function(ctxt)
                    W.data.vehicleSelected = W.VEHICLE_MODES.CONFIG
                end,
                clickToStep = 5 + stepOffset,
            })
        end
        buttons:insert(settingsButton)
        steps:insert({
            title = string.format("%s%s", titlePrefix, W.labels.vehicle.title),
            cancelButton = cancelButton,
            buttons = buttons,
        })

        -- start vote or start race
        buttons = Table()
        if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) then
            buttons:insert({
                icon = BJI_Prompt.quick.vote,
                label = W.labels.startVote,
                needConfirm = true,
                onClick = startVote,
            })
        end
        if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) then
            buttons:insert({
                icon = BJI_Prompt.quick.start,
                label = W.labels.startRace,
                needConfirm = true,
                onClick = start,
            })
        end
        buttons:insert(settingsButton)
        steps:insert({
            title = string.format("%s%s", titlePrefix, W.labels.startRace),
            cancelButton = cancelButton,
            buttons = buttons,
        })
    end

    BJI_Prompt.createFlow(steps)
end

W.onLoad = onLoad
W.onUnload = onUnload

W.header = drawHeader
W.body = drawBody
W.footer = drawFooter

W.onClose = onClose
W.open = open
W.openPromptFlow = openPromptFlow
W.getState = function() return W.show end

return W
