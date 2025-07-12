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

---@class BJIManagerInteractiveMarker : BJIManager
local M = {
    _name = "InteractiveMarker",

    ---@type table?
    group = nil,
    ---@type tablelib<string, InteractiveMarker> index markerID
    markers = Table(),
}

local function initGroup()
    if M.group then return end
    M.group = BJI_WorldObject.createGroup("BJIInteractiveMarkers")
end

local function reset()
    M.markers:forEach(function(_, id)
        M.deleteMarker(id)
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
---@param data {condition: (fun(ctxt: TickContext): boolean?), onEnter: fun(ctxt: TickContext)?, onActive: fun(ctxt: TickContext)?, onLeave: fun(ctxt: TickContext)?, visibleAnyVeh: boolean?, visibleFreeCam: boolean?, visibleWalking: boolean?}?
local function upsertMarker(id, icon, pos, radius, data)
    initGroup()
    M.deleteMarker(id)
    M.markers[id] = {
        _marker = require('lua/ge/extensions/gameplay/markers/missionMarker').create(),
        _active = false,
        condition = data and data.condition,
        onEnter = data and data.onEnter,
        onActive = data and data.onActive,
        onLeave = data and data.onLeave,
        visibleAnyVeh = data and data.visibleAnyVeh,
        visibleFreeCam = data and data.visibleFreeCam,
        visibleWalking = data and data.visibleWalking,
    }
    M.group:addObject((createMarkerObject(id) or {}).obj)
    M.markers[id]._marker:setup({ id = id, pos = pos, icon = icon, elemData = { true } })
    M.markers[id]._marker.radius = radius
end

local function deleteMarker(id)
    if M.markers[id] then
        initGroup()
        M.group:findObject(id):unregisterObject()
        if M.markers[id].onLeave then M.markers[id].onLeave(BJI_Tick.getContext()) end
        M.markers[id] = nil
    end
end

local visible, interact, decals, totalDecals -- gc
local cachedData = {}
---@param ctxt TickContext
local function renderTick(ctxt)
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
        cachedData.playerPosition = ctxt.veh and ctxt.veh.position or cachedData.campos
        if ctxt.veh then
            cachedData.bbCenter = vec3(be:getObjectOOBBCenterXYZ(ctxt.veh.gameVehicleID))
            cachedData.bbHalfAxis0 = vec3(be:getObjectOOBBHalfAxisXYZ(ctxt.veh.gameVehicleID, 0))
            cachedData.bbHalfAxis1 = vec3(be:getObjectOOBBHalfAxisXYZ(ctxt.veh.gameVehicleID, 1))
            cachedData.bbHalfAxis2 = vec3(be:getObjectOOBBHalfAxisXYZ(ctxt.veh.gameVehicleID, 2))
            cachedData.highestBBPointZ = ctxt.veh.position.z
        end
        decals, totalDecals = {}, 0
        M.markers:forEach(function(el)
            if el.condition and not el.condition(ctxt) then
                visible = false
            elseif not el.visibleFreeCam and ctxt.camera == BJI_Cam.CAMERAS.FREE then
                visible = false
            elseif not el.visibleAnyVeh and not ctxt.isOwner then
                visible = false
            elseif not el.visibleWalking and ctxt.veh and ctxt.veh.jbeam == "unicycle" then
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
                    if #interact > 0 then
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
                    totalDecals = totalDecals + 1
                    table.insert(decals, v)
                end
            else
                el._marker:hide()
                if el._active then
                    el._active = false
                    if el.onLeave then el.onLeave(ctxt) end
                end
            end
        end)
        if totalDecals > 0 then
            Engine.Render.DynamicDecalMgr.addDecals(decals, totalDecals)
        end
    end
end

M.reset = reset
M.getMarkers = getMarkers
M.getMarker = getMarker
M.upsertMarker = upsertMarker
M.deleteMarker = deleteMarker
M.renderTick = renderTick

return M
