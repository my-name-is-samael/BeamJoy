---@class BJIRaceWaypoint
---@field name string
---@field pos vec3
---@field rot quat
---@field radius number
---@field zOffset? number
---@field stand? boolean
---@field parents string[]

local function resetData()
    return {
        changed         = false,
        ---@type integer?
        id              = nil,
        author          = "",
        name            = "",
        ---@type BJIPositionRotation?
        previewPosition = nil,
        ---@type tablelib<integer, BJIRaceWaypoint[]>
        steps           = Table(),
        ---@type tablelib<integer, BJIPositionRotation>
        startPositions  = Table(),
        loopable        = false,
        enabled         = true,
        hasRecord       = false,
        keepRecord      = false,
    }
end

local W = {
    name               = "ScenarioEditorRace",

    raceData           = resetData(),
    tryLaps            = 1,
    labels             = {
        missing = "",
        tools = {
            title = "",
            rotation = "",
            reverse = "",
        },
        editTitle = "",
        name = "",
        nameTooltip = "",
        author = "",
        enabled = "",
        previewPosition = "",
        previewPositionTooltip = "",
        loopable = "",
        laps = "",
        lapsTooltip = "",
        startPositions = "",
        startPosition = "",
        startPositionTooltip = "",
        stepFinishWarning = "",
        steps = "",
        step = "",
        waypoint = "",
        branch = "",
        wpName = "",
        radius = "",
        size = "",
        bottomHeight = "",
        parent = "",
        parentStartTooltip = "",
        noChild = "",
        buttons = {
            refreshMarkers = "",
            rotateLeft = "",
            rotateRight = "",
            rotate180 = "",
            reverseAllSteps = "",
            toggleRaceVisibility = "",
            showPreviewPosition = "",
            setPreviewPositionHere = "",
            toggleLoopable = "",
            addStartPositionHere = "",
            moveUp = "",
            moveDown = "",
            showStartPosition = "",
            setStartPositionHere = "",
            deleteStartPosition = "",
            addRaceStepHere = "",
            deleteStep = "",
            addBranchHere = "",
            showWaypoint = "",
            setWaypointHere = "",
            toggleStandWaypoint = "",
            deleteWaypoint = "",
            removeParent = "",
            addParent = "",
            tryRace = "",
            errorMustHaveVehicle = "",
            errorInvalidData = "",
            leave = "",
            save = "",
        }
    },
    widths             = {
        startPositionsLabelsWidth = 0,
        wpLabelsWidth = 0,
    },
    cache              = {
        validTry = false,
        validSave = false,
        validSteps = false,
        invalid = {
            name = false,
            previewPosition = false,
            startPositionsCount = false,
            stepsCount = false,
            steps = {},
        },
        disableInputs = false,
    },
    ---@type BJIScenarioRaceSolo?
    scenarioSolo       = nil,

    nextTickScrollDown = false, -- flag to scroll down on next tick
}

local function onClose()
    BJI.Managers.WaypointEdit.reset() -- remove edit markers
    W.raceData = resetData()          -- reset data
end

