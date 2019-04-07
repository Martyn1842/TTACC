------------------------------------
-- Architecture specification definition and component prototypes

-- Each component has:
-- -Number of write addresses (writeN >=0)
-- -Number of read addresses (readN >=0)
-- -Memory (memory =bool)
-- -Data pass-through latency (passThrough >=1)
-- -Min write delay (minWDelay >=1)
-- -(Write address start (write >=0 or nil if no write) )
-- -(Read address start (read >= 0 or nil if no read) )
local component = {}

component.register = {
			["writeN"] = 1,
			["readN"] = 1,
			["memory"] = true,
			["passThrough"] = 4,
			["minWDelay"] = 2,}

component.RAM = {
		["writeN"] = 2,
		["readN"] = 2,
		["memory"] = true,
		["passThrough"] = 5,
		["minWDelay"] = 2,}

component.func = {
		["writeN"] = 1,
		["readN"] = 1,
		["memory"] = false,
		["passThrough"] = 5,
		["minWDelay"] = 1,}
		

		
local specification = {}
specification.write = 0 --Next free write address
specification.read = 0 --Next free read address
specification.new = function(objTyp, ...) --Create and assign new
	if not objTyp or not component[objTyp] then
		abort("invalid objTyp in specification")
	end
	local newObj = {}
	setmetatable(newObj, component[objTyp])
	component[objTyp]["__index"] = component[objTyp]
	if objTyp == "func" then --(function: writeN, readN, passThrough)
		newObj.writeN = (select(1, ...)) or newObj.writeN
		newObj.readN = (select(2, ...)) or newObj.readN
		newObj.passThrough = (select(3, ...)) or newObj.passThrough
	end
	if newObj.writeN == 0 and newObj.readN == 0 then
		abort("no means of interface with component in specification")
	end
	if newObj.writeN > 0 then --Assign write addresses
		newObj.write = specification.write
		specification.write = specification.write + newObj.writeN
		if specification.write > 32 then
			abort("exceeded max address for write")
		end
	end
	if newObj.readN > 0 then --Assign read addresses
		newObj.read = specification.read
		specification.read = specification.read + newObj.readN
		if specification.read > 32 then
			abort("exceeded max address for read")
		end
	end
	return newObj
	end
		
return specification