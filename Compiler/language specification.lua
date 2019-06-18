------------------------------------
-- Language container creation

local lang = {__type = {}}
local contents = {}
lang.__index = contents
lang.__newindex = function(t, k, v)
    if contents[k] then
        abort("Symbol \""..k.."\" has already been defined")
    end
    contents[k] = v
    if string.find(k, "^R[%d]+") then
        t.__type[k] = "register"
    elseif string.find(k, "^RAM[%d]+") then
        t.__type[k] = "RAM"
    else
        t.__type[k] = "reserved"
    end
end
setmetatable(lang, lang)

local parse = {}
parse.expression = function()
    local res = {}
    repeat
        table.insert(res, input:getNextToken("^([_%a][_%w]*)"))
    until not input:getNextToken("^(+)")
    return res
end

------------------------------------
-- Language description

lang["MOV"] = function() --MOV(a+b+c, x, y, z) -> x, y, z = a+b+c
    input:expect("(")
    local value = parse.expression()
    input:expect(",")
    local ident = {}
    repeat --Get destination identifiers
        local token = input:getNextToken("^([_%a][_%w]*)") or
            abort("invalid identifier \""..input:getNextToken("^([_%w]+)").."\"")
        if not lang[token] then
            abort("identifier \""..token.."\" not recognised")
        end
        if lang.__type[token] == "RAM" then
            input:expect("[")
            local addr = parse.expression()
            input:expect("]")
            token = currAST:writeRAM(token, addr)
        end
        table.insert(ident, token)
    until not input:getNextToken("^(,)")
    input:expect(")")
    currAST:move(value, ident)
end

return lang