#!/usr/bin/env texlua

if not modules then modules = { } end modules ['mtxrun'] = {
    version   = 1.001,
    comment   = "runner, lua replacement for texmfstart.rb",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- one can make a stub:
--
-- #!/bin/sh
-- env LUATEXDIR=/....../texmf/scripts/context/lua luatex --luaonly mtxrun.lua "$@"

-- filename : mtxrun.lua
-- comment  : companion to context.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- This script is based on texmfstart.rb but does not use kpsewhich to
-- locate files. Although kpse is a library it never came to opening up
-- its interface to other programs (esp scripting languages) and so we
-- do it ourselves. The lua variant evolved out of an experimental ruby
-- one. Interesting is that using a scripting language instead of c does
-- not have a speed penalty. Actually the lua variant is more efficient,
-- especially when multiple calls to kpsewhich are involved. The lua
-- library also gives way more control.

-- to be done / considered
--
-- support for --exec or make it default
-- support for jar files (or maybe not, never used, too messy)
-- support for $RUBYINPUTS cum suis (if still needed)
-- remember for subruns: _CTX_K_V_#{original}_
-- remember for subruns: _CTX_K_S_#{original}_
-- remember for subruns: TEXMFSTART.#{original} [tex.rb texmfstart.rb]

-- begin library merge



do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-string'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local string = string
local sub, gsub, find, match, gmatch, format, char, byte, rep, lower = string.sub, string.gsub, string.find, string.match, string.gmatch, string.format, string.char, string.byte, string.rep, string.lower
local lpegmatch, S, C, Ct = lpeg.match, lpeg.S, lpeg.C, lpeg.Ct

-- some functions may disappear as they are not used anywhere

if not string.split then

    -- this will be overloaded by a faster lpeg variant

    function string.split(str,pattern)
        local t = { }
        if #str > 0 then
            local n = 1
            for s in gmatch(str..pattern,"(.-)"..pattern) do
                t[n] = s
                n = n + 1
            end
        end
        return t
    end

end

function string.unquoted(str)
    return (gsub(str,"^([\"\'])(.*)%1$","%2"))
end


function string.quoted(str)
    return format("%q",str) -- always "
end

function string.count(str,pattern) -- variant 3
    local n = 0
    for _ in gmatch(str,pattern) do -- not for utf
        n = n + 1
    end
    return n
end

function string.limit(str,n,sentinel) -- not utf proof
    if #str > n then
        sentinel = sentinel or "..."
        return sub(str,1,(n-#sentinel)) .. sentinel
    else
        return str
    end
end

local space    = S(" \t\v\n")
local nospace  = 1 - space
local stripper = space^0 * C((space^0 * nospace^1)^0) -- roberto's code

function string.strip(str)
    return lpegmatch(stripper,str) or ""
end

function string.is_empty(str)
    return not find(str,"%S")
end

local patterns_escapes = {
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%(", [")"] = "%)",
 -- ["{"] = "%{", ["}"] = "%}"
 -- ["^"] = "%^", ["$"] = "%$",
}

local simple_escapes = {
    ["-"] = "%-",
    ["."] = "%.",
    ["?"] = ".",
    ["*"] = ".*",
}

function string.escapedpattern(str,simple)
    return (gsub(str,".",simple and simple_escapes or patterns_escapes))
end

function string.topattern(str,lowercase,strict)
    if str == "" then
        return ".*"
    else
        str = gsub(str,".",simple_escapes)
        if lowercase then
            str = lower(str)
        end
        if strict then
            return "^" .. str .. "$"
        else
            return str
        end
    end
end

-- obsolete names:

string.quote   = string.quoted
string.unquote = string.unquoted


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-table'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tostring, tonumber, ipairs, table, string = type, next, tostring, tonumber, ipairs, table, string
local concat, sort, insert, remove = table.concat, table.sort, table.insert, table.remove
local format, find, gsub, lower, dump, match = string.format, string.find, string.gsub, string.lower, string.dump, string.match
local getmetatable, setmetatable = getmetatable, setmetatable
local getinfo = debug.getinfo

-- Starting with version 5.2 Lua no longer provide ipairs, which makes
-- sense. As we already used the for loop and # in most places the
-- impact on ConTeXt was not that large; the remaining ipairs already
-- have been replaced. In a similar fashion we also hardly used pairs.
--
-- Just in case, we provide the fallbacks as discussed in Programming
-- in Lua (http://www.lua.org/pil/7.3.html):

if not ipairs then

    -- for k, v in ipairs(t) do                ... end
    -- for k=1,#t            do local v = t[k] ... end

    local function iterate(a,i)
        i = i + 1
        local v = a[i]
        if v ~= nil then
            return i, v --, nil
        end
    end

    function ipairs(a)
        return iterate, a, 0
    end

end

if not pairs then

    -- for k, v in pairs(t) do ... end
    -- for k, v in next, t  do ... end

    function pairs(t)
        return next, t -- , nil
    end

end

-- Also, unpack has been moved to the table table, and for compatiility
-- reasons we provide both now.

if not table.unpack then
    table.unpack = _G.unpack
elseif not unpack then
    _G.unpack = table.unpack
end

-- extra functions, some might go (when not used)

function table.strip(tab)
    local lst, l = { }, 0
    for i=1,#tab do
        local s = gsub(tab[i],"^%s*(.-)%s*$","%1")
        if s == "" then
            -- skip this one
        else
            l = l + 1
            lst[l] = s
        end
    end
    return lst
end

function table.keys(t)
    local keys, k = { }, 0
    for key, _ in next, t do
        k = k + 1
        keys[k] = key
    end
    return keys
end

local function compare(a,b)
    local ta, tb = type(a), type(b) -- needed, else 11 < 2
    if ta == tb then
        return a < b
    else
        return tostring(a) < tostring(b)
    end
end

local function sortedkeys(tab)
    local srt, category, s = { }, 0, 0 -- 0=unknown 1=string, 2=number 3=mixed
    for key,_ in next, tab do
        s = s + 1
        srt[s] = key
        if category == 3 then
            -- no further check
        else
            local tkey = type(key)
            if tkey == "string" then
                category = (category == 2 and 3) or 1
            elseif tkey == "number" then
                category = (category == 1 and 3) or 2
            else
                category = 3
            end
        end
    end
    if category == 0 or category == 3 then
        sort(srt,compare)
    else
        sort(srt)
    end
    return srt
end

local function sortedhashkeys(tab) -- fast one
    local srt, s = { }, 0
    for key,_ in next, tab do
        if key then
            s= s + 1
            srt[s] = key
        end
    end
    sort(srt)
    return srt
end

table.sortedkeys     = sortedkeys
table.sortedhashkeys = sortedhashkeys

local function nothing() end

local function sortedhash(t)
    if t then
        local n, s = 0, sortedkeys(t) -- the robust one
        local function kv(s)
            n = n + 1
            local k = s[n]
            return k, t[k]
        end
        return kv, s
    else
        return nothing
    end
end

table.sortedhash  = sortedhash
table.sortedpairs = sortedhash

function table.append(t, list)
    local n = #t
    for i=1,#list do
        n = n + 1
        t[n] = list[i]
    end
    return t
end

function table.prepend(t, list)
    local nl = #list
    local nt = nl + #t
    for i=#t,1,-1 do
        t[nt] = t[i]
        nt = nt - 1
    end
    for i=1,#list do
        t[i] = list[i]
    end
    return t
end

function table.merge(t, ...) -- first one is target
    t = t or { }
    local lst = { ... }
    for i=1,#lst do
        for k, v in next, lst[i] do
            t[k] = v
        end
    end
    return t
end

function table.merged(...)
    local tmp, lst = { }, { ... }
    for i=1,#lst do
        for k, v in next, lst[i] do
            tmp[k] = v
        end
    end
    return tmp
end

function table.imerge(t, ...)
    local lst, nt = { ... }, #t
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            nt = nt + 1
            t[nt] = nst[j]
        end
    end
    return t
end

function table.imerged(...)
    local tmp, ntmp, lst = { }, 0, {...}
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            ntmp = ntmp + 1
            tmp[ntmp] = nst[j]
        end
    end
    return tmp
end

local function fastcopy(old,metatabletoo) -- fast one
    if old then
        local new = { }
        for k,v in next, old do
            if type(v) == "table" then
                new[k] = fastcopy(v,metatabletoo) -- was just table.copy
            else
                new[k] = v
            end
        end
        if metatabletoo then
            -- optional second arg
            local mt = getmetatable(old)
            if mt then
                setmetatable(new,mt)
            end
        end
        return new
    else
        return { }
    end
end

-- todo : copy without metatable

local function copy(t, tables) -- taken from lua wiki, slightly adapted
    tables = tables or { }
    local tcopy = {}
    if not tables[t] then
        tables[t] = tcopy
    end
    for i,v in next, t do -- brrr, what happens with sparse indexed
        if type(i) == "table" then
            if tables[i] then
                i = tables[i]
            else
                i = copy(i, tables)
            end
        end
        if type(v) ~= "table" then
            tcopy[i] = v
        elseif tables[v] then
            tcopy[i] = tables[v]
        else
            tcopy[i] = copy(v, tables)
        end
    end
    local mt = getmetatable(t)
    if mt then
        setmetatable(tcopy,mt)
    end
    return tcopy
end

table.fastcopy = fastcopy
table.copy     = copy

function table.derive(parent)
    local child = { }
    if parent then
        setmetatable(child,{ __index = parent })
    end
    return child
end

function table.tohash(t,value)
    local h = { }
    if t then
        if value == nil then value = true end
        for _, v in next, t do -- no ipairs here
            h[v] = value
        end
    end
    return h
end

function table.fromhash(t)
    local hsh, h = { }, 0
    for k, v in next, t do -- no ipairs here
        if v then
            h = h + 1
            hsh[h] = k
        end
    end
    return hsh
end

local noquotes, hexify, handle, reduce, compact, inline, functions

local reserved = table.tohash { -- intercept a language inconvenience: no reserved words as key
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if',
    'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while',
}

local function simple_table(t)
    if #t > 0 then
        local n = 0
        for _,v in next, t do
            n = n + 1
        end
        if n == #t then
            local tt, nt = { }, 0
            for i=1,#t do
                local v = t[i]
                local tv = type(v)
                if tv == "number" then
                    nt = nt + 1
                    if hexify then
                        tt[nt] = format("0x%04X",v)
                    else
                        tt[nt] = tostring(v) -- tostring not needed
                    end
                elseif tv == "boolean" then
                    nt = nt + 1
                    tt[nt] = tostring(v)
                elseif tv == "string" then
                    nt = nt + 1
                    tt[nt] = format("%q",v)
                else
                    tt = nil
                    break
                end
            end
            return tt
        end
    end
    return nil
end

-- Because this is a core function of mkiv I moved some function calls
-- inline.
--
-- twice as fast in a test:
--
-- local propername = lpeg.P(lpeg.R("AZ","az","__") * lpeg.R("09","AZ","az", "__")^0 * lpeg.P(-1) )

-- problem: there no good number_to_string converter with the best resolution

local function dummy() end

local function do_serialize(root,name,depth,level,indexed)
    if level > 0 then
        depth = depth .. " "
        if indexed then
            handle(format("%s{",depth))
        else
            local tn = type(name)
            if tn == "number" then -- or find(k,"^%d+$") then
                if hexify then
                    handle(format("%s[0x%04X]={",depth,name))
                else
                    handle(format("%s[%s]={",depth,name))
                end
            elseif tn == "string" then
                if noquotes and not reserved[name] and find(name,"^%a[%w%_]*$") then
                    handle(format("%s%s={",depth,name))
                else
                    handle(format("%s[%q]={",depth,name))
                end
            elseif tn == "boolean" then
                handle(format("%s[%s]={",depth,tostring(name)))
            else
                handle(format("%s{",depth))
            end
        end
    end
    -- we could check for k (index) being number (cardinal)
    if root and next(root) then
        local first, last = nil, 0 -- #root cannot be trusted here (will be ok in 5.2 when ipairs is gone)
        if compact then
            -- NOT: for k=1,#root do (we need to quit at nil)
            for k,v in ipairs(root) do -- can we use next?
                if not first then first = k end
                last = last + 1
            end
        end
        local sk = sortedkeys(root)
        for i=1,#sk do
            local k = sk[i]
            local v = root[k]
                            -- circular
                        local t, tk = type(v), type(k)
            if compact and first and tk == "number" and k >= first and k <= last then
                if t == "number" then
                    if hexify then
                        handle(format("%s 0x%04X,",depth,v))
                    else
                        handle(format("%s %s,",depth,v)) -- %.99g
                    end
                elseif t == "string" then
                    if reduce and tonumber(v) then
                        handle(format("%s %s,",depth,v))
                    else
                        handle(format("%s %q,",depth,v))
                    end
                elseif t == "table" then
                    if not next(v) then
                        handle(format("%s {},",depth))
                    elseif inline then -- and #t > 0
                        local st = simple_table(v)
                        if st then
                            handle(format("%s { %s },",depth,concat(st,", ")))
                        else
                            do_serialize(v,k,depth,level+1,true)
                        end
                    else
                        do_serialize(v,k,depth,level+1,true)
                    end
                elseif t == "boolean" then
                    handle(format("%s %s,",depth,tostring(v)))
                elseif t == "function" then
                    if functions then
                        handle(format('%s loadstring(%q),',depth,dump(v)))
                    else
                        handle(format('%s "function",',depth))
                    end
                else
                    handle(format("%s %q,",depth,tostring(v)))
                end
            elseif k == "__p__" then -- parent
                if false then
                    handle(format("%s __p__=nil,",depth))
                end
            elseif t == "number" then
                if tk == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=0x%04X,",depth,k,v))
                    else
                        handle(format("%s [%s]=%s,",depth,k,v)) -- %.99g
                    end
                elseif tk == "boolean" then
                    if hexify then
                        handle(format("%s [%s]=0x%04X,",depth,tostring(k),v))
                    else
                        handle(format("%s [%s]=%s,",depth,tostring(k),v)) -- %.99g
                    end
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    if hexify then
                        handle(format("%s %s=0x%04X,",depth,k,v))
                    else
                        handle(format("%s %s=%s,",depth,k,v)) -- %.99g
                    end
                else
                    if hexify then
                        handle(format("%s [%q]=0x%04X,",depth,k,v))
                    else
                        handle(format("%s [%q]=%s,",depth,k,v)) -- %.99g
                    end
                end
            elseif t == "string" then
                if reduce and tonumber(v) then
                    if tk == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=%s,",depth,k,v))
                        else
                            handle(format("%s [%s]=%s,",depth,k,v))
                        end
                    elseif tk == "boolean" then
                        handle(format("%s [%s]=%s,",depth,tostring(k),v))
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=%s,",depth,k,v))
                    else
                        handle(format("%s [%q]=%s,",depth,k,v))
                    end
                else
                    if tk == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=%q,",depth,k,v))
                        else
                            handle(format("%s [%s]=%q,",depth,k,v))
                        end
                    elseif tk == "boolean" then
                        handle(format("%s [%s]=%q,",depth,tostring(k),v))
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=%q,",depth,k,v))
                    else
                        handle(format("%s [%q]=%q,",depth,k,v))
                    end
                end
            elseif t == "table" then
                if not next(v) then
                    if tk == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]={},",depth,k))
                        else
                            handle(format("%s [%s]={},",depth,k))
                        end
                    elseif tk == "boolean" then
                        handle(format("%s [%s]={},",depth,tostring(k)))
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s={},",depth,k))
                    else
                        handle(format("%s [%q]={},",depth,k))
                    end
                elseif inline then
                    local st = simple_table(v)
                    if st then
                        if tk == "number" then -- or find(k,"^%d+$") then
                            if hexify then
                                handle(format("%s [0x%04X]={ %s },",depth,k,concat(st,", ")))
                            else
                                handle(format("%s [%s]={ %s },",depth,k,concat(st,", ")))
                            end
                        elseif tk == "boolean" then -- or find(k,"^%d+$") then
                            handle(format("%s [%s]={ %s },",depth,tostring(k),concat(st,", ")))
                        elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                            handle(format("%s %s={ %s },",depth,k,concat(st,", ")))
                        else
                            handle(format("%s [%q]={ %s },",depth,k,concat(st,", ")))
                        end
                    else
                        do_serialize(v,k,depth,level+1)
                    end
                else
                    do_serialize(v,k,depth,level+1)
                end
            elseif t == "boolean" then
                if tk == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=%s,",depth,k,tostring(v)))
                    else
                        handle(format("%s [%s]=%s,",depth,k,tostring(v)))
                    end
                elseif tk == "boolean" then -- or find(k,"^%d+$") then
                    handle(format("%s [%s]=%s,",depth,tostring(k),tostring(v)))
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    handle(format("%s %s=%s,",depth,k,tostring(v)))
                else
                    handle(format("%s [%q]=%s,",depth,k,tostring(v)))
                end
            elseif t == "function" then
                if functions then
                    local f = getinfo(v).what == "C" and dump(dummy) or dump(v)
                 -- local f = getinfo(v).what == "C" and dump(function(...) return v(...) end) or dump(v)
                    if tk == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=loadstring(%q),",depth,k,f))
                        else
                            handle(format("%s [%s]=loadstring(%q),",depth,k,f))
                        end
                    elseif tk == "boolean" then
                        handle(format("%s [%s]=loadstring(%q),",depth,tostring(k),f))
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=loadstring(%q),",depth,k,f))
                    else
                        handle(format("%s [%q]=loadstring(%q),",depth,k,f))
                    end
                end
            else
                if tk == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=%q,",depth,k,tostring(v)))
                    else
                        handle(format("%s [%s]=%q,",depth,k,tostring(v)))
                    end
                elseif tk == "boolean" then -- or find(k,"^%d+$") then
                    handle(format("%s [%s]=%q,",depth,tostring(k),tostring(v)))
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    handle(format("%s %s=%q,",depth,k,tostring(v)))
                else
                    handle(format("%s [%q]=%q,",depth,k,tostring(v)))
                end
            end
                    end
    end
   if level > 0 then
        handle(format("%s},",depth))
    end
end

-- replacing handle by a direct t[#t+1] = ... (plus test) is not much
-- faster (0.03 on 1.00 for zapfino.tma)

local function serialize(_handle,root,name,specification) -- handle wins
    local tname = type(name)
    if type(specification) == "table" then
        noquotes  = specification.noquotes
        hexify    = specification.hexify
        handle    = _handle or specification.handle or print
        reduce    = specification.reduce or false
        functions = specification.functions
        compact   = specification.compact
        inline    = specification.inline and compact
        if functions == nil then
            functions = true
        end
        if compact == nil then
            compact = true
        end
        if inline == nil then
            inline = compact
        end
    else
        noquotes  = false
        hexify    = false
        handle    = _handle or print
        reduce    = false
        compact   = true
        inline    = true
        functions = true
    end
    if tname == "string" then
        if name == "return" then
            handle("return {")
        else
            handle(name .. "={")
        end
    elseif tname == "number" then
        if hexify then
            handle(format("[0x%04X]={",name))
        else
            handle("[" .. name .. "]={")
        end
    elseif tname == "boolean" then
        if name then
            handle("return {")
        else
            handle("{")
        end
    else
        handle("t={")
    end
    if root then
        -- The dummy access will initialize a table that has a delayed initialization
        -- using a metatable. (maybe explicitly test for metatable)
        if getmetatable(root) then -- todo: make this an option, maybe even per subtable
            local dummy = root._w_h_a_t_e_v_e_r_
            root._w_h_a_t_e_v_e_r_ = nil
        end
        -- Let's forget about empty tables.
        if next(root) then
            do_serialize(root,name,"",0)
        end
    end
    handle("}")
end


function table.serialize(root,name,specification)
    local t, n = { }, 0
    local function flush(s)
        n = n + 1
        t[n] = s
    end
    serialize(flush,root,name,specification)
    return concat(t,"\n")
end

table.tohandle = serialize

-- sometimes tables are real use (zapfino extra pro is some 85M) in which
-- case a stepwise serialization is nice; actually, we could consider:
--
-- for line in table.serializer(root,name,reduce,noquotes) do
--    ...(line)
-- end
--
-- so this is on the todo list

local maxtab = 2*1024

function table.tofile(filename,root,name,specification)
    local f = io.open(filename,'w')
    if f then
        if maxtab > 1 then
            local t, n = { }, 0
            local function flush(s)
                n = n + 1
                t[n] = s
                if n > maxtab then
                    f:write(concat(t,"\n"),"\n") -- hm, write(sometable) should be nice
                    t, n = { }, 0 -- we could recycle t if needed
                end
            end
            serialize(flush,root,name,specification)
            f:write(concat(t,"\n"),"\n")
        else
            local function flush(s)
                f:write(s,"\n")
            end
            serialize(flush,root,name,specification)
        end
        f:close()
        io.flush()
    end
end

local function flattened(t,f,depth)
    if f == nil then
        f = { }
        depth = 0xFFFF
    elseif tonumber(f) then
        -- assume then only two arguments are given
        depth = f
        f = { }
    elseif not depth then
        depth = 0xFFFF
    end
    for k, v in next, t do
        if type(k) ~= "number" then
            if depth > 0 and type(v) == "table" then
                flattened(v,f,depth-1)
            else
                f[k] = v
            end
        end
    end
    local n = #f
    for k=1,#t do
        local v = t[k]
        if depth > 0 and type(v) == "table" then
            flattened(v,f,depth-1)
            n = #f
        else
            n = n + 1
            f[n] = v
        end
    end
    return f
end

table.flattened = flattened

local function unnest(t,f) -- only used in mk, for old times sake
    if not f then          -- and only relevant for token lists
        f = { }
    end
    for i=1,#t do
        local v = t[i]
        if type(v) == "table" then
            if type(v[1]) == "table" then
                unnest(v,f)
            else
                f[#f+1] = v
            end
        else
            f[#f+1] = v
        end
    end
    return f
end

function table.unnest(t) -- bad name
    return unnest(t)
end

local function are_equal(a,b,n,m) -- indexed
    if a and b and #a == #b then
        n = n or 1
        m = m or #a
        for i=n,m do
            local ai, bi = a[i], b[i]
            if ai==bi then
                -- same
            elseif type(ai)=="table" and type(bi)=="table" then
                if not are_equal(ai,bi) then
                    return false
                end
            else
                return false
            end
        end
        return true
    else
        return false
    end
end

local function identical(a,b) -- assumes same structure
    for ka, va in next, a do
        local vb = b[ka]
        if va == vb then
            -- same
        elseif type(va) == "table" and  type(vb) == "table" then
            if not identical(va,vb) then
                return false
            end
        else
            return false
        end
    end
    return true
end

table.identical = identical
table.are_equal = are_equal

-- maybe also make a combined one

function table.compact(t)
    if t then
        for k,v in next, t do
            if not next(v) then
                t[k] = nil
            end
        end
    end
end

function table.contains(t, v)
    if t then
        for i=1, #t do
            if t[i] == v then
                return i
            end
        end
    end
    return false
end

function table.count(t)
    local n = 0
    for k, v in next, t do
        n = n + 1
    end
    return n
end

function table.swapped(t,s) -- hash
    local n = { }
    if s then
        for k, v in next, s do
            n[k] = v
        end
    end
    for k, v in next, t do
        n[v] = k
    end
    return n
end

function table.reversed(t)
    if t then
        local tt, tn = { }, #t
        if tn > 0 then
            local ttn = 0
            for i=tn,1,-1 do
                ttn = ttn + 1
                tt[ttn] = t[i]
            end
        end
        return tt
    end
end

function table.sequenced(t,sep,simple) -- hash only
    local s, n = { }, 0
    for k, v in sortedhash(t) do
        if simple then
            if v == true then
                n = n + 1
                s[n] = k
            elseif v and v~= "" then
                n = n + 1
                s[n] = k .. "=" .. tostring(v)
            end
        else
            n = n + 1
            s[n] = k .. "=" .. tostring(v)
        end
    end
    return concat(s, sep or " | ")
end

function table.print(t,...)
    if type(t) ~= "table" then
        print(tostring(t))
    else
        table.tohandle(print,t,...)
    end
end

-- -- -- obsolete but we keep them for a while and might comment them later -- -- --

-- roughly: copy-loop : unpack : sub == 0.9 : 0.4 : 0.45 (so in critical apps, use unpack)

function table.sub(t,i,j)
    return { unpack(t,i,j) }
end

-- slower than #t on indexed tables (#t only returns the size of the numerically indexed slice)

function table.is_empty(t)
    return not t or not next(t)
end

function table.has_one_entry(t)
    return t and not next(t,next(t))
end

-- new

function table.loweredkeys(t) -- maybe utf
    local l = { }
    for k, v in next, t do
        l[lower(k)] = v
    end
    return l
end

-- new, might move (maybe duplicate)

function table.unique(old)
    local hash = { }
    local new = { }
    local n = 0
    for i=1,#old do
        local oi = old[i]
        if not hash[oi] then
            n = n + 1
            new[n] = oi
            hash[oi] = true
        end
    end
    return new
end

-- function table.sorted(t,...)
--     table.sort(t,...)
--     return t -- still sorts in-place
-- end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-lpeg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


-- a new lpeg fails on a #(1-P(":")) test and really needs a + P(-1)

local lpeg = require("lpeg")

-- tracing (only used when we encounter a problem in integration of lpeg in luatex)

local report = texio and texio.write_nl or print

-- local lpmatch = lpeg.match
-- local lpprint = lpeg.print
-- local lpp     = lpeg.P
-- local lpr     = lpeg.R
-- local lps     = lpeg.S
-- local lpc     = lpeg.C
-- local lpb     = lpeg.B
-- local lpv     = lpeg.V
-- local lpcf    = lpeg.Cf
-- local lpcb    = lpeg.Cb
-- local lpcg    = lpeg.Cg
-- local lpct    = lpeg.Ct
-- local lpcs    = lpeg.Cs
-- local lpcc    = lpeg.Cc
-- local lpcmt   = lpeg.Cmt
-- local lpcarg  = lpeg.Carg

-- function lpeg.match(l,...) report("LPEG MATCH") lpprint(l) return lpmatch(l,...) end

-- function lpeg.P    (l) local p = lpp   (l) report("LPEG P =")    lpprint(l) return p end
-- function lpeg.R    (l) local p = lpr   (l) report("LPEG R =")    lpprint(l) return p end
-- function lpeg.S    (l) local p = lps   (l) report("LPEG S =")    lpprint(l) return p end
-- function lpeg.C    (l) local p = lpc   (l) report("LPEG C =")    lpprint(l) return p end
-- function lpeg.B    (l) local p = lpb   (l) report("LPEG B =")    lpprint(l) return p end
-- function lpeg.V    (l) local p = lpv   (l) report("LPEG V =")    lpprint(l) return p end
-- function lpeg.Cf   (l) local p = lpcf  (l) report("LPEG Cf =")   lpprint(l) return p end
-- function lpeg.Cb   (l) local p = lpcb  (l) report("LPEG Cb =")   lpprint(l) return p end
-- function lpeg.Cg   (l) local p = lpcg  (l) report("LPEG Cg =")   lpprint(l) return p end
-- function lpeg.Ct   (l) local p = lpct  (l) report("LPEG Ct =")   lpprint(l) return p end
-- function lpeg.Cs   (l) local p = lpcs  (l) report("LPEG Cs =")   lpprint(l) return p end
-- function lpeg.Cc   (l) local p = lpcc  (l) report("LPEG Cc =")   lpprint(l) return p end
-- function lpeg.Cmt  (l) local p = lpcmt (l) report("LPEG Cmt =")  lpprint(l) return p end
-- function lpeg.Carg (l) local p = lpcarg(l) report("LPEG Carg =") lpprint(l) return p end

local type = type
local byte, char, gmatch = string.byte, string.char, string.gmatch

-- Beware, we predefine a bunch of patterns here and one reason for doing so
-- is that we get consistent behaviour in some of the visualizers.

lpeg.patterns  = lpeg.patterns or { } -- so that we can share
local patterns = lpeg.patterns

local P, R, S, V, match = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.match
local Ct, C, Cs, Cc = lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc
local lpegtype = lpeg.type

local utfcharacters    = string.utfcharacters
local utfgmatch        = unicode and unicode.utf8.gmatch

local anything         = P(1)
local endofstring      = P(-1)
local alwaysmatched    = P(true)

patterns.anything      = anything
patterns.endofstring   = endofstring
patterns.beginofstring = alwaysmatched
patterns.alwaysmatched = alwaysmatched

local digit, sign      = R('09'), S('+-')
local cr, lf, crlf     = P("\r"), P("\n"), P("\r\n")
local newline          = crlf + S("\r\n") -- cr + lf
local escaped          = P("\\") * anything
local squote           = P("'")
local dquote           = P('"')
local space            = P(" ")

local utfbom_32_be     = P('\000\000\254\255')
local utfbom_32_le     = P('\255\254\000\000')
local utfbom_16_be     = P('\255\254')
local utfbom_16_le     = P('\254\255')
local utfbom_8         = P('\239\187\191')
local utfbom           = utfbom_32_be + utfbom_32_le
                       + utfbom_16_be + utfbom_16_le
                       + utfbom_8
local utftype          = utfbom_32_be / "utf-32-be" + utfbom_32_le  / "utf-32-le"
                       + utfbom_16_be / "utf-16-be" + utfbom_16_le  / "utf-16-le"
                       + utfbom_8     / "utf-8"     + alwaysmatched / "unknown"

local utf8next         = R("\128\191")

patterns.utf8one       = R("\000\127")
patterns.utf8two       = R("\194\223") * utf8next
patterns.utf8three     = R("\224\239") * utf8next * utf8next
patterns.utf8four      = R("\240\244") * utf8next * utf8next * utf8next
patterns.utfbom        = utfbom
patterns.utftype       = utftype

local utf8char         = patterns.utf8one + patterns.utf8two + patterns.utf8three + patterns.utf8four
local validutf8char    = utf8char^0 * endofstring * Cc(true) + Cc(false)

patterns.utf8          = utf8char
patterns.utf8char      = utf8char
patterns.validutf8     = validutf8char
patterns.validutf8char = validutf8char

patterns.digit         = digit
patterns.sign          = sign
patterns.cardinal      = sign^0 * digit^1
patterns.integer       = sign^0 * digit^1
patterns.float         = sign^0 * digit^0 * P('.') * digit^1
patterns.cfloat        = sign^0 * digit^0 * P(',') * digit^1
patterns.number        = patterns.float + patterns.integer
patterns.cnumber       = patterns.cfloat + patterns.integer
patterns.oct           = P("0") * R("07")^1
patterns.octal         = patterns.oct
patterns.HEX           = P("0x") * R("09","AF")^1
patterns.hex           = P("0x") * R("09","af")^1
patterns.hexadecimal   = P("0x") * R("09","AF","af")^1
patterns.lowercase     = R("az")
patterns.uppercase     = R("AZ")
patterns.letter        = patterns.lowercase + patterns.uppercase
patterns.space         = space
patterns.tab           = P("\t")
patterns.spaceortab    = patterns.space + patterns.tab
patterns.eol           = S("\n\r")
patterns.spacer        = S(" \t\f\v")  -- + char(0xc2, 0xa0) if we want utf (cf mail roberto)
patterns.newline       = newline
patterns.emptyline     = newline^1
patterns.nonspacer     = 1 - patterns.spacer
patterns.whitespace    = patterns.eol + patterns.spacer
patterns.nonwhitespace = 1 - patterns.whitespace
patterns.equal         = P("=")
patterns.comma         = P(",")
patterns.commaspacer   = P(",") * patterns.spacer^0
patterns.period        = P(".")
patterns.colon         = P(":")
patterns.semicolon     = P(";")
patterns.underscore    = P("_")
patterns.escaped       = escaped
patterns.squote        = squote
patterns.dquote        = dquote
patterns.nosquote      = (escaped + (1-squote))^0
patterns.nodquote      = (escaped + (1-dquote))^0
patterns.unsingle      = (squote/"") * patterns.nosquote * (squote/"")
patterns.undouble      = (dquote/"") * patterns.nodquote * (dquote/"")
patterns.unquoted      = patterns.undouble + patterns.unsingle -- more often undouble
patterns.unspacer      = ((patterns.spacer^1)/"")^0

patterns.somecontent   = (anything - newline - space)^1 -- (utf8char - newline - space)^1
patterns.beginline     = #(1-newline)

-- print(string.unquoted("test"))
-- print(string.unquoted([["t\"est"]]))
-- print(string.unquoted([["t\"est"x]]))
-- print(string.unquoted("\'test\'"))
-- print(string.unquoted('"test"'))
-- print(string.unquoted('"test"'))

function lpeg.anywhere(pattern) --slightly adapted from website
    return P { P(pattern) + 1 * V(1) } -- why so complex?
end

function lpeg.splitter(pattern, action)
    return (((1-P(pattern))^1)/action+1)^0
end

function lpeg.tsplitter(pattern, action)
    return Ct((((1-P(pattern))^1)/action+1)^0)
end

-- probleem: separator can be lpeg and that does not hash too well, but
-- it's quite okay as the key is then not garbage collected

local splitters_s, splitters_m, splitters_t = { }, { }, { }

local function splitat(separator,single)
    local splitter = (single and splitters_s[separator]) or splitters_m[separator]
    if not splitter then
        separator = P(separator)
        local other = C((1 - separator)^0)
        if single then
            local any = anything
            splitter = other * (separator * C(any^0) + "") -- ?
            splitters_s[separator] = splitter
        else
            splitter = other * (separator * other)^0
            splitters_m[separator] = splitter
        end
    end
    return splitter
end

local function tsplitat(separator)
    local splitter = splitters_t[separator]
    if not splitter then
        splitter = Ct(splitat(separator))
        splitters_t[separator] = splitter
    end
    return splitter
end

lpeg.splitat  = splitat
lpeg.tsplitat = tsplitat

function string.splitup(str,separator)
    if not separator then
        separator = ","
    end
    return match(splitters_m[separator] or splitat(separator),str)
end


local cache = { }

function lpeg.split(separator,str)
    local c = cache[separator]
    if not c then
        c = tsplitat(separator)
        cache[separator] = c
    end
    return match(c,str)
end

function string.split(str,separator)
    local c = cache[separator]
    if not c then
        c = tsplitat(separator)
        cache[separator] = c
    end
    return match(c,str)
end

local spacing  = patterns.spacer^0 * newline -- sort of strip
local empty    = spacing * Cc("")
local nonempty = Cs((1-spacing)^1) * spacing^-1
local content  = (empty + nonempty)^1

patterns.textline = content


local linesplitter = tsplitat(newline)

patterns.linesplitter = linesplitter

function string.splitlines(str)
    return match(linesplitter,str)
end

local utflinesplitter = utfbom^-1 * tsplitat(newline)

patterns.utflinesplitter = utflinesplitter

function string.utfsplitlines(str)
    return match(utflinesplitter,str or "")
end


local cache = { }

function lpeg.checkedsplit(separator,str)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^1)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return match(c,str)
end

function string.checkedsplit(str,separator)
    local c = cache[separator]
    if not c then
        separator = P(separator)
        local other = C((1 - separator)^1)
        c = Ct(separator^0 * other * (separator^1 * other)^0)
        cache[separator] = c
    end
    return match(c,str)
end


local function f2(s) local c1, c2         = byte(s,1,2) return   c1 * 64 + c2                       -    12416 end
local function f3(s) local c1, c2, c3     = byte(s,1,3) return  (c1 * 64 + c2) * 64 + c3            -   925824 end
local function f4(s) local c1, c2, c3, c4 = byte(s,1,4) return ((c1 * 64 + c2) * 64 + c3) * 64 + c4 - 63447168 end

local utf8byte = patterns.utf8one/byte + patterns.utf8two/f2 + patterns.utf8three/f3 + patterns.utf8four/f4

patterns.utf8byte = utf8byte



local cache = { }

function lpeg.stripper(str)
    if type(str) == "string" then
        local s = cache[str]
        if not s then
            s = Cs(((S(str)^1)/"" + 1)^0)
            cache[str] = s
        end
        return s
    else
        return Cs(((str^1)/"" + 1)^0)
    end
end

local cache = { }

function lpeg.keeper(str)
    if type(str) == "string" then
        local s = cache[str]
        if not s then
            s = Cs((((1-S(str))^1)/"" + 1)^0)
            cache[str] = s
        end
        return s
    else
        return Cs((((1-str)^1)/"" + 1)^0)
    end
end

function lpeg.frontstripper(str) -- or pattern (yet undocumented)
    return (P(str) + P(true)) * Cs(P(1)^0)
end

function lpeg.endstripper(str) -- or pattern (yet undocumented)
    return Cs((1 - P(str) * P(-1))^0)
end

-- Just for fun I looked at the used bytecode and
-- p = (p and p + pp) or pp gets one more (testset).

function lpeg.replacer(one,two)
    if type(one) == "table" then
        local no = #one
        if no > 0 then
            local p
            for i=1,no do
                local o = one[i]
                local pp = P(o[1]) / o[2]
                if p then
                    p = p + pp
                else
                    p = pp
                end
            end
            return Cs((p + 1)^0)
        end
    else
        two = two or ""
        return Cs((P(one)/two + 1)^0)
    end
end

local splitters_f, splitters_s = { }, { }

function lpeg.firstofsplit(separator) -- always return value
    local splitter = splitters_f[separator]
    if not splitter then
        separator = P(separator)
        splitter = C((1 - separator)^0)
        splitters_f[separator] = splitter
    end
    return splitter
end

function lpeg.secondofsplit(separator) -- nil if not split
    local splitter = splitters_s[separator]
    if not splitter then
        separator = P(separator)
        splitter = (1 - separator)^0 * separator * C(anything^0)
        splitters_s[separator] = splitter
    end
    return splitter
end

function lpeg.balancer(left,right)
    left, right = P(left), P(right)
    return P { left * ((1 - left - right) + V(1))^0 * right }
end



local nany = utf8char/""

function lpeg.counter(pattern)
    pattern = Cs((P(pattern)/" " + nany)^0)
    return function(str)
        return #match(pattern,str)
    end
end

if utfgmatch then

    function lpeg.count(str,what) -- replaces string.count
        if type(what) == "string" then
            local n = 0
            for _ in utfgmatch(str,what) do
                n = n + 1
            end
            return n
        else -- 4 times slower but still faster than / function
            return #match(Cs((P(what)/" " + nany)^0),str)
        end
    end

else

    local cache = { }

    function lpeg.count(str,what) -- replaces string.count
        if type(what) == "string" then
            local p = cache[what]
            if not p then
                p = Cs((P(what)/" " + nany)^0)
                cache[p] = p
            end
            return #match(p,str)
        else -- 4 times slower but still faster than / function
            return #match(Cs((P(what)/" " + nany)^0),str)
        end
    end

end

local patterns_escapes = { -- also defines in l-string
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%)", [")"] = "%)",
 -- ["{"] = "%{", ["}"] = "%}"
 -- ["^"] = "%^", ["$"] = "%$",
}

local simple_escapes = { -- also defines in l-string
    ["-"] = "%-",
    ["."] = "%.",
    ["?"] = ".",
    ["*"] = ".*",
}

local p = Cs((S("-.+*%()[]") / patterns_escapes + anything)^0)
local s = Cs((S("-.+*%()[]") / simple_escapes   + anything)^0)

function string.escapedpattern(str,simple)
    return match(simple and s or p,str)
end

-- utf extensies

lpeg.UP = lpeg.P

if utfcharacters then

    function lpeg.US(str)
        local p
        for uc in utfcharacters(str) do
            if p then
                p = p + P(uc)
            else
                p = P(uc)
            end
        end
        return p
    end


elseif utfgmatch then

    function lpeg.US(str)
        local p
        for uc in utfgmatch(str,".") do
            if p then
                p = p + P(uc)
            else
                p = P(uc)
            end
        end
        return p
    end

else

    function lpeg.US(str)
        local p
        local f = function(uc)
            if p then
                p = p + P(uc)
            else
                p = P(uc)
            end
        end
        match((utf8char/f)^0,str)
        return p
    end

end

local range = Cs(utf8byte) * (Cs(utf8byte) + Cc(false))

local utfchar = unicode and unicode.utf8 and unicode.utf8.char

function lpeg.UR(str,more)
    local first, last
    if type(str) == "number" then
        first = str
        last = more or first
    else
        first, last = match(range,str)
        if not last then
            return P(str)
        end
    end
    if first == last then
        return P(str)
    elseif utfchar and last - first < 8 then -- a somewhat arbitrary criterium
        local p
        for i=first,last do
            if p then
                p = p + P(utfchar(i))
            else
                p = P(utfchar(i))
            end
        end
        return p -- nil when invalid range
    else
        local f = function(b)
            return b >= first and b <= last
        end
        return utf8byte / f -- nil when invalid range
    end
end



function lpeg.oneof(list,...) -- lpeg.oneof("elseif","else","if","then")
    if type(list) ~= "table" then
        list = { list, ... }
    end
 -- sort(list) -- longest match first
    local p = P(list[1])
    for l=2,#list do
        p = p + P(list[l])
    end
    return p
end

function lpeg.is_lpeg(p)
    return p and lpegtype(p) == "pattern"
end

-- For the moment here, but it might move to utilities. Beware, we need to
-- have the longest keyword first, so 'aaa' comes beforte 'aa' which is why we
-- loop back from the end cq. prepend.

local sort, fastcopy, sortedkeys = table.sort, table.fastcopy, table.sortedkeys -- dependency!

function lpeg.append(list,pp,delayed,checked)
    local p = pp
    if #list > 0 then
        local keys = fastcopy(list)
        sort(keys)
        for i=#keys,1,-1 do
            local k = keys[i]
            if p then
                p = P(k) + p
            else
                p = P(k)
            end
        end
    elseif delayed then -- hm, it looks like the lpeg parser resolves anyway
        local keys = sortedkeys(list)
        if p then
            for i=1,#keys,1 do
                local k = keys[i]
                local v = list[k]
                p = P(k)/list + p
            end
        else
            for i=1,#keys do
                local k = keys[i]
                local v = list[k]
                if p then
                    p = P(k) + p
                else
                    p = P(k)
                end
            end
            if p then
                p = p / list
            end
        end
    elseif checked then
        -- problem: substitution gives a capture
        local keys = sortedkeys(list)
        for i=1,#keys do
            local k = keys[i]
            local v = list[k]
            if p then
                if k == v then
                    p = P(k) + p
                else
                    p = P(k)/v + p
                end
            else
                if k == v then
                    p = P(k)
                else
                    p = P(k)/v
                end
            end
        end
    else
        local keys = sortedkeys(list)
        for i=1,#keys do
            local k = keys[i]
            local v = list[k]
            if p then
                p = P(k)/v + p
            else
                p = P(k)/v
            end
        end
    end
    return p
end

-- inspect(lpeg.append({ a = "1", aa = "1", aaa = "1" } ,nil,true))
-- inspect(lpeg.append({ ["degree celsius"] = "1", celsius = "1", degree = "1" } ,nil,true))

-- function lpeg.exact_match(words,case_insensitive)
--     local pattern = concat(words)
--     if case_insensitive then
--         local pattern = S(upper(characters)) + S(lower(characters))
--         local list = { }
--         for i=1,#words do
--             list[lower(words[i])] = true
--         end
--         return Cmt(pattern^1, function(_,i,s)
--             return list[lower(s)] and i
--         end)
--     else
--         local pattern = S(concat(words))
--         local list = { }
--         for i=1,#words do
--             list[words[i]] = true
--         end
--         return Cmt(pattern^1, function(_,i,s)
--             return list[s] and i
--         end)
--     end
-- end

-- experiment:

local function make(t)
    local p
--     for k, v in next, t do
    for k, v in table.sortedhash(t) do
        if not p then
            if next(v) then
                p = P(k) * make(v)
            else
                p = P(k)
            end
        else
            if next(v) then
                p = p + P(k) * make(v)
            else
                p = p + P(k)
            end
        end
    end
    return p
end

function lpeg.utfchartabletopattern(list)
    local tree = { }
    for i=1,#list do
        local t = tree
        for c in gmatch(list[i],".") do
            if not t[c] then
                t[c] = { }
            end
            t = t[c]
        end
    end
    return make(tree)
end

-- inspect ( lpeg.utfchartabletopattern {
--     utfchar(0x00A0), -- nbsp
--     utfchar(0x2000), -- enquad
--     utfchar(0x2001), -- emquad
--     utfchar(0x2002), -- enspace
--     utfchar(0x2003), -- emspace
--     utfchar(0x2004), -- threeperemspace
--     utfchar(0x2005), -- fourperemspace
--     utfchar(0x2006), -- sixperemspace
--     utfchar(0x2007), -- figurespace
--     utfchar(0x2008), -- punctuationspace
--     utfchar(0x2009), -- breakablethinspace
--     utfchar(0x200A), -- hairspace
--     utfchar(0x200B), -- zerowidthspace
--     utfchar(0x202F), -- narrownobreakspace
--     utfchar(0x205F), -- math thinspace
-- } )


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-io'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local io = io
local byte, find, gsub, format = string.byte, string.find, string.gsub, string.format
local concat = table.concat
local type = type

if string.find(os.getenv("PATH"),";") then
    io.fileseparator, io.pathseparator = "\\", ";"
else
    io.fileseparator, io.pathseparator = "/" , ":"
end

function io.loaddata(filename,textmode)
    local f = io.open(filename,(textmode and 'r') or 'rb')
    if f then
        local data = f:read('*all')
        f:close()
        return data
    else
        return nil
    end
end

function io.savedata(filename,data,joiner)
    local f = io.open(filename,"wb")
    if f then
        if type(data) == "table" then
            f:write(concat(data,joiner or ""))
        elseif type(data) == "function" then
            data(f)
        else
            f:write(data or "")
        end
        f:close()
        io.flush()
        return true
    else
        return false
    end
end

function io.exists(filename)
    local f = io.open(filename)
    if f == nil then
        return false
    else
        assert(f:close())
        return true
    end
end

function io.size(filename)
    local f = io.open(filename)
    if f == nil then
        return 0
    else
        local s = f:seek("end")
        assert(f:close())
        return s
    end
end

function io.noflines(f)
    if type(f) == "string" then
        local f = io.open(filename)
        local n = f and io.noflines(f) or 0
        assert(f:close())
        return n
    else
        local n = 0
        for _ in f:lines() do
            n = n + 1
        end
        f:seek('set',0)
        return n
    end
end

local nextchar = {
    [ 4] = function(f)
        return f:read(1,1,1,1)
    end,
    [ 2] = function(f)
        return f:read(1,1)
    end,
    [ 1] = function(f)
        return f:read(1)
    end,
    [-2] = function(f)
        local a, b = f:read(1,1)
        return b, a
    end,
    [-4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        return d, c, b, a
    end
}

function io.characters(f,n)
    if f then
        return nextchar[n or 1], f
    end
end

local nextbyte = {
    [4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        if d then
            return byte(a), byte(b), byte(c), byte(d)
        end
    end,
    [3] = function(f)
        local a, b, c = f:read(1,1,1)
        if b then
            return byte(a), byte(b), byte(c)
        end
    end,
    [2] = function(f)
        local a, b = f:read(1,1)
        if b then
            return byte(a), byte(b)
        end
    end,
    [1] = function (f)
        local a = f:read(1)
        if a then
            return byte(a)
        end
    end,
    [-2] = function (f)
        local a, b = f:read(1,1)
        if b then
            return byte(b), byte(a)
        end
    end,
    [-3] = function(f)
        local a, b, c = f:read(1,1,1)
        if b then
            return byte(c), byte(b), byte(a)
        end
    end,
    [-4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        if d then
            return byte(d), byte(c), byte(b), byte(a)
        end
    end
}

function io.bytes(f,n)
    if f then
        return nextbyte[n or 1], f
    else
        return nil, nil
    end
end

function io.ask(question,default,options)
    while true do
        io.write(question)
        if options then
            io.write(format(" [%s]",concat(options,"|")))
        end
        if default then
            io.write(format(" [%s]",default))
        end
        io.write(format(" "))
        io.flush()
        local answer = io.read()
        answer = gsub(answer,"^%s*(.*)%s*$","%1")
        if answer == "" and default then
            return default
        elseif not options then
            return answer
        else
            for k=1,#options do
                if options[k] == answer then
                    return answer
                end
            end
            local pattern = "^" .. answer
            for k=1,#options do
                local v = options[k]
                if find(v,pattern) then
                    return v
                end
            end
        end
    end
end

local function readnumber(f,n,m)
    if m then
        f:seek("set",n)
        n = m
    end
    if n == 1 then
        return byte(f:read(1))
    elseif n == 2 then
        local a, b = byte(f:read(2),1,2)
        return 256 * a + b
    elseif n == 3 then
        local a, b, c = byte(f:read(3),1,3)
        return 256*256 * a + 256 * b + c
    elseif n == 4 then
        local a, b, c, d = byte(f:read(4),1,4)
        return 256*256*256 * a + 256*256 * b + 256 * c + d
    elseif n == 8 then
        local a, b = readnumber(f,4), readnumber(f,4)
        return 256 * a + b
    elseif n == 12 then
        local a, b, c = readnumber(f,4), readnumber(f,4), readnumber(f,4)
        return 256*256 * a + 256 * b + c
    elseif n == -2 then
        local b, a = byte(f:read(2),1,2)
        return 256*a + b
    elseif n == -3 then
        local c, b, a = byte(f:read(3),1,3)
        return 256*256 * a + 256 * b + c
    elseif n == -4 then
        local d, c, b, a = byte(f:read(4),1,4)
        return 256*256*256 * a + 256*256 * b + 256*c + d
    elseif n == -8 then
        local h, g, f, e, d, c, b, a = byte(f:read(8),1,8)
        return 256*256*256*256*256*256*256 * a +
                   256*256*256*256*256*256 * b +
                       256*256*256*256*256 * c +
                           256*256*256*256 * d +
                               256*256*256 * e +
                                   256*256 * f +
                                       256 * g +
                                             h
    else
        return 0
    end
end

io.readnumber = readnumber

function io.readstring(f,n,m)
    if m then
        f:seek("set",n)
        n = m
    end
    local str = gsub(f:read(n),"%z","")
    return str
end

--

if not io.i_limiter then function io.i_limiter() end end -- dummy so we can test safely
if not io.o_limiter then function io.o_limiter() end end -- dummy so we can test safely


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-number'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module will be replaced when we have the bit library

local tostring = tostring
local format, floor, match, rep = string.format, math.floor, string.match, string.rep
local concat, insert = table.concat, table.insert
local lpegmatch = lpeg.match

number       = number or { }
local number = number

-- a,b,c,d,e,f = number.toset(100101)

function number.toset(n)
    return match(tostring(n),"(.?)(.?)(.?)(.?)(.?)(.?)(.?)(.?)")
end

function number.toevenhex(n)
    local s = format("%X",n)
    if #s % 2 == 0 then
        return s
    else
        return "0" .. s
    end
end

-- the lpeg way is slower on 8 digits, but faster on 4 digits, some 7.5%
-- on
--
-- for i=1,1000000 do
--     local a,b,c,d,e,f,g,h = number.toset(12345678)
--     local a,b,c,d         = number.toset(1234)
--     local a,b,c           = number.toset(123)
-- end
--
-- of course dedicated "(.)(.)(.)(.)" matches are even faster

local one = lpeg.C(1-lpeg.S(''))^1

function number.toset(n)
    return lpegmatch(one,tostring(n))
end

function number.bits(n,zero)
    local t, i = { }, (zero and 0) or 1
    while n > 0 do
        local m = n % 2
        if m > 0 then
            insert(t,1,i)
        end
        n = floor(n/2)
        i = i + 1
    end
    return t
end


function number.bit(p)
    return 2 ^ (p - 1) -- 1-based indexing
end

function number.hasbit(x, p) -- typical call: if hasbit(x, bit(3)) then ...
    return x % (p + p) >= p
end

function number.setbit(x, p)
    return hasbit(x, p) and x or x + p
end

function number.clearbit(x, p)
    return hasbit(x, p) and x - p or x
end


function number.tobitstring(n,m)
    if n == 0 then
        if m then
            rep("00000000",m)
        else
            return "00000000"
        end
    else
        local t = { }
        while n > 0 do
            insert(t,1,n % 2 > 0 and 1 or 0)
            n = floor(n/2)
        end
        local nn = 8 - #t % 8
        if nn > 0 and nn < 8 then
            for i=1,nn do
                insert(t,1,0)
            end
        end
        if m then
            m = m * 8 - #t
            if m > 0 then
                insert(t,1,rep("0",m))
            end
        end
        return concat(t)
    end
end



end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-set'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This will become obsolete when we have the bitset library embedded.

set = set or { }

local nums   = { }
local tabs   = { }
local concat = table.concat
local next, type = next, type

set.create = table.tohash

function set.tonumber(t)
    if next(t) then
        local s = ""
    --  we could save mem by sorting, but it slows down
        for k, v in next, t do
            if v then
            --  why bother about the leading space
                s = s .. " " .. k
            end
        end
        local n = nums[s]
        if not n then
            n = #tabs + 1
            tabs[n] = t
            nums[s] = n
        end
        return n
    else
        return 0
    end
end

function set.totable(n)
    if n == 0 then
        return { }
    else
        return tabs[n] or { }
    end
end

function set.tolist(n)
    if n == 0 or not tabs[n] then
        return ""
    else
        local t, n = { }, 0
        for k, v in next, tabs[n] do
            if v then
                n = n + 1
                t[n] = k
            end
        end
        return concat(t," ")
    end
end

function set.contains(n,s)
    if type(n) == "table" then
        return n[s]
    elseif n == 0 then
        return false
    else
        local t = tabs[n]
        return t and t[s]
    end
end




end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-os'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This file deals with some operating system issues. Please don't bother me
-- with the pros and cons of operating systems as they all have their flaws
-- and benefits. Bashing one of them won't help solving problems and fixing
-- bugs faster and is a waste of time and energy.
--
-- path separators: / or \ ... we can use / everywhere
-- suffixes       : dll so exe <none> ... no big deal
-- quotes         : we can use "" in most cases
-- expansion      : unless "" are used * might give side effects
-- piping/threads : somewhat different for each os
-- locations      : specific user file locations and settings can change over time
--
-- os.type     : windows | unix (new, we already guessed os.platform)
-- os.name     : windows | msdos | linux | macosx | solaris | .. | generic (new)
-- os.platform : extended os.name with architecture

-- maybe build io.flush in os.execute

local os = os
local find, format, gsub, upper, gmatch = string.find, string.format, string.gsub, string.upper, string.gmatch
local concat = table.concat
local random, ceil = math.random, math.ceil
local rawget, rawset, type, getmetatable, setmetatable, tonumber = rawget, rawset, type, getmetatable, setmetatable, tonumber

-- The following code permits traversing the environment table, at least
-- in luatex. Internally all environment names are uppercase.

if not os.__getenv__ then

    os.__getenv__ = os.getenv
    os.__setenv__ = os.setenv

    if os.env then

        local osgetenv  = os.getenv
        local ossetenv  = os.setenv
        local osenv     = os.env      local _ = osenv.PATH -- initialize the table

        function os.setenv(k,v)
            if v == nil then
                v = ""
            end
            local K = upper(k)
            osenv[K] = v
            if type(v) == "table" then
                v = concat(v,";") -- path
            end
            ossetenv(K,v)
        end

        function os.getenv(k)
            local K = upper(k)
            local v = osenv[K] or osenv[k] or osgetenv(K) or osgetenv(k)
            if v == "" then
                return nil
            else
                return v
            end
        end

    else

        local ossetenv  = os.setenv
        local osgetenv  = os.getenv
        local osenv     = { }

        function os.setenv(k,v)
            if v == nil then
                v = ""
            end
            local K = upper(k)
            osenv[K] = v
        end

        function os.getenv(k)
            local K = upper(k)
            local v = osenv[K] or osgetenv(K) or osgetenv(k)
            if v == "" then
                return nil
            else
                return v
            end
        end

        local function __index(t,k)
            return os.getenv(k)
        end
        local function __newindex(t,k,v)
            os.setenv(k,v)
        end

        os.env = { }

        setmetatable(os.env, { __index = __index, __newindex = __newindex } )

    end

end

-- end of environment hack

local execute, spawn, exec, iopopen, ioflush = os.execute, os.spawn or os.execute, os.exec or os.execute, io.popen, io.flush

function os.execute(...) ioflush() return execute(...) end
function os.spawn  (...) ioflush() return spawn  (...) end
function os.exec   (...) ioflush() return exec   (...) end
function io.popen  (...) ioflush() return iopopen(...) end

function os.resultof(command)
    local handle = io.popen(command,"r")
    return handle and handle:read("*all") or ""
end

if not io.fileseparator then
    if find(os.getenv("PATH"),";") then
        io.fileseparator, io.pathseparator, os.type = "\\", ";", os.type or "mswin"
    else
        io.fileseparator, io.pathseparator, os.type = "/" , ":", os.type or "unix"
    end
end

os.type = os.type or (io.pathseparator == ";"       and "windows") or "unix"
os.name = os.name or (os.type          == "windows" and "mswin"  ) or "linux"

if os.type == "windows" then
    os.libsuffix, os.binsuffix, os.binsuffixes = 'dll', 'exe', { 'exe', 'cmd', 'bat' }
else
    os.libsuffix, os.binsuffix, os.binsuffixes = 'so', '', { '' }
end

function os.launch(str)
    if os.type == "windows" then
        os.execute("start " .. str) -- os.spawn ?
    else
        os.execute(str .. " &")     -- os.spawn ?
    end
end

if not os.times then
    -- utime  = user time
    -- stime  = system time
    -- cutime = children user time
    -- cstime = children system time
    function os.times()
        return {
            utime  = os.gettimeofday(), -- user
            stime  = 0,                 -- system
            cutime = 0,                 -- children user
            cstime = 0,                 -- children system
        }
    end
end

os.gettimeofday = os.gettimeofday or os.clock

local startuptime = os.gettimeofday()

function os.runtime()
    return os.gettimeofday() - startuptime
end


-- no need for function anymore as we have more clever code and helpers now
-- this metatable trickery might as well disappear

os.resolvers = os.resolvers or { } -- will become private

local resolvers = os.resolvers

local osmt = getmetatable(os) or { __index = function(t,k) t[k] = "unset" return "unset" end } -- maybe nil
local osix = osmt.__index

osmt.__index = function(t,k)
    return (resolvers[k] or osix)(t,k)
end

setmetatable(os,osmt)

-- we can use HOSTTYPE on some platforms

local name, platform = os.name or "linux", os.getenv("MTX_PLATFORM") or ""

local function guess()
    local architecture = os.resultof("uname -m") or ""
    if architecture ~= "" then
        return architecture
    end
    architecture = os.getenv("HOSTTYPE") or ""
    if architecture ~= "" then
        return architecture
    end
    return os.resultof("echo $HOSTTYPE") or ""
end

if platform ~= "" then

    os.platform = platform

elseif os.type == "windows" then

    -- we could set the variable directly, no function needed here

    function os.resolvers.platform(t,k)
        local platform, architecture = "", os.getenv("PROCESSOR_ARCHITECTURE") or ""
        if find(architecture,"AMD64") then
            platform = "mswin-64"
        else
            platform = "mswin"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "linux" then

    function os.resolvers.platform(t,k)
        -- we sometimes have HOSTTYPE set so let's check that first
        local platform, architecture = "", os.getenv("HOSTTYPE") or os.resultof("uname -m") or ""
        if find(architecture,"x86_64") then
            platform = "linux-64"
        elseif find(architecture,"ppc") then
            platform = "linux-ppc"
        else
            platform = "linux"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "macosx" then

    --[[
        Identifying the architecture of OSX is quite a mess and this
        is the best we can come up with. For some reason $HOSTTYPE is
        a kind of pseudo environment variable, not known to the current
        environment. And yes, uname cannot be trusted either, so there
        is a change that you end up with a 32 bit run on a 64 bit system.
        Also, some proper 64 bit intel macs are too cheap (low-end) and
        therefore not permitted to run the 64 bit kernel.
      ]]--

    function os.resolvers.platform(t,k)
     -- local platform, architecture = "", os.getenv("HOSTTYPE") or ""
     -- if architecture == "" then
     --     architecture = os.resultof("echo $HOSTTYPE") or ""
     -- end
        local platform, architecture = "", os.resultof("echo $HOSTTYPE") or ""
        if architecture == "" then
         -- print("\nI have no clue what kind of OSX you're running so let's assume an 32 bit intel.\n")
            platform = "osx-intel"
        elseif find(architecture,"i386") then
            platform = "osx-intel"
        elseif find(architecture,"x86_64") then
            platform = "osx-64"
        else
            platform = "osx-ppc"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "sunos" then

    function os.resolvers.platform(t,k)
        local platform, architecture = "", os.resultof("uname -m") or ""
        if find(architecture,"sparc") then
            platform = "solaris-sparc"
        else -- if architecture == 'i86pc'
            platform = "solaris-intel"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "freebsd" then

    function os.resolvers.platform(t,k)
        local platform, architecture = "", os.resultof("uname -m") or ""
        if find(architecture,"amd64") then
            platform = "freebsd-amd64"
        else
            platform = "freebsd"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

elseif name == "kfreebsd" then

    function os.resolvers.platform(t,k)
        -- we sometimes have HOSTTYPE set so let's check that first
        local platform, architecture = "", os.getenv("HOSTTYPE") or os.resultof("uname -m") or ""
        if find(architecture,"x86_64") then
            platform = "kfreebsd-amd64"
        else
            platform = "kfreebsd-i386"
        end
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

else

    -- platform = "linux"
    -- os.setenv("MTX_PLATFORM",platform)
    -- os.platform = platform

    function os.resolvers.platform(t,k)
        local platform = "linux"
        os.setenv("MTX_PLATFORM",platform)
        os.platform = platform
        return platform
    end

end

-- beware, we set the randomseed

-- from wikipedia: Version 4 UUIDs use a scheme relying only on random numbers. This algorithm sets the
-- version number as well as two reserved bits. All other bits are set using a random or pseudorandom
-- data source. Version 4 UUIDs have the form xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx with hexadecimal
-- digits x and hexadecimal digits 8, 9, A, or B for y. e.g. f47ac10b-58cc-4372-a567-0e02b2c3d479.
--
-- as we don't call this function too often there is not so much risk on repetition

local t = { 8, 9, "a", "b" }

function os.uuid()
    return format("%04x%04x-4%03x-%s%03x-%04x-%04x%04x%04x",
        random(0xFFFF),random(0xFFFF),
        random(0x0FFF),
        t[ceil(random(4))] or 8,random(0x0FFF),
        random(0xFFFF),
        random(0xFFFF),random(0xFFFF),random(0xFFFF)
    )
end

local d

function os.timezone(delta)
    d = d or tonumber(tonumber(os.date("%H")-os.date("!%H")))
    if delta then
        if d > 0 then
            return format("+%02i:00",d)
        else
            return format("-%02i:00",-d)
        end
    else
        return 1
    end
end

local memory = { }

local function which(filename)
    local fullname = memory[filename]
    if fullname == nil then
        local suffix = file.suffix(filename)
        local suffixes = suffix == "" and os.binsuffixes or { suffix }
        for directory in gmatch(os.getenv("PATH"),"[^" .. io.pathseparator .."]+") do
            local df = file.join(directory,filename)
            for i=1,#suffixes do
                local dfs = file.addsuffix(df,suffixes[i])
                if io.exists(dfs) then
                    fullname = dfs
                    break
                end
            end
        end
        if not fullname then
            fullname = false
        end
        memory[filename] = fullname
    end
    return fullname
end

os.which = which
os.where = which

-- print(os.which("inkscape.exe"))
-- print(os.which("inkscape"))
-- print(os.which("gs.exe"))
-- print(os.which("ps2pdf"))


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-file'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup

file       = file or { }
local file = file

local insert, concat = table.insert, table.concat
local find, gmatch, match, gsub, sub, char, lower = string.find, string.gmatch, string.match, string.gsub, string.sub, string.char, string.lower
local lpegmatch = lpeg.match
local getcurrentdir, attributes = lfs.currentdir, lfs.attributes

local P, R, S, C, Cs, Cp, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Cp, lpeg.Cc

local function dirname(name,default)
    return match(name,"^(.+)[/\\].-$") or (default or "")
end

local function basename(name)
    return match(name,"^.+[/\\](.-)$") or name
end

-- local function nameonly(name)
--     return (gsub(match(name,"^.+[/\\](.-)$") or name,"%..*$",""))
-- end

local function nameonly(name)
    return (gsub(match(name,"^.+[/\\](.-)$") or name,"%.[%a%d]+$",""))
end

local function extname(name,default)
    return match(name,"^.+%.([^/\\]-)$") or default or ""
end

local function splitname(name)
    local n, s = match(name,"^(.+)%.([^/\\]-)$")
    return n or name, s or ""
end

file.basename = basename
file.dirname  = dirname
file.nameonly = nameonly
file.extname  = extname
file.suffix   = extname

function file.removesuffix(filename)
    return (gsub(filename,"%.[%a%d]+$",""))
end

function file.addsuffix(filename, suffix, criterium)
    if not suffix or suffix == "" then
        return filename
    elseif criterium == true then
        return filename .. "." .. suffix
    elseif not criterium then
        local n, s = splitname(filename)
        if not s or s == "" then
            return filename .. "." .. suffix
        else
            return filename
        end
    else
        local n, s = splitname(filename)
        if s and s ~= "" then
            local t = type(criterium)
            if t == "table" then
                -- keep if in criterium
                for i=1,#criterium do
                    if s == criterium[i] then
                        return filename
                    end
                end
            elseif t == "string" then
                -- keep if criterium
                if s == criterium then
                    return filename
                end
            end
        end
        return n .. "." .. suffix
    end
end


function file.replacesuffix(filename, suffix)
    return (gsub(filename,"%.[%a%d]+$","")) .. "." .. suffix
end


local trick_1 = char(1)
local trick_2 = "^" .. trick_1 .. "/+"

function file.join(...) -- rather dirty
    local lst = { ... }
    local a, b = lst[1], lst[2]
    if not a or a == "" then -- not a added
        lst[1] = trick_1
    elseif b and find(a,"^/+$") and find(b,"^/") then
        lst[1] = ""
        lst[2] = gsub(b,"^/+","")
    end
    local pth = concat(lst,"/")
    pth = gsub(pth,"\\","/")
    local a, b = match(pth,"^(.*://)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    a, b = match(pth,"^(//)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    pth = gsub(pth,trick_2,"")
    return (gsub(pth,"//+","/"))
end


-- We should be able to use:
--
-- function file.is_writable(name)
--     local a = attributes(name) or attributes(dirname(name,"."))
--     return a and sub(a.permissions,2,2) == "w"
-- end
--
-- But after some testing Taco and I came up with:

function file.is_writable(name)
    if lfs.isdir(name) then
        name = name .. "/m_t_x_t_e_s_t.tmp"
        local f = io.open(name,"wb")
        if f then
            f:close()
            os.remove(name)
            return true
        end
    elseif lfs.isfile(name) then
        local f = io.open(name,"ab")
        if f then
            f:close()
            return true
        end
    else
        local f = io.open(name,"ab")
        if f then
            f:close()
            os.remove(name)
            return true
        end
    end
    return false
end

function file.is_readable(name)
    local a = attributes(name)
    return a and sub(a.permissions,1,1) == "r"
end

file.isreadable = file.is_readable -- depricated
file.iswritable = file.is_writable -- depricated

-- todo: lpeg \\ / .. does not save much

local checkedsplit = string.checkedsplit

function file.splitpath(str,separator) -- string
    str = gsub(str,"\\","/")
    return checkedsplit(str,separator or io.pathseparator)
end

function file.joinpath(tab,separator) -- table
    return concat(tab,separator or io.pathseparator) -- can have trailing //
end

-- we can hash them weakly


function file.collapsepath(str,anchor)
    if anchor and not find(str,"^/") and not find(str,"^%a:") then
        str = getcurrentdir() .. "/" .. str
    end
    if str == "" or str =="." then
        return "."
    elseif find(str,"^%.%.") then
        str = gsub(str,"\\","/")
        return str
    elseif not find(str,"%.") then
        str = gsub(str,"\\","/")
        return str
    end
    str = gsub(str,"\\","/")
    local starter, rest = match(str,"^(%a+:/*)(.-)$")
    if starter then
        str = rest
    end
    local oldelements = checkedsplit(str,"/")
    local newelements = { }
    local i = #oldelements
    while i > 0 do
        local element = oldelements[i]
        if element == '.' then
            -- do nothing
        elseif element == '..' then
            local n = i - 1
            while n > 0 do
                local element = oldelements[n]
                if element ~= '..' and element ~= '.' then
                    oldelements[n] = '.'
                    break
                else
                    n = n - 1
                end
             end
            if n < 1 then
               insert(newelements,1,'..')
            end
        elseif element ~= "" then
            insert(newelements,1,element)
        end
        i = i - 1
    end
    if #newelements == 0 then
        return starter or "."
    elseif starter then
        return starter .. concat(newelements, '/')
    elseif find(str,"^/") then
        return "/" .. concat(newelements,'/')
    else
        return concat(newelements, '/')
    end
end


function file.robustname(str,strict)
    str = gsub(str,"[^%a%d%/%-%.\\]+","-")
    if strict then
        return lower(gsub(str,"^%-*(.-)%-*$","%1"))
    else
        return str
    end
end

file.readdata = io.loaddata
file.savedata = io.savedata

function file.copy(oldname,newname)
    file.savedata(newname,io.loaddata(oldname))
end

-- lpeg variants, slightly faster, not always



















-- also rewrite previous

local letter    = R("az","AZ") + S("_-+")
local separator = P("://")

local qualified = P(".")^0 * P("/") + letter*P(":") + letter^1*separator + letter^1 * P("/")
local rootbased = P("/") + letter*P(":")

lpeg.patterns.qualified = qualified
lpeg.patterns.rootbased = rootbased

-- ./name ../name  /name c: :// name/name

function file.is_qualified_path(filename)
    return lpegmatch(qualified,filename) ~= nil
end

function file.is_rootbased_path(filename)
    return lpegmatch(rootbased,filename) ~= nil
end

-- actually these are schemes

local slash  = S("\\/")
local period = P(".")
local drive  = C(R("az","AZ")) * P(":")
local path   = C(((1-slash)^0 * slash)^0)
local suffix = period * C(P(1-period)^0 * P(-1))
local base   = C((1-suffix)^0)

drive  = drive  + Cc("")
path   = path   + Cc("")
base   = base   + Cc("")
suffix = suffix + Cc("")

local pattern_a =   drive * path  *   base * suffix
local pattern_b =           path  *   base * suffix
local pattern_c = C(drive * path) * C(base * suffix)

function file.splitname(str,splitdrive)
    if splitdrive then
        return lpegmatch(pattern_a,str) -- returns drive, path, base, suffix
    else
        return lpegmatch(pattern_b,str) -- returns path, base, suffix
    end
end

function file.nametotable(str,splitdrive) -- returns table
    local path, drive, subpath, name, base, suffix = lpegmatch(pattern_c,str)
    if splitdrive then
        return {
            path    = path,
            drive   = drive,
            subpath = subpath,
            name    = name,
            base    = base,
            suffix  = suffix,
        }
    else
        return {
            path    = path,
            name    = name,
            base    = base,
            suffix  = suffix,
        }
    end
end

-- function test(t) for k, v in next, t do print(v, "=>", file.splitname(v)) end end
--
-- test { "c:", "c:/aa", "c:/aa/bb", "c:/aa/bb/cc", "c:/aa/bb/cc.dd", "c:/aa/bb/cc.dd.ee" }
-- test { "c:", "c:aa", "c:aa/bb", "c:aa/bb/cc", "c:aa/bb/cc.dd", "c:aa/bb/cc.dd.ee" }
-- test { "/aa", "/aa/bb", "/aa/bb/cc", "/aa/bb/cc.dd", "/aa/bb/cc.dd.ee" }
-- test { "aa", "aa/bb", "aa/bb/cc", "aa/bb/cc.dd", "aa/bb/cc.dd.ee" }


-- for myself:

function file.strip(name,dir)
    local b, a = match(name,"^(.-)" .. dir .. "(.*)$")
    return a ~= "" and a or name
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-md5'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This also provides file checksums and checkers.

local md5, file = md5, file
local gsub, format, byte = string.gsub, string.format, string.byte

local function convert(str,fmt)
    return (gsub(md5.sum(str),".",function(chr) return format(fmt,byte(chr)) end))
end

if not md5.HEX then function md5.HEX(str) return convert(str,"%02X") end end
if not md5.hex then function md5.hex(str) return convert(str,"%02x") end end
if not md5.dec then function md5.dec(str) return convert(str,"%03i") end end


function file.needs_updating(oldname,newname,threshold) -- size modification access change
    local oldtime = lfs.attributes(oldname, modification)
    local newtime = lfs.attributes(newname, modification)
    if newtime >= oldtime then
        return false
    elseif oldtime - newtime < (threshold or 1) then
        return false
    else
        return true
    end
end

function file.checksum(name)
    if md5 then
        local data = io.loaddata(name)
        if data then
            return md5.HEX(data)
        end
    end
    return nil
end

function file.loadchecksum(name)
    if md5 then
        local data = io.loaddata(name .. ".md5")
        return data and (gsub(data,"%s",""))
    end
    return nil
end

function file.savechecksum(name, checksum)
    if not checksum then checksum = file.checksum(name) end
    if checksum then
        io.savedata(name .. ".md5",checksum)
        return checksum
    end
    return nil
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-url'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local char, gmatch, gsub, format, byte, find = string.char, string.gmatch, string.gsub, string.format, string.byte, string.find
local concat = table.concat
local tonumber, type = tonumber, type
local P, C, R, S, Cs, Cc, Ct = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cs, lpeg.Cc, lpeg.Ct
local lpegmatch, lpegpatterns, replacer = lpeg.match, lpeg.patterns, lpeg.replacer

-- from wikipedia:
--
--   foo://username:password@example.com:8042/over/there/index.dtb?type=animal;name=narwhal#nose
--   \_/   \_______________/ \_________/ \__/            \___/ \_/ \______________________/ \__/
--    |           |               |       |                |    |            |                |
--    |       userinfo         hostname  port              |    |          query          fragment
--    |    \________________________________/\_____________|____|/
-- scheme                  |                          |    |    |
--    |                authority                    path   |    |
--    |                                                    |    |
--    |            path                       interpretable as filename
--    |   ___________|____________                              |
--   / \ /                        \                             |
--   urn:example:animal:ferret:nose               interpretable as extension

url       = url or { }
local url = url

local tochar      = function(s) return char(tonumber(s,16)) end

local colon       = P(":")
local qmark       = P("?")
local hash        = P("#")
local slash       = P("/")
local percent     = P("%")
local endofstring = P(-1)

local hexdigit    = R("09","AF","af")
local plus        = P("+")
local nothing     = Cc("")
local escaped     = (plus / " ") + (percent * C(hexdigit * hexdigit) / tochar)

-- we assume schemes with more than 1 character (in order to avoid problems with windows disks)
-- we also assume that when we have a scheme, we also have an authority

local schemestr    = Cs((escaped+(1-colon-slash-qmark-hash))^2)
local authoritystr = Cs((escaped+(1-      slash-qmark-hash))^0)
local pathstr      = Cs((escaped+(1-            qmark-hash))^0)
local querystr     = Cs((escaped+(1-                  hash))^0)
local fragmentstr  = Cs((escaped+(1-           endofstring))^0)

local scheme    =                 schemestr    * colon + nothing
local authority = slash * slash * authoritystr         + nothing
local path      = slash         * pathstr              + nothing
local query     = qmark         * querystr             + nothing
local fragment  = hash          * fragmentstr          + nothing

local validurl  = scheme * authority * path * query * fragment
local parser    = Ct(validurl)

lpegpatterns.url         = validurl
lpegpatterns.urlsplitter = parser

local escapes = { } ; for i=0,255 do escapes[i] = format("%%%02X",i) end

local escaper = Cs((R("09","AZ","az") + S("-./_") + P(1) / escapes)^0)

lpegpatterns.urlescaper = escaper

-- todo: reconsider Ct as we can as well have five return values (saves a table)
-- so we can have two parsers, one with and one without

local function split(str)
    return (type(str) == "string" and lpegmatch(parser,str)) or str
end

local isscheme = schemestr * colon * slash * slash -- this test also assumes authority

local function hasscheme(str)
    local scheme = lpegmatch(isscheme,str) -- at least one character
    return scheme ~= "" and scheme or false
end


-- todo: cache them

local rootletter       = R("az","AZ")
                       + S("_-+")
local separator        = P("://")
local qualified        = P(".")^0 * P("/")
                       + rootletter * P(":")
                       + rootletter^1 * separator
                       + rootletter^1 * P("/")
local rootbased        = P("/")
                       + rootletter * P(":")

local barswapper       = replacer("|",":")
local backslashswapper = replacer("\\","/")

local function hashed(str) -- not yet ok (/test?test)
    local s = split(str)
    local somescheme = s[1] ~= ""
    local somequery  = s[4] ~= ""
    if not somescheme and not somequery then
        s = {
            scheme    = "file",
            authority = "",
            path      = str,
            query     = "",
            fragment  = "",
            original  = str,
            noscheme  = true,
            filename  = str,
        }
    else -- not always a filename but handy anyway
        local authority, path, filename = s[2], s[3]
        if authority == "" then
            filename = path
        else
            filename = authority .. "/" .. path
        end
        s = {
            scheme    = s[1],
            authority = authority,
            path      = path,
            query     = s[4],
            fragment  = s[5],
            original  = str,
            noscheme  = false,
            filename  = filename,
        }
    end
    return s
end

-- Here we assume:
--
-- files: ///  = relative
-- files: //// = absolute (!)



url.split     = split
url.hasscheme = hasscheme
url.hashed    = hashed

function url.addscheme(str,scheme) -- no authority
    if hasscheme(str) then
        return str
    elseif not scheme then
        return "file:///" .. str
    else
        return scheme .. ":///" .. str
    end
end

function url.construct(hash) -- dodo: we need to escape !
    local fullurl, f = { }, 0
    local scheme, authority, path, query, fragment = hash.scheme, hash.authority, hash.path, hash.query, hash.fragment
    if scheme and scheme ~= "" then
        f = f + 1 ; fullurl[f] = scheme .. "://"
    end
    if authority and authority ~= "" then
        f = f + 1 ; fullurl[f] = authority
    end
    if path and path ~= "" then
        f = f + 1 ; fullurl[f] = "/" .. path
    end
    if query and query ~= "" then
        f = f + 1 ; fullurl[f] = "?".. query
    end
    if fragment and fragment ~= "" then
        f = f + 1 ; fullurl[f] = "#".. fragment
    end
    return lpegmatch(escaper,concat(fullurl))
end

function url.filename(filename)
    local t = hashed(filename)
    return (t.scheme == "file" and (gsub(t.path,"^/([a-zA-Z])([:|])/)","%1:"))) or filename
end

function url.query(str)
    if type(str) == "string" then
        local t = { }
        for k, v in gmatch(str,"([^&=]*)=([^&=]*)") do
            t[k] = v
        end
        return t
    else
        return str
    end
end










end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-dir'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- dir.expandname will be merged with cleanpath and collapsepath

local type = type
local find, gmatch, match, gsub = string.find, string.gmatch, string.match, string.gsub
local concat, insert, remove = table.concat, table.insert, table.remove
local lpegmatch = lpeg.match

local P, S, R, C, Cc, Cs, Ct, Cv, V = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Cv, lpeg.V

dir = dir or { }
local dir = dir
local lfs = lfs

local attributes = lfs.attributes
local walkdir    = lfs.dir
local isdir      = lfs.isdir
local isfile     = lfs.isfile
local currentdir = lfs.currentdir

-- handy

function dir.current()
    return (gsub(currentdir(),"\\","/"))
end

-- optimizing for no find (*) does not save time


local lfsisdir = isdir

local function isdir(path)
    path = gsub(path,"[/\\]+$","")
    return lfsisdir(path)
end

lfs.isdir = isdir

local function globpattern(path,patt,recurse,action)
    if path == "/" then
        path = path .. "."
    elseif not find(path,"/$") then
        path = path .. '/'
    end
    if isdir(path) then -- lfs.isdir does not like trailing /
        for name in walkdir(path) do -- lfs.dir accepts trailing /
            local full = path .. name
            local mode = attributes(full,'mode')
            if mode == 'file' then
                if find(full,patt) then
                    action(full)
                end
            elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
                globpattern(full,patt,recurse,action)
            end
        end
    end
end

dir.globpattern = globpattern

local function collectpattern(path,patt,recurse,result)
    local ok, scanner
    result = result or { }
    if path == "/" then
        ok, scanner, first = xpcall(function() return walkdir(path..".") end, function() end) -- kepler safe
    else
        ok, scanner, first = xpcall(function() return walkdir(path)      end, function() end) -- kepler safe
    end
    if ok and type(scanner) == "function" then
        if not find(path,"/$") then path = path .. '/' end
        for name in scanner, first do
            local full = path .. name
            local attr = attributes(full)
            local mode = attr.mode
            if mode == 'file' then
                if find(full,patt) then
                    result[name] = attr
                end
            elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
                attr.list = collectpattern(full,patt,recurse)
                result[name] = attr
            end
        end
    end
    return result
end

dir.collectpattern = collectpattern

local pattern = Ct {
    [1] = (C(P(".") + P("/")^1) + C(R("az","AZ") * P(":") * P("/")^0) + Cc("./")) * V(2) * V(3),
    [2] = C(((1-S("*?/"))^0 * P("/"))^0),
    [3] = C(P(1)^0)
}

local filter = Cs ( (
    P("**") / ".*" +
    P("*")  / "[^/]*" +
    P("?")  / "[^/]" +
    P(".")  / "%%." +
    P("+")  / "%%+" +
    P("-")  / "%%-" +
    P(1)
)^0 )

local function glob(str,t)
    if type(t) == "function" then
        if type(str) == "table" then
            for s=1,#str do
                glob(str[s],t)
            end
        elseif isfile(str) then
            t(str)
        else
            local split = lpegmatch(pattern,str) -- we could use the file splitter
            if split then
                local root, path, base = split[1], split[2], split[3]
                local recurse = find(base,"%*%*")
                local start = root .. path
                local result = lpegmatch(filter,start .. base)
                globpattern(start,result,recurse,t)
            end
        end
    else
        if type(str) == "table" then
            local t = t or { }
            for s=1,#str do
                glob(str[s],t)
            end
            return t
        elseif isfile(str) then
            if t then
                t[#t+1] = str
                return t
            else
                return { str }
            end
        else
            local split = lpegmatch(pattern,str) -- we could use the file splitter
            if split then
                local t = t or { }
                local action = action or function(name) t[#t+1] = name end
                local root, path, base = split[1], split[2], split[3]
                local recurse = find(base,"%*%*")
                local start = root .. path
                local result = lpegmatch(filter,start .. base)
                globpattern(start,result,recurse,action)
                return t
            else
                return { }
            end
        end
    end
end

dir.glob = glob


local function globfiles(path,recurse,func,files) -- func == pattern or function
    if type(func) == "string" then
        local s = func
        func = function(name) return find(name,s) end
    end
    files = files or { }
    local noffiles = #files
    for name in walkdir(path) do
        if find(name,"^%.") then
            --- skip
        else
            local mode = attributes(name,'mode')
            if mode == "directory" then
                if recurse then
                    globfiles(path .. "/" .. name,recurse,func,files)
                end
            elseif mode == "file" then
                if not func or func(name) then
                    noffiles = noffiles + 1
                    files[noffiles] = path .. "/" .. name
                end
            end
        end
    end
    return files
end

dir.globfiles = globfiles

-- t = dir.glob("c:/data/develop/context/sources/**/????-*.tex")
-- t = dir.glob("c:/data/develop/tex/texmf/**/*.tex")
-- t = dir.glob("c:/data/develop/context/texmf/**/*.tex")
-- t = dir.glob("f:/minimal/tex/**/*")
-- print(dir.ls("f:/minimal/tex/**/*"))
-- print(dir.ls("*.tex"))

function dir.ls(pattern)
    return concat(glob(pattern),"\n")
end


local make_indeed = true -- false

local onwindows = os.type == "windows" or find(os.getenv("PATH"),";")

if onwindows then

    function dir.mkdirs(...)
        local str, pth, t = "", "", { ... }
        for i=1,#t do
            local s = t[i]
            if s ~= "" then
                if str ~= "" then
                    str = str .. "/" .. s
                else
                    str = s
                end
            end
        end
        local first, middle, last
        local drive = false
        first, middle, last = match(str,"^(//)(//*)(.*)$")
        if first then
            -- empty network path == local path
        else
            first, last = match(str,"^(//)/*(.-)$")
            if first then
                middle, last = match(str,"([^/]+)/+(.-)$")
                if middle then
                    pth = "//" .. middle
                else
                    pth = "//" .. last
                    last = ""
                end
            else
                first, middle, last = match(str,"^([a-zA-Z]:)(/*)(.-)$")
                if first then
                    pth, drive = first .. middle, true
                else
                    middle, last = match(str,"^(/*)(.-)$")
                    if not middle then
                        last = str
                    end
                end
            end
        end
        for s in gmatch(last,"[^/]+") do
            if pth == "" then
                pth = s
            elseif drive then
                pth, drive = pth .. s, false
            else
                pth = pth .. "/" .. s
            end
            if make_indeed and not isdir(pth) then
                lfs.mkdir(pth)
            end
        end
        return pth, (isdir(pth) == true)
    end

                                            
else

    function dir.mkdirs(...)
        local str, pth, t = "", "", { ... }
        for i=1,#t do
            local s = t[i]
            if s and s ~= "" then -- we catch nil and false
                if str ~= "" then
                    str = str .. "/" .. s
                else
                    str = s
                end
            end
        end
        str = gsub(str,"/+","/")
        if find(str,"^/") then
            pth = "/"
            for s in gmatch(str,"[^/]+") do
                local first = (pth == "/")
                if first then
                    pth = pth .. s
                else
                    pth = pth .. "/" .. s
                end
                if make_indeed and not first and not isdir(pth) then
                    lfs.mkdir(pth)
                end
            end
        else
            pth = "."
            for s in gmatch(str,"[^/]+") do
                pth = pth .. "/" .. s
                if make_indeed and not isdir(pth) then
                    lfs.mkdir(pth)
                end
            end
        end
        return pth, (isdir(pth) == true)
    end

                            
end

dir.makedirs = dir.mkdirs

-- we can only define it here as it uses dir.current

if onwindows then

    function dir.expandname(str) -- will be merged with cleanpath and collapsepath
        local first, nothing, last = match(str,"^(//)(//*)(.*)$")
        if first then
            first = dir.current() .. "/"
        end
        if not first then
            first, last = match(str,"^(//)/*(.*)$")
        end
        if not first then
            first, last = match(str,"^([a-zA-Z]:)(.*)$")
            if first and not find(last,"^/") then
                local d = currentdir()
                if lfs.chdir(first) then
                    first = dir.current()
                end
                lfs.chdir(d)
            end
        end
        if not first then
            first, last = dir.current(), str
        end
        last = gsub(last,"//","/")
        last = gsub(last,"/%./","/")
        last = gsub(last,"^/*","")
        first = gsub(first,"/*$","")
        if last == "" or last == "." then
            return first
        else
            return first .. "/" .. last
        end
    end

else

    function dir.expandname(str) -- will be merged with cleanpath and collapsepath
        if not find(str,"^/") then
            str = currentdir() .. "/" .. str
        end
        str = gsub(str,"//","/")
        str = gsub(str,"/%./","/")
        str = gsub(str,"(.)/%.$","%1")
        return str
    end

end

file.expandname = dir.expandname -- for convenience

local stack = { }

function dir.push(newdir)
    insert(stack,lfs.currentdir())
end

function dir.pop()
    local d = remove(stack)
    if d then
        lfs.chdir(d)
    end
    return d
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-boolean'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, tonumber = type, tonumber

boolean = boolean or { }
local boolean = boolean

function boolean.tonumber(b)
    if b then return 1 else return 0 end -- test and return or return
end

function toboolean(str,tolerant)
    if tolerant then
        local tstr = type(str)
        if tstr == "string" then
            return str == "true" or str == "yes" or str == "on" or str == "1" or str == "t"
        elseif tstr == "number" then
            return tonumber(str) ~= 0
        elseif tstr == "nil" then
            return false
        else
            return str
        end
    elseif str == "true" then
        return true
    elseif str == "false" then
        return false
    else
        return str
    end
end

string.toboolean = toboolean

function string.is_boolean(str,default)
    if type(str) == "string" then
        if str == "true" or str == "yes" or str == "on" or str == "t" then
            return true
        elseif str == "false" or str == "no" or str == "off" or str == "f" then
            return false
        end
    end
    return default
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-unicode'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not unicode then

    unicode = { utf8 = { } }

    local floor, char = math.floor, string.char

    function unicode.utf8.utfchar(n)
        if n < 0x80 then
            return char(n)
        elseif n < 0x800 then
            return char(
                0xC0 + floor(n/0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x10000 then
            return char(
                0xE0 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x40000 then
            return char(
                0xF0 + floor(n/0x40000),
                0x80 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        else
         -- return char(
         --     0xF1 + floor(n/0x1000000),
         --     0x80 + floor(n/0x40000),
         --     0x80 + floor(n/0x1000),
         --     0x80 + (floor(n/0x40) % 0x40),
         --     0x80 + (n % 0x40)
         -- )
            return "?"
        end
    end

end

local unicode = unicode

utf = utf or unicode.utf8

local concat = table.concat
local utfchar, utfbyte, utfgsub = utf.char, utf.byte, utf.gsub
local char, byte, find, bytepairs, utfvalues, format = string.char, string.byte, string.find, string.bytepairs, string.utfvalues, string.format
local type = type

local utfsplitlines = string.utfsplitlines

-- 0  EF BB BF      UTF-8
-- 1  FF FE         UTF-16-little-endian
-- 2  FE FF         UTF-16-big-endian
-- 3  FF FE 00 00   UTF-32-little-endian
-- 4  00 00 FE FF   UTF-32-big-endian

unicode.utfname = {
    [0] = 'utf-8',
    [1] = 'utf-16-le',
    [2] = 'utf-16-be',
    [3] = 'utf-32-le',
    [4] = 'utf-32-be'
}

-- \000 fails in <= 5.0 but is valid in >=5.1 where %z is depricated

function unicode.utftype(f)
    local str = f:read(4)
    if not str then
        f:seek('set')
        return 0
 -- elseif find(str,"^%z%z\254\255") then            -- depricated
 -- elseif find(str,"^\000\000\254\255") then        -- not permitted and bugged
    elseif find(str,"\000\000\254\255",1,true) then  -- seems to work okay (TH)
        return 4
 -- elseif find(str,"^\255\254%z%z") then            -- depricated
 -- elseif find(str,"^\255\254\000\000") then        -- not permitted and bugged
    elseif find(str,"\255\254\000\000",1,true) then  -- seems to work okay (TH)
        return 3
    elseif find(str,"^\254\255") then
        f:seek('set',2)
        return 2
    elseif find(str,"^\255\254") then
        f:seek('set',2)
        return 1
    elseif find(str,"^\239\187\191") then
        f:seek('set',3)
        return 0
    else
        f:seek('set')
        return 0
    end
end



local function utf16_to_utf8_be(t)
    if type(t) == "string" then
        t = utfsplitlines(str)
    end
    local result = { } -- we reuse result
    for i=1,#t do
        local r, more = 0, 0
        for left, right in bytepairs(t[i]) do
            if right then
                local now = 256*left + right
                if more > 0 then
                    now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
                    more = 0
                    r = r + 1
                    result[r] = utfchar(now)
                elseif now >= 0xD800 and now <= 0xDBFF then
                    more = now
                else
                    r = r + 1
                    result[r] = utfchar(now)
                end
            end
        end
        t[i] = concat(result,"",1,r) -- we reused tmp, hence t
    end
    return t
end

local function utf16_to_utf8_le(t)
    if type(t) == "string" then
        t = utfsplitlines(str)
    end
    local result = { } -- we reuse result
    for i=1,#t do
        local r, more = 0, 0
        for left, right in bytepairs(t[i]) do
            if right then
                local now = 256*right + left
                if more > 0 then
                    now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
                    more = 0
                    r = r + 1
                    result[r] = utfchar(now)
                elseif now >= 0xD800 and now <= 0xDBFF then
                    more = now
                else
                    r = r + 1
                    result[r] = utfchar(now)
                end
            end
        end
        t[i] = concat(result,"",1,r) -- we reused tmp, hence t
    end
    return t
end

local function utf32_to_utf8_be(t)
    if type(t) == "string" then
        t = utfsplitlines(t)
    end
    local result = { } -- we reuse result
    for i=1,#t do
        local r, more = 0, -1
        for a,b in bytepairs(t[i]) do
            if a and b then
                if more < 0 then
                    more = 256*256*256*a + 256*256*b
                else
                    r = r + 1
                    result[t] = utfchar(more + 256*a + b)
                    more = -1
                end
            else
                break
            end
        end
        t[i] = concat(result,"",1,r)
    end
    return t
end

local function utf32_to_utf8_le(t)
    if type(t) == "string" then
        t = utfsplitlines(t)
    end
    local result = { } -- we reuse result
    for i=1,#t do
        local r, more = 0, -1
        for a,b in bytepairs(t[i]) do
            if a and b then
                if more < 0 then
                    more = 256*b + a
                else
                    r = r + 1
                    result[t] = utfchar(more + 256*256*256*b + 256*256*a)
                    more = -1
                end
            else
                break
            end
        end
        t[i] = concat(result,"",1,r)
    end
    return t
end

unicode.utf32_to_utf8_be = utf32_to_utf8_be
unicode.utf32_to_utf8_le = utf32_to_utf8_le
unicode.utf16_to_utf8_be = utf16_to_utf8_be
unicode.utf16_to_utf8_le = utf16_to_utf8_le

function unicode.utf8_to_utf8(t)
    return type(t) == "string" and utfsplitlines(t) or t
end

function unicode.utf16_to_utf8(t,endian)
    return endian and utf16_to_utf8_be(t) or utf16_to_utf8_le(t) or t
end

function unicode.utf32_to_utf8(t,endian)
    return endian and utf32_to_utf8_be(t) or utf32_to_utf8_le(t) or t
end

local function little(c)
    local b = byte(c)
    if b < 0x10000 then
        return char(b%256,b/256)
    else
        b = b - 0x10000
        local b1, b2 = b/1024 + 0xD800, b%1024 + 0xDC00
        return char(b1%256,b1/256,b2%256,b2/256)
    end
end

local function big(c)
    local b = byte(c)
    if b < 0x10000 then
        return char(b/256,b%256)
    else
        b = b - 0x10000
        local b1, b2 = b/1024 + 0xD800, b%1024 + 0xDC00
        return char(b1/256,b1%256,b2/256,b2%256)
    end
end

function unicode.utf8_to_utf16(str,littleendian)
    if littleendian then
        return char(255,254) .. utfgsub(str,".",little)
    else
        return char(254,255) .. utfgsub(str,".",big)
    end
end

function unicode.utfcodes(str)
    local t, n = { }, 0
    for u in utfvalues(str) do
        n = n + 1
        t[n] = format("0x%04X",u)
    end
    return concat(t,separator or " ")
end

function unicode.ustring(s)
    return format("U+%05X",type(s) == "number" and s or utfbyte(s))
end

function unicode.xstring(s)
    return format("0x%05X",type(s) == "number" and s or utfbyte(s))
end


local lpegmatch = lpeg.match
local patterns = lpeg.patterns
local utftype = patterns.utftype

function unicode.filetype(data)
    return data and lpegmatch(utftype,data) or "unknown"
end

local toentities = lpeg.Cs (
    (
        patterns.utf8one
            + (
                patterns.utf8two
              + patterns.utf8three
              + patterns.utf8four
            ) / function(s) local b = utfbyte(s) if b < 127 then return s else return format("&#%X;",b) end end
    )^0
)

patterns.toentities = toentities

function utf.toentities(str)
    return lpegmatch(toentities,str)
end




local P, C, R, Cs = lpeg.P, lpeg.C, lpeg.R, lpeg.Cs

local one  = P(1)
local two  = C(1) * C(1)
local four = C(R(utfchar(0xD8),utfchar(0xFF))) * C(1) * C(1) * C(1)

-- actually one of them is already utf ... sort of useless this one

local pattern = P("\254\255") * Cs( (
                    four  / function(a,b,c,d)
                                local ab = 0xFF * byte(a) + byte(b)
                                local cd = 0xFF * byte(c) + byte(d)
                                return utfchar((ab-0xD800)*0x400 + (cd-0xDC00) + 0x10000)
                            end
                  + two   / function(a,b)
                                return utfchar(byte(a)*256 + byte(b))
                            end
                  + one
                )^1 )
              + P("\255\254") * Cs( (
                    four  / function(b,a,d,c)
                                local ab = 0xFF * byte(a) + byte(b)
                                local cd = 0xFF * byte(c) + byte(d)
                                return utfchar((ab-0xD800)*0x400 + (cd-0xDC00) + 0x10000)
                            end
                  + two   / function(b,a)
                                return utfchar(byte(a)*256 + byte(b))
                            end
                  + one
                )^1 )

function string.toutf(s)
    return lpegmatch(pattern,s) or s -- todo: utf32
end

local validatedutf = Cs (
    (
        patterns.utf8one
      + patterns.utf8two
      + patterns.utf8three
      + patterns.utf8four
      + P(1) / "�"
    )^0
)

patterns.validatedutf = validatedutf

function string.validutf(str)
    return lpegmatch(validatedutf,str)
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-math'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local floor, sin, cos, tan = math.floor, math.sin, math.cos, math.tan

if not math.round then
    function math.round(x) return floor(x + 0.5) end
end

if not math.div then
    function math.div(n,m) return floor(n/m) end
end

if not math.mod then
    function math.mod(n,m) return n % m end
end

local pipi = 2*math.pi/360

if not math.sind then
    function math.sind(d) return sin(d*pipi) end
    function math.cosd(d) return cos(d*pipi) end
    function math.tand(d) return tan(d*pipi) end
end

if not math.odd then
    function math.odd (n) return n % 2 ~= 0 end
    function math.even(n) return n % 2 == 0 end
end


end -- of closure

do -- create closure to overcome 200 locals limit

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

local format, gmatch, rep = string.format, string.gmatch, string.rep
local concat, insert, remove = table.concat, table.insert, table.remove
local setmetatable, getmetatable, tonumber, tostring = setmetatable, getmetatable, tonumber, tostring
local type, next, rawset, tonumber = type, next, rawset, tonumber

function tables.definetable(target) -- defines undefined tables
    local composed, t, n = nil, { }, 0
    for name in gmatch(target,"([^%.]+)") do
        n = n + 1
        if composed then
            composed = composed .. "." .. name
        else
            composed = name
        end
        t[n] = format("%s = %s or { }",composed,composed)
    end
    return concat(t,"\n")
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


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['util-sto'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable, getmetatable = setmetatable, getmetatable

utilities         = utilities or { }
utilities.storage = utilities.storage or { }
local storage     = utilities.storage

function storage.mark(t)
    if not t then
        texio.write_nl("fatal error: storage cannot be marked")
        return -- os.exit()
    end
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m.__storage__ = true
    return t
end

function storage.allocate(t)
    t = t or { }
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m.__storage__ = true
    return t
end

function storage.marked(t)
    local m = getmetatable(t)
    return m and m.__storage__
end

function storage.checked(t)
    if not t then
        texio.write_nl("fatal error: storage has not been allocated")
        return -- os.exit()
    end
    return t
end


function storage.setinitializer(data,initialize)
    local m = getmetatable(data) or { }
    m.__index = function(data,k)
        m.__index = nil -- so that we can access the entries during initializing
        initialize()
        return data[k]
    end
    setmetatable(data, m)
end

local keyisvalue = { __index = function(t,k)
    t[k] = k
    return k
end }

function storage.sparse(t)
    t = t or { }
    setmetatable(t,keyisvalue)
    return t
end

-- table namespace ?

local function f_empty ()             return "" end -- t,k
local function f_self  (t,k) t[k] = k return k  end
local function f_ignore()                       end -- t,k,v

local t_empty  = { __index    = f_empty  }
local t_self   = { __index    = f_self   }
local t_ignore = { __newindex = f_ignore }

function table.setmetatableindex(t,f)
    local m = getmetatable(t)
    if m then
        if f == "empty" then
            m.__index = f_empty
        elseif f == "key" then
            m.__index = f_self
        else
            m.__index = f
        end
    else
        if f == "empty" then
            setmetatable(t, t_empty)
        elseif f == "key" then
            setmetatable(t, t_self)
        else
            setmetatable(t,{ __index = f })
        end
    end
    return t
end

function table.setmetatablenewindex(t,f)
    local m = getmetatable(t)
    if m then
        if f == "ignore" then
            m.__newindex = f_ignore
        else
            m.__newindex = f
        end
    else
        if f == "ignore" then
            setmetatable(t, t_ignore)
        else
            setmetatable(t,{ __newindex = f })
        end
    end
    return t
end

function table.setmetatablecall(t,f)
    local m = getmetatable(t)
    if m then
        m.__call = f
    else
        setmetatable(t,{ __call = f })
    end
    return t
end

function table.setmetatablekey(t,key,value)
    local m = getmetatable(t)
    if not m then
        m = { }
        setmetatable(t,m)
    end
    m[key] = value
    return t
end

function table.getmetatablekey(t,key,value)
    local m = getmetatable(t)
    return m and m[key]
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['util-mrg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- hm, quite unreadable

local gsub, format = string.gsub, string.format
local concat = table.concat
local type, next = type, next

utilities             = utilities or {}
utilities.merger      = utilities.merger or { } -- maybe mergers
utilities.report      = logs and logs.reporter("system") or print

local merger          = utilities.merger

merger.strip_comment  = true

local m_begin_merge   = "begin library merge"
local m_end_merge     = "end library merge"
local m_begin_closure = "do -- create closure to overcome 200 locals limit"
local m_end_closure   = "end -- of closure"

local m_pattern =
    "%c+" ..
    "%-%-%s+" .. m_begin_merge ..
    "%c+(.-)%c+" ..
    "%-%-%s+" .. m_end_merge ..
    "%c+"

local m_format =
    "\n\n-- " .. m_begin_merge ..
    "\n%s\n" ..
    "-- " .. m_end_merge .. "\n\n"

local m_faked =
    "-- " .. "created merged file" .. "\n\n" ..
    "-- " .. m_begin_merge .. "\n\n" ..
    "-- " .. m_end_merge .. "\n\n"

local function self_fake()
    return m_faked
end

local function self_nothing()
    return ""
end

local function self_load(name)
    local data = io.loaddata(name) or ""
    if data == "" then
        utilities.report("merge: unknown file %s",name)
    else
        utilities.report("merge: inserting %s",name)
    end
    return data or ""
end

local function self_save(name, data)
    if data ~= "" then
        if merger.strip_comment then
            -- saves some 20K
            local n = #data
            data = gsub(data,"%-%-~[^\n\r]*[\r\n]","")
            utilities.report("merge: %s bytes of comment stripped, %s bytes of code left",n-#data,#data)
        end
        io.savedata(name,data)
        utilities.report("merge: saving %s",name)
    end
end

local function self_swap(data,code)
    return data ~= "" and (gsub(data,m_pattern, function() return format(m_format,code) end, 1)) or ""
end

local function self_libs(libs,list)
    local result, f, frozen, foundpath = { }, nil, false, nil
    result[#result+1] = "\n"
    if type(libs) == 'string' then libs = { libs } end
    if type(list) == 'string' then list = { list } end
    for i=1,#libs do
        local lib = libs[i]
        for j=1,#list do
            local pth = gsub(list[j],"\\","/") -- file.clean_path
            utilities.report("merge: checking library path %s",pth)
            local name = pth .. "/" .. lib
            if lfs.isfile(name) then
                foundpath = pth
            end
        end
        if foundpath then break end
    end
    if foundpath then
        utilities.report("merge: using library path %s",foundpath)
        local right, wrong = { }, { }
        for i=1,#libs do
            local lib = libs[i]
            local fullname = foundpath .. "/" .. lib
            if lfs.isfile(fullname) then
                utilities.report("merge: using library %s",fullname)
                right[#right+1] = lib
                result[#result+1] = m_begin_closure
                result[#result+1] = io.loaddata(fullname,true)
                result[#result+1] = m_end_closure
            else
                utilities.report("merge: skipping library %s",fullname)
                wrong[#wrong+1] = lib
            end
        end
        if #right > 0 then
            utilities.report("merge: used libraries: %s",concat(right," "))
        end
        if #wrong > 0 then
            utilities.report("merge: skipped libraries: %s",concat(wrong," "))
        end
    else
        utilities.report("merge: no valid library path found")
    end
    return concat(result, "\n\n")
end

function merger.selfcreate(libs,list,target)
    if target then
        self_save(target,self_swap(self_fake(),self_libs(libs,list)))
    end
end

function merger.selfmerge(name,libs,list,target)
    self_save(target or name,self_swap(self_load(name),self_libs(libs,list)))
end

function merger.selfclean(name)
    self_save(name,self_swap(self_load(name),self_nothing()))
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['util-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities        = utilities or {}
utilities.lua    = utilities.lua or { }
utilities.report = logs and logs.reporter("system") or print

local function stupidcompile(luafile,lucfile)
    local data = io.loaddata(luafile)
    if data and data ~= "" then
        data = string.dump(data)
        if data and data ~= "" then
            io.savedata(lucfile,data)
        end
    end
end

function utilities.lua.compile(luafile,lucfile,cleanup,strip,fallback) -- defaults: cleanup=false strip=true
    utilities.report("lua: compiling %s into %s",luafile,lucfile)
    os.remove(lucfile)
    local command = "-o " .. string.quoted(lucfile) .. " " .. string.quoted(luafile)
    if strip ~= false then
        command = "-s " .. command
    end
    local done = os.spawn("texluac " .. command) == 0 -- or os.spawn("luac " .. command) == 0
    if not done and fallback then
        utilities.report("lua: dumping %s into %s (unstripped)",luafile,lucfile)
        stupidcompile(luafile,lucfile) -- maybe use the stripper we have elsewhere
        cleanup = false -- better see how worse it is
    end
    if done and cleanup == true and lfs.isfile(lucfile) and lfs.isfile(luafile) then
        utilities.report("lua: removing %s",luafile)
        os.remove(luafile)
    end
    return done
end








end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['util-prs'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, R, V, C, Ct, Cs, Carg = lpeg.P, lpeg.R, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.Carg
local lpegmatch = lpeg.match
local concat, format, gmatch, find = table.concat, string.format, string.gmatch, string.find
local tostring, type, next = tostring, type, next

utilities         = utilities or {}
utilities.parsers = utilities.parsers or { }
local parsers     = utilities.parsers
parsers.patterns  = parsers.patterns or { }

local setmetatableindex = table.setmetatableindex
local sortedhash        = table.sortedhash

-- we could use a Cf Cg construct

local escape, left, right = P("\\"), P('{'), P('}')

lpeg.patterns.balanced = P {
    [1] = ((escape * (left+right)) + (1 - (left+right)) + V(2))^0,
    [2] = left * V(1) * right
}

local space     = P(' ')
local equal     = P("=")
local comma     = P(",")
local lbrace    = P("{")
local rbrace    = P("}")
local nobrace   = 1 - (lbrace+rbrace)
local nested    = P { lbrace * (nobrace + V(1))^0 * rbrace }
local spaces    = space^0
local argument  = Cs((lbrace/"") * ((nobrace + nested)^0) * (rbrace/""))
local content   = (1-P(-1))^0

lpeg.patterns.nested   = nested    -- no capture
lpeg.patterns.argument = argument  -- argument after e.g. =
lpeg.patterns.content  = content   -- rest after e.g =

local value     = P(lbrace * C((nobrace + nested)^0) * rbrace) + C((nested + (1-comma))^0)

local key       = C((1-equal-comma)^1)
local pattern_a = (space+comma)^0 * (key * equal * value + key * C(""))
local pattern_c = (space+comma)^0 * (key * equal * value)

local key       = C((1-space-equal-comma)^1)
local pattern_b = spaces * comma^0 * spaces * (key * ((spaces * equal * spaces * value) + C("")))

-- "a=1, b=2, c=3, d={a{b,c}d}, e=12345, f=xx{a{b,c}d}xx, g={}" : outer {} removes, leading spaces ignored

local hash = { }

local function set(key,value)
    hash[key] = value
end

local function set(key,value)
    hash[key] = value
end

local pattern_a_s = (pattern_a/set)^1
local pattern_b_s = (pattern_b/set)^1
local pattern_c_s = (pattern_c/set)^1

parsers.patterns.settings_to_hash_a = pattern_a_s
parsers.patterns.settings_to_hash_b = pattern_b_s
parsers.patterns.settings_to_hash_c = pattern_c_s

function parsers.make_settings_to_hash_pattern(set,how)
    if how == "strict" then
        return (pattern_c/set)^1
    elseif how == "tolerant" then
        return (pattern_b/set)^1
    else
        return (pattern_a/set)^1
    end
end

function parsers.settings_to_hash(str,existing)
    if str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_a_s,str)
        return hash
    else
        return { }
    end
end

function parsers.settings_to_hash_tolerant(str,existing)
    if str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_b_s,str)
        return hash
    else
        return { }
    end
end

function parsers.settings_to_hash_strict(str,existing)
    if str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_c_s,str)
        return next(hash) and hash
    else
        return nil
    end
end

local separator = comma * space^0
local value     = P(lbrace * C((nobrace + nested)^0) * rbrace) + C((nested + (1-comma))^0)
local pattern   = Ct(value*(separator*value)^0)

-- "aap, {noot}, mies" : outer {} removes, leading spaces ignored

parsers.patterns.settings_to_array = pattern

-- we could use a weak table as cache

function parsers.settings_to_array(str,strict)
    if not str or str == "" then
        return { }
    elseif strict then
        if find(str,"{") then
            return lpegmatch(pattern,str)
        else
            return { str }
        end
    else
        return lpegmatch(pattern,str)
    end
end

local function set(t,v)
    t[#t+1] = v
end

local value   = P(Carg(1)*value) / set
local pattern = value*(separator*value)^0 * Carg(1)

function parsers.add_settings_to_array(t,str)
    return lpegmatch(pattern,str,nil,t)
end

function parsers.hash_to_string(h,separator,yes,no,strict,omit)
    if h then
        local t, tn, s = { }, 0, table.sortedkeys(h)
        omit = omit and table.tohash(omit)
        for i=1,#s do
            local key = s[i]
            if not omit or not omit[key] then
                local value = h[key]
                if type(value) == "boolean" then
                    if yes and no then
                        if value then
                            tn = tn + 1
                            t[tn] = key .. '=' .. yes
                        elseif not strict then
                            tn = tn + 1
                            t[tn] = key .. '=' .. no
                        end
                    elseif value or not strict then
                        tn = tn + 1
                        t[tn] = key .. '=' .. tostring(value)
                    end
                else
                    tn = tn + 1
                    t[tn] = key .. '=' .. value
                end
            end
        end
        return concat(t,separator or ",")
    else
        return ""
    end
end

function parsers.array_to_string(a,separator)
    if a then
        return concat(a,separator or ",")
    else
        return ""
    end
end

function parsers.settings_to_set(str,t) -- tohash? -- todo: lpeg -- duplicate anyway
    t = t or { }
--  for s in gmatch(str,"%s*([^, ]+)") do -- space added
    for s in gmatch(str,"[^, ]+") do -- space added
        t[s] = true
    end
    return t
end

function parsers.simple_hash_to_string(h, separator)
    local t, tn = { }, 0
    for k, v in sortedhash(h) do
        if v then
            tn = tn + 1
            t[tn] = k
        end
    end
    return concat(t,separator or ",")
end

local value   = lbrace * C((nobrace + nested)^0) * rbrace
local pattern = Ct((space + value)^0)

function parsers.arguments_to_table(str)
    return lpegmatch(pattern,str)
end

-- temporary here (unoptimized)

function parsers.getparameters(self,class,parentclass,settings)
    local sc = self[class]
    if not sc then
        sc = { }
        self[class] = sc
        if parentclass then
            local sp = self[parentclass]
            if not sp then
                sp = { }
                self[parentclass] = sp
            end
            setmetatableindex(sc,sp)
        end
    end
    parsers.settings_to_hash(settings,sc)
end

function parsers.listitem(str)
    return gmatch(str,"[^, ]+")
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['util-fmt'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities            = utilities or { }
utilities.formatters = utilities.formatters or { }
local formatters     = utilities.formatters

local concat, format = table.concat, string.format
local tostring, type = tostring, type
local strip = string.strip

local P, R, Cs = lpeg.P, lpeg.R, lpeg.Cs
local lpegmatch = lpeg.match

-- temporary here

local digit         = R("09")
local period        = P(".")
local zero          = P("0")
local trailingzeros = zero^0 * -digit -- suggested by Roberto R
local case_1        = period * trailingzeros / ""
local case_2        = period * (digit - trailingzeros)^1 * (trailingzeros / "")
local number        = digit^1 * (case_1 + case_2)
local stripper      = Cs((number + 1)^0)


lpeg.patterns.stripzeros = stripper

function formatters.stripzeros(str)
    return lpegmatch(stripper,str)
end

function formatters.formatcolumns(result,between)
    if result and #result > 0 then
        between = between or "   "
        local widths, numbers = { }, { }
        local first = result[1]
        local n = #first
        for i=1,n do
            widths[i] = 0
        end
        for i=1,#result do
            local r = result[i]
            for j=1,n do
                local rj = r[j]
                local tj = type(rj)
                if tj == "number" then
                    numbers[j] = true
                end
                if tj ~= "string" then
                    rj = tostring(rj)
                    r[j] = rj
                end
                local w = #rj
                if w > widths[j] then
                    widths[j] = w
                end
            end
        end
        for i=1,n do
            local w = widths[i]
            if numbers[i] then
                if w > 80 then
                    widths[i] = "%s" .. between
                 else
                    widths[i] = "%0" .. w .. "i" .. between
                end
            else
                if w > 80 then
                    widths[i] = "%s" .. between
                 elseif w > 0 then
                    widths[i] = "%-" .. w .. "s" .. between
                else
                    widths[i] = "%s"
                end
            end
        end
        local template = strip(concat(widths))
        for i=1,#result do
            local str = format(template,unpack(result[i]))
            result[i] = strip(str)
        end
    end
    return result
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['util.deb'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- the <anonymous> tag is kind of generic and used for functions that are not
-- bound to a variable, like node.new, node.copy etc (contrary to for instance
-- node.has_attribute which is bound to a has_attribute local variable in mkiv)

local debug = require "debug"

local getinfo = debug.getinfo
local type, next, tostring = type, next, tostring
local format, find = string.format, string.find
local is_boolean = string.is_boolean

utilities          = utilities or { }
utilities.debugger = utilities.debugger or { }
local debugger     = utilities.debugger

local counters = { }
local names    = { }

-- one

local function hook()
    local f = getinfo(2) -- "nS"
    if f then
        local n = "unknown"
        if f.what == "C" then
            n = f.name or '<anonymous>'
            if not names[n] then
                names[n] = format("%42s",n)
            end
        else
            -- source short_src linedefined what name namewhat nups func
            n = f.name or f.namewhat or f.what
            if not n or n == "" then
                n = "?"
            end
            if not names[n] then
                names[n] = format("%42s : % 5i : %s",n,f.linedefined or 0,f.short_src or "unknown source")
            end
        end
        counters[n] = (counters[n] or 0) + 1
    end
end

function debugger.showstats(printer,threshold) -- hm, something has changed, rubish now
    printer   = printer or texio.write or print
    threshold = threshold or 0
    local total, grandtotal, functions = 0, 0, 0
    local dataset = { }
    for name, count in next, counters do
        dataset[#dataset+1] = { name, count }
    end
    table.sort(dataset,function(a,b) return a[2] == b[2] and b[1] > a[1] or a[2] > b[2] end)
    for i=1,#dataset do
        local d = dataset[i]
        local name  = d[1]
        local count = d[2]
        if count > threshold and not find(name,"for generator") then -- move up
            printer(format("%8i  %s\n", count, names[name]))
            total = total + count
        end
        grandtotal = grandtotal + count
        functions = functions + 1
    end
    printer("\n")
    printer(format("functions  : % 10i\n", functions))
    printer(format("total      : % 10i\n", total))
    printer(format("grand total: % 10i\n", grandtotal))
    printer(format("threshold  : % 10i\n", threshold))
end

function debugger.savestats(filename,threshold)
    local f = io.open(filename,'w')
    if f then
        debugger.showstats(function(str) f:write(str) end,threshold)
        f:close()
    end
end

function debugger.enable()
    debug.sethook(hook,"c")
end

function debugger.disable()
    debug.sethook()
end





local is_node = node and node.is_node
local is_lpeg = lpeg and lpeg.type

function inspect(i) -- global function
    local ti = type(i)
    if ti == "table" then
        table.print(i,"table")
    elseif is_node and is_node(i) then
        table.print(nodes.astable(i),tostring(i))
    elseif is_lpeg and is_lpeg(i) then
        lpeg.print(i)
    else
        print(tostring(i))
    end
end

-- from the lua book:

function traceback()
    local level = 1
    while true do
        local info = debug.getinfo(level, "Sl")
        if not info then
            break
        elseif info.what == "C" then
            print(format("%3i : C function",level))
        else
            print(format("%3i : [%s]:%d",level,info.short_src,info.currentline))
        end
        level = level + 1
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['trac-inf'] = {
    version   = 1.001,
    comment   = "companion to trac-inf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- As we want to protect the global tables, we no longer store the timing
-- in the tables themselves but in a hidden timers table so that we don't
-- get warnings about assignments. This is more efficient than using rawset
-- and rawget.

local format, lower = string.format, string.lower
local clock = os.gettimeofday or os.clock -- should go in environment
local write_nl = texio.write_nl

statistics       = statistics or { }
local statistics = statistics

statistics.enable    = true
statistics.threshold = 0.05

local statusinfo, n, registered, timers = { }, 0, { }, { }

local function hastiming(instance)
    return instance and timers[instance]
end

local function resettiming(instance)
    timers[instance or "notimer"] = { timing = 0, loadtime = 0 }
end

local function starttiming(instance)
    local timer = timers[instance or "notimer"]
    if not timer then
        timer = { }
        timers[instance or "notimer"] = timer
    end
    local it = timer.timing
    if not it then
        it = 0
    end
    if it == 0 then
        timer.starttime = clock()
        if not timer.loadtime then
            timer.loadtime = 0
        end
    end
    timer.timing = it + 1
end

local function stoptiming(instance, report)
    local timer = timers[instance or "notimer"]
    local it = timer.timing
    if it > 1 then
        timer.timing = it - 1
    else
        local starttime = timer.starttime
        if starttime then
            local stoptime = clock()
            local loadtime = stoptime - starttime
            timer.stoptime = stoptime
            timer.loadtime = timer.loadtime + loadtime
            if report then
                statistics.report("load time %0.3f",loadtime)
            end
            timer.timing = 0
            return loadtime
        end
    end
    return 0
end

local function elapsedtime(instance)
    local timer = timers[instance or "notimer"]
    return format("%0.3f",timer and timer.loadtime or 0)
end

local function elapsedindeed(instance)
    local timer = timers[instance or "notimer"]
    return (timer and timer.loadtime or 0) > statistics.threshold
end

local function elapsedseconds(instance,rest) -- returns nil if 0 seconds
    if elapsedindeed(instance) then
        return format("%s seconds %s", elapsedtime(instance),rest or "")
    end
end

statistics.hastiming      = hastiming
statistics.resettiming    = resettiming
statistics.starttiming    = starttiming
statistics.stoptiming     = stoptiming
statistics.elapsedtime    = elapsedtime
statistics.elapsedindeed  = elapsedindeed
statistics.elapsedseconds = elapsedseconds

-- general function

function statistics.register(tag,fnc)
    if statistics.enable and type(fnc) == "function" then
        local rt = registered[tag] or (#statusinfo + 1)
        statusinfo[rt] = { tag, fnc }
        registered[tag] = rt
        if #tag > n then n = #tag end
    end
end

function statistics.show(reporter)
    if statistics.enable then
        if not reporter then reporter = function(tag,data,n) write_nl(tag .. " " .. data) end end
        -- this code will move
        local register = statistics.register
        register("luatex banner", function()
            return lower(status.banner)
        end)
        register("control sequences", function()
            return format("%s of %s + %s", status.cs_count, status.hash_size,status.hash_extra)
        end)
        register("callbacks", function()
            local total, indirect = status.callbacks or 0, status.indirect_callbacks or 0
            return format("%s direct, %s indirect, %s total", total-indirect, indirect, total)
        end)
        collectgarbage("collect")
        register("current memory usage", statistics.memused)
        register("runtime",statistics.runtime)
        for i=1,#statusinfo do
            local s = statusinfo[i]
            local r = s[2]()
            if r then
                reporter(s[1],r,n)
            end
        end
        write_nl("") -- final newline
        statistics.enable = false
    end
end

local template, report_statistics, nn = nil, nil, 0 -- we only calcute it once

function statistics.showjobstat(tag,data,n)
    if not logs then
        -- sorry
    elseif type(data) == "table" then
        for i=1,#data do
            statistics.showjobstat(tag,data[i],n)
        end
    else
        if not template or n > nn then
            template, n = format("%%-%ss - %%s",n), nn
            report_statistics = logs.reporter("mkiv lua stats")
        end
        report_statistics(format(template,tag,data))
    end
end

function statistics.memused() -- no math.round yet -)
    local round = math.round or math.floor
    return format("%s MB (ctx: %s MB)",round(collectgarbage("count")/1000), round(status.luastate_bytes/1000000))
end

starttiming(statistics)

function statistics.formatruntime(runtime) -- indirect so it can be overloaded and
    return format("%s seconds", runtime)   -- indeed that happens in cure-uti.lua
end

function statistics.runtime()
    stoptiming(statistics)
    return statistics.formatruntime(elapsedtime(statistics))
end

function statistics.timed(action,report)
    report = report or logs.reporter("system")
    starttiming("run")
    action()
    stoptiming("run")
    report("total runtime: %s",elapsedtime("run"))
end

-- where, not really the best spot for this:

commands = commands or { }

function commands.resettimer(name)
    resettiming(name or "whatever")
    starttiming(name or "whatever")
end

function commands.elapsedtime(name)
    stoptiming(name or "whatever")
    context(elapsedtime(name or "whatever"))
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['trac-set'] = { -- might become util-set.lua
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tostring = type, next, tostring
local concat = table.concat
local format, find, lower, gsub, escapedpattern = string.format, string.find, string.lower, string.gsub, string.escapedpattern
local is_boolean = string.is_boolean
local settings_to_hash = utilities.parsers.settings_to_hash
local allocate = utilities.storage.allocate

utilities         = utilities or { }
local utilities   = utilities
utilities.setters = utilities.setters or { }
local setters     = utilities.setters

local data = { } -- maybe just local

-- We can initialize from the cnf file. This is sort of tricky as
-- later defined setters also need to be initialized then. If set
-- this way, we need to ensure that they are not reset later on.

local trace_initialize = false -- only for testing during development

function setters.initialize(filename,name,values) -- filename only for diagnostics
    local setter = data[name]
    if setter then
        local data = setter.data
        if data then
            for key, value in next, values do
             -- key = gsub(key,"_",".")
                value = is_boolean(value,value)
                local functions = data[key]
                if functions then
                    if #functions > 0 and not functions.value then
                        if trace_initialize then
                            setter.report("executing %s (%s -> %s)",key,filename,tostring(value))
                        end
                        for i=1,#functions do
                            functions[i](value)
                        end
                        functions.value = value
                    else
                        if trace_initialize then
                            setter.report("skipping %s (%s -> %s)",key,filename,tostring(value))
                        end
                    end
                else
                    -- we do a simple preregistration i.e. not in the
                    -- list as it might be an obsolete entry
                    functions = { default = value }
                    data[key] = functions
                    if trace_initialize then
                        setter.report("storing %s (%s -> %s)",key,filename,tostring(value))
                    end
                end
            end
            return true
        end
    end
end

-- user interface code

local function set(t,what,newvalue)
    local data, done = t.data, t.done
    if type(what) == "string" then
        what = settings_to_hash(what) -- inefficient but ok
    end
    if type(what) ~= "table" then
        return
    end
    if not done then -- catch ... why not set?
        done = { }
        t.done = done
    end
    for w, value in next, what do
        if value == "" then
            value = newvalue
        elseif not value then
            value = false -- catch nil
        else
            value = is_boolean(value,value)
        end
        w = "^" .. escapedpattern(w,true) .. "$" -- new: anchored
        for name, functions in next, data do
            if done[name] then
                -- prevent recursion due to wildcards
            elseif find(name,w) then
                done[name] = true
                for i=1,#functions do
                    functions[i](value)
                end
                functions.value = value
            end
        end
    end
end

local function reset(t)
    for name, functions in next, t.data do
        for i=1,#functions do
            functions[i](false)
        end
        functions.value = false
    end
end

local function enable(t,what)
    set(t,what,true)
end

local function disable(t,what)
    local data = t.data
    if not what or what == "" then
        t.done = { }
        reset(t)
    else
        set(t,what,false)
    end
end

function setters.register(t,what,...)
    local data = t.data
    what = lower(what)
    local functions = data[what]
    if not functions then
        functions = { }
        data[what] = functions
        if trace_initialize then
            t.report("defining %s",what)
        end
    end
    local default = functions.default -- can be set from cnf file
    for _, fnc in next, { ... } do
        local typ = type(fnc)
        if typ == "string" then
            if trace_initialize then
                t.report("coupling %s to %s",what,fnc)
            end
            local s = fnc -- else wrong reference
            fnc = function(value) set(t,s,value) end
        elseif typ ~= "function" then
            fnc = nil
        end
        if fnc then
            functions[#functions+1] = fnc
            -- default: set at command line or in cnf file
            -- value  : set in tex run (needed when loading runtime)
            local value = functions.value or default
            if value ~= nil then
                fnc(value)
                functions.value = value
            end
        end
    end
    return false -- so we can use it in an assignment
end

function setters.enable(t,what)
    local e = t.enable
    t.enable, t.done = enable, { }
    enable(t,what)
    t.enable, t.done = e, { }
end

function setters.disable(t,what)
    local e = t.disable
    t.disable, t.done = disable, { }
    disable(t,what)
    t.disable, t.done = e, { }
end

function setters.reset(t)
    t.done = { }
    reset(t)
end

function setters.list(t) -- pattern
    local list = table.sortedkeys(t.data)
    local user, system = { }, { }
    for l=1,#list do
        local what = list[l]
        if find(what,"^%*") then
            system[#system+1] = what
        else
            user[#user+1] = what
        end
    end
    return user, system
end

function setters.show(t)
    local category = t.name
    local list = setters.list(t)
    t.report()
    for k=1,#list do
        local name = list[k]
        local functions = t.data[name]
        if functions then
            local value, default, modules = functions.value, functions.default, #functions
            value   = value   == nil and "unset" or tostring(value)
            default = default == nil and "unset" or tostring(default)
            t.report("%-30s   modules: %2i   default: %6s   value: %6s",name,modules,default,value)
        end
    end
    t.report()
end

-- we could have used a bit of oo and the trackers:enable syntax but
-- there is already a lot of code around using the singular tracker

-- we could make this into a module but we also want the rest avaliable

local enable, disable, register, list, show = setters.enable, setters.disable, setters.register, setters.list, setters.show

local function report(setter,...)
    local report = logs and logs.report
    if report then
        report(setter.name,...)
    else -- fallback, as this module is loaded before the logger
        write_nl(format("%-15s : %s\n",setter.name,format(...)))
    end
end

function setters.new(name)
    local setter -- we need to access it in setter itself
    setter = {
        data     = allocate(), -- indexed, but also default and value fields
        name     = name,
        report   = function(...) report  (setter,...) end,
        enable   = function(...) enable  (setter,...) end,
        disable  = function(...) disable (setter,...) end,
        register = function(...) register(setter,...) end,
        list     = function(...) list    (setter,...) end,
        show     = function(...) show    (setter,...) end,
    }
    data[name] = setter
    return setter
end

trackers    = setters.new("trackers")
directives  = setters.new("directives")
experiments = setters.new("experiments")

local t_enable, t_disable, t_report = trackers   .enable, trackers   .disable, trackers   .report
local d_enable, d_disable, d_report = directives .enable, directives .disable, directives .report
local e_enable, e_disable, e_report = experiments.enable, experiments.disable, experiments.report

-- nice trick: we overload two of the directives related functions with variants that
-- do tracing (itself using a tracker) .. proof of concept

local trace_directives  = false local trace_directives  = false  trackers.register("system.directives",  function(v) trace_directives  = v end)
local trace_experiments = false local trace_experiments = false  trackers.register("system.experiments", function(v) trace_experiments = v end)

function directives.enable(...)
    if trace_directives then
        d_report("enabling: %s",concat({...}," "))
    end
    d_enable(...)
end

function directives.disable(...)
    if trace_directives then
        d_report("disabling: %s",concat({...}," "))
    end
    d_disable(...)
end

function experiments.enable(...)
    if trace_experiments then
        e_report("enabling: %s",concat({...}," "))
    end
    e_enable(...)
end

function experiments.disable(...)
    if trace_experiments then
        e_report("disabling: %s",concat({...}," "))
    end
    e_disable(...)
end

-- a useful example

directives.register("system.nostatistics", function(v)
    statistics.enable = not v
end)

directives.register("system.nolibraries", function(v)
    libraries = nil -- we discard this tracing for security
end)

-- experiment

local flags = environment and environment.engineflags

if flags then
    if trackers and flags.trackers then
        setters.initialize("flags","trackers", settings_to_hash(flags.trackers))
     -- t_enable(flags.trackers)
    end
    if directives and flags.directives then
        setters.initialize("flags","directives", settings_to_hash(flags.directives))
     -- d_enable(flags.directives)
    end
end

-- here

if texconfig then

    -- this happens too late in ini mode but that is no problem

    local function set(k,v)
        v = tonumber(v)
        if v then
            texconfig[k] = v
        end
    end

    directives.register("luatex.expanddepth",  function(v) set("expand_depth",v)   end)
    directives.register("luatex.hashextra",    function(v) set("hash_extra",v)     end)
    directives.register("luatex.nestsize",     function(v) set("nest_size",v)      end)
    directives.register("luatex.maxinopen",    function(v) set("max_in_open",v)    end)
    directives.register("luatex.maxprintline", function(v) set("max_print_line",v) end)
    directives.register("luatex.maxstrings",   function(v) set("max_strings",v)    end)
    directives.register("luatex.paramsize",    function(v) set("param_size",v)     end)
    directives.register("luatex.savesize",     function(v) set("save_size",v)      end)
    directives.register("luatex.stacksize",    function(v) set("stack_size",v)     end)

end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['trac-log'] = {
    version   = 1.001,
    comment   = "companion to trac-log.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: less categories, more subcategories (e.g. nodes)


local write_nl, write = texio and texio.write_nl or print, texio and texio.write or io.write
local format, gmatch, find = string.format, string.gmatch, string.find
local concat, insert, remove = table.concat, table.insert, table.remove
local escapedpattern = string.escapedpattern
local texcount = tex and tex.count
local next, type = next, type

local setmetatableindex = table.setmetatableindex

--[[ldx--
<p>This is a prelude to a more extensive logging module. We no longer
provide <l n='xml'/> based logging a sparsing is relatively easy anyway.</p>
--ldx]]--

logs       = logs or { }
local logs = logs

local moreinfo = [[
More information about ConTeXt and the tools that come with it can be found at:

maillist : ntg-context@ntg.nl / http://www.ntg.nl/mailman/listinfo/ntg-context
webpage  : http://www.pragma-ade.nl / http://tex.aanhet.net
wiki     : http://contextgarden.net
]]

-- basic loggers

local function ignore() end

setmetatableindex(logs, function(t,k) t[k] = ignore ; return ignore end)

local report, subreport, status, settarget, setformats, settranslations

local direct, subdirect, writer, pushtarget, poptarget

if tex and (tex.jobname or tex.formatname) then

    local valueiskey   = { __index = function(t,k) t[k] = k return k end } -- will be helper

    local target       = "term and log"

    logs.flush         = io.flush

    local formats      = { } setmetatable(formats,     valueiskey)
    local translations = { } setmetatable(translations,valueiskey)

    writer = function(...)
        write_nl(target,...)
    end

    newline = function()
        write_nl(target,"\n")
    end

    report = function(a,b,c,...)
        if c then
            write_nl(target,format("%-15s > %s\n",translations[a],format(formats[b],c,...)))
        elseif b then
            write_nl(target,format("%-15s > %s\n",translations[a],formats[b]))
        elseif a then
            write_nl(target,format("%-15s >\n",   translations[a]))
        else
            write_nl(target,"\n")
        end
    end

    direct = function(a,b,c,...)
        if c then
            return format("%-15s > %s",translations[a],format(formats[b],c,...))
        elseif b then
            return format("%-15s > %s",translations[a],formats[b])
        elseif a then
            return format("%-15s >",   translations[a])
        else
            return ""
        end
    end

    subreport = function(a,s,b,c,...)
        if c then
            write_nl(target,format("%-15s > %s > %s\n",translations[a],translations[s],format(formats[b],c,...)))
        elseif b then
            write_nl(target,format("%-15s > %s > %s\n",translations[a],translations[s],formats[b]))
        elseif a then
            write_nl(target,format("%-15s > %s >\n",   translations[a],translations[s]))
        else
            write_nl(target,"\n")
        end
    end

    subdirect = function(a,s,b,c,...)
        if c then
            return format("%-15s > %s > %s",translations[a],translations[s],format(formats[b],c,...))
        elseif b then
            return format("%-15s > %s > %s",translations[a],translations[s],formats[b])
        elseif a then
            return format("%-15s > %s >",   translations[a],translations[s])
        else
            return ""
        end
    end

    status = function(a,b,c,...)
        if c then
            write_nl(target,format("%-15s : %s\n",translations[a],format(formats[b],c,...)))
        elseif b then
            write_nl(target,format("%-15s : %s\n",translations[a],formats[b]))
        elseif a then
            write_nl(target,format("%-15s :\n",   translations[a]))
        else
            write_nl(target,"\n")
        end
    end

    local targets = {
        logfile  = "log",
        log      = "log",
        file     = "log",
        console  = "term",
        terminal = "term",
        both     = "term and log",
    }

    settarget = function(whereto)
        target = targets[whereto or "both"] or targets.both
        if target == "term" or target == "term and log" then
            logs.flush = io.flush
        else
            logs.flush = ignore
        end
    end

    local stack = { }

    pushtarget = function(newtarget)
        insert(stack,target)
        settarget(newtarget)
    end

    poptarget = function()
        if #stack > 0 then
            settarget(remove(stack))
        end
    end

    setformats = function(f)
        formats = f
    end

    settranslations = function(t)
        translations = t
    end

else

    logs.flush = ignore

    writer = write_nl

    newline = function()
        write_nl("\n")
    end

    report = function(a,b,c,...)
        if c then
            write_nl(format("%-15s | %s",a,format(b,c,...)))
        elseif b then
            write_nl(format("%-15s | %s",a,b))
        elseif a then
            write_nl(format("%-15s |",   a))
        else
            write_nl("")
        end
    end

    subreport = function(a,sub,b,c,...)
        if c then
            write_nl(format("%-15s | %s | %s",a,sub,format(b,c,...)))
        elseif b then
            write_nl(format("%-15s | %s | %s",a,sub,b))
        elseif a then
            write_nl(format("%-15s | %s |",   a,sub))
        else
            write_nl("")
        end
    end

    status = function(a,b,c,...) -- not to be used in lua anyway
        if c then
            write_nl(format("%-15s : %s\n",a,format(b,c,...)))
        elseif b then
            write_nl(format("%-15s : %s\n",a,b)) -- b can have %'s
        elseif a then
            write_nl(format("%-15s :\n",   a))
        else
            write_nl("\n")
        end
    end

    direct          = ignore
    subdirect       = ignore

    settarget       = ignore
    pushtarget      = ignore
    poptarget       = ignore
    setformats      = ignore
    settranslations = ignore

end

logs.report          = report
logs.subreport       = subreport
logs.status          = status
logs.settarget       = settarget
logs.pushtarget      = pushtarget
logs.poptarget       = poptarget
logs.setformats      = setformats
logs.settranslations = settranslations

logs.direct          = direct
logs.subdirect       = subdirect
logs.writer          = writer
logs.newline         = newline

-- installer

-- todo: renew (un) locks when a new one is added and wildcard

local data, states = { }, nil

function logs.reporter(category,subcategory)
    local logger = data[category]
    if not logger then
        local state = false
        if states == true then
            state = true
        elseif type(states) == "table" then
            for c, _ in next, states do
                if find(category,c) then
                    state = true
                    break
                end
            end
        end
        logger = {
            reporters = { },
            state = state,
        }
        data[category] = logger
    end
    local reporter = logger.reporters[subcategory or "default"]
    if not reporter then
        if subcategory then
            reporter = function(...)
                if not logger.state then
                    subreport(category,subcategory,...)
                end
            end
            logger.reporters[subcategory] = reporter
        else
            local tag = category
            reporter = function(...)
                if not logger.state then
                    report(category,...)
                end
            end
            logger.reporters.default = reporter
        end
    end
    return reporter
end

logs.new = logs.reporter -- for old times sake

-- context specicific: this ends up in the macro stream

local ctxreport = logs.writer

function logs.setmessenger(m)
    ctxreport = m
end

function logs.messenger(category,subcategory)
    -- we need to avoid catcode mess (todo: fast context)
    if subcategory then
        return function(...)
            ctxreport(subdirect(category,subcategory,...))
        end
    else
        return function(...)
            ctxreport(direct(category,...))
        end
    end
end

-- so far

local function setblocked(category,value)
    if category == true then
        -- lock all
        category, value = "*", true
    elseif category == false then
        -- unlock all
        category, value = "*", false
    elseif value == nil then
        -- lock selective
        value = true
    end
    if category == "*" then
        states = value
        for k, v in next, data do
            v.state = value
        end
    else
        states = utilities.parsers.settings_to_hash(category)
        for c, _ in next, states do
            if data[c] then
                v.state = value
            else
                c = escapedpattern(c,true)
                for k, v in next, data do
                    if find(k,c) then
                        v.state = value
                    end
                end
            end
        end
    end
end

function logs.disable(category,value)
    setblocked(category,value == nil and true or value)
end

function logs.enable(category)
    setblocked(category,false)
end

function logs.categories()
    return table.sortedkeys(data)
end

function logs.show()
    local n, c, s, max = 0, 0, 0, 0
    for category, v in table.sortedpairs(data) do
        n = n + 1
        local state = v.state
        local reporters = v.reporters
        local nc = #category
        if nc > c then
            c = nc
        end
        for subcategory, _ in next, reporters do
            local ns = #subcategory
            if ns > c then
                s = ns
            end
            local m = nc + ns
            if m > max then
                max = m
            end
        end
        local subcategories = concat(table.sortedkeys(reporters),", ")
        if state == true then
            state = "disabled"
        elseif state == false then
            state = "enabled"
        else
            state = "unknown"
        end
        -- no new here
        report("logging","category: '%s', subcategories: '%s', state: '%s'",category,subcategories,state)
    end
    report("logging","categories: %s, max category: %s, max subcategory: %s, max combined: %s",n,c,s,max)
end

directives.register("logs.blocked", function(v)
    setblocked(v,true)
end)

directives.register("logs.target", function(v)
    settarget(v)
end)

-- tex specific loggers (might move elsewhere)

local report_pages = logs.reporter("pages") -- not needed but saves checking when we grep for it

local real, user, sub

function logs.start_page_number()
    real, user, sub = texcount.realpageno, texcount.userpageno, texcount.subpageno
--     real, user, sub = 0, 0, 0
end

local timing    = false
local starttime = nil
local lasttime  = nil

trackers.register("pages.timing", function(v) -- only for myself (diagnostics)
    starttime = os.clock()
    timing    = true
end)

function logs.stop_page_number() -- the first page can includes the initialization so we omit this in average
    if timing then
        local elapsed, average
        local stoptime = os.clock()
        if not lasttime or real < 2 then
            elapsed   = stoptime
            average   = stoptime
            starttime = stoptime
        else
            elapsed  = stoptime - lasttime
            average  = (stoptime - starttime) / (real - 1)
        end
        lasttime = stoptime
        if real > 0 then
            if user > 0 then
                if sub > 0 then
                    report_pages("flushing realpage %s, userpage %s, subpage %s, time %0.04f / %0.04f",real,user,sub,elapsed,average)
                else
                    report_pages("flushing realpage %s, userpage %s, time %0.04f / %0.04f",real,user,elapsed,average)
                end
            else
                report_pages("flushing realpage %s, time %0.04f / %0.04f",real,elapsed,average)
            end
        else
            report_pages("flushing page, time %0.04f / %0.04f",elapsed,average)
        end
    else
        if real > 0 then
            if user > 0 then
                if sub > 0 then
                    report_pages("flushing realpage %s, userpage %s, subpage %s",real,user,sub)
                else
                    report_pages("flushing realpage %s, userpage %s",real,user)
                end
            else
                report_pages("flushing realpage %s",real)
            end
        else
            report_pages("flushing page")
        end
    end
    logs.flush()
end

logs.report_job_stat = statistics and statistics.showjobstat

local report_files = logs.reporter("files")

local nesting   = 0
local verbose   = false
local hasscheme = url.hasscheme

-- we don't have show_open and show_close callbacks yet

function logs.show_open(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         nesting = nesting + 1
 --         report_files("level %s, opening %s",nesting,name)
 --     else
 --         write(format("(%s",name)) -- tex adds a space
 --     end
 -- end
end

function logs.show_close(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         report_files("level %s, closing %s",nesting,name)
 --         nesting = nesting - 1
 --     else
 --         write(")") -- tex adds a space
 --     end
 -- end
end

function logs.show_load(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         report_files("level %s, loading %s",nesting+1,name)
 --     else
 --         write(format("(%s)",name))
 --     end
 -- end
end

-- there may be scripts out there using this:

local simple = logs.reporter("comment")

logs.simple     = simple
logs.simpleline = simple

-- obsolete

function logs.setprogram  () end -- obsolete
function logs.extendbanner() end -- obsolete
function logs.reportlines () end -- obsolete
function logs.reportbanner() end -- obsolete
function logs.reportline  () end -- obsolete
function logs.simplelines () end -- obsolete
function logs.help        () end -- obsolete

-- applications

local function reportlines(t,str)
    if str then
        for line in gmatch(str,"(.-)[\n\r]") do
            t.report(line)
        end
    end
end

local function reportbanner(t)
    local banner = t.banner
    if banner then
        t.report(banner)
        t.report()
    end
end

local function reportversion(t)
    local banner = t.banner
    if banner then
        t.report(banner)
    end
end

local function reporthelp(t,...)
    local helpinfo = t.helpinfo
    if type(helpinfo) == "string" then
        reportlines(t,helpinfo)
    elseif type(helpinfo) == "table" then
        local tags = { ... }
        for i=1,#tags do
            reportlines(t,t.helpinfo[tags[i]])
            if i < #tags then
                t.report()
            end
        end
    end
end

local function reportinfo(t)
    t.report()
    reportlines(t,moreinfo)
end

function logs.application(t)
    t.name     = t.name   or "unknown"
    t.banner   = t.banner
    t.report   = logs.reporter(t.name)
    t.help     = function(...) reportbanner(t) ; reporthelp(t,...) ; reportinfo(t) end
    t.identify = function() reportbanner(t) end
    t.version  = function() reportversion(t) end
    return t
end

-- somewhat special

-- logging to a file


function logs.system(whereto,process,jobname,category,...)
    local message = format("%s %s => %s => %s => %s\r",os.date("%d/%m/%y %H:%m:%S"),process,jobname,category,format(...))
    for i=1,10 do
        local f = io.open(whereto,"a") -- we can consider keepint the file open
        if f then
            f:write(message)
            f:close()
            break
        else
            sleep(0.1)
        end
    end
end

local report_system = logs.reporter("system","logs")

function logs.obsolete(old,new)
    local o = loadstring("return " .. new)()
    if type(o) == "function" then
        return function(...)
            report_system("function %s is obsolete, use %s",old,new)
            loadstring(old .. "=" .. new  .. " return ".. old)()(...)
        end
    elseif type(o) == "table" then
        local t, m = { }, { }
        m.__index = function(t,k)
            report_system("table %s is obsolete, use %s",old,new)
            m.__index, m.__newindex = o, o
            return o[k]
        end
        m.__newindex = function(t,k,v)
            report_system("table %s is obsolete, use %s",old,new)
            m.__index, m.__newindex = o, o
            o[k] = v
        end
        if libraries then
            libraries.obsolete[old] = t -- true
        end
        setmetatable(t,m)
        return t
    end
end

if utilities then
    utilities.report = report_system
end

if tex and tex.error then
    function logs.texerrormessage(...) -- for the moment we put this function here
        tex.error(format(...), { })
    end
else
    function logs.texerrormessage(...)
        print(format(...))
    end
end

-- do we still need io.flush then?

io.stdout:setvbuf('no')
io.stderr:setvbuf('no')


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['trac-pro'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local getmetatable, setmetatable, rawset, type = getmetatable, setmetatable, rawset, type

-- The protection implemented here is probably not that tight but good enough to catch
-- problems due to naive usage.
--
-- There's a more extensive version (trac-xxx.lua) that supports nesting.
--
-- This will change when we have _ENV in lua 5.2+

local trace_namespaces = false  trackers.register("system.namespaces", function(v) trace_namespaces = v end)

local report_system = logs.reporter("system","protection")

namespaces       = namespaces or { }
local namespaces = namespaces

local registered = { }

local function report_index(k,name)
    if trace_namespaces then
        report_system("reference to '%s' in protected namespace '%s', %s",k,name,debug.traceback())
    else
        report_system("reference to '%s' in protected namespace '%s'",k,name)
    end
end

local function report_newindex(k,name)
    if trace_namespaces then
        report_system("assignment to '%s' in protected namespace '%s', %s",k,name,debug.traceback())
    else
        report_system("assignment to '%s' in protected namespace '%s'",k,name)
    end
end

local function register(name)
    local data = name == "global" and _G or _G[name]
    if not data then
        return -- error
    end
    registered[name] = data
    local m = getmetatable(data)
    if not m then
        m = { }
        setmetatable(data,m)
    end
    local index, newindex = { }, { }
    m.__saved__index = m.__index
    m.__no__index = function(t,k)
        if not index[k] then
            index[k] = true
            report_index(k,name)
        end
        return nil
    end
    m.__saved__newindex = m.__newindex
    m.__no__newindex = function(t,k,v)
        if not newindex[k] then
            newindex[k] = true
            report_newindex(k,name)
        end
        rawset(t,k,v)
    end
    m.__protection__depth = 0
end

local function private(name) -- maybe save name
    local data = registered[name]
    if not data then
        data = _G[name]
        if not data then
            data = { }
            _G[name] = data
        end
        register(name)
    end
    return data
end

local function protect(name)
    local data = registered[name]
    if not data then
        return
    end
    local m = getmetatable(data)
    local pd = m.__protection__depth
    if pd > 0 then
        m.__protection__depth = pd + 1
    else
        m.__save_d_index, m.__saved__newindex = m.__index, m.__newindex
        m.__index, m.__newindex = m.__no__index, m.__no__newindex
        m.__protection__depth = 1
    end
end

local function unprotect(name)
    local data = registered[name]
    if not data then
        return
    end
    local m = getmetatable(data)
    local pd = m.__protection__depth
    if pd > 1 then
        m.__protection__depth = pd - 1
    else
        m.__index, m.__newindex = m.__saved__index, m.__saved__newindex
        m.__protection__depth = 0
    end
end

local function protectall()
    for name, _ in next, registered do
        if name ~= "global" then
            protect(name)
        end
    end
end

local function unprotectall()
    for name, _ in next, registered do
        if name ~= "global" then
            unprotect(name)
        end
    end
end

namespaces.register     = register        -- register when defined
namespaces.private      = private         -- allocate and register if needed
namespaces.protect      = protect
namespaces.unprotect    = unprotect
namespaces.protectall   = protectall
namespaces.unprotectall = unprotectall

namespaces.private("namespaces") registered = { } register("global") -- unreachable

directives.register("system.protect", function(v)
    if v then
        protectall()
    else
        unprotectall()
    end
end)

directives.register("system.checkglobals", function(v)
    if v then
        report_system("enabling global namespace guard")
        protect("global")
    else
        report_system("disabling global namespace guard")
        unprotect("global")
    end
end)

-- dummy section (will go to luat-dum.lua)







end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['luat-env'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A former version provided functionality for non embeded core
-- scripts i.e. runtime library loading. Given the amount of
-- Lua code we use now, this no longer makes sense. Much of this
-- evolved before bytecode arrays were available and so a lot of
-- code has disappeared already.

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_lua = logs.reporter("resolvers","lua")

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local format, sub, match, gsub, find = string.format, string.sub, string.match, string.gsub, string.find
local unquoted, quoted = string.unquoted, string.quoted
local concat = table.concat

-- precautions

os.setlocale(nil,nil) -- useless feature and even dangerous in luatex

function os.setlocale()
    -- no way you can mess with it
end

-- dirty tricks

if arg and (arg[0] == 'luatex' or arg[0] == 'luatex.exe') and arg[1] == "--luaonly" then
    arg[-1] = arg[0]
    arg[ 0] = arg[2]
    for k=3,#arg do
        arg[k-2] = arg[k]
    end
    arg[#arg] = nil -- last
    arg[#arg] = nil -- pre-last
end

-- environment

environment             = environment or { }
local environment       = environment

environment.arguments   = allocate()
environment.files       = allocate()
environment.sortedflags = nil

local mt = {
    __index = function(_,k)
        if k == "version" then
            local version = tex.toks and tex.toks.contextversiontoks
            if version and version ~= "" then
                rawset(environment,"version",version)
                return version
            else
                return "unknown"
            end
        elseif k == "jobname" or k == "formatname" then
            local name = tex and tex[k]
            if name or name== "" then
                rawset(environment,k,name)
                return name
            else
                return "unknown"
            end
        elseif k == "outputfilename" then
            local name = environment.jobname
            rawset(environment,k,name)
            return name
        end
    end
}

setmetatable(environment,mt)

function environment.initializearguments(arg)
    local arguments, files = { }, { }
    environment.arguments, environment.files, environment.sortedflags = arguments, files, nil
    for index=1,#arg do
        local argument = arg[index]
        if index > 0 then
            local flag, value = match(argument,"^%-+(.-)=(.-)$")
            if flag then
                arguments[flag] = unquoted(value or "")
            else
                flag = match(argument,"^%-+(.+)")
                if flag then
                    arguments[flag] = true
                else
                    files[#files+1] = argument
                end
            end
        end
    end
    environment.ownname = environment.ownname or arg[0] or 'unknown.lua'
end

function environment.setargument(name,value)
    environment.arguments[name] = value
end

-- todo: defaults, better checks e.g on type (boolean versus string)
--
-- tricky: too many hits when we support partials unless we add
-- a registration of arguments so from now on we have 'partial'

function environment.argument(name,partial)
    local arguments, sortedflags = environment.arguments, environment.sortedflags
    if arguments[name] then
        return arguments[name]
    elseif partial then
        if not sortedflags then
            sortedflags = allocate(table.sortedkeys(arguments))
            for k=1,#sortedflags do
                sortedflags[k] = "^" .. sortedflags[k]
            end
            environment.sortedflags = sortedflags
        end
        -- example of potential clash: ^mode ^modefile
        for k=1,#sortedflags do
            local v = sortedflags[k]
            if find(name,v) then
                return arguments[sub(v,2,#v)]
            end
        end
    end
    return nil
end

function environment.splitarguments(separator) -- rather special, cut-off before separator
    local done, before, after = false, { }, { }
    local originalarguments = environment.originalarguments
    for k=1,#originalarguments do
        local v = originalarguments[k]
        if not done and v == separator then
            done = true
        elseif done then
            after[#after+1] = v
        else
            before[#before+1] = v
        end
    end
    return before, after
end

function environment.reconstructcommandline(arg,noquote)
    arg = arg or environment.originalarguments
    if noquote and #arg == 1 then
        -- we could just do: return unquoted(resolvers.resolve(arg[i]))
        local a = arg[1]
        a = resolvers.resolve(a)
        a = unquoted(a)
        return a
    elseif #arg > 0 then
        local result = { }
        for i=1,#arg do
            -- we could just do: result[#result+1] = format("%q",unquoted(resolvers.resolve(arg[i])))
            local a = arg[i]
            a = resolvers.resolve(a)
            a = unquoted(a)
            a = gsub(a,'"','\\"') -- tricky
            if find(a," ") then
                result[#result+1] = quoted(a)
            else
                result[#result+1] = a
            end
        end
        return concat(result," ")
    else
        return ""
    end
end


if arg then

    -- new, reconstruct quoted snippets (maybe better just remove the " then and add them later)
    local newarg, instring = { }, false

    for index=1,#arg do
        local argument = arg[index]
        if find(argument,"^\"") then
            newarg[#newarg+1] = gsub(argument,"^\"","")
            if not find(argument,"\"$") then
                instring = true
            end
        elseif find(argument,"\"$") then
            newarg[#newarg] = newarg[#newarg] .. " " .. gsub(argument,"\"$","")
            instring = false
        elseif instring then
            newarg[#newarg] = newarg[#newarg] .. " " .. argument
        else
            newarg[#newarg+1] = argument
        end
    end
    for i=1,-5,-1 do
        newarg[i] = arg[i]
    end

    environment.initializearguments(newarg)

    environment.originalarguments = mark(newarg)
    environment.rawarguments      = mark(arg)

    arg = { } -- prevent duplicate handling

end

-- weird place ... depends on a not yet loaded module

function environment.texfile(filename)
    return resolvers.findfile(filename,'tex')
end

function environment.luafile(filename)
    local resolved = resolvers.findfile(filename,'tex') or ""
    if resolved ~= "" then
        return resolved
    end
    resolved = resolvers.findfile(filename,'texmfscripts') or ""
    if resolved ~= "" then
        return resolved
    end
    return resolvers.findfile(filename,'luatexlibs') or ""
end

environment.loadedluacode = loadfile -- can be overloaded

function environment.luafilechunk(filename,silent) -- used for loading lua bytecode in the format
    filename = file.replacesuffix(filename, "lua")
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        local data = environment.loadedluacode(fullname)
        if trace_locating then
            report_lua("loading file %s%s", fullname, not data and " failed" or "")
        elseif not silent then
            texio.write("<",data and "+ " or "- ",fullname,">")
        end
        return data
    else
        if trace_locating then
            report_lua("unknown file %s", filename)
        end
        return nil
    end
end

-- the next ones can use the previous ones / combine

function environment.loadluafile(filename, version)
    local lucname, luaname, chunk
    local basename = file.removesuffix(filename)
    if basename == filename then
        lucname, luaname = basename .. ".luc",  basename .. ".lua"
    else
        lucname, luaname = nil, basename -- forced suffix
    end
    -- when not overloaded by explicit suffix we look for a luc file first
    local fullname = (lucname and environment.luafile(lucname)) or ""
    if fullname ~= "" then
        if trace_locating then
            report_lua("loading %s", fullname)
        end
        chunk = loadfile(fullname) -- this way we don't need a file exists check
    end
    if chunk then
        assert(chunk)()
        if version then
            -- we check of the version number of this chunk matches
            local v = version -- can be nil
            if modules and modules[filename] then
                v = modules[filename].version -- new method
            elseif versions and versions[filename] then
                v = versions[filename]        -- old method
            end
            if v == version then
                return true
            else
                if trace_locating then
                    report_lua("version mismatch for %s: lua=%s, luc=%s", filename, v, version)
                end
                environment.loadluafile(filename)
            end
        else
            return true
        end
    end
    fullname = (luaname and environment.luafile(luaname)) or ""
    if fullname ~= "" then
        if trace_locating then
            report_lua("loading %s", fullname)
        end
        chunk = loadfile(fullname) -- this way we don't need a file exists check
        if not chunk then
            if trace_locating then
                report_lua("unknown file %s", filename)
            end
        else
            assert(chunk)()
            return true
        end
    end
    return false
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-tab'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module needs a cleanup: check latest lpeg, passing args, (sub)grammar, etc etc
-- stripping spaces from e.g. cont-en.xml saves .2 sec runtime so it's not worth the
-- trouble

-- todo: when serializing optionally remap named entities to hex (if known in char-ent.lua)
-- maybe when letter -> utf, else name .. then we need an option to the serializer .. a bit
-- of work so we delay this till we cleanup

local trace_entities = false  trackers.register("xml.entities", function(v) trace_entities = v end)

local report_xml = logs and logs.reporter("xml","core") or function(...) print(format(...)) end

--[[ldx--
<p>The parser used here is inspired by the variant discussed in the lua book, but
handles comment and processing instructions, has a different structure, provides
parent access; a first version used different trickery but was less optimized to we
went this route. First we had a find based parser, now we have an <l n='lpeg'/> based one.
The find based parser can be found in l-xml-edu.lua along with other older code.</p>

<p>Beware, the interface may change. For instance at, ns, tg, dt may get more
verbose names. Once the code is stable we will also remove some tracing and
optimize the code.</p>

<p>I might even decide to reimplement the parser using the latest <l n='lpeg'/> trickery
as the current variant was written when <l n='lpeg'/> showed up and it's easier now to
build tables in one go.</p>
--ldx]]--

xml = xml or { }
local xml = xml


local utf = unicode.utf8
local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, setmetatable, getmetatable, tonumber = type, next, setmetatable, getmetatable, tonumber
local format, lower, find, match, gsub = string.format, string.lower, string.find, string.match, string.gsub
local utfchar, utffind, utfgsub = utf.char, utf.find, utf.gsub
local lpegmatch = lpeg.match
local P, S, R, C, V, C, Cs = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.C, lpeg.Cs

--[[ldx--
<p>First a hack to enable namespace resolving. A namespace is characterized by
a <l n='url'/>. The following function associates a namespace prefix with a
pattern. We use <l n='lpeg'/>, which in this case is more than twice as fast as a
find based solution where we loop over an array of patterns. Less code and
much cleaner.</p>
--ldx]]--

xml.xmlns = xml.xmlns or { }

local check = P(false)
local parse = check

--[[ldx--
<p>The next function associates a namespace prefix with an <l n='url'/>. This
normally happens independent of parsing.</p>

<typing>
xml.registerns("mml","mathml")
</typing>
--ldx]]--

function xml.registerns(namespace, pattern) -- pattern can be an lpeg
    check = check + C(P(lower(pattern))) / namespace
    parse = P { P(check) + 1 * V(1) }
end

--[[ldx--
<p>The next function also registers a namespace, but this time we map a
given namespace prefix onto a registered one, using the given
<l n='url'/>. This used for attributes like <t>xmlns:m</t>.</p>

<typing>
xml.checkns("m","http://www.w3.org/mathml")
</typing>
--ldx]]--

function xml.checkns(namespace,url)
    local ns = lpegmatch(parse,lower(url))
    if ns and namespace ~= ns then
        xml.xmlns[namespace] = ns
    end
end

--[[ldx--
<p>Next we provide a way to turn an <l n='url'/> into a registered
namespace. This used for the <t>xmlns</t> attribute.</p>

<typing>
resolvedns = xml.resolvens("http://www.w3.org/mathml")
</typing>

This returns <t>mml</t>.
--ldx]]--

function xml.resolvens(url)
     return lpegmatch(parse,lower(url)) or ""
end

--[[ldx--
<p>A namespace in an element can be remapped onto the registered
one efficiently by using the <t>xml.xmlns</t> table.</p>
--ldx]]--

--[[ldx--
<p>This version uses <l n='lpeg'/>. We follow the same approach as before, stack and top and
such. This version is about twice as fast which is mostly due to the fact that
we don't have to prepare the stream for cdata, doctype etc etc. This variant is
is dedicated to Luigi Scarso, who challenged me with 40 megabyte <l n='xml'/> files that
took 12.5 seconds to load (1.5 for file io and the rest for tree building). With
the <l n='lpeg'/> implementation we got that down to less 7.3 seconds. Loading the 14
<l n='context'/> interface definition files (2.6 meg) went down from 1.05 seconds to 0.55.</p>

<p>Next comes the parser. The rather messy doctype definition comes in many
disguises so it is no surprice that later on have to dedicate quite some
<l n='lpeg'/> code to it.</p>

<typing>
<!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
<!DOCTYPE Something PUBLIC "... ..." "..." >
<!DOCTYPE Something SYSTEM "... ..." [ ... ] >
<!DOCTYPE Something SYSTEM "... ..." >
<!DOCTYPE Something [ ... ] >
<!DOCTYPE Something >
</typing>

<p>The code may look a bit complex but this is mostly due to the fact that we
resolve namespaces and attach metatables. There is only one public function:</p>

<typing>
local x = xml.convert(somestring)
</typing>

<p>An optional second boolean argument tells this function not to create a root
element.</p>

<p>Valid entities are:</p>

<typing>
<!ENTITY xxxx SYSTEM "yyyy" NDATA zzzz>
<!ENTITY xxxx PUBLIC "yyyy" >
<!ENTITY xxxx "yyyy" >
</typing>
--ldx]]--

-- not just one big nested table capture (lpeg overflow)

local nsremap, resolvens = xml.xmlns, xml.resolvens

local stack              = { }
local top                = { }
local dt                 = { }
local at                 = { }
local xmlns              = { }
local errorstr           = nil
local entities           = { }
local strip              = false
local cleanup            = false
local utfize             = false
local resolve_predefined = false
local unify_predefined   = false

local dcache             = { }
local hcache             = { }
local acache             = { }

local mt = { }

local function initialize_mt(root)
    mt = { __index = root } -- will be redefined later
end

function xml.setproperty(root,k,v)
    getmetatable(root).__index[k] = v
end

function xml.checkerror(top,toclose)
    return "" -- can be set
end

local function add_attribute(namespace,tag,value)
    if cleanup and #value > 0 then
        value = cleanup(value) -- new
    end
    if tag == "xmlns" then
        xmlns[#xmlns+1] = resolvens(value)
        at[tag] = value
    elseif namespace == "" then
        at[tag] = value
    elseif namespace == "xmlns" then
        xml.checkns(tag,value)
        at["xmlns:" .. tag] = value
    else
        -- for the moment this way:
        at[namespace .. ":" .. tag] = value
    end
end

local function add_empty(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local resolved = (namespace == "" and xmlns[#xmlns]) or nsremap[namespace] or namespace
    top = stack[#stack]
    dt = top.dt
    local t = { ns=namespace or "", rn=resolved, tg=tag, at=at, dt={}, __p__ = top }
    dt[#dt+1] = t
    setmetatable(t, mt)
    if at.xmlns then
        remove(xmlns)
    end
    at = { }
end

local function add_begin(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local resolved = (namespace == "" and xmlns[#xmlns]) or nsremap[namespace] or namespace
    top = { ns=namespace or "", rn=resolved, tg=tag, at=at, dt={}, __p__ = stack[#stack] }
    setmetatable(top, mt)
    dt = top.dt
    stack[#stack+1] = top
    at = { }
end

local function add_end(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local toclose = remove(stack)
    top = stack[#stack]
    if #stack < 1 then
        errorstr = format("nothing to close with %s %s", tag, xml.checkerror(top,toclose) or "")
    elseif toclose.tg ~= tag then -- no namespace check
        errorstr = format("unable to close %s with %s %s", toclose.tg, tag, xml.checkerror(top,toclose) or "")
    end
    dt = top.dt
    dt[#dt+1] = toclose
 -- dt[0] = top -- nasty circular reference when serializing table
    if toclose.at.xmlns then
        remove(xmlns)
    end
end

local function add_text(text)
    if cleanup and #text > 0 then
        dt[#dt+1] = cleanup(text)
    else
        dt[#dt+1] = text
    end
end

local function add_special(what, spacing, text)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    if strip and (what == "@cm@" or what == "@dt@") then
        -- forget it
    else
        dt[#dt+1] = { special=true, ns="", tg=what, dt={ text } }
    end
end

local function set_message(txt)
    errorstr = "garbage at the end of the file: " .. gsub(txt,"([ \n\r\t]*)","")
end

local reported_attribute_errors = { }

local function attribute_value_error(str)
    if not reported_attribute_errors[str] then
        report_xml("invalid attribute value: %q",str)
        reported_attribute_errors[str] = true
        at._error_ = str
    end
    return str
end

local function attribute_specification_error(str)
    if not reported_attribute_errors[str] then
        report_xml("invalid attribute specification: %q",str)
        reported_attribute_errors[str] = true
        at._error_ = str
    end
    return str
end

xml.placeholders = {
    unknown_dec_entity = function(str) return (str == "" and "&error;") or format("&%s;",str) end,
    unknown_hex_entity = function(str) return format("&#x%s;",str) end,
    unknown_any_entity = function(str) return format("&#x%s;",str) end,
}

local placeholders = xml.placeholders

local function fromhex(s)
    local n = tonumber(s,16)
    if n then
        return utfchar(n)
    else
        return format("h:%s",s), true
    end
end

local function fromdec(s)
    local n = tonumber(s)
    if n then
        return utfchar(n)
    else
        return format("d:%s",s), true
    end
end

-- one level expansion (simple case), no checking done

local rest = (1-P(";"))^0
local many = P(1)^0

local parsedentity =
    P("&") * (P("#x")*(rest/fromhex) + P("#")*(rest/fromdec)) * P(";") * P(-1) +
             (P("#x")*(many/fromhex) + P("#")*(many/fromdec))

-- parsing in the xml file

local predefined_unified = {
    [38] = "&amp;",
    [42] = "&quot;",
    [47] = "&apos;",
    [74] = "&lt;",
    [76] = "&gt;",
}

local predefined_simplified = {
    [38] = "&", amp  = "&",
    [42] = '"', quot = '"',
    [47] = "'", apos = "'",
    [74] = "<", lt   = "<",
    [76] = ">", gt   = ">",
}

local nofprivates = 0xF0000 -- shared but seldom used

local privates_u = { -- unescaped
    [ [[&]] ] = "&amp;",
    [ [["]] ] = "&quot;",
    [ [[']] ] = "&apos;",
    [ [[<]] ] = "&lt;",
    [ [[>]] ] = "&gt;",
}

local privates_p = {
}

local privates_n = {
    -- keeps track of defined ones
}

local function escaped(s)
    if s == "" then
        return ""
    else -- if utffind(s,privates_u) then
        return (utfgsub(s,".",privates_u))
 -- else
 --     return s
    end
end

local function unescaped(s)
    local p = privates_n[s]
    if not p then
        nofprivates = nofprivates + 1
        p = utfchar(nofprivates)
        privates_n[s] = p
        s = "&" .. s .. ";" -- todo: use char-ent to map to hex
        privates_u[p] = s
        privates_p[p] = s
    end
    return p
end

local function unprivatized(s,resolve)
    if s == "" then
        return ""
    else
        return (utfgsub(s,".",privates_p))
    end
end

xml.privatetoken = unescaped
xml.unprivatized = unprivatized
xml.privatecodes = privates_n

local function handle_hex_entity(str)
    local h = hcache[str]
    if not h then
        local n = tonumber(str,16)
        h = unify_predefined and predefined_unified[n]
        if h then
            if trace_entities then
                report_xml("utfize, converting hex entity &#x%s; into %s",str,h)
            end
        elseif utfize then
            h = (n and utfchar(n)) or xml.unknown_hex_entity(str) or ""
            if not n then
                report_xml("utfize, ignoring hex entity &#x%s;",str)
            elseif trace_entities then
                report_xml("utfize, converting hex entity &#x%s; into %s",str,h)
            end
        else
            if trace_entities then
                report_xml("found entity &#x%s;",str)
            end
            h = "&#x" .. str .. ";"
        end
        hcache[str] = h
    end
    return h
end

local function handle_dec_entity(str)
    local d = dcache[str]
    if not d then
        local n = tonumber(str)
        d = unify_predefined and predefined_unified[n]
        if d then
            if trace_entities then
                report_xml("utfize, converting dec entity &#%s; into %s",str,d)
            end
        elseif utfize then
            d = (n and utfchar(n)) or placeholders.unknown_dec_entity(str) or ""
            if not n then
                report_xml("utfize, ignoring dec entity &#%s;",str)
            elseif trace_entities then
                report_xml("utfize, converting dec entity &#%s; into %s",str,d)
            end
        else
            if trace_entities then
                report_xml("found entity &#%s;",str)
            end
            d = "&#" .. str .. ";"
        end
        dcache[str] = d
    end
    return d
end

xml.parsedentitylpeg = parsedentity

local function handle_any_entity(str)
    if resolve then
        local a = acache[str] -- per instance ! todo
        if not a then
            a = resolve_predefined and predefined_simplified[str]
            if a then
                if trace_entities then
                    report_xml("resolved entity &%s; -> %s (predefined)",str,a)
                end
            else
                if type(resolve) == "function" then
                    a = resolve(str) or entities[str]
                else
                    a = entities[str]
                end
                if a then
                    if type(a) == "function" then
                        if trace_entities then
                            report_xml("expanding entity &%s; (function)",str)
                        end
                        a = a(str) or ""
                    end
                    a = lpegmatch(parsedentity,a) or a -- for nested
                    if trace_entities then
                        report_xml("resolved entity &%s; -> %s (internal)",str,a)
                    end
                else
                    local unknown_any_entity = placeholders.unknown_any_entity
                    if unknown_any_entity then
                        a = unknown_any_entity(str) or ""
                    end
                    if a then
                        if trace_entities then
                            report_xml("resolved entity &%s; -> %s (external)",str,a)
                        end
                    else
                        if trace_entities then
                            report_xml("keeping entity &%s;",str)
                        end
                        if str == "" then
                            a = "&error;"
                        else
                            a = "&" .. str .. ";"
                        end
                    end
                end
            end
            acache[str] = a
        elseif trace_entities then
            if not acache[str] then
                report_xml("converting entity &%s; into %s",str,a)
                acache[str] = a
            end
        end
        return a
    else
        local a = acache[str]
        if not a then
            a = resolve_predefined and predefined_simplified[str]
            if a then
                -- one of the predefined
                acache[str] = a
                if trace_entities then
                    report_xml("entity &%s; becomes %s",str,tostring(a))
                end
            elseif str == "" then
                if trace_entities then
                    report_xml("invalid entity &%s;",str)
                end
                a = "&error;"
                acache[str] = a
            else
                if trace_entities then
                    report_xml("entity &%s; is made private",str)
                end
             -- a = "&" .. str .. ";"
                a = unescaped(str)
                acache[str] = a
            end
        end
        return a
    end
end

local function handle_end_entity(chr)
    report_xml("error in entity, %q found instead of ';'",chr)
end

local space            = S(' \r\n\t')
local open             = P('<')
local close            = P('>')
local squote           = S("'")
local dquote           = S('"')
local equal            = P('=')
local slash            = P('/')
local colon            = P(':')
local semicolon        = P(';')
local ampersand        = P('&')
local valid            = R('az', 'AZ', '09') + S('_-.')
local name_yes         = C(valid^1) * colon * C(valid^1)
local name_nop         = C(P(true)) * C(valid^1)
local name             = name_yes + name_nop
local utfbom           = lpeg.patterns.utfbom -- no capture
local spacing          = C(space^0)

----- entitycontent    = (1-open-semicolon)^0
local anyentitycontent = (1-open-semicolon-space-close)^0
local hexentitycontent = R("AF","af","09")^0
local decentitycontent = R("09")^0
local parsedentity     = P("#")/"" * (
                                P("x")/"" * (hexentitycontent/handle_hex_entity) +
                                            (decentitycontent/handle_dec_entity)
                            ) +             (anyentitycontent/handle_any_entity)
local entity           = ampersand/"" * parsedentity * ( (semicolon/"") + #(P(1)/handle_end_entity))

local text_unparsed    = C((1-open)^1)
local text_parsed      = Cs(((1-open-ampersand)^1 + entity)^1)

local somespace        = space^1
local optionalspace    = space^0

----- value            = (squote * C((1 - squote)^0) * squote) + (dquote * C((1 - dquote)^0) * dquote) -- ampersand and < also invalid in value
local value            = (squote * Cs((entity + (1 - squote))^0) * squote) + (dquote * Cs((entity + (1 - dquote))^0) * dquote) -- ampersand and < also invalid in value

local endofattributes  = slash * close + close -- recovery of flacky html
local whatever         = space * name * optionalspace * equal
----- wrongvalue       = C(P(1-whatever-close)^1 + P(1-close)^1) / attribute_value_error
----- wrongvalue       = C(P(1-whatever-endofattributes)^1 + P(1-endofattributes)^1) / attribute_value_error
----- wrongvalue       = C(P(1-space-endofattributes)^1) / attribute_value_error
local wrongvalue       = Cs(P(entity + (1-space-endofattributes))^1) / attribute_value_error

local attributevalue   = value + wrongvalue

local attribute        = (somespace * name * optionalspace * equal * optionalspace * attributevalue) / add_attribute
----- attributes       = (attribute)^0

local attributes       = (attribute + somespace^-1 * (((1-endofattributes)^1)/attribute_specification_error))^0

local parsedtext       = text_parsed   / add_text
local unparsedtext     = text_unparsed / add_text
local balanced         = P { "[" * ((1 - S"[]") + V(1))^0 * "]" } -- taken from lpeg manual, () example

local emptyelement     = (spacing * open         * name * attributes * optionalspace * slash * close) / add_empty
local beginelement     = (spacing * open         * name * attributes * optionalspace         * close) / add_begin
local endelement       = (spacing * open * slash * name              * optionalspace         * close) / add_end

local begincomment     = open * P("!--")
local endcomment       = P("--") * close
local begininstruction = open * P("?")
local endinstruction   = P("?") * close
local begincdata       = open * P("![CDATA[")
local endcdata         = P("]]") * close

local someinstruction  = C((1 - endinstruction)^0)
local somecomment      = C((1 - endcomment    )^0)
local somecdata        = C((1 - endcdata      )^0)

local function normalentity(k,v  ) entities[k] = v end
local function systementity(k,v,n) entities[k] = v end
local function publicentity(k,v,n) entities[k] = v end

-- todo: separate dtd parser

local begindoctype     = open * P("!DOCTYPE")
local enddoctype       = close
local beginset         = P("[")
local endset           = P("]")
local doctypename      = C((1-somespace-close)^0)
local elementdoctype   = optionalspace * P("<!ELEMENT") * (1-close)^0 * close

local basiccomment     = begincomment * ((1 - endcomment)^0) * endcomment

local normalentitytype = (doctypename * somespace * value)/normalentity
local publicentitytype = (doctypename * somespace * P("PUBLIC") * somespace * value)/publicentity
local systementitytype = (doctypename * somespace * P("SYSTEM") * somespace * value * somespace * P("NDATA") * somespace * doctypename)/systementity
local entitydoctype    = optionalspace * P("<!ENTITY") * somespace * (systementitytype + publicentitytype + normalentitytype) * optionalspace * close

-- we accept comments in doctypes

local doctypeset       = beginset * optionalspace * P(elementdoctype + entitydoctype + basiccomment + space)^0 * optionalspace * endset
local definitiondoctype= doctypename * somespace * doctypeset
local publicdoctype    = doctypename * somespace * P("PUBLIC") * somespace * value * somespace * value * somespace * doctypeset
local systemdoctype    = doctypename * somespace * P("SYSTEM") * somespace * value * somespace * doctypeset
local simpledoctype    = (1-close)^1 -- * balanced^0
local somedoctype      = C((somespace * (publicdoctype + systemdoctype + definitiondoctype + simpledoctype) * optionalspace)^0)
local somedoctype      = C((somespace * (publicdoctype + systemdoctype + definitiondoctype + simpledoctype) * optionalspace)^0)

local instruction      = (spacing * begininstruction * someinstruction * endinstruction) / function(...) add_special("@pi@",...) end
local comment          = (spacing * begincomment     * somecomment     * endcomment    ) / function(...) add_special("@cm@",...) end
local cdata            = (spacing * begincdata       * somecdata       * endcdata      ) / function(...) add_special("@cd@",...) end
local doctype          = (spacing * begindoctype     * somedoctype     * enddoctype    ) / function(...) add_special("@dt@",...) end

--  nicer but slower:
--
--  local instruction = (Cc("@pi@") * spacing * begininstruction * someinstruction * endinstruction) / add_special
--  local comment     = (Cc("@cm@") * spacing * begincomment     * somecomment     * endcomment    ) / add_special
--  local cdata       = (Cc("@cd@") * spacing * begincdata       * somecdata       * endcdata      ) / add_special
--  local doctype     = (Cc("@dt@") * spacing * begindoctype     * somedoctype     * enddoctype    ) / add_special

local trailer = space^0 * (text_unparsed/set_message)^0

--  comment + emptyelement + text + cdata + instruction + V("parent"), -- 6.5 seconds on 40 MB database file
--  text + comment + emptyelement + cdata + instruction + V("parent"), -- 5.8
--  text + V("parent") + emptyelement + comment + cdata + instruction, -- 5.5

local grammar_parsed_text = P { "preamble",
    preamble = utfbom^0 * instruction^0 * (doctype + comment + instruction)^0 * V("parent") * trailer,
    parent   = beginelement * V("children")^0 * endelement,
    children = parsedtext + V("parent") + emptyelement + comment + cdata + instruction,
}

local grammar_unparsed_text = P { "preamble",
    preamble = utfbom^0 * instruction^0 * (doctype + comment + instruction)^0 * V("parent") * trailer,
    parent   = beginelement * V("children")^0 * endelement,
    children = unparsedtext + V("parent") + emptyelement + comment + cdata + instruction,
}

-- maybe we will add settings to result as well

local function _xmlconvert_(data, settings)
    settings           = settings or { } -- no_root strip_cm_and_dt given_entities parent_root error_handler
    --
    strip              = settings.strip_cm_and_dt
    utfize             = settings.utfize_entities
    resolve            = settings.resolve_entities
    resolve_predefined = settings.resolve_predefined_entities -- in case we have escaped entities
    unify_predefined   = settings.unify_predefined_entities -- &#038; -> &amp;
    cleanup            = settings.text_cleanup
    entities           = settings.entities or { }
    --
    if utfize == nil then
        settings.utfize_entities = true
        utfize = true
    end
    if resolve_predefined == nil then
        settings.resolve_predefined_entities = true
        resolve_predefined = true
    end
    --
    --
    stack, top, at, xmlns, errorstr = { }, { }, { }, { }, nil
    acache, hcache, dcache = { }, { }, { } -- not stored
    reported_attribute_errors = { }
    if settings.parent_root then
        mt = getmetatable(settings.parent_root)
    else
        initialize_mt(top)
    end
    stack[#stack+1] = top
    top.dt = { }
    dt = top.dt
    if not data or data == "" then
        errorstr = "empty xml file"
    elseif utfize or resolve then
        if lpegmatch(grammar_parsed_text,data) then
            errorstr = ""
        else
            errorstr = "invalid xml file - parsed text"
        end
    elseif type(data) == "string" then
        if lpegmatch(grammar_unparsed_text,data) then
            errorstr = ""
        else
            errorstr = "invalid xml file - unparsed text"
        end
    else
        errorstr = "invalid xml file - no text at all"
    end
    local result
    if errorstr and errorstr ~= "" then
        result = { dt = { { ns = "", tg = "error", dt = { errorstr }, at={ }, er = true } } }
        setmetatable(stack, mt)
        local errorhandler = settings.error_handler
        if errorhandler == false then
            -- no error message
        else
            errorhandler = errorhandler or xml.errorhandler
            if errorhandler then
                xml.errorhandler(format("load error: %s",errorstr))
            end
        end
    else
        result = stack[1]
    end
    if not settings.no_root then
        result = { special = true, ns = "", tg = '@rt@', dt = result.dt, at={ }, entities = entities, settings = settings }
        setmetatable(result, mt)
        local rdt = result.dt
        for k=1,#rdt do
            local v = rdt[k]
            if type(v) == "table" and not v.special then -- always table -)
                result.ri = k -- rootindex
                v.__p__ = result  -- new, experiment, else we cannot go back to settings, we need to test this !
                break
            end
        end
    end
    if errorstr and errorstr ~= "" then
        result.error = true
    end
    result.statistics = {
        entities = {
            decimals     = dcache,
            hexadecimals = hcache,
            names        = acache,
        }
    }
    strip, utfize, resolve, resolve_predefined = nil, nil, nil, nil
    unify_predefined, cleanup, entities = nil, nil, nil
    stack, top, at, xmlns, errorstr = nil, nil, nil, nil, nil
    acache, hcache, dcache = nil, nil, nil
    reported_attribute_errors, mt, errorhandler = nil, nil, nil
    return result
end

-- Because we can have a crash (stack issues) with faulty xml, we wrap this one
-- in a protector:

function xmlconvert(data,settings)
    local ok, result = pcall(function() return _xmlconvert_(data,settings) end)
    if ok then
        return result
    else
        return _xmlconvert_("")
    end
end

xml.convert = xmlconvert

function xml.inheritedconvert(data,xmldata) -- xmldata is parent
    local settings = xmldata.settings
    if settings then
        settings.parent_root = xmldata -- to be tested
    end
 -- settings.no_root = true
    local xc = xmlconvert(data,settings) -- hm, we might need to locate settings
 -- xc.settings = nil
 -- xc.entities = nil
 -- xc.special = nil
 -- xc.ri = nil
 -- print(xc.tg)
    return xc
end

--[[ldx--
<p>Packaging data in an xml like table is done with the following
function. Maybe it will go away (when not used).</p>
--ldx]]--

function xml.is_valid(root)
    return root and root.dt and root.dt[1] and type(root.dt[1]) == "table" and not root.dt[1].er
end

function xml.package(tag,attributes,data)
    local ns, tg = match(tag,"^(.-):?([^:]+)$")
    local t = { ns = ns, tg = tg, dt = data or "", at = attributes or {} }
    setmetatable(t, mt)
    return t
end

function xml.is_valid(root)
    return root and not root.error
end

xml.errorhandler = report_xml

--[[ldx--
<p>We cannot load an <l n='lpeg'/> from a filehandle so we need to load
the whole file first. The function accepts a string representing
a filename or a file handle.</p>
--ldx]]--

function xml.load(filename,settings)
    local data = ""
    if type(filename) == "string" then
     -- local data = io.loaddata(filename) - -todo: check type in io.loaddata
        local f = io.open(filename,'r')
        if f then
            data = f:read("*all")
            f:close()
        end
    elseif filename then -- filehandle
        data = filename:read("*all")
    end
    return xmlconvert(data,settings)
end

--[[ldx--
<p>When we inject new elements, we need to convert strings to
valid trees, which is what the next function does.</p>
--ldx]]--

local no_root = { no_root = true }

function xml.toxml(data)
    if type(data) == "string" then
        local root = { xmlconvert(data,no_root) }
        return (#root > 1 and root) or root[1]
    else
        return data
    end
end

--[[ldx--
<p>For copying a tree we use a dedicated function instead of the
generic table copier. Since we know what we're dealing with we
can speed up things a bit. The second argument is not to be used!</p>
--ldx]]--

local function copy(old,tables)
    if old then
        tables = tables or { }
        local new = { }
        if not tables[old] then
            tables[old] = new
        end
        for k,v in next, old do
            new[k] = (type(v) == "table" and (tables[v] or copy(v, tables))) or v
        end
        local mt = getmetatable(old)
        if mt then
            setmetatable(new,mt)
        end
        return new
    else
        return { }
    end
end

xml.copy = copy

--[[ldx--
<p>In <l n='context'/> serializing the tree or parts of the tree is a major
actitivity which is why the following function is pretty optimized resulting
in a few more lines of code than needed. The variant that uses the formatting
function for all components is about 15% slower than the concatinating
alternative.</p>
--ldx]]--

-- todo: add <?xml version='1.0' standalone='yes'?> when not present

function xml.checkbom(root) -- can be made faster
    if root.ri then
        local dt = root.dt
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "table" and v.special and v.tg == "@pi@" and find(v.dt[1],"xml.*version=") then
                return
            end
        end
        insert(dt, 1, { special=true, ns="", tg="@pi@", dt = { "xml version='1.0' standalone='yes'"} } )
        insert(dt, 2, "\n" )
    end
end

--[[ldx--
<p>At the cost of some 25% runtime overhead you can first convert the tree to a string
and then handle the lot.</p>
--ldx]]--

-- new experimental reorganized serialize

local function verbose_element(e,handlers) -- options
    local handle = handlers.handle
    local serialize = handlers.serialize
    local ens, etg, eat, edt, ern = e.ns, e.tg, e.at, e.dt, e.rn
    local ats = eat and next(eat) and { }
    if ats then
        for k,v in next, eat do
            ats[#ats+1] = format('%s=%q',k,escaped(v))
        end
    end
    if ern and trace_entities and ern ~= ens then
        ens = ern
    end
    if ens ~= "" then
        if edt and #edt > 0 then
            if ats then
                handle("<",ens,":",etg," ",concat(ats," "),">")
            else
                handle("<",ens,":",etg,">")
            end
            for i=1,#edt do
                local e = edt[i]
                if type(e) == "string" then
                    handle(escaped(e))
                else
                    serialize(e,handlers)
                end
            end
            handle("</",ens,":",etg,">")
        else
            if ats then
                handle("<",ens,":",etg," ",concat(ats," "),"/>")
            else
                handle("<",ens,":",etg,"/>")
            end
        end
    else
        if edt and #edt > 0 then
            if ats then
                handle("<",etg," ",concat(ats," "),">")
            else
                handle("<",etg,">")
            end
            for i=1,#edt do
                local e = edt[i]
                if type(e) == "string" then
                    handle(escaped(e)) -- option: hexify escaped entities
                else
                    serialize(e,handlers)
                end
            end
            handle("</",etg,">")
        else
            if ats then
                handle("<",etg," ",concat(ats," "),"/>")
            else
                handle("<",etg,"/>")
            end
        end
    end
end

local function verbose_pi(e,handlers)
    handlers.handle("<?",e.dt[1],"?>")
end

local function verbose_comment(e,handlers)
    handlers.handle("<!--",e.dt[1],"-->")
end

local function verbose_cdata(e,handlers)
    handlers.handle("<![CDATA[", e.dt[1],"]]>")
end

local function verbose_doctype(e,handlers)
    handlers.handle("<!DOCTYPE ",e.dt[1],">")
end

local function verbose_root(e,handlers)
    handlers.serialize(e.dt,handlers)
end

local function verbose_text(e,handlers)
    handlers.handle(escaped(e))
end

local function verbose_document(e,handlers)
    local serialize = handlers.serialize
    local functions = handlers.functions
    for i=1,#e do
        local ei = e[i]
        if type(ei) == "string" then
            functions["@tx@"](ei,handlers)
        else
            serialize(ei,handlers)
        end
    end
end

local function serialize(e,handlers,...)
    local initialize = handlers.initialize
    local finalize   = handlers.finalize
    local functions  = handlers.functions
    if initialize then
        local state = initialize(...)
        if not state == true then
            return state
        end
    end
    local etg = e.tg
    if etg then
        (functions[etg] or functions["@el@"])(e,handlers)
 -- elseif type(e) == "string" then
 --     functions["@tx@"](e,handlers)
    else
        functions["@dc@"](e,handlers) -- dc ?
    end
    if finalize then
        return finalize()
    end
end

local function xserialize(e,handlers)
    local functions = handlers.functions
    local etg = e.tg
    if etg then
        (functions[etg] or functions["@el@"])(e,handlers)
 -- elseif type(e) == "string" then
 --     functions["@tx@"](e,handlers)
    else
        functions["@dc@"](e,handlers)
    end
end

local handlers = { }

local function newhandlers(settings)
    local t = table.copy(handlers.verbose or { }) -- merge
    if settings then
        for k,v in next, settings do
            if type(v) == "table" then
                local tk = t[k] if not tk then tk = { } t[k] = tk end
                for kk,vv in next, v do
                    tk[kk] = vv
                end
            else
                t[k] = v
            end
        end
        if settings.name then
            handlers[settings.name] = t
        end
    end
    utilities.storage.mark(t)
    return t
end

local nofunction = function() end

function xml.sethandlersfunction(handler,name,fnc)
    handler.functions[name] = fnc or nofunction
end

function xml.gethandlersfunction(handler,name)
    return handler.functions[name]
end

function xml.gethandlers(name)
    return handlers[name]
end

newhandlers {
    name       = "verbose",
    initialize = false, -- faster than nil and mt lookup
    finalize   = false, -- faster than nil and mt lookup
    serialize  = xserialize,
    handle     = print,
    functions  = {
        ["@dc@"]   = verbose_document,
        ["@dt@"]   = verbose_doctype,
        ["@rt@"]   = verbose_root,
        ["@el@"]   = verbose_element,
        ["@pi@"]   = verbose_pi,
        ["@cm@"]   = verbose_comment,
        ["@cd@"]   = verbose_cdata,
        ["@tx@"]   = verbose_text,
    }
}

--[[ldx--
<p>How you deal with saving data depends on your preferences. For a 40 MB database
file the timing on a 2.3 Core Duo are as follows (time in seconds):</p>

<lines>
1.3 : load data from file to string
6.1 : convert string into tree
5.3 : saving in file using xmlsave
6.8 : converting to string using xml.tostring
3.6 : saving converted string in file
</lines>

<p>Beware, these were timing with the old routine but measurements will not be that
much different I guess.</p>
--ldx]]--

-- maybe this will move to lxml-xml

local result

local xmlfilehandler = newhandlers {
    name       = "file",
    initialize = function(name)
        result = io.open(name,"wb")
        return result
    end,
    finalize   = function()
        result:close()
        return true
    end,
    handle     = function(...)
        result:write(...)
    end,
}

-- no checking on writeability here but not faster either
--
-- local xmlfilehandler = newhandlers {
--     initialize = function(name)
--         io.output(name,"wb")
--         return true
--     end,
--     finalize   = function()
--         io.close()
--         return true
--     end,
--     handle     = io.write,
-- }

function xml.save(root,name)
    serialize(root,xmlfilehandler,name)
end

local result

local xmlstringhandler = newhandlers {
    name       = "string",
    initialize = function()
        result = { }
        return result
    end,
    finalize   = function()
        return concat(result)
    end,
    handle     = function(...)
        result[#result+1] = concat { ... }
    end,
}

local function xmltostring(root) -- 25% overhead due to collecting
    if not root then
        return ""
    elseif type(root) == 'string' then
        return root
    else -- if next(root) then -- next is faster than type (and >0 test)
        return serialize(root,xmlstringhandler) or ""
    end
end

local function __tostring(root) -- inline
    return (root and xmltostring(root)) or ""
end

initialize_mt = function(root) -- redefinition
    mt = { __tostring = __tostring, __index = root }
end

xml.defaulthandlers = handlers
xml.newhandlers     = newhandlers
xml.serialize       = serialize
xml.tostring        = xmltostring

--[[ldx--
<p>The next function operated on the content only and needs a handle function
that accepts a string.</p>
--ldx]]--

local function xmlstring(e,handle)
    if not handle or (e.special and e.tg ~= "@rt@") then
        -- nothing
    elseif e.tg then
        local edt = e.dt
        if edt then
            for i=1,#edt do
                xmlstring(edt[i],handle)
            end
        end
    else
        handle(e)
    end
end

xml.string = xmlstring

--[[ldx--
<p>A few helpers:</p>
--ldx]]--


function xml.settings(e)
    while e do
        local s = e.settings
        if s then
            return s
        else
            e = e.__p__
        end
    end
    return nil
end

function xml.root(e)
    local r = e
    while e do
        e = e.__p__
        if e then
            r = e
        end
    end
    return r
end

function xml.parent(root)
    return root.__p__
end

function xml.body(root)
    return (root.ri and root.dt[root.ri]) or root -- not ok yet
end

function xml.name(root)
    if not root then
        return ""
    elseif root.ns == "" then
        return root.tg
    else
        return root.ns .. ":" .. root.tg
    end
end

--[[ldx--
<p>The next helper erases an element but keeps the table as it is,
and since empty strings are not serialized (effectively) it does
not harm. Copying the table would take more time. Usage:</p>
--ldx]]--

function xml.erase(dt,k)
    if dt then
        if k then
            dt[k] = ""
        else for k=1,#dt do
            dt[1] = { "" }
        end end
    end
end

--[[ldx--
<p>The next helper assigns a tree (or string). Usage:</p>

<typing>
dt[k] = xml.assign(root) or xml.assign(dt,k,root)
</typing>
--ldx]]--

function xml.assign(dt,k,root)
    if dt and k then
        dt[k] = (type(root) == "table" and xml.body(root)) or root
        return dt[k]
    else
        return xml.body(root)
    end
end

-- the following helpers may move

--[[ldx--
<p>The next helper assigns a tree (or string). Usage:</p>
<typing>
xml.tocdata(e)
xml.tocdata(e,"error")
</typing>
--ldx]]--

function xml.tocdata(e,wrapper) -- a few more in the aux module
    local whatever = type(e) == "table" and xmltostring(e.dt) or e or ""
    if wrapper then
        whatever = format("<%s>%s</%s>",wrapper,whatever,wrapper)
    end
    local t = { special = true, ns = "", tg = "@cd@", at = {}, rn = "", dt = { whatever }, __p__ = e }
    setmetatable(t,getmetatable(e))
    e.dt = { t }
end

function xml.makestandalone(root)
    if root.ri then
        local dt = root.dt
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "table" and v.special and v.tg == "@pi@" then
                local txt = v.dt[1]
                if find(txt,"xml.*version=") then
                    v.dt[1] = txt .. " standalone='yes'"
                    break
                end
            end
        end
    end
    return root
end

function xml.kind(e)
    local dt = e and e.dt
    if dt then
        local n = #dt
        if n == 1 then
            local d = dt[1]
            if d.special then
                local tg = d.tg
                if tg == "@cd@" then
                    return "cdata"
                elseif tg == "@cm" then
                    return "comment"
                elseif tg == "@pi@" then
                    return "instruction"
                elseif tg == "@dt@" then
                    return "declaration"
                end
            elseif type(d) == "string" then
                return "text"
            end
            return "element"
        elseif n > 0 then
            return "mixed"
        end
    end
    return "empty"
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-pth'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- e.ni is only valid after a filter run
-- todo: B/C/[get first match]

local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, tonumber, tostring, setmetatable, loadstring = type, next, tonumber, tostring, setmetatable, loadstring
local format, upper, lower, gmatch, gsub, find, rep = string.format, string.upper, string.lower, string.gmatch, string.gsub, string.find, string.rep
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local setmetatableindex = table.setmetatableindex

-- beware, this is not xpath ... e.g. position is different (currently) and
-- we have reverse-sibling as reversed preceding sibling

--[[ldx--
<p>This module can be used stand alone but also inside <l n='mkiv'/> in
which case it hooks into the tracker code. Therefore we provide a few
functions that set the tracers. Here we overload a previously defined
function.</p>
<p>If I can get in the mood I will make a variant that is XSLT compliant
but I wonder if it makes sense.</P>
--ldx]]--

--[[ldx--
<p>Expecially the lpath code is experimental, we will support some of xpath, but
only things that make sense for us; as compensation it is possible to hook in your
own functions. Apart from preprocessing content for <l n='context'/> we also need
this module for process management, like handling <l n='ctx'/> and <l n='rlx'/>
files.</p>

<typing>
a/b/c /*/c
a/b/c/first() a/b/c/last() a/b/c/index(n) a/b/c/index(-n)
a/b/c/text() a/b/c/text(1) a/b/c/text(-1) a/b/c/text(n)
</typing>
--ldx]]--

local trace_lpath    = false  if trackers then trackers.register("xml.path",    function(v) trace_lpath  = v end) end
local trace_lparse   = false  if trackers then trackers.register("xml.parse",   function(v) trace_lparse = v end) end
local trace_lprofile = false  if trackers then trackers.register("xml.profile", function(v) trace_lpath  = v trace_lparse = v trace_lprofile = v end) end

local report_lpath = logs.reporter("xml","lpath")

--[[ldx--
<p>We've now arrived at an interesting part: accessing the tree using a subset
of <l n='xpath'/> and since we're not compatible we call it <l n='lpath'/>. We
will explain more about its usage in other documents.</p>
--ldx]]--

local xml = xml

local lpathcalls  = 0  function xml.lpathcalls () return lpathcalls  end
local lpathcached = 0  function xml.lpathcached() return lpathcached end

xml.functions        = xml.functions or { } -- internal
local functions      = xml.functions

xml.expressions      = xml.expressions or { } -- in expressions
local expressions    = xml.expressions

xml.finalizers       = xml.finalizers or { } -- fast do-with ... (with return value other than collection)
local finalizers     = xml.finalizers

xml.specialhandler   = xml.specialhandler or { }
local specialhandler = xml.specialhandler

lpegpatterns.xml     = lpegpatterns.xml or { }
local xmlpatterns    = lpegpatterns.xml

finalizers.xml = finalizers.xml or { }
finalizers.tex = finalizers.tex or { }

local function fallback (t, name)
    local fn = finalizers[name]
    if fn then
        t[name] = fn
    else
        report_lpath("unknown sub finalizer '%s'",tostring(name))
        fn = function() end
    end
    return fn
end

setmetatableindex(finalizers.xml, fallback)
setmetatableindex(finalizers.tex, fallback)

xml.defaultprotocol = "xml"

-- as xsl does not follow xpath completely here we will also
-- be more liberal especially with regards to the use of | and
-- the rootpath:
--
-- test    : all 'test' under current
-- /test   : 'test' relative to current
-- a|b|c   : set of names
-- (a|b|c) : idem
-- !       : not
--
-- after all, we're not doing transformations but filtering. in
-- addition we provide filter functions (last bit)
--
-- todo: optimizer
--
-- .. : parent
-- *  : all kids
-- /  : anchor here
-- // : /**/
-- ** : all in between
--
-- so far we had (more practical as we don't transform)
--
-- {/test}   : kids 'test' under current node
-- {test}    : any kid with tag 'test'
-- {//test}  : same as above

-- evaluator (needs to be redone, for the moment copied)

-- todo: apply_axis(list,notable) and collection vs single

local apply_axis = { }

apply_axis['root'] = function(list)
    local collected = { }
    for l=1,#list do
        local ll = list[l]
        local rt = ll
        while ll do
            ll = ll.__p__
            if ll then
                rt = ll
            end
        end
        collected[l] = rt
    end
    return collected
end

apply_axis['self'] = function(list)
    return list
end

apply_axis['child'] = function(list)
    local collected, c = { }, 0
    for l=1,#list do
        local ll = list[l]
        local dt = ll.dt
        if dt then -- weird that this is needed
            local en = 0
            for k=1,#dt do
                local dk = dt[k]
                if dk.tg then
                    c = c + 1
                    collected[c] = dk
                    dk.ni = k -- refresh
                    en = en + 1
                    dk.ei = en
                end
            end
            ll.en = en
        end
    end
    return collected
end

local function collect(list,collected,c)
    local dt = list.dt
    if dt then
        local en = 0
        for k=1,#dt do
            local dk = dt[k]
            if dk.tg then
                c = c + 1
                collected[c] = dk
                dk.ni = k -- refresh
                en = en + 1
                dk.ei = en
                c = collect(dk,collected,c)
            end
        end
        list.en = en
    end
    return c
end

apply_axis['descendant'] = function(list)
    local collected, c = { }, 0
    for l=1,#list do
        c = collect(list[l],collected,c)
    end
    return collected
end

local function collect(list,collected,c)
    local dt = list.dt
    if dt then
        local en = 0
        for k=1,#dt do
            local dk = dt[k]
            if dk.tg then
                c = c + 1
                collected[c] = dk
                dk.ni = k -- refresh
                en = en + 1
                dk.ei = en
                c = collect(dk,collected,c)
            end
        end
        list.en = en
    end
    return c
end
apply_axis['descendant-or-self'] = function(list)
    local collected, c = { }, 0
    for l=1,#list do
        local ll = list[l]
        if ll.special ~= true then -- catch double root
            c = c + 1
            collected[c] = ll
        end
        c = collect(ll,collected,c)
    end
    return collected
end

apply_axis['ancestor'] = function(list)
    local collected, c = { }, 0
    for l=1,#list do
        local ll = list[l]
        while ll do
            ll = ll.__p__
            if ll then
                c = c + 1
                collected[c] = ll
            end
        end
    end
    return collected
end

apply_axis['ancestor-or-self'] = function(list)
    local collected, c = { }, 0
    for l=1,#list do
        local ll = list[l]
        c = c + 1
        collected[c] = ll
        while ll do
            ll = ll.__p__
            if ll then
                c = c + 1
                collected[c] = ll
            end
        end
    end
    return collected
end

apply_axis['parent'] = function(list)
    local collected, c = { }, 0
    for l=1,#list do
        local pl = list[l].__p__
        if pl then
            c = c + 1
            collected[c] = pl
        end
    end
    return collected
end

apply_axis['attribute'] = function(list)
    return { }
end

apply_axis['namespace'] = function(list)
    return { }
end

apply_axis['following'] = function(list) -- incomplete
    return { }
end

apply_axis['preceding'] = function(list) -- incomplete
    return { }
end

apply_axis['following-sibling'] = function(list)
    local collected, c = { }, 0
    for l=1,#list do
        local ll = list[l]
        local p = ll.__p__
        local d = p.dt
        for i=ll.ni+1,#d do
            local di = d[i]
            if type(di) == "table" then
                c = c + 1
                collected[c] = di
            end
        end
    end
    return collected
end

apply_axis['preceding-sibling'] = function(list)
    local collected, c = { }, 0
    for l=1,#list do
        local ll = list[l]
        local p = ll.__p__
        local d = p.dt
        for i=1,ll.ni-1 do
            local di = d[i]
            if type(di) == "table" then
                c = c + 1
                collected[c] = di
            end
        end
    end
    return collected
end

apply_axis['reverse-sibling'] = function(list) -- reverse preceding
    local collected, c = { }, 0
    for l=1,#list do
        local ll = list[l]
        local p = ll.__p__
        local d = p.dt
        for i=ll.ni-1,1,-1 do
            local di = d[i]
            if type(di) == "table" then
                c = c + 1
                collected[c] = di
            end
        end
    end
    return collected
end

apply_axis['auto-descendant-or-self'] = apply_axis['descendant-or-self']
apply_axis['auto-descendant']         = apply_axis['descendant']
apply_axis['auto-child']              = apply_axis['child']
apply_axis['auto-self']               = apply_axis['self']
apply_axis['initial-child']           = apply_axis['child']

local function apply_nodes(list,directive,nodes)
    -- todo: nodes[1] etc ... negated node name in set ... when needed
    -- ... currently ignored
    local maxn = #nodes
    if maxn == 3 then --optimized loop
        local nns, ntg = nodes[2], nodes[3]
        if not nns and not ntg then -- wildcard
            if directive then
                return list
            else
                return { }
            end
        else
            local collected, c, m, p = { }, 0, 0, nil
            if not nns then -- only check tag
                for l=1,#list do
                    local ll = list[l]
                    local ltg = ll.tg
                    if ltg then
                        if directive then
                            if ntg == ltg then
                                local llp = ll.__p__ ; if llp ~= p then p, m = llp, 1 else m = m + 1 end
                                c = c + 1
                                collected[c], ll.mi = ll, m
                            end
                        elseif ntg ~= ltg then
                            local llp = ll.__p__ ; if llp ~= p then p, m = llp, 1 else m = m + 1 end
                            c = c + 1
                            collected[c], ll.mi = ll, m
                        end
                    end
                end
            elseif not ntg then -- only check namespace
                for l=1,#list do
                    local ll = list[l]
                    local lns = ll.rn or ll.ns
                    if lns then
                        if directive then
                            if lns == nns then
                                local llp = ll.__p__ ; if llp ~= p then p, m = llp, 1 else m = m + 1 end
                                c = c + 1
                                collected[c], ll.mi = ll, m
                            end
                        elseif lns ~= nns then
                            local llp = ll.__p__ ; if llp ~= p then p, m = llp, 1 else m = m + 1 end
                            c = c + 1
                            collected[c], ll.mi = ll, m
                        end
                    end
                end
            else -- check both
                for l=1,#list do
                    local ll = list[l]
                    local ltg = ll.tg
                    if ltg then
                        local lns = ll.rn or ll.ns
                        local ok = ltg == ntg and lns == nns
                        if directive then
                            if ok then
                                local llp = ll.__p__ ; if llp ~= p then p, m = llp, 1 else m = m + 1 end
                                c = c + 1
                                collected[c], ll.mi = ll, m
                            end
                        elseif not ok then
                            local llp = ll.__p__ ; if llp ~= p then p, m = llp, 1 else m = m + 1 end
                            c = c + 1
                            collected[c], ll.mi = ll, m
                        end
                    end
                end
            end
            return collected
        end
    else
        local collected, c, m, p = { }, 0, 0, nil
        for l=1,#list do
            local ll = list[l]
            local ltg = ll.tg
            if ltg then
                local lns = ll.rn or ll.ns
                local ok = false
                for n=1,maxn,3 do
                    local nns, ntg = nodes[n+1], nodes[n+2]
                    ok = (not ntg or ltg == ntg) and (not nns or lns == nns)
                    if ok then
                        break
                    end
                end
                if directive then
                    if ok then
                        local llp = ll.__p__ ; if llp ~= p then p, m = llp, 1 else m = m + 1 end
                        c = c + 1
                        collected[c], ll.mi = ll, m
                    end
                elseif not ok then
                    local llp = ll.__p__ ; if llp ~= p then p, m = llp, 1 else m = m + 1 end
                    c = c + 1
                    collected[c], ll.mi = ll, m
                end
            end
        end
        return collected
    end
end

local quit_expression = false

local function apply_expression(list,expression,order)
    local collected, c = { }, 0
    quit_expression = false
    for l=1,#list do
        local ll = list[l]
        if expression(list,ll,l,order) then -- nasty, order alleen valid als n=1
            c = c + 1
            collected[c] = ll
        end
        if quit_expression then
            break
        end
    end
    return collected
end

local P, V, C, Cs, Cc, Ct, R, S, Cg, Cb = lpeg.P, lpeg.V, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Ct, lpeg.R, lpeg.S, lpeg.Cg, lpeg.Cb

local spaces     = S(" \n\r\t\f")^0
local lp_space   = S(" \n\r\t\f")
local lp_any     = P(1)
local lp_noequal = P("!=") / "~=" + P("<=") + P(">=") + P("==")
local lp_doequal = P("=")  / "=="
local lp_or      = P("|")  / " or "
local lp_and     = P("&")  / " and "

local lp_builtin = P (
        P("text")         / "(ll.dt[1] or '')" + -- fragile
        P("content")      / "ll.dt" +
    --  P("name")         / "(ll.ns~='' and ll.ns..':'..ll.tg)" +
        P("name")         / "((ll.ns~='' and ll.ns..':'..ll.tg) or ll.tg)" +
        P("tag")          / "ll.tg" +
        P("position")     / "l" + -- is element in finalizer
        P("firstindex")   / "1" +
        P("lastindex")    / "(#ll.__p__.dt or 1)" +
        P("firstelement") / "1" +
        P("lastelement")  / "(ll.__p__.en or 1)" +
        P("first")        / "1" +
        P("last")         / "#list" +
        P("rootposition") / "order" +
        P("order")        / "order" +
        P("element")      / "(ll.ei or 1)" +
        P("index")        / "(ll.ni or 1)" +
        P("match")        / "(ll.mi or 1)" +
     -- P("namespace")    / "ll.ns" +
        P("ns")           / "ll.ns"
    ) * ((spaces * P("(") * spaces * P(")"))/"")

-- for the moment we keep namespaces with attributes

local lp_attribute = (P("@") + P("attribute::")) / "" * Cc("(ll.at and ll.at['") * ((R("az","AZ") + S("-_:"))^1) * Cc("'])")
local lp_fastpos_p = ((P("+")^0 * R("09")^1 * P(-1)) / function(s) return "l==" .. s end)
local lp_fastpos_n = ((P("-")   * R("09")^1 * P(-1)) / function(s) return "(" .. s .. "<0 and (#list+".. s .. "==l))" end)
local lp_fastpos   = lp_fastpos_n + lp_fastpos_p
local lp_reserved  = C("and") + C("or") + C("not") + C("div") + C("mod") + C("true") + C("false")

local lp_lua_function  = C(R("az","AZ","__")^1 * (P(".") * R("az","AZ","__")^1)^1) * ("(") / function(t) -- todo: better . handling
    return t .. "("
end

local lp_function  = C(R("az","AZ","__")^1) * P("(") / function(t) -- todo: better . handling
    if expressions[t] then
        return "expr." .. t .. "("
    else
        return "expr.error("
    end
end

local lparent  = P("(")
local rparent  = P(")")
local noparent = 1 - (lparent+rparent)
local nested   = P{lparent * (noparent + V(1))^0 * rparent}
local value    = P(lparent * C((noparent + nested)^0) * rparent) -- P{"("*C(((1-S("()"))+V(1))^0)*")"}

local lp_child   = Cc("expr.child(ll,'") * R("az","AZ","--","__")^1 * Cc("')")
local lp_number  = S("+-") * R("09")^1
local lp_string  = Cc("'") * R("az","AZ","--","__")^1 * Cc("'")
local lp_content = (P("'") * (1-P("'"))^0 * P("'") + P('"') * (1-P('"'))^0 * P('"'))

local cleaner

local lp_special = (C(P("name")+P("text")+P("tag")+P("count")+P("child"))) * value / function(t,s)
    if expressions[t] then
        s = s and s ~= "" and lpegmatch(cleaner,s)
        if s and s ~= "" then
            return "expr." .. t .. "(ll," .. s ..")"
        else
            return "expr." .. t .. "(ll)"
        end
    else
        return "expr.error(" .. t .. ")"
    end
end

local content =
    lp_builtin +
    lp_attribute +
    lp_special +
    lp_noequal + lp_doequal +
    lp_or + lp_and +
    lp_reserved +
    lp_lua_function + lp_function +
    lp_content + -- too fragile
    lp_child +
    lp_any

local converter = Cs (
    lp_fastpos + (P { lparent * (V(1))^0 * rparent + content } )^0
)

cleaner = Cs ( (
    lp_reserved +
    lp_number +
    lp_string +
1 )^1 )



local template_e = [[
    local expr = xml.expressions
    return function(list,ll,l,order)
        return %s
    end
]]

local template_f_y = [[
    local finalizer = xml.finalizers['%s']['%s']
    return function(collection)
        return finalizer(collection,%s)
    end
]]

local template_f_n = [[
    return xml.finalizers['%s']['%s']
]]

--

local register_self                    = { kind = "axis", axis = "self"                    } -- , apply = apply_axis["self"]               }
local register_parent                  = { kind = "axis", axis = "parent"                  } -- , apply = apply_axis["parent"]             }
local register_descendant              = { kind = "axis", axis = "descendant"              } -- , apply = apply_axis["descendant"]         }
local register_child                   = { kind = "axis", axis = "child"                   } -- , apply = apply_axis["child"]              }
local register_descendant_or_self      = { kind = "axis", axis = "descendant-or-self"      } -- , apply = apply_axis["descendant-or-self"] }
local register_root                    = { kind = "axis", axis = "root"                    } -- , apply = apply_axis["root"]               }
local register_ancestor                = { kind = "axis", axis = "ancestor"                } -- , apply = apply_axis["ancestor"]           }
local register_ancestor_or_self        = { kind = "axis", axis = "ancestor-or-self"        } -- , apply = apply_axis["ancestor-or-self"]   }
local register_attribute               = { kind = "axis", axis = "attribute"               } -- , apply = apply_axis["attribute"]          }
local register_namespace               = { kind = "axis", axis = "namespace"               } -- , apply = apply_axis["namespace"]          }
local register_following               = { kind = "axis", axis = "following"               } -- , apply = apply_axis["following"]          }
local register_following_sibling       = { kind = "axis", axis = "following-sibling"       } -- , apply = apply_axis["following-sibling"]  }
local register_preceding               = { kind = "axis", axis = "preceding"               } -- , apply = apply_axis["preceding"]          }
local register_preceding_sibling       = { kind = "axis", axis = "preceding-sibling"       } -- , apply = apply_axis["preceding-sibling"]  }
local register_reverse_sibling         = { kind = "axis", axis = "reverse-sibling"         } -- , apply = apply_axis["reverse-sibling"]    }

local register_auto_descendant_or_self = { kind = "axis", axis = "auto-descendant-or-self" } -- , apply = apply_axis["auto-descendant-or-self"] }
local register_auto_descendant         = { kind = "axis", axis = "auto-descendant"         } -- , apply = apply_axis["auto-descendant"] }
local register_auto_self               = { kind = "axis", axis = "auto-self"               } -- , apply = apply_axis["auto-self"] }
local register_auto_child              = { kind = "axis", axis = "auto-child"              } -- , apply = apply_axis["auto-child"] }

local register_initial_child           = { kind = "axis", axis = "initial-child"           } -- , apply = apply_axis["initial-child"] }

local register_all_nodes               = { kind = "nodes", nodetest = true, nodes = { true, false, false } }

local skip = { }

local function errorrunner_e(str,cnv)
    if not skip[str] then
        report_lpath("error in expression: %s => %s",str,cnv)
        skip[str] = cnv or str
    end
    return false
end
local function errorrunner_f(str,arg)
    report_lpath("error in finalizer: %s(%s)",str,arg or "")
    return false
end

local function register_nodes(nodetest,nodes)
    return { kind = "nodes", nodetest = nodetest, nodes = nodes }
end

local function register_expression(expression)
    local converted = lpegmatch(converter,expression)
    local runner = loadstring(format(template_e,converted))
    runner = (runner and runner()) or function() errorrunner_e(expression,converted) end
    return { kind = "expression", expression = expression, converted = converted, evaluator = runner }
end

local function register_finalizer(protocol,name,arguments)
    local runner
    if arguments and arguments ~= "" then
        runner = loadstring(format(template_f_y,protocol or xml.defaultprotocol,name,arguments))
    else
        runner = loadstring(format(template_f_n,protocol or xml.defaultprotocol,name))
    end
    runner = (runner and runner()) or function() errorrunner_f(name,arguments) end
    return { kind = "finalizer", name = name, arguments = arguments, finalizer = runner }
end

local expression = P { "ex",
    ex = "[" * C((V("sq") + V("dq") + (1 - S("[]")) + V("ex"))^0) * "]",
    sq = "'" * (1 - S("'"))^0 * "'",
    dq = '"' * (1 - S('"'))^0 * '"',
}

local arguments = P { "ar",
    ar = "(" * Cs((V("sq") + V("dq") + V("nq") + P(1-P(")")))^0) * ")",
    nq = ((1 - S("),'\""))^1) / function(s) return format("%q",s) end,
    sq = P("'") * (1 - P("'"))^0 * P("'"),
    dq = P('"') * (1 - P('"'))^0 * P('"'),
}

-- todo: better arg parser

local function register_error(str)
    return { kind = "error", error = format("unparsed: %s",str) }
end

-- there is a difference in * and /*/ and so we need to catch a few special cases

local special_1 = P("*")  * Cc(register_auto_descendant) * Cc(register_all_nodes) -- last one not needed
local special_2 = P("/")  * Cc(register_auto_self)
local special_3 = P("")   * Cc(register_auto_self)

local no_nextcolon   = P(-1) + #(1-P(":")) -- newer lpeg needs the P(-1)
local no_nextlparent = P(-1) + #(1-P("(")) -- newer lpeg needs the P(-1)

local pathparser = Ct { "patterns", -- can be made a bit faster by moving some patterns outside

    patterns             = spaces * V("protocol") * spaces * (
                              ( V("special") * spaces * P(-1)                                                         ) +
                              ( V("initial") * spaces * V("step") * spaces * (P("/") * spaces * V("step") * spaces)^0 )
                           ),

    protocol             = Cg(V("letters"),"protocol") * P("://") + Cg(Cc(nil),"protocol"),

 -- the / is needed for // as descendant or self is somewhat special
 -- step                 = (V("shortcuts") + V("axis") * spaces * V("nodes")^0 + V("error")) * spaces * V("expressions")^0 * spaces * V("finalizer")^0,
    step                 = ((V("shortcuts") + P("/") + V("axis")) * spaces * V("nodes")^0 + V("error")) * spaces * V("expressions")^0 * spaces * V("finalizer")^0,

    axis                 = V("descendant") + V("child") + V("parent") + V("self") + V("root") + V("ancestor") +
                           V("descendant_or_self") + V("following_sibling") + V("following") +
                           V("reverse_sibling") + V("preceding_sibling") + V("preceding") + V("ancestor_or_self") +
                           #(1-P(-1)) * Cc(register_auto_child),

    special              = special_1 + special_2 + special_3,

    initial              = (P("/") * spaces * Cc(register_initial_child))^-1,

    error                = (P(1)^1) / register_error,

    shortcuts_a          = V("s_descendant_or_self") + V("s_descendant") + V("s_child") + V("s_parent") + V("s_self") + V("s_root") + V("s_ancestor"),

    shortcuts            = V("shortcuts_a") * (spaces * "/" * spaces * V("shortcuts_a"))^0,

    s_descendant_or_self = (P("***/") + P("/"))  * Cc(register_descendant_or_self), --- *** is a bonus
    s_descendant         = P("**")               * Cc(register_descendant),
    s_child              = P("*") * no_nextcolon * Cc(register_child     ),
    s_parent             = P("..")               * Cc(register_parent    ),
    s_self               = P("." )               * Cc(register_self      ),
    s_root               = P("^^")               * Cc(register_root      ),
    s_ancestor           = P("^")                * Cc(register_ancestor  ),

    descendant           = P("descendant::")         * Cc(register_descendant         ),
    child                = P("child::")              * Cc(register_child              ),
    parent               = P("parent::")             * Cc(register_parent             ),
    self                 = P("self::")               * Cc(register_self               ),
    root                 = P('root::')               * Cc(register_root               ),
    ancestor             = P('ancestor::')           * Cc(register_ancestor           ),
    descendant_or_self   = P('descendant-or-self::') * Cc(register_descendant_or_self ),
    ancestor_or_self     = P('ancestor-or-self::')   * Cc(register_ancestor_or_self   ),
 -- attribute            = P('attribute::')          * Cc(register_attribute          ),
 -- namespace            = P('namespace::')          * Cc(register_namespace          ),
    following            = P('following::')          * Cc(register_following          ),
    following_sibling    = P('following-sibling::')  * Cc(register_following_sibling  ),
    preceding            = P('preceding::')          * Cc(register_preceding          ),
    preceding_sibling    = P('preceding-sibling::')  * Cc(register_preceding_sibling  ),
    reverse_sibling      = P('reverse-sibling::')    * Cc(register_reverse_sibling    ),

    nodes                = (V("nodefunction") * spaces * P("(") * V("nodeset") * P(")") + V("nodetest") * V("nodeset")) / register_nodes,

    expressions          = expression / register_expression,

    letters              = R("az")^1,
    name                 = (1-S("/[]()|:*!"))^1, -- make inline
    negate               = P("!") * Cc(false),

    nodefunction         = V("negate") + P("not") * Cc(false) + Cc(true),
    nodetest             = V("negate") + Cc(true),
    nodename             = (V("negate") + Cc(true)) * spaces * ((V("wildnodename") * P(":") * V("wildnodename")) + (Cc(false) * V("wildnodename"))),
    wildnodename         = (C(V("name")) + P("*") * Cc(false)) * no_nextlparent,
    nodeset              = spaces * Ct(V("nodename") * (spaces * P("|") * spaces * V("nodename"))^0) * spaces,

    finalizer            = (Cb("protocol") * P("/")^-1 * C(V("name")) * arguments * P(-1)) / register_finalizer,

}

xmlpatterns.pathparser = pathparser

local cache = { }

local function nodesettostring(set,nodetest)
    local t = { }
    for i=1,#set,3 do
        local directive, ns, tg = set[i], set[i+1], set[i+2]
        if not ns or ns == "" then ns = "*" end
        if not tg or tg == "" then tg = "*" end
        tg = (tg == "@rt@" and "[root]") or format("%s:%s",ns,tg)
        t[i] = (directive and tg) or format("not(%s)",tg)
    end
    if nodetest == false then
        return format("not(%s)",concat(t,"|"))
    else
        return concat(t,"|")
    end
end

local function tagstostring(list)
    if #list == 0 then
        return "no elements"
    else
        local t = { }
        for i=1, #list do
            local li = list[i]
            local ns, tg = li.ns, li.tg
            if not ns or ns == "" then ns = "*" end
            if not tg or tg == "" then tg = "*" end
            t[i] = (tg == "@rt@" and "[root]") or format("%s:%s",ns,tg)
        end
        return concat(t," ")
    end
end

xml.nodesettostring = nodesettostring

local lpath -- we have a harmless kind of circular reference

local lshowoptions = { functions = false }

local function lshow(parsed)
    if type(parsed) == "string" then
        parsed = lpath(parsed)
    end
    report_lpath("%s://%s => %s",parsed.protocol or xml.defaultprotocol,parsed.pattern,
        table.serialize(parsed,false,lshowoptions))
end

xml.lshow = lshow

local function add_comment(p,str)
    local pc = p.comment
    if not pc then
        p.comment = { str }
    else
        pc[#pc+1] = str
    end
end

lpath = function (pattern) -- the gain of caching is rather minimal
    lpathcalls = lpathcalls + 1
    if type(pattern) == "table" then
        return pattern
    else
        local parsed = cache[pattern]
        if parsed then
            lpathcached = lpathcached + 1
        else
            parsed = lpegmatch(pathparser,pattern)
            if parsed then
                parsed.pattern = pattern
                local np = #parsed
                if np == 0 then
                    parsed = { pattern = pattern, register_self, state = "parsing error" }
                    report_lpath("parsing error in '%s'",pattern)
                    lshow(parsed)
                else
                    -- we could have done this with a more complex parser but this
                    -- is cleaner
                    local pi = parsed[1]
                    if pi.axis == "auto-child" then
                        if false then
                            add_comment(parsed, "auto-child replaced by auto-descendant-or-self")
                            parsed[1] = register_auto_descendant_or_self
                        else
                            add_comment(parsed, "auto-child replaced by auto-descendant")
                            parsed[1] = register_auto_descendant
                        end
                    elseif pi.axis == "initial-child" and np > 1 and parsed[2].axis then
                        add_comment(parsed, "initial-child removed") -- we could also make it a auto-self
                        remove(parsed,1)
                    end
                    local np = #parsed -- can have changed
                    if np > 1 then
                        local pnp = parsed[np]
                        if pnp.kind == "nodes" and pnp.nodetest == true then
                            local nodes = pnp.nodes
                            if nodes[1] == true and nodes[2] == false and nodes[3] == false then
                                add_comment(parsed, "redundant final wildcard filter removed")
                                remove(parsed,np)
                            end
                        end
                    end
                end
            else
                parsed = { pattern = pattern }
            end
            cache[pattern] = parsed
            if trace_lparse and not trace_lprofile then
                lshow(parsed)
            end
        end
        return parsed
    end
end

xml.lpath = lpath

-- we can move all calls inline and then merge the trace back
-- technically we can combine axis and the next nodes which is
-- what we did before but this a bit cleaner (but slower too)
-- but interesting is that it's not that much faster when we
-- go inline
--
-- beware: we need to return a collection even when we filter
-- else the (simple) cache gets messed up

-- caching found lookups saves not that much (max .1 sec on a 8 sec run)
-- and it also messes up finalizers

-- watch out: when there is a finalizer, it's always called as there
-- can be cases that a finalizer returns (or does) something in case
-- there is no match; an example of this is count()

local profiled = { }  xml.profiled = profiled

local function profiled_apply(list,parsed,nofparsed,order)
    local p = profiled[parsed.pattern]
    if p then
        p.tested = p.tested + 1
    else
        p = { tested = 1, matched = 0, finalized = 0 }
        profiled[parsed.pattern] = p
    end
    local collected = list
    for i=1,nofparsed do
        local pi = parsed[i]
        local kind = pi.kind
        if kind == "axis" then
            collected = apply_axis[pi.axis](collected)
        elseif kind == "nodes" then
            collected = apply_nodes(collected,pi.nodetest,pi.nodes)
        elseif kind == "expression" then
            collected = apply_expression(collected,pi.evaluator,order)
        elseif kind == "finalizer" then
            collected = pi.finalizer(collected) -- no check on # here
            p.matched = p.matched + 1
            p.finalized = p.finalized + 1
            return collected
        end
        if not collected or #collected == 0 then
            local pn = i < nofparsed and parsed[nofparsed]
            if pn and pn.kind == "finalizer" then
                collected = pn.finalizer(collected)
                p.finalized = p.finalized + 1
                return collected
            end
            return nil
        end
    end
    if collected then
        p.matched = p.matched + 1
    end
    return collected
end

local function traced_apply(list,parsed,nofparsed,order)
    if trace_lparse then
        lshow(parsed)
    end
    report_lpath("collecting: %s",parsed.pattern)
    report_lpath("root tags : %s",tagstostring(list))
    report_lpath("order     : %s",order or "unset")
    local collected = list
    for i=1,nofparsed do
        local pi = parsed[i]
        local kind = pi.kind
        if kind == "axis" then
            collected = apply_axis[pi.axis](collected)
            report_lpath("% 10i : ax : %s",(collected and #collected) or 0,pi.axis)
        elseif kind == "nodes" then
            collected = apply_nodes(collected,pi.nodetest,pi.nodes)
            report_lpath("% 10i : ns : %s",(collected and #collected) or 0,nodesettostring(pi.nodes,pi.nodetest))
        elseif kind == "expression" then
            collected = apply_expression(collected,pi.evaluator,order)
            report_lpath("% 10i : ex : %s -> %s",(collected and #collected) or 0,pi.expression,pi.converted)
        elseif kind == "finalizer" then
            collected = pi.finalizer(collected)
            report_lpath("% 10i : fi : %s : %s(%s)",(type(collected) == "table" and #collected) or 0,parsed.protocol or xml.defaultprotocol,pi.name,pi.arguments or "")
            return collected
        end
        if not collected or #collected == 0 then
            local pn = i < nofparsed and parsed[nofparsed]
            if pn and pn.kind == "finalizer" then
                collected = pn.finalizer(collected)
                report_lpath("% 10i : fi : %s : %s(%s)",(type(collected) == "table" and #collected) or 0,parsed.protocol or xml.defaultprotocol,pn.name,pn.arguments or "")
                return collected
            end
            return nil
        end
    end
    return collected
end

local function normal_apply(list,parsed,nofparsed,order)
    local collected = list
    for i=1,nofparsed do
        local pi = parsed[i]
        local kind = pi.kind
        if kind == "axis" then
            local axis = pi.axis
            if axis ~= "self" then
                collected = apply_axis[axis](collected)
            end
        elseif kind == "nodes" then
            collected = apply_nodes(collected,pi.nodetest,pi.nodes)
        elseif kind == "expression" then
            collected = apply_expression(collected,pi.evaluator,order)
        elseif kind == "finalizer" then
            return pi.finalizer(collected)
        end
        if not collected or #collected == 0 then
            local pf = i < nofparsed and parsed[nofparsed].finalizer
            if pf then
                return pf(collected) -- can be anything
            end
            return nil
        end
    end
    return collected
end


local function applylpath(list,pattern)
    if not list then
        return
    end
    local parsed = cache[pattern]
    if parsed then
        lpathcalls = lpathcalls + 1
        lpathcached = lpathcached + 1
    elseif type(pattern) == "table" then
        lpathcalls = lpathcalls + 1
        parsed = pattern
    else
        parsed = lpath(pattern) or pattern
    end
    if not parsed then
        return
    end
    local nofparsed = #parsed
    if nofparsed == 0 then
        return -- something is wrong
    end
    if not trace_lpath then
        return normal_apply  ({ list },parsed,nofparsed,list.mi)
    elseif trace_lprofile then
        return profiled_apply({ list },parsed,nofparsed,list.mi)
    else
        return traced_apply  ({ list },parsed,nofparsed,list.mi)
    end
end

xml.applylpath = applylpath -- takes a table as first argment, which is what xml.filter will do

--[[ldx--
<p>This is the main filter function. It returns whatever is asked for.</p>
--ldx]]--

function xml.filter(root,pattern) -- no longer funny attribute handling here
    return applylpath(root,pattern)
end

-- internal (parsed)

expressions.child = function(e,pattern)
    return applylpath(e,pattern) -- todo: cache
end
expressions.count = function(e,pattern) -- what if pattern == empty or nil
    local collected = applylpath(e,pattern) -- todo: cache
    return pattern and (collected and #collected) or 0
end

-- external

expressions.oneof = function(s,...) -- slow
    local t = {...} for i=1,#t do if s == t[i] then return true end end return false
end
expressions.error = function(str)
    xml.errorhandler(format("unknown function in lpath expression: %s",tostring(str or "?")))
    return false
end
expressions.undefined = function(s)
    return s == nil
end

expressions.quit = function(s)
    if s or s == nil then
        quit_expression = true
    end
    return true
end

expressions.print = function(...)
    print(...)
    return true
end

expressions.contains  = find
expressions.find      = find
expressions.upper     = upper
expressions.lower     = lower
expressions.number    = tonumber
expressions.boolean   = toboolean

function expressions.contains(str,pattern)
    local t = type(str)
    if t == "string" then
        if find(str,pattern) then
            return true
        end
    elseif t == "table" then
        for i=1,#str do
            local d = str[i]
            if type(d) == "string" and find(d,pattern) then
                return true
            end
        end
    end
    return false
end

-- user interface

local function traverse(root,pattern,handle)
    report_lpath("use 'xml.selection' instead for '%s'",pattern)
    local collected = applylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local r = e.__p__
            handle(r,r.dt,e.ni)
        end
    end
end

local function selection(root,pattern,handle)
    local collected = applylpath(root,pattern)
    if collected then
        if handle then
            for c=1,#collected do
                handle(collected[c])
            end
        else
            return collected
        end
    end
end

xml.traverse      = traverse           -- old method, r, d, k
xml.selection     = selection          -- new method, simple handle


-- generic function finalizer (independant namespace)

local function dofunction(collected,fnc)
    if collected then
        local f = functions[fnc]
        if f then
            for c=1,#collected do
                f(collected[c])
            end
        else
            report_lpath("unknown function '%s'",fnc)
        end
    end
end

finalizers.xml["function"] = dofunction
finalizers.tex["function"] = dofunction

-- functions

expressions.text = function(e,n)
    local rdt = e.__p__.dt
    return (rdt and rdt[n]) or ""
end

expressions.name = function(e,n) -- ns + tg
    local found = false
    n = tonumber(n) or 0
    if n == 0 then
        found = type(e) == "table" and e
    elseif n < 0 then
        local d, k = e.__p__.dt, e.ni
        for i=k-1,1,-1 do
            local di = d[i]
            if type(di) == "table" then
                if n == -1 then
                    found = di
                    break
                else
                    n = n + 1
                end
            end
        end
    else
        local d, k = e.__p__.dt, e.ni
        for i=k+1,#d,1 do
            local di = d[i]
            if type(di) == "table" then
                if n == 1 then
                    found = di
                    break
                else
                    n = n - 1
                end
            end
        end
    end
    if found then
        local ns, tg = found.rn or found.ns or "", found.tg
        if ns ~= "" then
            return ns .. ":" .. tg
        else
            return tg
        end
    else
        return ""
    end
end

expressions.tag = function(e,n) -- only tg
    if not e then
        return ""
    else
        local found = false
        n = tonumber(n) or 0
        if n == 0 then
            found = (type(e) == "table") and e -- seems to fail
        elseif n < 0 then
            local d, k = e.__p__.dt, e.ni
            for i=k-1,1,-1 do
                local di = d[i]
                if type(di) == "table" then
                    if n == -1 then
                        found = di
                        break
                    else
                        n = n + 1
                    end
                end
            end
        else
            local d, k = e.__p__.dt, e.ni
            for i=k+1,#d,1 do
                local di = d[i]
                if type(di) == "table" then
                    if n == 1 then
                        found = di
                        break
                    else
                        n = n - 1
                    end
                end
            end
        end
        return (found and found.tg) or ""
    end
end

--[[ldx--
<p>Often using an iterators looks nicer in the code than passing handler
functions. The <l n='lua'/> book describes how to use coroutines for that
purpose (<url href='http://www.lua.org/pil/9.3.html'/>). This permits
code like:</p>

<typing>
for r, d, k in xml.elements(xml.load('text.xml'),"title") do
    print(d[k]) -- old method
end
for e in xml.collected(xml.load('text.xml'),"title") do
    print(e) -- new one
end
</typing>
--ldx]]--

local wrap, yield = coroutine.wrap, coroutine.yield

function xml.elements(root,pattern,reverse) -- r, d, k
    local collected = applylpath(root,pattern)
    if collected then
        if reverse then
            return wrap(function() for c=#collected,1,-1 do
                local e = collected[c] local r = e.__p__ yield(r,r.dt,e.ni)
            end end)
        else
            return wrap(function() for c=1,#collected    do
                local e = collected[c] local r = e.__p__ yield(r,r.dt,e.ni)
            end end)
        end
    end
    return wrap(function() end)
end

function xml.collected(root,pattern,reverse) -- e
    local collected = applylpath(root,pattern)
    if collected then
        if reverse then
            return wrap(function() for c=#collected,1,-1 do yield(collected[c]) end end)
        else
            return wrap(function() for c=1,#collected    do yield(collected[c]) end end)
        end
    end
    return wrap(function() end)
end

-- handy

function xml.inspect(collection,pattern)
    pattern = pattern or "."
    for e in xml.collected(collection,pattern or ".") do
        report_lpath("pattern %q\n\n%s\n",pattern,xml.tostring(e))
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-mis'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local xml, lpeg, string = xml, lpeg, string

local concat = table.concat
local type, next, tonumber, tostring, setmetatable, loadstring = type, next, tonumber, tostring, setmetatable, loadstring
local format, gsub, match = string.format, string.gsub, string.match
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, S, R, C, V, Cc, Cs = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Cs

lpegpatterns.xml  = lpegpatterns.xml or { }
local xmlpatterns = lpegpatterns.xml

--[[ldx--
<p>The following helper functions best belong to the <t>lxml-ini</t>
module. Some are here because we need then in the <t>mk</t>
document and other manuals, others came up when playing with
this module. Since this module is also used in <l n='mtxrun'/> we've
put them here instead of loading mode modules there then needed.</p>
--ldx]]--

local function xmlgsub(t,old,new) -- will be replaced
    local dt = t.dt
    if dt then
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "string" then
                dt[k] = gsub(v,old,new)
            else
                xmlgsub(v,old,new)
            end
        end
    end
end


function xml.stripleadingspaces(dk,d,k) -- cosmetic, for manual
    if d and k then
        local dkm = d[k-1]
        if dkm and type(dkm) == "string" then
            local s = match(dkm,"\n(%s+)")
            xmlgsub(dk,"\n"..rep(" ",#s),"\n")
        end
    end
end



-- 100 * 2500 * "oeps< oeps> oeps&" : gsub:lpeg|lpeg|lpeg
--
-- 1021:0335:0287:0247

-- 10 * 1000 * "oeps< oeps> oeps& asfjhalskfjh alskfjh alskfjh alskfjh ;al J;LSFDJ"
--
-- 1559:0257:0288:0190 (last one suggested by roberto)

--    escaped = Cs((S("<&>") / xml.escapes + 1)^0)
--    escaped = Cs((S("<")/"&lt;" + S(">")/"&gt;" + S("&")/"&amp;" + 1)^0)
local normal  = (1 - S("<&>"))^0
local special = P("<")/"&lt;" + P(">")/"&gt;" + P("&")/"&amp;"
local escaped = Cs(normal * (special * normal)^0)

-- 100 * 1000 * "oeps&lt; oeps&gt; oeps&amp;" : gsub:lpeg == 0153:0280:0151:0080 (last one by roberto)

local normal    = (1 - S"&")^0
local special   = P("&lt;")/"<" + P("&gt;")/">" + P("&amp;")/"&"
local unescaped = Cs(normal * (special * normal)^0)

-- 100 * 5000 * "oeps <oeps bla='oeps' foo='bar'> oeps </oeps> oeps " : gsub:lpeg == 623:501 msec (short tags, less difference)

local cleansed = Cs(((P("<") * (1-P(">"))^0 * P(">"))/"" + 1)^0)

xmlpatterns.escaped   = escaped
xmlpatterns.unescaped = unescaped
xmlpatterns.cleansed  = cleansed

function xml.escaped  (str) return lpegmatch(escaped,str)   end
function xml.unescaped(str) return lpegmatch(unescaped,str) end
function xml.cleansed (str) return lpegmatch(cleansed,str)  end

-- this might move

function xml.fillin(root,pattern,str,check)
    local e = xml.first(root,pattern)
    if e then
        local n = #e.dt
        if not check or n == 0 or (n == 1 and e.dt[1] == "") then
            e.dt = { str }
        end
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-aux'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- not all functions here make sense anymore vbut we keep them for
-- compatibility reasons

local trace_manipulations = false  trackers.register("lxml.manipulations", function(v) trace_manipulations = v end)

local report_xml = logs.reporter("xml")

local xml = xml

local xmlconvert, xmlcopy, xmlname = xml.convert, xml.copy, xml.name
local xmlinheritedconvert = xml.inheritedconvert
local xmlapplylpath = xml.applylpath
local xmlfilter = xml.filter

local type, setmetatable, getmetatable = type, setmetatable, getmetatable
local insert, remove, fastcopy, concat = table.insert, table.remove, table.fastcopy, table.concat
local gmatch, gsub, format, find, strip = string.gmatch, string.gsub, string.format, string.find, string.strip
local utfbyte = utf.byte

local function report(what,pattern,c,e)
    report_xml("%s element '%s' (root: '%s', position: %s, index: %s, pattern: %s)",what,xmlname(e),xmlname(e.__p__),c,e.ni,pattern)
end

local function withelements(e,handle,depth)
    if e and handle then
        local edt = e.dt
        if edt then
            depth = depth or 0
            for i=1,#edt do
                local e = edt[i]
                if type(e) == "table" then
                    handle(e,depth)
                    withelements(e,handle,depth+1)
                end
            end
        end
    end
end

xml.withelements = withelements

function xml.withelement(e,n,handle) -- slow
    if e and n ~= 0 and handle then
        local edt = e.dt
        if edt then
            if n > 0 then
                for i=1,#edt do
                    local ei = edt[i]
                    if type(ei) == "table" then
                        if n == 1 then
                            handle(ei)
                            return
                        else
                            n = n - 1
                        end
                    end
                end
            elseif n < 0 then
                for i=#edt,1,-1 do
                    local ei = edt[i]
                    if type(ei) == "table" then
                        if n == -1 then
                            handle(ei)
                            return
                        else
                            n = n + 1
                        end
                    end
                end
            end
        end
    end
end

function xml.each(root,pattern,handle,reverse)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        if reverse then
            for c=#collected,1,-1 do
                handle(collected[c])
            end
        else
            for c=1,#collected do
                handle(collected[c])
            end
        end
        return collected
    end
end

function xml.processattributes(root,pattern,handle)
    local collected = xmlapplylpath(root,pattern)
    if collected and handle then
        for c=1,#collected do
            handle(collected[c].at)
        end
    end
    return collected
end

--[[ldx--
<p>The following functions collect elements and texts.</p>
--ldx]]--

-- are these still needed -> lxml-cmp.lua

function xml.collect(root, pattern)
    return xmlapplylpath(root,pattern)
end

function xml.collecttexts(root, pattern, flatten) -- todo: variant with handle
    local collected = xmlapplylpath(root,pattern)
    if collected and flatten then
        local xmltostring = xml.tostring
        for c=1,#collected do
            collected[c] = xmltostring(collected[c].dt)
        end
    end
    return collected or { }
end

function xml.collect_tags(root, pattern, nonamespace)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        local t, n = { }, 0
        for c=1,#collected do
            local e = collected[c]
            local ns, tg = e.ns, e.tg
            n = n + 1
            if nonamespace then
                t[n] = tg
            elseif ns == "" then
                t[n] = tg
            else
                t[n] = ns .. ":" .. tg
            end
        end
        return t
    end
end

--[[ldx--
<p>We've now arrived at the functions that manipulate the tree.</p>
--ldx]]--

local no_root = { no_root = true }

local function redo_ni(d)
    for k=1,#d do
        local dk = d[k]
        if type(dk) == "table" then
            dk.ni = k
        end
    end
end

local function xmltoelement(whatever,root)
    if not whatever then
        return nil
    end
    local element
    if type(whatever) == "string" then
        element = xmlinheritedconvert(whatever,root) -- beware, not really a root
    else
        element = whatever -- we assume a table
    end
    if element.error then
        return whatever -- string
    end
    if element then
                        end
    return element
end

xml.toelement = xmltoelement

local function copiedelement(element,newparent)
    if type(element) == "string" then
        return element
    else
        element = xmlcopy(element).dt
        if newparent and type(element) == "table" then
            element.__p__ = newparent
        end
        return element
    end
end

function xml.delete(root,pattern)
    if not pattern or pattern == "" then
        local p = root.__p__
        if p then
            if trace_manipulations then
                report('deleting',"--",c,root)
            end
            local d = p.dt
            remove(d,root.ni)
            redo_ni(d) -- can be made faster and inlined
        end
    else
        local collected = xmlapplylpath(root,pattern)
        if collected then
            for c=1,#collected do
                local e = collected[c]
                local p = e.__p__
                if p then
                    if trace_manipulations then
                        report('deleting',pattern,c,e)
                    end
                    local d = p.dt
                    remove(d,e.ni)
                    redo_ni(d) -- can be made faster and inlined
                end
            end
        end
    end
end

function xml.replace(root,pattern,whatever)
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local p = e.__p__
            if p then
                if trace_manipulations then
                    report('replacing',pattern,c,e)
                end
                local d = p.dt
                d[e.ni] = copiedelement(element,p)
                redo_ni(d) -- probably not needed
            end
        end
    end
end

local function wrap(e,wrapper)
    local t = {
        rn = e.rn,
        tg = e.tg,
        ns = e.ns,
        at = e.at,
        dt = e.dt,
        __p__ = e,
    }
    setmetatable(t,getmetatable(e))
    e.rn = wrapper.rn or e.rn or ""
    e.tg = wrapper.tg or e.tg or ""
    e.ns = wrapper.ns or e.ns or ""
    e.at = fastcopy(wrapper.at)
    e.dt = { t }
end

function xml.wrap(root,pattern,whatever)
    if whatever then
        local wrapper = xmltoelement(whatever,root)
        local collected = xmlapplylpath(root,pattern)
        if collected then
            for c=1,#collected do
                local e = collected[c]
                if trace_manipulations then
                    report('wrapping',pattern,c,e)
                end
                wrap(e,wrapper)
            end
        end
    else
        wrap(root,xmltoelement(pattern))
    end
end

local function inject_element(root,pattern,whatever,prepend)
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlapplylpath(root,pattern)
    local function inject_e(e)
        local r = e.__p__
        local d, k, rri = r.dt, e.ni, r.ri
        local edt = (rri and d[rri].dt) or (d and d[k] and d[k].dt)
        if edt then
            local be, af
            local cp = copiedelement(element,e)
            if prepend then
                be, af = cp, edt
            else
                be, af = edt, cp
            end
            local bn = #be
            for i=1,#af do
                bn = bn + 1
                be[bn] = af[i]
            end
            if rri then
                r.dt[rri].dt = be
            else
                d[k].dt = be
            end
            redo_ni(d)
        end
    end
    if not collected then
        -- nothing
    elseif collected.tg then
        -- first or so
        inject_e(collected)
    else
        for c=1,#collected do
            inject_e(collected[c])
        end
    end
end

local function insert_element(root,pattern,whatever,before) -- todo: element als functie
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlapplylpath(root,pattern)
    local function insert_e(e)
        local r = e.__p__
        local d, k = r.dt, e.ni
        if not before then
            k = k + 1
        end
        insert(d,k,copiedelement(element,r))
        redo_ni(d)
    end
    if not collected then
        -- nothing
    elseif collected.tg then
        -- first or so
        insert_e(collected)
    else
        for c=1,#collected do
            insert_e(collected[c])
        end
    end
end

xml.insert_element  =                 insert_element
xml.insertafter     =                 insert_element
xml.insertbefore    = function(r,p,e) insert_element(r,p,e,true) end
xml.injectafter     =                 inject_element
xml.injectbefore    = function(r,p,e) inject_element(r,p,e,true) end

local function include(xmldata,pattern,attribute,recursive,loaddata)
    -- parse="text" (default: xml), encoding="" (todo)
    -- attribute = attribute or 'href'
    pattern = pattern or 'include'
    loaddata = loaddata or io.loaddata
    local collected = xmlapplylpath(xmldata,pattern)
    if collected then
        for c=1,#collected do
            local ek = collected[c]
            local name = nil
            local ekdt = ek.dt
            local ekat = ek.at
            local epdt = ek.__p__.dt
            if not attribute or attribute == "" then
                name = (type(ekdt) == "table" and ekdt[1]) or ekdt -- check, probably always tab or str
            end
            if not name then
                for a in gmatch(attribute or "href","([^|]+)") do
                    name = ekat[a]
                    if name then break end
                end
            end
            local data = (name and name ~= "" and loaddata(name)) or ""
            if data == "" then
                epdt[ek.ni] = "" -- xml.empty(d,k)
            elseif ekat["parse"] == "text" then
                -- for the moment hard coded
                epdt[ek.ni] = xml.escaped(data) -- d[k] = xml.escaped(data)
            else
                local xi = xmlinheritedconvert(data,xmldata)
                if not xi then
                    epdt[ek.ni] = "" -- xml.empty(d,k)
                else
                    if recursive then
                        include(xi,pattern,attribute,recursive,loaddata)
                    end
                    epdt[ek.ni] = xml.body(xi) -- xml.assign(d,k,xi)
                end
            end
        end
    end
end

xml.include = include

local function stripelement(e,nolines,anywhere)
    local edt = e.dt
    if edt then
        if anywhere then
            local t, n = { }, 0
            for e=1,#edt do
                local str = edt[e]
                if type(str) ~= "string" then
                    n = n + 1
                    t[n] = str
                elseif str ~= "" then
                    -- todo: lpeg for each case
                    if nolines then
                        str = gsub(str,"%s+"," ")
                    end
                    str = gsub(str,"^%s*(.-)%s*$","%1")
                    if str ~= "" then
                        n = n + 1
                        t[n] = str
                    end
                end
            end
            e.dt = t
        else
            -- we can assume a regular sparse xml table with no successive strings
            -- otherwise we should use a while loop
            if #edt > 0 then
                -- strip front
                local str = edt[1]
                if type(str) ~= "string" then
                    -- nothing
                elseif str == "" then
                    remove(edt,1)
                else
                    if nolines then
                        str = gsub(str,"%s+"," ")
                    end
                    str = gsub(str,"^%s+","")
                    if str == "" then
                        remove(edt,1)
                    else
                        edt[1] = str
                    end
                end
            end
            local nedt = #edt
            if nedt > 0 then
                -- strip end
                local str = edt[nedt]
                if type(str) ~= "string" then
                    -- nothing
                elseif str == "" then
                    remove(edt)
                else
                    if nolines then
                        str = gsub(str,"%s+"," ")
                    end
                    str = gsub(str,"%s+$","")
                    if str == "" then
                        remove(edt)
                    else
                        edt[nedt] = str
                    end
                end
            end
        end
    end
    return e -- convenient
end

xml.stripelement = stripelement

function xml.strip(root,pattern,nolines,anywhere) -- strips all leading and trailing spacing
    local collected = xmlapplylpath(root,pattern) -- beware, indices no longer are valid now
    if collected then
        for i=1,#collected do
            stripelement(collected[i],nolines,anywhere)
        end
    end
end

local function renamespace(root, oldspace, newspace) -- fast variant
    local ndt = #root.dt
    for i=1,ndt or 0 do
        local e = root[i]
        if type(e) == "table" then
            if e.ns == oldspace then
                e.ns = newspace
                if e.rn then
                    e.rn = newspace
                end
            end
            local edt = e.dt
            if edt then
                renamespace(edt, oldspace, newspace)
            end
        end
    end
end

xml.renamespace = renamespace

function xml.remaptag(root, pattern, newtg)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            collected[c].tg = newtg
        end
    end
end

function xml.remapnamespace(root, pattern, newns)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            collected[c].ns = newns
        end
    end
end

function xml.checknamespace(root, pattern, newns)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            if (not e.rn or e.rn == "") and e.ns == "" then
                e.rn = newns
            end
        end
    end
end

function xml.remapname(root, pattern, newtg, newns, newrn)
    local collected = xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            e.tg, e.ns, e.rn = newtg, newns, newrn
        end
    end
end

--[[ldx--
<p>Helper (for q2p).</p>
--ldx]]--

function xml.cdatatotext(e)
    local dt = e.dt
    if #dt == 1 then
        local first = dt[1]
        if first.tg == "@cd@" then
            e.dt = first.dt
        end
    else
        -- maybe option
    end
end

-- local x = xml.convert("<x><a>1<b>2</b>3</a></x>")
-- xml.texttocdata(xml.first(x,"a"))
-- print(x) -- <x><![CDATA[1<b>2</b>3]]></x>

function xml.texttocdata(e) -- could be a finalizer
    local dt = e.dt
    local s = xml.tostring(dt) -- no shortcut?
    e.tg = "@cd@"
    e.special = true
    e.ns = ""
    e.rn = ""
    e.dt = { s }
    e.at = nil
end

-- local x = xml.convert("<x><a>1<b>2</b>3</a></x>")
-- xml.tocdata(xml.first(x,"a"))
-- print(x) -- <x><![CDATA[<a>1<b>2</b>3</a>]]></x>

function xml.elementtocdata(e) -- could be a finalizer
    local dt = e.dt
    local s = xml.tostring(e) -- no shortcut?
    e.tg = "@cd@"
    e.special = true
    e.ns = ""
    e.rn = ""
    e.dt = { s }
    e.at = nil
end

xml.builtinentities = table.tohash { "amp", "quot", "apos", "lt", "gt" } -- used often so share

local entities        = characters and characters.entities or nil
local builtinentities = xml.builtinentities

function xml.addentitiesdoctype(root,option) -- we could also have a 'resolve' i.e. inline hex
    if not entities then
        require("char-ent")
        entities = characters.entities
    end
    if entities and root and root.tg == "@rt@" and root.statistics then
        local list = { }
        local hexify = option == "hexadecimal"
        for k, v in table.sortedhash(root.statistics.entities.names) do
            if not builtinentities[k] then
                local e = entities[k]
                if not e then
                    e = format("[%s]",k)
                elseif hexify then
                    e = format("&#%05X;",utfbyte(k))
                end
                list[#list+1] = format("  <!ENTITY %s %q >",k,e)
            end
        end
        local dt = root.dt
        local n = dt[1].tg == "@pi@" and 2 or 1
        if #list > 0 then
            insert(dt, n, { "\n" })
            insert(dt, n, {
               tg      = "@dt@", -- beware, doctype is unparsed
               dt      = { format("Something [\n%s\n] ",concat(list)) },
               ns      = "",
               special = true,
            })
            insert(dt, n, { "\n\n" })
        else
         -- insert(dt, n, { table.serialize(root.statistics) })
        end
    end
end

-- local str = [==[
-- <?xml version='1.0' standalone='yes' ?>
-- <root>
-- <a>test &nbsp; test &#123; test</a>
-- <b><![CDATA[oeps]]></b>
-- </root>
-- ]==]
--
-- local x = xml.convert(str)
-- xml.addentitiesdoctype(x,"hexadecimal")
-- print(x)

--[[ldx--
<p>Here are a few synonyms.</p>
--ldx]]--

xml.all     = xml.each
xml.insert  = xml.insertafter
xml.inject  = xml.injectafter
xml.after   = xml.insertafter
xml.before  = xml.insertbefore
xml.process = xml.each

-- obsolete

xml.obsolete   = xml.obsolete or { }
local obsolete = xml.obsolete

xml.strip_whitespace           = xml.strip                 obsolete.strip_whitespace      = xml.strip
xml.collect_elements           = xml.collect               obsolete.collect_elements      = xml.collect
xml.delete_element             = xml.delete                obsolete.delete_element        = xml.delete
xml.replace_element            = xml.replace               obsolete.replace_element       = xml.replacet
xml.each_element               = xml.each                  obsolete.each_element          = xml.each
xml.process_elements           = xml.process               obsolete.process_elements      = xml.process
xml.insert_element_after       = xml.insertafter           obsolete.insert_element_after  = xml.insertafter
xml.insert_element_before      = xml.insertbefore          obsolete.insert_element_before = xml.insertbefore
xml.inject_element_after       = xml.injectafter           obsolete.inject_element_after  = xml.injectafter
xml.inject_element_before      = xml.injectbefore          obsolete.inject_element_before = xml.injectbefore
xml.process_attributes         = xml.processattributes     obsolete.process_attributes    = xml.processattributes
xml.collect_texts              = xml.collecttexts          obsolete.collect_texts         = xml.collecttexts
xml.inject_element             = xml.inject                obsolete.inject_element        = xml.inject
xml.remap_tag                  = xml.remaptag              obsolete.remap_tag             = xml.remaptag
xml.remap_name                 = xml.remapname             obsolete.remap_name            = xml.remapname
xml.remap_namespace            = xml.remapnamespace        obsolete.remap_namespace       = xml.remapnamespace

-- new (probably ok)

function xml.cdata(e)
    if e then
        local dt = e.dt
        if dt and #dt == 1 then
            local first = dt[1]
            return first.tg == "@cd@" and first.dt[1] or ""
        end
    end
    return ""
end

function xml.finalizers.xml.cdata(collected)
    if collected then
        local e = collected[1]
        if e then
            local dt = e.dt
            if dt and #dt == 1 then
                local first = dt[1]
                return first.tg == "@cd@" and first.dt[1] or ""
            end
        end
    end
    return ""
end

function xml.insertcomment(e,str,n) -- also insertcdata
    table.insert(e.dt,n or 1,{
        tg      = "@cm@",
        ns      = "",
        special = true,
        at      = { },
        dt      = { str },
    })
end

function xml.setcdata(e,str) -- also setcomment
    e.dt = { {
        tg      = "@cd@",
        ns      = "",
        special = true,
        at      = { },
        dt      = { str },
    } }
end

-- maybe helpers like this will move to an autoloader

function xml.separate(x,pattern)
    local collected = xmlapplylpath(x,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local d = e.dt
            if d == x then
                report_xml("warning: xml.separate changes root")
                x = d
            end
            local t, n = { "\n" }, 1
            local i, nd = 1, #d
            while i <= nd do
                while i <= nd do
                    local di = d[i]
                    if type(di) == "string" then
                        if di == "\n" or find(di,"^%s+$") then -- first test is speedup
                            i = i + 1
                        else
                            d[i] = strip(di)
                            break
                        end
                    else
                        break
                    end
                end
                if i > nd then
                    break
                end
                t[n+1] = "\n"
                t[n+2] = d[i]
                t[n+3] = "\n"
                n = n + 3
                i = i + 1
            end
            t[n+1] = "\n"
            setmetatable(t,getmetatable(d))
            e.dt = t
        end
    end
    return x
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-xml'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local find, lower, upper = string.find, string.lower, string.upper

local xml = xml

local finalizers     = xml.finalizers.xml
local xmlfilter      = xml.filter -- we could inline this one for speed
local xmltostring    = xml.tostring
local xmlserialize   = xml.serialize
local xmlcollected   = xml.collected
local xmlnewhandlers = xml.newhandlers

local function first(collected) -- wrong ?
    return collected and collected[1]
end

local function last(collected)
    return collected and collected[#collected]
end

local function all(collected)
    return collected
end

-- local function reverse(collected)
--     if collected then
--         local nc = #collected
--         if nc > 0 then
--             local reversed, r = { }, 0
--             for c=nc,1,-1 do
--                 r = r + 1
--                 reversed[r] = collected[c]
--             end
--             return reversed
--         else
--             return collected
--         end
--     end
-- end

local reverse = table.reversed

local function attribute(collected,name)
    if collected and #collected > 0 then
        local at = collected[1].at
        return at and at[name]
    end
end

local function att(id,name)
    local at = id.at
    return at and at[name]
end

local function count(collected)
    return collected and #collected or 0
end

local function position(collected,n)
    if not collected then
        return 0
    end
    local nc = #collected
    if nc == 0 then
        return 0
    end
    n = tonumber(n) or 0
    if n < 0 then
        return collected[nc + n + 1]
    elseif n > 0 then
        return collected[n]
    else
        return collected[1].mi or 0
    end
end

local function match(collected)
    return collected and #collected > 0 and collected[1].mi or 0 -- match
end

local function index(collected)
    return collected and #collected > 0 and collected[1].ni or 0 -- 0 is new
end

local function attributes(collected,arguments)
    if collected and #collected > 0 then
        local at = collected[1].at
        if arguments then
            return at[arguments]
        elseif next(at) then
            return at -- all of them
        end
    end
end

local function chainattribute(collected,arguments) -- todo: optional levels
    if collected and #collected > 0 then
        local e = collected[1]
        while e do
            local at = e.at
            if at then
                local a = at[arguments]
                if a then
                    return a
                end
            else
                break -- error
            end
            e = e.__p__
        end
    end
    return ""
end

local function raw(collected) -- hybrid (not much different from text so it might go)
    if collected and #collected > 0 then
        local e = collected[1] or collected
        return e and xmltostring(e) or "" -- only first as we cannot concat function
    else
        return ""
    end
end

--

local xmltexthandler = xmlnewhandlers {
    name       = "string",
    initialize = function()
        result = { }
        return result
    end,
    finalize   = function()
        return concat(result)
    end,
    handle     = function(...)
        result[#result+1] = concat { ... }
    end,
    escape     = false,
}

local function xmltotext(root)
    local dt = root.dt
    if not dt then
        return ""
    end
    local nt = #dt -- string or table
    if nt == 0 then
        return ""
    elseif nt == 1 and type(dt[1]) == "string" then
        return dt[1] -- no escaping of " ' < > &
    else
        return xmlserialize(root,xmltexthandler) or ""
    end
end

--

local function text(collected) -- hybrid
    if collected then -- no # test here !
        local e = collected[1] or collected -- why fallback to element, how about cdata
        return e and xmltotext(e) or ""
    else
        return ""
    end
end

local function texts(collected)
    if not collected then
        return { } -- why no nil
    end
    local nc = #collected
    if nc == 0 then
        return { } -- why no nil
    end
    local t, n = { }, 0
    for c=1,nc do
        local e = collected[c]
        if e and e.dt then
            n = n + 1
            t[n] = e.dt
        end
    end
    return t
end

local function tag(collected,n)
    if not collected then
        return
    end
    local nc = #collected
    if nc == 0 then
        return
    end
    local c
    if n == 0 or not n then
        c = collected[1]
    elseif n > 1 then
        c = collected[n]
    else
        c = collected[nc-n+1]
    end
    return c and c.tg
end

local function name(collected,n)
    if not collected then
        return
    end
    local nc = #collected
    if nc == 0 then
        return
    end
    local c
    if n == 0 or not n then
        c = collected[1]
    elseif n > 1 then
        c = collected[n]
    else
        c = collected[nc-n+1]
    end
    if not c then
        -- sorry
    elseif c.ns == "" then
        return c.tg
    else
        return c.ns .. ":" .. c.tg
    end
end

local function tags(collected,nonamespace)
    if not collected then
        return
    end
    local nc = #collected
    if nc == 0 then
        return
    end
    local t, n = { }, 0
    for c=1,nc do
        local e = collected[c]
        local ns, tg = e.ns, e.tg
        n = n + 1
        if nonamespace or ns == "" then
            t[n] = tg
        else
            t[n] = ns .. ":" .. tg
        end
    end
    return t
end

local function empty(collected,spacesonly)
    if not collected then
        return true
    end
    local nc = #collected
    if nc == 0 then
        return true
    end
    for c=1,nc do
        local e = collected[c]
        if e then
            local edt = e.dt
            if edt then
                local n = #edt
                if n == 1 then
                    local edk = edt[1]
                    local typ = type(edk)
                    if typ == "table" then
                        return false
                    elseif edk ~= "" then
                        return false
                    elseif spacesonly and not find(edk,"%S") then
                        return false
                    end
                elseif n > 1 then
                    return false
                end
            end
        end
    end
    return true
end

finalizers.first          = first
finalizers.last           = last
finalizers.all            = all
finalizers.reverse        = reverse
finalizers.elements       = all
finalizers.default        = all
finalizers.attribute      = attribute
finalizers.att            = att
finalizers.count          = count
finalizers.position       = position
finalizers.match          = match
finalizers.index          = index
finalizers.attributes     = attributes
finalizers.chainattribute = chainattribute
finalizers.text           = text
finalizers.texts          = texts
finalizers.tag            = tag
finalizers.name           = name
finalizers.tags           = tags
finalizers.empty          = empty

-- shortcuts -- we could support xmlfilter(id,pattern,first)

function xml.first(id,pattern)
    return first(xmlfilter(id,pattern))
end

function xml.last(id,pattern)
    return last(xmlfilter(id,pattern))
end

function xml.count(id,pattern)
    return count(xmlfilter(id,pattern))
end

function xml.attribute(id,pattern,a,default)
    return attribute(xmlfilter(id,pattern),a,default)
end

function xml.raw(id,pattern)
    if pattern then
        return raw(xmlfilter(id,pattern))
    else
        return raw(id)
    end
end

function xml.text(id,pattern) -- brrr either content or element (when cdata)
    if pattern then
     -- return text(xmlfilter(id,pattern))
        local collected = xmlfilter(id,pattern)
        return collected and #collected > 0 and xmltotext(collected[1]) or ""
    elseif id then
     -- return text(id)
        return xmltotext(id) or ""
    else
        return ""
    end
end

xml.content = text

--

function xml.position(id,pattern,n) -- element
    return position(xmlfilter(id,pattern),n)
end

function xml.match(id,pattern) -- number
    return match(xmlfilter(id,pattern))
end

function xml.empty(id,pattern,spacesonly)
    return empty(xmlfilter(id,pattern),spacesonly)
end

xml.all    = xml.filter
xml.index  = xml.position
xml.found  = xml.filter

-- a nice one:

local function totable(x)
    local t = { }
    for e in xmlcollected(x[1] or x,"/*") do
        t[e.tg] = xmltostring(e.dt) or ""
    end
    return next(t) and t or nil
end

xml.table        = totable
finalizers.table = totable

local function textonly(e,t)
    if e then
        local edt = e.dt
        if edt then
            for i=1,#edt do
                local e = edt[i]
                if type(e) == "table" then
                    textonly(e,t)
                else
                    t[#t+1] = e
                end
            end
        end
    end
    return t
end

function xml.textonly(e) -- no pattern
    return concat(textonly(e,{}))
end

--

-- local x = xml.convert("<x><a x='+'>1<B>2</B>3</a></x>")
-- xml.filter(x,"**/lowerall()") print(x)
-- xml.filter(x,"**/upperall()") print(x)

function finalizers.lowerall(collected)
    for c=1,#collected do
        local e = collected[c]
        if not e.special then
            e.tg = lower(e.tg)
            local eat = e.at
            if eat then
                local t = { }
                for k,v in next, eat do
                    t[lower(k)] = v
                end
                e.at = t
            end
        end
    end
end

function finalizers.upperall(collected)
    for c=1,#collected do
        local e = collected[c]
        if not e.special then
            e.tg = upper(e.tg)
            local eat = e.at
            if eat then
                local t = { }
                for k,v in next, eat do
                    t[upper(k)] = v
                end
                e.at = t
            end
        end
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local gsub, find, gmatch, char = string.gsub, string.find, string.gmatch, string.char
local concat = table.concat
local next, type = next, type

local filedirname, filebasename, fileextname, filejoin = file.dirname, file.basename, file.extname, file.join

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_detail     = false  trackers.register("resolvers.details",    function(v) trace_detail     = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)

local report_initialization = logs.reporter("resolvers","initialization")

local ostype, osname, ossetenv, osgetenv = os.type, os.name, os.setenv, os.getenv

-- The code here used to be part of a data-res but for convenience
-- we now split it over multiple files. As this file is now the
-- starting point we introduce resolvers here.

resolvers       = resolvers or { }
local resolvers = resolvers

-- We don't want the kpse library to kick in. Also, we want to be able to
-- execute programs. Control over execution is implemented later.

texconfig.kpse_init    = false
texconfig.shell_escape = 't'

if kpse and kpse.default_texmfcnf then
    local default_texmfcnf = kpse.default_texmfcnf()
    -- looks more like context:
    default_texmfcnf = gsub(default_texmfcnf,"$SELFAUTOLOC","selfautoloc:")
    default_texmfcnf = gsub(default_texmfcnf,"$SELFAUTODIR","selfautodir:")
    default_texmfcnf = gsub(default_texmfcnf,"$SELFAUTOPARENT","selfautoparent:")
    default_texmfcnf = gsub(default_texmfcnf,"$HOME","home:")
    --
    environment.default_texmfcnf = default_texmfcnf
end

kpse = { original = kpse }

setmetatable(kpse, {
    __index = function(kp,name)
        report_initialization("fatal error: kpse library is accessed (key: %s)",name)
        os.exit()
    end
} )

-- First we check a couple of environment variables. Some might be
-- set already but we need then later on. We start with the system
-- font path.

do

    local osfontdir = osgetenv("OSFONTDIR")

    if osfontdir and osfontdir ~= "" then
        -- ok
    elseif osname == "windows" then
        ossetenv("OSFONTDIR","c:/windows/fonts//")
    elseif osname == "macosx" then
        ossetenv("OSFONTDIR","$HOME/Library/Fonts//;/Library/Fonts//;/System/Library/Fonts//")
    end

end

-- Next comes the user's home path. We need this as later on we have
-- to replace ~ with its value.

do

    local homedir = osgetenv(ostype == "windows" and 'USERPROFILE' or 'HOME') or ''

    if not homedir or homedir == "" then
        homedir = char(127) -- we need a value, later we wil trigger on it
    end

    homedir = file.collapsepath(homedir)

    ossetenv("HOME",       homedir) -- can be used in unix cnf files
    ossetenv("USERPROFILE",homedir) -- can be used in windows cnf files

    environment.homedir = homedir

end

-- The following code sets the name of the own binary and its
-- path. This is fallback code as we have os.selfdir now.

do

    local args = environment.originalarguments or arg -- this needs a cleanup

    local ownbin  = environment.ownbin  or args[-2] or arg[-2] or args[-1] or arg[-1] or arg[0] or "luatex"
    local ownpath = environment.ownpath or os.selfdir

    ownbin  = file.collapsepath(ownbin)
    ownpath = file.collapsepath(ownpath)

    if not ownpath or ownpath == "" or ownpath == "unset" then
        ownpath = args[-1] or arg[-1]
        ownpath = ownpath and filedirname(gsub(ownpath,"\\","/"))
        if not ownpath or ownpath == "" then
            ownpath = args[-0] or arg[-0]
            ownpath = ownpath and filedirname(gsub(ownpath,"\\","/"))
        end
        local binary = ownbin
        if not ownpath or ownpath == "" then
            ownpath = ownpath and filedirname(binary)
        end
        if not ownpath or ownpath == "" then
            if os.binsuffix ~= "" then
                binary = file.replacesuffix(binary,os.binsuffix)
            end
            local path = osgetenv("PATH")
            if path then
                for p in gmatch(path,"[^"..io.pathseparator.."]+") do
                    local b = filejoin(p,binary)
                    if lfs.isfile(b) then
                        -- we assume that after changing to the path the currentdir function
                        -- resolves to the real location and use this side effect here; this
                        -- trick is needed because on the mac installations use symlinks in the
                        -- path instead of real locations
                        local olddir = lfs.currentdir()
                        if lfs.chdir(p) then
                            local pp = lfs.currentdir()
                            if trace_locating and p ~= pp then
                                report_initialization("following symlink '%s' to '%s'",p,pp)
                            end
                            ownpath = pp
                            lfs.chdir(olddir)
                        else
                            if trace_locating then
                                report_initialization("unable to check path '%s'",p)
                            end
                            ownpath =  p
                        end
                        break
                    end
                end
            end
        end
        if not ownpath or ownpath == "" then
            ownpath = "."
            report_initialization("forcing fallback ownpath .")
        elseif trace_locating then
            report_initialization("using ownpath '%s'",ownpath)
        end
    end

    environment.ownbin  = ownbin
    environment.ownpath = ownpath

end

resolvers.ownpath = environment.ownpath

function resolvers.getownpath()
    return environment.ownpath
end

-- The self variables permit us to use only a few (or even no)
-- environment variables.

do

    local ownpath = environment.ownpath or dir.current()

    if ownpath then
        ossetenv('SELFAUTOLOC',    file.collapsepath(ownpath))
        ossetenv('SELFAUTODIR',    file.collapsepath(ownpath .. "/.."))
        ossetenv('SELFAUTOPARENT', file.collapsepath(ownpath .. "/../.."))
    else
        report_initialization("error: unable to locate ownpath")
        os.exit()
    end

end

-- The running os:

-- todo: check is context sits here os.platform is more trustworthy
-- that the bin check as mtx-update runs from another path

local texos   = environment.texos   or osgetenv("TEXOS")
local texmfos = environment.texmfos or osgetenv('SELFAUTODIR')

if not texos or texos == "" then
    texos = file.basename(texmfos)
end

ossetenv('TEXMFOS',       texmfos)      -- full bin path
ossetenv('TEXOS',         texos)        -- partial bin parent
ossetenv('SELFAUTOSYSTEM',os.platform)  -- bonus

environment.texos   = texos
environment.texmfos = texmfos

-- The current root:

local texroot = environment.texroot or osgetenv("TEXROOT")

if not texroot or texroot == "" then
    texroot = osgetenv('SELFAUTOPARENT')
    ossetenv('TEXROOT',texroot)
end

environment.texroot = file.collapsepath(texroot)

-- Tracing. Todo ...

function resolvers.settrace(n) -- no longer number but: 'locating' or 'detail'
    if n then
        trackers.disable("resolvers.*")
        trackers.enable("resolvers."..n)
    end
end

resolvers.settrace(osgetenv("MTX_INPUT_TRACE"))

-- todo:

-- if profiler and osgetenv("MTX_PROFILE_RUN") == "YES" then
--     profiler.start("luatex-profile.log")
-- end

-- a forward definition

if not resolvers.resolve then
    function resolvers.resolve  (s) return s end
    function resolvers.unresolve(s) return s end
    function resolvers.repath   (s) return s end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-exp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, find, gmatch, lower, char, sub = string.format, string.find, string.gmatch, string.lower, string.char, string.sub
local concat, sort = table.concat, table.sort
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local Ct, Cs, Cc, P, C, S = lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.P, lpeg.C, lpeg.S
local type, next = type, next

local ostype = os.type
local collapsepath = file.collapsepath

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)

local report_expansions = logs.reporter("resolvers","expansions")

local resolvers = resolvers

-- As this bit of code is somewhat special it gets its own module. After
-- all, when working on the main resolver code, I don't want to scroll
-- past this every time. See data-obs.lua for the gsub variant.

local function f_first(a,b)
    local t, n = { }, 0
    for s in gmatch(b,"[^,]+") do
        n = n + 1 ; t[n] = a .. s
    end
    return concat(t,",")
end

local function f_second(a,b)
    local t, n = { }, 0
    for s in gmatch(a,"[^,]+") do
        n = n + 1 ; t[n] = s .. b
    end
    return concat(t,",")
end

-- kpsewhich --expand-braces '{a,b}{c,d}'
-- ac:bc:ad:bd

-- old  {a,b}{c,d} => ac ad bc bd
--
-- local function f_both(a,b)
--     local t, n = { }, 0
--     for sa in gmatch(a,"[^,]+") do
--         for sb in gmatch(b,"[^,]+") do
--             n = n + 1 ; t[n] = sa .. sb
--         end
--     end
--     return concat(t,",")
-- end
--
-- new  {a,b}{c,d} => ac bc ad bd

local function f_both(a,b)
    local t, n = { }, 0
    for sb in gmatch(b,"[^,]+") do              -- and not sa
        for sa in gmatch(a,"[^,]+") do          --         sb
            n = n + 1 ; t[n] = sa .. sb
        end
    end
    return concat(t,",")
end

local left  = P("{")
local right = P("}")
local var   = P((1 - S("{}" ))^0)
local set   = P((1 - S("{},"))^0)
local other = P(1)

local l_first  = Cs( ( Cc("{") * (C(set) * left * C(var) * right / f_first) * Cc("}")               + other )^0 )
local l_second = Cs( ( Cc("{") * (left * C(var) * right * C(set) / f_second) * Cc("}")              + other )^0 )
local l_both   = Cs( ( Cc("{") * (left * C(var) * right * left * C(var) * right / f_both) * Cc("}") + other )^0 )
local l_rest   = Cs( ( left * var * (left/"") * var * (right/"") * var * right                      + other )^0 )

local stripper_1 = lpeg.stripper ("{}@")
local replacer_1 = lpeg.replacer { { ",}", ",@}" }, { "{,", "{@," }, }

local function splitpathexpr(str, newlist, validate) -- I couldn't resist lpegging it (nice exercise).
    if trace_expansions then
        report_expansions("expanding variable '%s'",str)
    end
    local t, ok, done = newlist or { }, false, false
    local n = #t
    str = lpegmatch(replacer_1,str)
    repeat
        local old = str
        repeat
            local old = str
            str = lpegmatch(l_first, str)
        until old == str
        repeat
            local old = str
            str = lpegmatch(l_second,str)
        until old == str
        repeat
            local old = str
            str = lpegmatch(l_both,  str)
        until old == str
        repeat
            local old = str
            str = lpegmatch(l_rest,  str)
        until old == str
    until old == str -- or not find(str,"{")
    str = lpegmatch(stripper_1,str)
    if validate then
        for s in gmatch(str,"[^,]+") do
            s = validate(s)
            if s then
                n = n + 1 ; t[n] = s
            end
        end
    else
        for s in gmatch(str,"[^,]+") do
            n = n + 1 ; t[n] = s
        end
    end
    if trace_expansions then
        for k=1,#t do
            report_expansions("% 4i: %s",k,t[k])
        end
    end
    return t
end

-- We could make the previous one public.

local function validate(s)
    s = collapsepath(s) -- already keeps the //
    return s ~= "" and not find(s,"^!*unset/*$") and s
end

resolvers.validatedpath = validate -- keeps the trailing //

function resolvers.expandedpathfromlist(pathlist)
    local newlist = { }
    for k=1,#pathlist do
        splitpathexpr(pathlist[k],newlist,validate)
    end
    return newlist
end

-- {a,b,c,d}
-- a,b,c/{p,q,r},d
-- a,b,c/{p,q,r}/d/{x,y,z}//
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a{b,c}{d,e}f
-- {a,b,c,d}
-- {a,b,c/{p,q,r},d}
-- {a,b,c/{p,q,r}/d/{x,y,z}//}
-- {a,b,c/{p,q/{x,y,z}},d/{p,q,r}}
-- {a,b,c/{p,q/{x,y,z},w}v,d/{p,q,r}}
-- {$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}

local cleanup = lpeg.replacer {
    { "!"  , ""  },
    { "\\" , "/" },
}

function resolvers.cleanpath(str) -- tricky, maybe only simple paths
    local doslashes  = (P("\\")/"/" + 1)^0
    local donegation = (P("!") /""     )^0
    local homedir = lpegmatch(Cs(donegation * doslashes),environment.homedir or "")
    if homedir == "~" or homedir == "" or not lfs.isdir(homedir) then
        if trace_expansions then
            report_expansions("no home dir set, ignoring dependent paths")
        end
        function resolvers.cleanpath(str)
            if not str or find(str,"~") then
                return "" -- special case
            else
                return lpegmatch(cleanup,str)
            end
        end
    else
        local dohome  = ((P("~")+P("$HOME"))/homedir)^0
        local cleanup = Cs(donegation * dohome * doslashes)
        function resolvers.cleanpath(str)
            return str and lpegmatch(cleanup,str) or ""
        end
    end
    return resolvers.cleanpath(str)
end

-- print(resolvers.cleanpath(""))
-- print(resolvers.cleanpath("!"))
-- print(resolvers.cleanpath("~"))
-- print(resolvers.cleanpath("~/test"))
-- print(resolvers.cleanpath("!~/test"))
-- print(resolvers.cleanpath("~/test~test"))

-- This one strips quotes and funny tokens.

local expandhome = P("~") / "$HOME" -- environment.homedir

local dodouble = P('"')/"" * (expandhome + (1 - P('"')))^0 * P('"')/""
local dosingle = P("'")/"" * (expandhome + (1 - P("'")))^0 * P("'")/""
local dostring =             (expandhome +  1              )^0

local stripper = Cs(
    lpegpatterns.unspacer * (dosingle + dodouble + dostring) * lpegpatterns.unspacer
)

function resolvers.checkedvariable(str) -- assumes str is a string
    return type(str) == "string" and lpegmatch(stripper,str) or str
end

-- The path splitter:

-- A config (optionally) has the paths split in tables. Internally
-- we join them and split them after the expansion has taken place. This
-- is more convenient.

local cache = { }

----- splitter = lpeg.tsplitat(S(ostype == "windows" and ";" or ":;")) -- maybe add ,
local splitter = lpeg.tsplitat(";") -- as we move towards urls, prefixes and use tables we no longer do :

local backslashswapper = lpeg.replacer("\\","/")

local function splitconfigurationpath(str) -- beware, this can be either a path or a { specification }
    if str then
        local found = cache[str]
        if not found then
            if str == "" then
                found = { }
            else
                local split = lpegmatch(splitter,lpegmatch(backslashswapper,str)) -- can be combined
                found = { }
                local noffound = 0
                for i=1,#split do
                    local s = split[i]
                    if not find(s,"^{*unset}*") then
                        noffound = noffound + 1
                        found[noffound] = s
                    end
                end
                if trace_expansions then
                    report_expansions("splitting path specification '%s'",str)
                    for k=1,noffound do
                        report_expansions("% 4i: %s",k,found[k])
                    end
                end
                cache[str] = found
            end
        end
        return found
    end
end

resolvers.splitconfigurationpath = splitconfigurationpath

function resolvers.splitpath(str)
    if type(str) == 'table' then
        return str
    else
        return splitconfigurationpath(str)
    end
end

function resolvers.joinpath(str)
    if type(str) == 'table' then
        return file.joinpath(str)
    else
        return str
    end
end

-- The next function scans directories and returns a hash where the
-- entries are either strings or tables.

-- starting with . or .. etc or funny char




-- a lot of this caching can be stripped away when we have ssd's everywhere
--
-- we could cache all the (sub)paths here if needed

local attributes, directory = lfs.attributes, lfs.dir

local weird     = P(".")^1 + lpeg.anywhere(S("~`!#$%^&*()={}[]:;\"\'||<>,?\n\r\t"))
local timer     = { }
local scanned   = { }
local nofscans  = 0
local scancache = { }

local function scan(files,spec,path,n,m,r)
    local full    = (path == "" and spec) or (spec .. path .. '/')
    local dirs    = { }
    local nofdirs = 0
    for name in directory(full) do
        if not lpegmatch(weird,name) then
            local mode = attributes(full..name,'mode')
            if mode == 'file' then
                n = n + 1
                local f = files[name]
                if f then
                    if type(f) == 'string' then
                        files[name] = { f, path }
                    else
                        f[#f+1] = path
                    end
                else -- probably unique anyway
                    files[name] = path
                    local lower = lower(name)
                    if name ~= lower then
                        files["remap:"..lower] = name
                        r = r + 1
                    end
                end
            elseif mode == 'directory' then
                m = m + 1
                nofdirs = nofdirs + 1
                if path ~= "" then
                    dirs[nofdirs] = path..'/'..name
                else
                    dirs[nofdirs] = name
                end
            end
        end
    end
    if nofdirs > 0 then
        sort(dirs)
        for i=1,nofdirs do
            files, n, m, r = scan(files,spec,dirs[i],n,m,r)
        end
    end
    scancache[sub(full,1,-2)] = files
    return files, n, m, r
end

local fullcache = { }

function resolvers.scanfiles(path,branch,usecache)
    statistics.starttiming(timer)
    local realpath = resolvers.resolve(path) -- no shortcut
    if usecache then
        local files = fullcache[realpath]
        if files then
            if trace_locating then
                report_expansions("using caches scan of path '%s', branch '%s'",path,branch or path)
            end
            return files
        end
    end
    if trace_locating then
        report_expansions("scanning path '%s', branch '%s'",path,branch or path)
    end
    local files, n, m, r = scan({ },realpath .. '/',"",0,0,0)
    files.__path__        = path -- can be selfautoparent:texmf-whatever
    files.__files__       = n
    files.__directories__ = m
    files.__remappings__  = r
    if trace_locating then
        report_expansions("%s files found on %s directories with %s uppercase remappings",n,m,r)
    end
    if usecache then
        scanned[#scanned+1] = realpath
        fullcache[realpath] = files
    end
    nofscans = nofscans + 1
    statistics.stoptiming(timer)
    return files
end

local function simplescan(files,spec,path) -- first match only, no map and such
    local full    = (path == "" and spec) or (spec .. path .. '/')
    local dirs    = { }
    local nofdirs = 0
    for name in directory(full) do
        if not lpegmatch(weird,name) then
            local mode = attributes(full..name,'mode')
            if mode == 'file' then
                if not files[name] then
                    -- only first match
                    files[name] = path
                end
            elseif mode == 'directory' then
                nofdirs = nofdirs + 1
                if path ~= "" then
                    dirs[nofdirs] = path..'/'..name
                else
                    dirs[nofdirs] = name
                end
            end
        end
    end
    if nofdirs > 0 then
        sort(dirs)
        for i=1,nofdirs do
            files = simplescan(files,spec,dirs[i])
        end
    end
    return files
end

local simplecache    = { }
local nofsharedscans = 0

function resolvers.simplescanfiles(path,branch,usecache)
    statistics.starttiming(timer)
    local realpath = resolvers.resolve(path) -- no shortcut
    if usecache then
        local files = simplecache[realpath]
        if not files then
            files = scancache[realpath]
            if files then
                nofsharedscans = nofsharedscans + 1
            end
        end
        if files then
            if trace_locating then
                report_expansions("using caches scan of path '%s', branch '%s'",path,branch or path)
            end
            return files
        end
    end
    if trace_locating then
        report_expansions("scanning path '%s', branch '%s'",path,branch or path)
    end
    local files = simplescan({ },realpath .. '/',"")
    if trace_locating then
        report_expansions("%s files found",table.count(files))
    end
    if usecache then
        scanned[#scanned+1] = realpath
        simplecache[realpath] = files
    end
    nofscans = nofscans + 1
    statistics.stoptiming(timer)
    return files
end

function resolvers.scandata()
    table.sort(scanned)
    return {
        n      = nofscans,
        shared = nofsharedscans,
        time   = statistics.elapsedtime(timer),
        paths  = scanned,
    }
end



end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-env'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lower, gsub = string.lower, string.gsub

local resolvers = resolvers

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local fileextname       = file.extname

local formats           = allocate()
local suffixes          = allocate()
local dangerous         = allocate()
local suffixmap         = allocate()

resolvers.formats       = formats
resolvers.suffixes      = suffixes
resolvers.dangerous     = dangerous
resolvers.suffixmap     = suffixmap

local relations = allocate { -- todo: handlers also here
    core = {
        ofm = { -- will become obsolete
            names    = { "ofm", "omega font metric", "omega font metrics" },
            variable = 'OFMFONTS',
            suffixes = { 'ofm', 'tfm' },
        },
        ovf = { -- will become obsolete
            names    = { "ovf", "omega virtual font", "omega virtual fonts" },
            variable = 'OVFFONTS',
            suffixes = { 'ovf', 'vf' },
        },
        tfm = {
            names    = { "tfm", "tex font metric", "tex font metrics" },
            variable = 'TFMFONTS',
            suffixes = { 'tfm' },
        },
        vf = {
            names    = { "vf", "virtual font", "virtual fonts" },
            variable = 'VFFONTS',
            suffixes = { 'vf' },
        },
        otf = {
            names    = { "otf", "opentype", "opentype font", "opentype fonts"},
            variable = 'OPENTYPEFONTS',
            suffixes = { 'otf' },
        },
        ttf = {
            names    = { "ttf", "truetype", "truetype font", "truetype fonts", "truetype collection", "truetype collections", "truetype dictionary", "truetype dictionaries" },
            variable = 'TTFONTS',
            suffixes = { 'ttf', 'ttc', 'dfont' },
        },
        afm = {
            names    = { "afm", "adobe font metric", "adobe font metrics" },
            variable = "AFMFONTS",
            suffixes = { "afm" },
        },
        pfb = {
            names    = { "pfb", "type1", "type 1", "type1 font", "type 1 font", "type1 fonts", "type 1 fonts" },
            variable = 'T1FONTS',
            suffixes = { 'pfb', 'pfa' },
        },
        fea = {
            names    = { "fea", "font feature", "font features", "font feature file", "font feature files" },
            variable = 'FONTFEATURES',
            suffixes = { 'fea' },
        },
        cid = {
            names    = { "cid", "cid map", "cid maps", "cid file", "cid files" },
            variable = 'FONTCIDMAPS',
            suffixes = { 'cid', 'cidmap' },
        },
        fmt = {
            names    = { "fmt", "format", "tex format" },
            variable = 'TEXFORMATS',
            suffixes = { 'fmt' },
        },
        mem = { -- will become obsolete
            names    = { 'mem', "metapost format" },
            variable = 'MPMEMS',
            suffixes = { 'mem' },
        },
        mp = {
            names    = { "mp" },
            variable = 'MPINPUTS',
            suffixes = { 'mp', 'mpvi', 'mpiv', 'mpii' },
        },
        tex = {
            names    = { "tex" },
            variable = 'TEXINPUTS',
            suffixes = { 'tex', "mkvi", "mkiv", "mkii" },
        },
        icc = {
            names    = { "icc", "icc profile", "icc profiles" },
            variable = 'ICCPROFILES',
            suffixes = { 'icc' },
        },
        texmfscripts = {
            names    = { "texmfscript", "texmfscripts", "script", "scripts" },
            variable = 'TEXMFSCRIPTS',
            suffixes = { 'rb', 'pl', 'py' },
        },
        lua = {
            names    = { "lua" },
            variable = 'LUAINPUTS',
            suffixes = { 'lua', 'luc', 'tma', 'tmc' },
        },
        lib = {
            names    = { "lib" },
            variable = 'CLUAINPUTS',
            suffixes = os.libsuffix and { os.libsuffix } or { 'dll', 'so' },
        },
        bib = {
            names    = { 'bib' },
            suffixes = { 'bib' },
        },
        bst = {
            names    = { 'bst' },
            suffixes = { 'bst' },
        },
        fontconfig = {
            names    = { 'fontconfig', 'fontconfig file', 'fontconfig files' },
            variable = 'FONTCONFIG_PATH',
        },
    },
    obsolete = {
        enc = {
            names    = { "enc", "enc files", "enc file", "encoding files", "encoding file" },
            variable = 'ENCFONTS',
            suffixes = { 'enc' },
        },
        map = {
            names    = { "map", "map files", "map file" },
            variable = 'TEXFONTMAPS',
            suffixes = { 'map' },
        },
        lig = {
            names    = { "lig files", "lig file", "ligature file", "ligature files" },
            variable = 'LIGFONTS',
            suffixes = { 'lig' },
        },
        opl = {
            names    = { "opl" },
            variable = 'OPLFONTS',
            suffixes = { 'opl' },
        },
        ovp = {
            names    = { "ovp" },
            variable = 'OVPFONTS',
            suffixes = { 'ovp' },
        },
    },
    kpse = { -- subset
        base = {
            names    = { 'base', "metafont format" },
            variable = 'MFBASES',
            suffixes = { 'base', 'bas' },
        },
        cmap = {
            names    = { 'cmap', 'cmap files', 'cmap file' },
            variable = 'CMAPFONTS',
            suffixes = { 'cmap' },
        },
        cnf = {
            names    = { 'cnf' },
            suffixes = { 'cnf' },
        },
        web = {
            names    = { 'web' },
            suffixes = { 'web', 'ch' }
        },
        cweb = {
            names    = { 'cweb' },
            suffixes = { 'w', 'web', 'ch' },
        },
        gf = {
            names    = { 'gf' },
            suffixes = { '<resolution>gf' },
        },
        mf = {
            names    = { 'mf' },
            variable = 'MFINPUTS',
            suffixes = { 'mf' },
        },
        mft = {
            names    = { 'mft' },
            suffixes = { 'mft' },
        },
        pk = {
            names    = { 'pk' },
            suffixes = { '<resolution>pk' },
        },
    },
}

resolvers.relations = relations

-- formats: maps a format onto a variable

function resolvers.updaterelations()
    for category, categories in next, relations do
        for name, relation in next, categories do
            local rn = relation.names
            local rv = relation.variable
            local rs = relation.suffixes
            if rn and rv then
                for i=1,#rn do
                    local rni = lower(gsub(rn[i]," ",""))
                    formats[rni] = rv
                    if rs then
                        suffixes[rni] = rs
                        for i=1,#rs do
                            local rsi = rs[i]
                            suffixmap[rsi] = rni
                        end
                    end
                end
            end
            if rs then
            end
        end
    end
end

resolvers.updaterelations() -- push this in the metatable -> newindex

local function simplified(t,k)
    return k and rawget(t,lower(gsub(k," ",""))) or nil
end

setmetatableindex(formats,   simplified)
setmetatableindex(suffixes,  simplified)
setmetatableindex(suffixmap, simplified)

-- A few accessors, mostly for command line tool.

function resolvers.suffixofformat(str)
    local s = suffixes[str]
    return s and s[1] or ""
end

function resolvers.suffixofformat(str)
    return suffixes[str] or { }
end

for name, format in next, formats do
    dangerous[name] = true -- still needed ?
end

-- because vf searching is somewhat dangerous, we want to prevent
-- too liberal searching esp because we do a lookup on the current
-- path anyway; only tex (or any) is safe

dangerous.tex = nil


-- more helpers

function resolvers.formatofvariable(str)
    return formats[str] or ''
end

function resolvers.formatofsuffix(str) -- of file
    return suffixmap[fileextname(str)] or 'tex' -- so many map onto tex (like mkiv, cld etc)
end

function resolvers.variableofformat(str)
    return formats[str] or ''
end

function resolvers.variableofformatorsuffix(str)
    local v = formats[str]
    if v then
        return v
    end
    v = suffixmap[fileextname(str)]
    if v then
        return formats[v]
    end
    return ''
end



end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-tmp'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module deals with caching data. It sets up the paths and
implements loaders and savers for tables. Best is to set the
following variable. When not set, the usual paths will be
checked. Personally I prefer the (users) temporary path.</p>

</code>
TEXMFCACHE=$TMP;$TEMP;$TMPDIR;$TEMPDIR;$HOME;$TEXMFVAR;$VARTEXMF;.
</code>

<p>Currently we do no locking when we write files. This is no real
problem because most caching involves fonts and the chance of them
being written at the same time is small. We also need to extend
luatools with a recache feature.</p>
--ldx]]--

local format, lower, gsub, concat = string.format, string.lower, string.gsub, table.concat
local serialize, serializetofile = table.serialize, table.tofile
local mkdirs, isdir = dir.mkdirs, lfs.isdir

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)
local trace_cache    = false  trackers.register("resolvers.cache",    function(v) trace_cache    = v end)

local report_caches    = logs.reporter("resolvers","caches")
local report_resolvers = logs.reporter("resolvers","caching")

local resolvers = resolvers

-- intermezzo

local directive_cleanup = false  directives.register("system.compile.cleanup", function(v) directive_cleanup = v end)
local directive_strip   = true   directives.register("system.compile.strip",   function(v) directive_strip   = v end)

local compile = utilities.lua.compile

function utilities.lua.compile(luafile,lucfile,cleanup,strip)
    if cleanup == nil then cleanup = directive_cleanup end
    if strip   == nil then strip   = directive_strip   end
    return compile(luafile,lucfile,cleanup,strip)
end

-- end of intermezzo

caches          = caches or { }
local caches    = caches

caches.base     = caches.base or "luatex-cache"
caches.more     = caches.more or "context"
caches.direct   = false -- true is faster but may need huge amounts of memory
caches.tree     = false
caches.force    = true
caches.ask      = false
caches.relocate = false
caches.defaults = { "TMPDIR", "TEMPDIR", "TMP", "TEMP", "HOME", "HOMEPATH" }

local writable, readables, usedreadables = nil, { }, { }

-- we could use a metatable for writable and readable but not yet

local function identify()
    -- Combining the loops makes it messy. First we check the format cache path
    -- and when the last component is not present we try to create it.
    local texmfcaches = resolvers.cleanpathlist("TEXMFCACHE")
    if texmfcaches then
        for k=1,#texmfcaches do
            local cachepath = texmfcaches[k]
            if cachepath ~= "" then
                cachepath = resolvers.resolve(cachepath)
                cachepath = resolvers.cleanpath(cachepath)
                cachepath = file.collapsepath(cachepath)
                local valid = isdir(cachepath)
                if valid then
                    if file.is_readable(cachepath) then
                        readables[#readables+1] = cachepath
                        if not writable and file.is_writable(cachepath) then
                            writable = cachepath
                        end
                    end
                elseif not writable and caches.force then
                    local cacheparent = file.dirname(cachepath)
                    if file.is_writable(cacheparent) and true then -- we go on anyway (needed for mojca's kind of paths)
                        if not caches.ask or io.ask(format("\nShould I create the cache path %s?",cachepath), "no", { "yes", "no" }) == "yes" then
                            mkdirs(cachepath)
                            if isdir(cachepath) and file.is_writable(cachepath) then
                                report_caches("created: %s",cachepath)
                                writable = cachepath
                                readables[#readables+1] = cachepath
                            end
                        end
                    end
                end
            end
        end
    end
    -- As a last resort we check some temporary paths but this time we don't
    -- create them.
    local texmfcaches = caches.defaults
    if texmfcaches then
        for k=1,#texmfcaches do
            local cachepath = texmfcaches[k]
            cachepath = resolvers.expansion(cachepath) -- was getenv
            if cachepath ~= "" then
                cachepath = resolvers.resolve(cachepath)
                cachepath = resolvers.cleanpath(cachepath)
                local valid = isdir(cachepath)
                if valid and file.is_readable(cachepath) then
                    if not writable and file.is_writable(cachepath) then
                        readables[#readables+1] = cachepath
                        writable = cachepath
                        break
                    end
                end
            end
        end
    end
    -- Some extra checking. If we have no writable or readable path then we simply
    -- quit.
    if not writable then
        report_caches("fatal error: there is no valid writable cache path defined")
        os.exit()
    elseif #readables == 0 then
        report_caches("fatal error: there is no valid readable cache path defined")
        os.exit()
    end
    -- why here
    writable = dir.expandname(resolvers.cleanpath(writable)) -- just in case
    -- moved here
    local base, more, tree = caches.base, caches.more, caches.tree or caches.treehash() -- we have only one writable tree
    if tree then
        caches.tree = tree
        writable = mkdirs(writable,base,more,tree)
        for i=1,#readables do
            readables[i] = file.join(readables[i],base,more,tree)
        end
    else
        writable = mkdirs(writable,base,more)
        for i=1,#readables do
            readables[i] = file.join(readables[i],base,more)
        end
    end
    -- end
    if trace_cache then
        for i=1,#readables do
            report_caches("using readable path '%s' (order %s)",readables[i],i)
        end
        report_caches("using writable path '%s'",writable)
    end
    identify = function()
        return writable, readables
    end
    return writable, readables
end

function caches.usedpaths()
    local writable, readables = identify()
    if #readables > 1 then
        local result = { }
        for i=1,#readables do
            local readable = readables[i]
            if usedreadables[i] or readable == writable then
                result[#result+1] = format("readable: '%s' (order %s)",readable,i)
            end
        end
        result[#result+1] = format("writable: '%s'",writable)
        return result
    else
        return writable
    end
end

function caches.configfiles()
    return concat(resolvers.instance.specification,";")
end

function caches.hashed(tree)
    tree = gsub(tree,"\\$","/")
    tree = gsub(tree,"/+$","")
    tree = lower(tree)
    local hash = md5.hex(tree)
    if trace_cache or trace_locating then
        report_caches("hashing tree %s, hash %s",tree,hash)
    end
    return hash
end

function caches.treehash()
    local tree = caches.configfiles()
    if not tree or tree == "" then
        return false
    else
        return caches.hashed(tree)
    end
end

local r_cache, w_cache = { }, { } -- normally w in in r but who cares

local function getreadablepaths(...) -- we can optimize this as we have at most 2 tags
    local tags = { ... }
    local hash = concat(tags,"/")
    local done = r_cache[hash]
    if not done then
        local writable, readables = identify() -- exit if not found
        if #tags > 0 then
            done = { }
            for i=1,#readables do
                done[i] = file.join(readables[i],...)
            end
        else
            done = readables
        end
        r_cache[hash] = done
    end
    return done
end

local function getwritablepath(...)
    local tags = { ... }
    local hash = concat(tags,"/")
    local done = w_cache[hash]
    if not done then
        local writable, readables = identify() -- exit if not found
        if #tags > 0 then
            done = mkdirs(writable,...)
        else
            done = writable
        end
        w_cache[hash] = done
    end
    return done
end

caches.getreadablepaths = getreadablepaths
caches.getwritablepath  = getwritablepath

function caches.getfirstreadablefile(filename,...)
    local rd = getreadablepaths(...)
    for i=1,#rd do
        local path = rd[i]
        local fullname = file.join(path,filename)
        if file.is_readable(fullname) then
            usedreadables[i] = true
            return fullname, path
        end
    end
    return caches.setfirstwritablefile(filename,...)
end

function caches.setfirstwritablefile(filename,...)
    local wr = getwritablepath(...)
    local fullname = file.join(wr,filename)
    return fullname, wr
end

function caches.define(category,subcategory) -- for old times sake
    return function()
        return getwritablepath(category,subcategory)
    end
end

function caches.setluanames(path,name)
    return path .. "/" .. name .. ".tma", path .. "/" .. name .. ".tmc"
end

function caches.loaddata(readables,name)
    if type(readables) == "string" then
        readables = { readables }
    end
    for i=1,#readables do
        local path = readables[i]
        local tmaname, tmcname = caches.setluanames(path,name)
        local loader = loadfile(tmcname) or loadfile(tmaname)
        if loader then
            loader = loader()
            collectgarbage("step")
            return loader
        end
    end
    return false
end

function caches.is_writable(filepath,filename)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    return file.is_writable(tmaname)
end

local saveoptions = { compact = true }

function caches.savedata(filepath,filename,data,raw)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    local reduce, simplify = true, true
    if raw then
        reduce, simplify = false, false
    end
    data.cache_uuid = os.uuid()
    if caches.direct then
        file.savedata(tmaname,serialize(data,true,saveoptions))
    else
        serializetofile(tmaname,data,true,saveoptions)
    end
    utilities.lua.compile(tmaname,tmcname)
end

-- moved from data-res:

local content_state = { }

function caches.contentstate()
    return content_state or { }
end

function caches.loadcontent(cachename,dataname)
    local name = caches.hashed(cachename)
    local full, path = caches.getfirstreadablefile(name ..".lua","trees")
    local filename = file.join(path,name)
    local blob = loadfile(filename .. ".luc") or loadfile(filename .. ".lua")
    if blob then
        local data = blob()
        if data and data.content then
            if data.type == dataname then
                if data.version == resolvers.cacheversion then
                    content_state[#content_state+1] = data.uuid
                    if trace_locating then
                        report_resolvers("loading '%s' for '%s' from '%s'",dataname,cachename,filename)
                    end
                    return data.content
                else
                    report_resolvers("skipping '%s' for '%s' from '%s' (version mismatch)",dataname,cachename,filename)
                end
            else
                report_resolvers("skipping '%s' for '%s' from '%s' (datatype mismatch)",dataname,cachename,filename)
            end
        elseif trace_locating then
            report_resolvers("skipping '%s' for '%s' from '%s' (no content)",dataname,cachename,filename)
        end
    elseif trace_locating then
        report_resolvers("skipping '%s' for '%s' from '%s' (invalid file)",dataname,cachename,filename)
    end
end

function caches.collapsecontent(content)
    for k, v in next, content do
        if type(v) == "table" and #v == 1 then
            content[k] = v[1]
        end
    end
end

function caches.savecontent(cachename,dataname,content)
    local name = caches.hashed(cachename)
    local full, path = caches.setfirstwritablefile(name ..".lua","trees")
    local filename = file.join(path,name) -- is full
    local luaname, lucname = filename .. ".lua", filename .. ".luc"
    if trace_locating then
        report_resolvers("preparing '%s' for '%s'",dataname,cachename)
    end
    local data = {
        type    = dataname,
        root    = cachename,
        version = resolvers.cacheversion,
        date    = os.date("%Y-%m-%d"),
        time    = os.date("%H:%M:%S"),
        content = content,
        uuid    = os.uuid(),
    }
    local ok = io.savedata(luaname,serialize(data,true))
    if ok then
        if trace_locating then
            report_resolvers("category '%s', cachename '%s' saved in '%s'",dataname,cachename,luaname)
        end
        if utilities.lua.compile(luaname,lucname) then
            if trace_locating then
                report_resolvers("'%s' compiled to '%s'",dataname,lucname)
            end
            return true
        else
            if trace_locating then
                report_resolvers("compiling failed for '%s', deleting file '%s'",dataname,lucname)
            end
            os.remove(lucname)
        end
    elseif trace_locating then
        report_resolvers("unable to save '%s' in '%s' (access error)",dataname,luaname)
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-met'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find, format = string.find, string.format
local sequenced = table.sequenced
local addurlscheme, urlhashed = url.addscheme, url.hashed

local trace_locating = false

trackers.register("resolvers.locating", function(v) trace_methods = v end)
trackers.register("resolvers.methods",  function(v) trace_methods = v end)


local report_methods = logs.reporter("resolvers","methods")

local allocate = utilities.storage.allocate

local resolvers = resolvers

local registered = { }

local function splitmethod(filename) -- todo: filetype in specification
    if not filename then
        return { scheme = "unknown", original = filename }
    end
    if type(filename) == "table" then
        return filename -- already split
    end
    filename = file.collapsepath(filename)
    if not find(filename,"://") then
        return { scheme = "file", path = filename, original = filename, filename = filename }
    end
    local specification = url.hashed(filename)
    if not specification.scheme or specification.scheme == "" then
        return { scheme = "file", path = filename, original = filename, filename = filename }
    else
        return specification
    end
end

resolvers.splitmethod = splitmethod -- bad name but ok

-- the second argument is always analyzed (saves time later on) and the original
-- gets passed as original but also as argument

local function methodhandler(what,first,...) -- filename can be nil or false
    local method = registered[what]
    if method then
        local how, namespace = method.how, method.namespace
        if how == "uri" or how == "url" then
            local specification = splitmethod(first)
            local scheme = specification.scheme
            local resolver = namespace and namespace[scheme]
            if resolver then
                if trace_methods then
                    report_methods("resolver: method=%s, how=%s, scheme=%s, argument=%s",what,how,scheme,first)
                end
                return resolver(specification,...)
            else
                resolver = namespace.default or namespace.file
                if resolver then
                    if trace_methods then
                        report_methods("resolver: method=%s, how=%s, default, argument=%s",what,how,first)
                    end
                    return resolver(specification,...)
                elseif trace_methods then
                    report_methods("resolver: method=%s, how=%s, no handler",what,how)
                end
            end
        elseif how == "tag" then
            local resolver = namespace and namespace[first]
            if resolver then
                if trace_methods then
                    report_methods("resolver: method=%s, how=%s, tag=%s",what,how,first)
                end
                return resolver(...)
            else
                resolver = namespace.default or namespace.file
                if resolver then
                    if trace_methods then
                        report_methods("resolver: method=%s, how=%s, default",what,how)
                    end
                    return resolver(...)
                elseif trace_methods then
                    report_methods("resolver: method=%s, how=%s, unknown",what,how)
                end
            end
        end
    else
        report_methods("resolver: method=%s, unknown",what)
    end
end

resolvers.methodhandler = methodhandler

function resolvers.registermethod(name,namespace,how)
    registered[name] = { how = how or "tag", namespace = namespace }
    namespace["byscheme"] = function(scheme,filename,...)
        if scheme == "file" then
            return methodhandler(name,filename,...)
        else
            return methodhandler(name,addurlscheme(filename,scheme),...)
        end
    end
end

local concatinators = allocate { notfound = file.join       }  -- concatinate paths
local locators      = allocate { notfound = function() end  }  -- locate databases
local hashers       = allocate { notfound = function() end  }  -- load databases
local generators    = allocate { notfound = function() end  }  -- generate databases

resolvers.concatinators = concatinators
resolvers.locators      = locators
resolvers.hashers       = hashers
resolvers.generators    = generators

local registermethod = resolvers.registermethod

registermethod("concatinators",concatinators,"tag")
registermethod("locators",     locators,     "uri")
registermethod("hashers",      hashers,      "uri")
registermethod("generators",   generators,   "uri")


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-res'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- In practice we will work within one tds tree, but i want to keep
-- the option open to build tools that look at multiple trees, which is
-- why we keep the tree specific data in a table. We used to pass the
-- instance but for practical purposes we now avoid this and use a
-- instance variable. We always have one instance active (sort of global).

-- todo: cache:/// home:/// selfautoparent:/// (sometime end 2012)

local format, gsub, find, lower, upper, match, gmatch = string.format, string.gsub, string.find, string.lower, string.upper, string.match, string.gmatch
local concat, insert, sortedkeys = table.concat, table.insert, table.sortedkeys
local next, type, rawget = next, type, rawget
local os = os

local P, S, R, C, Cc, Cs, Ct, Carg = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Carg
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local filedirname       = file.dirname
local filebasename      = file.basename
local fileextname       = file.extname
local filejoin          = file.join
local collapsepath      = file.collapsepath
local joinpath          = file.joinpath
local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_detail     = false  trackers.register("resolvers.details",    function(v) trace_detail     = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)

local report_resolving = logs.reporter("resolvers","resolving")

local resolvers = resolvers

local expandedpathfromlist   = resolvers.expandedpathfromlist
local checkedvariable        = resolvers.checkedvariable
local splitconfigurationpath = resolvers.splitconfigurationpath
local methodhandler          = resolvers.methodhandler

local initializesetter = utilities.setters.initialize

local ostype, osname, osenv, ossetenv, osgetenv = os.type, os.name, os.env, os.setenv, os.getenv

resolvers.cacheversion  = '1.0.1'
resolvers.configbanner  = ''
resolvers.homedir       = environment.homedir
resolvers.criticalvars  = allocate { "SELFAUTOLOC", "SELFAUTODIR", "SELFAUTOPARENT", "TEXMFCNF", "TEXMF", "TEXOS" }
resolvers.luacnfname    = 'texmfcnf.lua'
resolvers.luacnfstate   = "unknown"

-- The web2c tex binaries as well as kpse have built in paths for the configuration
-- files and there can be a depressing truckload of them. This is actually the weak
-- spot of a distribution. So we don't want:
--
-- resolvers.luacnfspec = '{$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,}/web2c}'
--
-- but instead use:
--
-- resolvers.luacnfspec = 'selfautoparent:{/texmf{-local,}{,/web2c}}'
--
-- which does not make texlive happy as there is a texmf-local tree one level up
-- (sigh), so we need this. We can assume web2c as mkiv does not run on older
-- texlives anyway.
--
-- texlive:
--
-- selfautodir:
-- selfautoparent:
-- selfautodir:share/texmf-local/web2c
-- selfautodir:share/texmf/web2c
-- selfautodir:texmf-local/web2c
-- selfautodir:texmf/web2c
-- selfautoparent:share/texmf-local/web2c
-- selfautoparent:share/texmf/web2c
-- selfautoparent:texmf-local/web2c
-- selfautoparent:texmf/web2c
--
-- minimals:
--
-- home:texmf/web2c
-- selfautoparent:texmf-local/web2c
-- selfautoparent:texmf-context/web2c
-- selfautoparent:texmf/web2c

if environment.default_texmfcnf then
    -- unfortunately we now have quite some overkill in the spec (not so nice on a network)
    resolvers.luacnfspec = environment.default_texmfcnf
else
 -- resolvers.luacnfspec = "selfautoparent:texmf{-local,-context,}/web2c"
    resolvers.luacnfspec = "{selfautoloc:,selfautodir:,selfautoparent:}{,/texmf{-local,}/web2c}"
end

resolvers.luacnfspec = 'home:texmf/web2c;' .. resolvers.luacnfspec

-- which (as we want users to use the web2c path) be can be simplified to this:
--
-- if environment and environment.ownpath and string.find(environment.ownpath,"[\\/]texlive[\\/]") then
--     resolvers.luacnfspec = 'selfautodir:/texmf-local/web2c,selfautoparent:/texmf-local/web2c,selfautoparent:/texmf/web2c'
-- else
--     resolvers.luacnfspec = 'selfautoparent:/texmf-local/web2c,selfautoparent:/texmf/web2c'
-- end



local unset_variable = "unset"

local formats   = resolvers.formats
local suffixes  = resolvers.suffixes
local dangerous = resolvers.dangerous
local suffixmap = resolvers.suffixmap

resolvers.defaultsuffixes = { "tex" } --  "mkiv", "cld" -- too tricky

resolvers.instance = resolvers.instance or nil -- the current one (slow access)
local     instance = resolvers.instance or nil -- the current one (fast access)

-- An instance has an environment (coming from the outside, kept raw), variables
-- (coming from the configuration file), and expansions (variables with nested
-- variables replaced). One can push something into the outer environment and
-- its internal copy, but only the later one will be the raw unprefixed variant.

function resolvers.setenv(key,value,raw)
    if instance then
        -- this one will be consulted first when we stay inside
        -- the current environment (prefixes are not resolved here)
        instance.environment[key] = value
        -- we feed back into the environment, and as this is used
        -- by other applications (via os.execute) we need to make
        -- sure that prefixes are resolve
        ossetenv(key,raw and value or resolvers.resolve(value))
    end
end

-- Beware we don't want empty here as this one can be called early on
-- and therefore we use rawget.

local function getenv(key)
    local value = rawget(instance.environment,key)
    if value and value ~= "" then
        return value
    else
        local e = osgetenv(key)
        return e ~= nil and e ~= "" and checkedvariable(e) or ""
    end
end

resolvers.getenv = getenv
resolvers.env    = getenv

-- We are going to use some metatable trickery where we backtrack from
-- expansion to variable to environment.

local function resolve(k)
    return instance.expansions[k]
end

local dollarstripper   = lpeg.stripper("$")
local inhibitstripper  = P("!")^0 * Cs(P(1)^0)
local backslashswapper = lpeg.replacer("\\","/")

local somevariable     = P("$") / ""
local somekey          = C(R("az","AZ","09","__","--")^1)
local somethingelse    = P(";") * ((1-S("!{}/\\"))^1 * P(";") / "")
                       + P(";") * (P(";") / "")
                       + P(1)
local variableexpander = Cs( (somevariable * (somekey/resolve) + somethingelse)^1 )

local cleaner          = P("\\") / "/" + P(";") * S("!{}/\\")^0 * P(";")^1 / ";"
local variablecleaner  = Cs((cleaner  + P(1))^0)

local somevariable     = R("az","AZ","09","__","--")^1 / resolve
local variable         = (P("$")/"") * (somevariable + (P("{")/"") * somevariable * (P("}")/""))
local variableresolver = Cs((variable + P(1))^0)

local function expandedvariable(var)
    return lpegmatch(variableexpander,var) or var
end

function resolvers.newinstance() -- todo: all vars will become lowercase and alphanum only

     if trace_locating then
        report_resolving("creating instance")
     end

    local environment, variables, expansions, order = allocate(), allocate(), allocate(), allocate()

    local newinstance = {
        environment     = environment,
        variables       = variables,
        expansions      = expansions,
        order           = order,
        files           = allocate(),
        setups          = allocate(),
        found           = allocate(),
        foundintrees    = allocate(),
        hashes          = allocate(),
        hashed          = allocate(),
        specification   = allocate(),
        lists           = allocate(),
        data            = allocate(), -- only for loading
        fakepaths       = allocate(),
        remember        = true,
        diskcache       = true,
        renewcache      = false,
        renewtree       = false,
        loaderror       = false,
        savelists       = true,
        pattern         = nil, -- lists
        force_suffixes  = true,
    }

    setmetatableindex(variables,function(t,k)
        local v
        for i=1,#order do
            v = order[i][k]
            if v ~= nil then
                t[k] = v
                return v
            end
        end
        if v == nil then
            v = ""
        end
        t[k] = v
        return v
    end)

    setmetatableindex(environment, function(t,k)
        local v = osgetenv(k)
        if v == nil then
            v = variables[k]
        end
        if v ~= nil then
            v = checkedvariable(v) or ""
        end
        v = resolvers.repath(v) -- for taco who has a : separated osfontdir
        t[k] = v
        return v
    end)

    setmetatableindex(expansions, function(t,k)
        local v = environment[k]
        if type(v) == "string" then
            v = lpegmatch(variableresolver,v)
            v = lpegmatch(variablecleaner,v)
        end
        t[k] = v
        return v
    end)

    return newinstance

end

function resolvers.setinstance(someinstance) -- only one instance is active
    instance = someinstance
    resolvers.instance = someinstance
    return someinstance
end

function resolvers.reset()
    return resolvers.setinstance(resolvers.newinstance())
end

local function reset_hashes()
    instance.lists = { }
    instance.found = { }
end

local slash = P("/")

local pathexpressionpattern = Cs (
    Cc("^") * (
        Cc("%") * S(".-")
      + slash^2 * P(-1) / "/.*"
      + slash^2 / "/.-/"
      + (1-slash) * P(-1) * Cc("/")
      + P(1)
    )^1 * Cc("$") -- yes or no $
)

local cache = { }

local function makepathexpression(str)
    if str == "." then
        return "^%./$"
    else
        local c = cache[str]
        if not c then
            c = lpegmatch(pathexpressionpattern,str)
            cache[str] = c
        end
        return c
    end
end

local function reportcriticalvariables(cnfspec)
    if trace_locating then
        for i=1,#resolvers.criticalvars do
            local k = resolvers.criticalvars[i]
            local v = resolvers.getenv(k) or "unknown" -- this one will not resolve !
            report_resolving("variable '%s' set to '%s'",k,v)
        end
        report_resolving()
        if cnfspec then
            if type(cnfspec) == "table" then
                report_resolving("using configuration specification '%s'",concat(cnfspec,","))
            else
                report_resolving("using configuration specification '%s'",cnfspec)
            end
        end
        report_resolving()
    end
    reportcriticalvariables = function() end
end

local function identify_configuration_files()
    local specification = instance.specification
    if #specification == 0 then
        local cnfspec = getenv('TEXMFCNF')
        if cnfspec == "" then
            cnfspec = resolvers.luacnfspec
            resolvers.luacnfstate = "default"
        else
            resolvers.luacnfstate = "environment"
        end
        reportcriticalvariables(cnfspec)
        local cnfpaths = expandedpathfromlist(resolvers.splitpath(cnfspec))
        local luacnfname = resolvers.luacnfname
        for i=1,#cnfpaths do
            local filename = collapsepath(filejoin(cnfpaths[i],luacnfname))
            local realname = resolvers.resolve(filename)
            if lfs.isfile(realname) then
                specification[#specification+1] = filename
                if trace_locating then
                    report_resolving("found configuration file '%s'",realname)
                end
            elseif trace_locating then
                report_resolving("unknown configuration file '%s'",realname)
            end
        end
        if trace_locating then
            report_resolving()
        end
    elseif trace_locating then
        report_resolving("configuration files already identified")
    end
end

local function load_configuration_files()
    local specification = instance.specification
    if #specification > 0 then
        local luacnfname = resolvers.luacnfname
        for i=1,#specification do
            local filename = specification[i]
            local pathname = filedirname(filename)
            local filename = filejoin(pathname,luacnfname)
            local realname = resolvers.resolve(filename) -- no shortcut
            local blob = loadfile(realname)
            if blob then
                local setups = instance.setups
                local data = blob()
                local parent = data and data.parent
                if parent then
                    local filename = filejoin(pathname,parent)
                    local realname = resolvers.resolve(filename) -- no shortcut
                    local blob = loadfile(realname)
                    if blob then
                        local parentdata = blob()
                        if parentdata then
                            report_resolving("loading configuration file '%s'",filename)
                            data = table.merged(parentdata,data)
                        end
                    end
                end
                data = data and data.content
                if data then
                    if trace_locating then
                        report_resolving("loading configuration file '%s'",filename)
                        report_resolving()
                    end
                    local variables = data.variables or { }
                    local warning = false
                    for k, v in next, data do
                        local variant = type(v)
                        if variant == "table" then
                            initializesetter(filename,k,v)
                        elseif variables[k] == nil then
                            if trace_locating and not warning then
                                report_resolving("variables like '%s' in configuration file '%s' should move to the 'variables' subtable",
                                    k,resolvers.resolve(filename))
                                warning = true
                            end
                            variables[k] = v
                        end
                    end
                    setups[pathname] = variables
                    if resolvers.luacnfstate == "default" then
                        -- the following code is not tested
                        local cnfspec = variables["TEXMFCNF"]
                        if cnfspec then
                            if trace_locating then
                                report_resolving("reloading configuration due to TEXMF redefinition")
                            end
                            -- we push the value into the main environment (osenv) so
                            -- that it takes precedence over the default one and therefore
                            -- also over following definitions
                            resolvers.setenv('TEXMFCNF',cnfspec) -- resolves prefixes
                            -- we now identify and load the specified configuration files
                            instance.specification = { }
                            identify_configuration_files()
                            load_configuration_files()
                            -- we prevent further overload of the configuration variable
                            resolvers.luacnfstate = "configuration"
                            -- we quit the outer loop
                            break
                        end
                    end

                else
                    if trace_locating then
                        report_resolving("skipping configuration file '%s' (no content)",filename)
                    end
                    setups[pathname] = { }
                    instance.loaderror = true
                end
            elseif trace_locating then
                report_resolving("skipping configuration file '%s' (no valid format)",filename)
            end
            instance.order[#instance.order+1] = instance.setups[pathname]
            if instance.loaderror then
                break
            end
        end
    elseif trace_locating then
        report_resolving("warning: no lua configuration files found")
    end
end

-- scheme magic ... database loading

local function load_file_databases()
    instance.loaderror, instance.files = false, allocate()
    if not instance.renewcache then
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            resolvers.hashers.byscheme(hash.type,hash.name)
            if instance.loaderror then break end
        end
    end
end

local function locate_file_databases()
    -- todo: cache:// and tree:// (runtime)
    local texmfpaths = resolvers.expandedpathlist('TEXMF')
    if #texmfpaths > 0 then
        for i=1,#texmfpaths do
            local path = collapsepath(texmfpaths[i])
            local stripped = lpegmatch(inhibitstripper,path) -- the !! thing
            if stripped ~= "" then
                local runtime = stripped == path
                path = resolvers.cleanpath(path)
                local spec = resolvers.splitmethod(stripped)
                if runtime and (spec.noscheme or spec.scheme == "file") then
                    stripped = "tree:///" .. stripped
                elseif spec.scheme == "cache" or spec.scheme == "file" then
                    stripped = spec.path
                end
                if trace_locating then
                    if runtime then
                        report_resolving("locating list of '%s' (runtime) (%s)",path,stripped)
                    else
                        report_resolving("locating list of '%s' (cached)",path)
                    end
                end
                methodhandler('locators',stripped)
            end
        end
        if trace_locating then
            report_resolving()
        end
    elseif trace_locating then
        report_resolving("no texmf paths are defined (using TEXMF)")
    end
end

local function generate_file_databases()
    local hashes = instance.hashes
    for k=1,#hashes do
        local hash = hashes[k]
        methodhandler('generators',hash.name)
    end
    if trace_locating then
        report_resolving()
    end
end

local function save_file_databases() -- will become cachers
    for i=1,#instance.hashes do
        local hash = instance.hashes[i]
        local cachename = hash.name
        if hash.cache then
            local content = instance.files[cachename]
            caches.collapsecontent(content)
            if trace_locating then
                report_resolving("saving tree '%s'",cachename)
            end
            caches.savecontent(cachename,"files",content)
        elseif trace_locating then
            report_resolving("not saving runtime tree '%s'",cachename)
        end
    end
end

function resolvers.renew(hashname)
    if hashname and hashname ~= "" then
        local expanded = resolvers.expansion(hashname) or ""
        if expanded ~= "" then
            if trace_locating then
                report_resolving("identifying tree '%s' from '%s'",expanded,hashname)
            end
            hashname = expanded
        else
            if trace_locating then
                report_resolving("identifying tree '%s'",hashname)
            end
        end
        local realpath = resolvers.resolve(hashname)
        if lfs.isdir(realpath) then
            if trace_locating then
                report_resolving("using path '%s'",realpath)
            end
            methodhandler('generators',hashname)
            -- could be shared
            local content = instance.files[hashname]
            caches.collapsecontent(content)
            if trace_locating then
                report_resolving("saving tree '%s'",hashname)
            end
            caches.savecontent(hashname,"files",content)
            -- till here
        else
            report_resolving("invalid path '%s'",realpath)
        end
    end
end

local function load_databases()
    locate_file_databases()
    if instance.diskcache and not instance.renewcache then
        load_file_databases()
        if instance.loaderror then
            generate_file_databases()
            save_file_databases()
        end
    else
        generate_file_databases()
        if instance.renewcache then
            save_file_databases()
        end
    end
end

function resolvers.appendhash(type,name,cache)
    -- safeguard ... tricky as it's actually a bug when seen twice
    if not instance.hashed[name] then
        if trace_locating then
            report_resolving("hash '%s' appended",name)
        end
        insert(instance.hashes, { type = type, name = name, cache = cache } )
        instance.hashed[name] = cache
    end
end

function resolvers.prependhash(type,name,cache)
    -- safeguard ... tricky as it's actually a bug when seen twice
    if not instance.hashed[name] then
        if trace_locating then
            report_resolving("hash '%s' prepended",name)
        end
        insert(instance.hashes, 1, { type = type, name = name, cache = cache } )
        instance.hashed[name] = cache
    end
end

function resolvers.extendtexmfvariable(specification) -- crap, we could better prepend the hash
    local t = resolvers.splitpath(getenv('TEXMF'))
    insert(t,1,specification)
    local newspec = concat(t,";")
    if instance.environment["TEXMF"] then
        instance.environment["TEXMF"] = newspec
    elseif instance.variables["TEXMF"] then
        instance.variables["TEXMF"] = newspec
    else
        -- weird
    end
    reset_hashes()
end

function resolvers.splitexpansions()
    local ie = instance.expansions
    for k,v in next, ie do
        local t, tn, h, p = { }, 0, { }, splitconfigurationpath(v)
        for kk=1,#p do
            local vv = p[kk]
            if vv ~= "" and not h[vv] then
                tn = tn + 1
                t[tn] = vv
                h[vv] = true
            end
        end
        if #t > 1 then
            ie[k] = t
        else
            ie[k] = t[1]
        end
    end
end

-- end of split/join code

-- we used to have 'files' and 'configurations' so therefore the following
-- shared function

function resolvers.datastate()
    return caches.contentstate()
end

function resolvers.variable(name)
    local name = name and lpegmatch(dollarstripper,name)
    local result = name and instance.variables[name]
    return result ~= nil and result or ""
end

function resolvers.expansion(name)
    local name = name and lpegmatch(dollarstripper,name)
    local result = name and instance.expansions[name]
    return result ~= nil and result or ""
end

function resolvers.unexpandedpathlist(str)
    local pth = resolvers.variable(str)
    local lst = resolvers.splitpath(pth)
    return expandedpathfromlist(lst)
end

function resolvers.unexpandedpath(str)
    return joinpath(resolvers.unexpandedpathlist(str))
end

local done = { }

function resolvers.resetextrapath()
    local ep = instance.extra_paths
    if not ep then
        ep, done = { }, { }
        instance.extra_paths = ep
    elseif #ep > 0 then
        instance.lists, done = { }, { }
    end
end

function resolvers.registerextrapath(paths,subpaths)
    local ep = instance.extra_paths or { }
    local oldn = #ep
    local newn = oldn
    if paths and paths ~= "" then
        if subpaths and subpaths ~= "" then
            for p in gmatch(paths,"[^,]+") do
                -- we gmatch each step again, not that fast, but used seldom
                for s in gmatch(subpaths,"[^,]+") do
                    local ps = p .. "/" .. s
                    if not done[ps] then
                        newn = newn + 1
                        ep[newn] = resolvers.cleanpath(ps)
                        done[ps] = true
                    end
                end
            end
        else
            for p in gmatch(paths,"[^,]+") do
                if not done[p] then
                    newn = newn + 1
                    ep[newn] = resolvers.cleanpath(p)
                    done[p] = true
                end
            end
        end
    elseif subpaths and subpaths ~= "" then
        for i=1,oldn do
            -- we gmatch each step again, not that fast, but used seldom
            for s in gmatch(subpaths,"[^,]+") do
                local ps = ep[i] .. "/" .. s
                if not done[ps] then
                    newn = newn + 1
                    ep[newn] = resolvers.cleanpath(ps)
                    done[ps] = true
                end
            end
        end
    end
    if newn > 0 then
        instance.extra_paths = ep -- register paths
    end
    if newn > oldn then
        instance.lists = { } -- erase the cache
    end
end

local function made_list(instance,list)
    local ep = instance.extra_paths
    if not ep or #ep == 0 then
        return list
    else
        local done, new, newn = { }, { }, 0
        -- honour . .. ../.. but only when at the start
        for k=1,#list do
            local v = list[k]
            if not done[v] then
                if find(v,"^[%.%/]$") then
                    done[v] = true
                    newn = newn + 1
                    new[newn] = v
                else
                    break
                end
            end
        end
        -- first the extra paths
        for k=1,#ep do
            local v = ep[k]
            if not done[v] then
                done[v] = true
                newn = newn + 1
                new[newn] = v
            end
        end
        -- next the formal paths
        for k=1,#list do
            local v = list[k]
            if not done[v] then
                done[v] = true
                newn = newn + 1
                new[newn] = v
            end
        end
        return new
    end
end

function resolvers.cleanpathlist(str)
    local t = resolvers.expandedpathlist(str)
    if t then
        for i=1,#t do
            t[i] = collapsepath(resolvers.cleanpath(t[i]))
        end
    end
    return t
end

function resolvers.expandpath(str)
    return joinpath(resolvers.expandedpathlist(str))
end

function resolvers.expandedpathlist(str)
    if not str then
        return { }
    elseif instance.savelists then
        str = lpegmatch(dollarstripper,str)
        if not instance.lists[str] then -- cached
            local lst = made_list(instance,resolvers.splitpath(resolvers.expansion(str)))
            instance.lists[str] = expandedpathfromlist(lst)
        end
        return instance.lists[str]
    else
        local lst = resolvers.splitpath(resolvers.expansion(str))
        return made_list(instance,expandedpathfromlist(lst))
    end
end

function resolvers.expandedpathlistfromvariable(str) -- brrr
    str = lpegmatch(dollarstripper,str)
    local tmp = resolvers.variableofformatorsuffix(str)
    return resolvers.expandedpathlist(tmp ~= "" and tmp or str)
end

function resolvers.expandpathfromvariable(str)
    return joinpath(resolvers.expandedpathlistfromvariable(str))
end

function resolvers.expandbraces(str) -- output variable and brace expansion of STRING
--     local ori = resolvers.variable(str)
--     if ori == "" then
        local ori = str
--     end
    local pth = expandedpathfromlist(resolvers.splitpath(ori))
    return joinpath(pth)
end

function resolvers.registerfilehash(name,content,someerror)
    if content then
        instance.files[name] = content
    else
        instance.files[name] = { }
        if somerror == true then -- can be unset
            instance.loaderror = someerror
        end
    end
end

local function isreadable(name)
    local readable = lfs.isfile(name) -- not file.is_readable(name) asit can be a dir
    if trace_detail then
        if readable then
            report_resolving("file '%s' is readable",name)
        else
            report_resolving("file '%s' is not readable", name)
        end
    end
    return readable
end

-- name
-- name/name

local function collect_files(names)
    local filelist, noffiles = { }, 0
    for k=1,#names do
        local fname = names[k]
        if trace_detail then
            report_resolving("checking name '%s'",fname)
        end
        local bname = filebasename(fname)
        local dname = filedirname(fname)
        if dname == "" or find(dname,"^%.") then
            dname = false
        else
dname = gsub(dname,"*","%.*")
            dname = "/" .. dname .. "$"
        end
        local hashes = instance.hashes
        for h=1,#hashes do
            local hash = hashes[h]
            local blobpath = hash.name
            local files = blobpath and instance.files[blobpath]
            if files then
                if trace_detail then
                    report_resolving("deep checking '%s' (%s)",blobpath,bname)
                end
                local blobfile = files[bname]
                if not blobfile then
                    local rname = "remap:"..bname
                    blobfile = files[rname]
                    if blobfile then
                        bname = files[rname]
                        blobfile = files[bname]
                    end
                end
                if blobfile then
                    local blobroot = files.__path__ or blobpath
                    if type(blobfile) == 'string' then
                        if not dname or find(blobfile,dname) then
                            local variant = hash.type
                         -- local search  = filejoin(blobpath,blobfile,bname)
                            local search  = filejoin(blobroot,blobfile,bname)
                            local result  = methodhandler('concatinators',hash.type,blobroot,blobfile,bname)
                            if trace_detail then
                                report_resolving("match: variant '%s', search '%s', result '%s'",variant,search,result)
                            end
                            noffiles = noffiles + 1
                            filelist[noffiles] = { variant, search, result }
                        end
                    else
                        for kk=1,#blobfile do
                            local vv = blobfile[kk]
                            if not dname or find(vv,dname) then
                                local variant = hash.type
                             -- local search  = filejoin(blobpath,vv,bname)
                                local search  = filejoin(blobroot,vv,bname)
                                local result  = methodhandler('concatinators',hash.type,blobroot,vv,bname)
                                if trace_detail then
                                    report_resolving("match: variant '%s', search '%s', result '%s'",variant,search,result)
                                end
                                noffiles = noffiles + 1
                                filelist[noffiles] = { variant, search, result }
                            end
                        end
                    end
                end
            elseif trace_locating then
                report_resolving("no match in '%s' (%s)",blobpath,bname)
            end
        end
    end
    return noffiles > 0 and filelist or nil
end

local fit = { }

function resolvers.registerintrees(filename,format,filetype,usedmethod,foundname)
    local foundintrees = instance.foundintrees
    if usedmethod == "direct" and filename == foundname and fit[foundname] then
        -- just an extra lookup after a test on presence
    else
        local t = {
            filename   = filename,
            format     = format ~= "" and format or nil,
            filetype   = filetype  ~= "" and filetype or nil,
            usedmethod = usedmethod,
            foundname  = foundname,
        }
        fit[foundname] = t
        foundintrees[#foundintrees+1] = t
    end
end

-- split the next one up for readability (but this module needs a cleanup anyway)

local function can_be_dir(name) -- can become local
    local fakepaths = instance.fakepaths
    if not fakepaths[name] then
        if lfs.isdir(name) then
            fakepaths[name] = 1 -- directory
        else
            fakepaths[name] = 2 -- no directory
        end
    end
    return fakepaths[name] == 1
end

local preparetreepattern = Cs((P(".")/"%%." + P("-")/"%%-" + P(1))^0 * Cc("$"))

-- -- -- begin of main file search routing -- -- -- needs checking as previous has been patched

local collect_instance_files

local function find_analyze(filename,askedformat,allresults)
    local filetype, wantedfiles, ext = '', { }, fileextname(filename)
    -- too tricky as filename can be bla.1.2.3:
    --
    -- if not suffixmap[ext] then
    --     wantedfiles[#wantedfiles+1] = filename
    -- end
    wantedfiles[#wantedfiles+1] = filename
    if askedformat == "" then
        if ext == "" or not suffixmap[ext] then
            local defaultsuffixes = resolvers.defaultsuffixes
            for i=1,#defaultsuffixes do
                local forcedname = filename .. '.' .. defaultsuffixes[i]
                wantedfiles[#wantedfiles+1] = forcedname
                filetype = resolvers.formatofsuffix(forcedname)
                if trace_locating then
                    report_resolving("forcing filetype '%s'",filetype)
                end
            end
        else
            filetype = resolvers.formatofsuffix(filename)
            if trace_locating then
                report_resolving("using suffix based filetype '%s'",filetype)
            end
        end
    else
        if ext == "" or not suffixmap[ext] then
            local format_suffixes = suffixes[askedformat]
            if format_suffixes then
                for i=1,#format_suffixes do
                    wantedfiles[#wantedfiles+1] = filename .. "." .. format_suffixes[i]
                end
            end
        end
        filetype = askedformat
        if trace_locating then
            report_resolving("using given filetype '%s'",filetype)
        end
    end
    return filetype, wantedfiles
end

local function find_direct(filename,allresults)
    if not dangerous[askedformat] and isreadable(filename) then
        if trace_detail then
            report_resolving("file '%s' found directly",filename)
        end
        return "direct", { filename }
    end
end

local function find_wildcard(filename,allresults)
    if find(filename,'%*') then
        if trace_locating then
            report_resolving("checking wildcard '%s'", filename)
        end
        local method, result = resolvers.findwildcardfiles(filename)
        if result then
            return "wildcard", result
        end
    end
end

local function find_qualified(filename,allresults) -- this one will be split too
    if not file.is_qualified_path(filename) then
        return
    end
    if trace_locating then
        report_resolving("checking qualified name '%s'", filename)
    end
    if isreadable(filename) then
        if trace_detail then
            report_resolving("qualified file '%s' found", filename)
        end
        return "qualified", { filename }
    end
    if trace_detail then
        report_resolving("locating qualified file '%s'", filename)
    end
    local forcedname, suffix = "", fileextname(filename)
    if suffix == "" then -- why
        local format_suffixes = askedformat == "" and resolvers.defaultsuffixes or suffixes[askedformat]
        if format_suffixes then
            for i=1,#format_suffixes do
                local s = format_suffixes[i]
                forcedname = filename .. "." .. s
                if isreadable(forcedname) then
                    if trace_locating then
                        report_resolving("no suffix, forcing format filetype '%s'", s)
                    end
                    return "qualified", { forcedname }
                end
            end
        end
    end
    if suffix and suffix ~= "" then
        -- try to find in tree (no suffix manipulation), here we search for the
        -- matching last part of the name
        local basename = filebasename(filename)
        local pattern = lpegmatch(preparetreepattern,filename)
        -- messy .. to be sorted out
        local savedformat = askedformat
        local format = savedformat or ""
        if format == "" then
            askedformat = resolvers.formatofsuffix(suffix)
        end
        if not format then
            askedformat = "othertextfiles" -- kind of everything, maybe all
        end
        --
        if basename ~= filename then
            local resolved = collect_instance_files(basename,askedformat,allresults)
            if #resolved == 0 then
                local lowered = lower(basename)
                if filename ~= lowered then
                    resolved = collect_instance_files(lowered,askedformat,allresults)
                end
            end
            resolvers.format = savedformat
            --
            if #resolved > 0 then
                local result = { }
                for r=1,#resolved do
                    local rr = resolved[r]
                    if find(rr,pattern) then
                        result[#result+1] = rr
                    end
                end
                if #result > 0 then
                    return "qualified", result
                end
            end
        end
        -- a real wildcard:
        --
        -- local filelist = collect_files({basename})
        -- result = { }
        -- for f=1,#filelist do
        --     local ff = filelist[f][3] or ""
        --     if find(ff,pattern) then
        --         result[#result+1], ok = ff, true
        --     end
        -- end
        -- if #result > 0 then
        --     return "qualified", result
        -- end
    end
end

local function check_subpath(fname)
    if isreadable(fname) then
        if trace_detail then
            report_resolving("found '%s' by deep scanning",fname)
        end
        return fname
    end
end

local function find_intree(filename,filetype,wantedfiles,allresults)
    local typespec = resolvers.variableofformat(filetype)
    local pathlist = resolvers.expandedpathlist(typespec)
    local method = "intree"
    if pathlist and #pathlist > 0 then
        -- list search
        local filelist = collect_files(wantedfiles)
        local dirlist = { }
        if filelist then
            for i=1,#filelist do
                dirlist[i] = filedirname(filelist[i][3]) .. "/" -- was [2] .. gamble
            end
        end
        if trace_detail then
            report_resolving("checking filename '%s'",filename)
        end
        local result = { }
        for k=1,#pathlist do
            local path = pathlist[k]
            local pathname = lpegmatch(inhibitstripper,path)
            local doscan = path == pathname -- no ^!!
            if not find (pathname,'//$') then
                doscan = false -- we check directly on the path
            end
            local done = false
            -- using file list
            if filelist then -- database
                -- compare list entries with permitted pattern -- /xx /xx//
                local expression = makepathexpression(pathname)
                if trace_detail then
                    report_resolving("using pattern '%s' for path '%s'",expression,pathname)
                end
                for k=1,#filelist do
                    local fl = filelist[k]
                    local f = fl[2]
                    local d = dirlist[k]
                    if find(d,expression) then
                        -- todo, test for readable
                        result[#result+1] = resolvers.resolve(fl[3]) -- no shortcut
                        done = true
                        if allresults then
                            if trace_detail then
                                report_resolving("match to '%s' in hash for file '%s' and path '%s', continue scanning",expression,f,d)
                            end
                        else
                            if trace_detail then
                                report_resolving("match to '%s' in hash for file '%s' and path '%s', quit scanning",expression,f,d)
                            end
                            break
                        end
                    elseif trace_detail then
                        report_resolving("no match to '%s' in hash for file '%s' and path '%s'",expression,f,d)
                    end
                end
            end
            if done then
                method = "database"
            else
                method = "filesystem" -- bonus, even when !! is specified
                pathname = gsub(pathname,"/+$","")
                pathname = resolvers.resolve(pathname)
                local scheme = url.hasscheme(pathname)
                if not scheme or scheme == "file" then
                    local pname = gsub(pathname,"%.%*$",'')
                    if not find(pname,"%*") then
                        if can_be_dir(pname) then
                            -- quick root scan first
                            for k=1,#wantedfiles do
                                local w = wantedfiles[k]
                                local fname = check_subpath(filejoin(pname,w))
                                if fname then
                                    result[#result+1] = fname
                                    done = true
                                    if not allresults then
                                        break
                                    end
                                end
                            end
                            if not done and doscan then
                                -- collect files in path (and cache the result)
                                local files = resolvers.simplescanfiles(pname,false,true)
                                for k=1,#wantedfiles do
                                    local w = wantedfiles[k]
                                    local subpath = files[w]
                                    if not subpath or subpath == "" then
                                        -- rootscan already done
                                    elseif type(subpath) == "string" then
                                        local fname = check_subpath(filejoin(pname,subpath,w))
                                        if fname then
                                            result[#result+1] = fname
                                            done = true
                                            if not allresults then
                                                break
                                            end
                                        end
                                    else
                                        for i=1,#subpath do
                                            local sp = subpath[i]
                                            if sp == "" then
                                                -- roottest already done
                                            else
                                                local fname = check_subpath(filejoin(pname,sp,w))
                                                if fname then
                                                    result[#result+1] = fname
                                                    done = true
                                                    if not allresults then
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                        if done and not allresults then
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    else
                        -- no access needed for non existing path, speedup (esp in large tree with lots of fake)
                    end
                end
            end
            -- todo recursive scanning
            if done and not allresults then
                break
            end
        end
        if #result > 0 then
            return method, result
        end
    end
end

local function find_onpath(filename,filetype,wantedfiles,allresults)
    if trace_detail then
        report_resolving("checking filename '%s', filetype '%s', wanted files '%s'",filename, filetype or '?',concat(wantedfiles," | "))
    end
    local result = { }
    for k=1,#wantedfiles do
        local fname = wantedfiles[k]
        if fname and isreadable(fname) then
            filename = fname
            result[#result+1] = filejoin('.',fname)
            if not allresults then
                break
            end
        end
    end
    if #result > 0 then
        return "onpath", result
    end
end

local function find_otherwise(filename,filetype,wantedfiles,allresults) -- other text files | any | whatever
    local filelist = collect_files(wantedfiles)
    local fl = filelist and filelist[1]
    if fl then
        return "otherwise", { resolvers.resolve(fl[3]) } -- filename
    end
end

-- we could have a loop over the 6 functions but then we'd have to
-- always analyze

collect_instance_files = function(filename,askedformat,allresults) -- uses nested
    askedformat = askedformat or ""
    filename = collapsepath(filename)
    if allresults then
        -- no need for caching, only used for tracing
        local filetype, wantedfiles = find_analyze(filename,askedformat)
        local results = {
            { find_direct   (filename,true) },
            { find_wildcard (filename,true) },
            { find_qualified(filename,true) },
            { find_intree   (filename,filetype,wantedfiles,true) },
            { find_onpath   (filename,filetype,wantedfiles,true) },
            { find_otherwise(filename,filetype,wantedfiles,true) },
        }
        local result, status, done = { }, { }, { }
        for k, r in next, results do
            local method, list = r[1], r[2]
            if method and list then
                for i=1,#list do
                    local c = collapsepath(list[i])
                    if not done[c] then
                        result[#result+1] = c
                        done[c] = true
                    end
                    status[#status+1] = format("%-10s: %s",method,c)
                end
            end
        end
        if trace_detail then
            report_resolving("lookup status: %s",table.serialize(status,filename))
        end
        return result, status
    else
        local method, result, stamp, filetype, wantedfiles
        if instance.remember then
            stamp = format("%s--%s", filename, askedformat)
            result = stamp and instance.found[stamp]
            if result then
                if trace_locating then
                    report_resolving("remembered file '%s'",filename)
                end
                return result
            end
        end
        method, result = find_direct(filename)
        if not result then
            method, result = find_wildcard(filename)
            if not result then
                method, result = find_qualified(filename)
                if not result then
                    filetype, wantedfiles = find_analyze(filename,askedformat)
                    method, result = find_intree(filename,filetype,wantedfiles)
                    if not result then
                        method, result = find_onpath(filename,filetype,wantedfiles)
                        if not result then
                            method, result = find_otherwise(filename,filetype,wantedfiles)
                        end
                    end
                end
            end
        end
        if result and #result > 0 then
            local foundname = collapsepath(result[1])
            resolvers.registerintrees(filename,askedformat,filetype,method,foundname)
            result = { foundname }
        else
            result = { } -- maybe false
        end
        if stamp then
            if trace_locating then
                report_resolving("remembering file '%s'",filename)
            end
            instance.found[stamp] = result
        end
        return result
    end
end

-- -- -- end of main file search routing -- -- --


local function findfiles(filename,filetype,allresults)
    local result, status = collect_instance_files(filename,filetype or "",allresults)
    if not result or #result == 0 then
        local lowered = lower(filename)
        if filename ~= lowered then
            result, status = collect_instance_files(lowered,filetype or "",allresults)
        end
    end
    return result or { }, status
end

function resolvers.findfiles(filename,filetype)
    return findfiles(filename,filetype,true)
end

function resolvers.findfile(filename,filetype)
    return findfiles(filename,filetype,false)[1] or ""
end

function resolvers.findpath(filename,filetype)
    return filedirname(findfiles(filename,filetype,false)[1] or "")
end

local function findgivenfiles(filename,allresults)
    local bname, result = filebasename(filename), { }
    local hashes = instance.hashes
    local noffound = 0
    for k=1,#hashes do
        local hash = hashes[k]
        local files = instance.files[hash.name] or { }
        local blist = files[bname]
        if not blist then
            local rname = "remap:"..bname
            blist = files[rname]
            if blist then
                bname = files[rname]
                blist = files[bname]
            end
        end
        if blist then
            if type(blist) == 'string' then
                local found = methodhandler('concatinators',hash.type,hash.name,blist,bname) or ""
                if found ~= "" then
                    noffound = noffound + 1
                    result[noffound] = resolvers.resolve(found)
                    if not allresults then break end
                end
            else
                for kk=1,#blist do
                    local vv = blist[kk]
                    local found = methodhandler('concatinators',hash.type,hash.name,vv,bname) or ""
                    if found ~= "" then
                        noffound = noffound + 1
                        result[noffound] = resolvers.resolve(found)
                        if not allresults then break end
                    end
                end
            end
        end
    end
    return result
end

function resolvers.findgivenfiles(filename)
    return findgivenfiles(filename,true)
end

function resolvers.findgivenfile(filename)
    return findgivenfiles(filename,false)[1] or ""
end

local function doit(path,blist,bname,tag,variant,result,allresults)
    local done = false
    if blist and variant then
        local resolve = resolvers.resolve -- added
        if type(blist) == 'string' then
            -- make function and share code
            if find(lower(blist),path) then
                local full = methodhandler('concatinators',variant,tag,blist,bname) or ""
                result[#result+1] = resolve(full)
                done = true
            end
        else
            for kk=1,#blist do
                local vv = blist[kk]
                if find(lower(vv),path) then
                    local full = methodhandler('concatinators',variant,tag,vv,bname) or ""
                    result[#result+1] = resolve(full)
                    done = true
                    if not allresults then break end
                end
            end
        end
    end
    return done
end


local makewildcard = Cs(
    (P("^")^0 * P("/") * P(-1) + P(-1)) /".*"
  + (P("^")^0 * P("/") / "")^0 * (P("*")/".*" + P("-")/"%%-" + P(".")/"%%." + P("?")/"."+ P("\\")/"/" + P(1))^0
)

function resolvers.wildcardpattern(pattern)
    return lpegmatch(makewildcard,pattern) or pattern
end

local function findwildcardfiles(filename,allresults,result) -- todo: remap: and lpeg
    result = result or { }
    local base = filebasename(filename)
    local dirn = filedirname(filename)
    local path = lower(lpegmatch(makewildcard,dirn) or dirn)
    local name = lower(lpegmatch(makewildcard,base) or base)
    local files, done = instance.files, false
    if find(name,"%*") then
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            local hashname, hashtype = hash.name, hash.type
            for kk, hh in next, files[hashname] do
                if not find(kk,"^remap:") then
                    if find(lower(kk),name) then
                        if doit(path,hh,kk,hashname,hashtype,result,allresults) then done = true end
                        if done and not allresults then break end
                    end
                end
            end
        end
    else
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            local hashname, hashtype = hash.name, hash.type
            if doit(path,files[hashname][bname],bname,hashname,hashtype,result,allresults) then done = true end
            if done and not allresults then break end
        end
    end
    -- we can consider also searching the paths not in the database, but then
    -- we end up with a messy search (all // in all path specs)
    return result
end

function resolvers.findwildcardfiles(filename,result)
    return findwildcardfiles(filename,true,result)
end

function resolvers.findwildcardfile(filename)
    return findwildcardfiles(filename,false)[1] or ""
end

-- main user functions

function resolvers.automount()
    -- implemented later
end

function resolvers.load(option)
    statistics.starttiming(instance)
    identify_configuration_files()
    load_configuration_files()
    if option ~= "nofiles" then
        load_databases()
        resolvers.automount()
    end
    statistics.stoptiming(instance)
    local files = instance.files
    return files and next(files) and true
end

function resolvers.loadtime()
    return statistics.elapsedtime(instance)
end

local function report(str)
    if trace_locating then
        report_resolving(str) -- has already verbose
    else
        print(str)
    end
end

function resolvers.dowithfilesandreport(command, files, ...) -- will move
    if files and #files > 0 then
        if trace_locating then
            report('') -- ?
        end
        if type(files) == "string" then
            files = { files }
        end
        for f=1,#files do
            local file = files[f]
            local result = command(file,...)
            if type(result) == 'string' then
                report(result)
            else
                for i=1,#result do
                    report(result[i]) -- could be unpack
                end
            end
        end
    end
end

-- obsolete

-- resolvers.varvalue  = resolvers.variable   -- output the value of variable $STRING.
-- resolvers.expandvar = resolvers.expansion  -- output variable expansion of STRING.

function resolvers.showpath(str)     -- output search path for file type NAME
    return joinpath(resolvers.expandedpathlist(resolvers.formatofvariable(str)))
end

function resolvers.registerfile(files, name, path)
    if files[name] then
        if type(files[name]) == 'string' then
            files[name] = { files[name], path }
        else
            files[name] = path
        end
    else
        files[name] = path
    end
end

function resolvers.dowithpath(name,func)
    local pathlist = resolvers.expandedpathlist(name)
    for i=1,#pathlist do
        func("^"..resolvers.cleanpath(pathlist[i]))
    end
end

function resolvers.dowithvariable(name,func)
    func(expandedvariable(name))
end

function resolvers.locateformat(name)
    local barename = file.removesuffix(name) -- gsub(name,"%.%a+$","")
    local fmtname = caches.getfirstreadablefile(barename..".fmt","formats") or ""
    if fmtname == "" then
        fmtname = resolvers.findfile(barename..".fmt")
        fmtname = resolvers.cleanpath(fmtname)
    end
    if fmtname ~= "" then
        local barename = file.removesuffix(fmtname)
        local luaname, lucname, luiname = barename .. ".lua", barename .. ".luc", barename .. ".lui"
        if lfs.isfile(luiname) then
            return barename, luiname
        elseif lfs.isfile(lucname) then
            return barename, lucname
        elseif lfs.isfile(luaname) then
            return barename, luaname
        end
    end
    return nil, nil
end

function resolvers.booleanvariable(str,default)
    local b = resolvers.expansion(str)
    if b == "" then
        return default
    else
        b = toboolean(b)
        return (b == nil and default) or b
    end
end

function resolvers.dowithfilesintree(pattern,handle,before,after) -- will move, can be a nice iterator instead
    local instance = resolvers.instance
    local hashes = instance.hashes
    for i=1,#hashes do
        local hash = hashes[i]
        local blobtype = hash.type
        local blobpath = hash.name
        if blobpath then
            if before then
                before(blobtype,blobpath,pattern)
            end
            local files = instance.files[blobpath]
            local total, checked, done = 0, 0, 0
            if files then
                for k,v in next, files do
                    total = total + 1
                    if find(k,"^remap:") then
                        k = files[k]
                        v = k -- files[k] -- chained
                    end
                    if find(k,pattern) then
                        if type(v) == "string" then
                            checked = checked + 1
                            if handle(blobtype,blobpath,v,k) then
                                done = done + 1
                            end
                        else
                            checked = checked + #v
                            for i=1,#v do
                                if handle(blobtype,blobpath,v[i],k) then
                                    done = done + 1
                                end
                            end
                        end
                    end
                end
            end
            if after then
                after(blobtype,blobpath,pattern,total,checked,done)
            end
        end
    end
end

resolvers.obsolete = resolvers.obsolete or { }
local obsolete     = resolvers.obsolete

resolvers.find_file  = resolvers.findfile    obsolete.find_file  = resolvers.findfile
resolvers.find_files = resolvers.findfiles   obsolete.find_files = resolvers.findfiles


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-pre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- It could be interesting to hook the resolver in the file
-- opener so that unresolved prefixes travel around and we
-- get more abstraction.

-- As we use this beforehand we will move this up in the chain
-- of loading.


local resolvers    = resolvers
local prefixes     = utilities.storage.allocate()
resolvers.prefixes = prefixes

local gsub = string.gsub
local cleanpath, findgivenfile, expansion = resolvers.cleanpath, resolvers.findgivenfile, resolvers.expansion
local getenv = resolvers.getenv -- we can probably also use resolvers.expansion
local P, Cs, lpegmatch = lpeg.P, lpeg.Cs, lpeg.match

-- getenv = function(...) return resolvers.getenv(...) end -- needs checking (definitions changes later on)

prefixes.environment = function(str)
    return cleanpath(expansion(str))
end

prefixes.relative = function(str,n) -- lfs.isfile
    if io.exists(str) then
        -- nothing
    elseif io.exists("./" .. str) then
        str = "./" .. str
    else
        local p = "../"
        for i=1,n or 2 do
            if io.exists(p .. str) then
                str = p .. str
                break
            else
                p = p .. "../"
            end
        end
    end
    return cleanpath(str)
end

prefixes.auto = function(str)
    local fullname = prefixes.relative(str)
    if not lfs.isfile(fullname) then
        fullname = prefixes.locate(str)
    end
    return fullname
end

prefixes.locate = function(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath((fullname ~= "" and fullname) or str)
end

prefixes.filename = function(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath(file.basename((fullname ~= "" and fullname) or str)) -- no cleanpath needed here
end

prefixes.pathname = function(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath(file.dirname((fullname ~= "" and fullname) or str))
end

prefixes.selfautoloc = function(str)
    return cleanpath(file.join(getenv('SELFAUTOLOC'),str))
end

prefixes.selfautoparent = function(str)
    return cleanpath(file.join(getenv('SELFAUTOPARENT'),str))
end

prefixes.selfautodir = function(str)
    return cleanpath(file.join(getenv('SELFAUTODIR'),str))
end

prefixes.home = function(str)
    return cleanpath(file.join(getenv('HOME'),str))
end

prefixes.env  = prefixes.environment
prefixes.rel  = prefixes.relative
prefixes.loc  = prefixes.locate
prefixes.kpse = prefixes.locate
prefixes.full = prefixes.locate
prefixes.file = prefixes.filename
prefixes.path = prefixes.pathname

function resolvers.allprefixes(separator)
    local all = table.sortedkeys(prefixes)
    if separator then
        for i=1,#all do
            all[i] = all[i] .. ":"
        end
    end
    return all
end

local function _resolve_(method,target)
    local action = prefixes[method]
    if action then
        return action(target)
    else
        return method .. ":" .. target
    end
end

local resolved, abstract = { }, { }

function resolvers.resetresolve(str)
    resolved, abstract = { }, { }
end

local function resolve(str) -- use schemes, this one is then for the commandline only
    if type(str) == "table" then
        local t = { }
        for i=1,#str do
            t[i] = resolve(str[i])
        end
        return t
    else
        local res = resolved[str]
        if not res then
            res = gsub(str,"([a-z][a-z]+):([^ \"\';,]*)",_resolve_) -- home:xx;selfautoparent:xx; etc (comma added)
            resolved[str] = res
            abstract[res] = str
        end
        return res
    end
end

local function unresolve(str)
    return abstract[str] or str
end

resolvers.resolve   = resolve
resolvers.unresolve = unresolve

if os.uname then

    for k, v in next, os.uname() do
        if not prefixes[k] then
            prefixes[k] = function() return v end
        end
    end

end

if os.type == "unix" then

    local pattern

    local function makepattern(t,k,v)
        local colon = P(":")
        local p
        for k, v in table.sortedpairs(prefixes) do
            if p then
                p = P(k) + p
            else
                p = P(k)
            end
        end
        pattern = Cs((p * colon + colon/";" + P(1))^0)
        if t then
            t[k] = v
        end
    end

    makepattern()

    getmetatable(prefixes).__newindex = makepattern

    function resolvers.repath(str)
        return lpegmatch(pattern,str)
    end

else -- already the default:

    function resolvers.repath(str)
        return str
    end

end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-inp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local allocate  = utilities.storage.allocate
local resolvers = resolvers

local methodhandler  = resolvers.methodhandler
local registermethod = resolvers.registermethod

local finders = allocate { helpers = { }, notfound = function() end }
local openers = allocate { helpers = { }, notfound = function() end }
local loaders = allocate { helpers = { }, notfound = function() return false, nil, 0 end }

registermethod("finders", finders, "uri")
registermethod("openers", openers, "uri")
registermethod("loaders", loaders, "uri")

resolvers.finders = finders
resolvers.openers = openers
resolvers.loaders = loaders


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-out'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local allocate  = utilities.storage.allocate
local resolvers = resolvers

local registermethod = resolvers.registermethod

local savers = allocate { helpers = { } }

resolvers.savers = savers

registermethod("savers", savers, "uri")


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-fil'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_files = logs.reporter("resolvers","files")

local resolvers = resolvers

local finders, openers, loaders, savers = resolvers.finders, resolvers.openers, resolvers.loaders, resolvers.savers
local locators, hashers, generators, concatinators = resolvers.locators, resolvers.hashers, resolvers.generators, resolvers.concatinators

local checkgarbage = utilities.garbagecollector and utilities.garbagecollector.check

function locators.file(specification)
    local name = specification.filename
    local realname = resolvers.resolve(name) -- no shortcut
    if realname and realname ~= '' and lfs.isdir(realname) then
        if trace_locating then
            report_files("file locator '%s' found as '%s'",name,realname)
        end
        resolvers.appendhash('file',name,true) -- cache
    elseif trace_locating then
        report_files("file locator '%s' not found",name)
    end
end

function hashers.file(specification)
    local name = specification.filename
    local content = caches.loadcontent(name,'files')
    resolvers.registerfilehash(name,content,content==nil)
end

function generators.file(specification)
    local path = specification.filename
    local content = resolvers.scanfiles(path,false,true) -- scan once
    resolvers.registerfilehash(path,content,true)
end

concatinators.file = file.join

function finders.file(specification,filetype)
    local filename = specification.filename
    local foundname = resolvers.findfile(filename,filetype)
    if foundname and foundname ~= "" then
        if trace_locating then
            report_files("file finder: '%s' found",filename)
        end
        return foundname
    else
        if trace_locating then
            report_files("file finder: %s' not found",filename)
        end
        return finders.notfound()
    end
end

-- The default textopener will be overloaded later on.

function openers.helpers.textopener(tag,filename,f)
    return {
        reader = function()                           return f:read () end,
        close  = function() logs.show_close(filename) return f:close() end,
    }
end

function openers.file(specification,filetype)
    local filename = specification.filename
    if filename and filename ~= "" then
        local f = io.open(filename,"r")
        if f then
            if trace_locating then
                report_files("file opener, '%s' opened",filename)
            end
            return openers.helpers.textopener("file",filename,f)
        end
    end
    if trace_locating then
        report_files("file opener, '%s' not found",filename)
    end
    return openers.notfound()
end

function loaders.file(specification,filetype)
    local filename = specification.filename
    if filename and filename ~= "" then
        local f = io.open(filename,"rb")
        if f then
            logs.show_load(filename)
            if trace_locating then
                report_files("file loader, '%s' loaded",filename)
            end
            local s = f:read("*a")
            if checkgarbage then
                checkgarbage(#s)
            end
            f:close()
            if s then
                return true, s, #s
            end
        end
    end
    if trace_locating then
        report_files("file loader, '%s' not found",filename)
    end
    return loaders.notfound()
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-con'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, lower, gsub = string.format, string.lower, string.gsub

local trace_cache      = false  trackers.register("resolvers.cache",      function(v) trace_cache      = v end)
local trace_containers = false  trackers.register("resolvers.containers", function(v) trace_containers = v end)
local trace_storage    = false  trackers.register("resolvers.storage",    function(v) trace_storage    = v end)

--[[ldx--
<p>Once we found ourselves defining similar cache constructs
several times, containers were introduced. Containers are used
to collect tables in memory and reuse them when possible based
on (unique) hashes (to be provided by the calling function).</p>

<p>Caching to disk is disabled by default. Version numbers are
stored in the saved table which makes it possible to change the
table structures without bothering about the disk cache.</p>

<p>Examples of usage can be found in the font related code.</p>
--ldx]]--

containers          = containers or { }
local containers    = containers
containers.usecache = true

local report_containers = logs.reporter("resolvers","containers")

local function report(container,tag,name)
    if trace_cache or trace_containers then
        report_containers("container: %s, tag: %s, name: %s",container.subcategory,tag,name or 'invalid')
    end
end

local allocated = { }

local mt = {
    __index = function(t,k)
        if k == "writable" then
            local writable = caches.getwritablepath(t.category,t.subcategory) or { "." }
            t.writable = writable
            return writable
        elseif k == "readables" then
            local readables = caches.getreadablepaths(t.category,t.subcategory) or { "." }
            t.readables = readables
            return readables
        end
    end,
    __storage__ = true
}

function containers.define(category, subcategory, version, enabled)
    if category and subcategory then
        local c = allocated[category]
        if not c then
            c  = { }
            allocated[category] = c
        end
        local s = c[subcategory]
        if not s then
            s = {
                category    = category,
                subcategory = subcategory,
                storage     = { },
                enabled     = enabled,
                version     = version or math.pi, -- after all, this is TeX
                trace       = false,
             -- writable    = caches.getwritablepath  and caches.getwritablepath (category,subcategory) or { "." },
             -- readables   = caches.getreadablepaths and caches.getreadablepaths(category,subcategory) or { "." },
            }
            setmetatable(s,mt)
            c[subcategory] = s
        end
        return s
    end
end

function containers.is_usable(container, name)
    return container.enabled and caches and caches.is_writable(container.writable, name)
end

function containers.is_valid(container, name)
    if name and name ~= "" then
        local storage = container.storage[name]
        return storage and storage.cache_version == container.version
    else
        return false
    end
end

function containers.read(container,name)
    local storage = container.storage
    local stored = storage[name]
    if not stored and container.enabled and caches and containers.usecache then
        stored = caches.loaddata(container.readables,name)
        if stored and stored.cache_version == container.version then
            report(container,"loaded",name)
        else
            stored = nil
        end
        storage[name] = stored
    elseif stored then
        report(container,"reusing",name)
    end
    return stored
end

function containers.write(container, name, data)
    if data then
        data.cache_version = container.version
        if container.enabled and caches then
            local unique, shared = data.unique, data.shared
            data.unique, data.shared = nil, nil
            caches.savedata(container.writable, name, data)
            report(container,"saved",name)
            data.unique, data.shared = unique, shared
        end
        report(container,"stored",name)
        container.storage[name] = data
    end
    return data
end

function containers.content(container,name)
    return container.storage[name]
end

function containers.cleanname(name)
    return (gsub(lower(name),"[^%w%d]+","-"))
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-use'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, lower, gsub, find = string.format, string.lower, string.gsub, string.find

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_mounts = logs.reporter("resolvers","mounts")

local resolvers = resolvers

-- we will make a better format, maybe something xml or just text or lua

resolvers.automounted = resolvers.automounted or { }

function resolvers.automount(usecache)
    local mountpaths = resolvers.cleanpathlist(resolvers.expansion('TEXMFMOUNT'))
    if (not mountpaths or #mountpaths == 0) and usecache then
        mountpaths = caches.getreadablepaths("mount")
    end
    if mountpaths and #mountpaths > 0 then
        statistics.starttiming(resolvers.instance)
        for k=1,#mountpaths do
            local root = mountpaths[k]
            local f = io.open(root.."/url.tmi")
            if f then
                for line in f:lines() do
                    if line then
                        if find(line,"^[%%#%-]") then -- or %W
                            -- skip
                        elseif find(line,"^zip://") then
                            if trace_locating then
                                report_mounts("mounting %s",line)
                            end
                            table.insert(resolvers.automounted,line)
                            resolvers.usezipfile(line)
                        end
                    end
                end
                f:close()
            end
        end
        statistics.stoptiming(resolvers.instance)
    end
end

-- status info

statistics.register("used config file", function() return caches.configfiles() end)
statistics.register("used cache path",  function() return caches.usedpaths() end)

-- experiment (code will move)

function statistics.savefmtstatus(texname,formatbanner,sourcefile) -- texname == formatname
    local enginebanner = status.list().banner
    if formatbanner and enginebanner and sourcefile then
        local luvname = file.replacesuffix(texname,"luv")
        local luvdata = {
            enginebanner = enginebanner,
            formatbanner = formatbanner,
            sourcehash   = md5.hex(io.loaddata(resolvers.findfile(sourcefile)) or "unknown"),
            sourcefile   = sourcefile,
        }
        io.savedata(luvname,table.serialize(luvdata,true))
    end
end

function statistics.checkfmtstatus(texname)
    local enginebanner = status.list().banner
    if enginebanner and texname then
        local luvname = file.replacesuffix(texname,"luv")
        if lfs.isfile(luvname) then
            local luv = dofile(luvname)
            if luv and luv.sourcefile then
                local sourcehash = md5.hex(io.loaddata(resolvers.findfile(luv.sourcefile)) or "unknown")
                local luvbanner = luv.enginebanner or "?"
                if luvbanner ~= enginebanner then
                    return format("engine mismatch (luv: %s <> bin: %s)",luvbanner,enginebanner)
                end
                local luvhash = luv.sourcehash or "?"
                if luvhash ~= sourcehash then
                    return format("source mismatch (luv: %s <> bin: %s)",luvhash,sourcehash)
                end
            else
                return "invalid status file"
            end
        else
            return "missing status file"
        end
    end
    return true
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-zip'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- partly redone .. needs testing

local format, find, match = string.format, string.find, string.match

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_zip = logs.reporter("resolvers","zip")

-- zip:///oeps.zip?name=bla/bla.tex
-- zip:///oeps.zip?tree=tex/texmf-local
-- zip:///texmf.zip?tree=/tex/texmf
-- zip:///texmf.zip?tree=/tex/texmf-local
-- zip:///texmf-mine.zip?tree=/tex/texmf-projects

local resolvers = resolvers

zip                   = zip or { }
local zip             = zip

zip.archives          = zip.archives or { }
local archives        = zip.archives

zip.registeredfiles   = zip.registeredfiles or { }
local registeredfiles = zip.registeredfiles

local limited = false

directives.register("system.inputmode", function(v)
    if not limited then
        local i_limiter = io.i_limiter(v)
        if i_limiter then
            zip.open = i_limiter.protect(zip.open)
            limited = true
        end
    end
end)

local function validzip(str) -- todo: use url splitter
    if not find(str,"^zip://") then
        return "zip:///" .. str
    else
        return str
    end
end

function zip.openarchive(name)
    if not name or name == "" then
        return nil
    else
        local arch = archives[name]
        if not arch then
           local full = resolvers.findfile(name) or ""
           arch = (full ~= "" and zip.open(full)) or false
           archives[name] = arch
        end
       return arch
    end
end

function zip.closearchive(name)
    if not name or (name == "" and archives[name]) then
        zip.close(archives[name])
        archives[name] = nil
    end
end

function resolvers.locators.zip(specification)
    local archive = specification.filename
    local zipfile = archive and archive ~= "" and zip.openarchive(archive) -- tricky, could be in to be initialized tree
    if trace_locating then
        if zipfile then
            report_zip("locator, archive '%s' found",archive)
        else
            report_zip("locator, archive '%s' not found",archive)
        end
    end
end

function resolvers.hashers.zip(specification)
    local archive = specification.filename
    if trace_locating then
        report_zip("loading file '%s'",archive)
    end
    resolvers.usezipfile(specification.original)
end

function resolvers.concatinators.zip(zipfile,path,name) -- ok ?
    if not path or path == "" then
        return format('%s?name=%s',zipfile,name)
    else
        return format('%s?name=%s/%s',zipfile,path,name)
    end
end

function resolvers.finders.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_zip("finder, archive '%s' found",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    dfile = zfile:close()
                    if trace_locating then
                        report_zip("finder, file '%s' found",queryname)
                    end
                    return specification.original
                elseif trace_locating then
                    report_zip("finder, file '%s' not found",queryname)
                end
            elseif trace_locating then
                report_zip("finder, unknown archive '%s'",archive)
            end
        end
    end
    if trace_locating then
        report_zip("finder, '%s' not found",original)
    end
    return resolvers.finders.notfound()
end

function resolvers.openers.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_zip("opener, archive '%s' opened",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    if trace_locating then
                        report_zip("opener, file '%s' found",queryname)
                    end
                    return resolvers.openers.helpers.textopener('zip',original,dfile)
                elseif trace_locating then
                    report_zip("opener, file '%s' not found",queryname)
                end
            elseif trace_locating then
                report_zip("opener, unknown archive '%s'",archive)
            end
        end
    end
    if trace_locating then
        report_zip("opener, '%s' not found",original)
    end
    return resolvers.openers.notfound()
end

function resolvers.loaders.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_zip("loader, archive '%s' opened",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    logs.show_load(original)
                    if trace_locating then
                        report_zip("loader, file '%s' loaded",original)
                    end
                    local s = dfile:read("*all")
                    dfile:close()
                    return true, s, #s
                elseif trace_locating then
                    report_zip("loader, file '%s' not found",queryname)
                end
            elseif trace_locating then
                report_zip("loader, unknown archive '%s'",archive)
            end
        end
    end
    if trace_locating then
        report_zip("loader, '%s' not found",original)
    end
    return resolvers.openers.notfound()
end

-- zip:///somefile.zip
-- zip:///somefile.zip?tree=texmf-local -> mount

function resolvers.usezipfile(archive)
    local specification = resolvers.splitmethod(archive) -- to be sure
    local archive = specification.filename
    if archive and not registeredfiles[archive] then
        local z = zip.openarchive(archive)
        if z then
            local instance = resolvers.instance
            local tree = url.query(specification.query).tree or ""
            if trace_locating then
                report_zip("registering, registering archive '%s'",archive)
            end
            statistics.starttiming(instance)
            resolvers.prependhash('zip',archive)
            resolvers.extendtexmfvariable(archive) -- resets hashes too
            registeredfiles[archive] = z
            instance.files[archive] = resolvers.registerzipfile(z,tree)
            statistics.stoptiming(instance)
        elseif trace_locating then
            report_zip("registering, unknown archive '%s'",archive)
        end
    elseif trace_locating then
        report_zip("registering, '%s' not found",archive)
    end
end

function resolvers.registerzipfile(z,tree)
    local files, filter = { }, ""
    if tree == "" then
        filter = "^(.+)/(.-)$"
    else
        filter = format("^%s/(.+)/(.-)$",tree)
    end
    if trace_locating then
        report_zip("registering, using filter '%s'",filter)
    end
    local register, n = resolvers.registerfile, 0
    for i in z:files() do
        local path, name = match(i.filename,filter)
        if path then
            if name and name ~= '' then
                register(files, name, path)
                n = n + 1
            else
                -- directory
            end
        else
            register(files, i.filename, '')
            n = n + 1
        end
    end
    report_zip("registering, %s files registered",n)
    return files
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-tre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- \input tree://oeps1/**/oeps.tex

local find, gsub, format = string.find, string.gsub, string.format

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_trees = logs.reporter("resolvers","trees")

local resolvers = resolvers

local done, found, notfound = { }, { }, resolvers.finders.notfound

function resolvers.finders.tree(specification)
    local spec = specification.filename
    local fnd = found[spec]
    if fnd == nil then
        if spec ~= "" then
            local path, name = file.dirname(spec), file.basename(spec)
            if path == "" then path = "." end
            local hash = done[path]
            if not hash then
                local pattern = path .. "/*" -- we will use the proper splitter
                hash = dir.glob(pattern)
                done[path] = hash
            end
            local pattern = "/" .. gsub(name,"([%.%-%+])", "%%%1") .. "$"
            for k=1,#hash do
                local v = hash[k]
                if find(v,pattern) then
                    found[spec] = v
                    return v
                end
            end
        end
        fnd = notfound() -- false
        found[spec] = fnd
    end
    return fnd
end

function resolvers.locators.tree(specification)
    local name = specification.filename
    local realname = resolvers.resolve(name) -- no shortcut
    if realname and realname ~= '' and lfs.isdir(realname) then
        if trace_locating then
            report_trees("locator '%s' found",realname)
        end
        resolvers.appendhash('tree',name,false) -- don't cache
    elseif trace_locating then
        report_trees("locator '%s' not found",name)
    end
end

function resolvers.hashers.tree(specification)
    local name = specification.filename
    if trace_locating then
        report_trees("analysing '%s'",name)
    end
    resolvers.methodhandler("hashers",name)

    resolvers.generators.file(specification)
end

resolvers.concatinators.tree = resolvers.concatinators.file
resolvers.generators.tree    = resolvers.generators.file
resolvers.openers.tree       = resolvers.openers.file
resolvers.loaders.tree       = resolvers.loaders.file


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-crl'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this one is replaced by data-sch.lua --

local gsub = string.gsub

local resolvers = resolvers

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders

resolvers.curl = resolvers.curl or { }
local curl     = resolvers.curl

local cached = { }

local function runcurl(specification)
    local original  = specification.original
 -- local scheme    = specification.scheme
    local cleanname = gsub(original,"[^%a%d%.]+","-")
    local cachename = caches.setfirstwritablefile(cleanname,"curl")
    if not cached[original] then
        if not io.exists(cachename) then
            cached[original] = cachename
            local command = "curl --silent --create-dirs --output " .. cachename .. " " .. original
            os.spawn(command)
        end
        if io.exists(cachename) then
            cached[original] = cachename
        else
            cached[original] = ""
        end
    end
    return cached[original]
end

-- old code: we could be cleaner using specification (see schemes)

local function finder(specification,filetype)
    return resolvers.methodhandler("finders",runcurl(specification),filetype)
end

local opener = openers.file
local loader = loaders.file

local function install(scheme)
    finders[scheme] = finder
    openers[scheme] = opener
    loaders[scheme] = loader
end

resolvers.curl.install = install

install('http')
install('https')
install('ftp')


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- some loading stuff ... we might move this one to slot 2 depending
-- on the developments (the loaders must not trigger kpse); we could
-- of course use a more extensive lib path spec

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_libraries = logs.reporter("resolvers","libraries")

local gsub, insert = string.gsub, table.insert
local unpack = unpack or table.unpack

local resolvers, package = resolvers, package

local  libformats = { 'luatexlibs', 'tex', 'texmfscripts', 'othertextfiles' } -- 'luainputs'
local clibformats = { 'lib' }

local _path_, libpaths, _cpath_, clibpaths

function package.libpaths()
    if not _path_ or package.path ~= _path_ then
        _path_ = package.path
        libpaths = file.splitpath(_path_,";")
    end
    return libpaths
end

function package.clibpaths()
    if not _cpath_ or package.cpath ~= _cpath_ then
        _cpath_ = package.cpath
        clibpaths = file.splitpath(_cpath_,";")
    end
    return clibpaths
end

local function thepath(...)
    local t = { ... } t[#t+1] = "?.lua"
    local path = file.join(unpack(t))
    if trace_locating then
        report_libraries("! appending '%s' to 'package.path'",path)
    end
    return path
end

local p_libpaths, a_libpaths = { }, { }

function package.appendtolibpath(...)
    insert(a_libpath,thepath(...))
end

function package.prependtolibpath(...)
    insert(p_libpaths,1,thepath(...))
end

-- beware, we need to return a loadfile result !

local function loaded(libpaths,name,simple)
    for i=1,#libpaths do -- package.path, might become option
        local libpath = libpaths[i]
        local resolved = gsub(libpath,"%?",simple)
        if trace_locating then -- more detail
            report_libraries("! checking for '%s' on 'package.path': '%s' => '%s'",simple,libpath,resolved)
        end
        if file.is_readable(resolved) then
            if trace_locating then
                report_libraries("! lib '%s' located via 'package.path': '%s'",name,resolved)
            end
            return loadfile(resolved)
        end
    end
end

package.loaders[2] = function(name) -- was [#package.loaders+1]
    if file.suffix(name) == "" then
        name = file.addsuffix(name,"lua") -- maybe a list
        if trace_locating then -- mode detail
            report_libraries("! locating '%s' with forced suffix",name)
        end
    else
        if trace_locating then -- mode detail
            report_libraries("! locating '%s'",name)
        end
    end
    for i=1,#libformats do
        local format = libformats[i]
        local resolved = resolvers.findfile(name,format) or ""
        if trace_locating then -- mode detail
            report_libraries("! checking for '%s' using 'libformat path': '%s'",name,format)
        end
        if resolved ~= "" then
            if trace_locating then
                report_libraries("! lib '%s' located via environment: '%s'",name,resolved)
            end
            return loadfile(resolved)
        end
    end
    -- libpaths
    local libpaths, clibpaths = package.libpaths(), package.clibpaths()
    local simple = gsub(name,"%.lua$","")
    local simple = gsub(simple,"%.","/")
    local resolved = loaded(p_libpaths,name,simple) or loaded(libpaths,name,simple) or loaded(a_libpaths,name,simple)
    if resolved then
        return resolved
    end
    --
    local libname = file.addsuffix(simple,os.libsuffix)
    for i=1,#clibformats do
        -- better have a dedicated loop
        local format = clibformats[i]
        local paths = resolvers.expandedpathlistfromvariable(format)
        for p=1,#paths do
            local path = paths[p]
            local resolved = file.join(path,libname)
            if trace_locating then -- mode detail
                report_libraries("! checking for '%s' using 'clibformat path': '%s'",libname,path)
            end
            if file.is_readable(resolved) then
                if trace_locating then
                    report_libraries("! lib '%s' located via 'clibformat': '%s'",libname,resolved)
                end
                return package.loadlib(resolved,name)
            end
        end
    end
    for i=1,#clibpaths do -- package.path, might become option
        local libpath = clibpaths[i]
        local resolved = gsub(libpath,"?",simple)
        if trace_locating then -- more detail
            report_libraries("! checking for '%s' on 'package.cpath': '%s'",simple,libpath)
        end
        if file.is_readable(resolved) then
            if trace_locating then
                report_libraries("! lib '%s' located via 'package.cpath': '%s'",name,resolved)
            end
            return package.loadlib(resolved,name)
        end
    end
    -- just in case the distribution is messed up
    if trace_loading then -- more detail
        report_libraries("! checking for '%s' using 'luatexlibs': '%s'",name)
    end
    local resolved = resolvers.findfile(file.basename(name),'luatexlibs') or ""
    if resolved ~= "" then
        if trace_locating then
            report_libraries("! lib '%s' located by basename via environment: '%s'",name,resolved)
        end
        return loadfile(resolved)
    end
    if trace_locating then
        report_libraries('? unable to locate lib: %s',name)
    end
--  return "unable to locate " .. name
end

resolvers.loadlualib = require

-- -- -- --

package.obsolete = package.obsolete or { }

package.append_libpath           = appendtolibpath   -- will become obsolete
package.prepend_libpath          = prependtolibpath  -- will become obsolete

package.obsolete.append_libpath  = appendtolibpath   -- will become obsolete
package.obsolete.prepend_libpath = prependtolibpath  -- will become obsolete


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-aux'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find
local type, next = type, next

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local resolvers = resolvers

local report_scripts = logs.reporter("resolvers","scripts")

function resolvers.updatescript(oldname,newname) -- oldname -> own.name, not per se a suffix
    local scriptpath = "scripts/context/lua"
    newname = file.addsuffix(newname,"lua")
    local oldscript = resolvers.cleanpath(oldname)
    if trace_locating then
        report_scripts("to be replaced old script %s", oldscript)
    end
    local newscripts = resolvers.findfiles(newname) or { }
    if #newscripts == 0 then
        if trace_locating then
            report_scripts("unable to locate new script")
        end
    else
        for i=1,#newscripts do
            local newscript = resolvers.cleanpath(newscripts[i])
            if trace_locating then
                report_scripts("checking new script %s", newscript)
            end
            if oldscript == newscript then
                if trace_locating then
                    report_scripts("old and new script are the same")
                end
            elseif not find(newscript,scriptpath) then
                if trace_locating then
                    report_scripts("new script should come from %s",scriptpath)
                end
            elseif not (find(oldscript,file.removesuffix(newname).."$") or find(oldscript,newname.."$")) then
                if trace_locating then
                    report_scripts("invalid new script name")
                end
            else
                local newdata = io.loaddata(newscript)
                if newdata then
                    if trace_locating then
                        report_scripts("old script content replaced by new content")
                    end
                    io.savedata(oldscript,newdata)
                    break
                elseif trace_locating then
                    report_scripts("unable to load new script")
                end
            end
        end
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-tmf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local resolvers = resolvers

local report_tds = logs.reporter("resolvers","tds")

--  =  <<
--  ?  ??
--  <  +=
--  >  =+

function resolvers.load_tree(tree,resolve)
    if type(tree) == "string" and tree ~= "" then

        local getenv, setenv = resolvers.getenv, resolvers.setenv

        -- later might listen to the raw osenv var as well
        local texos   = "texmf-" .. os.platform

        local oldroot = environment.texroot
        local newroot = file.collapsepath(tree)

        local newtree = file.join(newroot,texos)
        local newpath = file.join(newtree,"bin")

        if not lfs.isdir(newtree) then
            report_tds("no '%s' under tree %s",texos,tree)
            os.exit()
        end
        if not lfs.isdir(newpath) then
            report_tds("no '%s/bin' under tree %s",texos,tree)
            os.exit()
        end

        local texmfos = newtree

        environment.texroot = newroot
        environment.texos   = texos
        environment.texmfos = texmfos

        -- Beware, we need to obey the relocatable autoparent so we
        -- set TEXMFCNF to its raw value. This is somewhat tricky when
        -- we run a mkii job from within. Therefore, in mtxrun, there
        -- is a resolve applied when we're in mkii/kpse mode or when
        -- --resolve is passed to mtxrun. Maybe we should also set the
        -- local AUTOPARENT etc. although these are alwasy set new.

        if resolve then
         -- resolvers.luacnfspec = resolvers.joinpath(resolvers.resolve(resolvers.expandedpathfromlist(resolvers.splitpath(resolvers.luacnfspec))))
            resolvers.luacnfspec = resolvers.resolve(resolvers.luacnfspec)
        end

        setenv('SELFAUTOPARENT', newroot)
        setenv('SELFAUTODIR',    newtree)
        setenv('SELFAUTOLOC',    newpath)
        setenv('TEXROOT',        newroot)
        setenv('TEXOS',          texos)
        setenv('TEXMFOS',        texmfos)
        setenv('TEXMFCNF',       resolvers.luacnfspec,true) -- already resolved
        setenv('PATH',           newpath .. io.pathseparator .. getenv('PATH'))

        report_tds("changing from root '%s' to '%s'",oldroot,newroot)
        report_tds("prepending '%s' to PATH",newpath)
        report_tds("setting TEXMFCNF to '%s'",resolvers.luacnfspec)
        report_tds()
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-lst'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- used in mtxrun, can be loaded later .. todo

local find, concat, upper, format = string.find, table.concat, string.upper, string.format
local fastcopy, sortedpairs = table.fastcopy, table.sortedpairs

resolvers.listers = resolvers.listers or { }

local resolvers = resolvers

local report_lists = logs.reporter("resolvers","lists")

local function tabstr(str)
    if type(str) == 'table' then
        return concat(str," | ")
    else
        return str
    end
end

function resolvers.listers.variables(pattern)
    local instance    = resolvers.instance
    local environment = instance.environment
    local variables   = instance.variables
    local expansions  = instance.expansions
    local pattern     = upper(pattern or "")
    local configured  = { }
    local order       = instance.order
    for i=1,#order do
        for k, v in next, order[i] do
            if v ~= nil and configured[k] == nil then
                configured[k] = v
            end
        end
    end
    local env = fastcopy(environment)
    local var = fastcopy(variables)
    local exp = fastcopy(expansions)
    for key, value in sortedpairs(configured) do
        if key ~= "" and (pattern == "" or find(upper(key),pattern)) then
            report_lists(key)
            report_lists("  env: %s",tabstr(rawget(environment,key))    or "unset")
            report_lists("  var: %s",tabstr(configured[key])            or "unset")
            report_lists("  exp: %s",tabstr(expansions[key])            or "unset")
            report_lists("  res: %s",tabstr(resolvers.resolve(expansions[key])) or "unset")
        end
    end
    instance.environment = fastcopy(env)
    instance.variables   = fastcopy(var)
    instance.expansions  = fastcopy(exp)
end

function resolvers.listers.configurations(report)
    local configurations = resolvers.instance.specification
    local report = report or texio.write_nl
    for i=1,#configurations do
        report(format("file : %s",resolvers.resolve(configurations[i])))
    end
    report("")
    local list = resolvers.expandedpathfromlist(resolvers.splitpath(resolvers.luacnfspec))
    for i=1,#list do
        local li = resolvers.resolve(list[i])
        if lfs.isdir(li) then
            report(format("path - %s",li))
        else
            report(format("path + %s",li))
        end
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['luat-sta'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code is used in the updater

local gmatch, match = string.gmatch, string.match
local type = type

states          = states or { }
local states    = states

states.data     = states.data or { }
local data      = states.data

states.hash     = states.hash or { }
local hash      = states.hash

states.tag      = states.tag      or ""
states.filename = states.filename or ""

function states.save(filename,tag)
    tag = tag or states.tag
    filename = file.addsuffix(filename or states.filename,'lus')
    io.savedata(filename,
        "-- generator : luat-sta.lua\n" ..
        "-- state tag : " .. tag .. "\n\n" ..
        table.serialize(data[tag or states.tag] or {},true)
    )
end

function states.load(filename,tag)
    states.filename = filename
    states.tag = tag or "whatever"
    states.filename = file.addsuffix(states.filename,'lus')
    data[states.tag], hash[states.tag] = (io.exists(filename) and dofile(filename)) or { }, { }
end

local function set_by_tag(tag,key,value,default,persistent)
    local d, h = data[tag], hash[tag]
    if d then
        if type(d) == "table" then
            local dkey, hkey = key, key
            local pre, post = match(key,"(.+)%.([^%.]+)$")
            if pre and post then
                for k in gmatch(pre,"[^%.]+") do
                    local dk = d[k]
                    if not dk then
                        dk = { }
                        d[k] = dk
                    elseif type(dk) == "string" then
                        -- invalid table, unable to upgrade structure
                        -- hope for the best or delete the state file
                        break
                    end
                    d = dk
                end
                dkey, hkey = post, key
            end
            if value == nil then
                value = default
            elseif value == false then
                -- special case
            elseif persistent then
                value = value or d[dkey] or default
            else
                value = value or default
            end
            d[dkey], h[hkey] = value, value
        elseif type(d) == "string" then
            -- weird
            data[tag], hash[tag] = value, value
        end
    end
end

local function get_by_tag(tag,key,default)
    local h = hash[tag]
    if h and h[key] then
        return h[key]
    else
        local d = data[tag]
        if d then
            for k in gmatch(key,"[^%.]+") do
                local dk = d[k]
                if dk ~= nil then
                    d = dk
                else
                    return default
                end
            end
            if d == false then
                return false
            else
                return d or default
            end
        end
    end
end

states.set_by_tag = set_by_tag
states.get_by_tag = get_by_tag

function states.set(key,value,default,persistent)
    set_by_tag(states.tag,key,value,default,persistent)
end

function states.get(key,default)
    return get_by_tag(states.tag,key,default)
end





end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['luat-fmt'] = {
    version   = 1.001,
    comment   = "companion to mtxrun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


local format = string.format

local report_format = logs.reporter("resolvers","formats")

-- helper for mtxrun

local quoted = string.quoted

local function primaryflags() -- not yet ok
    local trackers   = environment.argument("trackers")
    local directives = environment.argument("directives")
    local flags = ""
    if trackers and trackers ~= "" then
        flags = flags .. "--trackers=" .. quoted(trackers)
    end
    if directives and directives ~= "" then
        flags = flags .. "--directives=" .. quoted(directives)
    end
    return flags
end

function environment.make_format(name)
    -- change to format path (early as we need expanded paths)
    local olddir = lfs.currentdir()
    local path = caches.getwritablepath("formats") or "" -- maybe platform
    if path ~= "" then
        lfs.chdir(path)
    end
    report_format("format path: %s",lfs.currentdir())
    -- check source file
    local texsourcename = file.addsuffix(name,"mkiv")
    local fulltexsourcename = resolvers.findfile(texsourcename,"tex") or ""
    if fulltexsourcename == "" then
        texsourcename = file.addsuffix(name,"tex")
        fulltexsourcename = resolvers.findfile(texsourcename,"tex") or ""
    end
    if fulltexsourcename == "" then
        report_format("no tex source file with name: %s (mkiv or tex)",name)
        lfs.chdir(olddir)
        return
    else
        report_format("using tex source file: %s",fulltexsourcename)
    end
    local texsourcepath = dir.expandname(file.dirname(fulltexsourcename)) -- really needed
    -- check specification
    local specificationname = file.replacesuffix(fulltexsourcename,"lus")
    local fullspecificationname = resolvers.findfile(specificationname,"tex") or ""
    if fullspecificationname == "" then
        specificationname = file.join(texsourcepath,"context.lus")
        fullspecificationname = resolvers.findfile(specificationname,"tex") or ""
    end
    if fullspecificationname == "" then
        report_format("unknown stub specification: %s",specificationname)
        lfs.chdir(olddir)
        return
    end
    local specificationpath = file.dirname(fullspecificationname)
    -- load specification
    local usedluastub = nil
    local usedlualibs = dofile(fullspecificationname)
    if type(usedlualibs) == "string" then
        usedluastub = file.join(file.dirname(fullspecificationname),usedlualibs)
    elseif type(usedlualibs) == "table" then
        report_format("using stub specification: %s",fullspecificationname)
        local texbasename = file.basename(name)
        local luastubname = file.addsuffix(texbasename,"lua")
        local lucstubname = file.addsuffix(texbasename,"luc")
        -- pack libraries in stub
        report_format("creating initialization file: %s",luastubname)
        utilities.merger.selfcreate(usedlualibs,specificationpath,luastubname)
        -- compile stub file (does not save that much as we don't use this stub at startup any more)
        local strip = resolvers.booleanvariable("LUACSTRIP", true)
        if utilities.lua.compile(luastubname,lucstubname) and lfs.isfile(lucstubname) then
            report_format("using compiled initialization file: %s",lucstubname)
            usedluastub = lucstubname
        else
            report_format("using uncompiled initialization file: %s",luastubname)
            usedluastub = luastubname
        end
    else
        report_format("invalid stub specification: %s",fullspecificationname)
        lfs.chdir(olddir)
        return
    end
    -- generate format
    local command = format("luatex --ini %s --lua=%s %s %sdump",primaryflags(),quoted(usedluastub),quoted(fulltexsourcename),os.platform == "unix" and "\\\\" or "\\")
    report_format("running command: %s\n",command)
    os.spawn(command)
    -- remove related mem files
    local pattern = file.removesuffix(file.basename(usedluastub)).."-*.mem"
 -- report_format("removing related mplib format with pattern '%s'", pattern)
    local mp = dir.glob(pattern)
    if mp then
        for i=1,#mp do
            local name = mp[i]
            report_format("removing related mplib format %s", file.basename(name))
            os.remove(name)
        end
    end
    lfs.chdir(olddir)
end

function environment.run_format(name,data,more)
 -- hm, rather old code here; we can now use the file.whatever functions
    if name and name ~= "" then
        local barename = file.removesuffix(name)
        local fmtname = caches.getfirstreadablefile(file.addsuffix(barename,"fmt"),"formats")
        if fmtname == "" then
            fmtname = resolvers.findfile(file.addsuffix(barename,"fmt")) or ""
        end
        fmtname = resolvers.cleanpath(fmtname)
        if fmtname == "" then
            report_format("no format with name: %s",name)
        else
            local barename = file.removesuffix(name) -- expanded name
            local luaname = file.addsuffix(barename,"luc")
            if not lfs.isfile(luaname) then
                luaname = file.addsuffix(barename,"lua")
            end
            if not lfs.isfile(luaname) then
                report_format("using format name: %s",fmtname)
                report_format("no luc/lua with name: %s",barename)
            else
                local command = format("luatex %s --fmt=%s --lua=%s %s %s",primaryflags(),quoted(barename),quoted(luaname),quoted(data),more ~= "" and quoted(more) or "")
                report_format("running command: %s",command)
                os.spawn(command)
            end
        end
    end
end


end -- of closure
-- end library merge

own = { } -- not local, might change

own.libs = { -- order can be made better

    'l-string.lua',
    'l-table.lua',
    'l-lpeg.lua',
    'l-io.lua',
    'l-number.lua',
    'l-set.lua',
    'l-os.lua',
    'l-file.lua',
    'l-md5.lua',
    'l-url.lua',
    'l-dir.lua',
    'l-boolean.lua',
    'l-unicode.lua',
    'l-math.lua',

    'util-tab.lua',
    'util-sto.lua',
    'util-mrg.lua',
    'util-lua.lua',
    'util-prs.lua',
    'util-fmt.lua',
    'util-deb.lua',

    'trac-inf.lua',
    'trac-set.lua',
    'trac-log.lua',
    'trac-pro.lua',

    'luat-env.lua', -- can come before inf (as in mkiv)

    'lxml-tab.lua',
    'lxml-lpt.lua',
 -- 'lxml-ent.lua',
    'lxml-mis.lua',
    'lxml-aux.lua',
    'lxml-xml.lua',

    'data-ini.lua',
    'data-exp.lua',
    'data-env.lua',
    'data-tmp.lua',
    'data-met.lua',
    'data-res.lua',
    'data-pre.lua',
    'data-inp.lua',
    'data-out.lua',
    'data-fil.lua',
    'data-con.lua',
    'data-use.lua',
--  'data-tex.lua',
--  'data-bin.lua',
    'data-zip.lua',
    'data-tre.lua',
    'data-crl.lua',
    'data-lua.lua',
    'data-aux.lua', -- updater
    'data-tmf.lua',
    'data-lst.lua',

    'luat-sta.lua',
    'luat-fmt.lua',
}

-- We need this hack till luatex is fixed.
--
-- for k,v in pairs(arg) do print(k,v) end

if arg and (arg[0] == 'luatex' or arg[0] == 'luatex.exe') and arg[1] == "--luaonly" then
    arg[-1]=arg[0] arg[0]=arg[2] for k=3,#arg do arg[k-2]=arg[k] end arg[#arg]=nil arg[#arg]=nil
end

-- End of hack.

local format, gsub, gmatch, match, find = string.format, string.gsub, string.gmatch, string.match, string.find
local concat = table.concat

own.name = (environment and environment.ownname) or arg[0] or 'mtxrun.lua'
own.path = gsub(match(own.name,"^(.+)[\\/].-$") or ".","\\","/")

local ownpath, owntree = own.path, environment and environment.ownpath or own.path

own.list = {
    '.',
    ownpath ,
    ownpath .. "/../sources", -- HH's development path
    owntree .. "/../../texmf-local/tex/context/base",
    owntree .. "/../../texmf-context/tex/context/base",
    owntree .. "/../../texmf-dist/tex/context/base",
    owntree .. "/../../texmf/tex/context/base",
    owntree .. "/../../../texmf-local/tex/context/base",
    owntree .. "/../../../texmf-context/tex/context/base",
    owntree .. "/../../../texmf-dist/tex/context/base",
    owntree .. "/../../../texmf/tex/context/base",
}

if own.path == "." then table.remove(own.list,1) end

local function locate_libs()
    for l=1,#own.libs do
        local lib = own.libs[l]
        for p =1,#own.list do
            local pth = own.list[p]
            local filename = pth .. "/" .. lib
            local found = lfs.isfile(filename)
            if found then
                package.path = package.path .. ";" .. pth .. "/?.lua" -- in case l-* does a require
                return pth
            end
        end
    end
end

local function load_libs()
    local found = locate_libs()
    if found then
        for l=1,#own.libs do
            local filename = found .. "/" .. own.libs[l]
            local codeblob = loadfile(filename)
            if codeblob then
                codeblob()
            end
        end
    else
        resolvers = nil
    end
end

if not resolvers then
    load_libs()
end

if not resolvers then
    print("")
    print("Mtxrun is unable to start up due to lack of libraries. You may")
    print("try to run 'lua mtxrun.lua --selfmerge' in the path where this")
    print("script is located (normally under ..../scripts/context/lua) which")
    print("will make this script library independent.")
    os.exit()
end

-- verbosity

local e_verbose = environment.arguments["verbose"]

if e_verbose then
    trackers.enable("resolvers.locating")
end

-- some common flags (also passed through environment)

local e_silent       = environment.argument("silent")
local e_noconsole    = environment.argument("noconsole")

local e_trackers     = environment.argument("trackers")
local e_directives   = environment.argument("directives")
local e_experiments  = environment.argument("experiments")

if e_silent == true then
    e_silent = "*"
end

if type(e_silent) == "string" then
    if type(e_directives) == "string" then
        e_directives = format("%s,logs.blocked={%s}",e_directives,e_silent)
    else
        e_directives = format("logs.blocked={%s}",e_silent)
    end
end

if e_noconsole then
    if type(e_directives) == "string" then
        e_directives = format("%s,logs.target=file",e_directives)
    else
        e_directives = format("logs.target=file")
    end
end

if e_trackers    then trackers   .enable(e_trackers)    end
if e_directives  then directives .enable(e_directives)  end
if e_experiments then experiments.enable(e_experiments) end

if not environment.trackers    then environment.trackers    = e_trackers    end
if not environment.directives  then environment.directives  = e_directives  end
if not environment.experiments then environment.experiments = e_experiments end

--

local instance = resolvers.reset()

local helpinfo = [[
--script              run an mtx script (lua prefered method) (--noquotes), no script gives list
--execute             run a script or program (texmfstart method) (--noquotes)
--resolve             resolve prefixed arguments
--ctxlua              run internally (using preloaded libs)
--internal            run script using built in libraries (same as --ctxlua)
--locate              locate given filename in database (default) or system (--first --all --detail)

--autotree            use texmf tree cf. env 'texmfstart_tree' or 'texmfstarttree'
--tree=pathtotree     use given texmf tree (default file: 'setuptex.tmf')
--environment=name    use given (tmf) environment file
--path=runpath        go to given path before execution
--ifchanged=filename  only execute when given file has changed (md checksum)
--iftouched=old,new   only execute when given file has changed (time stamp)

--makestubs           create stubs for (context related) scripts
--removestubs         remove stubs (context related) scripts
--stubpath=binpath    paths where stubs wil be written
--windows             create windows (mswin) stubs
--unix                create unix (linux) stubs

--verbose             give a bit more info
--trackers=list       enable given trackers
--progname=str        format or backend

--edit                launch editor with found file
--launch (--all)      launch files like manuals, assumes os support

--timedrun            run a script an time its run
--autogenerate        regenerate databases if needed (handy when used to run context in an editor)

--usekpse             use kpse as fallback (when no mkiv and cache installed, often slower)
--forcekpse           force using kpse (handy when no mkiv and cache installed but less functionality)

--prefixes            show supported prefixes

--generate            generate file database

--variables           show configuration variables
--configurations      show configuration order

--expand-braces       expand complex variable
--expand-path         expand variable (resolve paths)
--expand-var          expand variable (resolve references)
--show-path           show path expansion of ...
--var-value           report value of variable
--find-file           report file location
--find-path           report path of file

--pattern=str         filter variables
]]

local application = logs.application {
    name     = "mtxrun",
    banner   = "ConTeXt TDS Runner Tool 1.31",
    helpinfo = helpinfo,
}

local report = application.report

messages = messages or { } -- for the moment

runners = runners  or { } -- global (might become local)

runners.applications = {
    ["lua"] = "luatex --luaonly",
    ["luc"] = "luatex --luaonly",
    ["pl"] = "perl",
    ["py"] = "python",
    ["rb"] = "ruby",
}

runners.suffixes = {
    'rb', 'lua', 'py', 'pl'
}

runners.registered = {
    texexec      = { 'texexec.rb',      false },  -- context mkii runner (only tool not to be luafied)
    texutil      = { 'texutil.rb',      true  },  -- old perl based index sorter for mkii (old versions need it)
    texfont      = { 'texfont.pl',      true  },  -- perl script that makes mkii font metric files
    texfind      = { 'texfind.pl',      false },  -- perltk based tex searching tool, mostly used at pragma
    texshow      = { 'texshow.pl',      false },  -- perltk based context help system, will be luafied
 -- texwork      = { 'texwork.pl',      false },  -- perltk based editing environment, only used at pragma
    makempy      = { 'makempy.pl',      true  },
    mptopdf      = { 'mptopdf.pl',      true  },
    pstopdf      = { 'pstopdf.rb',      true  },  -- converts ps (and some more) images, does some cleaning (replaced)
 -- examplex     = { 'examplex.rb',     false },
    concheck     = { 'concheck.rb',     false },
    runtools     = { 'runtools.rb',     true  },
    textools     = { 'textools.rb',     true  },
    tmftools     = { 'tmftools.rb',     true  },
    ctxtools     = { 'ctxtools.rb',     true  },
    rlxtools     = { 'rlxtools.rb',     true  },
    pdftools     = { 'pdftools.rb',     true  },
    mpstools     = { 'mpstools.rb',     true  },
 -- exatools     = { 'exatools.rb',     true  },
    xmltools     = { 'xmltools.rb',     true  },
 -- luatools     = { 'luatools.lua',    true  },
    mtxtools     = { 'mtxtools.rb',     true  },
    pdftrimwhite = { 'pdftrimwhite.pl', false },
}

runners.launchers = {
    windows = { },
    unix    = { },
}

-- like runners.libpath("framework"): looks on script's subpath

function runners.libpath(...)
    package.prepend_libpath(file.dirname(environment.ownscript),...)
    package.prepend_libpath(file.dirname(environment.ownname)  ,...)
end

function runners.prepare()
    local checkname = environment.argument("ifchanged")
    if type(checkname) == "string" and checkname ~= "" then
        local oldchecksum = file.loadchecksum(checkname)
        local newchecksum = file.checksum(checkname)
        if oldchecksum == newchecksum then
            if e_verbose then
                report("file '%s' is unchanged",checkname)
            end
            return "skip"
        elseif e_verbose then
            report("file '%s' is changed, processing started",checkname)
        end
        file.savechecksum(checkname)
    end
    local touchname = environment.argument("iftouched")
    if type(touchname) == "string" and touchname ~= "" then
        local oldname, newname = string.splitup(touchname, ",")
        if oldname and newname and oldname ~= "" and newname ~= "" then
            if not file.needs_updating(oldname,newname) then
                if e_verbose then
                    report("file '%s' and '%s' have same age",oldname,newname)
                end
                return "skip"
            elseif e_verbose then
                report("file '%s' is older than '%s'",oldname,newname)
            end
        end
    end
    local runpath = environment.argument("path")
    if type(runpath) == "string" and not lfs.chdir(runpath) then
        report("unable to change to path '%s'",runpath)
        return "error"
    end
    runners.prepare = function() end
    return "run"
end

function runners.execute_script(fullname,internal,nosplit)
    local noquote = environment.argument("noquotes")
    if fullname and fullname ~= "" then
        local state = runners.prepare()
        if state == 'error' then
            return false
        elseif state == 'skip' then
            return true
        elseif state == "run" then
            local path, name, suffix, result = file.dirname(fullname), file.basename(fullname), file.extname(fullname), ""
            if path ~= "" then
                result = fullname
            elseif name then
                name = gsub(name,"^int[%a]*:",function()
                    internal = true
                    return ""
                end )
                name = gsub(name,"^script:","")
                if suffix == "" and runners.registered[name] and runners.registered[name][1] then
                    name = runners.registered[name][1]
                    suffix = file.extname(name)
                end
                if suffix == "" then
                    -- loop over known suffixes
                    for _,s in pairs(runners.suffixes) do
                        result = resolvers.findfile(name .. "." .. s, 'texmfscripts')
                        if result ~= "" then
                            break
                        end
                    end
                elseif runners.applications[suffix] then
                    result = resolvers.findfile(name, 'texmfscripts')
                else
                    -- maybe look on path
                    result = resolvers.findfile(name, 'other text files')
                end
            end
            if result and result ~= "" then
                if not no_split then
                    local before, after = environment.splitarguments(fullname) -- already done
                    environment.arguments_before, environment.arguments_after = before, after
                end
                if internal then
                    arg = { } for _,v in pairs(environment.arguments_after) do arg[#arg+1] = v end
                    environment.ownscript = result
                    dofile(result)
                else
                    local binary = runners.applications[file.extname(result)]
                    result = string.quoted(string.unquoted(result))
                 -- if string.match(result,' ') and not string.match(result,"^\".*\"$") then
                 --     result = '"' .. result .. '"'
                 -- end
                    if binary and binary ~= "" then
                        result = binary .. " " .. result
                    end
                    local command = result .. " " .. environment.reconstructcommandline(environment.arguments_after,noquote)
                    if e_verbose then
                        report()
                        report("executing: %s",command)
                        report()
                        report()
                        io.flush()
                    end
                    -- no os.exec because otherwise we get the wrong return value
                    local code = os.execute(command) -- maybe spawn
                    if code == 0 then
                        return true
                    else
                        if binary then
                            binary = file.addsuffix(binary,os.binsuffix)
                            for p in gmatch(os.getenv("PATH"),"[^"..io.pathseparator.."]+") do
                                if lfs.isfile(file.join(p,binary)) then
                                    return false
                                end
                            end
                            report()
                            report("This script needs '%s' which seems not to be installed.",binary)
                            report()
                        end
                        return false
                    end
                end
            end
        end
    end
    return false
end

function runners.execute_program(fullname)
    local noquote = environment.argument("noquotes")
    if fullname and fullname ~= "" then
        local state = runners.prepare()
        if state == 'error' then
            return false
        elseif state == 'skip' then
            return true
        elseif state == "run" then
            local before, after = environment.splitarguments(fullname)
            for k=1,#after do after[k] = resolvers.resolve(after[k]) end
            environment.initializearguments(after)
            fullname = gsub(fullname,"^bin:","")
            local command = fullname .. " " .. (environment.reconstructcommandline(after or "",noquote) or "")
            report()
            report("executing: %s",command)
            report()
            report()
            io.flush()
            local code = os.exec(command) -- (fullname,unpack(after)) does not work / maybe spawn
            return code == 0
        end
    end
    return false
end

-- the --usekpse flag will fallback (not default) on kpse (hm, we can better update mtx-stubs)

local windows_stub = '@echo off\013\010setlocal\013\010set ownpath=%%~dp0%%\013\010texlua "%%ownpath%%mtxrun.lua" --usekpse --execute %s %%*\013\010endlocal\013\010'
local unix_stub    = '#!/bin/sh\010mtxrun --usekpse --execute %s \"$@\"\010'

function runners.handle_stubs(create)
    local stubpath = environment.argument('stubpath') or '.' -- 'auto' no longer subpathssupported
    local windows  = environment.argument('windows') or environment.argument('mswin') or false
    local unix     = environment.argument('unix') or environment.argument('linux') or false
    if not windows and not unix then
        if os.platform == "unix" then
            unix = true
        else
            windows = true
        end
    end
    for _,v in pairs(runners.registered) do
        local name, doit = v[1], v[2]
        if doit then
            local base = gsub(file.basename(name), "%.(.-)$", "")
            if create then
                if windows then
                    io.savedata(file.join(stubpath,base..".bat"),format(windows_stub,name))
                    report("windows stub for '%s' created",base)
                end
                if unix then
                    io.savedata(file.join(stubpath,base),format(unix_stub,name))
                    report("unix stub for '%s' created",base)
                end
            else
                if windows and (os.remove(file.join(stubpath,base..'.bat')) or os.remove(file.join(stubpath,base..'.cmd'))) then
                    report("windows stub for '%s' removed", base)
                end
                if unix and (os.remove(file.join(stubpath,base)) or os.remove(file.join(stubpath,base..'.sh'))) then
                    report("unix stub for '%s' removed",base)
                end
            end
        end
    end
end

function runners.resolve_string(filename)
    if filename and filename ~= "" then
        runners.report_location(resolvers.resolve(filename))
    end
end

-- differs from texmfstart where locate appends .com .exe .bat ... todo

function runners.locate_file(filename) -- was given file but only searches in tree
    if filename and filename ~= "" then
        if environment.argument("first") then
            runners.report_location(resolvers.findfile(filename))
         -- resolvers.dowithfilesandreport(resolvers.findfile,filename)
        elseif environment.argument("all") then
            local result, status = resolvers.findfiles(filename)
            if status and environment.argument("detail") then
                runners.report_location(status)
            else
                runners.report_location(result)
            end
        else
            runners.report_location(resolvers.findgivenfile(filename))
         -- resolvers.dowithfilesandreport(resolvers.findgivenfile,filename)
        end
    end
end

function runners.locate_platform()
    runners.report_location(os.platform)
end

function runners.report_location(result)
    if type(result) == "table" then
        for i=1,#result do
            if i > 1 then
                io.write("\n")
            end
            io.write(result[i])
        end
    else
        io.write(result)
    end
end

function runners.edit_script(filename) -- we assume that gvim is present on most systems (todo: also in cnf file)
    local editor = os.getenv("MTXRUN_EDITOR") or os.getenv("TEXMFSTART_EDITOR") or os.getenv("EDITOR") or 'gvim'
    local rest = resolvers.resolve(filename)
    if rest ~= "" then
        local command = editor .. " " .. rest
        if e_verbose then
            report()
            report("starting editor: %s",command)
            report()
            report()
        end
        os.launch(command)
    end
end

function runners.save_script_session(filename, list)
    local t = { }
    for i=1,#list do
        local key = list[i]
        t[key] = environment.arguments[key]
    end
    io.savedata(filename,table.serialize(t,true))
end

function runners.load_script_session(filename)
    if lfs.isfile(filename) then
        local t = io.loaddata(filename)
        if t then
            t = loadstring(t)
            if t then t = t() end
            for key, value in pairs(t) do
                environment.arguments[key] = value
            end
        end
    end
end

function resolvers.launch(str)
    -- maybe we also need to test on mtxrun.launcher.suffix environment
    -- variable or on windows consult the assoc and ftype vars and such
    local launchers = runners.launchers[os.platform] if launchers then
        local suffix = file.extname(str) if suffix then
            local runner = launchers[suffix] if runner then
                str = runner .. " " .. str
            end
        end
    end
    os.launch(str)
end

function runners.launch_file(filename)
    trackers.enable("resolvers.locating")
    local allresults = environment.arguments["all"]
    local pattern = environment.arguments["pattern"]
    if not pattern or pattern == "" then
        pattern = filename
    end
    if not pattern or pattern == "" then
        report("provide name or --pattern=")
    else
        local t = resolvers.findfiles(pattern,nil,allresults)
        if not t or #t == 0 then
            t = resolvers.findfiles("*/" .. pattern,nil,allresults)
        end
        if not t or #t == 0 then
            t = resolvers.findfiles("*/" .. pattern .. "*",nil,allresults)
        end
        if t and #t > 0 then
            if allresults then
                for _, v in pairs(t) do
                    report("launching %s", v)
                    resolvers.launch(v)
                end
            else
                report("launching %s", t[1])
                resolvers.launch(t[1])
            end
        else
            report("no match for %s", pattern)
        end
    end
end

local mtxprefixes = {
    { "^mtx%-",    "mtx-"  },
    { "^mtx%-t%-", "mtx-t-" },
}

function runners.find_mtx_script(filename)
    local function found(name)
        local path = file.dirname(name)
        if path and path ~= "" then
            return false
        else
            local fullname = own and own.path and file.join(own.path,name)
            return io.exists(fullname) and fullname
        end
    end
    filename = file.addsuffix(filename,"lua")
    local basename = file.removesuffix(file.basename(filename))
    local suffix = file.extname(filename)
    -- qualified path, raw name
    local fullname = file.is_qualified_path(filename) and io.exists(filename) and filename
    if fullname and fullname ~= "" then
        return fullname
    end
    -- current path, raw name
    fullname = "./" .. filename
    fullname = io.exists(fullname) and fullname
    if fullname and fullname ~= "" then
        return fullname
    end
    -- mtx- prefix checking
    for i=1,#mtxprefixes do
        local mtxprefix = mtxprefixes[i]
        mtxprefix = find(filename,mtxprefix[1]) and "" or mtxprefix[2]
        -- context namespace, mtx-<filename>
        fullname = mtxprefix .. filename
        fullname = found(fullname) or resolvers.findfile(fullname)
        if fullname and fullname ~= "" then
            return fullname
        end
        -- context namespace, mtx-<filename>s
        fullname = mtxprefix .. basename .. "s" .. "." .. suffix
        fullname = found(fullname) or resolvers.findfile(fullname)
        if fullname and fullname ~= "" then
            return fullname
        end
        -- context namespace, mtx-<filename minus trailing s>
        fullname = mtxprefix .. gsub(basename,"s$","") .. "." .. suffix
        fullname = found(fullname) or resolvers.findfile(fullname)
        if fullname and fullname ~= "" then
            return fullname
        end
    end
    -- context namespace, just <filename>
    fullname = resolvers.findfile(filename)
    return fullname
end

function runners.register_arguments(...)
    local arguments = environment.arguments_after
    local passedon = { ... }
    for i=#passedon,1,-1 do
        local pi = passedon[i]
        if pi then
            table.insert(arguments,1,pi)
        end
    end
end

function runners.execute_ctx_script(filename,...)
    runners.register_arguments(...)
    local arguments = environment.arguments_after
    local fullname = runners.find_mtx_script(filename) or ""
    if file.extname(fullname) == "cld" then
        -- handy in editors where we force --autopdf
        report("running cld script: %s",filename)
        table.insert(arguments,1,fullname)
        table.insert(arguments,"--autopdf")
        fullname = runners.find_mtx_script("context") or ""
    end
    -- retry after generate but only if --autogenerate
    if fullname == "" and environment.argument("autogenerate") then -- might become the default
        instance.renewcache = true
        trackers.enable("resolvers.locating")
        resolvers.load()
        --
        fullname = runners.find_mtx_script(filename) or ""
    end
    -- that should do it
    if fullname ~= "" then
        local state = runners.prepare()
        if state == 'error' then
            return false
        elseif state == 'skip' then
            return true
        elseif state == "run" then
            -- load and save ... kind of undocumented
            arg = { } for _,v in pairs(arguments) do arg[#arg+1] = resolvers.resolve(v) end
            environment.initializearguments(arg)
            local loadname = environment.arguments['load']
            if loadname then
                if type(loadname) ~= "string" then loadname = file.basename(fullname) end
                loadname = file.replacesuffix(loadname,"cfg")
                runners.load_script_session(loadname)
            end
            filename = environment.files[1]
            if e_verbose then
                report("using script: %s\n",fullname)
            end
            environment.ownscript = fullname
            dofile(fullname)
            local savename = environment.arguments['save']
            if savename then
                local save_list = runners.save_list
                if save_list and next(save_list) then
                    if type(savename) ~= "string" then savename = file.basename(fullname) end
                    savename = file.replacesuffix(savename,"cfg")
                    runners.save_script_session(savename,save_list)
                end
            end
            return true
        end
    else
        if filename == "" or filename == "help" then
            local context = resolvers.findfile("mtx-context.lua")
            trackers.enable("resolvers.locating")
            if context ~= "" then
                local result = dir.glob((gsub(context,"mtx%-context","mtx-*"))) -- () needed
                local valid = { }
                table.sort(result)
                for i=1,#result do
                    local scriptname = result[i]
                    local scriptbase = match(scriptname,".*mtx%-([^%-]-)%.lua")
                    if scriptbase then
                        local data = io.loaddata(scriptname)
                        local banner, version = match(data,"[\n\r]logs%.extendbanner%s*%(%s*[\"\']([^\n\r]+)%s*(%d+%.%d+)")
                        if banner then
                            valid[#valid+1] = { scriptbase, version, banner }
                        end
                    end
                end
                if #valid > 0 then
                    application.identify()
                    report("no script name given, known scripts:")
                    report()
                    for k=1,#valid do
                        local v = valid[k]
                        report("%-12s  %4s  %s",v[1],v[2],v[3])
                    end
                end
            else
                report("no script name given")
            end
        else
            filename = file.addsuffix(filename,"lua")
            if file.is_qualified_path(filename) then
                report("unknown script '%s'",filename)
            else
                report("unknown script '%s' or 'mtx-%s'",filename,filename)
            end
        end
        return false
    end
end

function runners.prefixes()
    application.identify()
    report()
    report(concat(resolvers.allprefixes(true)," "))
end

function runners.timedrun(filename) -- just for me
    if filename and filename ~= "" then
        runners.timed(function() os.execute(filename) end)
    end
end

function runners.timed(action)
    statistics.timed(action)
end

-- this is a bit dirty ... first we store the first filename and next we
-- split the arguments so that we only see the ones meant for this script
-- ... later we will use the second half

local filename = environment.files[1] or ""
local ok      = true

local before, after = environment.splitarguments(filename)
environment.arguments_before, environment.arguments_after = before, after
environment.initializearguments(before)

instance.lsrmode  = environment.argument("lsr") or false

-- maybe the unset has to go to this level

local is_mkii_stub = runners.registered[file.removesuffix(file.basename(filename))]

local e_argument = environment.argument

if e_argument("usekpse") or e_argument("forcekpse") or is_mkii_stub then

    resolvers.load_tree(e_argument('tree'),true) -- force resolve of TEXMFCNF

    os.setenv("engine","")
    os.setenv("progname","")

    local remapper = {
        otf   = "opentype fonts",
        ttf   = "truetype fonts",
        ttc   = "truetype fonts",
        pfb   = "type1 fonts",
        other = "other text files",
    }

    local progname = e_argument("progname") or 'context'

    local function kpse_initialized()
        texconfig.kpse_init = true
        local t = os.clock()
        local k = kpse.original.new("luatex",progname)
        local dummy = k:find_file("mtxrun.lua") -- so that we're initialized
        report("kpse fallback with progname '%s' initialized in %s seconds",progname,os.clock()-t)
        kpse_initialized = function() return k end
        return k
    end

    local findfile = resolvers.findfile
    local showpath = resolvers.showpath

    if e_argument("forcekpse") then

        function resolvers.findfile(name,kind)
            return (kpse_initialized():find_file(resolvers.cleanpath(name),(kind ~= "" and (remapper[kind] or kind)) or "tex") or "") or ""
        end
        function resolvers.showpath(name)
            return (kpse_initialized():show_path(name)) or ""
        end

    elseif e_argument("usekpse") or is_mkii_stub then

        resolvers.load()

        function resolvers.findfile(name,kind)
            local found = findfile(name,kind) or ""
            if found ~= "" then
                return found
            else
                return (kpse_initialized():find_file(resolvers.cleanpath(name),(kind ~= "" and (remapper[kind] or kind)) or "tex") or "") or ""
            end
        end
        function resolvers.showpath(name)
            local found = showpath(name) or ""
            if found ~= "" then
                return found
            else
                return (kpse_initialized():show_path(name)) or ""
            end
        end

    end

    function runners.loadbase()
    end

else

    function runners.loadbase(...)
        if not resolvers.load(...) then
            report("forcing cache reload")
            instance.renewcache = true
            trackers.enable("resolvers.locating")
            if not resolvers.load(...) then
                report("the resolver databases are not present or outdated")
            end
        end
    end

    resolvers.load_tree(e_argument('tree'),e_argument("resolve"))

end


if e_argument("selfmerge") then

    -- embed used libraries

    runners.loadbase()
    local found = locate_libs()
    if found then
        utilities.merger.selfmerge(own.name,own.libs,{ found })
    end

elseif e_argument("selfclean") then

    -- remove embedded libraries

    runners.loadbase()
    utilities.merger.selfclean(own.name)

elseif e_argument("selfupdate") then

    runners.loadbase()
    trackers.enable("resolvers.locating")
    resolvers.updatescript(own.name,"mtxrun")

elseif e_argument("ctxlua") or e_argument("internal") then

    -- run a script by loading it (using libs)

    runners.loadbase()
    ok = runners.execute_script(filename,true)

elseif e_argument("script") or e_argument("scripts") then

    -- run a script by loading it (using libs), pass args

    runners.loadbase()
    if is_mkii_stub then
        ok = runners.execute_script(filename,false,true)
    else
        ok = runners.execute_ctx_script(filename)
    end

elseif e_argument("execute") then

    -- execute script

    runners.loadbase()
    ok = runners.execute_script(filename)

elseif e_argument("direct") then

    -- equals bin:

    runners.loadbase()
    ok = runners.execute_program(filename)

elseif e_argument("edit") then

    -- edit file

    runners.loadbase()
    runners.edit_script(filename)

elseif e_argument("launch") then

    runners.loadbase()
    runners.launch_file(filename)

elseif e_argument("makestubs") then

    -- make stubs (depricated)

    runners.handle_stubs(true)

elseif e_argument("removestubs") then

    -- remove stub (depricated)

    runners.loadbase()
    runners.handle_stubs(false)

elseif e_argument("resolve") then

    -- resolve string

    runners.loadbase()
    runners.resolve_string(filename)

elseif e_argument("locate") then

    -- locate file (only database)

    runners.loadbase()
    runners.locate_file(filename)

elseif e_argument("platform") or e_argument("show-platform") then

    -- locate platform

    runners.loadbase()
    runners.locate_platform()

elseif e_argument("prefixes") then

    runners.loadbase()
    runners.prefixes()

elseif e_argument("timedrun") then

    -- locate platform

    runners.loadbase()
    runners.timedrun(filename)

elseif e_argument("variables") or e_argument("show-variables") or e_argument("expansions") or e_argument("show-expansions") then

    -- luatools: runners.execute_ctx_script("mtx-base","--expansions",filename)

    resolvers.load("nofiles")
    resolvers.listers.variables(e_argument("pattern"))

elseif e_argument("configurations") or e_argument("show-configurations") then

    -- luatools: runners.execute_ctx_script("mtx-base","--configurations",filename)

    resolvers.load("nofiles")
    resolvers.listers.configurations()

elseif e_argument("find-file") then

    -- luatools: runners.execute_ctx_script("mtx-base","--find-file",filename)

    resolvers.load()
    local e_all     = e_argument("all")
    local e_pattern = e_argument("pattern")
    local e_format  = e_argument("format")
    local finder    = e_all and resolvers.findfiles or resolvers.findfile
    if not e_pattern then
        runners.register_arguments(filename)
        environment.initializearguments(environment.arguments_after)
        resolvers.dowithfilesandreport(finder,environment.files,e_format)
    elseif type(e_pattern) == "string" then
        resolvers.dowithfilesandreport(finder,{ e_pattern },e_format)
    end

elseif e_argument("find-path") then

    -- luatools: runners.execute_ctx_script("mtx-base","--find-path",filename)

    resolvers.load()
    local path = resolvers.findpath(filename, instance.my_format)
    if e_verbose then
        report(path)
    else
        print(path)
    end

elseif e_argument("expand-braces") then

    -- luatools: runners.execute_ctx_script("mtx-base","--expand-braces",filename

    resolvers.load("nofiles")
    runners.register_arguments(filename)
    environment.initializearguments(environment.arguments_after)
    resolvers.dowithfilesandreport(resolvers.expandbraces, environment.files)

elseif e_argument("expand-path") then

    -- luatools: runners.execute_ctx_script("mtx-base","--expand-path",filename)

    resolvers.load("nofiles")
    runners.register_arguments(filename)
    environment.initializearguments(environment.arguments_after)
    resolvers.dowithfilesandreport(resolvers.expandpath, environment.files)

elseif e_argument("expand-var") or e_argument("expand-variable") then

    -- luatools: runners.execute_ctx_script("mtx-base","--expand-var",filename)

    resolvers.load("nofiles")
    runners.register_arguments(filename)
    environment.initializearguments(environment.arguments_after)
    resolvers.dowithfilesandreport(resolvers.expansion, environment.files)

elseif e_argument("show-path") or e_argument("path-value") then

    -- luatools: runners.execute_ctx_script("mtx-base","--show-path",filename)

    resolvers.load("nofiles")
    runners.register_arguments(filename)
    environment.initializearguments(environment.arguments_after)
    resolvers.dowithfilesandreport(resolvers.showpath, environment.files)

elseif e_argument("var-value") or e_argument("show-value") then

    -- luatools: runners.execute_ctx_script("mtx-base","--show-value",filename)

    resolvers.load("nofiles")
    runners.register_arguments(filename)
    environment.initializearguments(environment.arguments_after)
    resolvers.dowithfilesandreport(resolvers.variable,environment.files)

elseif e_argument("format-path") then

    -- luatools: runners.execute_ctx_script("mtx-base","--format-path",filename)

    resolvers.load()
    report(caches.getwritablepath("format"))

elseif e_argument("pattern") then

    -- luatools

    runners.execute_ctx_script("mtx-base","--pattern='" .. e_argument("pattern") .. "'",filename)

elseif e_argument("generate") then

    -- luatools

    if filename and filename ~= "" then
        resolvers.load("nofiles")
        trackers.enable("resolvers.locating")
        resolvers.renew(filename)
    else
        instance.renewcache = true
        trackers.enable("resolvers.locating")
        resolvers.load()
    end

    e_verbose = true

elseif e_argument("make") or e_argument("ini") or e_argument("compile") then

    -- luatools: runners.execute_ctx_script("mtx-base","--make",filename)

    resolvers.load()
    trackers.enable("resolvers.locating")
    environment.make_format(filename)

elseif e_argument("run") then

    -- luatools

    runners.execute_ctx_script("mtx-base","--run",filename)

elseif e_argument("fmt") then

    -- luatools

    runners.execute_ctx_script("mtx-base","--fmt",filename)

elseif e_argument("help") and filename=='base' then

    -- luatools

    runners.execute_ctx_script("mtx-base","--help")

elseif e_argument("version") then

    application.version()

elseif e_argument("help") or filename=='help' or filename == "" then

    application.help()

elseif find(filename,"^bin:") then

    runners.loadbase()
    ok = runners.execute_program(filename)

elseif is_mkii_stub then

    -- execute mkii script

    runners.loadbase()
    ok = runners.execute_script(filename,false,true)

elseif false then

    runners.loadbase()
    ok = runners.execute_ctx_script(filename)
    if not ok then
        ok = runners.execute_script(filename)
    end

elseif environment.files[1] == 'texmfcnf.lua' then -- so that we don't need to load mtx-base

    resolvers.load("nofiles")
    resolvers.listers.configurations()

else

    runners.loadbase()
    runners.execute_ctx_script("mtx-base",filename)

end

if e_verbose then
    report()
    report("runtime: %0.3f seconds",os.runtime())
end

if os.type ~= "windows" then
    texio.write("\n") -- is this still valid?
end

if ok == false then ok = 1 elseif ok == true then ok = 0 end

os.exit(ok)
