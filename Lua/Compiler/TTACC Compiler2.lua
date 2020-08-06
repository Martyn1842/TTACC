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

compilerError = function(s)
    s = s or ""
    print("\nTTACC Compiler: Error on line "..currentScanner.currLine)
    print("    "..s)
    os.exit()
end

-- Define hardware


local symbolTable = {}
local symbolType  = {}

symbolType['#DEF'] = "RESERVED"
symbolTable['#DEF'] = function()
    local name = currentScanner:getNextToken("^([_%a][_%w]*)")
    local value = currentScanner:getNextToken()
    if name == "DATALANES" then
        hardware.dataLanes = tonumber(value)
    elseif hardware[value] then
        hardware[value](hardware, name)
        -- hardware:register(name)
        symbolTable[name] = value
        symbolType[name] = value
    else
        compilerError("could not assign definition with \""..value.."\"")
    end
end





local token = currentScanner:getNextToken("^([#_%a][_%w]*)")
while token do
    -- print(token)
    if symbolTable[token] then
        symbolTable[token]()
    else
        compilerError("urecognised token \""..token.."\"")
    end
    token = currentScanner:getNextToken("^([#_%a][_%w]*)")
end


print("Hardware:\n    Data lanes: "..hardware.dataLanes.."\n    Address:")
for i = 1, #hardware.address do
    print("        "..i..": "..hardware.address[i][1].." "..hardware.address[i][2])
end
if #hardware.literal > 0 then
    print("    Literal:")
    for i = 1, #hardware.literal do
        print("        "..i..": "..string.gsub(tostring(hardware.literal[i]), "\n", "\n           "))
    end
end