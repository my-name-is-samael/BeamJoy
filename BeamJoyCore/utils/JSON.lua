local json = {}

function json.stringify(obj)
    --return Util.JsonPrettify(_Util.JsonEncode(obj))
    -- FALLBACK https://github.com/BeamMP/BeamMP/issues/578
    return require("utils/JSONold").stringify(obj)
end

function json.stringifyRaw(obj)
    --return Util.JsonEncode(obj)
    -- FALLBACK https://github.com/BeamMP/BeamMP/issues/578
    return require("utils/JSONold").stringifyRaw(obj)
end

function json.parse(str)
    if type(str) ~= "string" or #str == 0 then
        LogWarn("Tried to parse empty or not string value")
        return nil
    end
    return Util.JsonDecode(str)
end

return json
