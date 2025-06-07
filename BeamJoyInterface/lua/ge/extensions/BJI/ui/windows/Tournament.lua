---@class BJIWindowTournament : BJIWindow
local W = {
    name = "Tournament",
    w = 450,
    h = 300,

    ACTIVITIES_FILTERS = Table({
        [BJI.Managers.Tournament.ACTIVITIES_TYPES.RACE_SOLO] = function()
            return table.length(BJI.Managers.Context.Scenario.Data.Races) > 0
        end,
        [BJI.Managers.Tournament.ACTIVITIES_TYPES.RACE] = function()
            return table.filter(BJI.Managers.Context.Scenario.Data.Races,
                    function(r) return r.places > 1 end):length() > 0 and
                table.length(BJI.Managers.Context.Players) >=
                BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS
        end,
        [BJI.Managers.Tournament.ACTIVITIES_TYPES.SPEED] = function()
            return table.length(BJI.Managers.Context.Players) >=
                BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.SPEED).MINIMUM_PARTICIPANTS
        end,
        [BJI.Managers.Tournament.ACTIVITIES_TYPES.HUNTER] = function()
            return BJI.Managers.Context.Scenario.Data.Hunter and
                BJI.Managers.Context.Scenario.Data.Hunter.enabled and
                table.length(BJI.Managers.Context.Players) >=
                BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.HUNTER)
                .MINIMUM_PARTICIPANTS
        end,
        [BJI.Managers.Tournament.ACTIVITIES_TYPES.DERBY] = function()
            return table.length(BJI.Managers.Context.Scenario.Data.Derby) > 0 and
                table.length(BJI.Managers.Context.Players) >=
                BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DERBY).MINIMUM_PARTICIPANTS
        end,
        [BJI.Managers.Tournament.ACTIVITIES_TYPES.TAG] = function()
            return false -- TODO
        end
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
            endSoloRace = "",
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
        ---@type ColumnsBuilder?
        chartCols = nil,
        showPlayersCombo = false,
        ---@type tablelib<integer, string>
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
    widths = {
        whitelist = 0,
        editNumInput = 0,
        editInputsCol = 0,
        chart = {},
        whitelistPlayerCombo = 0,
        addActivityLabels = 0,
        addActivityCombos = 0,
        clearAndEnd = 0,
    },
    ---@type BJIManagerTournament?
    manager = nil,
}

local function onClose()
    W.manualShow = false
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("tournament.title")
    W.labels.state = BJI.Managers.Lang.get("tournament.state")
    W.labels.whitelist = BJI.Managers.Lang.get("tournament.whitelist")
    W.labels.activityTimeoutIn = BJI.Managers.Lang.get("tournament.activityTimeoutIn")
    W.labels.activityAboutToTimeout = BJI.Managers.Lang.get("tournament.activityAboutToTimeout")
    W.labels.total = BJI.Managers.Lang.get("tournament.total")
    W.labels.noParticipant = BJI.Managers.Lang.get("tournament.noParticipant")
    W.labels.startActivity.title = BJI.Managers.Lang.get("tournament.startActivity")
    W.labels.startActivity.track = BJI.Managers.Lang.get("tournament.track")
    W.labels.startActivity.arena = BJI.Managers.Lang.get("tournament.arena")
    W.labels.startActivity.duration = BJI.Managers.Lang.get("tournament.duration")

    W.labels.buttons.edit = BJI.Managers.Lang.get("common.buttons.edit")
    W.labels.buttons.remove = BJI.Managers.Lang.get("common.buttons.remove")
    W.labels.buttons.confirm = BJI.Managers.Lang.get("common.buttons.confirm")
    W.labels.buttons.cancel = BJI.Managers.Lang.get("common.buttons.cancel")
    W.labels.buttons.join = BJI.Managers.Lang.get("common.buttons.join")
    W.labels.buttons.add = BJI.Managers.Lang.get("common.buttons.add")
    W.labels.buttons.start = BJI.Managers.Lang.get("common.buttons.start")
    W.labels.buttons.resetAll = BJI.Managers.Lang.get("common.buttons.resetAll")
    W.labels.buttons.endSoloRace = BJI.Managers.Lang.get("tournament.buttons.endSoloRace")
    W.labels.buttons.endTournament = BJI.Managers.Lang.get("tournament.buttons.endTournament")
    W.labels.buttons.endTournamentTooltip = BJI.Managers.Lang.get("tournament.buttons.endTournamentTooltip")
    W.labels.buttons.errorMustHaveVehicle = BJI.Managers.Lang.get("tournament.buttons.errorMustHaveVehicle")

    Table(W.manager.ACTIVITIES_TYPES):forEach(function(type)
        W.labels.activities[type] = BJI.Managers.Lang.get("tournament.activities." .. type, type)
    end)
