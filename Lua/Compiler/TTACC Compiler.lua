-- for k, v in pairs(arg) do
--     print(tostring(k)..": "..tostring(v))
-- end

-- Add lib directory to path for require
local filepath = arg[0]
local _, dirpath, directorySeparator = string.find(filepath, ".*([\\/])")
dirpath = string.sub(filepath, 1, dirpath)
package.path = dirpath.."?.lua;"..package.path

local frame = require("lib.frame")
local hardware = require("hardware.core")


--Returns a new scanner object for s
local newScanner = function(s)
    local newScan = {cursorPos = 0, currLine = 1, s = s}
    function newScan:skipWhitespace()
        local c
        _, self.cursorPos, c = string.find(self.s, "[   ]*([^    ])", self.cursorPos)
        if self.cursorPos == nil then return end
        if c == ";" then --If c is a comment
            _, self.cursorPos = string.find(self.s, "\n", self.cursorPos)
            if self.cursorPos == nil then return end
        elseif c ~= "\n" then --If c is not a NL
            return c
        end
        -- c is a NL, or fallen through after skipping comment
		self.cursorPos=self.cursorPos+1
		self.currLine=self.currLine+1
		return self:skipWhitespace()
    end
    --Returns next token in s, skipping white space and new lines
    function newScan:getNextToken(pat)
		if not self:skipWhitespace() then return end
		-- match pattern pat else match not (WS or NL)
        local _, tokenEnd, c = string.find(self.s, pat or "([^  \n]+)", self.cursorPos)
        self.cursorPos = tokenEnd and tokenEnd+1 or self.cursorPos
        return c
    end
    --Return true if pattern pat will be matched
    function newScan:check(pat)
        if not self:skipWhitespace() then return end
        if string.find(self.s, pat, self.cursorPos) then return true end
    end
	--Abort unless expected string s is next
	function newScan:expect(s)
		if not self:getNextToken(--Escape any magic characters
			"^("..string.gsub(s, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")..")") then
            compilerError("expected \""..s.."\"")
		end
    end
	return newScan	
end


local inFile = assert(io.open(arg[1]))
local mainScanner = newScanner(inFile:read("*all"))
inFile:close()
local currentScanner = mainScanner

local compilerError = function(s)
    s = s or ""
    print("\nTTACC Compiler Error on line "..currentScanner.currLine)
    print("    "..s)
    os.exit()
end



local symbolTable = {}
local symbolType = {}

symbolType.DEF = "RESERVED"
function symbolTable.DEF()
    local name = currentScanner:getNextToken("^([_%a][_%w]*)")
    local defTable = {
        REGISTER = function()
            hardware:register(name)
            symbolTable[name] = value
            symbolType[name] = "REGISTER"
        end
    }
    if currentScanner:check("^{") then -- Is a literal
        local value = currentScanner:getNextToken("^(%b{})")
        local index = hardware:addLiteral(value)
        symbolType[name] = "LITERAL"
        symbolTable[name]= function()
            print("access literal["..index.."]")
        end
    else
        local value = currentScanner:getNextToken()
        if defTable[value] then
            defTable[value]()
        else
            compilerError("could not assign definition with \""..value.."\"")
        end
    end
end

-- expression   = term, (addop, term)*
-- term         = factor, (mulop, factor)*
-- factor       = LITERAL | ADDRESS | expression
local moves={}
symbolType.MOV = "RESERVED"
function symbolTable.MOV()
    currentScanner:expect("(")
    -- Get expression to move
    local from = currentScanner:getNextToken("^([^,]+)")
    local mov
    print("Moving "..from.." to")
    if string.find(from, "^{") then -- Is literal
        mov = {"LITERAL", hardware:addLiteral(from)}
    else
        if not symbolType[from] then compilerError("attempted MOV from unrecognised source: "..from) end
        mov = {"ADDRESS", from}
    end
    while currentScanner:getNextToken("^(,)") do -- While destinations to move to
        local to = currentScanner:getNextToken("^([_%a][_%w]*)")
        print(to)
        if not symbolType[to] then compilerError("attempted MOV to unrecognised destination: "..to) end
        table.insert(mov, "ADDRESS")
        table.insert(mov, to)
    end
    currentScanner:expect(")")
    table.insert(moves, mov)
end


local token = currentScanner:getNextToken("^([_%a][_%w]*)")
while token do
    -- print(token)
    if symbolTable[token] then
        symbolTable[token]()
    else
        compilerError("urecognised token \""..token.."\"")
    end
    token = currentScanner:getNextToken("^([_%a][_%w]*)")
end

print("Hardware:\n    Address:")
for i = 1, #hardware.address do
    print("        "..i..": "..hardware.address[i][1].." "..hardware.address[i][2])
end
if #hardware.literal > 0 then
    print("    Literal:")
    for i = 1, #hardware.literal do
        print("        "..i..": "..string.gsub(tostring(hardware.literal[i]), "\n", "\n           "))
    end
end
print("moves:")
for i=1, #moves do
    for j=1, #moves[i] do
        io.write(moves[i][j]..", ")
    end
    print()
end