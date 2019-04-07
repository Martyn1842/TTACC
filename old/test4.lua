------------------------------------
-- Graph object prototype

graph = {
	-- Create vertex with optional edges (directional)
	addVertex	= function(self, vertex, neighbours)
		if self[vertex] then return false end
		self[vertex] = {}
		neighbours = (type(neighbours) == "table" and neighbours or {neighbours}) or {}
		for i = 1, #neighbours do self:addEdge(vertex, neighbours[i]) end
		return true
	end,
	-- If vertex then add vertex "vertex:N" where N is number of vertices "vertex"+1
	-- Else add vertex "N" where N is number of numeric vertices+1
	addUniqueVertex = function(self, vertex, neighbours)
		local i=1
		if vertex then
			while self[vertex..":"..i] do i=i+1 end
			self:addVertex(vertex..":"..i, neighbours)
		else
			while self[i] do i=i+1 end
			self:addVertex(i, neighbours)
		end
		return i
	end,
	-- Remove vertex and all references to it in graph
	removeVertex = function(self, vertex)
		if self[vertex] then
			self[vertex] = nil
			for vertex2, neighbours in pairs(self) do --For each vertex
				for i = #neighbours, 1, -1 do --For each neighbour
					if neighbours[i] == vertex then table.remove(self[vertex2], i) end
				end
			end
			return true
		end
	end,
	-- Add edge from vertex to vertex2 (directional),
	-- multiple such edges can exist simultaneously
	addEdge = function(self, vertex, vertex2)
		if self[vertex] and self[vertex2] then
			table.insert(self[vertex], vertex2)
			return true
		end
	end,
	-- Removes one instance of edge from vertex to vertex2 (directional)
	removeEdge = function(self, vertex, vertex2)
		if self[vertex] and self[vertex2] then
			for i = 1, #self[vertex] do
				if self[vertex][i] == vertex2 then
					table.remove(self[vertex], i) return true
				end
			end
		end
	end,
	removeAllEdges = function(self, vertex)
		if self[vertex] then self[vertex] = {} return true end
	end,
	-- Returns true if vertex2 is adjacent to vertex (directional)
	isAdjacent = function(self, vertex, vertex2)
		if self[vertex] and self[vertex2] then
			for i = 1, #self[vertex] do
				if self[vertex][i] == vertex2 then return true end
			end
		end
		return false
	end,
	setVertexInfo = function(self, vertex, info) --Sets "info" field of vertex
		if self[vertex] then
			self[vertex]["info"] = info
			return true
		end
	end,
	getVertexInfo = function(self, vertex) --Returns "info" field of vertex
		if self[vertex] then
			return self[vertex]["info"]
		end
	end,
	-- Returns "info" field of vertex's n-th neighbour
	getNeighbourInfo = function(self, vertex, n)
		if self[vertex] and self[vertex][n] then
			return self[ self[vertex][n] ].info
		end
	end,
	new		= function(self) --Returns a new graph
		local newGraph = {}
		setmetatable(newGraph, self)
		self.__index = self
		return newGraph
	end,
	copy	= function(self, seen)
		if type(self) ~= "table" then return self end
		if seen and seen[self] then return seen[self] end
		seen = seen or {}
		local new = setmetatable({}, getmetatable(self))
		seen[self] = new
		for k, v in pairs(self) do
			new[graph.copy(k, seen)] = graph.copy(v, seen)
		end
		return new
	end,
	printX	= function(self) --Randomly prints whole graph
		for k, v in pairs(self) do
			if type(v) == "table" and v[1] then
				local s = k..": "..tostring(v[1])
				for i = 2, #v do s = s..", "..tostring(v[i]) end
				print(s)
				--if v.info then print("Info: "..v.info) end
			else
				print(k..": <NO EDGES>")
			end
			if self[k].info then print("Info: "..self[k].info) end
		end
	end,
	print	= function(self, startVertex) --Prints graph ordered from vertex
		local printed, run = {}
		run = function(self, vertex)
			if not vertex then return self:printX() end --No start point, random instead
			if not self[vertex] then
				print("vertex \""..vertex.."\" does not exist") return
			end
			if printed[vertex] then return end --If already printed stop
			if self[vertex][1] then --If vertex has edges
				local s = vertex..": "..self[vertex][1]
				for i = 2, #self[vertex] do
					s = s..", "..self[vertex][i]
				end
				print(s) --Print vertex's edges
				if self[vertex]["info"] then print("Info: "..self[vertex]["info"]) end
				printed[vertex] = true
				for i = 1, #self[vertex] do
					run(self, self[vertex][i])
				end
			elseif not printed[vertex] then --If vertex has no edges
				print(vertex..": <NO EDGES>")
				if self[vertex]["info"] then print("Info: "..self[vertex]["info"]) end
				printed[vertex] = true
			end
		end
		run(self, startVertex)
	end
}

