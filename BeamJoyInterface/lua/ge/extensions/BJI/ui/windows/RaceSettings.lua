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

    cache = {
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
    },
}
--- gc prevention
local ctxt, configLabel, nextValue

local function onClose()
    W.show = false
end

local function updateLabels()
    W.cache.labels.unknown = BJI.Managers.Lang.get("common.unknown")

    W.cache.labels.title = W.settings.multi and
        BJI.Managers.Lang.get("races.preparation.multiplayer") or
        BJI.Managers.Lang.get("races.preparation.singleplayer")
    W.cache.labels.raceName = string.var("{1} \"{2}\"", { BJI.Managers.Lang.get("races.play.race"), W.settings.raceName })

    W.cache.labels.laps = BJI.Managers.Lang.get("races.edit.laps")
    W.cache.labels.manyLapsWarning = BJI.Managers.Lang.get("races.settings.manyLapsWarning")

    W.cache.labels.respawnStrategies.title = BJI.Managers.Lang.get("races.settings.respawnStrategies.title")
    W.cache.labels.respawnStrategies.all = BJI.Managers.Lang.get("races.settings.respawnStrategies.all")
    W.cache.labels.respawnStrategies.norespawn = BJI.Managers.Lang.get("races.settings.respawnStrategies.norespawn")
    W.cache.labels.respawnStrategies.lastcheckpoint = BJI.Managers.Lang.get(
        "races.settings.respawnStrategies.lastcheckpoint")
    W.cache.labels.respawnStrategies.stand = BJI.Managers.Lang.get("races.settings.respawnStrategies.stand")

    W.cache.labels.collisions = BJI.Managers.Lang.get("races.settings.collisions")

    W.cache.labels.vehicle.title = BJI.Managers.Lang.get("races.settings.vehicles.playerVehicle")
    W.cache.labels.vehicle.all = BJI.Managers.Lang.get("races.settings.vehicles.all")
    W.cache.labels.vehicle.currentModel = BJI.Managers.Lang.get("races.settings.vehicles.currentModel")
    W.cache.labels.vehicle.currentConfig = BJI.Managers.Lang.get("races.settings.vehicles.currentConfig")
    W.cache.labels.vehicle.vehicleProtected = BJI.Managers.Lang.get("vehicleSelector.protectedVehicle")
    W.cache.labels.vehicle.selfProtected = BJI.Managers.Lang.get("vehicleSelector.selfProtected")

    W.cache.labels.cancel = BJI.Managers.Lang.get("common.buttons.cancel")
    W.cache.labels.startVote = BJI.Managers.Lang.get("races.settings.startVote")
    W.cache.labels.startRace = BJI.Managers.Lang.get("races.settings.startRace")
end

