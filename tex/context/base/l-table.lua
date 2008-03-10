-- filename : l-table.lua
-- comment  : split off from luat-lib
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-table'] = 1.001

table.join = table.concat

function table.strip(tab)
    local lst = { }
    for k, v in ipairs(tab) do
     -- s = string.gsub(v, "^%s*(.-)%s*$", "%1")
        s = v:gsub("^%s*(.-)%s*$", "%1")
        if s == "" then
            -- skip this one
        else
            lst[#lst+1] = s
        end
    end
    return lst
end

--~ function table.sortedkeys(tab)
--~     local srt = { }
--~     for key,_ in pairs(tab) do
--~         srt[#srt+1] = key
--~     end
--~     table.sort(srt)
--~     return srt
--~ end

function table.sortedkeys(tab)
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
        table.sort(srt,function(a,b) return (tostring(a) < tostring(b)) end)
    else
        table.sort(srt)
    end
    return srt
end

function table.append(t, list)
    for _,v in pairs(list) do
        table.insert(t,v)
    end
end

function table.prepend(t, list)
    for k,v in pairs(list) do
        table.insert(t,k,v)
    end
end

--~ function table.merge(t, ...)
--~     for _, list in ipairs({...}) do
--~         for k,v in pairs(list) do
--~             t[k] = v
--~         end
--~     end
--~     return t
--~ end

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

--~ function table.merged(...)
--~     local tmp = { }
--~     for _, list in ipairs({...}) do
--~         for k,v in pairs(list) do
--~             tmp[k] = v
--~         end
--~     end
--~     return tmp
--~ end

function table.merged(...)
    local tmp, lst = { }, {...}
    for i=1,#lst do
        for k, v in pairs(lst[i]) do
            tmp[k] = v
        end
    end
    return tmp
end

--~ function table.imerge(t, ...)
--~     for _, list in ipairs({...}) do
--~         for _, v in ipairs(list) do
--~             t[#t+1] = v
--~         end
--~     end
--~     return t
--~ end

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

--~ function table.imerged(...)
--~     local tmp = { }
--~     for _, list in ipairs({...}) do
--~         for _,v in pairs(list) do
--~             tmp[#tmp+1] = v
--~         end
--~     end
--~     return tmp
--~ end

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

if not table.fastcopy then do

    local type, pairs, getmetatable, setmetatable = type, pairs, getmetatable, setmetatable

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

    table.fastcopy = fastcopy

end end

if not table.copy then do

    local type, pairs, getmetatable, setmetatable = type, pairs, getmetatable, setmetatable

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

    table.copy = copy

end end

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

do

    -- one of my first exercises in lua ...

    -- 34.055.092 32.403.326 arabtype.tma
    --  1.620.614  1.513.863 lmroman10-italic.tma
    --  1.325.585  1.233.044 lmroman10-regular.tma
    --  1.248.157  1.158.903 lmsans10-regular.tma
    --    194.646    153.120 lmtypewriter10-regular.tma
    --  1.771.678  1.658.461 palatinosanscom-bold.tma
    --  1.695.251  1.584.491 palatinosanscom-regular.tma
    -- 13.736.534 13.409.446 zapfinoextraltpro.tma

    -- 13.679.038 11.774.106 arabtype.tmc
    --    886.248    754.944 lmroman10-italic.tmc
    --    729.828    466.864 lmroman10-regular.tmc
    --    688.482    441.962 lmsans10-regular.tmc
    --    128.685     95.853 lmtypewriter10-regular.tmc
    --    715.929    582.985 palatinosanscom-bold.tmc
    --    669.942    540.126 palatinosanscom-regular.tmc
    --  1.560.588  1.317.000 zapfinoextraltpro.tmc

    table.serialize_functions = true
    table.serialize_compact   = true
    table.serialize_inline    = true

    local function key(k)
        if type(k) == "number" then -- or k:find("^%d+$") then
            return "["..k.."]"
        elseif noquotes and k:find("^%a[%a%d%_]*$") then
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
            --  for _,v in ipairs(t) do
                for i=1,#t do
                    local v = t[i]
                    local tv = type(v)
                    if tv == "number" or tv == "boolean" then
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

    local function serialize(root,name,handle,depth,level,reduce,noquotes,indexed)
        handle = handle or print
        reduce = reduce or false
        if depth then
            depth = depth .. " "
            if indexed then
                handle(("%s{"):format(depth))
            else
                handle(("%s%s={"):format(depth,key(name)))
            end
        else
            depth = ""
            local tname = type(name)
            if tname == "string" then
                if name == "return" then
                    handle("return {")
                else
                    handle(name .. "={")
                end
            elseif tname == "number" then
                handle("[" .. name .. "]={")
            elseif tname == "boolean" then
                if name then
                    handle("return {")
                else
                    handle("{")
                end
            else
                handle("t={")
            end
        end
        if root and next(root) then
            local compact = table.serialize_compact
            local inline  = compact and table.serialize_inline
            local first, last = nil, 0 -- #root cannot be trusted here
            if compact then
              for k,v in ipairs(root) do -- NOT: for k=1,#root do
                    if not first then first = k end
                    last = last + 1
                end
            end
            for _,k in pairs(table.sortedkeys(root)) do
                local v = root[k]
                local t = type(v)
                if compact and first and type(k) == "number" and k >= first and k <= last then
                    if t == "number" then
                        handle(("%s %s,"):format(depth,v))
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
                                handle(("%s { %s },"):format(depth,table.concat(st,", ")))
                            else
                                serialize(v,k,handle,depth,level+1,reduce,noquotes,true)
                            end
                        else
                            serialize(v,k,handle,depth,level+1,reduce,noquotes,true)
                        end
                    elseif t == "boolean" then
                        handle(("%s %s,"):format(depth,tostring(v)))
                    elseif t == "function" then
                        if table.serialize_functions then
                            handle(('%s loadstring(%q),'):format(depth,string.dump(v)))
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
                    handle(("%s %s=%s,"):format(depth,key(k),v))
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
                            handle(("%s %s={ %s },"):format(depth,key(k),table.concat(st,", ")))
                        else
                            serialize(v,k,handle,depth,level+1,reduce,noquotes)
                        end
                    else
                        serialize(v,k,handle,depth,level+1,reduce,noquotes)
                    end
                elseif t == "boolean" then
                    handle(("%s %s=%s,"):format(depth,key(k),tostring(v)))
                elseif t == "function" then
                    if table.serialize_functions then
                        handle(('%s %s=loadstring(%q),'):format(depth,key(k),string.dump(v)))
                    else
                        handle(('%s %s="function",'):format(depth,key(k)))
                    end
                else
                    handle(("%s %s=%q,"):format(depth,key(k),tostring(v)))
                --  handle(('%s %s=loadstring(%q),'):format(depth,key(k),string.dump(function() return v end)))
                end
            end
            if level > 0 then
                handle(("%s},"):format(depth))
            else
                handle(("%s}"):format(depth))
            end
        else
            handle(("%s}"):format(depth))
        end
    end

    --~ name:
    --~
    --~ true     : return     { }
    --~ false    :            { }
    --~ nil      : t        = { }
    --~ string   : string   = { }
    --~ 'return' : return     { }
    --~ number   : [number] = { }

    function table.serialize(root,name,reduce,noquotes)
        local t = { }
        local function flush(s)
            t[#t+1] = s
        end
        serialize(root, name, flush, nil, 0, reduce, noquotes)
        return table.concat(t,"\n")
    end

    function table.tohandle(handle,root,name,reduce,noquotes)
        serialize(root, name, handle, nil, 0, reduce, noquotes)
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

    function table.tofile(filename,root,name,reduce,noquotes)
        local f = io.open(filename,'w')
        if f then
            local concat = table.concat
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
                serialize(root, name, flush, nil, 0, reduce, noquotes)
                f:write(concat(t,"\n"),"\n")
            else
                local function flush(s)
                    f:write(s,"\n")
                end
                serialize(root, name, flush, nil, 0, reduce, noquotes)
            end
            f:close()
        end
    end

end

--~ t = {
--~     b = "123",
--~     a = "x",
--~     c = 1.23,
--~     d = "1.23",
--~     e = true,
--~     f = {
--~         d = "1.23",
--~         a = "x",
--~         b = "123",
--~         c = 1.23,
--~         e = true,
--~         f = {
--~             e = true,
--~             f = {
--~                 e = true
--~             },
--~         },
--~     },
--~     g = function() end
--~ }

--~ print(table.serialize(t), "\n")
--~ print(table.serialize(t,"name"), "\n")
--~ print(table.serialize(t,false), "\n")
--~ print(table.serialize(t,true), "\n")
--~ print(table.serialize(t,"name",true), "\n")
--~ print(table.serialize(t,"name",true,true), "\n")

do

    local function flatten(t,f,complete)
        for _,v in ipairs(t) do
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

end

function table.insert_before_value(t,value,str)
    for i=1,#t do
        if t[i] == value then
            table.insert(t,i,str)
            return
        end
    end
    table.insert(t,1,str)
end

function table.insert_after_value(t,value,str)
    for i=1,#t do
        if t[i] == value then
            table.insert(t,i+1,str)
            return
        end
    end
    t[#t+1] = str
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

function table.tohash(t)
    local h = { }
    for _, v in pairs(t) do -- no ipairs here
        h[v] = true
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

function table.contains(t, v)
    if t then
        for i=1, #t do
            if t[i] == v then
                return true
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
    for i=1,#t do tt[i] = string.format("0x%04X",t[i]) end
    return table.concat(tt,seperator or " ")
end
