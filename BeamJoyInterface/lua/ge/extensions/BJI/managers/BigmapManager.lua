local M = {
    _name = "BJIBigmap",
    baseFunctions = {},
    POI_TYPES_BLACKLIST = {
        "mission"
    },
    quickTravel = true, -- default state when joining
}

-- remove missions from bigmap
local function getRawPoiListByLevel(level)
    if BJIRestrictions.getState(BJIRestrictions.OTHER.BIG_MAP) then
        HideGameMenu()
    end
    local status, list, generation = pcall(M.baseFunctions.getRawPoiListByLevel, level)
    if status then
        local i = 1
        while i < #list do
            while type(list[i].data) == "table" and
                table.includes(M.POI_TYPES_BLACKLIST, list[i].data.type) do
                table.remove(list, i)
            end
            i = i + 1
        end
        return list, generation
    else
        local err = list
        BJIToast.error("Error retrieving POIs for current map")
        LogError(err)
        return {}, 0
    end
end

local function formatPoiForBigmap(poi)
    if BJIRestrictions.getState(BJIRestrictions.OTHER.BIG_MAP) then
        BJIToast.error(BJILang.get("errors.unavailableDuringScenario"))
        LogWarn("getRawPoiListByLevel")
    end

    local bmi = poi.markerInfo.bigmapMarker
    local canQuickTravel = M.quickTravel and not not bmi.quickTravelPosRotFunction or false
    return {
        id = poi.id,
        name = bmi.name,
        description = bmi.description,
        thumbnailFile = bmi.thumbnail,
        previewFiles = bmi.previews,
        type = poi.data.type,
        label = '',
        quickTravelAvailable = canQuickTravel,
        quickTravelUnlocked = canQuickTravel,
    }
end

local function onLoad()
    if extensions.gameplay_rawPois then
        M.baseFunctions.getRawPoiListByLevel = extensions.gameplay_rawPois.getRawPoiListByLevel
        extensions.gameplay_rawPois.getRawPoiListByLevel = getRawPoiListByLevel

        M.baseFunctions.formatPoiForBigmap = extensions.freeroam_bigMapPoiProvider.formatPoiForBigmap
        extensions.freeroam_bigMapPoiProvider.formatPoiForBigmap = formatPoiForBigmap
    end
end

local function onUnload()
    extensions.gameplay_rawPois.getRawPoiListByLevel = M.baseFunctions.getRawPoiListByLevel
    extensions.freeroam_bigMapPoiProvider.formatPoiForBigmap = M.baseFunctions.formatPoiForBigmap
end

local function toggleQuickTravel(state)
    M.quickTravel = state
end

M.onLoad = onLoad
M.onUnload = onUnload

M.toggleQuickTravel = toggleQuickTravel

RegisterBJIManager(M)
return M