local function updateLabels()
    W.labels.missing = BJI.Managers.Lang.get("errors.missing")

    W.labels.tools.title = BJI.Managers.Lang.get("races.tools.title")
    W.labels.tools.rotation = BJI.Managers.Lang.get("races.tools.rotation")
    W.labels.tools.reverse = BJI.Managers.Lang.get("races.tools.reverse")

    W.labels.editTitle = BJI.Managers.Lang.get("races.edit.title")
    W.labels.name = BJI.Managers.Lang.get("races.edit.name")
    W.labels.nameTooltip = BJI.Managers.Lang.get("races.edit.nameTooltip")
    W.labels.author = BJI.Managers.Lang.get("races.edit.author") .. " :"
    W.labels.enabled = BJI.Managers.Lang.get("races.edit.enabled")
    W.labels.previewPosition = BJI.Managers.Lang.get("races.edit.previewPosition")
    W.labels.previewPositionTooltip = BJI.Managers.Lang.get("races.edit.previewPositionTooltip")
    W.labels.loopable = BJI.Managers.Lang.get("races.edit.loopable")
    W.labels.laps = BJI.Managers.Lang.get("races.edit.laps")
    W.labels.lapsTooltip = BJI.Managers.Lang.get("races.edit.lapsTooltip")
    W.labels.startPositions = string.var("{1}:", { BJI.Managers.Lang.get("races.edit.startPositions") })
    W.labels.startPosition = BJI.Managers.Lang.get("races.edit.startPositionLabel")
    W.labels.startPositionTooltip = BJI.Managers.Lang.get("races.edit.startPositionsNameTooltip")
    W.labels.stepFinishWarning = BJI.Managers.Lang.get("races.edit.stepsFinishWarning")
    W.labels.steps = BJI.Managers.Lang.get("races.edit.steps") .. " :"
    W.labels.step = BJI.Managers.Lang.get("races.edit.step") .. " "
    W.labels.waypoint = BJI.Managers.Lang.get("races.edit.waypoint")
    W.labels.branch = BJI.Managers.Lang.get("races.edit.branch") .. " "
    W.labels.wpName = BJI.Managers.Lang.get("races.edit.wpName")
    W.labels.radius = BJI.Managers.Lang.get("races.edit.radius")
    W.labels.size = BJI.Managers.Lang.get("races.edit.size")
    W.labels.bottomHeight = BJI.Managers.Lang.get("races.edit.bottomHeight")
    W.labels.parent = BJI.Managers.Lang.get("races.edit.parent")
    W.labels.parentStartTooltip = BJI.Managers.Lang.get("races.edit.parentStartTooltip")
    W.labels.noChild = BJI.Managers.Lang.get("races.edit.errors.noChild")

    W.labels.buttons.refreshMarkers = BJI.Managers.Lang.get("races.edit.buttons.refreshMarkers")
    W.labels.buttons.rotateLeft = BJI.Managers.Lang.get("races.edit.buttons.rotateLeft")
    W.labels.buttons.rotateRight = BJI.Managers.Lang.get("races.edit.buttons.rotateRight")
    W.labels.buttons.rotate180 = BJI.Managers.Lang.get("races.edit.buttons.rotate180")
    W.labels.buttons.reverseAllSteps = BJI.Managers.Lang.get("races.edit.buttons.reverseAllSteps")
    W.labels.buttons.toggleRaceVisibility = BJI.Managers.Lang.get("races.edit.buttons.toggleRaceVisibility")
    W.labels.buttons.showPreviewPosition = BJI.Managers.Lang.get("races.edit.buttons.showPreviewPosition")
    W.labels.buttons.setPreviewPositionHere = BJI.Managers.Lang.get("races.edit.buttons.setPreviewPositionHere")
    W.labels.buttons.toggleLoopable = BJI.Managers.Lang.get("races.edit.buttons.toggleLoopable")
    W.labels.buttons.addStartPositionHere = BJI.Managers.Lang.get("races.edit.buttons.addStartPositionHere")
    W.labels.buttons.moveUp = BJI.Managers.Lang.get("common.buttons.moveUp")
    W.labels.buttons.moveDown = BJI.Managers.Lang.get("common.buttons.moveDown")
    W.labels.buttons.showStartPosition = BJI.Managers.Lang.get("races.edit.buttons.showStartPosition")
    W.labels.buttons.setStartPositionHere = BJI.Managers.Lang.get("races.edit.buttons.setStartPositionHere")
    W.labels.buttons.deleteStartPosition = BJI.Managers.Lang.get("races.edit.buttons.deleteStartPosition")
    W.labels.buttons.addRaceStepHere = BJI.Managers.Lang.get("races.edit.buttons.addRaceStepHere")
    W.labels.buttons.deleteStep = BJI.Managers.Lang.get("races.edit.buttons.deleteStep")
    W.labels.buttons.addBranchHere = BJI.Managers.Lang.get("races.edit.buttons.addBranchHere")
    W.labels.buttons.showWaypoint = BJI.Managers.Lang.get("races.edit.buttons.showWaypoint")
    W.labels.buttons.setWaypointHere = BJI.Managers.Lang.get("races.edit.buttons.setWaypointHere")
    W.labels.buttons.toggleStandWaypoint = BJI.Managers.Lang.get("races.edit.buttons.toggleStandWaypoint")
    W.labels.buttons.deleteWaypoint = BJI.Managers.Lang.get("races.edit.buttons.deleteWaypoint")
    W.labels.buttons.removeParent = BJI.Managers.Lang.get("races.edit.buttons.removeParent")
    W.labels.buttons.addParent = BJI.Managers.Lang.get("races.edit.buttons.addParent")
    W.labels.buttons.tryRace = BJI.Managers.Lang.get("races.edit.buttons.tryRace")
    W.labels.buttons.errorMustHaveVehicle = BJI.Managers.Lang.get("races.edit.buttons.errorMustHaveVehicle")
    W.labels.buttons.errorInvalidData = BJI.Managers.Lang.get("races.edit.buttons.errorInvalidData")
    W.labels.buttons.leave = BJI.Managers.Lang.get("common.buttons.leave")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
end

local function updateWidths()
    W.widths.startPositionsLabelsWidth = W.raceData.startPositions
        :reduce(function(acc, _, i)
            local w = BJI.Utils.Common.GetColumnTextWidth(W.labels.startPosition:var({ index = i }))
            return w > acc and w or acc
        end, 0)

    W.widths.wpLabelsWidth = Table({ W.labels.wpName, W.labels.radius, W.labels.size,
        W.labels.bottomHeight, W.labels.parent }):reduce(function(acc, l)
        local w = BJI.Utils.Common.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end, W.name))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, updateWidths, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

--- find parent in steps before currStep
---@param wpName string
---@param currStep integer
---@return BJIRaceWaypoint?
local function findParent(wpName, currStep)
    if currStep == 1 then return nil end -- no parent if first step
    return Range(currStep - 1, 1)
        :map(function(i) return W.raceData.steps[i] end)
        :find(function(step)
            return step:find(function(wp)
                return wp.name:trim() == wpName:trim()
            end)
        end)
end

