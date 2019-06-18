------------------------------------
--[[
    Compiler contents:
    -Miscelanious functions
	-Lexical scanner
	-Expression parser
	-Load files

    Compiler architecture:
    -Tokenisation by Lexical Scanner
    --Construction of Abstract Syntax Tree from Symbol Table, triggered by Lexical Scanner
    -First pass over AST, set minimum timings
    -Second pass over AST, group signals on active ticks
    -Third pass over AST, assign data lanes
    -While there are scheduling conflicts:
    --Fourth pass over AST, adjust timings
    --Fifth pass over AST, regroup signals
    --Sixth pass over AST, assign data lanes
]]


------------------------------------
-- Miscelanious compiler functions

--Get running file path information
--local filepath = string.sub(debug.getinfo(1, "S").source, 2, -1)
local filepath = arg[0]
local _, dirpath, directorySeparator = string.find(filepath, ".*([\\/])")
dirpath = string.sub(filepath, 1, dirpath)


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

--Scan arg for prefix and return next if found
local extraxtArg = function(prefix)
	for i = 1, #arg do
		if arg[i] == prefix then
			return arg[i+1]
		end
	end
end

local verbose = extraxtArg("-v") or true --Change true/false to set verbose default
vPrint = function(s) --Prints string if verbose is true
	if verbose then print(s) end
end

warning = function(s) --Print warning message if verbose is true
	local currLine = input and input.currLine or 0
	vPrint("["..currLine.."] Warning: "..s)
end

------------------------------------
-- Lexical scanner

