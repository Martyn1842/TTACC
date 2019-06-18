local subDirs = { --subdirectories to search
    "signal",
    "item",
    "fluid"
}
local blacklist = { --properties to blacklist
    types = {"item-group", "item-subgroup"},
    subgroups = {"virtual-signal-special"}
}
local search = "gu" --search collected names for search string
local verbose = false --if true print debug info
--257 signals at last count

if not arg[1] then
    error("no target directory specified")
end

local oldPrint = print
print = function(s)
    if verbose then
        oldPrint(s)
    end
end
setmetatable(_G, getmetatable(_G) or {})
getmetatable(_G).__index = function(t, k)
    print("attempted to access undefined global \""..k.."\"")
    return function() return false end
end

local oldRequire = require
require = function() end
local oldPath = package.path
package.path = arg[1].."?.lua;"..oldPath

function contains(t, s)
    for i = 1, #t do
        if t[i] == s then
            return true
        end
    end
    return false
end
data = {}
function data:extend(t)
    for i = 1, #t do
        if not (
            contains(blacklist.types, t[i].type)
            or contains(blacklist.subgroups, t[i].subgroup)
            or (t[i].flags and contains(t[i].flags, "hidden"))
        ) then
            table.insert(data, t[i].name)
            if t[i].type == "fluid" 
            and (t[i].auto_barrel == nil or t[i].auto_barrel ~= false) then
                table.insert(data, t[i].name.."-barrel")
            end
        end
    end
end

getmetatable(_G).__newindex = function(t, k, v)
    if k == "_" then
        rawset(t, k, v)
    else
        print("created global variable \""..k.."\"")
        rawset(t, k, v)
    end
end

local scanSubDir = function(subDir)
    for filename in io.popen('dir "'..arg[1]..'\\'..subDir..'"'):lines() do
        if filename:sub(filename:len()-3, filename:len()) == ".lua" then
            _, _, filename = string.find(filename, "([^ ]+)%.lua")
            print(filename)
            pcall(oldRequire, "."..subDir.."."..filename)
        end
    end
end

for _, subDir in ipairs(subDirs) do
    scanSubDir(subDir)
end

print("\n=>\n")
for i = 1, #data do
    print(data[i])
end

print("\n"..#data.."\n\""..search.."\"\n=>\n")
for i = 1, #data do
    if string.find(data[i], search) then
        print(data[i])
    end
end

local dirpath = arg[0]
_, _, dirpath = string.find(dirpath, "(.+[\\/])")
local f = assert(io.open(dirpath.."lib/signalIDs.lua", "w"))
f:write("--A dictionary of valid signalIDs\n--Contains "..#data.." signalIDs\n")
f:write("--Test if \"signalID[name]\" is true to confirm \"name\" is a valid signal type\n")
f:write("--Signal types are in alphabetical order and have value N for N-th type\n")
f:write("--This is for creation of unique integer dictionaries (eg. \"a\": 1, \"b\": 2, \"c\": 3, etc)\n")
f:write("return {\n")
if data[1] then
    table.sort(data)
    f:write("  [\""..data[1].."\"] = 1")
    for i = 2, #data do
        f:write(",\n  [\""..data[i].."\"] = "..i)
    end
end
f:write("\n}")
f:close()