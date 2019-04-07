oldPrint = print print = function(s) io.write(s.."\n") end

input="main R1=R2 end HALT\n"
block={info={}}
output={["line"] = 0}
currLine=1
cursorPos=0
currentTick=1
dataBusWidth=6
dataLaneUsage={}
addrLanes={["read"]={"0", "4", "8", "C", "G", "K"},
		  ["write"]={"2", "6", "A", "E", "I", "M"}}

addrTab = {R1={addr=1}, NEG={addr=2}, R2={addr=4}, RAM1={addrD=8, addrA=16}}

label = {
	num = 0,
	new		= function(self)
		self.num = self.num + 1
		self[self.num] = output.line
		return self.num
	end,
	post 	= function(self, labelName)
		self[labelName] = (not self[labelName]) and output.line
			or abort("label \""..labelName.."\" already exists")
	end,
	fetch	= function(self, labelName)
		if not self[labelName] then
			abort("label \""..labelName.."\" does not exist") end
		return self[labelName]
	end }

graph = {
	-- Create vertex with optional edges (directional)
	addVertex	= function(self, vertex, neighbours)
		if self[vertex] then print("vertex \""..vertex.."\" already exists") return end
		self[vertex] = {}
		neighbours = (type(neighbours) == "table" and neighbours or {neighbours}) or {}
		for i = 1, #neighbours do self:addEdge(vertex, neighbours[i]) end
	end,
	-- Remove vertex and all references to it in graph
	removeVertex = function(self, vertex)
		if not self[vertex] then print("vertex \""..vertex.."\" does not exist") return end
		self[vertex] = nil
		for vertex2, neighbours in pairs(self) do
			for i = #neighbours, 1, -1 do
				if neighbours[i] == vertex then table.remove(self[vertex2], i) end
			end
		end
	end,
	--Add edge from vertex to vertex2 (directional),
	--multiple such edges can exist simultaneously
	addEdge = function(self, vertex, vertex2)
		if not self[vertex] then print("vertex \""..vertex.."\" does not exist") return end
		if vertex == vertex2 then print("cannot form edge to self") return end
		if not self[vertex2] then print("vertex \""..vertex2.."\" does not exist") return end
		table.insert(self[vertex], vertex2)
	end,
	--Removes one instance of edge from vertex to vertex2 (directional)
	removeEdge = function(self, vertex, vertex2)
		if not self[vertex] then print("vertex \""..vertex.."\" does not exist") return end
		if not self[vertex2] then print("vertex \""..vertex2.."\" does not exist") return end
		for i = 1, #self[vertex] do
			if self[vertex][i] == vertex2 then table.remove(self[vertex], i) return end
		end
	end,
	-- Returns true if vertex2 is adjacent to vertex (directional)
	isAdjacent = function(self, vertex, vertex2)
		if not self[vertex] then print("vertex \""..vertex.."\" does not exist") return end
		if not self[vertex2] then print("vertex \""..vertex2.."\" does not exist") return end
		for i = 1, #self[vertex] do
			if self[vertex][i] == vertex2 then return true end
		end
		return false
	end,
	new		= function(self)
		local newGraph = {}
		setmetatable(newGraph, self)
		self.__index = self
		return newGraph
	end
}

