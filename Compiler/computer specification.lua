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

local specification = {}

specification.dataLanes = 6
specification.R1 = component.new("register")
specification.R2 = component.new("register")
specification.R3 = component.new("register")
specification.R4 = component.new("register")
specification.R4 = component.new("register")
specification.R5 = component.new("register")
specification.R6 = component.new("register")
specification.NEG = component.new("func")

return specification