local function updateCache()
    ctxt = BJI.Managers.Tick.getContext()

    W.cache.data.currentVeh.model = nil
    W.cache.data.currentVeh.modelLabel = nil
    W.cache.data.currentVeh.config = nil
    W.cache.data.comboRespawnStrategies = {}
    W.cache.data.comboVehicle = {}
    W.cache.data.showVoteBtn = false
    W.cache.data.showStartBtn = false

    -- autoclose checks
    if W.show and (not BJI.Managers.Scenario.isFreeroam() or (
            not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) and
            not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
            not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO)
        )) then
        onClose()
        return
    elseif not W.settings.multi and not ctxt.isOwner then
        onClose()
        return
    elseif W.settings.multi and BJI.Managers.Perm.getCountPlayersCanSpawnVehicle() < BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS then
        -- when a player leaves then there are not enough players to start
        BJI.Managers.Toast.warning(BJI.Managers.Lang.get("races.preparation.notEnoughPlayers"))
        onClose()
        return
    end

    -- respawn strategies
    W.cache.data.comboRespawnStrategies = Table(W.settings.respawnStrategies)
        :map(function(rs)
            return {
                value = rs,
                label = W.cache.labels.respawnStrategies[rs],
            }
        end)
    if not table.any(W.cache.data.comboRespawnStrategies, function(option)
            return option.value == W.cache.data.respawnStrategySelected
        end) then
        W.cache.data.respawnStrategySelected = W.cache.data.comboRespawnStrategies[1].value
    end

    if W.settings.multi then
        W.cache.data.currentVehicleProtected = ctxt.veh and not ctxt.isOwner and ctxt.veh.protected
        W.cache.data.selfProtected = ctxt.isOwner and settings.getValue("protectConfigFromClone", false) == true
        -- vehicle combo
        table.insert(W.cache.data.comboVehicle, {
            value = W.VEHICLE_MODES.ALL,
            label = W.cache.labels.vehicle.all,
        })
        if ctxt.veh and ctxt.veh.isVehicle and not BJI.Managers.Veh.isModelBlacklisted(ctxt.veh.jbeam) then
            table.insert(W.cache.data.comboVehicle, {
                value = W.VEHICLE_MODES.MODEL,
                label = W.cache.labels.vehicle.currentModel,
            })
            if not W.cache.data.currentVehicleProtected and not W.cache.data.selfProtected then
                table.insert(W.cache.data.comboVehicle, {
                    value = W.VEHICLE_MODES.CONFIG,
                    label = W.cache.labels.vehicle.currentConfig,
                })
            end
            if not W.cache.data.vehicleSelected then
                if W.settings.vehicleMode then
                    W.cache.data.vehicleSelected = table.find(W.cache.data.comboVehicle, function(v)
                        return v.value == W.settings.vehicleMode
                    end) or W.cache.data.comboVehicle[1]
                end
            end
        end
        if not table.find(W.cache.data.comboVehicle, function(option)
                return option.value == W.cache.data.vehicleSelected
            end) then
            W.cache.data.vehicleSelected = W.cache.data.comboVehicle[1].value
        end
    end

    -- current veh
    if ctxt.veh then
        W.cache.data.currentVeh.model = ctxt.veh.jbeam
        W.cache.data.currentVeh.modelLabel = BJI.Managers.Veh.getModelLabel(W.cache.data.currentVeh.model) or
            W.cache.labels.unknown

        W.cache.data.currentVeh.config = BJI.Managers.Veh.getFullConfig(ctxt.veh.veh.partConfig)
        configLabel = BJI.Managers.Veh.getCurrentConfigLabel()
        W.cache.data.currentVeh.configLabel = configLabel and string.var("{1} {2}",
            { W.cache.data.currentVeh.modelLabel, configLabel }) or W.cache.labels.unknown
    else
        W.cache.data.currentVeh.model = nil
        W.cache.data.currentVeh.modelLabel = nil
        W.cache.data.currentVeh.config = nil
        W.cache.data.currentVeh.configLabel = nil
    end

    W.cache.data.showVoteBtn = W.settings.multi and not BJI.Managers.Tournament.state and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)
    W.cache.data.showStartBtn = (W.settings.multi and BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO)) or
        (not W.settings.multi and BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO))
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels,
        W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.NG_VEHICLE_REPLACED,
        BJI.Managers.Events.EVENTS.VEHICLE_REMOVED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.CONFIG_PROTECTION_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI.Managers.Cache.CACHES.RACES or data.cache == BJI.Managers.Cache.CACHES.PLAYERS then
            updateCache()
        end
    end, W.name .. "Cache"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function drawHeader()
    Text(W.cache.labels.title, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
    Text(W.cache.labels.raceName)
end

local function drawBody(ctxt)
    if BeginTable("BJIRaceSettings", {
            { label = "##race-settings-labels" },
            { label = "##race-settings-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        if W.settings.loopable then
            TableNewRow()
            Text(W.cache.labels.laps)
            TableNextColumn()
            nextValue = SliderInt("raceSettingsLaps", W.settings.laps, 1, 50)
            if nextValue then W.settings.laps = nextValue end
            if W.settings.laps >= 20 then
                Text(W.cache.labels.manyLapsWarning, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
            end
        end

        TableNewRow()
        Text(W.cache.labels.respawnStrategies.title)
        TableNextColumn()
        nextValue = Combo("respawnStrategies", W.cache.data.respawnStrategySelected,
            W.cache.data.comboRespawnStrategies, { width = -1 })
        if nextValue then W.cache.data.respawnStrategySelected = nextValue end

        if W.settings.multi then
            TableNewRow()
            Text(W.cache.labels.collisions)
            TableNextColumn()
            if IconButton("raceSettingsCollisions", W.settings.collisions and BJI.Utils.Icon.ICONS.check_circle or
                    BJI.Utils.Icon.ICONS.cancel, { btnStyle = W.settings.collisions and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                        BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
                W.settings.collisions = not W.settings.collisions
            end

            TableNewRow()
            Text(W.cache.labels.vehicle.title)
            TableNextColumn()
            if W.cache.data.selfProtected then
                ShowHelpMarker(W.cache.labels.vehicle.selfProtected)
                SameLine()
            elseif W.cache.data.currentVehicleProtected then
                ShowHelpMarker(W.cache.labels.vehicle.vehicleProtected)
                SameLine()
            end
            nextValue = Combo("settingsVehicle", W.cache.data.vehicleSelected, W.cache.data.comboVehicle, { width = -1 })
            if nextValue then W.cache.data.vehicleSelected = nextValue end

            if W.cache.data.vehicleSelected ~= W.VEHICLE_MODES.ALL then
                TableNewRow()
                TableNextColumn()
                Text(W.cache.data.vehicleSelected == W.VEHICLE_MODES.MODEL and
                    W.cache.data.currentVeh.modelLabel or W.cache.data.currentVeh.configLabel)
            end
        end

        EndTable()
    end
end

local function getPayloadSettings()
    return {
        laps = W.settings.loopable and W.settings.laps or nil,
        model = W.cache.data.vehicleSelected ~= W.VEHICLE_MODES.ALL and W.cache.data.currentVeh.model or nil,
        config = W.cache.data.vehicleSelected == W.VEHICLE_MODES.CONFIG and W.cache.data.currentVeh.config or nil,
        respawnStrategy = W.cache.data.respawnStrategySelected,
        collisions = W.settings.collisions
    }
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    if not W.settings then return end
    if IconButton("cancelRaceStart", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.cache.labels.cancel)
    if W.cache.data.showVoteBtn then
        SameLine()
        if IconButton("voteRaceStart", BJI.Utils.Icon.ICONS.event_available,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            BJI.Tx.vote.RaceStart(W.settings.raceID, true, getPayloadSettings())
            onClose()
        end
        TooltipText(W.cache.labels.startVote)
    end
    if W.cache.data.showStartBtn then
        SameLine()
        if IconButton("raceStart", BJI.Utils.Icon.ICONS.videogame_asset,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            if W.settings.multi then
                BJI.Tx.vote.RaceStart(W.settings.raceID, false, getPayloadSettings())
                onClose()
            else
                BJI.Tx.scenario.RaceDetails(W.settings.raceID, function(raceData)
                    if raceData then
                        if BJI.Managers.Scenario.isFreeroam() then
                            BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_SOLO).initRace(
                                ctxt,
                                {
                                    laps = raceData.loopable and W.settings.laps or nil,
                                    respawnStrategy = W.cache.data.respawnStrategySelected,
                                },
                                raceData
                            )
                        end
                        onClose()
                    else
                        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.invalidData"))
                    end
                end)
            end
        end
        TooltipText(W.cache.labels.startRace)
    end
end

---@param raceSettings RaceSettings
local function open(raceSettings)
    if #raceSettings.respawnStrategies == 0 then
        LogError("No respawn strategies found")
        return
    end

    raceSettings.laps = raceSettings.laps or W.settings.laps or 1
    raceSettings.collisions = raceSettings.collisions or W.settings.collisions
    W.settings = raceSettings

    W.cache.data.respawnStrategySelected = W.settings.defaultRespawnStrategy or W.cache.data.respawnStrategySelected
    W.cache.data.vehicleSelected = W.cache.data.vehicleSelected or W.VEHICLE_MODES.ALL

    if BJI.Managers.Scenario.isFreeroam() and
        (BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) or
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO)) then
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

W.onLoad = onLoad
W.onUnload = onUnload

W.header = drawHeader
W.body = drawBody
W.footer = drawFooter

W.onClose = onClose
W.open = open
W.getState = function() return W.show end

return W