codeGen = {
	["getDataLane"]	= function()
		if dataLaneUsage[currentTick] == nil then --No lanes in use
			dataLaneUsage[currentTick] = {true}
			return 1
		end
		local lane = 0
		repeat
			lane = lane + 1
			if not dataLaneUsage[currentTick][lane] then --Found empty lane
				dataLaneUsage[currentTick][lane] = true
				return lane
			end
		until lane > dataBusWidth
		abort("no available data lane")
	end,
	["newInstr"]	= function(sleep, jump)
		print("new instruction")
		output.line = output.line + 1
		output[output.line] = {["sleep"] = sleep or 1,
								["jump"] = jump or (output.line + 1),
								[1]	= "=["..output.line.."]====="}
	end,
	["closeInstr"]	= function(sleep, jump)
		output[output.line]["sleep"] = math.max((sleep or 1),
											output[output.line]["sleep"])
		output[output.line]["jump"] = jump or output[output.line]["jump"]
		-- table.insert(output[output.line], "W = "..-output.line)
		-- table.insert(output[output.line], "X = "..(jump 
									-- or output[output.line]["jump"]))
		currentTick = currentTick + sleep
		--output.line = output.line + 1
	end,
	["MOVE"]		= function(a, b) --Copy a to b
		codeGen.newInstr()
		print("generating move instructions: \""..tostring(a).."\" to \""..tostring(b).."\"")
		local lane = codeGen.getDataLane()
		--print("doing move") io.read()
		if type(a) == "table" then --If multiple sources
			local sum, y = 0, 0
			for _, v in pairs(a) do
				if type(v) == "number" then --Sum literal ints
					y = y + v
				else
					sum = bit32.bor(sum, addrTab[v]["addr"]) or
							abort("no known address for \""..v.."\"")
				end
			end
			if y ~= 0 then table.insert(output[output.line], "YELLOW = "..y) end
			if sum ~= 0 then table.insert(output[output.line], 
										addrLanes["read"][lane].." = "..sum) end
		elseif type(a) == "number" then --If single literal source
			table.insert(output[output.line], "YELLOW = "..a)
		else --If single address source
			table.insert(output[output.line], 
						addrLanes["read"][lane].." = "..addrTab[a]["addr"])
		end
		if type(b) == "table" then --If multiple destinations
			local sum = 0
			for _, v in pairs(b) do
				sum = bit32.bor(sum, addrTab[v]["addr"]) or
						abort("no known address for \""..v.."\"")
			end
			table.insert(output[output.line], --Write to all of b
						addrLanes["write"][lane].." = "..sum)
		else --If single destination
			table.insert(output[output.line], --Write to b
						addrLanes["write"][lane].." = "..addrTab[b]["addr"])
		end
		output[output.line]["sleep"] = math.max(output[output.line]["sleep"], 4)
	end,
	["jump"]		= function(target)
		if output[output.line]["jump"] ~= 0 then
			if type(target) == "number" then
				output[output.line]["jump"] = target
			end
			print("jump from "..(output.line).." to "..target)
		end
	end,
	["HALT"]		= function()
		output[output.line]["jump"] = 0
	end
}

blockGen = {
	["getDataLane"]	= function()
		if dataLaneUsage[currentTick] == nil then --No lanes in use
			dataLaneUsage[currentTick] = {true}
			return 1
		end
		local lane = 0
		repeat
			lane = lane + 1
			if not dataLaneUsage[currentTick][lane] then --Found empty lane
				dataLaneUsage[currentTick][lane] = true
				return lane
			end
		until lane > dataBusWidth
		abort("no available data lane")
	end,
	["newInstr"]	= function(sleep, jump)
		print("new instruction")
		output.line = output.line + 1
		output[output.line] = {["sleep"] = sleep or 1,
								["jump"] = jump or (output.line + 1),
								[1]	= "=["..output.line.."]====="}
	end,
	["closeInstr"]	= function(sleep, jump)
		output[output.line]["sleep"] = math.max((sleep or 1),
											output[output.line]["sleep"])
		output[output.line]["jump"] = jump or output[output.line]["jump"]
		-- table.insert(output[output.line], "W = "..-output.line)
		-- table.insert(output[output.line], "X = "..(jump 
									-- or output[output.line]["jump"]))
		currentTick = currentTick + sleep
		--output.line = output.line + 1
	end,
	["MOVE"]		= function(a, b) --Copy a to b
		codeGen.newInstr()
		print("generating move instructions: \""..tostring(a).."\" to \""..tostring(b).."\"")
		local lane = codeGen.getDataLane()
		--print("doing move") io.read()
		if type(a) == "table" then --If multiple sources
			local sum, y = 0, 0
			for _, v in pairs(a) do
				if type(v) == "number" then --Sum literal ints
					y = y + v
				else
					sum = bit32.bor(sum, addrTab[v]["addr"]) or
							abort("no known address for \""..v.."\"")
				end
			end
			if y ~= 0 then table.insert(output[output.line], "YELLOW = "..y) end
			if sum ~= 0 then table.insert(output[output.line], 
										addrLanes["read"][lane].." = "..sum) end
		elseif type(a) == "number" then --If single literal source
			table.insert(output[output.line], "YELLOW = "..a)
		else --If single address source
			table.insert(output[output.line], 
						addrLanes["read"][lane].." = "..addrTab[a]["addr"])
		end
		if type(b) == "table" then --If multiple destinations
			local sum = 0
			for _, v in pairs(b) do
				sum = bit32.bor(sum, addrTab[v]["addr"]) or
						abort("no known address for \""..v.."\"")
			end
			table.insert(output[output.line], --Write to all of b
						addrLanes["write"][lane].." = "..sum)
		else --If single destination
			table.insert(output[output.line], --Write to b
						addrLanes["write"][lane].." = "..addrTab[b]["addr"])
		end
		output[output.line]["sleep"] = math.max(output[output.line]["sleep"], 4)
	end,
	["jump"]		= function(target)
		if output[output.line]["jump"] ~= 0 then
			if type(target) == "number" then
				output[output.line]["jump"] = target
			end
			print("jump from "..(output.line).." to "..target)
		end
	end,
	["HALT"]		= function()
		output[output.line]["jump"] = 0
	end
}