--- search for existing wp child in steps after currStep
---@param wpName string
---@param currStep integer
---@return boolean
local function childExists(wpName, currStep)
    if currStep >= #W.raceData.steps then return false end -- no child if last step
    return Range(currStep + 1, #W.raceData.steps)
        :map(function(i) return W.raceData.steps[i] end)
        :any(function(step)
            return step:any(function(wp)
                return wp.parents:any(function(parent) return parent:trim() == wpName:trim() end)
            end)
        end)
end

local function validateRace()
    W.cache.validSave = true
    W.cache.validTry = true

    W.cache.invalid.name = #W.raceData.name == 0 or Table(BJI.Managers.Context.Scenario.Data.Races)
        :any(function(r) return r.id ~= W.raceData.id and r.name == W.raceData.name:trim() end)
    W.cache.invalid.previewPosition = not W.raceData.previewPosition
    W.cache.invalid.startPositionsCount = #W.raceData.startPositions == 0
    W.cache.invalid.stepsCount = #W.raceData.steps == 0
    W.cache.invalid.steps = {}
    local previousWpNames = Table()
    W.raceData.steps:forEach(function(wps, iStep)
        W.cache.invalid.steps[iStep] = {}
        local stepWpNames = Table()
        wps:forEach(function(wp, iWp)
            W.cache.invalid.steps[iStep][iWp] = {}
            if #wp.name == 0 or wp.name:trim() == "start" then
                W.cache.invalid.steps[iStep][iWp].name = true
                W.cache.validSave = false
                W.cache.validTry = false
            else
                stepWpNames:insert(wp.name)
            end

            if iStep < #W.raceData.steps and not childExists(wp.name, iStep) then
                W.cache.invalid.steps[iStep][iWp].missingChild = true
                W.cache.validSave = false
                W.cache.validTry = false
            end

            W.cache.invalid.steps[iStep][iWp].parents = {}
            if iStep > 1 then -- validate parents
                wp.parents:forEach(function(parentName, iParent)
                    if parentName:trim() ~= "start" and
                        not findParent(parentName, iStep) then
                        W.cache.invalid.steps[iStep][iWp].parents[iParent] = true
                        W.cache.validSave = false
                        W.cache.validTry = false
                    end
                end)
            end
        end)
        previousWpNames:addAll(stepWpNames)
    end)

    W.cache.validSave = W.cache.validSave and not W.cache.invalid.name and
        not W.cache.invalid.previewPosition and not W.cache.invalid.startPositionsCount and
        not W.cache.invalid.stepsCount

    W.cache.validTry = W.cache.validTry and not W.cache.invalid.startPositionsCount and
        not W.cache.invalid.stepsCount
end

local function updateMarkers()
    BJI.Managers.WaypointEdit.reset()

    local startPositionColor = BJI.Utils.ShapeDrawer.Color(1, 1, 0, .5)
    local cpColor = BJI.Utils.ShapeDrawer.Color(1, .5, .5, .5)
    local finishColor = BJI.Utils.ShapeDrawer.Color(.66, .66, 1, .5)
    local standColor = BJI.Utils.ShapeDrawer.Color(1, .66, 0, .5)

    BJI.Managers.WaypointEdit.setWaypointsWithSegments(W.raceData.startPositions:map(function(p, i)
        return { -- START POSITIONS
            name = BJI.Managers.Lang.get("races.edit.startPositionLabel"):var({ index = i }),
            pos = p.pos,
            rot = p.rot,
            radius = 2,
            color = startPositionColor,
            textColor = startPositionColor,
            textBg = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5),
            type = BJI.Managers.WaypointEdit.TYPES.ARROW,
        }
    end):addAll(W.raceData.steps:map(function(step, iStep)
        return step:map(function(wp)
            return { -- RACE CHECKPOINT / FINISH / STAND
                name = wp.name,
                pos = wp.pos,
                top = wp.stand and wp.radius * 2 or nil,
                bottom = wp.stand and -(wp.zOffset or 1) or nil,
                rot = wp.rot,
                zOffset = wp.zOffset or 1,
                radius = wp.radius,
                color = wp.stand and standColor or
                    (iStep == #W.raceData.steps and finishColor or cpColor),
                parents = table.clone(wp.parents),
                finish = iStep == #W.raceData.steps,
                type = wp.stand and BJI.Managers.WaypointEdit.TYPES.CYLINDER or
                    BJI.Managers.WaypointEdit.TYPES.RACE_GATE,
            }
        end)
    end):reduce(function(res, step)
        step:forEach(function(wp)
            res:insert(wp)
        end)
        return res
    end, Table())), W.raceData.loopable)
end

local function getNewWPName()
    return "wp" .. tostring(W.raceData.steps:reduce(function(max, step)
        return step:reduce(function(max2, wp)
            if wp.name:find("^wp%d+$") then
                local num = tonumber(wp.name:sub(3))
                return num > max2 and num or max2
            end
            return max2
        end, max)
    end, 0) + 1)
end

local function getNewWaypointRadius(iStep, iWp)
    local previousStep = W.raceData.steps[iStep - 1]
    if previousStep then
        if previousStep[iWp] then
            return previousStep[iWp].radius
        else
            return previousStep[1].radius
        end
    end
    return 1
end

---@param callback fun(raceID?: integer)
local function saveRace(callback)
    local function _vec3export(v)
        return {
            x = tonumber(v.x),
            y = tonumber(v.y),
            z = tonumber(v.z),
        }
    end

    local function _quatexport(q)
        return {
            x = tonumber(q.x),
            y = tonumber(q.y),
            z = tonumber(q.z),
            w = tonumber(q.w),
        }
    end

    local function _finalSave()
        local race = {
            id = W.raceData.id,
            author = W.raceData.author,
            name = W.raceData.name:trim(),
            enabled = W.raceData.enabled,
            previewPosition = math.roundPositionRotation({
                pos = _vec3export(W.raceData.previewPosition.pos),
                rot = _quatexport(W.raceData.previewPosition.rot)
            }),
            keepRecord = W.raceData.keepRecord,
        }

        if not W.raceData.keepRecord then
            race.loopable = W.raceData.loopable

            -- startPositions
            race.startPositions = W.raceData.startPositions:map(function(sp)
                return math.roundPositionRotation({
                    pos = _vec3export(sp.pos),
                    rot = _quatexport(sp.rot),
                })
            end)
            -- steps
            race.steps = W.raceData.steps:reduce(function(acc, step)
                acc:insert(step:map(function(wp)
                    return math.roundPositionRotation({
                        name = wp.name:trim(),
                        parents = wp.parents
                            :map(function(p) return p:trim() end),
                        pos = _vec3export(wp.pos),
                        zOffset = wp.zOffset,
                        rot = _quatexport(wp.rot),
                        radius = wp.radius,
                        stand = wp.stand,
                    })
                end))
                return acc
            end, Table())
        end

        W.cache.disableInputs = true
        BJI.Tx.scenario.RaceSave(race, function(result)
            if result then
                W.raceData.id = result
                W.raceData.changed = false
                W.raceData.hasRecord = W.raceData.hasRecord and W.raceData.keepRecord
                W.raceData.keepRecord = true
            else
                BJI.Managers.Toast.error(BJI.Managers.Lang.get("races.edit.saveErrorToast"))
            end
            W.cache.disableInputs = false
            if type(callback) == "function" then callback(result or nil) end
        end)
    end

    if W.raceData.hasRecord and not W.raceData.keepRecord then
        BJI.Managers.Popup.createModal(BJI.Managers.Lang.get("races.edit.hasRecordConfirm"), {
            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"), _finalSave),
        })
    else
        _finalSave()
    end
end

local function tryRace(ctxt)
    if not ctxt.isOwner or not W.cache.validTry then
        -- invalid default vehicle
        return
    end
    local saved, laps = table.clone(W.raceData), W.tryLaps

    local function launch()
        BJI.Managers.RaceWaypoint.resetAll()
        W.scenarioSolo.initRace(
            ctxt,
            {
                laps = W.raceData.loopable and W.tryLaps or nil,
                respawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key,
            },
            {
                name = W.raceData.name,
                startPositions = W.raceData.startPositions:map(function(sp)
                    return {
                        pos = { x = sp.pos.x, y = sp.pos.y, z = sp.pos.z },
                        rot = { x = sp.rot.x, y = sp.rot.y, z = sp.rot.z, w = sp.rot.w },
                    }
                end),
                steps = W.raceData.steps:map(function(wps)
                    return wps:map(function(wp)
                        return {
                            name = wp.name:trim(),
                            pos = { x = wp.pos.x, y = wp.pos.y, z = wp.pos.z },
                            zOffset = wp.zOffset,
                            rot = { x = wp.rot.x, y = wp.rot.y, z = wp.rot.z, w = wp.rot.w },
                            radius = wp.radius,
                            parents = wp.parents:map(function(p) return p:trim() end),
                            stand = wp.stand,
                        }
                    end)
                end),
                author = W.raceData.author,
            },
            function()
                W.openWithData(saved, laps)
            end
        )
    end

    if W.raceData.changed and W.cache.validSave then
        saveRace(function()
            saved.id = W.raceData.id
            saved.changed = false
            launch()
        end)
    else
        launch()
    end
end

local function reverseRace()
    local function _process()
        local newSteps = Table()
        W.raceData.steps:forEach(function(step, iStep)
            if iStep == #W.raceData.steps then
                -- last step
                if W.raceData.loopable then
                    -- loopable race (only reverse rotation)
                    local newStepFinish = Table()
                    step:forEach(function(finish, iFinish)
                        local newFinish = {
                            name = #step == 1 and "finish" or "finish" .. tostring(iFinish),
                            pos = vec3(finish.pos),
                            rot = quat(finish.rot) * quat(0, 0, 1, 0),
                            radius = finish.radius,
                        }
                        newStepFinish:insert(newFinish)
                    end)
                    newSteps:insert(newStepFinish)
                elseif #W.raceData.startPositions > 0 then
                    -- sprint race (swap finish with reversed start pos)
                    local newFinish = {
                        name = "finish",
                        pos = vec3(W.raceData.startPositions[1].pos),
                        rot = quat(W.raceData.startPositions[1].rot),
                        radius = step[1].radius,
                    }
                    newFinish.rot = newFinish.rot * quat(0, 0, 1, 0)
                    newSteps:insert(Table({ newFinish }))
                    -- and set start pos to reversed finish + remove other starts
                    W.raceData.startPositions = Table({ {
                        pos = vec3(step[1].pos),
                        rot = quat(step[1].rot) * quat(0, 0, 1, 0),
                    } })
                end
            else
                -- normal step
                local newStep = Table()
                step:forEach(function(wp, iWp)
                    local newIStep = #W.raceData.steps - iStep
                    wp.name = #step > 1 and string.var("wp{1}-{2}", { newIStep, iWp }) or
                        string.var("wp{1}", { newIStep })
                    wp.rot = wp.rot * quat(0, 0, 1, 0)
                    newStep:insert(wp)
                end)
                newSteps:insert(1, newStep)
            end
        end)
        -- update parents
        newSteps:forEach(function(wps, iStep)
            wps:forEach(function(wp)
                wp.parents = Table(iStep == 1 and { "start" } or
                    newSteps[iStep - 1]:map(function(el) return el.name end))
            end)
        end)
        W.raceData.steps = Table(newSteps)
        W.raceData.changed = true
        updateMarkers()
        validateRace()
    end
    BJI.Managers.Popup.createModal(
        BJI.Managers.Lang.get("races.edit.reverseConfirm"), {
            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"), _process),
        })
end

---@param ctxt TickContext
local function drawTools(ctxt)
    local vehpos = ctxt.isOwner and ctxt.vehPosRot or nil
    if vehpos then
        LineBuilder():icon({
            icon = ICONS.build,
        }):text(W.labels.tools.title)
            :build()

        local line = LineBuilder():text(W.labels.tools.rotation)
        Table({
            { value = -20, icon = ICONS.tb_spiral_left_inside },
            { value = -10, icon = ICONS.tb_spiral_left_outside },
            { value = 10,  icon = ICONS.tb_spiral_right_outside },
            { value = 20,  icon = ICONS.tb_spiral_right_inside },
        }):forEach(function(r)
            line:btnIcon({
                id = string.var("rotate{1}", { r.value }),
                icon = r.icon,
                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                tooltip = string.var("{1} ({2}°)", {
                    r.value < 0 and W.labels.buttons.rotateLeft or W.labels.buttons.rotateRight,
                    math.abs(r.value)
                }),
                onClick = function()
                    local pos = vehpos.pos
                    pos.z = pos.z + .1
                    local rot = vehpos.rot
                    rot = rot - quat(0, 0, math.round(r.value / 360, 8), 0)
                    BJI.Managers.Veh.setPositionRotation(pos, rot, { safe = false })
                end,
            })
        end)
        line:btnIcon({
            id = "rotate180",
            icon = ICONS.tb_bank,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            tooltip = W.labels.buttons.rotate180,
            onClick = function()
                vehpos.rot = vehpos.rot * quat(0, 0, 1, 0)
                BJI.Managers.Veh.setPositionRotation(vehpos.pos, vehpos.rot)
            end
        }):build()
    end
    if #W.raceData.steps > 1 then
        LineBuilder():text(W.labels.tools.reverse)
            :btnIcon({
                id = "reverseRace",
                icon = ICONS.reply_all,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                tooltip = W.labels.buttons.reverseAllSteps,
                onClick = reverseRace,
            }):build()
    end
end

---@param ctxt TickContext
local function drawNameAndAuthor(ctxt)
    LineBuilder()
        :text(W.labels.name, nil, W.labels.nameTooltip)
        :inputString({
            id = "raceName",
            style = W.cache.invalid.name and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
            disabled = W.cache.disableInputs,
            value = W.raceData.name,
            onUpdate = function(val)
                W.raceData.name = val
                W.raceData.changed = true
                validateRace()
            end
        })
        :build()
    LineBuilder()
        :text(W.labels.author)
        :text(W.raceData.author, W.raceData.author == ctxt.user.playerName and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :build()
end

---@param ctxt TickContext
local function drawPreviewPosition(ctxt)
    local line = LineBuilder()
        :icon({
            icon = ICONS.simobject_camera,
            coloredIcon = true,
            style = { W.cache.invalid.previewPosition and
            BJI.Utils.Style.TEXT_COLORS.ERROR or BJI.Utils.Style.TEXT_COLORS.DEFAULT },
        })
        :text(W.labels.previewPosition, W.cache.invalid.previewPosition and BJI.Utils.Style.TEXT_COLORS.ERROR or nil,
            W.labels.previewPositionTooltip)
        :btnIcon({
            id = "setPreviewPos",
            icon = W.raceData.previewPosition and ICONS.edit_location or ICONS.add_location,
            style = W.raceData.previewPosition and BJI.Utils.Style.BTN_PRESETS.WARNING or
                BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs,
            tooltip = W.labels.buttons.setPreviewPositionHere,
            onClick = function()
                W.raceData.previewPosition = BJI.Managers.Cam.getPositionRotation(true)
                W.raceData.changed = true
                validateRace()
            end
        })
    if W.raceData.previewPosition then
        line:btnIcon({
            id = "goToPreviewPos",
            icon = ICONS.pin_drop,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            tooltip = W.labels.buttons.showPreviewPosition,
            onClick = function()
                if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                    BJI.Managers.Cam.toggleFreeCam()
                end
                BJI.Managers.Cam.setPositionRotation(W.raceData.previewPosition.pos, W.raceData.previewPosition.rot)
            end
        })
    end
    line:build()
end

-- laps amount & start/finish waypoint
local function drawLoopable()
    LineBuilder():text(W.labels.loopable)
        :btnIconToggle({
            id = "toggleLoopable",
            icon = ICONS.rotate_90_degrees_ccw,
            state = W.raceData.loopable,
            disabled = W.cache.disableInputs,
            tooltip = W.labels.buttons.toggleLoopable,
            onClick = function()
                W.raceData.loopable = not W.raceData.loopable
                W.raceData.changed = true
                W.raceData.keepRecord = false
                updateMarkers()
            end,
        }):build()
end

---@param ctxt TickContext
local function drawStartPositions(ctxt)
    AccordionBuilder():label("##startPositions"):commonStart(
        function(isOpen)
            local line = LineBuilder(true):icon({
                icon = ICONS.simobject_player_spawn_sphere,
                coloredIcon = true,
                style = { W.cache.invalid.startPositionsCount and
                BJI.Utils.Style.TEXT_COLORS.ERROR or BJI.Utils.Style.TEXT_COLORS.DEFAULT },
            }):text(W.labels.startPositions, W.cache.invalid.startPositionsCount and
                BJI.Utils.Style.TEXT_COLORS.ERROR or nil)
            if isOpen then
                local disabled = not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
                line:btnIcon({
                    id = "addStartPos",
                    icon = ICONS.add_location,
                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or disabled,
                    tooltip = string.var("{1}{2}", {
                        W.labels.buttons.addStartPositionHere,
                        disabled and (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""
                    }),
                    onClick = function()
                        W.raceData.startPositions:insert(ctxt.vehPosRot)
                        W.raceData.changed = true
                        W.raceData.keepRecord = false
                        updateMarkers()
                        validateRace()
                    end,
                })
            end
            if W.cache.invalid.startPositionsCount then
                line:text(W.labels.missing, BJI.Utils.Style.TEXT_COLORS.ERROR)
            end
            line:build()
        end
    ):openedBehavior(
        function()
            W.raceData.startPositions:reduce(function(cols, sp, iSp)
                return cols:addRow({
                    cells = {
                        function()
                            LineLabel(W.labels.startPosition:var({ index = iSp }), nil, false,
                                W.labels.startPositionTooltip)
                        end,
                        function()
                            LineBuilder():btnIcon({
                                id = "moveUpStartPos" .. tostring(iSp),
                                icon = ICONS.arrow_drop_up,
                                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = W.cache.disableInputs or iSp == 1,
                                tooltip = W.labels.buttons.moveUp,
                                onClick = function()
                                    W.raceData.startPositions:insert(iSp - 1, W.raceData.startPositions[iSp])
                                    W.raceData.startPositions:remove(iSp + 1)
                                    W.raceData.changed = true
                                    W.raceData.keepRecord = false
                                    updateMarkers()
                                    validateRace()
                                end,
                            }):btnIcon({
                                id = "moveDownStartPos" .. tostring(iSp),
                                icon = ICONS.arrow_drop_down,
                                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = W.cache.disableInputs or iSp == #W.raceData.startPositions,
                                tooltip = W.labels.buttons.moveDown,
                                onClick = function()
                                    W.raceData.startPositions:insert(iSp + 2, W.raceData.startPositions[iSp])
                                    W.raceData.startPositions:remove(iSp)
                                    W.raceData.changed = true
                                    W.raceData.keepRecord = false
                                    updateMarkers()
                                    validateRace()
                                end,
                            }):btnIcon({
                                id = "goToStartPos" .. tostring(iSp),
                                icon = ICONS.pin_drop,
                                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                                tooltip = W.labels.buttons.showStartPosition,
                                onClick = function()
                                    if ctxt.isOwner then
                                        BJI.Managers.Veh.setPositionRotation(sp.pos, sp.rot, { saveHome = true })
                                        if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                                            BJI.Managers.Cam.toggleFreeCam()
                                        end
                                    else
                                        if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                                            BJI.Managers.Cam.toggleFreeCam()
                                        end
                                        BJI.Managers.Cam.setPositionRotation(sp.pos, sp.rot)
                                    end
                                end,
                            }):btnIcon({
                                id = "moveStartPos" .. tostring(iSp),
                                icon = ICONS.edit_location,
                                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = W.cache.disableInputs or not ctxt.veh or
                                    ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                                tooltip = string.var("{1}{2}", {
                                    W.labels.buttons.setStartPositionHere,
                                    (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                                    (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""
                                }),
                                onClick = function()
                                    table.assign(sp, ctxt.vehPosRot)
                                    W.raceData.changed = true
                                    W.raceData.keepRecord = false
                                    updateMarkers()
                                    validateRace()
                                end,
                            }):btnIcon({
                                id = "deleteStartPos" .. tostring(iSp),
                                icon = ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                disabled = W.cache.disableInputs,
                                tooltip = W.labels.buttons.deleteStartPosition,
                                onClick = function()
                                    W.raceData.startPositions:remove(iSp)
                                    W.raceData.changed = true
                                    W.raceData.keepRecord = false
                                    updateMarkers()
                                    validateRace()
                                end,
                            }):build()
                        end
                    }
                })
            end, ColumnsBuilder("BJIScenarioEditorRaceStartPositions", { W.widths.startPositionsLabelsWidth, -1 }))
                :build()
        end
    ):build()
end

---@param ctxt TickContext
---@param iStep integer
---@param step table
---@param iWp integer
---@param wp table
local function drawWaypoint(ctxt, iStep, step, iWp, wp)
    -- WAYPOINT ACTIONS
    local line = LineBuilder():text(#step == 1 and W.labels.waypoint or
        W.labels.branch .. tostring(iWp)):btnIcon({
        id = string.var("goToWP-{1}-{2}", { iStep, iWp }),
        icon = ICONS.pin_drop,
        style = BJI.Utils.Style.BTN_PRESETS.INFO,
        tooltip = W.labels.buttons.showWaypoint,
        onClick = function()
            if ctxt.isOwner then
                BJI.Managers.Veh.setPositionRotation(wp.pos, wp.rot, { saveHome = true })
                if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                    BJI.Managers.Cam.toggleFreeCam()
                end
            else
                if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                    BJI.Managers.Cam.toggleFreeCam()
                end
                BJI.Managers.Cam.setPositionRotation(wp.pos, wp.rot)
            end
        end,
    }):btnIcon({
        id = string.var("moveWP-{1}-{2}", { iStep, iWp }),
        icon = ICONS.edit_location,
        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
        disabled = W.cache.disableInputs or not ctxt.veh or
            ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
        tooltip = string.var("{1}{2}", {
            W.labels.buttons.setWaypointHere,
            (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
            (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""
        }),
        onClick = function()
            table.assign(wp, ctxt.vehPosRot)
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end,
    }):btnIconToggle({
        id = string.var("toggleStandWP-{1}-{2}", { iStep, iWp }),
        icon = ICONS.local_gas_station,
        state = wp.stand == true,
        disabled = W.cache.disableInputs,
        tooltip = W.labels.buttons.toggleStandWaypoint,
        onClick = function()
            wp.stand = not wp.stand
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end
    }):btnIcon({
        id = string.var("deleteWP-{1}-{2}", { iStep, iWp }),
        icon = ICONS.delete_forever,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        disabled = W.cache.disableInputs,
        tooltip = W.labels.buttons.deleteWaypoint,
        onClick = function()
            if iWp == 1 and #step == 1 then
                -- remove step
                W.raceData.steps:remove(iStep)
            else
                step:remove(iWp)
            end
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end
    })
    if W.cache.invalid.steps[iStep][iWp].missingChild then
        line:text(W.labels.noChild, BJI.Utils.Style.TEXT_COLORS.ERROR)
    end
    line:build()

    -- WAYPOINT DATA
    Indent(2)
    ColumnsBuilder(string.var("BJIScenarioEditorRaceStep{1}branch{2}", { iStep, iWp }), { W.widths.wpLabelsWidth, -1 })
        :addRow({
            cells = {
                function() LineLabel(W.labels.wpName) end,
                function()
                    LineBuilder()
                        :inputString({
                            id = string.var("nameWP-{1}-{2}", { iStep, iWp }),
                            value = wp.name,
                            style = W.cache.invalid.steps[iStep][iWp].name and
                                BJI.Utils.Style.INPUT_PRESETS.ERROR,
                            disabled = W.cache.disableInputs,
                            onUpdate = function(val)
                                wp.name = val
                                W.raceData.changed = true
                                W.raceData.keepRecord = false
                                updateMarkers()
                                validateRace()
                            end,
                        })
                        :build()
                end,
            }
        }):addRow({
        cells = {
            function() LineLabel(wp.stand and W.labels.radius or W.labels.size) end,
            function()
                LineBuilder()
                    :inputNumeric({
                        id = string.var("radiusWP-{1}-{2}", { iStep, iWp }),
                        type = "float",
                        value = wp.radius,
                        min = 1,
                        max = 50,
                        step = .5,
                        disabled = W.cache.disableInputs,
                        onUpdate = function(val)
                            wp.radius = val
                            W.raceData.changed = true
                            W.raceData.keepRecord = false
                            updateMarkers()
                            validateRace()
                        end
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.bottomHeight) end,
            function()
                LineBuilder()
                    :inputNumeric({
                        id = string.var("bottomHeightWP-{1}-{2}", { iStep, iWp }),
                        type = "float",
                        value = wp.zOffset or 1,
                        min = 0,
                        max = 10,
                        step = .25,
                        disabled = W.cache.disableInputs,
                        onUpdate = function(val)
                            wp.zOffset = val ~= 1 and val or nil
                            W.raceData.changed = true
                            W.raceData.keepRecord = false
                            updateMarkers()
                            validateRace()
                        end
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.parent) end,
            function()
                if iStep == 1 then
                    LineLabel(wp.parents[1], nil, false, W.labels.parentStartTooltip)
                else
                    wp.parents:forEach(function(parent, iParent)
                        line = LineBuilder()
                        if #wp.parents > 1 then
                            line:btnIcon({
                                id = string.var("deleteWPParent-{1}-{2}-{3}", { iStep, iWp, iParent }),
                                icon = ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                disabled = W.cache.disableInputs,
                                tooltip = W.labels.buttons.removeParent,
                                onClick = function()
                                    wp.parents:remove(iParent)
                                    W.raceData.changed = true
                                    W.raceData.keepRecord = false
                                    updateMarkers()
                                    validateRace()
                                end
                            })
                        end
                        line:inputString({
                            id = string.var("WPParent-{1}-{2}-{3}", { iStep, iWp, iParent }),
                            value = parent,
                            style = W.cache.invalid.steps[iStep][iWp].parents[iParent] and
                                BJI.Utils.Style.INPUT_PRESETS.ERROR,
                            disabled = W.cache.disableInputs,
                            onUpdate = function(val)
                                wp.parents[iParent] = val
                                W.raceData.changed = true
                                W.raceData.keepRecord = false
                                updateMarkers()
                                validateRace()
                            end
                        }):build()
                    end)
                    LineBuilder():btnIcon({
                        id = string.var("addWPParent-{1}-{2}", { iStep, iWp }),
                        icon = ICONS.addListItem,
                        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = W.cache.disableInputs,
                        tooltip = W.labels.buttons.addParent,
                        onClick = function()
                            wp.parents:insert("")
                            W.raceData.changed = true
                            W.raceData.keepRecord = false
                            updateMarkers()
                            validateRace()
                        end
                    }):build()
                end
            end,
        }
    }):build()
    Indent(-2)
end

local function addStepBranch(ctxt, iStep, step)
    step:insert(table.assign({
        name = getNewWPName(),
        parents = Table(iStep == 1 and { "start" } or
            W.raceData.steps[iStep - 1]:map(function(wp) return wp.name end)),
        radius = getNewWaypointRadius(iStep, #step + 1),
    }, ctxt.vehPosRot))
    W.raceData.changed = true
    W.raceData.keepRecord = false
    updateMarkers()
    validateRace()
end

---@param ctxt TickContext
---@param iStep integer
---@param step table
local function drawStep(ctxt, iStep, step)
    -- STEP ACTIONS
    LineBuilder()
        :text(W.labels.step .. tostring(iStep),
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT):btnIcon({
        id = "moveupStep" .. tostring(iStep),
        icon = ICONS.arrow_drop_up,
        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
        disabled = W.cache.disableInputs or iStep == 1,
        tooltip = W.labels.buttons.moveUp,
        onClick = function()
            W.raceData.steps:insert(iStep - 1, W.raceData.steps[iStep])
            W.raceData.steps:remove(iStep + 1)
            if iStep == 2 then -- reset parents to start if second is moved up
                step:forEach(function(wp)
                    wp.parents = Table({ "start" })
                end)
            end
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end
    }):btnIcon({
        id = "movedownStep" .. tostring(iStep),
        icon = ICONS.arrow_drop_down,
        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
        disabled = W.cache.disableInputs or iStep == #W.raceData.steps,
        tooltip = W.labels.buttons.moveDown,
        onClick = function()
            if iStep == 1 then -- set second steps parents to start
                W.raceData.steps[iStep + 1]:forEach(function(wp)
                    wp.parents = Table({ "start" })
                end)
            end
            W.raceData.steps:insert(iStep + 2, W.raceData.steps[iStep])
            W.raceData.steps:remove(iStep)
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end
    }):btnIcon({
        id = "deleteStep" .. tostring(iStep),
        icon = ICONS.delete_forever,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        disabled = W.cache.disableInputs,
        tooltip = W.labels.buttons.deleteStep,
        onClick = function()
            if iStep == 1 and W.raceData.steps[iStep + 1] then
                -- set new firsts parent to start
                W.raceData.steps[iStep + 1]:forEach(function(wp)
                    wp.parents = Table({ "start" })
                end)
            end
            W.raceData.steps:remove(iStep)
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end
    }):btnIcon({
        id = "addStepBranchTop" .. tostring(iStep),
        icon = ICONS.fg_sideways,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = W.cache.disableInputs or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
        tooltip = string.var("{1}{2}", {
            W.labels.buttons.addBranchHere,
            (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
            (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""
        }),
        onClick = function()
            addStepBranch(ctxt, iStep, step)
        end
    }):build()

    Indent(2)
    step:forEach(function(wp, iWp)
        drawWaypoint(ctxt, iStep, step, iWp, wp)
    end)
    if #step > 1 then
        LineBuilder():btnIcon({
            id = "addStepBranchBottom" .. tostring(iStep),
            icon = ICONS.fg_sideways,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
            tooltip = string.var("{1}{2}", {
                W.labels.buttons.addBranchHere,
                (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""
            }),
            onClick = function()
                addStepBranch(ctxt, iStep, step)
            end
        }):build()
    end
    Indent(-2)
end

local function addNewStep(ctxt)
    local parents = #W.raceData.steps == 0 and Table({ "start" }) or
        W.raceData.steps[#W.raceData.steps]:map(function(wp) return wp.name end)
    W.raceData.steps:insert(Table({
        table.assign({
            name = getNewWPName(),
            parents = parents,
            radius = getNewWaypointRadius(#W.raceData.steps + 1, 1),
        }, ctxt.vehPosRot)
    }))
    W.raceData.changed = true
    W.raceData.keepRecord = false
    updateMarkers()
    validateRace()
    -- scroll down
    W.nextTickScrollDown = true
end

---@param ctxt TickContext
local function drawSteps(ctxt)
    LineLabel(W.labels.stepFinishWarning, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
    AccordionBuilder():label("##raceSteps"):commonStart(
        function(isOpen)
            local line = LineBuilder(true):icon({
                icon = ICONS.simobject_bng_waypoint,
                coloredIcon = true,
                style = { (W.cache.invalid.stepsCount or Table(W.cache.invalid.steps):flat()
                    :any(function(el) return el end)) and
                BJI.Utils.Style.TEXT_COLORS.ERROR or BJI.Utils.Style.TEXT_COLORS.DEFAULT },
            }):text(W.labels.steps)
            if isOpen then
                line:btnIcon({
                    id = "addRaceStepTop",
                    icon = ICONS.add_location,
                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not ctxt.veh or
                        ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                    tooltip = string.var("{1}{2}", {
                        W.labels.buttons.addRaceStepHere,
                        (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                        (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""
                    }),
                    onClick = function()
                        addNewStep(ctxt)
                    end
                })
            end
            if W.cache.invalid.stepsCount then
                line:text(W.labels.missing, BJI.Utils.Style.TEXT_COLORS.ERROR)
            end
            line:build()
        end
    ):openedBehavior(
        function()
            -- STEPS
            W.raceData.steps:forEach(function(step, iStep)
                drawStep(ctxt, iStep, step)
            end)
            if #W.raceData.steps > 1 then
                LineBuilder():btnIcon({
                    id = "addRaceStepBottom",
                    icon = ICONS.add_location,
                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not ctxt.veh or
                        ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                    tooltip = string.var("{1}{2}", {
                        W.labels.buttons.addRaceStepHere,
                        (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                        (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""
                    }),
                    onClick = function()
                        addNewStep(ctxt)
                    end
                }):build()
            end
        end
    ):build()
end

local function header(ctxt)
    LineBuilder():text(W.labels.editTitle):btnIcon({
        id = "reloadMarkers",
        icon = ICONS.sync,
        style = BJI.Utils.Style.BTN_PRESETS.INFO,
        tooltip = W.labels.buttons.refreshMarkers,
        onClick = updateMarkers,
    }):build()

    drawTools(ctxt)
    Separator()

    drawNameAndAuthor(ctxt)

    LineBuilder():text(W.labels.enabled):btnIconToggle({
        id = "raceEnabled",
        icon = W.raceData.enabled and ICONS.visibility or ICONS.visibility_off,
        state = W.raceData.enabled,
        tooltip = W.labels.buttons.toggleRaceVisibility,
        onClick = function()
            W.raceData.enabled = not W.raceData.enabled
            W.raceData.changed = true
        end
    }):build()
end

---@param ctxt TickContext
local function body(ctxt)
    local markedScrollDown = W.nextTickScrollDown
    W.nextTickScrollDown = false

    drawPreviewPosition(ctxt)
    Separator()
    drawLoopable()
    Separator()
    drawStartPositions(ctxt)
    Separator()
    drawSteps(ctxt)

    if markedScrollDown then
        ui_imgui.SetScrollY(ui_imgui.GetScrollMaxY())
    end
end

local function footer(ctxt)
    local tryDisabled = false
    local tryErrorTooltip = ""
    if not W.cache.validTry then
        tryDisabled = true
        tryErrorTooltip = " (" .. W.labels.buttons.errorInvalidData .. ")"
    elseif not W.scenarioSolo.canChangeTo(ctxt) or not ctxt.isOwner then
        tryDisabled = true
        tryErrorTooltip = " (" .. W.labels.buttons.errorMustHaveVehicle .. ")"
    end
    local line = LineBuilder():btnIcon({
        id = "tryRace",
        icon = ICONS.fg_vehicle_race_car,
        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
        disabled = tryDisabled,
        tooltip = string.var("{1}{2}", {
            W.labels.buttons.tryRace, tryErrorTooltip
        }),
        onClick = function()
            tryRace(ctxt)
        end,
    })
    if W.raceData.loopable then
        line:text(W.labels.laps, nil, W.labels.lapsTooltip)
            :inputNumeric({
                id = "raceLaps",
                type = "int",
                value = W.tryLaps,
                min = 1,
                max = 20,
                step = 1,
                onUpdate = function(val)
                    W.tryLaps = val
                end
            })
    end
    line:build()

    line = LineBuilder()
        :btnIcon({
            id = "leaveRaceEditor",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = W.labels.buttons.leave,
            onClick = BJI.Windows.ScenarioEditor.onClose,
        })
    if W.raceData.changed or not W.raceData.id then
        line:btnIcon({
            id = "saveRace",
            icon = ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs or not W.cache.validSave,
            tooltip = string.var("{1}{2}", {
                W.labels.buttons.save,
                not W.cache.validSave and
                (" (" .. W.labels.buttons.errorInvalidData .. ")") or ""
            }),
            onClick = saveRace,
        })
    end
    line:build()
end

local function footerLines(ctxt)
    return 2
end

local function openWithData(raceData, tryLaps)
    W.scenarioSolo = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_SOLO)
    table.assign(W.raceData, raceData)
    W.raceData.steps = Table(W.raceData.steps)
    W.raceData.startPositions = Table(W.raceData.startPositions)
    W.tryLaps = tryLaps or 1
    updateMarkers()
    validateRace()
    BJI.Windows.ScenarioEditor.view = W
end

---@param raceID? integer
---@param isCopy? boolean
local function openWithID(raceID, isCopy)
    local res = {
        changed = false,
        id = nil,
        author = BJI.Managers.Context.User.playerName,
        name = "",
        previewPosition = nil,
        steps = {},
        startPositions = {},
        loopable = false,
        laps = nil,
        enabled = true,
        hasRecord = false,
        keepRecord = true,
    }
    if raceID then
        -- ID existing => edition / duplication
        BJI.Tx.scenario.RaceDetails(raceID, function(raceData)
            if raceData then
                if isCopy then
                    -- duplication
                    res.keepRecord = false
                else
                    -- edition
                    res.id = raceData.id
                    res.author = raceData.author
                    res.name = raceData.name
                    res.hasRecord = raceData.record ~= nil
                end
                res.previewPosition = math.tryParsePosRot(raceData.previewPosition)
                res.steps = raceData.steps
                for _, step in ipairs(res.steps) do
                    for iWp, wp in ipairs(step) do
                        step[iWp] = math.tryParsePosRot(wp)
                    end
                end
                res.startPositions = raceData.startPositions
                for iSp, sp in ipairs(res.startPositions) do
                    res.startPositions[iSp] = math.tryParsePosRot(sp)
                end
                res.loopable = raceData.loopable == true
                res.laps = raceData.loopable and 1 or nil
                res.enabled = raceData.enabled == true

                W.openWithData(res)
            else
                BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.invalidData"))
            end
        end)
    else
        -- no ID => creation
        W.openWithData(res)
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.footerLines = footerLines
W.onClose = onClose

W.openWithData = openWithData
W.openWithID = openWithID

return W
