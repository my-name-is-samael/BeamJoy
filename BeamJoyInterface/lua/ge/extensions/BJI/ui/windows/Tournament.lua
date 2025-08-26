---@class BJIWindowTournament : BJIWindow
local W = {
    name = "Tournament",
    minSize = ImVec2(450, 300),

    ACTIVITIES_FILTERS = Table({
        [BJI_Tournament.ACTIVITIES_TYPES.RACE_SOLO] = function()
            return table.length(BJI_Scenario.Data.Races) > 0
        end,
        [BJI_Tournament.ACTIVITIES_TYPES.RACE] = function()
            return table.filter(BJI_Scenario.Data.Races,
                    function(r) return r.places > 1 end):length() > 0 and
                BJI_Context.Players:length() >=
                BJI_Scenario.get(BJI_Scenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS
        end,
        [BJI_Tournament.ACTIVITIES_TYPES.SPEED] = function()
            return BJI_Context.Players:length() >=
                BJI_Scenario.get(BJI_Scenario.TYPES.SPEED).MINIMUM_PARTICIPANTS
        end,
        [BJI_Tournament.ACTIVITIES_TYPES.HUNTER] = function()
            return BJI_Scenario.Data.HunterInfected and
                BJI_Scenario.Data.HunterInfected.enabledHunter and
                BJI_Context.Players:length() >=
                BJI_Scenario.get(BJI_Scenario.TYPES.HUNTER)
                .MINIMUM_PARTICIPANTS
        end,
        [BJI_Tournament.ACTIVITIES_TYPES.INFECTED] = function()
            return BJI_Scenario.Data.HunterInfected and
                BJI_Scenario.Data.HunterInfected.enabledInfected and
                BJI_Context.Players:length() >=
                BJI_Scenario.get(BJI_Scenario.TYPES.INFECTED)
                .MINIMUM_PARTICIPANTS
        end,
        [BJI_Tournament.ACTIVITIES_TYPES.DERBY] = function()
            return table.filter(BJI_Scenario.Data.Derby,
                    function(a) return a.enabled end):length() > 0 and
                BJI_Context.Players:length() >=
                BJI_Scenario.get(BJI_Scenario.TYPES.DERBY).MINIMUM_PARTICIPANTS
        end,
    }),

    manualShow = false,

    labels = {
        title = "",
        state = "",
        whitelist = "",
        activityTimeoutIn = "",
        activityAboutToTimeout = "",
        total = "",
        noParticipant = "",
        zeroScoreTooltip = "",
        activities = {},
        buttons = {
            edit = "",
            remove = "",
            confirm = "",
            cancel = "",
            join = "",
            add = "",
            start = "",
            resetAll = "",
            endSoloActivity = "",
            endTournament = "",
            endTournamentTooltip = "",
            errorMustHaveVehicle = "",
        },
        startActivity = {
            title = "",
            track = "",
            arena = "",
            duration = "",
        }
    },
    cache = {
        ---@type tablelib<string, tablelib<integer, integer>> index playerNames > index activityIndex
        inputs = Table(),
        staffView = false,
        disableToggleBtns = false,
        tournamentData = {
            inFreeroam = false,
            showPlayersModeration = false,
            activities = Table(),
            columnsConfig = Table(),
            players = Table(),
        },
        showPlayersCombo = false,
        ---@type ComboOption[]
        playersCombo = Table(),
        ---@type string?
        selectedPlayer = nil,
        showStartActivity = false,
        ---@type tablelib<integer, {value: string, label: string}>
        startActivityCombo = Table(),
        ---@type {value: string, label: string}?
        selectedStartActivity = nil,
        showStartActivitySec = false,
        startActivitySecLabel = function() return "" end,
        ---@type tablelib<integer, {value: integer, label: string}>
        startActivitySecCombo = Table(),
        ---@type {value: integer, label: string}?
        selectedStartActivitySec = nil,
        showStartActivityDuration = false,
        startActivityDuration = 5,

        disableInputs = false,
    },
    ---@type BJIManagerTournament?
    manager = nil,
}
--- gc prevention
local nextValue, drawn, remainingSecs, label, scenario, sorted, staff, inFreeroam,
showPlayersModeration, cells, total, score, custom, totalIncr

local function onClose()
    W.manualShow = false
end

local function updateLabels()
    W.labels.title = BJI_Lang.get("tournament.title")
    W.labels.state = BJI_Lang.get("tournament.state")
    W.labels.whitelist = BJI_Lang.get("tournament.whitelist")
    W.labels.activityTimeoutIn = BJI_Lang.get("tournament.activityTimeoutIn")
    W.labels.activityAboutToTimeout = BJI_Lang.get("tournament.activityAboutToTimeout")
    W.labels.total = BJI_Lang.get("tournament.total")
    W.labels.noParticipant = BJI_Lang.get("tournament.noParticipant")
    W.labels.zeroScoreTooltip = BJI_Lang.get("tournament.zeroScoreTooltip")
    W.labels.startActivity.title = BJI_Lang.get("tournament.startActivity")
    W.labels.startActivity.track = BJI_Lang.get("tournament.track")
    W.labels.startActivity.arena = BJI_Lang.get("tournament.arena")
    W.labels.startActivity.duration = BJI_Lang.get("tournament.duration")

    W.labels.buttons.edit = BJI_Lang.get("common.buttons.edit")
    W.labels.buttons.remove = BJI_Lang.get("common.buttons.remove")
    W.labels.buttons.confirm = BJI_Lang.get("common.buttons.confirm")
    W.labels.buttons.cancel = BJI_Lang.get("common.buttons.cancel")
    W.labels.buttons.join = BJI_Lang.get("common.buttons.join")
    W.labels.buttons.add = BJI_Lang.get("common.buttons.add")
    W.labels.buttons.start = BJI_Lang.get("common.buttons.start")
    W.labels.buttons.resetAll = BJI_Lang.get("common.buttons.resetAll")
    W.labels.buttons.endSoloActivity = BJI_Lang.get("tournament.buttons.endSoloActivity")
    W.labels.buttons.endTournament = BJI_Lang.get("tournament.buttons.endTournament")
    W.labels.buttons.endTournamentTooltip = BJI_Lang.get("tournament.buttons.endTournamentTooltip")
    W.labels.buttons.errorMustHaveVehicle = BJI_Lang.get("tournament.buttons.errorMustHaveVehicle")

    Table(W.manager.ACTIVITIES_TYPES):forEach(function(type)
        W.labels.activities[type] = BJI_Lang.get("tournament.activities." .. type, type)
    end)
end

---@param staff boolean
---@return boolean
local function canAddOrRemovePlayer(staff)
    if staff then
        if not BJI_Scenario.isServerScenarioInProgress() then
            return true
        elseif BJI_Scenario.is(BJI_Scenario.TYPES.RACE_MULTI) then
            scenario = BJI_Scenario.get(BJI_Scenario.TYPES.RACE_MULTI)
            return scenario.state == scenario.STATES.GRID
        elseif BJI_Scenario.is(BJI_Scenario.TYPES.HUNTER) then
            scenario = BJI_Scenario.get(BJI_Scenario.TYPES.HUNTER)
            return scenario.state == scenario.STATES.PREPARATION
        elseif BJI_Scenario.is(BJI_Scenario.TYPES.DERBY) then
            scenario = BJI_Scenario.get(BJI_Scenario.TYPES.DERBY)
            return scenario.state == scenario.STATES.PREPARATION
        end
    end
    return false
end

---@return boolean
local function isSoloActivityInProgress()
    return W.manager.activities[#W.manager.activities] ~= nil and
        W.manager.activities[#W.manager.activities].targetTime ~= nil
end

---@param playerName string
---@return integer?
local function getCurrentSoloRaceScore(playerName)
    if isSoloActivityInProgress() and W.manager.activities[#W.manager.activities].raceID then
        ---@param p BJTournamentPlayer
        sorted = W.manager.players:filter(function(p)
            return p.scores[#W.manager.activities] and p.scores[#W.manager.activities].tempValue
        end):map(function(p)
            return {
                playerName = p.playerName,
                time = p.scores[#W.manager.activities].tempValue,
            }
        end):sort(function(a, b)
            if a.time and b.time then
                return a.time < b.time
            else
                return a.time
            end
        end):map(function(el)
            return el.playerName
        end)
        return table.indexOf(sorted, playerName)
    end
end

local previousActivitiesAmount = 0
local function updateData()
    if not W.getState() then return end

    W.manager = BJI_Tournament
    staff = BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO)
    inFreeroam = BJI_Scenario.isFreeroam()
    showPlayersModeration = canAddOrRemovePlayer(staff)

    if W.manager.state then
        W.onClose = nil
    elseif staff then
        W.onClose = onClose
    end

    W.cache.disableInputs = false
    W.cache.staffView = staff
    W.cache.disableToggleBtns = not inFreeroam

    -- player combo
    W.cache.showPlayersCombo = staff and showPlayersModeration
    W.cache.playersCombo = Table()
    if W.cache.showPlayersCombo then
        W.cache.playersCombo = BJI_Context.Players:filter(function(p)
                return not W.manager.players:any(function(p2)
                    return p.playerName == p2.playerName
                end) and BJI_Perm.canSpawnVehicle(p.playerID)
            end):map(function(p)
                return {
                    value = p.playerName,
                    label = p.playerName,
                }
            end)
            :values():sort(function(a, b) return a.label:lower() < b.label:lower() end)
        if not W.cache.playersCombo:any(function(option)
                return option.value == W.cache.selectedPlayer
            end) then
            W.cache.selectedPlayer = W.cache.playersCombo[1] and W.cache.playersCombo[1].value or nil
        end

        if #W.cache.playersCombo == 0 then
            W.cache.showPlayersCombo = false
        end
    end

    W.cache.showStartActivitySec = false
    W.cache.showStartActivityDuration = false
    W.cache.showStartActivity = W.manager.state and staff and inFreeroam and
        not isSoloActivityInProgress()
    if W.cache.showStartActivity then
        W.cache.startActivityCombo = Table(W.ACTIVITIES_FILTERS):filter(function(af) return af() end):map(function(_, t)
            return {
                value = t,
                label = W.labels.activities[t],
            }
        end):values():sort(function(a, b) return a.label < b.label end)
        if not W.cache.startActivityCombo:any(function(el)
                return el.value == W.cache.selectedStartActivity
            end) then
            W.cache.selectedStartActivity = W.cache.startActivityCombo[1].value
        end
        if #W.cache.startActivityCombo == 0 then
            W.cache.showStartActivity = false
        end
    end

    if W.cache.showStartActivity then
        if W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.DERBY then
            W.cache.showStartActivitySec = true
            W.cache.startActivitySecLabel = function() return W.labels.startActivity.arena end
            W.cache.startActivitySecCombo = Table(BJI_Scenario.Data.Derby):filter(function(a)
                return a.enabled
            end):map(function(arena, i)
                return {
                    value = i,
                    label = arena.name,
                }
            end):values():sort(function(a, b) return a.label < b.label end)
            if not W.cache.startActivitySecCombo:any(function(el)
                    return el.value == W.cache.selectedStartActivitySec
                end) then
                W.cache.selectedStartActivitySec = W.cache.startActivitySecCombo[1].value
            end
        elseif W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.RACE_SOLO or
            W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.RACE then
            W.cache.showStartActivitySec = true
            W.cache.startActivitySecLabel = function() return W.labels.startActivity.track end
            W.cache.startActivitySecCombo = Table(BJI_Scenario.Data.Races):filter(function(r)
                return W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.RACE_SOLO or
                    r.places > 1
            end):map(function(r)
                local label = r.name
                if W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.RACE then
                    label = label .. string.var(" ({1})",
                        { BJI_Lang.get("races.preparation.places"):var({ places = r.places }) })
                end
                return {
                    value = r.id,
                    label = label,
                }
            end):values():sort(function(a, b)
                if not a.label or not b.label then
                    return a.label ~= nil
                end
                return a.label < b.label
            end)
            if not W.cache.startActivitySecCombo:any(function(el)
                    return el.value == W.cache.selectedStartActivitySec
                end) then
                W.cache.selectedStartActivitySec = W.cache.startActivitySecCombo[1].value
            end

            if W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.RACE_SOLO then
                W.cache.showStartActivityDuration = true
                W.cache.startActivityDuration = math.clamp(W.cache.startActivityDuration, 2, 120)
            end
        end
    end

    if previousActivitiesAmount > #W.manager.activities then
        -- on activity removed (or data resetted), clear inputs
        W.cache.inputs = Table()
    else
        -- remove obsolete inputs
        W.cache.inputs = W.cache.inputs:filter(function(_, playerName)
            return W.manager.players:any(function(p) return p.playerName == playerName end)
        end)
    end
    previousActivitiesAmount = #W.manager.activities

    W.cache.tournamentData.inFreeroam = inFreeroam
    W.cache.tournamentData.showPlayersModeration = showPlayersModeration
    W.cache.tournamentData.activities = W.manager.activities:map(function(a, i)
        local soloActInProgress = i == #W.manager.activities and isSoloActivityInProgress()
        return {
            type = a.type,
            name = a.name,
            raceID = a.raceID,
            isSoloActivityInProgress = soloActInProgress,
            soloRaceName = a.raceID and (Table(BJI_Scenario.Data.Races)
                :find(function(r) return r.id == a.raceID end) or { name = "INVALID" }).name or nil,
            targetTime = a.targetTime,
            showJoinSoloRace = W.manager.state and soloActInProgress and a.raceID and
                (not W.manager.whitelist or W.manager.whitelistPlayers
                    :includes(BJI_Context.User.playerName))
        }
    end)
    W.cache.tournamentData.columnsConfig = Table({
        { label = "##tournament-players" },
    })
    W.cache.tournamentData.activities:forEach(function(_, i, t)
        W.cache.tournamentData.columnsConfig:insert({
            label = "##tournament-activity-" .. tostring(i),
        })
    end)
    W.cache.tournamentData.columnsConfig:insert({
        label = "##tournament-activity-spacer",
        flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH }
    })
    W.cache.tournamentData.columnsConfig:insert({ label = "##tournament-total" })
    W.cache.tournamentData.players = W.manager.players:map(function(p)
        cells = Table({
            { -- name column
                playerName = p.playerName,
                color = p.playerName == BJI_Context.User.playerName and
                    BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil
            }
        })
        total = 0
        W.cache.tournamentData.activities:forEach(function(a, i, t)
            score, custom, totalIncr = nil, nil, #W.manager.players
            if p.scores[i] then
                if p.scores[i].tempValue then
                    -- parse tempValue
                    if a.raceID then
                        -- solo race time
                        totalIncr = getCurrentSoloRaceScore(p.playerName) or #W.manager.players
                        custom = BJI.Utils.UI.RaceDelay(p.scores[i].tempValue)
                    else
                        custom = p.scores[i].tempValue
                    end
                end
                if p.scores[i].score then
                    score = p.scores[i].score
                    totalIncr = score
                end
            end
            total = total + totalIncr
            cells:insert({ -- activities columns
                score = score,
                custom = custom,
                edit = staff and W.cache.inputs[p.playerName] and W.cache.inputs[p.playerName][i],
                canEdit = staff and (i < #W.cache.tournamentData.activities or
                    BJI_Scenario.isFreeroam()),
            })
        end)
        cells:insert({})                -- spacer
        cells:insert({ score = total }) -- total column
        return cells
    end)
end

local listeners = Table()
local function onLoad()
    W.manager = BJI_Tournament

    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateData()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.SCENARIO_UPDATED,
        BJI_Events.EVENTS.PLAYER_CONNECT,
        BJI_Events.EVENTS.PLAYER_DISCONNECT,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateData, W.name .. "Data"))
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
    }, function(_, data)
        if table.includes({
                BJI_Cache.CACHES.RACES,
                BJI_Cache.CACHES.HUNTER_INFECTED_DATA,
                BJI_Cache.CACHES.DERBY_DATA,
            }, data.cache) then
            updateData()
        end
    end, W.name .. "ScenarioData"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

---@param ctxt TickContext
local function header(ctxt)
    if BeginTable("BJITournamentHeader", {
            { label = "##tournament-header-left",   flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##tournament-header-middle", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##tournament-header-right" },
        }) then
        TableNewRow()
        Text(W.labels.title)
        TableNextColumn()
        Text(W.labels.state)
        SameLine()
        if IconButton("toggleState", W.manager.state and BJI.Utils.Icon.ICONS.check_circle or
                BJI.Utils.Icon.ICONS.cancel, { bgLess = true, disabled = W.cache.disableInputs or
                    W.cache.disableToggleBtns, btnStyle = W.manager.state and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            W.cache.disableInputs = true
            BJI_Tx_tournament.toggle(not W.manager.state)
        end
        TableNextColumn()
        Text(W.labels.whitelist)
        SameLine()
        if IconButton("toggleWhitelist", W.manager.whitelist and BJI.Utils.Icon.ICONS.check_circle or
                BJI.Utils.Icon.ICONS.cancel, { bgLess = true, disabled = W.cache.disableInputs or
                    W.cache.disableToggleBtns, btnStyle = W.manager.whitelist and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            W.cache.disableInputs = true
            BJI_Tx_tournament.toggleWhitelist(not W.manager.whitelist)
        end

        EndTable()
    end
end

local function drawTournamentData(ctxt)
    if BeginTable("BJITournamentData", W.cache.tournamentData.columnsConfig,
            { flags = { TABLE_FLAGS.BORDERS_INNER } }) then
        TableNewRow()
        W.cache.tournamentData.activities:forEach(function(a, i)
            drawn = false
            TableNextColumn()
            if W.cache.tournamentData.inFreeroam and W.cache.staffView then
                if a.isSoloActivityInProgress then
                    if IconButton("endSoloActivity", BJI.Utils.Icon.ICONS.check_circle,
                            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, bgLess = true,
                                disabled = W.cache.disableInputs }) then
                        W.cache.disableInputs = true
                        BJI_Tx_tournament.endSoloActivity()
                    end
                    TooltipText(W.labels.buttons.endSoloActivity)
                else
                    if IconButton("removeActivity-" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true,
                                disabled = W.cache.disableInputs }) then
                        W.cache.disableInputs = true
                        BJI_Tx_tournament.removeActivity(i)
                    end
                    TooltipText(W.labels.buttons.remove)
                end
                drawn = true
            end
            if drawn then SameLine() end
            Text(W.labels.activities[a.type])
            if W.cache.tournamentData.inFreeroam and a.showJoinSoloRace then
                SameLine()
                if IconButton("joinActivity", BJI.Utils.Icon.ICONS.videogame_asset,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = not ctxt.isOwner }) then
                    Table(BJI_Scenario.Data.Races)
                        :find(function(r) return r.id == a.raceID end, function(race)
                            BJI_Win_RaceSettings.open({
                                multi = false,
                                raceID = race.id,
                                raceName = race.name,
                                loopable = race.loopable,
                                defaultRespawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES
                                    .LAST_CHECKPOINT.key,
                                respawnStrategies = Table(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES)
                                    :filter(function(rs)
                                        return race.hasStand or
                                            rs.key ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key
                                    end)
                                    :sort(function(el1, el2) return el1.order < el2.order end)
                                    :map(function(el) return el.key end),
                            })
                        end)
                end
            end
            if a.name then
                Text(a.name)
            end
            if a.targetTime then
                remainingSecs = math.round((a.targetTime - ctxt.now) / 1000)
                if remainingSecs > 0 then
                    label = W.labels.activityTimeoutIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingSecs) })
                else
                    label = W.labels.activityAboutToTimeout
                end
                Text(label, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
            end
        end)
        TableNextColumn() -- spacer
        TableNextColumn()
        Text(W.labels.total)

        W.cache.tournamentData.players:forEach(function(cells, iPlayer)
            TableNewRow()
            if W.cache.tournamentData.showPlayersModeration then
                if IconButton("removePlayer-" .. tostring(iPlayer), BJI.Utils.Icon.ICONS.delete_forever,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true,
                            disabled = W.cache.disableInputs }) then
                    W.cache.disableInputs = true
                    BJI_Tx_tournament.removePlayer(cells[1].playerName)
                end
                TooltipText(W.labels.buttons.remove)
                SameLine()
            end
            Text(cells[1].playerName, { color = cells[1].color })
            for iCell = 2, #cells do
                TableNextColumn()
                if iCell < #cells then
                    if cells[iCell].custom then
                        Text(cells[iCell].custom)
                    elseif cells[iCell].edit then
                        if IconButton("canceledit-" .. tostring(iPlayer) .. "-" .. tostring(iCell),
                                BJI.Utils.Icon.ICONS.cancel, { disabled = W.cache.disableInputs,
                                    btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
                            W.cache.inputs[cells[1].playerName][iCell - 1] = nil
                            cells[iCell].edit = false
                            updateData()
                        end
                        TooltipText(W.labels.buttons.cancel)
                        SameLine()
                        if IconButton("confirmedit-" .. tostring(iPlayer) .. "-" .. tostring(iCell),
                                W.cache.inputs[cells[1].playerName][iCell - 1] == 0 and
                                BJI.Utils.Icon.ICONS.delete_forever or BJI.Utils.Icon.ICONS.check_circle,
                                { disabled = W.cache.disableInputs, bgLess = true,
                                    btnStyle = W.cache.inputs[cells[1].playerName][iCell - 1] == 0 and
                                        BJI.Utils.Style.BTN_PRESETS.ERROR or BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                            W.cache.disableInputs = true
                            BJI_Tx_tournament.editScore(cells[1].playerName, iCell - 1,
                                W.cache.inputs[cells[1].playerName][iCell - 1])
                            cells[iCell].score = W.cache.inputs[cells[1].playerName][iCell - 1] ~= 0 and
                                W.cache.inputs[cells[1].playerName][iCell - 1] or nil
                            W.cache.inputs[cells[1].playerName][iCell - 1] = nil
                            cells[iCell].edit = false
                        end
                        TooltipText(W.labels.buttons.confirm)
                        SameLine()
                        nextValue = InputInt("edit-" .. tostring(iPlayer) .. "-" .. tostring(iCell),
                            W.cache.inputs[cells[1].playerName][iCell - 1] or 0, {
                                disabled = W.cache.disableInputs,
                                min = 0,
                                max = #W.cache.tournamentData.players,
                                width = 200
                            })
                        TooltipText(W.labels.zeroScoreTooltip)
                        if nextValue then W.cache.inputs[cells[1].playerName][iCell - 1] = nextValue end
                    else
                        if cells[iCell].canEdit then
                            if IconButton("startedit-" .. tostring(iPlayer) .. "-" .. tostring(iCell),
                                    cells[iCell].score and BJI.Utils.Icon.ICONS.mode_edit or BJI.Utils.Icon.ICONS.add_circle,
                                    { btnStyle = cells[iCell].score and BJI.Utils.Style.BTN_PRESETS.WARNING or
                                        BJI.Utils.Style.BTN_PRESETS.SUCCESS, bgLess = not cells[iCell].score,
                                        disabled = W.cache.disableInputs }) then
                                if not W.cache.inputs[cells[1].playerName] then
                                    W.cache.inputs[cells[1].playerName] = {}
                                end
                                W.cache.inputs[cells[1].playerName][iCell - 1] = cells[iCell].score or
                                    #W.cache.tournamentData.players
                                updateData()
                            end
                            SameLine()
                        end
                        if cells[iCell].score then
                            Text(tostring(cells[iCell].score))
                        end
                    end
                else -- total
                    Text(tostring(cells[iCell].score))
                end
            end
        end)
        if #W.cache.tournamentData.players == 0 then
            TableNewRow()
            Text(W.labels.noParticipant)
        end

        EndTable()
    end
end

local function drawAddPlayerCombo(ctxt)
    if W.cache.showPlayersCombo then
        if IconButton("addWhitelistPlayer", BJI.Utils.Icon.ICONS.add,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                    not W.cache.selectedPlayer or #W.cache.selectedPlayer == 0 }) then
            W.cache.disableInputs = true
            BJI_Tx_tournament.togglePlayer(W.cache.selectedPlayer, true)
        end
        TooltipText(W.labels.buttons.add)
        SameLine()
        nextValue = Combo("whitelistPlayersCombo", W.cache.selectedPlayer, W.cache.playersCombo,
            { disabled = W.cache.disableInputs })
        if nextValue then W.cache.selectedPlayer = nextValue end
    end
end

local function drawStartActivity(ctxt)
    if W.cache.showStartActivity then
        if W.cache.showPlayersCombo then
            Separator()
        end
        if BeginTable("BJITournamentStartActivity", {
                { label = "##tournament-startactivity-labels" },
                { label = "##tournament-startactivity-combo" },
                { label = "##tournament-startactivity-extra", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            }) then
            TableNewRow()
            Text(W.labels.startActivity.title)
            TableNextColumn()
            nextValue = Combo("startActivityCombo", W.cache.selectedStartActivity,
                W.cache.startActivityCombo:filter(function(p)
                    return not W.cache.disableInputs or p == W.cache.selectedStartActivity
                end))
            if nextValue then
                W.cache.selectedStartActivity = nextValue
                updateData()
            end

            if W.cache.showStartActivitySec then
                TableNewRow()
                Text(W.cache.startActivitySecLabel())
                TableNextColumn()
                nextValue = Combo("startActivitySecCombo", W.cache.selectedStartActivitySec,
                    W.cache.startActivitySecCombo:filter(function(p)
                        return not W.cache.disableInputs or p == W.cache.selectedStartActivitySec
                    end))
                if nextValue then
                    W.cache.selectedStartActivitySec = nextValue
                end
                if W.cache.showStartActivityDuration then
                    TableNextColumn()
                    Text(W.labels.startActivity.duration)
                    SameLine()
                    nextValue = SliderIntPrecision("startActivityDuration", W.cache.startActivityDuration, 2, 120,
                        { formatRender = BJI.Utils.UI.PrettyDelay(W.cache.startActivityDuration * 60) })
                    if nextValue then W.cache.startActivityDuration = nextValue end
                end
            end

            EndTable()
        end
        if Button("startActivity", W.labels.buttons.start,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not W.cache.selectedStartActivity }) then
            if W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.RACE_SOLO then
                W.cache.disableInputs = true
                W.cache.showStartActivity = false
                BJI_Tx_tournament.addSoloRace(W.cache.selectedStartActivitySec,
                    W.cache.startActivityDuration)
            elseif W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.RACE then
                Table(BJI_Scenario.Data.Races):find(function(r)
                    return r.id == W.cache.selectedStartActivitySec and r.places > 1
                end, function(race)
                    BJI_Win_RaceSettings.open({
                        multi = true,
                        raceID = race.id,
                        raceName = race.name,
                        loopable = race.loopable,
                        defaultRespawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES
                            .LAST_CHECKPOINT.key,
                        respawnStrategies = Table(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES)
                            :sort(function(a, b) return a.order < b.order end)
                            :map(function(el) return el.key end)
                            :filter(function(rs)
                                return race.hasStand or
                                    rs ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key
                            end),
                    })
                end)
            elseif W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.SPEED then
                BJI_Tx_vote.ScenarioStart(BJI_Votes.SCENARIO_TYPES.SPEED, false)
            elseif W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.HUNTER then
                BJI_Win_HunterSettings.open()
            elseif W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.INFECTED then
                BJI_Win_InfectedSettings.open()
            elseif W.cache.selectedStartActivity == W.manager.ACTIVITIES_TYPES.DERBY then
                BJI_Win_DerbySettings.open(W.cache.selectedStartActivitySec)
            end
        end
    end
end

---@param ctxt TickContext
local function body(ctxt)
    EmptyLine()

    drawTournamentData(ctxt)
    drawAddPlayerCombo(ctxt)
    for _ = 1, 3 - #W.manager.players do
        EmptyLine()
    end

    drawStartActivity(ctxt)

    if W.cache.staffView and BeginTable("BJITournamentFooter", {
            { label = "##tournament-footer-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##tournament-footer-right" },
        }) then
        TableNewRow()
        TableNextColumn()
        if Button("resetTournament", W.labels.buttons.resetAll,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs or
                    (#W.manager.players == 0 and #W.manager.activities == 0) }) then
            W.cache.disableInputs = true
            BJI_Tx_tournament.clear()
        end
        SameLine()
        if Button("endTournament", W.labels.buttons.endTournament,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                    not W.manager.state or #W.manager.activities == 0 }) then
            W.cache.disableInputs = true
            BJI_Tx_tournament.endTournament()
        end
        TooltipText(W.labels.buttons.endTournamentTooltip)

        EndTable()
    end
end

local function open()
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) and
        not BJI_Tournament.state then
        W.manualShow = true
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.open = open
W.getState = function()
    return W.manualShow or BJI_Tournament.state
end

W.updateData = updateData

return W