symTab = {
	["main"]	= function()
		block.main = graph:new()
		block.info.main = {startLine = output.line + 1}
		while true do --Process main block
			local token = getNextToken(input, "^([_%a][_%w]*)")
			if token == "end" then --End of main block
				codeGen.jump(block.info.main.startLine)
				break
			elseif token == nil then --No matching "end" found
				abort("expected \"end\" for \"main\"")
			else --Other token found
				processStatement(token)
			end
		end
	end,
	["end"]		= function()
		--codeGen.closeInstr(1, label:fetch("main"))
	end,
	["NEG"]		= function()
		if not getNextToken(input, "^(%()") then abort("expected \"(\"") end
		local args = expression()
		if not getNextToken(input, "^(%))") then abort("expected \")\"") end
		if type(args) == "number" then return math.modf(-args) end
		codeGen.MOVE(args, "NEG")
		codeGen.closeInstr(4)
		print("neg closed instruction")
		return "NEG"
	end,
	["R1"]		= 0,
	["RAM1"]	= {size=10},
}
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

getNextToken = function(s, pat) --Returns next token in s, skipping WS and NL
	local c
	cursorPos=cursorPos+1
	_, cursorPos, c = string.find(s, "[ 	]*([^ 	])", cursorPos) --Skip WS
	if cursorPos == nil then return end
	if c == "\n" then --If c in a NL
		currLine=currLine+1
		return getNextToken(s, pat)
	else
		--match pattern pat else match not (WS or NL)
		--print(pat or "no pattern")
		_, cursorPos, c = string.find(s, pat or "([^ 	\n]+)", cursorPos)
		--print(tostring(c)) --io.read()
		return c
	end
end

halt = function(s) --Print s and stop compiler
	io.output(stdout)
	print("\n\n\n"..s.."\n\n\n".." Press Enter to close...")
	io.input(stdin)
	io.read()
	os.exit()
end

abort = function(s) --Print error message s and stop compiler
	local sTrace = debug.traceback()
	sTrace = string.gsub(sTrace, "[%w%s+\\]*[%w%s]+%.lua", "...\\<this file>")
	sTrace = string.gsub(sTrace, "[%.]+%.%.%.\\", "...\\") --Remove excess periods
	halt("["..currLine.."] Error: "..s.."\n\n"..sTrace)
end

processStatement = function(token)
	if symTab[token] == nil and codeGen[token] == nil then
		abort("token \""..token.."\" not recognised")
	end
	if symTypes[token] == "register" then
		assignment(token)
	else
		if symTab[token] then symTab[token]()
			else codeGen[token]() end
	end
end

getStatement = function(s)
	--print("getting statement") io.read()
	local token = getNextToken(s, "^([_%a][_%w]*)")
	if token == nil then return end --halt(" === SCRIPT COMPLETE === ") end
	--print("got token \""..token.."\"") io.read()
	processStatement(token)
	-- if symTab[token] == nil and codeGen[token] == nil then
		-- abort("token \""..token.."\" not recognised")
	-- end
	-- if symTypes[token] == "register" then
		-- assignment(token)
	-- else
		-- if symTab[token] then symTab[token]()
			-- else codeGen[token]() end
	-- end
	return true
end

