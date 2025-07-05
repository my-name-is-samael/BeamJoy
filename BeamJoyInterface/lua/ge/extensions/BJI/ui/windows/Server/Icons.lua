local W = {}
--- gc prevention
local nextValue, opened, maxIconsPerRow

local filter = ""
---@type tablelib<integer, string> index 1-N
local filtered
local function updateFilter()
    local query = filter:lower():trim()
    if #query == 0 then
        filtered = Table(BJI.Utils.Icon.ICONS_FLAT):clone()
    else
        filtered = Table(BJI.Utils.Icon.ICONS_FLAT)
            :filter(function(i) return i:lower():find(query) end)
    end
    if filtered then
        filtered:sort(function(a, b) return a:lower() < b:lower() end)
    end
end
updateFilter()

---@param ctxt TickContext
local function header(ctxt)
    Icon(BJI.Utils.Icon.ICONS.ab_filter_default)
    SameLine()
    nextValue = InputText("iconsFilter", filter)
    if nextValue then
        filter = nextValue
        updateFilter()
    end
end

---@param ctxt TickContext
local function body(ctxt)
    maxIconsPerRow = math.floor(GetContentRegionAvail().x / BJI.Utils.UI.GetBtnIconSize(true))
    filtered:forEach(function(icon, i)
        if i % maxIconsPerRow ~= 1 then SameLine() end
        Icon(icon, { big = true })
        TooltipText(icon)
    end)
end

W.onLoad = TrueFn
W.onUnload = TrueFn
W.header = header
W.body = body

return W
