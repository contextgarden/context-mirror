if not modules then modules = { } end modules ['util-tab'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities        = utilities or {}
utilities.tables = utilities.tables or { }
local tables     = utilities.tables

local format, gmatch, rep, gsub = string.format, string.gmatch, string.rep, string.gsub
local concat, insert, remove = table.concat, table.insert, table.remove
local setmetatable, getmetatable, tonumber, tostring = setmetatable, getmetatable, tonumber, tostring
local type, next, rawset, tonumber, load, select = type, next, rawset, tonumber, load, select
local lpegmatch, P, Cs = lpeg.match, lpeg.P, lpeg.Cs
local serialize = table.serialize

local splitter = lpeg.tsplitat(".")

function tables.definetable(target,nofirst,nolast) -- defines undefined tables
    local composed, shortcut, t = nil, nil, { }
    local snippets = lpegmatch(splitter,target)
    for i=1,#snippets - (nolast and 1 or 0) do
        local name = snippets[i]
        if composed then
            composed = shortcut .. "." .. name
            shortcut = shortcut .. "_" .. name
            t[#t+1] = format("local %s = %s if not %s then %s = { } %s = %s end",shortcut,composed,shortcut,shortcut,composed,shortcut)
        else
            composed = name
            shortcut = name
            if not nofirst then
                t[#t+1] = format("%s = %s or { }",composed,composed)
            end
        end
    end
    if nolast then
        composed = shortcut .. "." .. snippets[#snippets]
    end
    return concat(t,"\n"), composed
end

-- local t = tables.definedtable("a","b","c","d")

function tables.definedtable(...)
    local t = _G
    for i=1,select("#",...) do
        local li = select(i,...)
        local tl = t[li]
        if not tl then
            tl = { }
            t[li] = tl
        end
        t = tl
    end
    return t
end

function tables.accesstable(target,root)
    local t = root or _G
    for name in gmatch(target,"([^%.]+)") do
        t = t[name]
        if not t then
            return
        end
    end
    return t
end

function tables.migratetable(target,v,root)
    local t = root or _G
    local names = string.split(target,".")
    for i=1,#names-1 do
        local name = names[i]
        t[name] = t[name] or { }
        t = t[name]
        if not t then
            return
        end
    end
    t[names[#names]] = v
end

function tables.removevalue(t,value) -- todo: n
    if value then
        for i=1,#t do
            if t[i] == value then
                remove(t,i)
                -- remove all, so no: return
            end
        end
    end
end

function tables.insertbeforevalue(t,value,extra)
    for i=1,#t do
        if t[i] == extra then
            remove(t,i)
        end
    end
    for i=1,#t do
        if t[i] == value then
            insert(t,i,extra)
            return
        end
    end
    insert(t,1,extra)
end

function tables.insertaftervalue(t,value,extra)
    for i=1,#t do
        if t[i] == extra then
            remove(t,i)
        end
    end
    for i=1,#t do
        if t[i] == value then
            insert(t,i+1,extra)
            return
        end
    end
    insert(t,#t+1,extra)
end

-- experimental

local function toxml(t,d,result,step)
    for k, v in table.sortedpairs(t) do
        if type(v) == "table" then
            if type(k) == "number" then
                result[#result+1] = format("%s<entry n='%s'>",d,k)
                toxml(v,d..step,result,step)
                result[#result+1] = format("%s</entry>",d,k)
            else
                result[#result+1] = format("%s<%s>",d,k)
                toxml(v,d..step,result,step)
                result[#result+1] = format("%s</%s>",d,k)
            end
        elseif type(k) == "number" then
            result[#result+1] = format("%s<entry n='%s'>%s</entry>",d,k,v,k)
        else
            result[#result+1] = format("%s<%s>%s</%s>",d,k,tostring(v),k)
        end
    end
end

function table.toxml(t,name,nobanner,indent,spaces)
    local noroot = name == false
    local result = (nobanner or noroot) and { } or { "<?xml version='1.0' standalone='yes' ?>" }
    local indent = rep(" ",indent or 0)
    local spaces = rep(" ",spaces or 1)
    if noroot then
        toxml( t, inndent, result, spaces)
    else
        toxml( { [name or "root"] = t }, indent, result, spaces)
    end
    return concat(result,"\n")
end

-- also experimental

-- encapsulate(table,utilities.tables)
-- encapsulate(table,utilities.tables,true)
-- encapsulate(table,true)

function tables.encapsulate(core,capsule,protect)
    if type(capsule) ~= "table" then
        protect = true
        capsule = { }
    end
    for key, value in next, core do
        if capsule[key] then
            print(format("\ninvalid inheritance '%s' in '%s': %s",key,tostring(core)))
            os.exit()
        else
            capsule[key] = value
        end
    end
    if protect then
        for key, value in next, core do
            core[key] = nil
        end
        setmetatable(core, {
            __index = capsule,
            __newindex = function(t,key,value)
                if capsule[key] then
                    print(format("\ninvalid overload '%s' in '%s'",key,tostring(core)))
                    os.exit()
                else
                    rawset(t,key,value)
                end
            end
        } )
    end
end

local function fastserialize(t,r,outer) -- no mixes
    r[#r+1] = "{"
    local n = #t
    if n > 0 then
        for i=1,n do
            local v = t[i]
            local tv = type(v)
            if tv == "string" then
                r[#r+1] = format("%q,",v)
            elseif tv == "number" then
                r[#r+1] = format("%s,",v)
            elseif tv == "table" then
                fastserialize(v,r)
            elseif tv == "boolean" then
                r[#r+1] = format("%s,",tostring(v))
            end
        end
    else
        for k, v in next, t do
            local tv = type(v)
            if tv == "string" then
                r[#r+1] = format("[%q]=%q,",k,v)
            elseif tv == "number" then
                r[#r+1] = format("[%q]=%s,",k,v)
            elseif tv == "table" then
                r[#r+1] = format("[%q]=",k)
                fastserialize(v,r)
            elseif tv == "boolean" then
                r[#r+1] = format("[%q]=%s,",k,tostring(v))
            end
        end
    end
    if outer then
        r[#r+1] = "}"
    else
        r[#r+1] = "},"
    end
    return r
end

-- local f_hashed_string  = formatters["[%q]=%q,"]
-- local f_hashed_number  = formatters["[%q]=%s,"]
-- local f_hashed_table   = formatters["[%q]="]
-- local f_hashed_true    = formatters["[%q]=true,"]
-- local f_hashed_false   = formatters["[%q]=false,"]
--
-- local f_indexed_string = formatters["%q,"]
-- local f_indexed_number = formatters["%s,"]
-- ----- f_indexed_true   = formatters["true,"]
-- ----- f_indexed_false  = formatters["false,"]
--
-- local function fastserialize(t,r,outer) -- no mixes
--     r[#r+1] = "{"
--     local n = #t
--     if n > 0 then
--         for i=1,n do
--             local v = t[i]
--             local tv = type(v)
--             if tv == "string" then
--                 r[#r+1] = f_indexed_string(v)
--             elseif tv == "number" then
--                 r[#r+1] = f_indexed_number(v)
--             elseif tv == "table" then
--                 fastserialize(v,r)
--             elseif tv == "boolean" then
--              -- r[#r+1] = v and f_indexed_true(k) or f_indexed_false(k)
--                 r[#r+1] = v and "true," or "false,"
--             end
--         end
--     else
--         for k, v in next, t do
--             local tv = type(v)
--             if tv == "string" then
--                 r[#r+1] = f_hashed_string(k,v)
--             elseif tv == "number" then
--                 r[#r+1] = f_hashed_number(k,v)
--             elseif tv == "table" then
--                 r[#r+1] = f_hashed_table(k)
--                 fastserialize(v,r)
--             elseif tv == "boolean" then
--                 r[#r+1] = v and f_hashed_true(k) or f_hashed_false(k)
--             end
--         end
--     end
--     if outer then
--         r[#r+1] = "}"
--     else
--         r[#r+1] = "},"
--     end
--     return r
-- end

function table.fastserialize(t,prefix) -- so prefix should contain the =
    return concat(fastserialize(t,{ prefix or "return" },true))
end

function table.deserialize(str)
    if not str or str == "" then
        return
    end
    local code = load(str)
    if not code then
        return
    end
    code = code()
    if not code then
        return
    end
    return code
end

-- inspect(table.fastserialize { a = 1, b = { 4, { 5, 6 } }, c = { d = 7, e = 'f"g\nh' } })

function table.load(filename)
    if filename then
        local t = io.loaddata(filename)
        if t and t ~= "" then
            t = load(t)
            if type(t) == "function" then
                t = t()
                if type(t) == "table" then
                    return t
                end
            end
        end
    end
end

function table.save(filename,t,n,...)
    io.savedata(filename,serialize(t,n == nil and true or n,...))
end

local function slowdrop(t)
    local r = { }
    local l = { }
    for i=1,#t do
        local ti = t[i]
        local j = 0
        for k, v in next, ti do
            j = j + 1
            l[j] = format("%s=%q",k,v)
        end
        r[i] = format(" {%s},\n",concat(l))
    end
    return format("return {\n%s}",concat(r))
end

local function fastdrop(t)
    local r = { "return {\n" }
    for i=1,#t do
        local ti = t[i]
        r[#r+1] = " {"
        for k, v in next, ti do
            r[#r+1] = format("%s=%q",k,v)
        end
        r[#r+1] = "},\n"
    end
    r[#r+1] = "}"
    return concat(r)
end

function table.drop(t,slow)
    if #t == 0 then
        return "return { }"
    elseif slow == true then
        return slowdrop(t) -- less memory
    else
        return fastdrop(t) -- some 15% faster
    end
end

function table.autokey(t,k)
    local v = { }
    t[k] = v
    return v
end