factor = function()
	local uMin, token = false
	if string.find(input, "^[ 	\n]*[+-]", cursorPos+1) then --If unary addop
		local op = getNextToken(input, "([+-])")
		uMin = (op == "-") --If unary minus
	end
	if string.find(input, "^[ 	\n]*%(", cursorPos+1) then --If parens
		if not getNextToken(input, "^(%()") then abort("expected \"(\"") end
		token = expression()
		if not getNextToken(input, "^(%))") then abort("expected \")\"") end
		token = (uMin and type(token) == "number")
			and math.modf(-token) or token
	elseif string.find(input, "^[ 	\n]*[_%a]", cursorPos+1) then --If identifier
		token = getNextToken(input, "^([_%a][_%w]*)") --Get identifier
		if symTypes[token] == "reserved" then
			local ret = symTab[token]() --function call
			token = ret and ret or token
		else
			
		end
		if uMin then print("NEG R1") token = "-"..token end
	else --Is integer
		token = getNextToken(input, "^([_%w]+)")
		if not string.find(token, "^[%d]+$") then abort("expected integer") end
		token = uMin and math.modf(-token) or tonumber(token)
	end
	--print("factor returning type "..type(token)) io.read()
	return token
end

term = function()
	local value = factor()
	while string.find(input, "^[ 	\n]*[*/]", cursorPos+1) do
		local token = getNextToken(input, "^([*/])")
		if type(value) == "number" then
			local value2 = factor()
			if type(value2) == "number" then --If both number
				value = (token == "*") and math.modf(value * value2)
										or math.modf(value / value2)
			else --If value is number but value2 is not
				value = (token == "*") and value.."*"..value2
										or value.."/"..value2
			end
		else --If value is not number (is value2 number irrelevant
			value = (token == "*") and value.."*"..expression()
									or value.."/"..factor()
		end
	end
	--print("term returning type "..type(value)) io.read()
	return value
end

expression = function()
	local value = term()
	while string.find(input, "^[ 	\n]*[+-]", cursorPos+1) do
		local token = getNextToken(input, "^([+-])")
		if type(value) == "number" then
			local value2 = term()
			if type(value2) == "number" then --If both number
				value = (token == "+") and math.modf(value + value2)
										or math.modf(value - value2)
			else --If value is number but value2 is not
				if string.find(value2, "^-") then --If value2 is -ve string
					value = (token == "+") and value..value2
							or value.."+"..string.sub(value2, 2, -1)
				else --If value2 is +ve string
					value = (token == "+") and value.."+"..value2
											or value.."-"..value2
				end
			end
		else --If value is not number (is value2 number irrelevant)
			local value2 = expression()
			--If value2 is negative number
			if type(value2) == "number" and value2 < 0 then
				value = (token == "+") and value.."-"..math.modf(-value2)
										or value.."+"..math.modf(-value2)
			else
				if string.find(value2, "^-") then --If value2 is -ve string
					value = (token == "+") and value..value2
								or value.."+"..string.sub(value2, 2, -1)
				else --If value2 is +ve string
					value = (token == "+") and value.."+"..value2
											or value.."-"..value2
				end
			end
		end
	end
	--print("expression returning type "..type(value)) io.read()
	return value
end

assignment = function(ident)
	local t = {}
	while string.find(input, "^[ 	\n]*(,)", cursorPos+1) do
		t[1] = ident
		getNextToken(input, "^(,)")
		local s = getNextToken(input, "^([_%a][_%w]*)") or abort("expected identifier")
		table.insert(t, s)
	end
	ident = t[1] and t or ident
	if ident == nil then abort("expected identifier") end
	if (not getNextToken(input, "^(=)")) then abort("expected \"=\"") end
	local val = expression()
	if val == nil then abort("expected value for identifier \""..ident.."\"") end
	local t={}
	string.gsub(val, "(-?[%w]+)", function(w) 
				table.insert(t, (tonumber(w) and math.modf(w) or w)) end)
	val = #t > 1 and t or t[1]
	codeGen.MOVE(val, ident)
	codeGen.closeInstr(4)
	print("assignment closed instruction")
end

stdout = io.output()
assert(io.output("E:\\Users\\Martin\\Documents\\Coding\\Lua\\Factorio\\log.txt"))
--io.write("io test\n")

while getStatement(input) do end

printTable = function(t)
	for i = 1, #t do
		if type(t[i]) == "table" then printTable()
		else print(t[i]) end
	end
end
for i = 1, output.line do
	if output[i][1] then
		printTable(output[i])
		print("W = "..-i)
		if output[i]["jump"] ~= 0 then print("X = "..output[i]["jump"]) end
		print( (output[i]["sleep"] < 2) and "Y = 1"
					or "Z = "..(output[i]["sleep"]-2) )
	end
end
halt(" ===SCRIPT COMPLETE=== ")