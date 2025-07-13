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
    name                 = "ScenarioEditorRace",

    raceData             = resetData(),
    tryLaps              = 1,
    labels               = {
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
    cache                = {
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
    scenarioSolo         = nil,

    scrollDownQueuedTick = 0, -- flag to scroll down on next tick
}
--- gc prevention
local tryDisabled, tryErrorTooltip, nextValue, vehpos, opened, invalidData

local function onClose()
    BJI_WaypointEdit.reset() -- remove edit markers
    W.raceData = resetData()          -- reset data
end

local function updateLabels()
    W.labels.missing = BJI_Lang.get("errors.missing")

    W.labels.tools.title = BJI_Lang.get("races.tools.title")
    W.labels.tools.rotation = BJI_Lang.get("races.tools.rotation")
    W.labels.tools.reverse = BJI_Lang.get("races.tools.reverse")

    W.labels.editTitle = BJI_Lang.get("races.edit.title")
    W.labels.name = BJI_Lang.get("races.edit.name")
    W.labels.nameTooltip = BJI_Lang.get("races.edit.nameTooltip")
    W.labels.author = BJI_Lang.get("races.edit.author") .. " :"
    W.labels.enabled = BJI_Lang.get("races.edit.enabled")
    W.labels.previewPosition = BJI_Lang.get("races.edit.previewPosition")
    W.labels.previewPositionTooltip = BJI_Lang.get("races.edit.previewPositionTooltip")
    W.labels.loopable = BJI_Lang.get("races.edit.loopable")
    W.labels.laps = BJI_Lang.get("races.edit.laps")
    W.labels.lapsTooltip = BJI_Lang.get("races.edit.lapsTooltip")
    W.labels.startPositions = string.var("{1}:", { BJI_Lang.get("races.edit.startPositions") })
    W.labels.startPosition = BJI_Lang.get("races.edit.startPositionLabel")
    W.labels.startPositionTooltip = BJI_Lang.get("races.edit.startPositionsNameTooltip")
    W.labels.stepFinishWarning = BJI_Lang.get("races.edit.stepsFinishWarning")
    W.labels.steps = BJI_Lang.get("races.edit.steps") .. " :"
    W.labels.step = BJI_Lang.get("races.edit.step") .. " "
    W.labels.waypoint = BJI_Lang.get("races.edit.waypoint")
    W.labels.branch = BJI_Lang.get("races.edit.branch") .. " "
    W.labels.wpName = BJI_Lang.get("races.edit.wpName")
    W.labels.radius = BJI_Lang.get("races.edit.radius")
    W.labels.size = BJI_Lang.get("races.edit.size")
    W.labels.bottomHeight = BJI_Lang.get("races.edit.bottomHeight")
    W.labels.parent = BJI_Lang.get("races.edit.parent")
    W.labels.parentStartTooltip = BJI_Lang.get("races.edit.parentStartTooltip")
    W.labels.noChild = BJI_Lang.get("races.edit.errors.noChild")

    W.labels.buttons.refreshMarkers = BJI_Lang.get("races.edit.buttons.refreshMarkers")
    W.labels.buttons.rotateLeft = BJI_Lang.get("races.edit.buttons.rotateLeft")
    W.labels.buttons.rotateRight = BJI_Lang.get("races.edit.buttons.rotateRight")
    W.labels.buttons.rotate180 = BJI_Lang.get("races.edit.buttons.rotate180")
    W.labels.buttons.reverseAllSteps = BJI_Lang.get("races.edit.buttons.reverseAllSteps")
    W.labels.buttons.toggleRaceVisibility = BJI_Lang.get("races.edit.buttons.toggleRaceVisibility")
    W.labels.buttons.showPreviewPosition = BJI_Lang.get("races.edit.buttons.showPreviewPosition")
    W.labels.buttons.setPreviewPositionHere = BJI_Lang.get("races.edit.buttons.setPreviewPositionHere")
    W.labels.buttons.toggleLoopable = BJI_Lang.get("races.edit.buttons.toggleLoopable")
    W.labels.buttons.addStartPositionHere = BJI_Lang.get("races.edit.buttons.addStartPositionHere")
    W.labels.buttons.moveUp = BJI_Lang.get("common.buttons.moveUp")
    W.labels.buttons.moveDown = BJI_Lang.get("common.buttons.moveDown")
    W.labels.buttons.showStartPosition = BJI_Lang.get("races.edit.buttons.showStartPosition")
    W.labels.buttons.setStartPositionHere = BJI_Lang.get("races.edit.buttons.setStartPositionHere")
    W.labels.buttons.deleteStartPosition = BJI_Lang.get("races.edit.buttons.deleteStartPosition")
    W.labels.buttons.addRaceStepHere = BJI_Lang.get("races.edit.buttons.addRaceStepHere")
    W.labels.buttons.deleteStep = BJI_Lang.get("races.edit.buttons.deleteStep")
    W.labels.buttons.addBranchHere = BJI_Lang.get("races.edit.buttons.addBranchHere")
    W.labels.buttons.showWaypoint = BJI_Lang.get("races.edit.buttons.showWaypoint")
    W.labels.buttons.setWaypointHere = BJI_Lang.get("races.edit.buttons.setWaypointHere")
    W.labels.buttons.toggleStandWaypoint = BJI_Lang.get("races.edit.buttons.toggleStandWaypoint")
    W.labels.buttons.deleteWaypoint = BJI_Lang.get("races.edit.buttons.deleteWaypoint")
    W.labels.buttons.removeParent = BJI_Lang.get("races.edit.buttons.removeParent")
    W.labels.buttons.addParent = BJI_Lang.get("races.edit.buttons.addParent")
    W.labels.buttons.tryRace = BJI_Lang.get("races.edit.buttons.tryRace")
    W.labels.buttons.errorMustHaveVehicle = BJI_Lang.get("errors.mustHaveVehicle")
    W.labels.buttons.errorInvalidData = BJI_Lang.get("errors.someDataAreInvalid")
    W.labels.buttons.leave = BJI_Lang.get("common.buttons.leave")
    W.labels.buttons.save = BJI_Lang.get("common.buttons.save")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
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

    W.cache.invalid.name = #W.raceData.name == 0 or Table(BJI_Scenario.Data.Races)
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
            if #wp.name == 0 or wp.name:trim() == "start" or
                previousWpNames:includes(wp.name) then
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

            local seenParents = Table()
            W.cache.invalid.steps[iStep][iWp].parents = {}
            if iStep > 1 then -- validate parents
                wp.parents:forEach(function(parentName, iParent)
                    if parentName:trim() ~= "start" and
                        not findParent(parentName, iStep) then
                        W.cache.invalid.steps[iStep][iWp].parents[iParent] = true
                        W.cache.validSave = false
                        W.cache.validTry = false
                    else
                        if seenParents:includes(parentName) then
                            W.cache.invalid.steps[iStep][iWp].parents[iParent] = true
                            W.cache.validSave = false
                            W.cache.validTry = false
                        else
                            seenParents:insert(parentName)
                        end
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
    local startPositionColor = BJI.Utils.ShapeDrawer.Color(1, 1, 0, .5)
    local cpColor = BJI.Utils.ShapeDrawer.Color(1, .5, .5, .5)
    local finishColor = BJI.Utils.ShapeDrawer.Color(.66, .66, 1, .5)
    local standColor = BJI.Utils.ShapeDrawer.Color(1, .66, 0, .5)

    BJI_WaypointEdit.setWaypointsWithSegments(W.raceData.startPositions:map(function(p, i)
        return { -- START POSITIONS
            name = BJI_Lang.get("races.edit.startPositionLabel"):var({ index = i }),
            pos = p.pos,
            rot = p.rot,
            radius = 2,
            color = startPositionColor,
            textColor = startPositionColor,
            textBg = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5),
            type = BJI_WaypointEdit.TYPES.ARROW,
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
                type = wp.stand and BJI_WaypointEdit.TYPES.CYLINDER or
                    BJI_WaypointEdit.TYPES.RACE_GATE,
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

---@param callback fun(raceID?: integer)?
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
        BJI_Tx_scenario.RaceSave(race, function(result)
            if result then
                W.raceData.id = result
                W.raceData.changed = false
                W.raceData.hasRecord = W.raceData.hasRecord and W.raceData.keepRecord
                W.raceData.keepRecord = true
            else
                BJI_Toast.error(BJI_Lang.get("races.edit.saveErrorToast"))
            end
            W.cache.disableInputs = false
            if type(callback) == "function" then callback(result or nil) end
        end)
    end

    if W.raceData.hasRecord and not W.raceData.keepRecord then
        BJI_Popup.createModal(BJI_Lang.get("races.edit.hasRecordConfirm"), {
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.cancel")),
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.confirm"), _finalSave),
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
        BJI_RaceWaypoint.resetAll()
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
    BJI_Popup.createModal(
        BJI_Lang.get("races.edit.reverseConfirm"), {
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.cancel")),
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.confirm"), _process),
        })
end

---@param ctxt TickContext
local function drawTools(ctxt)
    vehpos = ctxt.isOwner and math.roundPositionRotation({
        pos = ctxt.veh.position,
        rot = ctxt.veh.rotation,
    }) or nil
    if vehpos then
        Icon(BJI.Utils.Icon.ICONS.build)
        SameLine()
        Text(W.labels.tools.title)

        Text(W.labels.tools.rotation)
        Table({
            { value = -20, icon = BJI.Utils.Icon.ICONS.tb_spiral_left_inside },
            { value = -10, icon = BJI.Utils.Icon.ICONS.tb_spiral_left_outside },
            { value = 10,  icon = BJI.Utils.Icon.ICONS.tb_spiral_right_outside },
            { value = 20,  icon = BJI.Utils.Icon.ICONS.tb_spiral_right_inside },
        }):forEach(function(r)
            SameLine()
            if IconButton("rotate" .. tostring(r.value), r.icon,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                BJI_Veh.setPositionRotation(vehpos.pos + vec3(0, 0, .1),
                    vehpos.rot - quat(0, 0, math.round(r.value / 360, 8), 0),
                    { safe = false })
            end
            TooltipText(string.format("%s (%d°)",
                r.value < 0 and W.labels.buttons.rotateLeft or W.labels.buttons.rotateRight,
                math.abs(r.value)
            ))
        end)
        SameLine()
        if IconButton("rotate180", BJI.Utils.Icon.ICONS.tb_bank,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
            vehpos.rot = vehpos.rot * quat(0, 0, 1, 0)
            BJI_Veh.setPositionRotation(vehpos.pos, vehpos.rot)
        end
        TooltipText(W.labels.buttons.rotate180)
    end
    if #W.raceData.steps > 1 then
        Text(W.labels.tools.reverse)
        SameLine()
        if IconButton("reverseRace", BJI.Utils.Icon.ICONS.reply_all,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            reverseRace()
        end
        TooltipText(W.labels.buttons.reverseAllSteps)
    end
end

---@param ctxt TickContext
local function drawNameAndAuthor(ctxt)
    Text(W.labels.name)
    TooltipText(W.labels.nameTooltip)
    SameLine()
    nextValue = InputText("raceName", W.raceData.name,
        {
            inputStyle = W.cache.invalid.name and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
            disabled = W.cache.disableInputs
        })
    if nextValue then
        W.raceData.name = nextValue
        W.raceData.changed = true
        validateRace()
    end

    Text(W.labels.author)
    SameLine()
    Text(W.raceData.author, {
        color = W.raceData.author == ctxt.user.playerName and
            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil
    })
end

---@param ctxt TickContext
local function drawPreviewPosition(ctxt)
    Icon(BJI.Utils.Icon.ICONS.simobject_camera, {
        color = W.cache.invalid.previewPosition and
            BJI.Utils.Style.TEXT_COLORS.ERROR or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    })
    SameLine()
    Text(W.labels.previewPosition, {
        color = W.cache.invalid.previewPosition and
            BJI.Utils.Style.TEXT_COLORS.ERROR or nil
    })
    TooltipText(W.labels.previewPositionTooltip)
    SameLine()
    if IconButton("setPreviewPos", W.raceData.previewPosition and
            BJI.Utils.Icon.ICONS.edit_location or BJI.Utils.Icon.ICONS.add_location,
            { btnStyle = W.raceData.previewPosition and BJI.Utils.Style.BTN_PRESETS.WARNING or
                BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs }) then
        W.raceData.previewPosition = BJI_Cam.getPositionRotation(true)
        W.raceData.changed = true
        validateRace()
    end
    TooltipText(W.labels.buttons.setPreviewPositionHere)
    if W.raceData.previewPosition then
        SameLine()
        if IconButton("goToPreviewPos", BJI.Utils.Icon.ICONS.pin_drop) then
            if ctxt.camera ~= BJI_Cam.CAMERAS.FREE then
                BJI_Cam.toggleFreeCam()
            end
            BJI_Cam.setPositionRotation(W.raceData.previewPosition.pos, W.raceData.previewPosition.rot)
        end
        TooltipText(W.labels.buttons.showPreviewPosition)
    end
end

-- laps amount & start/finish waypoint
local function drawLoopable()
    Text(W.labels.loopable)
    SameLine()
    if IconButton("toggleLoopable", BJI.Utils.Icon.ICONS.rotate_90_degrees_ccw,
            { btnStyle = W.raceData.loopable and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
        W.raceData.loopable = not W.raceData.loopable
        W.raceData.changed = true
        W.raceData.keepRecord = false
        updateMarkers()
    end
    TooltipText(W.labels.buttons.toggleLoopable)
end

---@param ctxt TickContext
local function drawStartPositions(ctxt)
    opened = BeginTree("##startPositions")
    SameLine()
    Icon(BJI.Utils.Icon.ICONS.simobject_player_spawn_sphere,
        { color = W.cache.invalid.startPositionsCount and BJI.Utils.Style.TEXT_COLORS.ERROR or nil })
    SameLine()
    Text(W.labels.startPositions)
    if opened then
        SameLine()
        if IconButton("addStartPos", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                    not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
            W.raceData.startPositions:insert(math.roundPositionRotation({
                pos = ctxt.veh.position,
                rot = ctxt.veh.rotation,
            }))
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end
        TooltipText(W.labels.buttons.addStartPositionHere ..
            ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""))
    end
    if W.cache.invalid.startPositionsCount then
        SameLine()
        Text(W.labels.missing, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        if BeginTable("BJIScenarioEditorRaceStartPositions", {
                { label = "##scenarioeditor-race-startpositions-labels" },
                { label = "##scenarioeditor-race-startpositions-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            }) then
            W.raceData.startPositions:forEach(function(sp, iSp)
                TableNewRow()
                Text(W.labels.startPosition:var({ index = iSp }))
                TooltipText(W.labels.startPositionTooltip)
                TableNextColumn()
                if IconButton("moveUpStartPos" .. tostring(iSp), BJI.Utils.Icon.ICONS.arrow_drop_up,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = W.cache.disableInputs or iSp == 1 }) then
                    W.raceData.startPositions:insert(iSp - 1, W.raceData.startPositions[iSp])
                    W.raceData.startPositions:remove(iSp + 1)
                    W.raceData.changed = true
                    W.raceData.keepRecord = false
                    updateMarkers()
                    validateRace()
                end
                TooltipText(W.labels.buttons.moveUp)
                SameLine()
                if IconButton("moveDownStartPos" .. tostring(iSp), BJI.Utils.Icon.ICONS.arrow_drop_down,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = W.cache.disableInputs or iSp == #W.raceData.startPositions }) then
                    W.raceData.startPositions:insert(iSp + 2, W.raceData.startPositions[iSp])
                    W.raceData.startPositions:remove(iSp)
                    W.raceData.changed = true
                    W.raceData.keepRecord = false
                    updateMarkers()
                    validateRace()
                end
                TooltipText(W.labels.buttons.moveDown)
                SameLine()
                if IconButton("goToStartPos" .. tostring(iSp), BJI.Utils.Icon.ICONS.pin_drop) then
                    if ctxt.isOwner then
                        BJI_Veh.setPositionRotation(sp.pos, sp.rot, { saveHome = true })
                        if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                            BJI_Cam.toggleFreeCam()
                        end
                    else
                        if ctxt.camera ~= BJI_Cam.CAMERAS.FREE then
                            BJI_Cam.toggleFreeCam()
                        end
                        BJI_Cam.setPositionRotation(sp.pos, sp.rot)
                    end
                end
                TooltipText(W.labels.buttons.showStartPosition)
                SameLine()
                if IconButton("moveStartPos" .. tostring(iSp), BJI.Utils.Icon.ICONS.edit_location,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = W.cache.disableInputs or not ctxt.veh or
                                ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
                    table.assign(sp, math.roundPositionRotation({
                        pos = ctxt.veh.position,
                        rot = ctxt.veh.rotation,
                    }))
                    W.raceData.changed = true
                    W.raceData.keepRecord = false
                    updateMarkers()
                    validateRace()
                end
                TooltipText(W.labels.buttons.setStartPositionHere ..
                    ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                        (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""))
                SameLine()
                if IconButton("deleteStartPos" .. tostring(iSp), BJI.Utils.Icon.ICONS.delete_forever,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                    W.raceData.startPositions:remove(iSp)
                    W.raceData.changed = true
                    W.raceData.keepRecord = false
                    updateMarkers()
                    validateRace()
                end
                TooltipText(W.labels.buttons.deleteStartPosition)
            end)
            EndTable()
        end
        EndTree()
    end
end

---@param ctxt TickContext
---@param iStep integer
---@param step table
---@param iWp integer
---@param wp table
local function drawWaypoint(ctxt, iStep, step, iWp, wp)
    -- WAYPOINT ACTIONS
    Text(#step == 1 and W.labels.waypoint or W.labels.branch .. tostring(iWp))
    SameLine()
    if IconButton(string.format("goToWP-%d-%d", iStep, iWp), BJI.Utils.Icon.ICONS.pin_drop) then
        if ctxt.isOwner then
            BJI_Veh.setPositionRotation(wp.pos, wp.rot, { saveHome = true })
            if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                BJI_Cam.toggleFreeCam()
            end
        else
            if ctxt.camera ~= BJI_Cam.CAMERAS.FREE then
                BJI_Cam.toggleFreeCam()
            end
            BJI_Cam.setPositionRotation(wp.pos, wp.rot)
        end
    end
    TooltipText(W.labels.buttons.showWaypoint)
    SameLine()
    if IconButton(string.format("moveWP-%d-%d", iStep, iWp), BJI.Utils.Icon.ICONS.edit_location,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
        table.assign(wp, math.roundPositionRotation({
            pos = ctxt.veh.position,
            rot = ctxt.veh.rotation,
        }))
        W.raceData.changed = true
        W.raceData.keepRecord = false
        updateMarkers()
        validateRace()
    end
    TooltipText(W.labels.buttons.setWaypointHere ..
        ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
            (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""))
    SameLine()
    if IconButton(string.format("toggleStandWP-%d-%d", iStep, iWp), BJI.Utils.Icon.ICONS.local_gas_station,
            { btnStyle = wp.stand == true and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
        wp.stand = not wp.stand
        W.raceData.changed = true
        W.raceData.keepRecord = false
        updateMarkers()
        validateRace()
    end
    TooltipText(W.labels.buttons.toggleStandWaypoint)
    SameLine()
    if IconButton(string.format("deleteWP-%d-%d", iStep, iWp), BJI.Utils.Icon.ICONS.delete_forever,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
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
    TooltipText(W.labels.buttons.deleteWaypoint)
    -- post delete frame fix
    invalidData = W.cache.invalid.steps[iStep] ~= nil and W.cache.invalid.steps[iStep][iWp] or { parents = {} }
    if invalidData.missingChild then
        SameLine()
        Text(W.labels.noChild, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end

    -- WAYPOINT DATA
    Indent(); Indent()
    if BeginTable(string.format("BJIScenarioEditorRaceStep-%s-%s", iStep, iWp), {
            { label = string.format("##scenarioeditor-race-steps-wp-%d-%d-labels", iStep, iWp) },
            { label = string.format("##scenarioeditor-race-steps-wp-%d-%d-inputs", iStep, iWp),
                flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.wpName)
        TableNextColumn()
        nextValue = InputText(string.format("WPname-%d-%d", iStep, iWp), wp.name, {
            inputStyle = invalidData.name and
                BJI.Utils.Style.INPUT_PRESETS.ERROR,
            disabled = W.cache.disableInputs
        })
        if nextValue then
            -- update all references before updating
            W.raceData.steps:forEach(function(wps, iStep2)
                if iStep2 > iStep then
                    wps:forEach(function(wp2)
                        wp2.parents:forEach(function(p, i)
                            if p == wp.name then
                                wp2.parents[i] = nextValue
                            end
                        end)
                    end)
                end
            end)
            wp.name = nextValue
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end

        TableNewRow()
        Text(wp.stand and W.labels.radius or W.labels.size)
        TableNextColumn()
        nextValue = SliderFloatPrecision(string.format("WPradius-%d-%d", iStep, iWp), wp.radius, 1, 50,
            { step = .5, precision = 1, disabled = W.cache.disableInputs })
        if nextValue then
            wp.radius = nextValue
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end

        TableNewRow()
        Text(W.labels.bottomHeight)
        TableNextColumn()
        nextValue = SliderFloatPrecision(string.format("WPbottomHeight-%d-%d", iStep, iWp), wp.zOffset or 1, 0, 10,
            { step = .2, precision = 1, disabled = W.cache.disableInputs })
        if nextValue then
            wp.zOffset = nextValue ~= 1 and nextValue or nil
            W.raceData.changed = true
            W.raceData.keepRecord = false
            updateMarkers()
            validateRace()
        end

        TableNewRow()
        Text(W.labels.parent)
        TableNextColumn()
        if iStep == 1 then
            Text(wp.parents[1])
            TooltipText(W.labels.parentStartTooltip)
        else
            wp.parents:forEach(function(parent, iParent)
                if #wp.parents > 1 then
                    if IconButton(string.format("deleteWPParent-%d-%d-%d", iStep, iWp, iParent),
                            BJI.Utils.Icon.ICONS.delete_forever, { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                disabled = W.cache.disableInputs }) then
                        wp.parents:remove(iParent)
                        W.raceData.changed = true
                        W.raceData.keepRecord = false
                        updateMarkers()
                        validateRace()
                    end
                    TooltipText(W.labels.buttons.removeParent)
                    SameLine()
                end
                nextValue = InputText(string.format("WPParent-%d-%d-%d", iStep, iWp, iParent), parent,
                    {
                        inputStyle = invalidData.parents[iParent] and
                            BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                        disabled = W.cache.disableInputs
                    })
                if nextValue then
                    wp.parents[iParent] = nextValue
                    W.raceData.changed = true
                    W.raceData.keepRecord = false
                    updateMarkers()
                    validateRace()
                end
            end)
            if IconButton(string.format("addWPParent-%d-%d", iStep, iWp), BJI.Utils.Icon.ICONS.addListItem,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs }) then
                wp.parents:insert("")
                W.raceData.changed = true
                W.raceData.keepRecord = false
                updateMarkers()
                validateRace()
            end
            TooltipText(W.labels.buttons.addParent)
        end

        EndTable()
    end
    Unindent(); Unindent()
end

---@param ctxt TickContext
---@param iStep integer
---@param step table
local function addStepBranch(ctxt, iStep, step)
    step:insert(table.assign({
        name = getNewWPName(),
        parents = Table(iStep == 1 and { "start" } or
            W.raceData.steps[iStep - 1]:map(function(wp) return wp.name end)),
        radius = getNewWaypointRadius(iStep, #step + 1),
    }, math.roundPositionRotation({
        pos = ctxt.veh.position,
        rot = ctxt.veh.rotation
    })))
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
    Text(W.labels.step .. tostring(iStep),
        { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
    SameLine()
    if IconButton("moveupStep" .. tostring(iStep), BJI.Utils.Icon.ICONS.arrow_drop_up,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                disabled = W.cache.disableInputs or iStep == 1,
            }) then
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
    TooltipText(W.labels.buttons.moveUp)
    SameLine()
    if IconButton("movedownStep" .. tostring(iStep), BJI.Utils.Icon.ICONS.arrow_drop_down,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                disabled = W.cache.disableInputs or iStep == #W.raceData.steps }) then
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
    TooltipText(W.labels.buttons.moveDown)
    SameLine()
    if IconButton("deleteStep" .. tostring(iStep), BJI.Utils.Icon.ICONS.delete_forever,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
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
    TooltipText(W.labels.buttons.deleteStep)
    SameLine()
    if IconButton("addStepBranchTop" .. tostring(iStep), BJI.Utils.Icon.ICONS.fg_sideways,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.disableInputs or not ctxt.veh or
                    ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
        addStepBranch(ctxt, iStep, step)
    end
    TooltipText(W.labels.buttons.addBranchHere ..
        ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
            (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""))

    Indent(); Indent()
    step:forEach(function(wp, iWp)
        drawWaypoint(ctxt, iStep, step, iWp, wp)
    end)
    if #step > 1 then
        if IconButton("addStepBranchBottom" .. tostring(iStep), BJI.Utils.Icon.ICONS.fg_sideways,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not ctxt.veh or
                        ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
            addStepBranch(ctxt, iStep, step)
        end
        TooltipText(W.labels.buttons.addBranchHere ..
            ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""))
    end
    Unindent(); Unindent()
end

---@param ctxt TickContext
local function addNewStep(ctxt)
    local parents = #W.raceData.steps == 0 and Table({ "start" }) or
        W.raceData.steps[#W.raceData.steps]:map(function(wp) return wp.name end)
    W.raceData.steps:insert(Table({
        table.assign({
            name = getNewWPName(),
            parents = parents,
            radius = getNewWaypointRadius(#W.raceData.steps + 1, 1),
        }, math.roundPositionRotation({
            pos = ctxt.veh.position,
            rot = ctxt.veh.rotation,
        }))
    }))
    W.raceData.changed = true
    W.raceData.keepRecord = false
    updateMarkers()
    validateRace()
    -- scroll down
    W.scrollDownQueuedTick = 2
end

---@param ctxt TickContext
local function drawSteps(ctxt)
    Text(W.labels.stepFinishWarning, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })

    opened = BeginTree("##raceSteps")
    SameLine()
    Icon(BJI.Utils.Icon.ICONS.simobject_bng_waypoint, {
        color = (W.cache.invalid.stepsCount or
                Table(W.cache.invalid.steps):flat():any(function(el) return el end)) and
            BJI.Utils.Style.TEXT_COLORS.ERROR or nil
    })
    SameLine()
    Text(W.labels.steps)
    if opened then
        SameLine()
        if IconButton("addRaceStepTop", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                    not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
            addNewStep(ctxt)
        end
        TooltipText(W.labels.buttons.addRaceStepHere ..
            ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or "")
        )
    end
    if W.cache.invalid.stepsCount then
        SameLine()
        Text(W.labels.missing, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        W.raceData.steps:forEach(function(step, iStep)
            drawStep(ctxt, iStep, step)
        end)
        if #W.raceData.steps > 1 then
            if IconButton("addRaceStepBottom", BJI.Utils.Icon.ICONS.add_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = W.cache.disableInputs or not ctxt.veh or
                            ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
                addNewStep(ctxt)
            end
            TooltipText(W.labels.buttons.addRaceStepHere ..
                ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                    (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""))
        end
        EndTree()
    end
end

local function header(ctxt)
    Text(W.labels.editTitle)
    SameLine()
    if IconButton("reloadMarkers", BJI.Utils.Icon.ICONS.sync,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.INFO }) then
        updateMarkers()
    end
    TooltipText(W.labels.buttons.refreshMarkers)

    drawTools(ctxt)
    Separator()

    drawNameAndAuthor(ctxt)

    Text(W.labels.enabled)
    SameLine()
    if IconButton("raceEnabled", W.raceData.enabled and
            BJI.Utils.Icon.ICONS.visibility or BJI.Utils.Icon.ICONS.visibility_off,
            { btnStyle = W.raceData.enabled and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        W.raceData.enabled = not W.raceData.enabled
        W.raceData.changed = true
    end
    TooltipText(W.labels.buttons.toggleRaceVisibility)
end

---@param ctxt TickContext
local function body(ctxt)
    -- autoscroll down
    if W.scrollDownQueuedTick > 0 then
        W.scrollDownQueuedTick = W.scrollDownQueuedTick - 1
        if W.scrollDownQueuedTick == 0 then
            ui_imgui.SetScrollY(ui_imgui.GetScrollMaxY())
        end
    end

    drawPreviewPosition(ctxt)
    Separator()
    drawLoopable()
    Separator()
    drawStartPositions(ctxt)
    Separator()
    drawSteps(ctxt)
end

local function footer(ctxt)
    tryDisabled = false
    tryErrorTooltip = ""
    if not W.cache.validTry then
        tryDisabled = true
        tryErrorTooltip = " (" .. W.labels.buttons.errorInvalidData .. ")"
    elseif not W.scenarioSolo.canChangeTo(ctxt) or not ctxt.isOwner then
        tryDisabled = true
        tryErrorTooltip = " (" .. W.labels.buttons.errorMustHaveVehicle .. ")"
    end
    if IconButton("tryRace", BJI.Utils.Icon.ICONS.fg_vehicle_race_car,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                disabled = tryDisabled }) then
        tryRace(ctxt)
    end
    TooltipText(W.labels.buttons.tryRace .. tryErrorTooltip)
    if W.raceData.loopable then
        SameLine()
        Text(W.labels.laps)
        TooltipText(W.labels.lapsTooltip)
        SameLine()
        nextValue = SliderIntPrecision("raceLaps", W.tryLaps, 1, 20, { step = 1 })
        if nextValue then W.tryLaps = nextValue end
    end

    if IconButton("leaveRaceEditor", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI_Win_ScenarioEditor.onClose()
    end
    TooltipText(W.labels.buttons.leave)
    if W.raceData.changed or not W.raceData.id then
        SameLine()
        if IconButton("saveRace", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not W.cache.validSave }) then
            saveRace()
        end
        TooltipText(W.labels.buttons.save ..
            (not W.cache.validSave and
                (" (" .. W.labels.buttons.errorInvalidData .. ")") or ""))
    end
end

local function openWithData(raceData, tryLaps)
    W.scenarioSolo = BJI_Scenario.get(BJI_Scenario.TYPES.RACE_SOLO)
    table.assign(W.raceData, raceData)
    W.raceData.steps = Table(W.raceData.steps)
    W.raceData.startPositions = Table(W.raceData.startPositions)
    W.tryLaps = tryLaps or 1
    updateMarkers()
    validateRace()
    BJI_Win_ScenarioEditor.view = W
end

---@param raceID? integer
---@param isCopy? boolean
local function openWithID(raceID, isCopy)
    local res = {
        changed = false,
        id = nil,
        author = BJI_Context.User.playerName,
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
        BJI_Tx_scenario.RaceDetails(raceID, function(raceData)
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
                BJI_Toast.error(BJI_Lang.get("errors.invalidData"))
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
function W.footerLines(ctxt) return 2 end

W.onClose = onClose

W.openWithData = openWithData
W.openWithID = openWithID

return W
