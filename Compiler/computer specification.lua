------------------------------------
-- Computer specification

-- Each component has:
-- -Number of write addresses (writeN >=0)
-- -Number of read addresses (readN >=0)
-- -Memory (memory =bool)
-- -Data pass-through latency (passThrough >=1)
-- -Min write delay (minWDelay >=1)
-- -(Write address start (write >=0 or nil if no write) )
-- -(Read address start (read >= 0 or nil if no read) )

--Defaults are defined in architecture specification

local mt = {}
mt.__index = mt
mt.__newindex = function(t, k ,v)
    if symTab[k] then abort("Symbol \""..k.."\" has already been defined") end
    mt[k] = v
end
local specification = setmetatable({}, mt)
local new = function(objType, name, ...)
    specification[name] = component.new(objType, ...)
    symTab[name] = mt[name]
    symTab.__type[name] = objType
end


------------------------------------
-- Start computer specification

specification.dataLanes = 6
new("register", "R1")
new("register", "R2")
new("register", "R3")
new("register", "R4")
new("register", "R5")
new("register", "R6")
new("register", "R7")
new("func", "NEG")

------------------------------------
-- End computer specification

return specification