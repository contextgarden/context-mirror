if not modules then modules = { } end modules ['luat-sto'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next = type, next
local gmatch, format, write_nl = string.gmatch, string.format, texio.write_nl

storage            = storage or { }
storage.min        = 0 -- 500
storage.max        = storage.min - 1
storage.noftables  = storage.noftables or 0
storage.nofmodules = storage.nofmodules or 0
storage.data       = { }
storage.evaluators = { }

local evaluators = storage.evaluators -- (evaluate,message,names)
local data       = storage.data

function storage.register(...)
    data[#data+1] = { ... }
end

-- evaluators .. messy .. to be redone

function storage.evaluate(name)
    evaluators[#evaluators+1] = name
end

function storage.finalize() -- we can prepend the string with "evaluate:"
    for i=1,#evaluators do
        local t = evaluators[i]
        for i, v in next, t do
            local tv = type(v)
            if tv == "string" then
                t[i] = loadstring(v)()
            elseif tv == "table" then
                for _, vv in next, v do
                    if type(vv) == "string" then
                        t[i] = loadstring(vv)()
                    end
                end
            elseif tv == "function" then
                t[i] = v()
            end
        end
    end
end

function storage.dump()
    for i=1,#data do
        local d = data[i]
        local message, original, target, evaluate = d[1], d[2] ,d[3] ,d[4]
        local name, initialize, finalize, code = nil, "", "", ""
        for str in gmatch(target,"([^%.]+)") do
            if name then
                name = name .. "." .. str
            else
                name = str
            end
            initialize = format("%s %s = %s or {} ", initialize, name, name)
        end
        if evaluate then
            finalize = "storage.evaluate(" .. name .. ")"
        end
        storage.max = storage.max + 1
        if trace_storage then
            logs.report('storage','saving %s in slot %s',message,storage.max)
            code =
                initialize ..
                format("logs.report('storage','restoring %s from slot %s') ",message,storage.max) ..
                table.serialize(original,name) ..
                finalize
        else
            code = initialize .. table.serialize(original,name) .. finalize
        end
        lua.bytecode[storage.max] = loadstring(code)
        collectgarbage("step")
    end
end

-- we also need to count at generation time (nicer for message)

if lua.bytecode then -- from 0 upwards
    local i, b = storage.min, lua.bytecode
    while b[i] do
        storage.noftables = i
        b[i]()
        b[i] = nil
        i = i + 1
    end
end

statistics.register("stored bytecode data", function()
    local modules = (storage.nofmodules > 0 and storage.nofmodules) or (status.luabytecodes - 500)
    local dumps = (storage.noftables > 0 and storage.noftables) or storage.max-storage.min + 1
    return format("%s modules, %s tables, %s chunks",modules,dumps,modules+dumps)
end)

if lua.bytedata then
    storage.register("lua/bytedata",lua.bytedata,"lua.bytedata")
end

-- wrong place, kind of forward reference

function statistics.report_storage(whereto)
    whereto = whereto or "term and log"
    write_nl(whereto," ","stored tables:"," ")
    for k,v in table.sortedpairs(storage.data) do
        write_nl(whereto,format("%03i %s",k,v[1]))
    end
    write_nl(whereto," ","stored modules:"," ")
    for k,v in table.sortedpairs(lua.bytedata) do
        write_nl(whereto,format("%03i %s %s",k,v[2],v[1]))
    end
    write_nl(whereto," ","stored attributes:"," ")
    for k,v in table.sortedpairs(attributes.names) do
        write_nl(whereto,format("%03i %s",k,v))
    end
    write_nl(whereto," ","stored catcodetables:"," ")
    for k,v in table.sortedpairs(catcodes.names) do
        write_nl(whereto,format("%03i %s",k,v))
    end
    write_nl(whereto," ")
end

storage.shared = storage.shared or { }

-- Because the storage mechanism assumes tables, we define a table for storing
-- (non table) values.

storage.register("storage/shared", storage.shared, "storage.shared")
