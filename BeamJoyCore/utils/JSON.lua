local json = {}

function json.stringify(obj)
    --return Util.JsonPrettify(_Util.JsonEncode(obj))
    -- FALLBACK https://github.com/BeamMP/BeamMP/issues/578
    if obj == nil then
        return nil
    end
    return require("utils/JSONold").stringify(obj, nil, true)
end

function json.stringifyRaw(obj)
    --return Util.JsonEncode(obj)
    -- FALLBACK https://github.com/BeamMP/BeamMP/issues/578
    if obj == nil then
        return nil
    end
    return require("utils/JSONold").stringify(obj)
end

function json.parse(str)
    if type(str) ~= "string" or #str == 0 then
        LogWarn("Tried to parse empty or not string value")
        return nil
    end
    -- return Util.JsonDecode(str)
    -- FALLBACK https://github.com/BeamMP/BeamMP-Server/issues/348#issuecomment-2999621760
    return require("utils/JSONold").parse(str)
end

return json
