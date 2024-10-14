local function draw(ctxt)
    if BJIVeh.isCurrentVehicleOwn() and not BJIScenario.isServerScenarioInProgress() then
        require("ge/extensions/BJI/ui/WindowBJI/Body/VehicleEnergyIndicator")(ctxt)

        require("ge/extensions/BJI/ui/WindowBJI/Body/VehicleHealthIndicator")(ctxt)
    end

    if (
            BJIScenario.isFreeroam() or
            BJIScenario.is(BJIScenario.TYPES.VEHICLE_DELIVERY) or
            BJIScenario.is(BJIScenario.TYPES.PACKAGE_DELIVERY)
        ) and
        BJIContext.Scenario.Data.Deliveries and
        #BJIContext.Scenario.Data.Deliveries > 0 and
        BJIContext.Scenario.Data.DeliveryLeaderboard and
        #BJIContext.Scenario.Data.DeliveryLeaderboard > 0 then
        require("ge/extensions/BJI/ui/WindowBJI/Body/DeliveryLeaderBoard")()
    end

    if BJIScenario.is(BJIScenario.TYPES.VEHICLE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY) then
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY).drawDeliveryUI(ctxt)
        Separator()
    elseif BJIScenario.is(BJIScenario.TYPES.PACKAGE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY) then
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY).drawDeliveryUI(ctxt)
        Separator()
    elseif BJIScenario.is(BJIScenario.TYPES.BUS_MISSION) and
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION) then
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).drawMissionUI(ctxt)
    end

    if BJIScenario.isFreeroam() and
        BJIContext.Scenario.Data.Races and
        #BJIContext.Scenario.Data.Races > 0 then
        local recordRaces = {}
        for _, race in ipairs(BJIContext.Scenario.Data.Races) do
            if race.record then
                table.insert(recordRaces, race)
            end
        end
        if #recordRaces > 0 then
            table.sort(recordRaces, function(a, b)
                return a.name < b.name
            end)
            require("ge/extensions/BJI/ui/WindowBJI/Body/RaceLeaderboard")(recordRaces)
        end
    end

    local staff = BJIPerm.isStaff()

    if staff then
        require("ge/extensions/BJI/ui/WindowBJI/Body/Moderation")(ctxt)
    else
        require("ge/extensions/BJI/ui/WindowBJI/Body/Players")(ctxt)
    end
end
return draw
