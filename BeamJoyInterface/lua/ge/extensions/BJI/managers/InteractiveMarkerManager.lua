---@class ActivityWindow
---@field type string
---@field label string
---@field buttonLabel string
---@field callback fun(ctxt: TickContext)
---@field condition (fun(ctxt: TickContext): boolean)?
---@field icon string?

---@class InteractiveMarker
---@field _marker table internal
---@field _active boolean internal
---@field condition fun(ctxt: TickContext): boolean?
---@field onEnter fun(ctxt: TickContext)?
---@field onActive fun(ctxt: TickContext)? -- triggered every tick when active
---@field onLeave fun(ctxt: TickContext)?
---@field visibleFreeCam boolean?
---@field visibleAnyVeh boolean?
---@field visibleWalking boolean?
---@field activityData ActivityWindow[]?

---@class BJIManagerInteractiveMarker : BJIManager
local M = {
    _name = "InteractiveMarker",

    TYPES = {
        GARAGE = {
            icon = BJI.Utils.Icon.ICONS.poi_garage_2_round,
            color = BJI.Utils.ShapeDrawer.Color(1, .4, 0),
        },
        ENERGY_STATION = {
            icon = BJI.Utils.Icon.ICONS.poi_fuel_round,
            color = BJI.Utils.ShapeDrawer.Color(1, .4, 0),
        },
        RACE_SOLO = {
            icon = BJI.Utils.Icon.ICONS.mission_timeTrials_triangle,
            color = BJI.Utils.ShapeDrawer.Color(.3, .5, 1),
        },
        RACE_MULTI = {
            icon = BJI.Utils.Icon.ICONS.mission_airace02_triangle,
            color = BJI.Utils.ShapeDrawer.Color(.3, .5, 1),
        },
        DELIVERY_HUBS = {
            icon = BJI.Utils.Icon.ICONS.mission_delivery_triangle,
            color = BJI.Utils.ShapeDrawer.Color(.4, .4, 1),
        },
        BUS_MISSION = {
            icon = BJI.Utils.Icon.ICONS.mission_busRoute_triangle,
            color = BJI.Utils.ShapeDrawer.Color(1, 1, 0),
        },
        DERBY_ARENA = {
            icon = BJI.Utils.Icon.ICONS.mission_cup_triangle,
            color = BJI.Utils.ShapeDrawer.Color(1, 0, 0),
        },
    },

    ---@type table?
    group = nil,
    ---@type tablelib<string, InteractiveMarker> index markerID
    markers = Table(),
    ---@type tablelib<integer, ActivityWindow>
    currentActivityWindows = Table(),
}

local function initGroup()
    if M.group then return end
    M.group = BJI_WorldObject.createGroup("BJIInteractiveMarkers")
end

local function reset()
    M.markers:forEach(function(_, id)
        M.deleteMarker(tostring(id))
    end)
end

local function getMarkers()
    return M.markers
end

---@param id string
---@return InteractiveMarker?
local function getMarker(id)
    return M.markers[id]
end

---@param id string
---@return table?
local function createMarkerObject(id)
    if not M.markers[id] then return end
    local obj = scenetree.findObject(id)
    if not obj then
        obj = createObject("BeamNGWorldIconsRenderer")
        obj:registerObject(id)
        obj.maxIconScale = 2
        obj.mConstantSizeIcons = true
        obj.canSave = false
        obj:loadIconAtlas("core/art/gui/images/iconAtlas.png", "core/art/gui/images/iconAtlas.json")
    end
    M.markers[id]._marker.iconRendererId = obj:getId()
    M.markers[id]._marker.iconDataById = {}
    return obj
end

---@param id string
---@param icon string
---@param pos vec3
---@param radius number 0-N
---@param data {condition: (fun(ctxt: TickContext): boolean?), onEnter: fun(ctxt: TickContext)?, onActive: fun(ctxt: TickContext)?, onLeave: fun(ctxt: TickContext)?, visibleAnyVeh: boolean?, visibleFreeCam: boolean?, visibleWalking: boolean?, color: BJIColor?}?
---@param activityData ActivityWindow[]?
local function upsertMarker(id, icon, pos, radius, data, activityData)
    data = data or {}
    initGroup()
    M.deleteMarker(id)
    M.markers[id] = {
        _marker = require('lua/ge/extensions/gameplay/markers/missionMarker').create(),
        _active = false,
        condition = data.condition,
        onEnter = data.onEnter,
        onActive = data.onActive,
        onLeave = data.onLeave,
        visibleAnyVeh = data.visibleAnyVeh,
        visibleFreeCam = data.visibleFreeCam,
        visibleWalking = data.visibleWalking,
        activityData = activityData
    }
    M.group:addObject((createMarkerObject(id) or {}).obj)
    M.markers[id]._marker:setup({ id = id, pos = pos, icon = icon, elemData = { true } })
    M.markers[id]._marker.radius = radius
    M.markers[id]._marker.groundDecalData[2].scale = vec3(radius * 2, radius * 2, 3)
    if data.color then
        -- icon
        table.find(M.markers[id]._marker.iconDataById, TrueFn, function(iconInfo)
            iconInfo.color = data.color:colorI()
        end)
        -- dot
        M.markers[id]._marker.groundDecalData[1].color = data.color:colorF()
        -- ring
        M.markers[id]._marker.groundDecalData[2].color = data.color:colorF()
    end
