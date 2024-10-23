local ctrl = {
    tag = "BJIPlayerController"
}

function ctrl.tick(data)
    BJITick.server(data)
end

function ctrl.toast(data)
    local type, msg, delay = data[1], data[2], tonumber(data[3])
    BJIToast.toast(type, msg, delay)
end

function ctrl.flash(data)
    local msg, delay = data[1], tonumber(data[2])
    BJIMessage.flash(msg, msg, delay, false)
end

local firstMessagesOffset = 0
function ctrl.chat(data)
    local event, chatData = data[1], data[2]
    chatData.color = chatData.color and RGBA(chatData.color[1], chatData.color[2], chatData.color[3], chatData.color[4]) or
        nil

    if BJIContext.WorldReadyState ~= 2 then
        -- first message
        BJIAsync.task(function()
            return BJIContext.WorldReadyState == 2
        end, function()
            BJIAsync.delayTask(function()
                    BJIChat.onChat(event, chatData)
                end, 3000 + firstMessagesOffset,
                svar("BJIChatReadyDelay{1}", { GetCurrentTimeMillis() }))
            firstMessagesOffset = firstMessagesOffset + 10
        end, "BJIChatReadyWorld")
    else
        BJIChat.onChat(event, chatData)
    end
end

function ctrl.teleportToPlayer(data)
    local targetID = data[1]
    BJIScenario.tryTeleportToPlayer(targetID, true)
end

function ctrl.teleportToPos(data)
    local pos = data[1]
    BJIVeh.setPositionRotation(pos)
end

function ctrl.explodeVehicle(data)
    local gameVehID = data[1]
    BJIVeh.explodeVehicle(gameVehID)
end

return ctrl
