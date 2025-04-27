local function _baseSoundsPath(filename)
    return string.var("/art/sound/{1}.ogg", { filename })
end

local M = {
    _name = "BJISound",
    SOUNDS = {
        LEVEL_UP = _baseSoundsPath("levelup"),
        NAV_CHANGE = _baseSoundsPath("nav_change"),
        RACE_COUNTDOWN = _baseSoundsPath("race_countdown"),
        RACE_START = _baseSoundsPath("race_start"),
        RACE_WAYPOINT = _baseSoundsPath("race_waypoint"),
    }
}

local function addSound(name, filePath)
    M.SOUNDS[name] = filePath
end

local function play(sound)
    if not table.includes(M.SOUNDS, sound) then
        LogError(string.var("Unknown sound \"{1}\"", { sound }))
    end

    Engine.Audio.playOnce('AudioGui', sound)
end

M.addSound = addSound
M.play = play

RegisterBJIManager(M)
return M
