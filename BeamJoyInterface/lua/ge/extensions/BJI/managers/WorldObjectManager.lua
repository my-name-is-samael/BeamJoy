---@class BJIManagerWorldObject : BJIManager
local M = {
    _name = "WorldObject",

    parentName = "BJIObjects",
    ---@type table?
    parent = nil,
}

local function initParent()
    if M.parent then return end
    if not scenetree.MissionGroup:findObject(M.parentName) then
        local BJIObjects = createObject('SimGroup')
        BJIObjects:registerObject('BJIObjects')
        BJIObjects.canSave = false
        scenetree.MissionGroup:addObject(BJIObjects.obj)
    end
    M.parent = scenetree.MissionGroup:findObject(M.parentName)
    if not M.parent then
        error("Unable to create BJI world objects tree")
    end
end

---@param objName string
---@return table?
local function findObject(objName)
    initParent()
    return M.parent:findObject(objName)
end

---@param groupName string
---@return table?
local function createGroup(groupName)
    initParent()
    local existing = M.parent:findObject(groupName)
    if existing then return existing end

    local group = createObject("SimGroup")
    group:registerObject(groupName)
    group.canSave = false
    M.parent:addObject(group.obj)
    return M.parent:findObject(groupName)
end

---@param group table?
---@return tablelib<integer, table>
local function getGroupChildren(group)
    if not group or type(group.getObjects) ~= "function" then
        return Table()
    end
    return Table(group:getObjects()):map(function(objName)
        return group:findObject(objName)
    end)
end

local function unregister(obj)
    if not obj or type(obj.unregisterObject) ~= "function" then return end
    obj:unregisterObject()
end

---@param objName string
---@return table
local function createCornerMarker(objName)
    local marker = createObject('TSStatic')
    marker:setField('shapeName', 0, "art/shapes/interface/position_marker.dae")
    marker:setPosition(vec3(0, 0, 0))
    marker.scale = vec3(1, 1, 1)
    marker:setField('rotation', 0, '1 0 0 0')
    marker.useInstanceRenderData = true
    marker:setField('instanceColor', 0, '0 0 0 0')
    marker:setField('collisionType', 0, "Collision Mesh")
    marker:setField('decalType', 0, "Collision Mesh")
    marker:setField('playAmbient', 0, "1")
    marker:setField('allowPlayerStep', 0, "1")
    marker:setField('canSave', 0, "0")
    marker:setField('canSaveDynamicFields', 0, "1")
    marker:setField('renderNormals', 0, "0")
    marker:setField('meshCulling', 0, "0")
    marker:setField('originSort', 0, "0")
    marker:setField('forceDetail', 0, "-1")
    marker.canSave = false
    marker:registerObject(objName)
    return marker
end

-- global functions

M.findObject = findObject
M.createGroup = createGroup
M.getGroupChildren = getGroupChildren
M.unregister = unregister

-- specific objects instances

M.createCornerMarker = createCornerMarker

return M
