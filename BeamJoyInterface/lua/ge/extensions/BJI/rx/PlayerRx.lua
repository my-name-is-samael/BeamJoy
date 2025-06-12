local ctrl = {
    tag = "PlayerRx"
}

function ctrl.tick(data)
    BJI.Managers.Tick.server(data)
end

function ctrl.toast(data)
    local type, msg, delay = data[1], data[2], tonumber(data[3])
    BJI.Managers.Toast.toast(type, msg, delay)
end

function ctrl.flash(data)
    local msg, delay = data[1], tonumber(data[2])
    BJI.Managers.Message.flash(msg, msg, delay, false)
end

function ctrl.chat(data)
    local event, chatData = data[1], data[2]
    BJI.Managers.Chat.onChat(event, chatData)
end

function ctrl.teleportToPlayer(data)
    local targetID = data[1]
    BJI.Managers.Scenario.tryTeleportToPlayer(targetID, true)
end

function ctrl.teleportToPos(data)
    local pos = vec3(data[1])
    BJI.Managers.Veh.setPositionRotation(pos)
end

function ctrl.explodeVehicle(data)
    local gameVehID = data[1]
    BJI.Managers.Veh.explodeVehicle(gameVehID)
end

function ctrl.syncPaint(data)
    ---@type integer, integer, NGPaint
    local vid, paintIndex, paintData = data[1], data[2], data[3]
    local veh = BJI.Managers.Veh.getVehicleObject(vid)
    if veh and not BJI.Managers.Veh.isVehicleOwn(vid) then
        BJI.Managers.Veh.paintVehicle(veh, paintIndex, paintData)
    end
end

return ctrl
