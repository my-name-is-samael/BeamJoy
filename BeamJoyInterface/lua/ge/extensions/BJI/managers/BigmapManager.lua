local M = {
    baseFunctions = {},
    POI_TYPES_BLACKLIST = {
        "mission"
    }
}

-- remove missions from bigmap
local function getRawPoiListByLevel(level)
    local list, generation = M.baseFunctions.getRawPoiListByLevel(level)
    local i = 1
    while i < #list do
        while tincludes(M.POI_TYPES_BLACKLIST, list[i].data.type, true) do
            table.remove(list, i)
        end
        i = i + 1
    end
    return list, generation
end

local function onLoad()
    if gameplay_rawPois then
        M.baseFunctions.getRawPoiListByLevel = gameplay_rawPois.getRawPoiListByLevel

        gameplay_rawPois.getRawPoiListByLevel = getRawPoiListByLevel
    end
end

local function onUnload()
    if M.baseFunctions.getRawPoiListByLevel then
        gameplay_rawPois.getRawPoiListByLevel = M.baseFunctions.getRawPoiListByLevel
    end
end

M.onLoad = onLoad
M.onUnload = onUnload

RegisterBJIManager(M)
return M
