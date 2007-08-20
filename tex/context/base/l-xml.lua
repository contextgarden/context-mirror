if not modules then modules = { } end modules ['l-xml'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Tthe parser used here is inspired by the variant discussed in the lua book, but
handles comment and processing instructions, has a different structure, provides
parent access; a first version used different tricky but was less optimized to we
went this route.</p>

<p>Expecially the lpath code is experimental, we will support some of xpath, but
only things that make sense for us; as compensation it is possible to hook in your
own functions. Apart from preprocessing content for <l n='context'/> we also need
this module for process management, like handling <l n='ctx'/> and <l n='rlx'/>
files.</p>

<typing>
a/b/c /*/c (todo: a/b/(pattern)/d)
a/b/c/first() a/b/c/last() a/b/c/index(n) a/b/c/index(-n)
a/b/c/text() a/b/c/text(1) a/b/c/text(-1) a/b/c/text(n)
</typing>

<p>Beware, the interface may change. For instance at, ns, tg, dt may get more
verbose names. Once the code is stable we will also removee some tracing and
optimize the code.</p>
--ldx]]--

xml = xml or { }
tex = tex or { }

do

    -- The dreadful doctype comes in many disguises:
    --
    -- <!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
    -- <!DOCTYPE Something PUBLIC "... ..." "..." >
    -- <!DOCTYPE Something SYSTEM "... ..." [ ... ] >
    -- <!DOCTYPE Something SYSTEM "... ..." >
    -- <!DOCTYPE Something [ ... ] >
    -- <!DOCTYPE Something >

    local doctype_patterns = {
        "<!DOCTYPE%s+(.-%s+PUBLIC%s+%b\"\"%s+%b\"\"%s+%b[])%s*>",
        "<!DOCTYPE%s+(.-%s+PUBLIC%s+%b\"\"%s+%b\"\")%s*>",
        "<!DOCTYPE%s+(.-%s+SYSTEM%s+%b\"\"%s+%b[])%s*>",
        "<!DOCTYPE%s+(.-%s+SYSTEM%s+%b\"\")%s*>",
        "<!DOCTYPE%s+(.-%s%b[])%s*>",
        "<!DOCTYPE%s+(.-)%s*>"
    }

    -- We assume no "<" which is the lunatic part of the xml spec
    -- especially since ">" is permitted; otherwise we need a char
    -- by char parser ... more something for later ... normally
    -- entities will be used anyway.

    local function prepare(data) -- todo: option to delete doctype stuff, comment, etc
        -- pack (for backward compatibility)
        if type(data) == "table" then
            data = table.concat(data,"")
        end
        -- CDATA
        data = data:gsub("<%!%[CDATA%[(.-)%]%]>", function(txt)
            return string.format("<@cd@>%s</@cd@>",txt:to_hex())
        end)
        -- DOCTYPE
        data = data:gsub("^(.-)(<[^%!%?])", function(a,b)
            if a:find("<!DOCTYPE ") then
                for _,v in ipairs(doctype_patterns) do
                    a = a:gsub(v, function(d) return string.format("<@dd@>%s</@dd@>",d:to_hex()) end)
                end
            end
            return a .. b
        end,1)
        -- comment / does not catch doctype
        data = data:gsub("<%!%-%-(.-)%-%->", function(txt)
            return string.format("<@cm@>%s</@cm@>",txt:to_hex())
        end)
        -- processing instructions
        data = data:gsub("<%?(.-)%?>", function(txt)
            return string.format("<@pi@>%s</@pi@>",txt:to_hex())
        end)
        return data
    end

    local function split(s)
        local t = {}
        for namespace, tag, _,val in s:gmatch("(%w-):?(%w+)=([\"\'])(.-)%3") do
            if namespace == "" then
                t[tag] = val
            else
                t[tag] = val
            end
        end
        return t
    end

    function xml.convert(data,no_root,collapse)
        local data = prepare(data)
        local stack, top = {}, {}
        local i, j, errorstr = 1, 1, nil
        stack[#stack+1] = top
        top.dt = { }
        local dt = top.dt
        while true do
            local ni, first, attributes, last, fulltag
            ni, j, first, fulltag, attributes, last = data:find("<(/-)([^%s%>/]+)%s*([^>]-)%s*(/-)>", j)
            if not ni then break end
            local namespace, tag = fulltag:match("^(.-):(.+)$")
            if not tag then
                namespace, tag = "", fulltag
            end
            local text = data:sub(i, ni-1)
            if (text == "") or (collapse and text:find("^%s*$")) then
                -- no need for empty text nodes, beware, also packs <a>x y z</a>
                -- so is not that useful unless used with empty elements
            else
                dt[#dt+1] = text
            end
            if first == "/" then
                -- end tag
                local toclose = table.remove(stack)  -- remove top
                top = stack[#stack]
                if #stack < 1 then
                    errorstr = "nothing to close with " .. tag
                    break
                end
                if toclose.tg ~= tag then
                    errorstr = "unable to close " .. toclose.tg .. " with " .. tag
                    break
                end
                dt= top.dt
                dt[#dt+1] = toclose
            elseif last == "/" then
                -- empty element tag
                if attributes == "" then
                    dt[#dt+1] = { ns=namespace, tg=tag }
                else
                    dt[#dt+1] = { ns=namespace, tg=tag, at=split(attributes) }
                end
                setmetatable(top, { __tostring = xml.text } )
                dt[#dt].__p__ = top
            else
                -- begin tag
                if attributes == "" then
                    top = { ns=namespace, tg=tag, dt = { } }
                else
                    top = { ns=namespace, tg=tag, at=split(attributes), dt = { } }
                end
                top.__p__ = stack[#stack]
                setmetatable(top, { __tostring = xml.text } )
                dt = top.dt
                stack[#stack+1] = top
            end
            i = j + 1
        end
        if not errorstr then
            local text = data:sub(i)
            if dt and not text:find("^%s*$") then
                dt[#dt+1] = text
            end
            if #stack > 1 then
                errorstr = "unclosed " .. stack[#stack].tg
            end
        end
        if errorstr then
        --  stack = { [1] = { tg = "error", dt = { [1] = errorstr } } }
            stack = { { tg = "error", dt = { errorstr } } }
            setmetatable(stack, { __tostring = xml.text } )
        end
        if no_root then
            return stack[1]
        else
            local t = { tg = '@rt@', dt = stack[1].dt }
            setmetatable(t, { __tostring = xml.text } )
            return t
        end
    end

end

function xml.load(filename,collapse)
    if type(filename) == "string" then
        local root, f = { }, io.open(filename,'r') -- no longer 'rb'
        if f then
            root = xml.convert(f:read("*all"),false,collapse)
            f:close()
        end
        return root
    else
        return xml.convert(filename:read("*all"),false,collapse)
    end
end

function xml.toxml(data,collapse)
    local t = { xml.convert(data,true,collapse) }
    if #t > 1 then
        return t
    else
        return t[1]
    end
end

function xml.serialize(e, handle, textconverter, attributeconverter) -- check if string:format is faster
    local format = string.format
    handle = handle or (tex and tex.sprint) or io.write
    local function flush(before,e,after)
        handle(before)
        for _,ee in ipairs(e.dt) do -- i added, todo iloop
            xml.serialize(ee,handle,string.from_hex)
        end
        handle(after)
    end
    if e then
        if e.tg then
            if e.tg == "@pi@" then
                flush("<?",e,"?>")
            elseif e.tg == "@cm@" then
                flush("<!--",e,"-->")
            elseif e.tg == "@cd@" then
                flush("<![CDATA[",e,"]]>")
            elseif e.tg == "@dd@" then
                flush("<!DOCTYPE ",e,">")
            elseif e.tg == "@rt@" then
                xml.serialize(e.dt,handle,textconverter,attributeconverter)
            else
                if e.ns ~= "" then
                    handle(format("<%s:%s",e.ns,e.tg))
                else
                    handle(format("<%s",e.tg))
                end
                if e.at then
                    if attributeconverter then
                        for k,v in pairs(e.at) do
                            handle(format(' %s=%q',k,attributeconverter(v)))
                        end
                    else
                        for k,v in pairs(e.at) do
                            handle(format(' %s=%q',k,v))
                        end
                    end
                end
                if e.dt then
                    handle(">")
                    for k,ee in ipairs(e.dt) do -- i added, for i=1,n is faster
                        xml.serialize(ee,handle,textconverter,attributeconverter)
                    end
                    handle(format("</%s>",e.tg))
                else
                    handle("/>")
                end
            end
        elseif type(e) == "string" then
            if textconverter then
                handle(textconverter(e))
            else
                handle(e)
            end
        else
            for _,ee in ipairs(e) do -- i added
                xml.serialize(ee,handle,textconverter,attributeconverter)
            end
        end
    end
end

function xml.string(e,handle)
    if e.tg then
        if e.dt then
            for _,ee in ipairs(e.dt) do -- i added
                xml.string(ee,handle)
            end
        end
    else
        handle(e)
    end
end

function xml.save(root,name)
    local f = io.open(name,"w")
    if f then
        xml.serialize(root,function(s) f:write(s) end)
        f:close()
    end
end

function xml.stringify(root)
    local result = { }
    xml.serialize(root,function(s) result[#result+1] = s end)
    return table.concat(result,"")
end

xml.tostring = xml.stringify

function xml.stringify_text(root) -- no root element
    if root and root.dt then
        return xml.stringify(root)
    else
        return ""
    end
end

function xml.text(dt) -- no root element
    if dt then
        return xml.stringify(dt)
    else
        return ""
    end
end

function xml.body(t) -- removes initial pi
    if t and t.dt and t.tg == "@rt@" then
        for k,v in ipairs(t.dt) do
            if type(v) == "table" and v.tg ~= "@pi@" then
                return v
            end
        end
    end
    return t
end

-- call: e[k] = xml.empty() or xml.empty(e,k)

function xml.empty(e,k) -- erases an element but keeps the table intact
    if e and k then
        e[k] = ""
        return e[k]
    else
        return ""
    end
end

-- call: e[k] = xml.assign(t) or xml.assign(e,k,t)

function xml.assign(e,k,t) -- assigns xml tree / more testing will be done
    if e and k then
        if type(t) == "table" then
            e[k] = xml.body(t)
        else
            e[k] = t -- no parsing
        end
        return e[k]
    else
        return xml.body(t)
    end
end

-- 0=nomatch 1=match 2=wildcard 3=ancestor

-- "tag"
-- "tag1/tag2/tag3"
-- "*/tag1/tag2/tag3"
-- "/tag1/tag2/tag3"
-- "/tag1/tag2|tag3"
-- "tag[@att='value']
-- "tag1|tag2[@att='value']

xml.trace_lpath  = false

function xml.tag(e)
    return e.tg or ""
end

function xml.att(e,a)
    return (e.at and e.at[a]) or ""
end

xml.attribute = xml.att

do

    local cache = { }

    local function fault   ( ) return 0 end
    local function wildcard( ) return 2 end
    local function result  (b) if b then return 1 else return 0 end end

    -- we can avoid functions: m[i] = number|function

    function xml.lpath(str) --maybe @rt@ special
        str = str or "*"
        local m = cache[str]
        if not m then
            -- todo: text()
            if not str then
                if xml.trace_lpath then print("lpath", "no string", "wildcard") end
                m = {
                    function(e)
                        if xml.trace_lpath then print(2, 1, "wildcard", e.tg) end
                        return 2
                    end
                }
            elseif type(str) == "table" then
                if xml.trace_lpath then print("lpath", "table" , "inherit") end
                m = str
            else
                if str == "" or str == "*" then
                    if xml.trace_lpath then print("lpath", "empty or *", "wildcard") end
                    m = {
                        function(e)
                            if xml.trace_lpath then print(2, 2, "wildcard", e.tg) end
                            return 2
                        end
                    }
                else
                    m = { }
                    if str:find("^/") then
                        -- done in split
                    else
                        if xml.trace_lpath then print("lpath", "/", "wildcard") end
                        m[#m+1] = function(e,i)
                            if xml.trace_lpath then print(2, 3, "wildcard", e.tg) end
                            return 2
                        end
                    end
                    for v in str:gmatch("([^/]+)") do
                        if v == "" or v == "*" then
                          if #m > 0 then -- when not, then we get problems with root being second (after <?xml ...?> (we could start at dt[2])
                                if xml.trace_lpath then print("lpath", "empty or *", "wildcard") end
                                m[#m+1] = function(e,i)
                                    if xml.trace_lpath then print(2, 4, "wildcard", e.ns, e.tg) end
                                    return 2
                                end
                          end
                        elseif v == ".." then
                            if xml.trace_lpath then print("lpath", "..", "ancestor") end
                            m[#m+1] = function(e,i)
                                if xml.trace_lpath then print(3, 5, "ancestor", e.__p__.tg) end
                                return 3
                            end
                        else
                            local n, a, t = v:match("^(.-)%[@(.-)=(.-)%]$")
                            if n and a and t then
                                local s = ""
                                local ns, tg = n:match("^(.-):(.+)$")
                                if tg then
                                    s, n = ns, tg
                                end
                            --  t = t:gsub("^([\'\"])([^%1]*)%1$", "%2") -- todo
                                t = t:gsub("^\'(.*)\'$", "%1") -- todo
                                t = t:gsub("^\"(.*)\"$", "%1") -- todo
                                if v:find("|") then
                                    -- todo: ns ! ! ! ! ! ! ! ! !
                                    local tt = n:split("|")
                                    if xml.trace_lpath then print("lpath", "match", t, n) end
                                    m[#m+1] = function(e,i)
                                        for _,v in ipairs(tt) do -- i added, todo: iloop
                                            if e.at and e.tg == v and e.at[a] == t then
                                                if xml.trace_lpath then print(1, 6, "element ", v, "attribute", t) end
                                                return 1
                                            end
                                        end
                                        if xml.trace_lpath then print(1, 6, "no match") end
                                        return 0
                                    end
                                else
                                    if xml.trace_lpath then print("lpath", "match", t, n) end
                                    m[#m+1] = function(e,i)
                                        if e.at and e.ns == s and e.tg == n and e.at[a] == t then
                                            if xml.trace_lpath then print(1, 7, "element ", n, "attribute", t) end
                                            return 1
                                        else
                                            if xml.trace_lpath then print(1, 7, "no match") end
                                            return 0
                                        end
                                    end
                                end
                            elseif v:find("|") then
                                local tt = v:split("|")
                                for k,v in ipairs(tt) do -- i added, iloop is faster
                                    if xml.trace_lpath then print("lpath", "or match", v) end
                                    local ns, tg = v:match("^(.-):(.+)$")
                                    if not tg then
                                        ns, tg = "", v
                                    end
                                    tt[k] = function(e,i)
                                        if ns == e.ns and tg == e.tg then
                                            if xml.trace_lpath then print(1, 8, "element ", ns, tg) end
                                            return 1
                                        else
                                            if xml.trace_lpath then print(1, 8, "no match", ns, tg) end
                                            return 0
                                        end
                                    end
                                end
                                m[#m+1] = function(e,i)
                                    for _,v in ipairs(tt) do -- i added, iloop is faster
                                        if v(e,i) then
                                            return 1
                                        end
                                    end
                                    return 0
                                end
                            else
                                if xml.trace_lpath then print("lpath", "match", v) end
                                local ns, tg = v:match("^(.-):(.+)$")
                                if not tg then
                                    ns, tg = "", v
                                end
                                m[#m+1] = function(e,i)
                                    if ns == e.ns and tg == e.tg then
                                        if xml.trace_lpath then print(1, 9, "element ", ns, tg) end
                                        return 1
                                    else
                                        if xml.trace_lpath then print(1, 9, "no match", ns, tg) end
                                        return 0
                                    end
                                end
                            end
                        end
                    end
                end
                if xml.trace_lpath then print("lpath", "result", str, "size", #m) end
            end
            cache[str] = m
        end
        return m
    end

    function xml.traverse_tree(root,pattern,handle,reverse,index,wildcard)
        if root and root.dt then
            index = index or 1
            local match = pattern[index] or wildcard
--~             local prev = pattern[index-1] or fault -- better use the wildcard
            local traverse = xml.traverse_tree
            local rootdt = root.dt
            local start, stop, step = 1, #rootdt, 1
            if reverse and index == #pattern then
                start, stop, step = stop, start, -1
            end
            for k=start,stop,step do
                local e = rootdt[k]
                if e.tg then
                    local m = (type(match) == "function" and match(e,index)) or match
                    if m == 1 then -- match
                        if index < #pattern then
                            if not traverse(e,pattern,handle,reverse,index+1) then return false end
                        elseif handle(rootdt,k) then
                            return false
                        end
                    elseif m == 2 then -- wildcard (not ok, now same as 3)
                        if index < #pattern then
                            if not traverse(e,pattern,handle,reverse,index+1,true) then return false end
                        elseif handle(rootdt,k) then
                            return false
                        end
                    elseif m == 3 then -- ancestor
                        local ep = e.__p__
                        if index < #pattern then
                            if not traverse(ep,pattern,handle,reverse,index+1) then return false end
                        elseif handle(rootdt,k) then
                            return false
                        end
--~                     elseif prev(e,index) == 2 then -- wildcard
--~                         if not traverse(e,pattern,handle,reverse,index) then return false end
                    elseif wildcard then -- maybe two kind of wildcards: * ** //
                        if not traverse(e,pattern,handle,reverse,index,wildcard) then return false end
                    end
                else
                    local edt = e.dt
                    if edt then
                        -- todo ancester
                        for kk=1,#edt do
                            local ee = edt[kk]
                            if match(ee,index) > 0 then
                                if index < #pattern then
                                    if not traverse(ee,pattern,handle,reverse,index+1) then return false end
                                elseif handle(rootdt,k) then
--~                                 elseif handle(edt,kk) then
                                    return false
                                end
                            elseif prev(ee) == 2 then
                                if not traverse(ee,pattern,handle,reverse,index) then return false end
                            end
                        end
                    end
                end
            end
        end
        return true
    end

    local traverse, lpath, convert = xml.traverse_tree, xml.lpath, xml.convert

    xml.filters = { }

    function xml.filters.default(root,pattern)
        local ee, kk
        traverse(root, lpath(pattern), function(e,k) ee,kk = e,k return true end)
        return ee and ee[kk], ee, kk
    end
    function xml.filters.reverse(root,pattern)
        local ee, kk
        traverse(root, lpath(pattern), function(e,k) ee,kk = e,k return true end,'reverse')
        return ee and ee[kk], ee, kk
    end
    function xml.filters.count(root, pattern)
        local n = 0
        traverse(root, lpath(pattern), function(e,k) n = n + 1 end)
        return n
    end
    function xml.filters.first(root,pattern)
        local ee, kk
        traverse(root, lpath(pattern), function(e,k) ee,kk = e,k return true end)
        return ee and ee[kk], ee, kk
    end
    function xml.filters.last(root,pattern)
        local ee, kk
        traverse(root, lpath(pattern), function(e,k) ee,kk = e,k return true end, 'reverse')
        return ee and ee[kk], ee, kk
    end
    function xml.filters.index(root,pattern,arguments)
        local ee, kk, reverse, i = nil, ni, false, tonumber(arguments or '1') or 1
        if i and i ~= 0 then
            if i < 0 then
                reverse, i = true, -i
            end
            traverse(root, lpath(pattern), function(e,k) ee, kk, i = e, k , i-1 return i == 0 end, reverse)
            if i > 0 then
                return nil, nil, nil
            else
                return ee and ee[kk], ee, kk
            end
        else
            return nil, nil, nil
        end
    end
    function xml.filters.attributes(root,pattern,arguments)
        local ee, kk
        traverse(root, lpath(pattern), function(e,k) ee,kk = e,k return true end)
        local ekat = ee and ee[kk] and ee[kk].at
        if ekat then
            if arguments then
                return ekat[arguments] or "", ee, kk
            else
                return ekat, ee, kk
            end
        else
            return {}, ee, kk
        end
    end
    function xml.filters.text(root,pattern,arguments)
        local ek, ee, kk = xml.filters.index(root,pattern,arguments)
        return (ek and ek.dt and ek.dt[1]) or ""
    end

    function xml.filter(root,pattern)
        local pat, fun, arg = pattern:match("^(.+)/(.-)%((.*)%)$")
        if fun then
            return (xml.filters[fun] or xml.filters.default)(root,pat,arg)
        else
            pat, arg = pattern:match("^(.+)/@(.-)$")
            if arg then
                return xml.filters.attributes(root,pat,arg)
            else
                return xml.filters.default(root,pattern)
            end
        end
    end

    xml.filters.position = xml.filters.index

    -- these may go away

    xml.index_element  = xml.filters.index
    xml.count_elements = xml.filters.count
    xml.first_element  = xml.filters.first
    xml.last_element   = xml.filters.last
    xml.index_text     = xml.filters.text
    xml.first_text     = function (root,pattern) return xml.filters.text(root,pattern, 1) end
    xml.last_text      = function (root,pattern) return xml.filters.text(root,pattern,-1) end

    -- so far

    function xml.get_text(root,pattern,reverse)
        local ek
        traverse(root, lpath(pattern), function(e,k) ek = e and e[k] end, reverse)
        return (ek and ek.dt and ek.dt[1]) or ""
    end

    function xml.each_element(root, pattern, handle, reverse)
        local ok
        traverse(root, lpath(pattern), function(e,k) ok = true handle(e[k],e,k) end, reverse)
        return ok
    end

    function xml.get_element(root,pattern,reverse)
        local ee, kk
        traverse(root, lpath(pattern), function(e,k) ee,kk = e,k end, reverse)
        return ee and ee[kk], ee, kk
    end

    function xml.all_elements(root, pattern, handle, reverse)
        local t = { }
        traverse(root, lpath(pattern), function(e,k) t[#t+1] = e[k] end)
        return t
    end

    function xml.all_texts(root, pattern, handle, reverse)
        local t = { }
        traverse(root, lpath(pattern), function(e,k)
            local ek = e[k]
            t[#t+1] = (ek and ek.dt and ek.dt[1]) or ""
        end)
        return t
    end

    -- array for each

    function xml.insert_element(root, pattern, element, before) -- todo: element als functie
        if root and element then
            local matches, collect = { }, nil
            if type(element) == "string" then
                element = convert(element,true)
            end
            if element and element.td == "@rt@" then
                element = element.dt
            end
            if element then
                if before then
                    collect = function(e,k) matches[#matches+1] = { e, element, k     } end
                else
                    collect = function(e,k) matches[#matches+1] = { e, element, k + 1 } end
                end
                traverse(root, lpath(pattern), collect)
                for i=#matches,1,-1 do
                    local m = matches[i]
                    local t, element, at = m[1],m[2],m[3]
                    -- when string, then element is { dt = { ... }, { ... } }
                    if element.tg then
                        table.insert(t,at,element) -- untested
                    elseif element.dt then
                        for _,v in ipairs(element.dt) do -- i added
                            table.insert(t,at,v)
                            at = at + 1
                        end
                    end
                end
            end
        end
    end

    -- first, last, each

    xml.insert_element_after  =                 xml.insert_element
    xml.insert_element_before = function(r,p,e) xml.insert_element(r,p,e,true) end

    function xml.delete_element(root, pattern)
        local matches, deleted = { }, { }
        local collect = function(e,k) matches[#matches+1] = { e, k } end
        traverse(root, lpath(pattern), collect)
        for i=#matches,1,-1 do
            local m = matches[i]
            deleted[#deleted+1] = table.remove(m[1],m[2])
        end
        return deleted
    end

    function xml.replace_element(root, pattern, element)
        if type(element) == "string" then
            element = convert(element,true)
        end
        if element and element.td == "@rt@" then
            element = element.dt
        end
        if element then
            local collect = function(e,k)
                e[k] = element.dt -- maybe not clever enough
            end
            traverse(root, lpath(pattern), collect)
        end
    end

    function xml.process(root, pattern, handle)
        traverse(root, lpath(pattern), function(e,k)
            if e[k].dt then
                for k,v in ipairs(e[k].dt) do if v.tg then handle(v) end end -- i added
            end
        end)
    end

 --  function xml.process_attributes(root, pattern, handle)
 --      traverse(root, lpath(pattern), function(e,k) handle(e[k].at) end)
 --  end

    function xml.process_attributes(root, pattern, handle)
        traverse(root, lpath(pattern), function(e,k)
            local ek = e[k]
            local a = ek.at or { }
            handle(a)
            if next(a) then
                ek.at = a
            else
                ek.at = nil
            end
        end)
    end

    function xml.package(tag,attributes,data)
        local n, t = tag:match("^(.-):(.+)$")
        if attributes then
            return { ns = n or "", tg = t or tag, dt = data or "", at = attributes }
        else
            return { ns = n or "", tg = t or tag, dt = data or "" }
        end
    end

    -- some special functions, handy for the manual:

    function xml.gsub(t,old,new)
        if t.dt then
            for k,v in ipairs(t.dt) do
                if type(v) == "string" then
                    t.dt[k] = v:gsub(old,new)
                else
                    xml.gsub(v,old,new)
                end
            end
        end
    end

    function xml.strip_leading_spaces(ek, e, k) -- cosmetic, for manual
        if e and k and e[k-1] and type(e[k-1]) == "string" then
            local s = e[k-1]:match("\n(%s+)")
            xml.gsub(ek,"\n"..string.rep(" ",#s),"\n")
        end
    end

    function xml.serialize_path(root,lpath,handle)
        local ek, e, k = xml.first_element(root,lpath)
        ek = table.copy(ek)
        xml.strip_leading_spaces(ek,e,k)
        xml.serialize(ek,handle)
    end

end

xml.count   = xml.filters.count
xml.index   = xml.filters.index
xml.first   = xml.filters.first
xml.last    = xml.filters.last

xml.each    = xml.each_element
xml.all     = xml.all_elements

xml.insert  = xml.insert_element_after
xml.after   = xml.insert_element_after
xml.before  = xml.insert_element_before
xml.delete  = xml.delete_element
xml.replace = xml.replace_element

-- a few helpers, the may move to lxml modules

function xml.include(xmldata,element,attribute,pathlist,collapse)
    element   = element   or 'ctx:include'
    attribute = attribute or 'name'
    pathlist  = pathlist or { '.' }
    local function include(ek,e,k)
        local name = (ek.at and ek.at[attribute]) or ""
        if name ~= "" then
            -- maybe file lookup in tree
            local fullname
            for _, path in ipairs(pathlist) do
                if path == '.' then
                    fullname = name
                else
                    fullname = file.join(path,name)
                end
                local f = io.open(fullname)
                if f then
                    xml.assign(e,k,xml.load(f,collapse))
                    f:close()
                    break
                else
                    xml.empty(e,k)
                end
            end
        else
            xml.empty(e,k)
        end
    end
    while xml.each(xmldata, element, include) do end
end

