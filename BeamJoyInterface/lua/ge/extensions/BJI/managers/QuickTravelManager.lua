local M = {
    state = true, -- default state when joining
}

-- override bigmap poi creation fn to prevent quick travel
local function overrideFunction()
    freeroam_bigMapPoiProvider.formatPoiForBigmap = function(poi)
        local bmi = poi.markerInfo.bigmapMarker
        local canQuickTravel = M.state and not not bmi.quickTravelPosRotFunction or false
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
end

local function toggle(state)
    M.state = state
    overrideFunction()
end

M.toggle = toggle

RegisterBJIManager(M)
return M
