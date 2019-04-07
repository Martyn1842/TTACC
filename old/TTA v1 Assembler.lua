input="\n R1=3 \nmain\n R1=4 \nend"
dataLanes=6
addrLanes={	["read"] = {"0", "4", "8", "C", "G", "K"},
			["write"]= {"2", "6", "A", "E", "I", "M"}}
currLine=1
progLine=1
outTicks={}
currOutTick=1
cursorPos=0

filepath = string.sub(debug.getinfo(1, S).source, 2, -1)
_, _, directorySeparator = string.find(filepath, "([\\/])")
_, _, dirpath = string.find(filepath, "(.+"..directorySeparator..")")
print(filepath)
print(directorySeparator)
print(dirpath)
print()
assert(loadfile(dirpath.."architecture specification.lua"))()

label = {
	post 	= function(self, labelName)
		self[labelName] = self[labelName] or progLine
	end,
	fetch 	= function(self, labelName)
		return self[labelName]
	end
}

stack = { --Stack object
	pointer = 1, --pointer is kept empty
	push = function(self, val)
		self[self.pointer] = val
		self.pointer = self.pointer + 1
	end,
	pop = function(self)
		if self.pointer == 1 then --Stack is empty
			return
		end
		self.pointer = self.pointer - 1
		local val = self[self.pointer]
		self[self.pointer] = nil
		return val
	end,
	new = function(self, newStack) --Create a new stack
		local newStack = newStack or {}
		setmetatable(newStack, self)
		self.__index = self
		return newStack
	end
}
queue = { --Queue object
	pushPointer = 1, --pointer is kept empty
	popPointer = 1, --pointer is kept full
	push = function(self, val)
		self[self.pushPointer] = val
		self.pushPointer = self.pushPointer + 1
	end,
	pop = function(self)
		if self.pushPointer > self.popPointer then
			local val = self[self.popPointer]
			self[self.popPointer] = nil
			self.popPointer = self.popPointer + 1
			if self.pushPointer == self.popPointer then
				self.pushPointer, self.popPointer = 1
			end
			return val
		else --Queue empty
			self.pushPointer, self.popPointer = 1, 1
			return
		end
	end,
	new = function(self, newQueue) --Create a new queue
		local newQueue = newQueue or {}
		newQueue.pushPointer = #newQueue + 1
		setmetatable(newQueue, self)
		self.__index = self
		return newQueue
	end
}

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
		--print(c)
		--io.read()
		return c
	end
end

addrTab ={
	["R1"] 		={addr = 1, latRefr = 5},
	["NEG"] 	={addr = 2, latProc = 5},
}

--Object code generation functions
codeGen ={
--Move a to b
	["getDataLane"] = function()
		if outTicks[currOutTick] == nil then
			outTicks[currOutTick] = {true}
			return 1
		end
		local lane = 0
		repeat
			lane = lane + 1
			if lane > dataLanes then abort("out of data lanes") end
			--print(currOutTick..", "..lane) io.read()
		until (outTicks[currOutTick][lane] == nil)
		--print("TEST") io.read()
		outTicks[currOutTick] = outTicks[currOutTick] or {}
		outTicks[currOutTick][lane] = true
		return dataLane
	end,
	["incProg"] 		= function(sleep, jump)
		print("W = "..-progLine)
		progLine = progLine + 1
		print("X = "..(jump or progLine))
		if sleep > 1 then
			print("Z = "..sleep-2)
		else
			print("Y = 1")
		end
	end,
	["move"] 		= function(a, b)
		--get dataLane availability
		local lane = codeGen.getDataLane()
		--send write
		print(addrLanes["write"][lane].." = "..addrTab[b]["addr"])
		--send read
		if type(a) == "number" then
			print("YELLOW = "..a)
		else
			print(addrLanes["read"][lane].." = "..addrTab[a]["addr"])
		end
		codeGen.incProg(8)
	end,
	["NEG"]			= function(args) --negate args
		print("NEG")
		codeGen.move(args, "NEG")
	end,
	-- Begin main function
	["startMain"] 	= function()
		label:post("main")
		print("DO MAIN")
	end,
	-- End main function
	["endMain"] 	= function()
		outTicks[currOutTick] = outTicks[currOutTick] or {}
		outTicks[currOutTick]["nextLine"] = label:fetch("main")
		print("END MAIN")
	end,
	-- Evaluate a+b
	["add"] 	= function(a, b)
		print("ADD "..a.." TO "..b)
	end,
	-- Evaluate a-b
	["sub"] 	= function(a, b)
		print("SUB "..b.." FROM "..a)
	end,
	["mul"]		= function(a, b)
		print("MUL "..b)
	end,
	["div"]		= function(a, b)
		print("DIV "..b)
	end,
}--codeGen end


