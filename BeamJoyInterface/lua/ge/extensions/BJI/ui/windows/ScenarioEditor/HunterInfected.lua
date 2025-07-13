local W = {
    name = "ScenarioEditorHunter",

    TABS = Table({
        {
            subWindow = require("ge/extensions/BJI/ui/windows/ScenarioEditor/HunterInfected/Hunter"),
            titleKey = "hunter",
        },
        {
            subWindow = require("ge/extensions/BJI/ui/windows/ScenarioEditor/HunterInfected/Infected"),
            titleKey = "infected",
        }
    }),
    tab = 1,

    labels = {
        title = "",
        tabs = {},
        enabled = "",
        buttons = {
            refreshMarkers = "",
            toggleModeVisibility = "",
            close = "",
            save = "",
        },
        errors = {
            missingPoints = "",
            errorMustHaveVehicle = "",
            errorInvalidData = "",
        },
        hunter = {
            title = "",
            fields = {
                hunters = "",
                hunted = "",
                waypoints = "",
                radius = "",
            },
            buttons = {
                showHunterStartPosition = "",
                setHunterStartPositionHere = "",
                deleteHunterStartPosition = "",
                addHunterStartPositionHere = "",
                showHuntedStartPosition = "",
                setHuntedStartPositionHere = "",
                deleteHuntedStartPosition = "",
                addHuntedStartPositionHere = "",
                addWaypointHere = "",
                showWaypoint = "",
                setWaypointHere = "",
                deleteWaypoint = "",
            },
            tags = {
                waypointName = "",
                hunterName = "",
                huntedName = "",
            },
        },
        infected = {
            title = "",
            fields = {
                survivors = "",
                infected = "",
            },
            buttons = {
                showSurvivorStartPosition = "",
                setSurvivorStartPositionHere = "",
                deleteSurvivorStartPosition = "",
                addSurvivorStartPositionHere = "",
                showInfectedStartPosition = "",
                setInfectedStartPositionHere = "",
                deleteInfectedStartPosition = "",
                addInfectedStartPositionHere = "",
            },
            tags = {
                survivorName = "",
                infectedName = "",
            },
        },
    },

    data = {
        enabledHunter = false,
        enabledInfected = false,
        waypoints = Table(),
        majorPositions = Table(),
        minorPositions = Table(),

        canEnableHunter = false,
        cannotEnableHunterTooltip = "",
        canEnableInfected = false,
        cannotEnableInfectedTooltip = "",
    },

    tabOpenInit = false,
    disableButtons = false,
    changed = false,
    valid = false,
}

local function onClose()
    BJI_WaypointEdit.reset()
    W.changed = false
    W.valid = true
end