end

---@param id string
local function deleteMarker(id)
    if M.markers[id] then
        initGroup()
        M.group:findObject(id):unregisterObject()
        if M.markers[id].onLeave then M.markers[id].onLeave(BJI_Tick.getContext()) end
        M.markers[id] = nil
    end
end

local activeWindows = Table()
local decals = {}
local visible, interact, activeSpeed -- gc
local cachedData
---@param ctxt TickContext
local function fastTick(ctxt)
    if M.markers:length() > 0 then
        cachedData = {
            veh = ctxt.veh and ctxt.veh.veh,
            camPos = BJI_Cam.getPositionRotation().pos,
            bigMapActive = freeroam_bigMapMode.bigMapActive(),
            globalAlpha = 1,
            dt = BJI.dt.real,
            cruisingSpeedFactor = 0,
            isWalking = ctxt.veh and ctxt.veh.jbeam == "unicycle",
            canInteract = true,
        }
        cachedData.playerPosition = ctxt.veh and ctxt.veh.position or cachedData.camPos
        if ctxt.veh then
            cachedData.bbCenter = vec3(be:getObjectOOBBCenterXYZ(ctxt.veh.gameVehicleID))
            cachedData.bbHalfAxis0 = vec3(be:getObjectOOBBHalfAxisXYZ(ctxt.veh.gameVehicleID, 0))
            cachedData.bbHalfAxis1 = vec3(be:getObjectOOBBHalfAxisXYZ(ctxt.veh.gameVehicleID, 1))
            cachedData.bbHalfAxis2 = vec3(be:getObjectOOBBHalfAxisXYZ(ctxt.veh.gameVehicleID, 2))
            cachedData.highestBBPointZ = ctxt.veh.position.z
        end
    end
end

local function renderTick(ctxt)
    if cachedData and M.markers:length() > 0 then
        activeSpeed = not ctxt.veh or not tonumber(ctxt.veh.veh.speed) or
            tonumber(ctxt.veh.veh.speed) < .5
        table.clear(decals)
        activeWindows:clear()
        ---@param el InteractiveMarker
        M.markers:forEach(function(el)
            if el.condition and not el.condition(ctxt) then
                visible = false
            elseif not el.visibleFreeCam and ctxt.camera == BJI_Cam.CAMERAS.FREE then
                visible = false
            elseif not el.visibleAnyVeh and not ctxt.isOwner then
                visible = false
            elseif not el.visibleWalking and cachedData.isWalking then
                visible = false
            else
                visible = true
            end
            if visible then
                el._marker:show()
                el._marker:update(cachedData)
                if not freeroam_bigMapMode.bigMapActive() then
                    interact = {}
                    el._marker:interactInPlayMode(cachedData, interact)
                    if activeSpeed and not BJI_Prompt.process and #interact > 0 then
                        if not el._active then
                            el._active = true
                            if el.onEnter then el.onEnter(ctxt) end
                        end
                        if el.onActive then el.onActive(ctxt) end
                    elseif el._active then
                        el._active = false
                        if el.onLeave then el.onLeave(ctxt) end
                    end
                end
                for _, v in ipairs(el._marker.groundDecalData.texture and
                    { el._marker.groundDecalData } or el._marker.groundDecalData) do
                    table.insert(decals, v)
                end
            else
                el._marker:hide()
                if el._active then
                    el._active = false
                    if el.onLeave then el.onLeave(ctxt) end
                end
            end
            if el._active and el.activityData then
                activeWindows:addAll(table.filter(el.activityData, function(w)
                    return not w.condition or w.condition(ctxt)
                end))
            end
        end)
        if #decals > 0 then
            Engine.Render.DynamicDecalMgr.addDecals(decals, #decals)
        end
        if not M.currentActivityWindows:compare(activeWindows) then
            if #activeWindows == 0 then
                ui_missionInfo.closeDialogue()
                guihooks.trigger('ActivityAcceptUpdate', nil)
            else
                ---@param w ActivityWindow
                ui_missionInfo.openActivityAcceptDialogue(activeWindows:map(function(w)
                    return {
                        icon = w.icon,
                        preheadings = { w.type },
                        heading = w.label,
                        buttonLabel = w.buttonLabel,
                        buttonFun = function() w.callback(BJI_Tick.getContext()) end,
                    }
                end))
            end
            M.currentActivityWindows:clear()
            M.currentActivityWindows:addAll(activeWindows)
        end
    end
end

M.onLoad = function()
    BJI_Events.addListener(BJI_Events.EVENTS.FAST_TICK, fastTick, M._name)
end
M.renderTick = renderTick

M.reset = reset
M.getMarkers = getMarkers
M.getMarker = getMarker
M.upsertMarker = upsertMarker
M.deleteMarker = deleteMarker

return M
