local frame = require("lib.frame")
local private = {}
local hardware = setmetatable({}, private)


private.dataLanes = 6 -- Default is 6, can be changed before addresses are assigned

function hardware:addModule(name, write_addresses, read_addresses, has_memory)
    if write_addresses < 1 and read_addresses < 1 then
        compilerError("attempted to add a module with no addresses to interact with")
    end
    has_memory = has_memory or false

    local addressStart = #private.address
    private.addressMap[name] = {addressStart+1, write_addresses, read_addresses, has_memory}
    for i = 1, write_addresses do
        private.address[addressStart+i] = {'w', name}
    end
    for i = 1, read_addresses do
        private.address[addressStart+write_addresses+i] = {'r', name}
    end
end

function hardware:REGISTER(name)
    self:addModule(name, 1, 1, true)
end

function hardware:RAM(name)
    self:addModule(name, 3, 1, true)
end

-- Add circuit frame "lit" to the literal pool, returns the index used
function hardware:addLiteral(lit)
    if type(lit) == "string" then -- If literal is directly parsed string input, transform to table
        -- Add return and ['_____'] around keys for load
        lit = "return "..string.gsub(lit, "([%w-]+)[   ]*=", "['%1']=")
        -- Load string and keep returned table
        lit = frame:new( assert(load(lit))() )
    end
    if type(lit) ~= "table" then error("could not process "..tostring(lit).." into literal", 2) end
    for i = 1, #private.literal do -- Search for equivalent defined literal
        if lit == private.literal[i] then
            return i -- Found equivalent literal, return its index
        end
    end
    local index = #private.literal+1
    private.literal[index] = lit
    return index
end


private.literal = {}
private.address = {}
private.addressMap = {}
private.__index = private
private.__newindex = function(t, k, v)
    if k == "dataLanes" and #private.address > 0 then
        compilerError("attempted to change the number of data lanes after addresses assigned")
    else
        private[k] = v
    end
end

return hardware