-- filename : l-table.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-table'] = 1.001

table.join = table.concat

local concat, sort, insert, remove = table.concat, table.sort, table.insert, table.remove
local format = string.format
local getmetatable, setmetatable = getmetatable, setmetatable
local pairs, ipairs, type, next, tostring = pairs, ipairs, type, next, tostring

function table.strip(tab)
    local lst = { }
    for i=1,#tab do
        local s = tab[i]:gsub("^%s*(.-)%s*$","%1")
        if s == "" then
            -- skip this one
        else
            lst[#lst+1] = s
        end
    end
    return lst
end

local function sortedkeys(tab)
    local srt, kind = { }, 0 -- 0=unknown 1=string, 2=number 3=mixed
    for key,_ in pairs(tab) do
        srt[#srt+1] = key
        if kind == 3 then
            -- no further check
        else
            local tkey = type(key)
            if tkey == "string" then
            --  if kind == 2 then kind = 3 else kind = 1 end
                kind = (kind == 2 and 3) or 1
            elseif tkey == "number" then
            --  if kind == 1 then kind = 3 else kind = 2 end
                kind = (kind == 1 and 3) or 2
            else
                kind = 3
            end
        end
    end
    if kind == 0 or kind == 3 then
        sort(srt,function(a,b) return (tostring(a) < tostring(b)) end)
    else
        sort(srt)
    end
    return srt
end

local function sortedhashkeys(tab) -- fast one
    local srt = { }
    for key,_ in pairs(tab) do
        srt[#srt+1] = key
    end
    sort(srt)
    return srt
end

table.sortedkeys     = sortedkeys
table.sortedhashkeys = sortedhashkeys

function table.append(t, list)
    for _,v in pairs(list) do
        insert(t,v)
    end
end

function table.prepend(t, list)
    for k,v in pairs(list) do
        insert(t,k,v)
    end
end

function table.merge(t, ...) -- first one is target
    t = t or {}
    local lst = {...}
    for i=1,#lst do
        for k, v in pairs(lst[i]) do
            t[k] = v
        end
    end
    return t
end

function table.merged(...)
    local tmp, lst = { }, {...}
    for i=1,#lst do
        for k, v in pairs(lst[i]) do
            tmp[k] = v
        end
    end
    return tmp
end

function table.imerge(t, ...)
    local lst = {...}
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            t[#t+1] = nst[j]
        end
    end
    return t
end

function table.imerged(...)
    local tmp, lst = { }, {...}
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            tmp[#tmp+1] = nst[j]
        end
    end
    return tmp
end

local function fastcopy(old) -- fast one
    if old then
        local new = { }
        for k,v in pairs(old) do
            if type(v) == "table" then
                new[k] = fastcopy(v) -- was just table.copy
            else
                new[k] = v
            end
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

local function copy(t, tables) -- taken from lua wiki, slightly adapted
    tables = tables or { }
    local tcopy = {}
    if not tables[t] then
        tables[t] = tcopy
    end
    for i,v in pairs(t) do -- brrr, what happens with sparse indexed
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

-- rougly: copy-loop : unpack : sub == 0.9 : 0.4 : 0.45 (so in critical apps, use unpack)

function table.sub(t,i,j)
    return { unpack(t,i,j) }
end

function table.replace(a,b)
    for k,v in pairs(b) do
        a[k] = v
    end
end

-- slower than #t on indexed tables (#t only returns the size of the numerically indexed slice)

function table.is_empty(t)
    return not t or not next(t)
end

function table.one_entry(t)
    local n = next(t)
    return n and not next(t,n)
end

function table.starts_at(t)
    return ipairs(t,1)(t,0)
end

function table.tohash(t,value)
    local h = { }
    if value == nil then value = true end
    for _, v in pairs(t) do -- no ipairs here
        h[v] = value
    end
    return h
end

function table.fromhash(t)
    local h = { }
    for k, v in pairs(t) do -- no ipairs here
        if v then h[#h+1] = k end
    end
    return h
end

--~ print(table.serialize(t), "\n")
--~ print(table.serialize(t,"name"), "\n")
--~ print(table.serialize(t,false), "\n")
--~ print(table.serialize(t,true), "\n")
--~ print(table.serialize(t,"name",true), "\n")
--~ print(table.serialize(t,"name",true,true), "\n")

table.serialize_functions = true
table.serialize_compact   = true
table.serialize_inline    = true

local noquotes, hexify, handle, reduce, compact, inline, functions

local reserved = table.tohash { -- intercept a language flaw, no reserved words as key
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if',
    'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while',
}

local function key(k)
    if type(k) == "number" then -- or k:find("^%d+$") then
        if hexify then
            return ("[0x%04X]"):format(k)
        else
            return "["..k.."]"
        end
    elseif noquotes and not reserved[k] and k:find("^%a[%a%d%_]*$") then
        return k
    else
        return '["'..k..'"]'
    end
end

local function simple_table(t)
    if #t > 0 then
        local n = 0
        for _,v in pairs(t) do
            n = n + 1
        end
        if n == #t then
            local tt = { }
            for i=1,#t do
                local v = t[i]
                local tv = type(v)
                if tv == "number" then
                    if hexify then
                        tt[#tt+1] = ("0x%04X"):format(v)
                    else
                        tt[#tt+1] = tostring(v)
                    end
                elseif tv == "boolean" then
                    tt[#tt+1] = tostring(v)
                elseif tv == "string" then
                    tt[#tt+1] = ("%q"):format(v)
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

local function do_serialize(root,name,depth,level,indexed)
    if level > 0 then
        depth = depth .. " "
        if indexed then
            handle(("%s{"):format(depth))
        elseif name then
            handle(("%s%s={"):format(depth,key(name)))
        else
            handle(("%s{"):format(depth))
        end
    end
    if root and next(root) then
        local first, last = nil, 0 -- #root cannot be trusted here
        if compact then
          for k,v in ipairs(root) do -- NOT: for k=1,#root do (we need to quit at nil)
                if not first then first = k end
                last = last + 1
            end
        end
        local sk = sortedkeys(root)
        for i=1,#sk do
            local k = sk[i]
            local v = root[k]
--~ if v == root then
    -- circular
--~ else
            local t = type(v)
            if compact and first and type(k) == "number" and k >= first and k <= last then
                if t == "number" then
                    if hexify then
                        handle(("%s 0x%04X,"):format(depth,v))
                    else
                        handle(("%s %s,"):format(depth,v))
                    end
                elseif t == "string" then
                    if reduce and (v:find("^[%-%+]?[%d]-%.?[%d+]$") == 1) then
                        handle(("%s %s,"):format(depth,v))
                    else
                        handle(("%s %q,"):format(depth,v))
                    end
                elseif t == "table" then
                    if not next(v) then
                        handle(("%s {},"):format(depth))
                    elseif inline then
                        local st = simple_table(v)
                        if st then
                            handle(("%s { %s },"):format(depth,concat(st,", ")))
                        else
                            do_serialize(v,k,depth,level+1,true)
                        end
                    else
                        do_serialize(v,k,depth,level+1,true)
                    end
                elseif t == "boolean" then
                    handle(("%s %s,"):format(depth,tostring(v)))
                elseif t == "function" then
                    if functions then
                        handle(('%s loadstring(%q),'):format(depth,v:dump()))
                    else
                        handle(('%s "function",'):format(depth))
                    end
                else
                    handle(("%s %q,"):format(depth,tostring(v)))
                end
            elseif k == "__p__" then -- parent
                if false then
                    handle(("%s __p__=nil,"):format(depth))
                end
            elseif t == "number" then
                if hexify then
                    handle(("%s %s=0x%04X,"):format(depth,key(k),v))
                else
                    handle(("%s %s=%s,"):format(depth,key(k),v))
                end
            elseif t == "string" then
                if reduce and (v:find("^[%-%+]?[%d]-%.?[%d+]$") == 1) then
                    handle(("%s %s=%s,"):format(depth,key(k),v))
                else
                    handle(("%s %s=%q,"):format(depth,key(k),v))
                end
            elseif t == "table" then
                if not next(v) then
                    handle(("%s %s={},"):format(depth,key(k)))
                elseif inline then
                    local st = simple_table(v)
                    if st then
                        handle(("%s %s={ %s },"):format(depth,key(k),concat(st,", ")))
                    else
                        do_serialize(v,k,depth,level+1)
                    end
                else
                    do_serialize(v,k,depth,level+1)
                end
            elseif t == "boolean" then
                handle(("%s %s=%s,"):format(depth,key(k),tostring(v)))
            elseif t == "function" then
                if functions then
                    handle(('%s %s=loadstring(%q),'):format(depth,key(k),v:dump()))
                else
                    handle(('%s %s="function",'):format(depth,key(k)))
                end
            else
                handle(("%s %s=%q,"):format(depth,key(k),tostring(v)))
            --  handle(('%s %s=loadstring(%q),'):format(depth,key(k),string.dump(function() return v end)))
            end
--~ end
        end
    end
   if level > 0 then
        handle(("%s},"):format(depth))
    end
end

local function serialize(root,name,_handle,_reduce,_noquotes,_hexify)
    noquotes = _noquotes
    hexify = _hexify
    handle = _handle or print
    reduce = _reduce or false
    compact = table.serialize_compact
    inline  = compact and table.serialize_inline
    functions = table.serialize_functions
    local tname = type(name)
    if tname == "string" then
        if name == "return" then
            handle("return {")
        else
            handle(name .. "={")
        end
    elseif tname == "number" then
        if hexify then
            handle(("[0x%04X]={"):format(name))
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
    if root and next(root) then
        do_serialize(root,name,"",0,indexed)
    end
    handle("}")
end

--~ name:
--~
--~ true     : return     { }
--~ false    :            { }
--~ nil      : t        = { }
--~ string   : string   = { }
--~ 'return' : return     { }
--~ number   : [number] = { }

function table.serialize(root,name,reduce,noquotes,hexify)
    local t = { }
    local function flush(s)
        t[#t+1] = s
    end
    serialize(root,name,flush,reduce,noquotes,hexify)
    return concat(t,"\n")
end

function table.tohandle(handle,root,name,reduce,noquotes,hexify)
    serialize(root,name,handle,reduce,noquotes,hexify)
end

-- sometimes tables are real use (zapfino extra pro is some 85M) in which
-- case a stepwise serialization is nice; actually, we could consider:
--
-- for line in table.serializer(root,name,reduce,noquotes) do
--    ...(line)
-- end
--
-- so this is on the todo list

table.tofile_maxtab = 2*1024

function table.tofile(filename,root,name,reduce,noquotes,hexify)
    local f = io.open(filename,'w')
    if f then
        local maxtab = table.tofile_maxtab
        if maxtab > 1 then
            local t = { }
            local function flush(s)
                t[#t+1] = s
                if #t > maxtab then
                    f:write(concat(t,"\n"),"\n") -- hm, write(sometable) should be nice
                    t = { }
                end
            end
            serialize(root,name,flush,reduce,noquotes,hexify)
            f:write(concat(t,"\n"),"\n")
        else
            local function flush(s)
                f:write(s,"\n")
            end
            serialize(root,name,flush,reduce,noquotes,hexify)
        end
        f:close()
    end
end

local function flatten(t,f,complete)
    for i=1,#t do
        local v = t[i]
        if type(v) == "table" then
            if complete or type(v[1]) == "table" then
                flatten(v,f,complete)
            else
                f[#f+1] = v
            end
        else
            f[#f+1] = v
        end
    end
end

function table.flatten(t)
    local f = { }
    flatten(t,f,true)
    return f
end

function table.unnest(t) -- bad name
    local f = { }
    flatten(t,f,false)
    return f
end

table.flatten_one_level = table.unnest

-- the next three may disappear

function table.remove_value(t,value) -- todo: n
    if value then
        for i=1,#t do
            if t[i] == value then
                remove(t,i)
                -- remove all, so no: return
            end
        end
    end
end

function table.insert_before_value(t,value,str)
    if str then
        if value then
            for i=1,#t do
                if t[i] == value then
                    insert(t,i,str)
                    return
                end
            end
        end
        insert(t,1,str)
    elseif value then
        insert(t,1,value)
    end
end

function table.insert_after_value(t,value,str)
    if str then
        if value then
            for i=1,#t do
                if t[i] == value then
                    insert(t,i+1,str)
                    return
                end
            end
        end
        t[#t+1] = str
    elseif value then
        t[#t+1] = value
    end
end

function table.are_equal(a,b,n,m)
    if #a == #b then
        n = n or 1
        m = m or #a
        for i=n,m do
            local ai, bi = a[i], b[i]
            if (ai==bi) or (type(ai)=="table" and type(bi)=="table" and table.are_equal(ai,bi)) then
                -- continue
            else
                return false
            end
        end
        return true
    else
        return false
    end
end

function table.compact(t)
    if t then
        for k,v in pairs(t) do
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
    local n, e = 0, next(t)
    while e do
        n, e = n + 1, next(t,e)
    end
    return n
end

function table.swapped(t)
    local s = { }
    for k, v in pairs(t) do
        s[v] = k
    end
    return s
end

--~ function table.are_equal(a,b)
--~     return table.serialize(a) == table.serialize(b)
--~ end

function table.clone(t,p) -- t is optional or nil or table
    if not p then
        t, p = { }, t or { }
    elseif not t then
        t = { }
    end
    setmetatable(t, { __index = function(_,key) return p[key] end })
    return t
end

function table.hexed(t,seperator)
    local tt = { }
    for i=1,#t do tt[i] = ("0x%04X"):format(t[i]) end
    return concat(tt,seperator or " ")
end

function table.reverse_hash(h)
    local r = { }
    for k,v in pairs(h) do
        r[v] = (k:gsub(" ","")):lower()
    end
    return r
end

function table.reverse(t)
    local tt = { }
    if #t > 0 then
        for i=#t,1,-1 do
            tt[#tt+1] = t[i]
        end
    end
    return tt
end
