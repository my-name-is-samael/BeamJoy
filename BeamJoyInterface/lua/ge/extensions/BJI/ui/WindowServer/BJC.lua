local function draw(ctxt)

    AccordionBuilder()
        :label(BJILang.get("serverConfig.bjc.whitelist.title"))
        :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/Whitelist")(ctxt) end)
        :build()

    AccordionBuilder()
        :label(BJILang.get("serverConfig.bjc.voteKick.title"))
        :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/VoteKick")(ctxt) end)
        :build()

    AccordionBuilder()
        :label(BJILang.get("serverConfig.bjc.mapVote.title"))
        :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/VoteMap")(ctxt) end)
        :build()

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.BAN) then
        AccordionBuilder()
            :label(BJILang.get("serverConfig.bjc.tempban.title"))
            :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/TempBan")(ctxt) end)
            :build()
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO) then
        AccordionBuilder()
            :label(BJILang.get("serverConfig.bjc.race.title"))
            :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/Race")(ctxt) end)
            :build()

        AccordionBuilder()
            :label(BJILang.get("serverConfig.bjc.speed.title"))
            :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/Speed")(ctxt) end)
            :build()

            AccordionBuilder()
                :label(BJILang.get("serverConfig.bjc.hunter.title"))
                :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/Hunter")(ctxt) end)
                :build()

        AccordionBuilder()
            :label(BJILang.get("serverConfig.bjc.vehicleDelivery.title"))
            :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/VehicleDelivery")(ctxt) end)
            :build()
    end

    if BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.OWNER) then
        AccordionBuilder()
            :label(BJILang.get("serverConfig.bjc.server.title"))
            :openedBehavior(function() require("ge/extensions/BJI/ui/WindowServer/BJC/Server")(ctxt) end)
            :build()
    end
end
return draw
