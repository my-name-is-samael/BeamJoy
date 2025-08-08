playerInfo = playerInfo or {}
obj = obj or {}

local M = {}

local counter = 0
local physstart = 0
local physmult = 1

local function update(dtSim)
	if counter == 0 then
		physstart = os.clock()
	end
	counter = counter + 1
	if counter == 2000 then
		counter = 0
		local physend = os.clock()
		local physdiff = physend - physstart
		if playerInfo.firstPlayerSeated then
			physmult = 1 / physdiff
            obj:queueGameEngineLua("BJI.setPhysicsSpeed("..physmult..")")
		end
	end
end

M.update = update

return M
