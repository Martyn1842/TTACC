--A library for representing and operating on Factorio combinator circuit frames
--Requires a dictionary of valid signalIDs

--When all signals in a frame are to have the same value,
--  use a frame with default value set to the desired value, instead of explicitly setting all values
--If extending this library,
--  code which overwrites a signal value with one that may have changed should use function "int32(value)",
--  this is to ensure proper formatting and bounding of the value


local signalIDs = require("lib.signalIDs")
local totalSignals = signalIDs[2]
signalIDs = signalIDs[1]

local int32 = function(n)
    if tonumber(n) then --If tonumber can directly convert (number, string decimal, string hexadecimal)
        n = tonumber(n)
    elseif string.find(n, "^-?0[bB]") then --If binary string
        if string.find(n, "^-") then --If negative
            n = -tonumber(string.sub(n, 4), 2)
        else
            n = tonumber(string.sub(n, 3), 2)
        end
    else --n is not recognised as valid input
        error("could not convert \""..n.."\" to int32", 2)
    end
    local overflow = n < -2^31 or n >= 2^32 --Does n exceed signed int32 limits?
    n = overflow and n % 2^32 or n --Cut down to 32 bits
    if n >= 2^31 then
        n = n - 2^32 --Positive limit exceeded, roll to negative
    elseif n < -2^31 then
        n = n + 2^32 --Negative limit exceeded, roll to positive
    end
    return (math.modf(n)), overflow --math.modf is just for formatting
end

local values = setmetatable({}, {__mode="k"})
local default = setmetatable({}, {__mode="k"})
local frame = {}
setmetatable(frame, frame)

function frame:getDefault() --Returns the value of a frame's unset signals
    return default[self]
end

function frame:setDefault(value) --Sets the value of a frame's unset signals
    default[self] = int32(value) or 0
end

function frame:new(init) --Returns a new frame, inititalised with optional table or,
    --"dict" to create integer dictionary or,
    --number to set all signals to that value
    local newFrame = setmetatable({}, getmetatable(self))
    values[newFrame] = {}
    default[newFrame] = 0
    if init then
        if type(init) == "table" then --init is table,
            for k, v in pairs(init) do --copy its values
                values[newFrame][k] = v
            end
        elseif init == "dict" then --init is "dict",
            for k, v in pairs(signalIDs) do --copy signal dictionary
                values[newFrame][k] = v
            end
        else --init should be used to set default value
            default[newFrame] = int32(init)
        end
    end
    return newFrame
end

function frame:copy() --Returns a copy of a frame
    local newFrame = setmetatable({}, getmetatable(self))
    default[newFrame] = default[self]
    values[newFrame] = {}
    for k, v in pairs(values[self]) do
        values[newFrame][k] = v
    end
    return newFrame
end

function frame:add(f2) --Adds f2 to frame
    if getmetatable(f2) ~= getmetatable(self) then
        error("attempt to add a non-frame \""..tostring(f2).."\" to a frame", 2)
    end
    local newFrame = frame:new(default[self]+default[f2])
    for k, v in pairs(values[self]) do --For each set value of self,
        newFrame[k] = v + (values[f2][k] or default[f2]) --add value or default of f2
    end
    for k, v in pairs(values[f2]) do --For each set value of f2 unset in newFrame,
        newFrame[k] = values[newFrame][k] or (v + default[self]) --add it to default of self
    end
    return newFrame
end
frame.__add = frame.add

function frame:sub(f2) --Subtracts f2 from frame
    if getmetatable(f2) ~= getmetatable(self) then
        error("attempt to subtract a non-frame \""..tostring(f2).."\" from a frame", 2)
    end
    local newFrame = frame:new(default[self]-default[f2])
    for k, v in pairs(values[self]) do --For each set value of self,
        newFrame[k] = v - (values[f2][k] or default[f2]) --sub value or default of f2
    end
    for k, v in pairs(values[f2]) do --For each set value of f2 unset in newFrame,
        newFrame[k] = values[newFrame][k] or (default[self] - v) --sub it from default of self
    end
    return newFrame
end
frame.__sub = frame.sub

function frame:neg() --Negates the values of frame
    local newFrame = frame:new(-default[self])
    for k, v in pairs(values[self]) do
        newFrame[k] = -v
    end
    return newFrame
end
frame.__unm = frame.neg

function frame:mul(f2) --Elementwise multiplication of frame and f2
    if getmetatable(f2) ~= getmetatable(self) then
        error("attempt to multiply a non-frame \""..tostring(f2).."\" with a frame", 2)
    end
    local newFrame = frame:new(default[self] * default[f2])
    for k, v in pairs(values[self]) do --For each set value of self,
        newFrame[k] = v * (values[f2][k] or default[f2]) --mul by value or default of f2
    end
    for k, v in pairs(values[f2]) do --For each set value of f2 unset in newFrame,
        newFrame[k] = values[newFrame][k] or (v * default[self]) --mul by default of self
    end
    return newFrame
end
frame.__mul = frame.mul

function frame:sum(signal) --Returns the sum of elements of frame as type "signal"
    signal = signal or "signal-dot"
    local total = totalSignals * default[self]
    for _, v in pairs(values[self]) do
        total = total + v - default[self]
    end
    return frame:new({ [signal]=total })
end

function frame:eq(f2) --Returns true if frame == f2
    if getmetatable(f2) ~= getmetatable(self) then
        error("attempt to compare a non-frame \""..tostring(f2).."\" with a frame", 2)
    end
    for k, v in pairs(values[self]) do
        if v ~= values[f2][k] then return false end
    end
    for k, v in pairs(values[f2]) do
        if v ~= values[self][k] then return false end
    end
    return true
end
frame.__eq = frame.eq

function frame:tostring()
    local map = {}
    local s = "DEFAULT: "..default[self]
    for k, _ in pairs(values[self]) do
        table.insert(map, k)
    end
    if #map > 0 then
        table.sort(map)
        for i = 1, #map do
            s = s.."\n"..map[i]..": "..values[self][map[i]]
        end
    end
    return s
end
frame.__tostring = frame.tostring

function frame:print()
    if vPrint then
        vPrint(self:tostring())
    else
        print(self)
    end
end

frame.__index = function(t, k)
    -- print(tostring(t)..": "..k)
    if signalIDs[k] then
        return values[t][k] or default[t]
    else
        return getmetatable(t)[k] or error("attempted to read invalid signalID \""..k.."\"", 2)
    end
end
frame.__newindex = function(t, k, v)
    if signalIDs[k] then
        local vI, overflow = int32(v)
        if overflow and warning then
            warning("Integer overflow occurred! \""..k.."\": "..v.." -> "..vI)
        end
        values[t][k] = vI == default[t] and nil or vI
    else
        error("attempted to set invalid signalID \""..k.."\"", 2)
    end
end

return frame