-- Chat instability server crash workaround (https://github.com/BeamMP/BeamMP-Server/issues/435)

function BJCH_OnChatMessage(...)
    MP.TriggerGlobalEvent("onBJCChatMessage", ...)
    return 1
end

function _G.onInit() ---@diagnostic disable-line
    MP.RegisterEvent("onChatMessage", "BJCH_OnChatMessage")
end