end

---@param staff boolean
---@return boolean
local function canAddOrRemovePlayer(staff)
    if staff then
        if not BJI.Managers.Scenario.isServerScenarioInProgress() then
            return true
        elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_MULTI) then
            local scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_MULTI)
            return scenario.state == scenario.STATES.GRID
        elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.HUNTER) then
            local scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.HUNTER)
            return scenario.state == scenario.STATES.PREPARATION
        elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.DERBY) then
            local scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DERBY)
            return scenario.state == scenario.STATES.PREPARATION
        end
    end
    return false
end

local function updateWidths()
    local staff = BJI.Managers.Perm.isStaff()
    local inFreeroam = BJI.Managers.Scenario.isFreeroam()
    local showPlayerAddOrRemove = canAddOrRemovePlayer(staff)

    W.widths.whitelist = staff and BJI.Utils.UI.GetColumnTextWidth(W.labels.whitelist) + BJI.Utils.UI.GetBtnIconSize() or
        0
    W.widths.clearAndEnd = staff and BJI.Utils.UI.GetInputWidthByContent(W.labels.buttons.endTournament .. "  ") +
        BJI.Utils.UI.GetInputWidthByContent(W.labels.buttons.resetAll .. "  ") or 0

    W.widths.editNumInput = staff and BJI.Utils.UI.GetInputWidthByContent("8888", true) or 0
    W.widths.editInputsCol = staff and
        W.widths.editNumInput + BJI.Utils.UI.GetBtnIconSize() * 2 + BJI.Utils.UI.GetColumnTextWidth("") or 0

    W.widths.chart = {}
    ---@param activity BJTournamentActivity
    ---@param i integer
    Table(W.manager.activities):forEach(function(activity, i)
        if i == #W.manager.activities then
            W.widths.chart[i + 1] = -1
            return
        end
        W.widths.chart[i + 1] = BJI.Utils.UI.GetColumnTextWidth(W.labels.activities[activity.type]) +
            ((inFreeroam and staff) and BJI.Utils.UI.GetBtnIconSize() * (activity.targetTime and 2 or 1) or 0)
        if activity.name then
            local w = BJI.Utils.UI.GetColumnTextWidth(activity.name)
            if w > W.widths.chart[i + 1] then
                W.widths.chart[i + 1] = w
            end
        end
    end)
    -- playernames (+ activities input autocheck)
    ---@param res integer
    ---@param p BJTournamentPlayer
    W.widths.chart[1] = W.manager.players:reduce(function(res, p)
        if W.cache.inputs[p.playerName] and #W.manager.activities > 1 then
            Range(1, #W.manager.activities - 1):forEach(function(i)
                local input = W.cache.inputs[p.playerName][i]
                if input then
                    if W.widths.chart[i + 1] < W.widths.editInputsCol then
                        W.widths.chart[i + 1] = W.widths.editInputsCol
                    end
                elseif staff then
                    local w = BJI.Utils.UI.GetBtnIconSize()
                    if p.scores[i] then
                        w = w + BJI.Utils.UI.GetColumnTextWidth("88") -- max size
                    end
                    if w > W.widths.chart[i + 1] then
                        W.widths.chart[i + 1] = w
                    end
                end
            end)
        end

        local w = BJI.Utils.UI.GetColumnTextWidth(p.playerName)
        if showPlayerAddOrRemove then
            w = w + BJI.Utils.UI.GetBtnIconSize()
        end
        return w > res and w or res
    end, 0)
    if #W.manager.players == 0 then
        W.widths.chart[1] = BJI.Utils.UI.GetColumnTextWidth(W.labels.noParticipant)
    end
    -- total
    W.widths.chart[#W.manager.activities + 2] = BJI.Utils.UI.GetColumnTextWidth(W.labels.total)

    if #W.manager.activities == 0 then
        W.widths.chart[1] = -1
    end

    W.widths.whitelistPlayerCombo = Table(BJI.Managers.Context.Players)
        :map(function(p) return p.playerName end)
        :filter(function(p) return not W.manager.players:any(function(p2) return p == p2.playerName end) end)
        :reduce(function(res, p)
            local w = BJI.Utils.UI.GetComboWidthByContent(p)
            return w > res and w or res
        end, 0)

    if W.cache.showStartActivity then
        W.widths.addActivityLabels = BJI.Utils.UI.GetColumnTextWidth(W.labels.startActivity.title)
        if W.cache.selectedStartActivity then
            local label
            if W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.DERBY then
                label = W.labels.startActivity.arena
            elseif W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE or
                W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE_SOLO then
                label = W.labels.startActivity.track
            end
            if label then
                local w = BJI.Utils.UI.GetColumnTextWidth(label)
                if w > W.widths.addActivityLabels then
                    W.widths.addActivityLabels = w
                end
            end
        end

        W.widths.addActivityCombos = W.cache.startActivityCombo:reduce(function(res, option)
            local w = BJI.Utils.UI.GetComboWidthByContent(option.label)
            return w > res and w or res
        end, 0)
        if W.cache.selectedStartActivity then
            W.cache.startActivitySecCombo:forEach(function(option)
                local w = BJI.Utils.UI.GetComboWidthByContent(option.label)
                if w > W.widths.addActivityCombos then
                    W.widths.addActivityCombos = w
                end
            end)
        end
    end
end

local function isRaceSoloInProgress()
    return W.manager.state and W.manager.activities[#W.manager.activities] and
        W.manager.activities[#W.manager.activities].type == W.manager.ACTIVITIES_TYPES.RACE_SOLO and
        W.manager.activities[#W.manager.activities].targetTime
end

---@param playerName string
---@return integer?
local function getCurrentSoloRaceScore(playerName)
    if isRaceSoloInProgress() then
        ---@param p BJTournamentPlayer
        local sorted = W.manager.players:filter(function(p)
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

local savedActivitiesAmount = 0
local function updateData()
    if not W.getState() then return end

    W.manager = BJI.Managers.Tournament
    local staff = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO)
    local inFreeroam = BJI.Managers.Scenario.isFreeroam()
    local showPlayerAddOrRemove = canAddOrRemovePlayer(staff)

    if W.manager.state then
        W.onClose = nil
    elseif staff then
        W.onClose = onClose
    end

    W.cache.disableInputs = false
    W.cache.staffView = staff
    W.cache.disableToggleBtns = not inFreeroam

    -- player combo
    W.cache.showPlayersCombo = staff and W.manager.whitelist and showPlayerAddOrRemove
    W.cache.playersCombo = Table()
    if W.cache.showPlayersCombo then
        W.cache.playersCombo = Table(BJI.Managers.Context.Players)
            :map(function(p) return p.playerName end)
            :filter(function(p) return not W.manager.players:any(function(p2) return p == p2.playerName end) end)
            :values():sort(function(a, b) return a < b end)
        if not W.cache.selectedPlayer or not W.cache.playersCombo:includes(W.cache.selectedPlayer) then
            W.cache.selectedPlayer = W.cache.playersCombo[1]
        end

        if #W.cache.playersCombo == 0 then
            W.cache.showPlayersCombo = false
        end
    end

    W.cache.showStartActivity = W.manager.state and staff and inFreeroam and
        not isRaceSoloInProgress()
    if W.cache.showStartActivity then
        W.cache.startActivityCombo = Table(W.ACTIVITIES_FILTERS):filter(function(af) return af() end):map(function(_, t)
            return {
                value = t,
                label = W.labels.activities[t],
            }
        end):values():sort(function(a, b) return a.label < b.label end)
        if not W.cache.selectedStartActivity or
            not W.cache.startActivityCombo:any(function(el)
                return el.value == W.cache.selectedStartActivity.value
            end) then
            W.cache.selectedStartActivity = W.cache.startActivityCombo[1]
        end
        if #W.cache.startActivityCombo == 0 then
            W.cache.showStartActivity = false
        end
    end

    if W.cache.showStartActivity then
        W.cache.showStartActivitySec = false
        W.cache.showStartActivityDuration = false
        if W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.DERBY then
            W.cache.showStartActivitySec = true
            W.cache.startActivitySecLabel = function() return W.labels.startActivity.arena end
            W.cache.startActivitySecCombo = Table(BJI.Managers.Context.Scenario.Data.Derby):map(function(arena, i)
                return {
                    value = i,
                    label = arena.name,
                }
            end):values():sort(function(a, b) return a.label < b.label end)
            if not W.cache.selectedStartActivitySec or
                not W.cache.startActivitySecCombo:any(function(el)
                    return el.value == W.cache.selectedStartActivitySec.value
                end) then
                W.cache.selectedStartActivitySec = W.cache.startActivitySecCombo[1]
            end
        elseif W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE_SOLO or
            W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE then
            W.cache.showStartActivitySec = true
            W.cache.startActivitySecLabel = function() return W.labels.startActivity.track end
            W.cache.startActivitySecCombo = Table(BJI.Managers.Context.Scenario.Data.Races):filter(function(r)
                return W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE_SOLO or
                    r.places > 1
            end):map(function(r, i)
                local label = r.name
                if W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE then
                    label = label .. string.var(" ({1})",
                        { BJI.Managers.Lang.get("races.preparation.places"):var({ places = r.places }) })
                end
                return {
                    value = i,
                    label = label,
                }
            end):values():sort(function(a, b)
                if not a.label or not b.label then
                    return a.label ~= nil
                end
                return a.label < b.label
            end)
            if not W.cache.selectedStartActivitySec or
                not W.cache.startActivitySecCombo:any(function(el)
                    return el.value == W.cache.selectedStartActivitySec.value
                end) then
                W.cache.selectedStartActivitySec = nil
            end

            if W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE_SOLO then
                W.cache.showStartActivityDuration = true
                W.cache.startActivityDuration = math.clamp(W.cache.startActivityDuration, 2, 120)
            end
        end
    end

    if savedActivitiesAmount > #W.manager.activities then
        -- on activity removed (or data resetted), clear inputs
        W.cache.inputs = Table()
    else
        -- remove obsolete inputs
        W.cache.inputs = W.cache.inputs:filter(function(_, playerName)
            return W.manager.players:any(function(p) return p.playerName == playerName end)
        end)
    end
    savedActivitiesAmount = #W.manager.activities

    updateWidths()

    W.cache.chartCols = ColumnsBuilder("BJITournamentChart", W.widths.chart --[[, true]])
    ---@param data BJTournamentActivity
    local headerCells = W.manager.activities:reduce(function(res, data, i)
        local isSoloRaceInprogress = i == #W.manager.activities and data.raceID and data.targetTime
        local showJoinSoloRace = W.manager.state and isSoloRaceInprogress and (not W.manager.whitelist or
            W.manager.whitelistPlayers:includes(BJI.Managers.Context.User.playerName))
        res[i + 1] = function()
            local ctxt = BJI.Managers.Tick.getContext()
            local line = LineBuilder()
            if inFreeroam and staff then
                if isSoloRaceInprogress then
                    line:btnIcon({
                        id = "endSoloRace",
                        icon = BJI.Utils.Icon.ICONS.check_circle,
                        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        coloredIcon = true,
                        tooltip = W.labels.buttons.endSoloRace,
                        disabled = W.cache.disableInputs,
                        onClick = function()
                            W.cache.disableInputs = true
                            BJI.Tx.tournament.endSoloRace()
                        end
                    })
                else
                    line:btnIcon({
                        id = "removeActivity-" .. tostring(i),
                        icon = BJI.Utils.Icon.ICONS.cancel,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        coloredIcon = true,
                        tooltip = W.labels.buttons.remove,
                        disabled = W.cache.disableInputs,
                        onClick = function()
                            W.cache.disableInputs = true
                            BJI.Tx.tournament.removeActivity(i)
                        end
                    })
                end
            end
            line:text(W.labels.activities[data.type])
            if inFreeroam and showJoinSoloRace then
                line:btnIcon({
                    id = "joinActivity",
                    icon = BJI.Utils.Icon.ICONS.videogame_asset,
                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = not ctxt.isOwner,
                    tooltip = string.var("{1}{2}", {
                        W.labels.buttons.join,
                        not ctxt.isOwner and " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or "",
                    }),
                    onClick = function()
                        Table(BJI.Managers.Context.Scenario.Data.Races)
                            :find(function(r) return r.id == data.raceID end, function(race)
                                BJI.Windows.RaceSettings.open({
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
                                        :sort(function(a, b) return a.order < b.order end)
                                        :map(function(el) return el.key end),
                                })
                            end)
                    end,
                })
            end
            line:build()

            if data.name then
                LineLabel(data.name)
            end
            if data.targetTime then
                local remainingSecs = math.round((data.targetTime - ctxt.now) / 1000)
                local label
                if remainingSecs > 0 then
                    label = W.labels.activityTimeoutIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingSecs) })
                else
                    label = W.labels.activityAboutToTimeout
                end
                LineLabel(label, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
            end
        end
        return res
    end, Table())
    headerCells[#W.manager.activities + 2] = function() LineLabel(W.labels.total) end
    W.cache.chartCols:addRow({
        cells = headerCells
    }):addSeparator()
    ---@param p BJTournamentPlayer
    W.manager.players:forEach(function(p, iPlayer)
        -- playername (+ remove btn)
        local playerCells = Table({
            function()
                local line = LineBuilder()
                if staff and showPlayerAddOrRemove then
                    line:btnIcon({
                        id = "removePlayer-" .. tostring(iPlayer),
                        icon = BJI.Utils.Icon.ICONS.cancel,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        coloredIcon = true,
                        tooltip = W.labels.buttons.remove,
                        disabled = W.cache.disableInputs,
                        onClick = function()
                            W.cache.disableInputs = true
                            BJI.Tx.tournament.removePlayer(p.playerName)
                        end
                    })
                end
                line:text(p.playerName,
                    p.playerName == BJI.Managers.Context.User.playerName and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil)
                    :build()
            end,
        })
        local total = 0
        -- scores columns (+edit btn/input)
        W.manager.activities:forEach(function(activity, iActivity)
            local score = #W.manager.players
            local label = ""
            if p.scores[iActivity] then
                if p.scores[iActivity].score then
                    score = p.scores[iActivity].score
                    label = score
                elseif p.scores[iActivity].tempValue then
                    -- parse tempValue
                    if iActivity == #W.manager.activities and activity.type == W.manager.ACTIVITIES_TYPES.RACE_SOLO then
                        -- solo race time
                        score = getCurrentSoloRaceScore(p.playerName) or score
                        label = BJI.Utils.UI.RaceDelay(p.scores[iActivity].tempValue)
                    end
                end
            end
            total = total + score
            playerCells[iActivity + 1] = function()
                local showInput = staff and W.cache.inputs[p.playerName] and W.cache.inputs[p.playerName][iActivity]
                local showEdit = not showInput and staff
                if showEdit and iActivity == #W.manager.activities and (isRaceSoloInProgress() or
                        BJI.Managers.Scenario.isServerScenarioInProgress()) then
                    showEdit = false
                end
                local showLabel = not showInput and p.scores[iActivity]
                local line = LineBuilder()
                if showInput then
                    line:btnIcon({
                        id = string.var("cancelEdit-{1}-{2}", { p.playerName, iActivity }),
                        icon = BJI.Utils.Icon.ICONS.cancel,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        coloredIcon = true,
                        tooltip = W.labels.buttons.cancel,
                        disabled = W.cache.disableInputs,
                        onClick = function()
                            W.cache.inputs[p.playerName][iActivity] = nil
                            updateData()
                        end
                    }):btnIcon({
                        id = string.var("confirmEdit-{1}-{2}", { p.playerName, iActivity }),
                        icon = BJI.Utils.Icon.ICONS.check_circle,
                        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        coloredIcon = true,
                        tooltip = W.labels.buttons.confirm,
                        disabled = W.cache.disableInputs,
                        onClick = function()
                            W.cache.disableInputs = true
                            BJI.Tx.tournament.editScore(p.playerName, iActivity, W.cache.inputs[p.playerName][iActivity])
                            W.cache.inputs[p.playerName][iActivity] = nil
                        end
                    }):inputNumeric({
                        id = string.var("edit-{1}-{2}", { p.playerName, iActivity }),
                        type = "int",
                        value = W.cache.inputs[p.playerName][iActivity] or 0,
                        disabled = W.cache.disableInputs,
                        min = 0,
                        max = #W.manager.players,
                        step = 1,
                        width = W.widths.editNumInput,
                        onUpdate = function(v)
                            W.cache.inputs[p.playerName][iActivity] = v
                        end
                    })
                else
                    if showEdit then
                        local add = #tostring(label) == 0
                        line:btnIcon({
                            id = string.var("edit-{1}-{2}", { p.playerName, iActivity }),
                            icon = add and BJI.Utils.Icon.ICONS.add_circle or BJI.Utils.Icon.ICONS.mode_edit,
                            style = add and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.WARNING,
                            coloredIcon = true,
                            tooltip = W.labels.buttons.edit,
                            onClick = function()
                                if not W.cache.inputs[p.playerName] then
                                    W.cache.inputs[p.playerName] = {}
                                end
                                W.cache.inputs[p.playerName][iActivity] = p.scores[iActivity] and
                                    p.scores[iActivity].score or 0
                                updateData()
                            end
                        })
                    end
                    if showLabel then
                        line:text(label)
                    end
                end
                line:build()
            end
        end)
        -- total
        playerCells[#W.manager.activities + 2] = function() LineLabel(tostring(total)) end
        W.cache.chartCols:addRow({
            cells = playerCells
        }):addSeparator()
    end)
    if # W.manager.players == 0 then
        W.cache.chartCols:addRow({
            cells = {
                function() LineLabel(W.labels.noParticipant) end
            }
        }):addSeparator()
    end
end

local listeners = Table()
local function onLoad()
    W.manager = BJI.Managers.Tournament

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end, W.name .. "Labels"))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateWidths, W.name .. "Widths"))

    updateData()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.PLAYER_CONNECT,
        BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateData, W.name .. "Data"))
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
    }, function(_, data)
        if table.includes({
                BJI.Managers.Cache.CACHES.RACES,
                BJI.Managers.Cache.CACHES.HUNTER_DATA,
                BJI.Managers.Cache.CACHES.DERBY_DATA,
            }, data.cache) then
            updateData()
        end
    end, W.name .. "ScenarioData"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param ctxt TickContext