local function updateLabels()
    W.labels.title = BJI_Lang.get("hunterInfectedEditor.title")
    W.labels.enabled = BJI_Lang.get("hunterInfectedEditor.enabled")
    W.labels.buttons.refreshMarkers = BJI_Lang.get("hunterInfectedEditor.buttons.refreshMarkers")
    W.labels.buttons.toggleModeVisibility = BJI_Lang.get("hunterInfectedEditor.buttons.toggleModeVisibility")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI_Lang.get("common.buttons.save")
    W.labels.errors.missingPoints = BJI_Lang.get("hunterInfectedEditor.errors.missingPoints")
    W.labels.errors.errorMustHaveVehicle = BJI_Lang.get("errors.mustHaveVehicle")
    W.labels.errors.errorInvalidData = BJI_Lang.get("errors.someDataAreInvalid")

    -- hunter
    W.labels.hunter.title = BJI_Lang.get("hunterInfectedEditor.hunter.title")
    W.labels.hunter.fields.hunters = BJI_Lang.get("hunterInfectedEditor.hunter.fields.hunters")
    W.labels.hunter.fields.hunted = BJI_Lang.get("hunterInfectedEditor.hunter.fields.hunted")
    W.labels.hunter.fields.waypoints = BJI_Lang.get("hunterInfectedEditor.hunter.fields.waypoints")
    W.labels.hunter.fields.radius = BJI_Lang.get("hunterInfectedEditor.hunter.fields.radius")
    W.labels.hunter.buttons.showHunterStartPosition = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.showHunterStartPosition")
    W.labels.hunter.buttons.setHunterStartPositionHere = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.setHunterStartPositionHere")
    W.labels.hunter.buttons.deleteHunterStartPosition = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.deleteHunterStartPosition")
    W.labels.hunter.buttons.addHunterStartPositionHere = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.addHunterStartPositionHere")
    W.labels.hunter.buttons.showHuntedStartPosition = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.showHuntedStartPosition")
    W.labels.hunter.buttons.setHuntedStartPositionHere = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.setHuntedStartPositionHere")
    W.labels.hunter.buttons.deleteHuntedStartPosition = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.deleteHuntedStartPosition")
    W.labels.hunter.buttons.addHuntedStartPositionHere = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.addHuntedStartPositionHere")
    W.labels.hunter.buttons.addWaypointHere = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.addWaypointHere")
    W.labels.hunter.buttons.showWaypoint = BJI_Lang.get("hunterInfectedEditor.hunter.buttons.showWaypoint")
    W.labels.hunter.buttons.setWaypointHere = BJI_Lang.get(
        "hunterInfectedEditor.hunter.buttons.setWaypointHere")
    W.labels.hunter.buttons.deleteWaypoint = BJI_Lang.get("hunterInfectedEditor.hunter.buttons.deleteWaypoint")
    W.labels.hunter.tags.waypointName = BJI_Lang.get("hunterInfectedEditor.hunter.tags.waypointName")
    W.labels.hunter.tags.hunterName = BJI_Lang.get("hunterInfectedEditor.hunter.tags.hunterName")
    W.labels.hunter.tags.huntedName = BJI_Lang.get("hunterInfectedEditor.hunter.tags.huntedName")

    -- infected
    W.labels.infected.title = BJI_Lang.get("hunterInfectedEditor.infected.title")
    W.labels.infected.fields.survivors = BJI_Lang.get("hunterInfectedEditor.infected.fields.survivors")
    W.labels.infected.fields.infected = BJI_Lang.get("hunterInfectedEditor.infected.fields.infected")
    W.labels.infected.buttons.showSurvivorStartPosition = BJI_Lang.get(
        "hunterInfectedEditor.infected.buttons.showSurvivorStartPosition")
    W.labels.infected.buttons.setSurvivorStartPositionHere = BJI_Lang.get(
        "hunterInfectedEditor.infected.buttons.setSurvivorStartPositionHere")
    W.labels.infected.buttons.deleteSurvivorStartPosition = BJI_Lang.get(
        "hunterInfectedEditor.infected.buttons.deleteSurvivorStartPosition")
    W.labels.infected.buttons.addSurvivorStartPositionHere = BJI_Lang.get(
        "hunterInfectedEditor.infected.buttons.addSurvivorStartPositionHere")
    W.labels.infected.buttons.showInfectedStartPosition = BJI_Lang.get(
        "hunterInfectedEditor.infected.buttons.showInfectedStartPosition")
    W.labels.infected.buttons.setInfectedStartPositionHere = BJI_Lang.get(
        "hunterInfectedEditor.infected.buttons.setInfectedStartPositionHere")
    W.labels.infected.buttons.deleteInfectedStartPosition = BJI_Lang.get(
        "hunterInfectedEditor.infected.buttons.deleteInfectedStartPosition")
    W.labels.infected.buttons.addInfectedStartPositionHere = BJI_Lang.get(
        "hunterInfectedEditor.infected.buttons.addInfectedStartPositionHere")
    W.labels.infected.tags.survivorName = BJI_Lang.get("hunterInfectedEditor.infected.tags.survivorName")
    W.labels.infected.tags.infectedName = BJI_Lang.get("hunterInfectedEditor.infected.tags.infectedName")
end

