input="A = X*8*2\n B=X*8/2\nC=X/8*2\nD=X/8/2\n E=2+4*8\n F=(2+4)*8"
currLine=1
cursorPos=0

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

halt = function(s) --Print s and stop program
	print("\n\n\n"..s.."\n\n\n".." Press Enter to close...")
	io.input(stdin)
	io.read()
	os.exit()
end

abort = function(s) --Print error message s and stop program
	local sTrace = debug.traceback()
	sTrace = string.gsub(sTrace, "[%w%s+\\]*[%w%s]+%.lua", "...\\<this file>")
	sTrace = string.gsub(sTrace, "[%.]+%.%.%.\\", "...\\") --Remove excess periods
	halt("["..currLine.."] Error: "..s.."\n\n"..sTrace)
end

getToken = function(s)
	local token = getNextToken(s)
	if token == nil then
		halt(" === SCRIPT COMPLETE === ")
	end
	if symTab[token] == nil then
		abort("token \""..token.."\" not recognised")
	end
	symTab[token]()
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
		if uMin then print("NEG R1") token = "-"..token end
	else --Is integer
		token = getNextToken(input, "^([_%w]+)")
		if not string.find(token, "^[%d]+$") then abort("expected integer") end
		token = uMin and math.modf(-token) or tonumber(token)
	end
	--print("factor returning type "..type(token))
	--io.read()
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
	--print("term returning type "..type(value))
	--io.read()
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
	return value
end

assignment = function()
	local ident = getNextToken(input, "^([_%a][_%w]*)")
	if ident == nil then abort("expected identifier") end
	if not getNextToken(input, "(=)") then abort("expected \"=\"") end
	local value = expression()
	if value == nil then abort("expected value for identifier \""..ident.."\"") end
	return (ident.." = "..value)
end

while string.find(input, "[^ 	\n]", cursorPos+1) do
	print(assignment())
end
halt(" ===SCRIPT COMPLETE=== ")