symTab = { --Symbol table, stores functions/values of symbols
	["main"] 	= codeGen.startMain,
	["end"] 	= codeGen.endMain,
	["var"]		= function() --declare variable
		local ident, val = assignment()
		addToSymTab(ident, val, "var")
		codeGen.move(val, ident)
	end,
	["R1"]		= 0,
	["NEG"]		= function()
		print("doing NEG") io.read()
		if not getNextToken(input, "^(%()") then abort("expected \"(\"") end
		local args = expression()
		print(args) io.read()
		if type(args) == "number" then
			return math.modf(-args)
		else
			codeGen.NEG(args)
			codeGen.move("NEG", "")
		end
	end,
}--symTab end
symTypes = {} --Stores symbol types
for k, _ in pairs(symTab) do --Initialise symTypes with reserved words
	if string.find(k, "R[%d]+") then
		symTypes[k] = "register"
	else
		symTypes[k] = "reserved"
	end
end

addToSymTab = function(ident, val, typ)
	if symTypes[ident] then
		if symTypes[ident] == "reserved" then
			abort("cannot declare reserved word \""..ident.."\" as "..typ)
		end
		abort(typ.." \""..ident.."\" already declared")
	end
	symTypes[ident] = typ
	symTab[ident] = val
end



halt = function(s) --Print (s) and stop program
	print("\n\n\n"..s.."\n\n\n".." Press Enter to close...")
	io.input(stdin)
	io.read()
	os.exit()
end

abort = function(s) --Print error message (s) and stop program
	local sTrace = debug.traceback()
	sTrace = string.gsub(sTrace, "[%w%s+\\]*[%w%s]+%.lua", "...\\<this file>")
	sTrace = string.gsub(sTrace, "[%.]+%.%.%.\\", "...\\") --Remove excess periods
	halt("["..currLine.."] Error: "..s.."\n\n"..sTrace)
end

getStatement = function(s)
	local token = getNextToken(s, "^([_%w]+)")
	if token == nil then halt(" === SCRIPT COMPLETE === ") end
	--print("got statement start: "..token) io.read()
	if symTab[token] == nil then abort("token \""..token.."\" not recognised") end
	if symTypes[token] == "var" or symTypes[token] == "register" then
		--local instr = new:queue()
		_, symTab[token] = assignment(token)
		codeGen.move(symTab[token], token)
	else
		symTab[token]()
	end
end

factor = function() --Parses a factor
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
		if symTypes[token] == "reserved" or symTypes[token] == "func" then
			local ret = symTab[token]()
			if type(ret) == "number" then
			else --WORK OUT WTF IS GOING ON WITH RETURNS
			end
		end
		if uMin then codeGen.NEG() token = "-"..token end
	else --Is integer
		token = getNextToken(input, "^([_%w]+)")
		if not string.find(token, "^[%d]+$") then abort("expected integer") end
		token = uMin and math.modf(-token) or tonumber(token)
	end
	--print("factor returning type "..type(token))
	--io.read()
	return token
end

term = function() --Parses a term
	local value = factor()
	while string.find(input, "^[ 	\n]*[*/]", cursorPos+1) do
		local token = getNextToken(input, "^([*/])")
		if type(value) == "number" then
			local value2 = factor()
			if type(value2) == "number" then --If both number
				value = (token == "*") and math.modf(value * value2)
										or math.modf(value / value2)
			else --If value is number but value2 is not
				if token =="*" then
					codeGen.mul(value, value2)
					value = value.."*"..value2
				else
					codeGen.div(value, value2)
					value = value.."/"..value2
				end
			end
		else --If value is not number (is value2 number irrelevant
			if token =="*" then
				local value2 = expression()
				codeGen.mul(value, value2)
				value = value.."*"..value2
			else
				local value2 = factor()
				codeGen.div(value, value2)
				value = value.."/"..value2
			end
		end
	end
	--print("term returning type "..type(value))
	--io.read()
	return value
end

expression = function() --Parses an expression from s
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
	return value
end

assignment = function(ident) --Parses an assignment statement
	ident = ident or getNextToken(input, "^([_%a][_%w]*)")
	if ident == nil then abort("expected identifier") end
	if not getNextToken(input, "(=)") then abort("expected \"=\"") end
	local value = expression()
	if value == nil then abort("expected value for identifier \""..ident.."\"") end
	return ident, value
end


halt("==import test complete==")


while true do getStatement(input) end
halt(" === SCRIPT COMPLETE === ")