------------------------------------
-- Multiset object prototype

multiset = {
	new		= function(self) --Returns a new multiset
		local newSet = setmetatable({}, self)
		self.__index = self
		return newSet
	end,
	copy	= function(self, seen)
		if type(self) ~= "table" then return self end
		if seen and seen[self] then return seen[self] end
		seen = seen or {}
		local new = setmetatable({}, getmetatable(self))
		seen[self] = new
		for k, v in pairs(self) do
			new[multiset.copy(k, seen)] = multiset.copy(v, seen)
		end
		return new
	end,
	cardinality = function(self)
		local result = 0
		for _, v in pairs(self) do result = result + v end
		return result
	end,
	subset	= function(self, s2) --Returns true if set is subset of (or equal to) s2
		if type(s2) ~= "table" then return false end
		for k, v in pairs(self) do
			if not s2[k] or v > s2[k] then return false end
		end
		return true
	end,
	equal	= function(self, s2)
		if type(s2) ~= "table" then return false end
		if not self:subset(s2) then return false end
		return self.subset(s2, self)
	end,
	union	= function(self, s2) --Returns union of self and s2
		local result = setmetatable({}, getmetatable(self))
		for k, v in pairs(self) do
			result[k] = math.max(v, s2[k] or v)
		end
		for k, v in pairs(s2) do
			result[k] = result[k] and result[k] or math.max(v, self[k] or v)
		end
		return result
	end,
	sum		= function(self, s2) --Returns sum of self and s2
		local result = setmetatable({}, getmetatable(self))
		for k, v in pairs(self) do
			result[k] = v + (s2[k] or 0)
		end
		for k, v in pairs(s2) do
			result[k] = result[k] and result[k] or v + (self[k] or 0)
		end
		return result
	end,
	print	= function(self)
		local flatten = function(s)
			local flatTable, fetch = {}, 0
			local fetch = function(s)
				for _, v in pairs(s) do
					if type(v) == "table" then fetch(v)
					else table.insert(flatTable, v) end
				end
			end
			fetch(s)
			return flatTable
		end
		local map = {}
		for k in pairs(self) do table.insert(map, k) end
		table.sort(map, function(a, b) return self[a] < self[b] end)
		for _, k in ipairs(map) do print(k..": "..self[k]) end
	end,
}

------------------------------------
-- Compile error reporting functions

local halt = function(s) --Print s and stop program
	io.output(stdout)
	s = s and "\n\n"..s or ""
	print(s.."\n\n".." Press Enter to close...")
	io.input(stdin)
	io.read()
	os.exit()
end
abort = function(s) --Print error message s and stop program
	local currLine = input and input.currLine or 0
	local sTrace = debug.traceback()
	sTrace = string.gsub(sTrace, directorySeparator.."[^%\n]+"..directorySeparator,
		directorySeparator.."..."..directorySeparator)
	halt("["..currLine.."] Error: "..s.."\n\n"..sTrace)
end

