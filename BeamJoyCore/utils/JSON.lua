local _Util = Util

local json = {}

function json.stringify(obj)
    --return _Util.JsonPrettify(_Util.JsonEncode(obj))
    -- FALLBACK https://github.com/BeamMP/BeamMP/issues/578
    return require("utils/JSONold").stringify(obj)
end

function json.stringifyRaw(obj)
    --return _Util.JsonEncode(obj)
    -- FALLBACK https://github.com/BeamMP/BeamMP/issues/578
    return require("utils/JSONold").stringifyRaw(obj)
end

function json.parse(str)
    return _Util.JsonDecode(str)
end

return json
