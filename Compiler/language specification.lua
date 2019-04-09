------------------------------------
-- Language container creation

local lang = {_type = {}}
local contents = {}
lang.__index = contents
lang.__newindex = function(k, v)
    if contents[k] then
        abort("Symbol \""..k.."\" has already been defined")
    end
    contents[k] = v
    if string.find(k, "^R[%d]+") then
        lang._type[k] = "register"
    elseif string.find(k, "^RAM[%d]+") then
        lang._type[k] = "RAM"
    else
        lang._type[k] = "reserved"
    end
end
setmetatable(lang, lang)

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
        if not lang._type[token] then
            abort("identifier \""..token.."\" not recognised")
        end
        if lang._type[token] == "RAM" then
            input:expect("[")
            local addr = parse.expression()
            input:expect("]")
            token = constructAST.writeRAM(token, addr)
        end
        table.insert(ident, token)
    until not input:getNextToken("^(,)")
    input:expect(")")
    constructAST.move(value, ident)
end

return lang