--Does not deal with looping tables
table.equal = 0
table.equal = function(t1, t2)
	if type(t1) ~= type(t2) then return false end
	if type(t1) ~= "table" then return t1 == t2 end
	for k, v1 in pairs(t1) do
		if not t2[k] then return false end
		if type(v1) == "table" then
			if not table.equal(v1, t2[k]) then return false end
		else
			if v1 ~= t2[k] then return false end
		end
	end
	for k, _ in pairs(t2) do
		if not t1[k] then return false end
	end
	return true
end

table.max = function(t)
	local result, ind
	for k, v in pairs(t) do
		if tonumber(v) then
			if result then
				result = result < v and v or result
				ind = result < v and k or ind
			else
				result, ind = v, k
			end
		end
	end
	return result, ind
end


--Scan arg for prefix and return next if found
local extraxtArg = function(prefix)
	for i = 1, #arg do
		if arg[i] == prefix then
			return arg[i+1]
		end
	end
end

--loads a package from a specified full directory path, caching requests
--if refetch is true contents of the cache will not be checked
local directRequire = function(target, refetch)
	__dRLoaded = __dRLoaded or {}
	if not refetch and __dRLoaded[target] then
		--print("fetched from cache: "..target.."\n")
		return __dRLoaded[target]()
	else
		local file, errMess = loadfile(target)
		if not file then abort(errMess) end
		__dRLoaded[target] = file
		--print("fetched from file: "..target.."\n")
		return file()
	end
end




------------------------------------
-- Lexical scanner

