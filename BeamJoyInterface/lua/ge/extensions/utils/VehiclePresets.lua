local U = {}

--- How to add your own vehicle config:
--- spawn your vehicle, then execute:
--- `dump(BJI_Veh.getCurrentModel(), BJI_Veh.getCurrentConfigKey())`
--- to print the model, then the config key (keep in mind your custom
--- configurations will not be available to other players)
local DERBY_PRESETS = Table({
    {
        label = "Derby Vehicles",
        configs = Table({
            {
                model = "autobello",
                key = "gambler",
            },
            {
                model = "legran",
                key = "derby",
            },
            {
                model = "legran",
                key = "derby_wagon",
            },
            {
                model = "moonhawk",
                key = "terrible",
            },
            {
                model = "nine",
                key = "nine_junkrod",
            },
            {
                model = "burnside",
                key = "stunned",
            },
            {
                model = "bolide",
                key = "gambler",
            },
            {
                model = "etki",
                key = "offroad",
            },
            {
                model = "barstow",
                key = "awful",
            },
            {
                model = "bluebuck",
                key = "horrible",
            },
            {
                model = "pickup",
                key = "d35_disappointment_A",
            },
            {
                model = "fullsize",
                key = "gambler",
            },
            {
                model = "fullsize",
                key = "miserable",
            },
            {
                model = "van",
                key = "derby",
            },
            {
                model = "roamer",
                key = "derby",
            },
            {
                model = "sunburst2",
                key = "offroad",
            },
            {
                model = "bx",
                key = "derby_M",
            },
            {
                model = "covet",
                key = "gamblertruck",
            },
            {
                model = "covet",
                key = "3wheel",
            },
            {
                model = "covet",
                key = "pointless",
            },
            {
                model = "covet",
                key = "skidplate",
            },
            {
                model = "miramar",
                key = "derby",
            },
            {
                model = "midsize",
                key = "derby",
            },
            {
                model = "pessima",
                key = "derby",
            },
            {
                model = "pigeon",
                key = "gambler",
            },
            {
                model = "lansdale",
                key = "gambler500",
            },
            {
                model = "lansdale",
                key = "33_derby_late_M",
            },
            {
                model = "lansdale",
                key = "25_derby_M",
            },
            {
                model = "wendover",
                key = "gambler",
            },
            {
                model = "wendover",
                key = "junkhana",
            },
        })
    }
})

---@return {label: string, configs: {model: string, key: string}[]}[]
function U.getDerbyPresets()
    return DERBY_PRESETS:clone()
end

return U