local function updateEnabled()
    W.data.canEnableHunter = true
    W.data.cannotEnableHunterTooltip = ""
    if #W.data.waypoints < 2 or
        #W.data.majorPositions < 5 or
        #W.data.minorPositions < 2 then
        W.data.enabledHunter = false
        W.data.canEnableHunter = false
        W.data.cannotEnableHunterTooltip = W.labels.errors.missingPoints:var({
            amount = math.max(5 - #W.data.majorPositions, 0) +
                math.max(2 - #W.data.minorPositions, 0) +
                math.max(2 - #W.data.waypoints, 0)
        })
    end

    W.data.canEnableInfected = true
    W.data.cannotEnableInfectedTooltip = ""
    if #W.data.majorPositions < 5 or
        #W.data.minorPositions < 2 then
        W.data.enabledInfected = false
        W.data.canEnableInfected = false
        W.data.cannotEnableInfectedTooltip = W.labels.errors.missingPoints:var({
            amount = math.max(5 - #W.data.majorPositions, 0) +
                math.max(2 - #W.data.minorPositions, 0)
        })
    end
end

local function validateData()
    W.valid = true
    if W.data.enabledHunter then
        if #W.data.waypoints < 2 or
            #W.data.majorPositions < 5 or
            #W.data.minorPositions < 2 then
            W.valid = false
        end
    end
    if W.data.enabledInfected then
        if #W.data.majorPositions < 5 or
            #W.data.minorPositions < 2 then
            W.valid = false
        end
    end
end

local function reloadMarkers()
    W.TABS[W.tab].subWindow.reloadMarkers(W)
end

local function updateCache()
    local data = BJI_Scenario.Data.HunterInfected
    W.data.enabledHunter = data.enabledHunter
    W.data.enabledInfected = data.enabledInfected
    W.data.waypoints = Table(data.waypoints):map(function(target)
        return math.tryParsePosRot(table.clone({
            pos = target.pos,
            radius = target.radius,
        }))
    end)
    W.data.majorPositions = Table(data.majorPositions):map(function(majorPos)
        return math.tryParsePosRot(table.clone(majorPos))
    end)
    W.data.minorPositions = Table(data.minorPositions):map(function(minorPos)
        return math.tryParsePosRot(table.clone(minorPos))
    end)

    updateEnabled()
    validateData()
    reloadMarkers()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI_Cache.CACHES.HUNTER_INFECTED_DATA then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function save()
    W.disableButtons = true
    BJI_Tx_scenario.HunterInfectedSave({
        enabledHunter = W.data.enabledHunter,
        enabledInfected = W.data.enabledInfected,
        waypoints = W.data.waypoints:map(function(target)
            return {
                pos = target.pos,
                radius = target.radius,
            }
        end),
        majorPositions = W.data.majorPositions:map(function(hunter)
            return math.roundPositionRotation(hunter)
        end),
        minorPositions = W.data.minorPositions:map(function(hunted)
            return math.roundPositionRotation(hunted)
        end),
    }, function(result)
        if result then
            W.changed = false
        else
            BJI_Toast.error(BJI_Lang.get("hunterInfectedEditor.errors.saveErrorToast"))
        end
        W.disableButtons = false
    end)
end

---@param ctxt TickContext
local function header(ctxt)
    Text(W.labels.title)
    SameLine()
    if IconButton("reloadMarkers", BJI.Utils.Icon.ICONS.sync) then
        reloadMarkers()
    end
    TooltipText(W.labels.buttons.refreshMarkers)

    if BeginTabBar("BJIHunterInfectedEditorTabs") then
        W.TABS:forEach(function(t, i)
            if BeginTabItem(W.labels[t.titleKey].title) then
                if W.tabOpenInit then
                    W.tab = i
                    reloadMarkers()
                end
                EndTabItem()
            end
        end)
        if not W.tabOpenInit then -- on window open tab selection system
            W.TABS:filter(function(_, i) return i ~= W.tab end):forEach(function(t)
                SetTabItemClosed(W.labels[t.titleKey].title)
            end)
            W.tabOpenInit = true
        end
        EndTabBar()
    end
end

---@param ctxt TickContext
local function body(ctxt)
    W.TABS[W.tab].subWindow.body(W, ctxt)
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeEdit", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI_Win_ScenarioEditor.onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.changed then
        SameLine()
        if IconButton("saveEdit", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.disableButtons or not W.valid }) then
            save()
        end
        TooltipText(W.labels.buttons.save ..
            (not W.valid and " (" .. W.labels.errors.errorMustHaveVehicle .. ")" or ""))
    end
end

---@param tabIndex integer
local function open(tabIndex)
    W.tab = tabIndex or W.tab or 1
    W.tabOpenInit = false
    BJI_Win_ScenarioEditor.view = W
end

-- children scope methods
W.updateEnabled = updateEnabled
W.validateData = validateData

-- public methods
W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.open = open

return W
