local multiset = {}

function multiset:new() --Returns a new multiset
    local newSet = setmetatable({}, self)
    self.__index = self
    return newSet
end

function multiset:copy(seen) --Returns a copy of a multiset
    if type(self) ~= "table" then return self end
    if seen and seen[self] then return seen[self] end
    seen = seen or {}
    local newSet = setmetatable({}, getmetatable(self))
    seen[self] = newSet
    for k, v in pairs(self) do
        newSet[multiset.copy(k, seen)] = multiset.copy(v, seen)
    end
    return newSet
end

function multiset:cardinality()
    local result = 0
    for _, v in pairs(self) do result = result + v end
    return result
end

function multiset:subset(s2) --Returns true if set is subset of (or equal to) s2
    if type(s2) ~= "table" then return false end
    for k, v in pairs(self) do
        if not s2[k] or v > s2[k] then return false end
    end
    return true
end

function multiset:equal(s2)
    if type(s2) ~= "table" or not self:subset(s2) then
        return false
    end
    return self.subset(s2, self)
end

function multiset:union(s2) --Returns union of set and s2
    local result = setmetatable({}, getmetatable(self))
    for k, v in pairs(self) do
        result[k] = math.max(v, s2[k] or v)
    end
    for k, v in pairs(s2) do
        result[k] = result[k] or v
    end
    return result
end

function multiset:sum(s2) --Returns sum of self and s2
    local result = setmetatable({}, getmetatable(self))
    for k, v in pairs(self) do
        result[k] = v + (s2[k] or 0)
    end
    for k, v in pairs(s2) do
        result[k] = result[k] or v
    end
    return result
end

function multiset:print()
    local map = {}
	for k in pairs(self) do table.insert(map, k) end
	table.sort(map, function(a, b) return self[a] < self[b] end)
	for _, k in ipairs(map) do print(k..": "..self[k]) end
end

return multiset