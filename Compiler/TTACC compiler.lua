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


--Get running file path information
--local filepath = string.sub(debug.getinfo(1, "S").source, 2, -1)
local filepath = arg[0]
local _, _, directorySeparator = string.find(filepath, "([\\/])")
local _, _, dirpath = string.find(filepath, "(.+"..directorySeparator..")")

package.path = dirpath.."?.lua;"..package.path
local graph = require("lib.graph")
local multiset = require("lib.multiset")

------------------------------------
-- Miscelanious compiler functions

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

--Scan arg for prefix and return next if found
local extraxtArg = function(prefix)
	for i = 1, #arg do
		if arg[i] == prefix then
			return arg[i+1]
		end
	end
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
	function newScan:processStatement(token)
		if symTab[token] == nil then
			abort("token \""..token.."\" not recognised")
		-- elseif symTab._type[token] == "register" then
		-- 	assignment(token)
		else
			symTab[token]()
		end
	end
	--Returns true if token found
	function newScan:getStatement()
		local token = self:getNextToken("^([_%a][_%w]*)")
		if token == nil then return end
		self:processStatement(token)
		return true
	end
	return newScan	
end

------------------------------------
--Expression parser

------------------------------------
--Load input and specification files

symTab = require(extraxtArg("-l") or "language specification")
component = require(extraxtArg("-a") or "architecture specification")
specification = require(extraxtArg("-s") or "computer specification")
local inFile = assert(io.open(extraxtArg("-f") or dirpath.."input.txt"))
input = newScanner(inFile:read("*all"))
inFile:close()

------------------------------------
--Scan input, constructing AST
while input:getStatement() do end