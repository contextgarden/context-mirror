if not modules then modules = { } end modules ['luat-sto'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we could nil some function in the productionrun

local type, next, setmetatable, getmetatable, collectgarbage = type, next, setmetatable, getmetatable, collectgarbage
local gmatch, format, write_nl = string.gmatch, string.format, texio.write_nl
local serialize, concat, sortedhash = table.serialize, table.concat, table.sortedhash
local bytecode = lua.bytecode

local report_storage = logs.reporter("system","storage")

storage            = storage or { }
local storage      = storage

local data         = { }
storage.data       = data

local evaluators   = { }
storage.evaluators = evaluators

storage.min        = 0 -- 500
storage.max        = storage.min - 1
storage.noftables  = storage.noftables or 0
storage.nofmodules = storage.nofmodules or 0

storage.mark       = utilities.storage.mark
storage.allocate   = utilities.storage.allocate
storage.marked     = utilities.storage.marked

function storage.register(...)
    local t = { ... }
    local d = t[2]
    if d then
        storage.mark(d)
    else
        report_storage("fatal error: invalid storage '%s'",t[1])
        os.exit()
    end
    data[#data+1] = t
    return t
end

local function dump()
    local max = storage.max
    for i=1,#data do
        local d = data[i]
        local message, original, target = d[1], d[2] ,d[3]
        local c, code, name = 0, { }, nil
        for str in gmatch(target,"([^%.]+)") do
            if name then
                name = name .. "." .. str
            else
                name = str
            end
            c = c + 1 ; code[c] = format("%s = %s or { }",name,name)
        end
        max = max + 1
        if trace_storage then
            report_storage('saving %s in slot %s',message,max)
            c = c + 1 ; code[c] = format("report_storage('restoring %s from slot %s')",message,max)
        end
        c = c + 1 ; code[c] = serialize(original,name)
        bytecode[max] = loadstring(concat(code,"\n"))
        collectgarbage("step")
    end
    storage.max = max
end

lua.registerfinalizer(dump,"dump storage")

-- to be tested with otf caching:

function lua.collectgarbage(threshold)
    local current = collectgarbage("count")
    local threshold = threshold or 256 * 1024
    while true do
        collectgarbage("collect")
        local previous = collectgarbage("count")
        if current - previous < threshold then
            break
        else
            current = previous
        end
    end
end

-- we also need to count at generation time (nicer for message)

--~ if lua.bytecode then -- from 0 upwards
--~     local i, b = storage.min, lua.bytecode
--~     while b[i] do
--~         storage.noftables = i
--~         b[i]()
--~         b[i] = nil
--~         i = i + 1
--~     end
--~ end

statistics.register("stored bytecode data", function()
    local modules = (storage.nofmodules > 0 and storage.nofmodules) or (status.luabytecodes - lua.firstbytecode - 1)
    local dumps = (storage.noftables > 0 and storage.noftables) or storage.max-storage.min + 1
    return format("%s modules, %s tables, %s chunks",modules,dumps,modules+dumps)
end)

if lua.bytedata then
    storage.register("lua/bytedata",lua.bytedata,"lua.bytedata")
end

function statistics.reportstorage(whereto)
    whereto = whereto or "term and log"
    write_nl(whereto," ","stored tables:"," ")
    for k,v in sortedhash(storage.data) do
        write_nl(whereto,format("%03i %s",k,v[1]))
    end
    write_nl(whereto," ","stored modules:"," ")
    for k,v in sortedhash(lua.bytedata) do
        write_nl(whereto,format("%03i %s %s",k,v[2],v[1]))
    end
    write_nl(whereto," ","stored attributes:"," ")
    for k,v in sortedhash(attributes.names) do
        write_nl(whereto,format("%03i %s",k,v))
    end
    write_nl(whereto," ","stored catcodetables:"," ")
    for k,v in sortedhash(catcodes.names) do
        write_nl(whereto,format("%03i %s",k,concat(v," ")))
    end
    write_nl(whereto," ","used corenamespaces:"," ")
    for k,v in sortedhash(interfaces.corenamespaces) do
        write_nl(whereto,format("%03i %s",k,v))
    end
    write_nl(whereto," ")
end

storage.shared = storage.shared or { }

-- Because the storage mechanism assumes tables, we define a table for storing
-- (non table) values.

storage.register("storage/shared", storage.shared, "storage.shared")

local mark  = storage.mark

if string.patterns     then                               mark(string.patterns)     end
if lpeg.patterns       then                               mark(lpeg.patterns)       end
if os.env              then                               mark(os.env)              end
if number.dimenfactors then                               mark(number.dimenfactors) end
if libraries           then for k,v in next, libraries do mark(v)                   end end
