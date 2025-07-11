---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.SCENARIO
    local scenario = {
        _name = "scenario"
    }

    ---@param raceID integer
    ---@param callback fun(raceData: table|false)
    function scenario.RaceDetails(raceID, callback)
        BJI_Rx_SCENARIO.raceDetailsCallback(callback)
        TX._send(event.EVENT, event.TX.RACE_DETAILS, { raceID })
    end

    ---@param raceData table
    ---@param callback fun(raceID: integer|false)
    function scenario.RaceSave(raceData, callback)
        BJI_Rx_SCENARIO.raceSaveCallback(callback)
        TX._send(event.EVENT, event.TX.RACE_SAVE, { raceData })
    end

    function scenario.RaceToggle(raceID, state)
        TX._send(event.EVENT, event.TX.RACE_TOGGLE, { raceID, state })
    end

    function scenario.RaceDelete(raceID)
        TX._send(event.EVENT, event.TX.RACE_DELETE, { raceID })
    end

    function scenario.RaceMultiUpdate(eventName, data)
        TX._send(event.EVENT, event.TX.RACE_MULTI_UPDATE, { eventName, data })
    end

    function scenario.RaceMultiStop()
        TX._send(event.EVENT, event.TX.RACE_MULTI_STOP)
    end

    function scenario.RaceSoloStart()
        TX._send(event.EVENT, event.TX.RACE_SOLO_START)
    end

    function scenario.RaceSoloUpdate(raceID, time, model)
        TX._send(event.EVENT, event.TX.RACE_SOLO_UPDATE, { raceID, time, model })
    end

    function scenario.RaceSoloEnd(finished)
        TX._send(event.EVENT, event.TX.RACE_SOLO_END, { finished })
    end

    ---@param energyStations table[]
    ---@param callback fun(boolean)
    function scenario.EnergyStationsSave(energyStations, callback)
        BJI_Rx_SCENARIO.energyStationsSaveCallback(callback)
        TX._send(event.EVENT, event.TX.ENERGY_STATIONS_SAVE, { energyStations })
    end

    ---@param garages table[]
    ---@param callback fun(boolean)
    function scenario.GaragesSave(garages, callback)
        BJI_Rx_SCENARIO.garagesSaveCallback(callback)
        TX._send(event.EVENT, event.TX.GARAGES_SAVE, { garages })
    end

    ---@param positions table[]
    ---@param callback fun(boolean)
    function scenario.DeliverySave(positions, callback)
        BJI_Rx_SCENARIO.deliverySaveCallback(callback)
        TX._send(event.EVENT, event.TX.DELIVERY_SAVE, { positions })
    end

    function scenario.DeliveryVehicleStart()
        TX._send(event.EVENT, event.TX.DELIVERY_VEHICLE_START)
    end

    function scenario.DeliveryVehicleSuccess(isPristine)
        TX._send(event.EVENT, event.TX.DELIVERY_VEHICLE_SUCCESS, { isPristine })
    end

    function scenario.DeliveryVehicleFail()
        TX._send(event.EVENT, event.TX.DELIVERY_VEHICLE_FAIL)
    end

    function scenario.DeliveryPackageStart()
        TX._send(event.EVENT, event.TX.DELIVERY_PACKAGE_START)
    end

    function scenario.DeliveryPackageSuccess()
        TX._send(event.EVENT, event.TX.DELIVERY_PACKAGE_SUCCESS)
    end

    function scenario.DeliveryPackageFail()
        TX._send(event.EVENT, event.TX.DELIVERY_PACKAGE_FAIL)
    end

    function scenario.DeliveryMultiJoin(gameVehID, pos)
        TX._send(event.EVENT, event.TX.DELIVERY_MULTI_JOIN, { gameVehID, pos })
    end

    function scenario.DeliveryMultiResetted()
        TX._send(event.EVENT, event.TX.DELIVERY_MULTI_RESETTED)
    end

    function scenario.DeliveryMultiReached()
        TX._send(event.EVENT, event.TX.DELIVERY_MULTI_REACHED)
    end

    function scenario.DeliveryMultiLeave()
        TX._send(event.EVENT, event.TX.DELIVERY_MULTI_LEAVE)
    end

    ---@param busLines table[]
    ---@param callback fun(boolean)
    function scenario.BusLinesSave(busLines, callback)
        BJI_Rx_SCENARIO.busLinesSaveCallback(callback)
        TX._send(event.EVENT, event.TX.BUS_LINES_SAVE, { busLines })
    end

    function scenario.BusMissionStart()
        TX._send(event.EVENT, event.TX.BUS_MISSION_START)
    end

    function scenario.BusMissionReward(idBusLine)
        TX._send(event.EVENT, event.TX.BUS_MISSION_REWARD, { idBusLine })
    end

    function scenario.BusMissionStop()
        TX._send(event.EVENT, event.TX.BUS_MISSION_STOP)
    end

    function scenario.SpeedFail(time)
        TX._send(event.EVENT, event.TX.SPEED_FAIL, { time })
    end

    function scenario.SpeedStop()
        TX._send(event.EVENT, event.TX.SPEED_STOP)
    end

    ---@param hunterData table
    ---@param callback fun(boolean)
    function scenario.HunterInfectedSave(hunterData, callback)
        BJI_Rx_SCENARIO.hunterInfectedSaveCallback(callback)
        TX._send(event.EVENT, event.TX.HUNTER_INFECTED_SAVE, { hunterData })
    end

    ---@param clientEvent string
    ---@param data any
    function scenario.HunterUpdate(clientEvent, data)
        TX._send(event.EVENT, event.TX.HUNTER_UPDATE, { clientEvent, data })
    end

    ---@param playerID integer
    function scenario.HunterForceFugitive(playerID)
        TX._send(event.EVENT, event.TX.HUNTER_FORCE_FUGITIVE, { playerID })
    end

    function scenario.HunterStop()
        TX._send(event.EVENT, event.TX.HUNTER_STOP)
    end

    ---@param clientEvent string
    ---@param data any
    function scenario.InfectedUpdate(clientEvent, data)
        TX._send(event.EVENT, event.TX.INFECTED_UPDATE, { clientEvent, data })
    end

    ---@param playerID integer
    function scenario.InfectedForceInfected(playerID)
        TX._send(event.EVENT, event.TX.INFECTED_FORCE_INFECTED, { playerID })
    end

    function scenario.InfectedStop()
        TX._send(event.EVENT, event.TX.INFECTED_STOP)
    end

    ---@param arenas table[]
    ---@param callback fun(boolean)
    function scenario.DerbySave(arenas, callback)
        BJI_Rx_SCENARIO.derbySaveCallback(callback)
        TX._send(event.EVENT, event.TX.DERBY_SAVE, { arenas })
    end

    function scenario.DerbyUpdate(clientEvent, data)
        TX._send(event.EVENT, event.TX.DERBY_UPDATE, { clientEvent, data })
    end

    function scenario.DerbyStop()
        TX._send(event.EVENT, event.TX.DERBY_STOP)
    end

    ---@param lobbyId integer?
    ---@param gameVehID integer
    function scenario.TagDuoJoin(lobbyId, gameVehID)
        TX._send(event.EVENT, event.TX.TAG_DUO_JOIN, { lobbyId, gameVehID })
    end

    ---@param lobbyId integer
    ---@param clientEvent string
    function scenario.TagDuoUpdate(lobbyId, clientEvent)
        TX._send(event.EVENT, event.TX.TAG_DUO_UPDATE, { lobbyId, clientEvent })
    end

    function scenario.TagDuoLeave()
        TX._send(event.EVENT, event.TX.TAG_DUO_LEAVE)
    end

    ---@param data BJPursuitPayload
    function scenario.PursuitData(data)
        TX._send(event.EVENT, event.TX.PURSUIT_DATA, data)
    end

    ---@param isArrest boolean
    function scenario.PursuitReward(isArrest)
        TX._send(event.EVENT, event.TX.PURSUIT_REWARD, { isArrest })
    end

    return scenario
end
