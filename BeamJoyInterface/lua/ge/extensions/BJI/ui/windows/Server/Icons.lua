local W = {}

local filter = ""
local filtered = table.clone(ICONS_FLAT)
local function updateFilter()
    local query = filter:lower()
    if #query == 0 then
        filtered = table.clone(ICONS_FLAT)
    else
        filtered = {}
        for _, icon in ipairs(ICONS_FLAT) do
            if icon:lower():find(query) then
                table.insert(filtered, icon)
            end
        end
    end
    table.sort(filtered, function(a, b) return a:lower() < b:lower() end)
end

local function drawFilter()
    LineBuilder()
        :icon({
            icon = ICONS.ab_filter_default,
        })
        :inputString({
            id = "iconsFilter",
            value = filter,
            onUpdate = function(val)
                filter = val
                updateFilter()
            end
        })
end

local function body(ctxt)
    drawFilter()
    AccordionBuilder()
        :label("DEBUG ICONS")
        :commonStart(function()
            LineBuilder(true)
                :icon({
                    icon = ICONS.warning,
                    style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                    coloredIcon = true,
                })
                :text("Performances")
                :build()
        end)
        :openedBehavior(function()
            local w = ui_imgui.GetContentRegionAvail().x
            local iconSize = GetBtnIconSize(true)
            local colsAmount = math.floor(w / iconSize)
            local widths = {}
            for _ = 1, colsAmount do
                table.insert(widths, iconSize)
            end
            local cols = ColumnsBuilder("debugIcons", widths, true)
            for i = 1, #filtered, colsAmount do
                local cells = {}
                for j = i, i + colsAmount - 1 do
                    if j <= #filtered then
                        table.insert(cells, function()
                            LineBuilder()
                                :icon({
                                    icon = filtered[j],
                                    big = true,
                                })
                                :build()
                        end)
                    end
                end
                cols:addRow({
                    cells = cells
                })
                cells = {}
                for j = i, i + colsAmount - 1 do
                    if j <= #filtered then
                        table.insert(cells, function()
                            LineBuilder()
                                :helpMarker(filtered[j])
                                :build()
                        end)
                    end
                end
                cols:addRow({
                    cells = cells
                })
            end
            cols:build()
        end)
        :build()
end

W.onLoad = TrueFn
W.onUnload = TrueFn
W.body = body

return W

