local ctrl = {}

local function require(ctxt)
    BJCCache.getCache(ctxt, ctxt.data[1])
end

ctrl.require = require

return ctrl
