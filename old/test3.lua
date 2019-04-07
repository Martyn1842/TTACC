--Get running file path information
local filepath = string.sub(debug.getinfo(1, "S").source, 2, -1)
_, _, directorySeparator = string.find(filepath, "([\\/])")
local _, _, dirpath = string.find(filepath, "(.+"..directorySeparator..")")

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
			if v[1] then
				local s = k..": "..v[1]
				for i = 2, #v do s = s..", "..v[i] end
				print(s)
				if v.info then print("Info: "..v.info) end
			else
				print(k..": <NONE>")
				if v.info then print("Info: "..v.info) end
			end
		end
	end,
	print	= function(self, startVertex) --Prints graph ordered from vertex
		local printed, run = {}
		run = function(self, vertex)
			if not vertex then return printX(self) end --No start point, random instead
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
				print(vertex..": <NONE>")
				if self[vertex]["info"] then print("Info: "..self[vertex]["info"]) end
				printed[vertex] = true
			end
		end
		run(graph, startVertex)
	end
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
local abort = function(s) --Print error message s and stop program
	local currLine = input and input.currLine or 0
	local sTrace = debug.traceback()
	sTrace = string.gsub(sTrace, directorySeparator.."[^%\n]+"..directorySeparator,
		directorySeparator.."..."..directorySeparator)
	halt("["..currLine.."] Error: "..s.."\n\n"..sTrace)
end
local expect = function(s, input) --Assert expected token s is next in input
	if not input:getNextToken(--Escape any magic characters
		"^("..string.gsub(s, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")..")") then
		abort("expected \""..s.."\"")
	end
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
--if refetch is true contents of the cache will be ignored
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
			expect("[")
			local addr = parse.expression()
			expect("]")
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
-- Computer specification

 -- specification = {
	-- dataLanes = 6,
	-- R1 = component.new("register"),
	-- R2 = component.new("register"),
	-- R3 = component.new("register"),
	-- R4 = component.new("register"),
	-- R5 = component.new("register"),
	-- NEG = component.new("func"),
-- }

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

-- block2 = {}
-- block2Gen = {
	-- run, --Forward declaration
	-- start = function(blockName)
		-- block2[blockName] = block[blockName]:copy() --Copy block graph
		-- block2[blockName]["tick"]={} --Create tick table
		-- For each neighbour of "return"
		-- for i = 1, #block[blockName]["return"] do
			-- For each neighbour of "return"'s neighbour
			-- local retNeighbour = block2[blockName]["return"][i]
			-- while block2[blockName][retNeighbour][1] and
				-- not tonumber( block2[blockName]:getNeighbourInfo(retNeighbour, 1) ) do
					-- block2Gen.run(blockName, retNeighbour, block2[blockName][retNeighbour][1], 0)
			-- end
		-- end
	-- end,
	-- Block name, previous vertex, next vertex, current tick
	-- run = function(blockName, pVert, nVert, cTick)
		-- local lVert = block2[blockName]:addUniqueVertex() --Datalane vertex
		-- block2[blockName]:removeEdge(pVert, nVert) --Splice in
		-- block2[blockName]:addEdge(pVert, lVert)    --datalane
		-- block2[blockName]:addEdge(lVert, nVert)    --vertex
		-- Allocate datalane in tick table
		-- block2[blockName]["tick"][cTick] = block2[blockName]["tick"][cTick] or {}
		-- table.insert(block2[blockName]["tick"][cTick], nVert)
		-- Set datalane number on vertex info
		-- block2[blockName]:setVertexInfo(lVert, #block2[blockName]["tick"][cTick])
		--Add latency for nVert component
		-- local nTick = cTick + specification[block2[blockName][nVert].info].passThrough
		-- Recurse
		-- while block2[blockName][nVert][1] and
			-- not tonumber( block2[blockName]:getNeighbourInfo(nVert, 1) ) do
				-- block2Gen.run(blockName, nVert, block2[blockName][nVert][1], nTick)
		-- end
	-- end,
-- }

------------------------------------
--Set minimum timings (2)

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
		print("run: "..nVert.." on tick "..cTick)
		--If no neighbours then stop
		if #block2[blockName][nVert] == 0 then return end
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

block3 = {}
block3Gen = {
	run,
	start = function(blockName)
		block3[blockName] = block2[blockName]:copy() --Copy block graph
	end,
	run = function(blockName, cTick)
		
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
		expect("(", input)
		local value = parse.expression() --Get source
		expect(",", input)
		local ident = {}
		repeat --Get destination identifiers
			local token = input:getNextToken("^([_%a][_%w]*)")
				or abort("invalid identifier \""..
					input:getNextToken("^([_%w]+)").."\"")
			if not symTypes[token] then
				abort("identifier \""..token.."\" not recognised")
			end
			if symTypes[token] == "RAM" then
				expect("[", input)
				local addr = parse.expression()
				expect("]", input)
				token = blockGen.writeRAM(token, addr)
			end
			table.insert(ident, token)
		until not input:getNextToken("^(,)")
		expect(")", input)
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
			expect("(", input)
			value = parse.expression()
			expect(")", input)
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
for k, _ in pairs(symTab) do
	if string.find(k, "^R[%d]+") then
		symTypes[k] = "register"
	elseif string.find(k, "^RAM[%d]+") then
		symTypes[k] = "RAM"
	else
		symTypes[k] = "reserved"
	end
end

------------------------------------
-- Compiler variables

input = newScanner("MOV(R1, R2) MOV(R2+R3, R4, R5)")


------------------------------------
-- Compiler main

block.current = blockGen.newBlock("program")
while input:getStatement() do end
--Input parsing and first block generation pass complete, perform second block generation pass
--print("TEST") io.read()
block2Gen.start("program")
--print("TEST") io.read()

--Change print to output to file
ioOut = io.output()
io.output(dirpath.."log.txt")
tempPrint = print
print = function(printS) io.write(printS or "", "\n") end

print(input.s.."\n")
print("program block:")
block.program:print("return")
print() block2.program:print("return")
print()

printTable = function(t, p, d)
	d = d or 0
	if type(t) ~= "table" then print(d..": "..tostring(t)) return end
	p = p or {}
	if p[t] then return end
	p[t] = true
	for _, v in pairs(t) do
		printTable(v, p, d+1)
	end
end

for k, v in pairs(block2.program.tick) do
	print("===["..k.."]===")
	printTable(v)
end


--if block.main then print("main block:") block.main:print("return") end

-- for i = 1, #block do
	-- print("block "..i..":")
	-- printGraph(block[i], "return")
-- end

--Restore print function
io.output(ioOut)
print = tempPrint
halt(" ===SCRIPT COMPLETE=== ")

------------------------------------