local function header(ctxt)
    ColumnsBuilder("BJITournamentHeader", { -1, -1, W.widths.whitelist }):addRow({
        cells = {
            function() LineLabel(W.labels.title) end,
            W.cache.staffView and function()
                LineBuilder():text(W.labels.state):btnIconToggle({
                    id = "toggleState",
                    state = W.manager.state,
                    coloredIcon = true,
                    disabled = W.cache.disableInputs or W.cache.disableToggleBtns,
                    onClick = function()
                        W.cache.disableInputs = true
                        BJI.Tx.tournament.toggle(not W.manager.state)
                    end
                }):build()
            end or nil,
            W.cache.staffView and function()
                LineBuilder():text(W.labels.whitelist):btnIconToggle({
                    id = "toggleWhitelist",
                    state = W.manager.whitelist,
                    coloredIcon = true,
                    disabled = W.cache.disableInputs or W.cache.disableToggleBtns,
                    onClick = function()
                        W.cache.disableInputs = true
                        BJI.Tx.tournament.toggleWhitelist(not W.manager.whitelist)
                    end
                }):build()
            end or nil,
        }
    }):build()
end

---@param ctxt TickContext
local function body(ctxt)
    EmptyLine()
    if W.cache.chartCols then
        W.cache.chartCols:build()
    end

    if W.cache.showPlayersCombo then
        LineBuilder():btnIcon({
            id = "addWhitelistPlayer",
            icon = BJI.Utils.Icon.ICONS.add,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            tooltip = W.labels.buttons.add,
            disabled = W.cache.disableInputs or not W.cache.selectedPlayer or
                #W.cache.selectedPlayer == 0,
            onClick = function()
                W.cache.disableInputs = true
                BJI.Tx.tournament.toggleWhitelistPlayer(W.cache.selectedPlayer, true)
            end
        }):inputCombo({
            id = "whitelistPlayersCombo",
            items = W.cache.playersCombo:filter(function(p)
                return not W.cache.disableInputs or p == W.cache.selectedPlayer
            end),
            value = W.cache.selectedPlayer,
            width = W.widths.whitelistPlayerCombo,
            onChange = function(v)
                W.cache.selectedPlayer = tostring(v)
            end
        }):build()
    end

    for _ = 1, 3 - #W.manager.players do
        EmptyLine()
    end

    if W.cache.showStartActivity then
        if W.cache.showPlayersCombo then
            Separator()
        end
        local cols = ColumnsBuilder("BJITournamentStartActivity",
            { W.widths.addActivityLabels, W.widths.addActivityCombos, -1 }):addRow({
            cells = {
                function() LineLabel(W.labels.startActivity.title) end,
                function()
                    LineBuilder():inputCombo({
                        id = "startActivityCombo",
                        items = W.cache.startActivityCombo:filter(function(p)
                            return not W.cache.disableInputs or p == W.cache.selectedStartActivity
                        end),
                        value = W.cache.selectedStartActivity,
                        getLabelFn = function(el) return el.label end,
                        onChange = function(v)
                            W.cache.selectedStartActivity = v
                            updateData()
                        end
                    }):build()
                end,
            }
        })
        if W.cache.showStartActivitySec then
            cols:addRow({
                cells = {
                    function() LineLabel(W.cache.startActivitySecLabel()) end,
                    function()
                        LineBuilder():inputCombo({
                            id = "startActivitySecCombo",
                            items = W.cache.startActivitySecCombo:filter(function(p)
                                return not W.cache.disableInputs or p == W.cache.selectedStartActivitySec
                            end),
                            value = W.cache.selectedStartActivitySec,
                            getLabelFn = function(el) return el.label end,
                            onChange = function(v)
                                W.cache.selectedStartActivitySec = v
                            end
                        }):build()
                    end,
                    W.cache.showStartActivityDuration and function()
                        LineBuilder():text(W.labels.startActivity.duration):slider({
                            id = "startActivityDuration",
                            type = "int",
                            value = W.cache.startActivityDuration,
                            min = 2,
                            max = 120,
                            renderFormat = BJI.Utils.UI.PrettyDelay(W.cache.startActivityDuration * 60),
                            onUpdate = function(v)
                                W.cache.startActivityDuration = v
                            end
                        }):build()
                    end or nil,
                }
            })
        end
        cols:build()
        LineBuilder():btn({
            id = "startActivity",
            label = W.labels.buttons.start,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs or not W.cache.selectedStartActivity,
            onClick = function()
                if W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE_SOLO then
                    W.cache.disableInputs = true
                    BJI.Tx.tournament.addSoloRace(W.cache.selectedStartActivitySec.value,
                        W.cache.startActivityDuration)
                elseif W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.RACE then
                    Table(BJI.Managers.Context.Scenario.Data.Races):find(function(r)
                        return r.id == W.cache.selectedStartActivitySec.value and r.places > 1
                    end, function(race)
                        BJI.Windows.RaceSettings.open({
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
                elseif W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.SPEED then
                    BJI.Tx.scenario.SpeedStart(false)
                elseif W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.HUNTER then
                    BJI.Windows.HunterSettings.open()
                elseif W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.DERBY then
                    BJI.Windows.DerbySettings.open(W.cache.selectedStartActivitySec.value)
                elseif W.cache.selectedStartActivity.value == W.manager.ACTIVITIES_TYPES.TAG then
                    -- TODO start tag
                end
            end,
        }):build()
    end
end

local function footer(ctxt)
    ColumnsBuilder("BJITournamentFooter", { -1, W.widths.clearAndEnd }):addRow({
        cells = { nil,
            function()
                LineBuilder():btn({
                    id = "resetTournament",
                    label = W.labels.buttons.resetAll,
                    style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                    disabled = W.cache.disableInputs or (#W.manager.players == 0 and #W.manager.activities == 0),
                    onClick = function()
                        W.cache.disableInputs = true
                        BJI.Tx.tournament.clear()
                    end
                }):btn({
                    id = "endTournament",
                    label = W.labels.buttons.endTournament,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    tooltip = W.labels.buttons.endTournamentTooltip,
                    disabled = W.cache.disableInputs or not W.manager.state or #W.manager.activities == 0,
                    onClick = function()
                        W.cache.disableInputs = true
                        BJI.Tx.tournament.endTournament()
                    end
                }):build()
            end
        }
    }):build()
end

local function open()
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
        not BJI.Managers.Tournament.state then
        W.manualShow = true
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.open = open
W.getState = function()
    return W.manualShow or BJI.Managers.Tournament.state
end

W.updateData = updateData

return W
