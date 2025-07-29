--- Checks if the server version is greater than or equal to the given version
---@param major integer
---@param minor integer?
---@param patch integer?
---@return boolean
function CheckServerVersion(major, minor, patch)
    minor = minor or 0
    patch = patch or 0
    local srvMajor, srvMinor, srvPatch = MP.GetServerVersion()
    if srvMajor ~= major then
        return major < srvMajor
    end
    if srvMinor ~= minor then
        return minor < srvMinor
    end
    return patch <= srvPatch
end
