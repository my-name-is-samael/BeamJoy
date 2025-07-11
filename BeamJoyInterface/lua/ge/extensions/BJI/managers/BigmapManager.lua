---@class BJIManagerBigmap : BJIManager
local M = {
    _name = "Bigmap",

    baseFunctions = {},
    POI_TYPES_BLACKLIST = {
        "mission"
    },
    quickTravel = true, -- default state when joining
}

-- remove missions from bigmap
local function getRawPoiListByLevel(level)
    if BJI_Restrictions.getState(BJI_Restrictions.OTHER.BIG_MAP) then
        BJI_UI.hideGameMenu()
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
        BJI_Toast.error("Error retrieving POIs for current map")
        LogError(err)
        return {}, 0
    end
end

local function formatPoiForBigmap(poi)
    if BJI_Restrictions.getState(BJI_Restrictions.OTHER.BIG_MAP) then
        BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
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

local function updateQuickTravelState()
    local function _update()
        M.quickTravel = BJI_Scenario.canQuickTravel()
    end

    if BJI_Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY then
        _update()
    else
        BJI_Async.task(function()
            return BJI_Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY
        end, _update)
    end
end

local function onUnload()
    extensions.gameplay_rawPois.getRawPoiListByLevel = M.baseFunctions.getRawPoiListByLevel
    extensions.freeroam_bigMapPoiProvider.formatPoiForBigmap = M.baseFunctions.formatPoiForBigmap
end

local function onLoad()
    if extensions.gameplay_rawPois then
        M.baseFunctions.getRawPoiListByLevel = extensions.gameplay_rawPois.getRawPoiListByLevel
        extensions.gameplay_rawPois.getRawPoiListByLevel = getRawPoiListByLevel

        M.baseFunctions.formatPoiForBigmap = extensions.freeroam_bigMapPoiProvider.formatPoiForBigmap
        extensions.freeroam_bigMapPoiProvider.formatPoiForBigmap = formatPoiForBigmap
    end
    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)
    BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.SCENARIO_UPDATED,
    }, function(_, data)
        if data.event ~= BJI_Events.EVENTS.CACHE_LOADED or
            data.cache == BJI_Cache.CACHES.BJC then
            updateQuickTravelState()
        end
    end, M._name)
end

M.onLoad = onLoad

return M
