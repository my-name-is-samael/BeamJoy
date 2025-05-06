local ctrl = {}

local function require(ctxt)
    Table(ctxt.data):forEach(function(cacheType)
        BJCCache.getCache(ctxt, cacheType)
    end)
end

ctrl.require = require

return ctrl