--Returns a new scanner object for s
local newScanner = function(s)
	local newScan = {cursorPos = 0, currLine = 1, s = s}
	--Returns next token in s, skipping WS and NL
	function newScan:getNextToken(pat)
		local c --Capture
		--Skip WS
		_, self.cursorPos, c = string.find(self.s, "[ 	]*([^ 	])", self.cursorPos)
		if self.cursorPos == nil then return end
		if c == ";" then --If c is a comment
			_, self.cursorPos = string.find(self.s, "\n", self.cursorPos)
			if self.cursorPos == nil then return end
		elseif c ~= "\n" then --If c is not a NL
			-- match pattern pat else match not (WS or NL)
			local tokenStart = self.cursorPos
			_, self.cursorPos, c = string.find(self.s, pat or "([^ 	\n]+)", self.cursorPos)
			self.cursorPos = self.cursorPos and self.cursorPos+1 or tokenStart
			return c
		end
		-- c is a NL, or fallen through after skipping comment
		self.cursorPos=self.cursorPos+1
		self.currLine=self.currLine+1
		return self:getNextToken(pat)
	end
	--Abort unless expected token s is next
	function newScan:expect(s)
		if not self:getNextToken(--Escape any magic characters
			"^("..string.gsub(s, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")..")") then
			abort("expected \""..s.."\"")
		end
	end
	return newScan	
end

------------------------------------
--Expression parser
--exampleFrame = {"signal-red": 16, "signal-blue": -123}

--Separate expression parser seems uneeded and counter to the language, should be handled by symbols

-- parse = {
-- 	factor = function(expr)
-- 		local parseFrameNum = function()
-- 			local v = input:getNextToken("^([+-]?%w+)")
-- 			if tonumber(v) then
-- 				v = tonumber(v)
-- 			else
-- 				local uMinus = string.find(v, "^-")
-- 				v = (uMinus or string.find(v, "^+")) and string.sub(v, 2) or v
-- 				if string.find(v, "^0b") then --is binary
-- 					v = tonumber(string.sub(v, 3), 2)
-- 				end
-- 				v = uMinus and -v or v
-- 			end
-- 			return v
-- 		end
-- 		local uMinus = input:getNextToken("^(-)") and true or false
-- 		local value = input:getNextToken("^({)") and true or false
-- 		if value then --parse for frame literal
-- 			value = {}
-- 			repeat
-- 				value[input:getNextToken("^\"(.-)\":")] = parseFrameNum()
-- 			until not input:getNextToken("^(,)")
-- 			input:expect("}")
-- 			value = frame:new(value)
-- 			value = uMinus and -value or value
-- 		elseif input:getNextToken("^(%()") then --parse for expression
-- 			value = parse.expression(expr)
-- 			input:expect(")")
-- 		else --parse for identifier
-- 			value = input:getNextToken("([_%w]+)")
-- 			if not symTab[value] then
-- 				abort("identifier \""..value.."\" not recognised")
-- 			else
-- 				if symTab.__type[value] == "RAM" then --If factor is RAM address
-- 					expect("[")
-- 					local addr = parse.expression()
-- 					expect("]")
-- 					value = blockGen.readRAM(value, addr)
-- 				elseif symTab.__type[value] == "reserved" then
-- 					value = symTab[value]()
-- 				end
-- 			end
-- 		end
-- 		print("parse.factor returning "..(getmetatable(value)==frame and value:tostring() or value))
-- 		return value
-- 	end,
-- 	term = function(expr)
-- 		local value = parse.factor(expr)
-- 		print("parse.term returning "..(getmetatable(value)==frame and value:tostring() or value))
-- 		return value
-- 	end,
-- 	expression = function(expr)
-- 		expr = expr or frame:new() --expr holds value of expression currently being built
-- 		local value = parse.term(expr)
-- 		expr = expr+value
-- 		while true do
-- 			local operator = input:getNextToken("^([+-])")
-- 			if not operator then break end
-- 			value2 = parse.term(expr)
-- 			if getmetatable(value2) == frame then
-- 				expr = operator == "+" and expr+value2 or expr-value2
-- 			else
-- 				table.insert(expr, (operator == "-") and ("-"..value2) or value2)
-- 			end
-- 		end
-- 		print("parse.expression returning "..(getmetatable(expr)==frame and expr:tostring() or expr))
-- 		return expr
-- 	end
-- }

------------------------------------
--Load input and specification files

package.path = dirpath.."?.lua;"..package.path
graph = require("lib.graph")
multiset = require("lib.multiset")
frame = require("lib.frame")

symTab = require(extraxtArg("-l") or "language specification")
component = require(extraxtArg("-a") or "architecture specification")
specification = require(extraxtArg("-s") or "computer specification")
local inFile = assert(io.open(extraxtArg("-f") or dirpath.."input.txt"))
input = newScanner(inFile:read("*all"))
inFile:close()

------------------------------------
--AST constructor
local AST = {}
AST.__index = function(t, k)
	return rawget(AST, k) or graph[k] --Attempt to use AST methods first, fall back on graph methods
end

function AST:new()
	local newAST = setmetatable(graph:new(), AST)
	newAST:addVertex("return")
	newAST.currVal = {}
	return newAST
end

function AST:move(source, destination) --Move from table of sources to table of destinations
	for i = 1, #source do --For each source
		if not self.currVal[source[i]] then --Check if it exists in "currVal"
			--New source: create it, add to "currVal"
			local sourceV = self:addUniqueVertex()
			self:setInfo(sourceV, source[i])
			self.currVal[source[i]] = sourceV
		else --Already exists: unlink "return" from it
			while self:removeEdge("return", self.currVal[source[i]]) do end
		end
	end
	for i = 1, #destination do --For each destination
		if string.find(destination[i], "^RAM") then --If RAM
			local destV = self.currVal[destination[i]]
			local d = self:addUniqueVertex()
			for j = 1, #source do --Link to sources
				local destV = self
				self:addEdge(d, self.currVal[source[j]])
			end
		else --If not RAM, create new destination vertex and link "return" to it
			local destV = self:addUniqueVertex()
			self:setInfo(destV, destination[i])
			self:addEdge("return", destV)
			self.currVal[destination[i]] = destV --Update "currVal"
			for j = 1, #source do --Link to sources
				self:addEdge(destV, self.currVal[source[j]])
			end
		end
	end
end

function AST:readRAM()
end

function AST:writeRAM()
end

------------------------------------
--Scan input, constructing AST
local mainAST = AST:new()
currAST = mainAST
local nextToken = input:getNextToken("^([_%a][_%w]*)")
while nextToken do
	if symTab[nextToken] == nil then
		abort("token \""..nextToken.."\" not recognised")
	else
		symTab[nextToken]()
	end
	nextToken = input:getNextToken("^([_%a][_%w]*)")
end

------------------------------------
--First pass over AST, set minimum timings

if verbose then --If verbose, copy AST to preserve result of previous pass
	local ASTpass1 = currAST:copy()
	currAST = ASTpass1
end
currAST.tick = {[0]={}} --Create tick table
currAST.pass1 = function() end --Forward declaration
function currAST:pass1(nVert, cTick)
	if not self[nVert][1] then return end --If no neighbours, stop
	self.tick[cTick] = self.tick[cTick] or {} --Extend tick table if necessary
	self.tick[cTick][nVert] = {table.unpack(self[nVert])} --Add nVert and neighbours to tick table
	local nTick = cTick + specification[self[nVert].info].passThrough
	for i = 1, #self[nVert] do
		self:pass1(self[nVert][i], nTick)
	end
end
for i = 1, #currAST["return"] do
	currAST:pass1(currAST["return"][i], 0)
end

------------------------------------
--Second pass over AST, group signals on active ticks

--For each active tick:
---Determine usage number of each vertex (workset)
---Create workset mapping and sort
---Attempt to group destinations of vertices in descending usage order
---Pick vertex from mapping by pointer and attempt to group destinations:
----Find destinations of vertex
----Group destinations that source from same sets of vertices
----If grouping successful:
-----Decrement workSet appropriately
-----Re-sort mapping and reset pointer
----If unsuccessful:
-----Increment mapping pointer
---Stop when usage of vertex picked == 1 or mapping pointer > #map


--Group column with row?
--		AB	C	ABC
--	AB	X	0	0
--	C	0	X	0
--	ABC	1	1	X
-->	(AB), (C), (AB)(C)
-- ABx <= ABy and Cx <= Cy indicate they can each be grouped into ABC

--		A	B	C
--	AB	1	1	0
--	C	0	0	1
--	ABC	1	1	1
-->	(AB), (C), (AB)(C)

--		AB	A	B
--	AB	X	1	1
--	A	0	X	0
--	B	0	0	X
-->	(A)(B), (A), (B)
-- Ax <= Ay and Bx <= By indicate they can each be grouped into AB

--		A	B
--	AB	1	1
--	A	1	0
--	B	0	1
--> (A)(B), (A), (B)

--		A	AB	AC
--	A	X	0	0
--	AB	1	X	0
--	AC	1	0	X
--> (A), (AB), (AC)
-- Ay > Ax indicates A would be over used if grouped

--		A	B	C
--	A	1	0	1
--	AB	1	1	0
--	AC	1	0	1

--		AA	AB	AC
--	AA	X	0	0
--	AB	0	X	0
--	AC	0	0	X
--> (AA), (AB), (AC)
-- No potential groupings found, however

--		A	A	B	C
--	AA	1	1	0	0
--	AB	1	1	0	0
--	AC	1	1	0	0

--		A	A	AB	AC
--	A	X	X	0	0
--	A	X	X	0	0
--	AB	1	1	X	0
--	AC	1	1	0	X
--> (A), (A), (A)(B), (A)(C)
-- Ax <= Ay indicates they can be grouped into AB and AC

--		A	A	B	C
--	A	1	1	0	0
--	A	1	1	0	0
--	AB	1	1	1	0
--	AC	1	1	0	1
-->	(A), (A), (A)(B), (A)(C)

if verbose then --If verbose, copy AST to preserve result of previous pass
	local ASTpass2 = currAST:copy()
	currAST = ASTpass2
end
currAST.pass2 = function() end --Forward declaration
function currAST:pass2(cTick, signals)
	local source, dest, workset, usedBy = 0, 0, multiset:new(), {}
	for _, d in pairs(signals) do 	--For each destination
		dest = dest + 1 				  --Increment destination count
		for _, s in ipairs(d) do 		  --For each source of destination
			if workset[s] then 				--If source already counted
				workset[s] = workset[s] + 1   --Increment source use count
				usedBy[s][d] = 1
			else 							--Else source not yet counted
				workset[s] = 1 				  --Add source to use count
				source = source + 1 		  --Increment source count
				usedBy[s] = multiset:new()	  --Create usage list for source
				usedBy[s][d] = 1
			end
		end
	end
	if source > dest then print("more sources on tick "..cTick)
	elseif dest > source then print("more destinations on tick "..cTick)
	else print("equal sources and destinations on tick "..cTick) end

	local map = {p=1} --Create map of sources
	for k, _ in pairs(workset) do
		map[map.p] = k --Add source to map
		map.p = map.p + 1 --Increament pointer
	end
	map.p = 1 --Reset pointer, sort by descending usage of each source
	table.sort(map, function(a, b) return workset[a] > workset[b] end)

	while map.p < #map and map[map.p] > 1 do
		local v = map[map.p] --Pick most used source not ungroupable
	end
end
for cTick, signals in pairs(currAST.tick) do
	currAST:pass2(cTick, signals)
end

currAST:printFrom("return")