--Returns a new scanner object for s
local newScanner = function(s)
	local newScan = {cursorPos = 0, currLine = 1, s = s}
	--Returns next token in s, skipping WS and NL
	newScan.getNextToken = function(self, pat)
		local c --Capture
		--Skip WS
		_, self.cursorPos, c = string.find(self.s, "[ 	]*([^ 	])",
			self.cursorPos)
		if self.cursorPos == nil then return end
		if c == "\n" then --If c is a NL
			self.cursorPos=self.cursorPos+1
			self.currLine=self.currLine+1
			return self:getNextToken(pat)
		else
			-- match pattern pat else match not (WS or NL)
			local tokenStart = self.cursorPos
			_, self.cursorPos, c = string.find(self.s, pat or
				"([^ 	\n]+)", self.cursorPos)
			self.cursorPos = self.cursorPos and
				self.cursorPos+1 or tokenStart
			return c
		end
	end
	--Abort unless expected token s is next
	newScan.expect = function(self, s)
		if not self:getNextToken(--Escape any magic characters
			"^("..string.gsub(s, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")..")") then
			abort("expected \""..s.."\"")
		end
	end
	newScan.processStatement = function(self, token)
		if symTab[token] == nil then
			abort("token \""..token.."\" not recognised")
		elseif symTypes[token] == "register" then
			assignment(token)
		else
			symTab[token]()
		end
	end
	newScan.getStatement = function(self)
		-- print("getting statement") io.read()
		local token = self:getNextToken("^([_%a][_%w]*)")
		if token == nil then return end --halt(" === SCRIPT COMPLETE === ") end
		-- print("got token \""..token.."\"") io.read()
		self:processStatement(token)
		return true
	end
	return newScan	
end

------------------------------------
-- Expression parsing functions
local parse = {}
parse.factor = function()
	local uMinus = input:getNextToken("^(-)") and true or false
	local value = input:getNextToken("^([_%w]+)")
	if tonumber(value) then
		value = uMinus and math.modf(-value) or tonumber(value)
	elseif not symTypes[value] then
		abort("identifier \""..ident[1].."\" not recognised")
	else
		if symTypes[value] == "RAM" then --If factor is RAM address
			input:expect("[")
			local addr = parse.expression()
			input:expect("]")
			value = blockGen.readRAM(value, addr)
		elseif symTypes[value] == "reserved" then
			value = symTab[value]()
		end
	end
	return value
end
parse.term = function()
	local value = parse.factor()
	return value
end
parse.expression = function() --Returns terms in < order, numbers summed at head
	local value = {parse.term()}
	while true do
		local operator = input:getNextToken("^([+-])")
		if not operator then
			break
		elseif operator == "-" then
			local v = parse.term()
			if tonumber(v) then
				v = math.modf(-v)
				table.insert(value, v)
			else
			end
		else
			table.insert(value, parse.term())
		end
	end
	local nSum = 0
	for i = #value, 1, -1 do --Extract all numbers
		if type(value[i]) == "number" then
			nSum = nSum + value[i]
			table.remove(value, i)
		end
	end
	table.sort(value)
	if nSum ~= 0 then table.insert(value, 1, nSum) end
	return value
end

------------------------------------
-- Statement checking and processing functions


------------------------------------
--Construct AST (1)
--Scheduling:
---Set minimum timings (2)
---Group signals on each active tick (3)
---Assign data lanes (4)
---While there are scheduling conflicts: (5)
----Adjust timings (6)
----Regroup signals (7)
----Assign data lanes (8)

------------------------------------
-- First pass block generation functions (abstract syntax tree)

block = {}
blockGen = {
	["move"] = function(source, destination)
		for i = 1, #source do --For each source
			-- Check if it exists in "currVal"
			if not block[block.current]["currVal"][source[i]] then
				-- If new source: create it, add it to "currVal"
				local sourceV = block[block.current]:addUniqueVertex()
				block[block.current]:setVertexInfo(sourceV, source[i])
				block[block.current]["currVal"][source[i]] = sourceV
			else --Exists: unlink "return" from it
				while block[block.current]:removeEdge("return", 
					block[block.current]["currVal"][source[i]]) do end
			end
		end
		for i = 1, #destination do --For each destination
			if string.find(destination[i], "^RAM") then --If RAM
				local destV = block[block.current]["currVal"][destination[i]]
				local d = block[block.current]:addUniqueVertex()
				block[block.current]:addEdge(destV, d)
				for j = 1, #source do --Link to sources
					block[block.current]:addEdge(d,
							block[block.current]["currVal"][source[j]])
				end
			else --If not RAM
				-- Create new destination vertex, link "return" to it
				local destV = block[block.current]:addUniqueVertex()
				block[block.current]:setVertexInfo(destV, destination[i])
				block[block.current]:addEdge("return", destV)
				-- Update "currVal"
				block[block.current]["currVal"][destination[i]] = destV
				for j = 1, #source do --Link to sources
					block[block.current]:addEdge(destV,
							block[block.current]["currVal"][source[j]])
				end
			end
		end
	end,
	-- Neighbours: 1=address port, 2=data port
	["readRAM"] = function(RAM, addr)
		-- Check if it exists in "currVal"
		local checkS = RAM
		for i = 1, #addr do --Update addr sources
			if not block[block.current]["currVal"][addr[i]] then
				-- Addr source does not exist, create it
				local addrV = block[block.current]:addUniqueVertex()
				block[block.current]:setVertexInfo(addrV, addr[i])
				block[block.current]["currVal"][addr[i]] = addrV
			else --Exists: unlink "return" from it
				while block[block.current]:removeEdge("return",
						block[block.current]["currVal"][addr[i]]) do end
			end
			checkS = checkS..":"..block[block.current]["currVal"][addr[i]]
		end
		-- If exists: unlink "return" from it
		if block[block.current]["currVal"][checkS] then
			while block[block.current]:removeEdge("return",
					block[block.current]["currVal"][checkS]) do end
		else --New source, create and add to "currVal"
			local sourceV = block[block.current]:addUniqueVertex()
			block[block.current]:setVertexInfo(sourceV, checkS)
			block[block.current]["currVal"][checkS] = sourceV
			-- Create data and address vertices, and link
			local a = block[block.current]:addUniqueVertex()
			local d = block[block.current]:addUniqueVertex()
			block[block.current]:addEdge(sourceV, a)
			block[block.current]:addEdge(sourceV, d)
			for i = 1, #addr do --Link address to each addr source
				block[block.current]:addEdge(a, 
					block[block.current]["currVal"][addr[i]])
			end
		end
		return checkS
	end,
	["writeRAM"] = function(RAM, addr)
		-- Check if it exists in "currVal"
		local checkS = RAM
		for i = 1, #addr do --Update addr sources
			if not block[block.current]["currVal"][addr[i]] then
				-- Addr source does not exist, create it
				local addrV = block[block.current]:addUniqueVertex()
				block[block.current]:setVertexInfo(addrV, addr[i])
				block[block.current]["currVal"][addr[i]] = addrV
			else --Exists: unlink "return" from it
				while block[block.current]:removeEdge("return",
						block[block.current]["currVal"][addr[i]]) do end
			end
			checkS = checkS..":"..block[block.current]["currVal"][addr[i]]
		end
		-- Create new destination vertex, link "return" to it
		local destV = block[block.current]:addUniqueVertex()
		block[block.current]:setVertexInfo(destV, checkS)
		block[block.current]:addEdge("return", destV)
		-- Create data and address vertices, and link
		local a = block[block.current]:addUniqueVertex()
		-- local d = block[block.current]:addUniqueVertex()
		block[block.current]:addEdge(destV, a)
		-- block[block.current]:addEdge(destV, d)
		-- Update "currVal"
		block[block.current]["currVal"][checkS] = destV
		for i = 1, #addr do --Link to addr sources
			block[block.current]:addEdge(a,
						block[block.current]["currVal"][addr[i]])
		end
		return checkS
	end,
	newBlock = function(blockName)
		blockName = blockName or #block+1
		block[blockName] = graph:new()
		block[blockName]:addVertex("return")
		block[blockName]["currVal"] = {}
		return blockName
	end
}

------------------------------------
-- Second pass block generation functions (scheduling)

------------------------------------
--Set minimum timings (2)

--Product:
--{ 0={ 3={ 1,2 }, 4={ 1,2 } },  On tick 0, move from 1 and 2 to both 3 and 4
--  4={ 6={ 5 }, 8={ 4,5,7 } } } On tick 4, move from 5 to 6 and from 4, 5, and 7 to 8

block2 = {}
block2Gen = {
	run, --Forward declaration
	start = function(blockName)
		block2[blockName] = block[blockName]:copy() --Copy block graph
		block2[blockName].tick = {[0] = {}} --Create tick table
		--For each neighbour of "return"
		for i = 1, #block2[blockName]["return"] do
			block2Gen.run(blockName, block2[blockName]["return"][i], 0)
		end
	end,
	run = function(blockName, nVert, cTick)
		--print("run: "..nVert.." on tick "..cTick)
		--If no neighbours then stop
		if not block2[blockName][nVert][1] then return end
		--Create tick table if necessary
		block2[blockName]["tick"][cTick] = block2[blockName]["tick"][cTick] or {}
		--Add vertex and neighbours to tick table
		block2[blockName]["tick"][cTick][nVert] = {table.unpack(block2[blockName][nVert])}
		local nTick = cTick + specification[block2[blockName][nVert].info].passThrough
		for i = 1, #block2[blockName][nVert] do
			block2Gen.run(blockName, block2[blockName][nVert][i], nTick)
		end
	end
}

------------------------------------
--Group signals on each active tick (3)

--For each active tick:
---Determine usage number of each vertex (workSet)
---Create workSet mapping and sort
---Attempt to group destinations of vertices in descending usage order
---Pick vertex from mapping by pointer and attempt to group destinations:
----Find destinations of vertex
----Group destinations that source from same sets of vertices
----If grouping successful:
-----Decrement workSet appropriately
-----Re-sort mapping and reset pointer
----If unsuccessful:
-----Increment mapping pointer
---Stop when usage of vertex picked == 1


--Group column with row?
--		AB	C	ABC
--	AB	X	0	0
--	C	0	X	0
--	ABC	1	1	X
-->	(AB)(C)
-- ABx <= ABy and Cx <= Cy indicate they can each be grouped into ABC

--		AB	A	B
--	AB	X	1	1
--	A	0	X	0
--	B	0	0	X
-->	(A)(B)
-- Ax <= Ay and Bx <= By indicate they can each be grouped into AB

--		A	AB	AC
--	A	X	0	0
--	AB	1	X	0
--	AC	1	0	X
--> (A)(AB)(AC)
-- Ay > Ax indicates A would be over used if grouped

--		AA	AB	AC
--	AA	X	0	0
--	AB	0	X	0
--	AC	0	0	X
--> (AA)(AB)(AC)
-- No potential groupings found, however

--		A	A	AB	AC
--	A	X	X	0	0
--	A	X	X	0	0
--	AB	1	1	X	0
--	AC	1	1	0	X

block3 = {}
block3Gen = {
	run,
	start = function(blockName)
		block3[blockName] = block2[blockName]:copy() --Copy block graph
		--For each neighbour of "return"
		for cTick, signals in pairs(block3[blockName].tick) do
			print("tick "..cTick..":")
			block3[blockName].tick[cTick] = block3Gen.run(blockName, signals)
		end
	end,
	groupBySource = function(blockName, signals, workSet)
		printTable(signals, true)
		return signals
	end,
	groupByDest = function(blockName, signals, dest, workSet)
		printTable(signals, true)
		return signals
	end,
	run = function(blockName, signals)
		--Count number of tick movement sources and destinations, create workSet
		local source, dest, workSet = 0, 0, {}
		for _, s in pairs(signals) do
			dest = dest + 1
			for _, v in ipairs(s) do
				if not workSet[v] then
					workSet[v] = 1
					source = source + 1
				else
					workSet[v] = workSet[v] + 1
				end
			end
		end
		--print(source)
		--print(dest)
		print()
		printTable(signals, true)
		local map = {p=1}
		for k, _ in pairs(workSet) do
			map[map.p] = k
			map.p = map.p + 1
		end
		map.p = 1
		table.sort(map, function(a, b) return workSet[a] > workSet[b] end)
		--if source < dest then return block3Gen.groupBySource(blockName, signals, workSet)
		--else return block3Gen.groupByDest(blockName, signals, dest, workSet) end
		while workSet[map[map.p]] > 1 do
			--Pick most used vertex
			local vertex, destinations, nDestinations = map[map.p], {}, 0
			--Find destinations
			for k, v in pairs(signals) do
				for _, s in ipairs(v) do
					destinations[s] = vertex == s or destinations[s]
					nDestinations = vertex == s and nDestinations+1 or nDestinations
				end
			end
			if nDestinations > 1 then
				
			else --If no destinations to group
				map.p = map.p + 1
			end
		end
		return signals
	end
}

------------------------------------
-- Block output code generation

code = {}
codeGen = {
	
}

------------------------------------
-- Symbol table (contains main language definition)

symTab ={
	["MOV"] = function() --MOV(a+b+c, x, y, z) -> x, y, z = a+b+c
		input:expect("(")
		local value = parse.expression() --Get source
		input:expect(",")
		local ident = {}
		repeat --Get destination identifiers
			local token = input:getNextToken("^([_%a][_%w]*)")
				or abort("invalid identifier \""..
					input:getNextToken("^([_%w]+)").."\"")
			if not symTypes[token] then
				abort("identifier \""..token.."\" not recognised")
			end
			if symTypes[token] == "RAM" then
				input:expect("[")
				local addr = parse.expression()
				input:expect("]")
				token = blockGen.writeRAM(token, addr)
			end
			table.insert(ident, token)
		until not input:getNextToken("^(,)")
		input:expect(")")
		blockGen.move(value, ident)
	end,
	["main"] = function() --Designates main block, repeats infinitely
		block.current = blockGen.newBlock("main")
		while true do
			local token = input:getNextToken("^([_%a][_%w]*)")
			if token == "end" then --End of main block
				block.current = "program"
				break
			elseif token == nil then --No matching "end" found
				abort("expected \"end\" for \"main\"")
			else
				processStatement(token)
			end
		end
	end,
	["R1"] = 0,
	["R2"] = 0,
	["R3"] = 0,
	["R4"] = 0,
	["R5"] = 0,
	["R6"] = 0,
	["R7"] = 0,
	["R8"] = 0,
	["RAM1"]={size=6},
	-- Negate "value" or parse input if not provided
	["NEG"] = function(value) --NEG(a) -> a*(-1)
		if not value then
			input:expect("(")
			value = parse.expression()
			input:expect(")")
		end
		local checkS = "NEG"
		for i = 1, #value do
			if block[block.current]["currVal"][value[i]] then
				checkS = checkS..":"..
					block[block.current]["currVal"][value[i]]
			else
				checkS = false break
			end
		end
		print(checkS)
		if not block[block.current]["currVal"][checkS] then
			print("No equivalent NEG instance")
			blockGen.move(value, {"NEG"})
		else print("equivalent NEG instance")
		end
		return "NEG"
	end,
}

------------------------------------
-- Symbol table types (auto-populated)

symTypes = {}

------------------------------------
-- Compiler variables


------------------------------------
-- Compiler main


printTable = function(t, verbose, p, d)
	d = d or 0
	if type(t) ~= "table" then return print(""..tostring(t)) end
	p = p or {}
	if p[t] then return end
	p[t] = true
	for k, v in pairs(t) do
		if verbose then print(d..":"..tostring(k)..":") end
		printTable(v, verbose, p, d+1)
	end
end

------------------------------------

--Main section


--Get running file path information
local filepath = string.sub(debug.getinfo(1, "S").source, 2, -1)
_, _, directorySeparator = string.find(filepath, "([\\/])")
local _, _, dirpath = string.find(filepath, "(.+"..directorySeparator..")")

--Load architecture specification
local architectureSpecificationSource = extraxtArg("-a") or "architecture specification.lua"
architectureSpecificationSource = string.find(architectureSpecificationSource, directorySeparator) and
	architectureSpecificationSource or dirpath .. architectureSpecificationSource
component = directRequire(architectureSpecificationSource)

--Load computer specification
local computerSpecificationSource = extraxtArg("-s") or dirpath .. "computer specification.lua"
computerSpecificationSource = string.find(computerSpecificationSource, directorySeparator) and
	computerSpecificationSource or dirpath .. computerSpecificationSource
specification = directRequire(computerSpecificationSource)

--Initialise symTypes
for k, _ in pairs(symTab) do
	if string.find(k, "^R[%d]+") then
		symTypes[k] = "register"
	elseif string.find(k, "^RAM[%d]+") then
		symTypes[k] = "RAM"
	else
		symTypes[k] = "reserved"
	end
end

--Load input
input = newScanner("MOV(R1 + R1, R3) MOV(R1+R2,R4)")

block.current = blockGen.newBlock("program")
while input:getStatement() do end
--Input parsing and first block generation pass complete, perform second block generation pass
block2Gen.start("program")
block3Gen.start("program")

--Change print to output to file
local ioOut = io.output()
io.output(dirpath.."log.txt")
local tempPrint = print
print = function(printS) io.write(printS or "", "\n") end

print(input.s.."\n")
print("program block:")
block.program:print("return")
print() block2.program:print("return")
print()

--Print move timings
for k, v in pairs(block2.program.tick) do
	print("===["..k.."]===")
	printTable(v)
end

--Restore print function
io.output(ioOut)
print = tempPrint
halt(" ===SCRIPT COMPLETE=== ")
