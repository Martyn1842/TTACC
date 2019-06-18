local graph = {}
setmetatable(graph, graph)
-- graph.__index = graph

function graph:new() --Returns a new graph
    local newGraph = setmetatable({}, graph)
    return newGraph
end

function graph:copy(seen) --Returns a copy of a graph
    if type(self) ~= "table" then return self end
    if seen and seen[self] then return seen[self] end
    seen = seen or {}
    local newGraph = setmetatable({}, getmetatable(self))
    seen[self] = new
    for k, v in pairs(self) do
        newGraph[graph.copy(k, seen)] = graph.copy(v, seen)
    end
    return newGraph
end

function graph:print() --Prints graph, order undefined
    for k, v in pairs(self) do
        if type(v) == "table" and v[1] then
            local s = k..": "..tostring(v[1])
            for i = 2, #v do s = s..", "..tostring(v[i]) end
            print(s)
        else
            print(k..": <NO EDGES>")
        end
        if self[k].info then print("Info: "..self[k].info) end
    end
end

function graph:printFrom(startVertex) --Prints graph, starting from startVertex
    if not startVertex then return self:print() end --No start point, default to unordered
    local printed, run = {}
    run = function(self, vertex)
        if not self[vertex] then
            print("vertex \""..vertex.."\" does not exist") return
        end
        if printed[vertex] then return end --If already printed, stop
        local s = vertex..": "
        if self[vertex][1] then --If vertex has edges
            s = s..self[vertex][1]
            for i = 2, #self[vertex] do
                s = s..", "..self[vertex][i]
            end
        else
            s = s.."<NO EDGES>"
        end
        print(s)
        if self[vertex].info then print("Info: "..self[vertex].info) end
        printed[vertex] = true
        for i = 1, #self[vertex] do run(self, self[vertex][i]) end
    end
    return run(self, startVertex)
end

function graph:addVertex(vertex, neighbours) --Create vertex with optional directional edges
    if self[vertex] then return false end
    self[vertex] = {}
    neighbours = (type(neighbours) == "table" and neighbours or {neighbours}) or {}
    for i = 1, #neighbours do self:addEdge(vertex, neighbours[i]) end
    return true
end

function graph:addUniqueVertex(vertex, neighbours) --Adds a unique vertex with optional neighbours,
    local i=1                                      --returning the name of the vertex created
    if vertex then --Vertex name specified
        vertex = tostring(vertex)
        if self[vertex] then --"vertex" is not unique,
            --add vertex "vertex:N" where N is number of vertices "vertex"+1
            while self[vertex..":"..i] do i=i+1 end
            i = vertex..":"..i
        else --"vertex" is unique, simply add it
            i = vertex
        end
    else --Add numeric vertex "N" where N is number of numeric vertices+1
        while self[i] do i=i+1 end
    end
    self:addVertex(i, neighbours)
    return i
end

function graph:removeVertex(vertex) --Remove vertex and all references to it
    if self[vertex] then
        self[vertex] = nil
        for vertex2, neighbours in pairs(self) do --For each vertex
            for i = #neighbours, 1, -1 do --For each neighbour
                if neighbours[i] == vertex then table.remove(self[vertex2], i) end
            end
        end
    end
    return true
end

function graph:addEdge(vertex, vertex2) --Add directional edge from vertex to vertex2
    if self[vertex] and self[vertex2] then
        table.insert(self[vertex], vertex2)
        return true
    end
end

function graph:removeEdge(vertex, vertex2) --Remove one edge from vertex to vertex2
    if not (self[vertex] and self[vertex2]) then return end
    for i = 1, #self[vertex] do
        if self[vertex][i] == vertex2 then
            table.remove(self[vertex], i)
            return true
        end
    end
end

function graph:removeAllEdges(vertex)
    if self[vertex] then
        self[vertex] = {}
        return true
    end
end

function graph:isAdjacent(vertex, vertex2) --Returns true if vertex2 is adjacent to vertex
    if not (self[vertex] and self[vertex2]) then return end
    for i = 1, #self[vertex] do
        if self[vertex][i] == vertex2 then return true end
    end
    return false
end

function graph:setInfo(vertex, info) --Sets "info" field of vertex
    if self[vertex] then
        self[vertex].info = info
        return true
    end
end

function graph:getInfo(vertex) --Returns "info" field of vertex
    if self[vertex] then
        return self[vertex].info
    end
end

function graph:disjointUnion(graph2) --Returns the disjoint union with graph2
    if getmetatable(graph2) ~= getmetatable(self) then
        error("attempt to combine a non-graph \""..tostring(graph2).."\" with a graph", 2)
    end
    local newGraph = self:copy()
    for k, v in pairs(graph2) do
        local n = newGraph:addUniqueVertex(k, v)
        newGraph:setInfo(n==0 and k or k..":"..n, graph2:getInfo(k))
    end
end

return graph