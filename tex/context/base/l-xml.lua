if not modules then modules = { } end modules ['l-xml'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: ns, tg = s:match("^(.-):?([^:]+)$")

--[[ldx--
<p>The parser used here is inspired by the variant discussed in the lua book, but
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
verbose names. Once the code is stable we will also remove some tracing and
optimize the code.</p>
--ldx]]--

xml = xml or { }
tex = tex or { }

xml.trace_lpath = false
xml.trace_print = false

--[[ldx--
<p>First a hack to enable namespace resolving.</p>
--ldx]]--

do

    xml.xmlns = { }

    local data = { }

    function xml.registerns(namespace,pattern)
        data[#data+1] = { namespace:lower(), pattern:lower() }
    end

    function xml.checkns(namespace,url)
        url = url:lower()
        for i=1,#data do
            local d = data[i]
            if url:find(d[2]) then
                if namespace ~= d[1] then
                    xml.xmlns[namespace] = d[1]
                end
            end
        end
    end

    function xml.resolvens(url)
        url = url:lower()
        for i=1,#data do
            local d = data[i]
            if url:find(d[2]) then
                return d[1]
            end
        end
        return ""
    end

end

--[[ldx--
<p>Next comes the loader. The dreadful doctype comes in many disguises:</p>

<typing>
<!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
<!DOCTYPE Something PUBLIC "... ..." "..." >
<!DOCTYPE Something SYSTEM "... ..." [ ... ] >
<!DOCTYPE Something SYSTEM "... ..." >
<!DOCTYPE Something [ ... ] >
<!DOCTYPE Something >
</typing>
--ldx]]--

do

    -- Loading 12 cont-*.xml and keys-*.xml files totaling to 2.62 MBytes takes 1.1 sec
    -- on a windows vista laptop with dual core 7600 (2.3 Ghz), which is not that bad.
    -- Of this half time is spent on doctype etc parsing.

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

    -- data = data:gsub(nothing done) is still a copy so we find first

    local function prepare(data,text)
        -- pack (for backward compatibility)
        if type(data) == "table" then
            data = table.concat(data,"")
        end
        -- CDATA
        if data:find("<%!%[CDATA%[") then
            data = data:gsub("<%!%[CDATA%[(.-)%]%]>", function(txt)
                text[#text+1] = txt or ""
                return string.format("<@cd@>%s</@cd@>",#text)
            end)
        end
        -- DOCTYPE
        if data:find("<!DOCTYPE ") then
            data = data:gsub("^(.-)(<[^%!%?])", function(a,b)
                if a:find("<!DOCTYPE ") then
                    for _,v in ipairs(doctype_patterns) do
                        a = a:gsub(v, function(d)
                            text[#text+1] = d or ""
                            return string.format("<@dd@>%s</@dd@>",#text)
                        end)
                    end
                end
                return a .. b
            end,1)
        end
        -- comment / does not catch doctype
        data = data:gsub("<%!%-%-(.-)%-%->", function(txt)
            text[#text+1] = txt or ""
            return string.format("<@cm@>%s</@cm@>",#text)
        end)
        -- processing instructions / altijd 1
        data = data:gsub("<%?(.-)%?>", function(txt)
            text[#text+1] = txt or ""
            return string.format("<@pi@>%s</@pi@>",#text)
        end)
        return data, text
    end

    -- maybe we will move the @tg@ stuff to a dedicated key, say 'st'; this will speed up
    -- serializing and testing

    function xml.convert(data,no_root,collapse)
        local crap = { }
        data, crap = prepare(data, crap)
        local nsremap = xml.xmlns
        local remove = table.remove
        local stack, top = {}, {}
        local i, j, errorstr = 1, 1, nil
        stack[#stack+1] = top
        top.dt = { }
        local dt = top.dt
        local id = 0
        local namespaces = { }
        local mt = { __tostring = xml.text }
        while true do
            local ni, first, attributes, last, fulltag
            ni, j, first, fulltag, attributes, last = data:find("<(/-)([^%s%>/]+)%s*([^>]-)%s*(/-)>", j)
            if not ni then break end
            local namespace, tag = fulltag:match("^(.-):(.+)$")
            if attributes ~= "" then
                local t = {}
                for ns, tag, _, value in attributes:gmatch("(%w-):?(%w+)=([\"\'])(.-)%3") do
                    if tag == "xmlns" then -- not ok yet
                        namespaces[#stack] = xml.resolvens(value)
                    elseif ns == "" then
                        t[tag] = value
                    elseif ns == "xmlns" then
                        xml.checkns(tag,value)
                    else
                        t[tag] = value
                    end
                end
                attributes = t
            else
                attributes = { }
            end
            if namespace then -- realtime remapping
                namespace = nsremap[namespace] or namespace
            else
                namespace, tag = namespaces[#stack] or "", fulltag
            end
            local text = data:sub(i, ni-1)
            if text == "" or (collapse and text:find("^%s*$")) then
                -- no need for empty text nodes, beware, also packs <a>x y z</a>
                -- so is not that useful unless used with empty elements
            else
                dt[#dt+1] = text
            end
            if first == "/" then
                -- end tag
                local toclose = remove(stack)  -- remove top
                top = stack[#stack]
                namespaces[#stack] = nil
                if #stack < 1 then
                    errorstr = string.format("nothing to close with %s", tag)
                    break
                elseif toclose.tg ~= tag then -- no namespace check
                    errorstr = string.format("unable to close %s with %s", toclose.tg, tag)
                    break
                end
                if tag:find("^@..@$") then
                    dt[1] = crap[tonumber(dt[1])] or ""
                end
                dt = top.dt
                dt[#dt+1] = toclose
            elseif last == "/" then
                -- empty element tag
                dt[#dt+1] = { ns = namespace, tg = tag, dt = { }, at = attributes, __p__ = top }
            --  setmetatable(top, { __tostring = xml.text })
                setmetatable(top, mt)
            else
                -- begin tag
                top = { ns = namespace, tg = tag, dt = { }, at = attributes, __p__ = stack[#stack] }
            --  setmetatable(top, { __tostring = xml.text })
                setmetatable(top, mt)
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
                errorstr = string.format("unclosed %s", stack[#stack].tg)
            end
        end
        if errorstr then
            stack = { { tg = "error", dt = { errorstr } } }
        --  setmetatable(stack, { __tostring = xml.text })
            setmetatable(stack, mt)
        end
        if no_root then
            return stack[1]
        else
            local t = { ns = "", tg = '@rt@', dt = stack[1].dt }
        --  setmetatable(t, { __tostring = xml.text })
            setmetatable(t, mt)
            for k,v in ipairs(t.dt) do
                if type(v) == "table" and v.tg ~= "@pi@" and v.tg ~= "@dd@" and v.tg ~= "@cm@" then
                    t.ri = k -- rootindex
                    break
                end
            end
            return t
        end
    end

    function xml.copy(old,tables,parent) -- fast one
        tables = tables or { }
        if old then
            local new = { }
            if not table[old] then
                table[old] = new
            end
            for i,v in pairs(old) do
            --  new[i] = (type(v) == "table" and (table[v] or xml.copy(v, tables, table))) or v
                if type(v) == "table" then
                    new[i] = table[v] or xml.copy(v, tables, table)
                else
                    new[i] = v
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

function xml.root(root)
    return (root.ri and root.dt[root.ri]) or root
end

function xml.toxml(data,collapse)
    local t = { xml.convert(data,true,collapse) }
    if #t > 1 then
        return t
    else
        return t[1]
    end
end

function xml.serialize(e, handle, textconverter, attributeconverter)
    handle = handle or (tex and tex.sprint) or io.write
    if not e then
        -- quit
    elseif e.command and xml.command then -- test for command == "" ?
        xml.command(e)
    elseif e.tg then
        local format, serialize = string.format, xml.serialize
        local ens, etg, eat, edt = e.ns, e.tg, e.at, e.dt
        -- no spaces, so no flush needed (check)
        if etg == "@pi@" then
            handle(format("<?%s?>",edt[1]))
        elseif etg == "@cm@" then
            handle(format("<!--%s-->",edt[1]))
        elseif etg == "@cd@" then
            handle(format("<![CDATA[%s]]>",edt[1]))
        elseif etg == "@dd@" then
            handle(format("<!DOCTYPE %s>",edt[1]))
        elseif etg == "@rt@" then
            serialize(edt,handle,textconverter,attributeconverter)
        else
            local ats = eat and next(eat) and { }
            if ats then
                if attributeconverter then
                    for k,v in pairs(eat) do
                        ats[#ats+1] = format('%s=%q',k,attributeconverter(v))
                    end
                else
                    for k,v in pairs(eat) do
                        ats[#ats+1] = format('%s=%q',k,v)
                    end
                end
            end
            if ens ~= "" then
                if edt and #edt > 0 then
                    if ats then
                        handle(format("<%s:%s %s>",ens,etg,table.concat(ats," ")))
                    else
                        handle(format("<%s:%s>",ens,etg))
                    end
                    for i=1,#edt do
                        serialize(edt[i],handle,textconverter,attributeconverter)
                    end
                    handle(format("</%s:%s>",ens,etg))
                else
                    if ats then
                        handle(format("<%s:%s %s/>",ens,etg,table.concat(ats," ")))
                    else
                        handle(format("<%s:%s/>",ens,etg))
                    end
                end
            else
                if edt and #edt > 0 then
                    if ats then
                        handle(format("<%s %s>",etg,table.concat(ats," ")))
                    else
                        handle(format("<%s>",etg))
                    end
                    for i=1,#edt do
                        serialize(edt[i],handle,textconverter,attributeconverter)
                    end
                    handle(format("</%s>",etg))
                else
                    if ats then
                        handle(format("<%s %s/>",etg,table.concat(ats," ")))
                    else
                        handle(format("<%s/>",etg))
                    end
                end
            end
        end
    elseif type(e) == "string" then
        if textconverter then
            handle(textconverter(e))
        else
            handle(e)
        end
    else
        for i=1,#e do
            xml.serialize(e[i],handle,textconverter,attributeconverter)
        end
    end
end

function xml.string(e,handle) -- weird one that may become obsolete
    if e.tg then
        local edt = e.dt
        if edt then
            for i=1,#edt do
                xml.string(edt[i],handle)
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
    if root then
        if type(root) == 'string' then
            return root
        elseif next(root) then
            local result = { }
            xml.serialize(root,function(s) result[#result+1] = s end)
            return table.concat(result,"")
        end
    end
    return ""
end

xml.tostring = xml.stringify

do

    -- print

    local newline = lpeg.P("\n")
    local space   = lpeg.P(" ")
    local content = lpeg.C((1-newline)^1)

    if tex then

        -- taco: we need a kind of raw print into tex, i.e. embedded \n's become lineendings
        -- for tex and an empty line a par; could be a c-wrapper around existing stuff; i
        -- played a lot with tex.print but that does not work ok (should be obeylines save)

        local buffer = {}

        local function cprint(s)
            buffer[#buffer+1] = s
        end
        local function nprint( )
            if #buffer > 0 then
                if xml.trace_print then
                    texio.write_nl(string.format("tex.print : [[[%s]]]", table.join(buffer)))
                end
                tex.print(table.join(buffer))
                buffer = {}
            else
                if xml.trace_print then
                    texio.write_nl(string.format("tex.print : [[[%s]]]", ""))
                end
                tex.print("")
            end
        end
        local function fprint()
            if #buffer > 0 then
                if xml.trace_print then
                    texio.write_nl(string.format("tex.sprint: [[[%s]]]", table.join(buffer)))
                end
                tex.sprint(table.join(buffer))
                buffer = { }
            end
        end

        local line_n  = newline / nprint
        local line_c  = content / cprint
        local capture = (line_n + line_c)^0

        local function sprint(root)
            if not root then
                -- quit
            elseif type(root) == 'string' then
                lpeg.match(capture,root)
            elseif next(root) then
                xml.serialize(root, sprint, nil, nil, true)
            end
        end

        function xml.sprint(root)
            buffer = {}
            sprint(root)
            if #buffer > 0 then
                nprint()
            end
        end

        xml.sflush = fprint

    else

        function xml.sprint(root)
            if not root then
                -- quit
            elseif type(root) == 'string' then
                print(root)
            elseif next(root) then
                xml.serialize(root, xml.sprint, nil, nil, true)
            end
        end

    end

    function xml.tprint(root)
        if type(root) == "table" then
            for i=1,#root do
                xml.sprint(root[i])
            end
        elseif type(root) == "string" then
            xml.sprint(root)
        end
    end

    -- lines (looks hackery, but we cannot pass variables in capture functions)

    local buffer, flush = {}, nil

    local function cprint(s)
        buffer[#buffer+1] = s
    end
    local function nprint()
        flush()
    end

    local line_n  = newline / nprint
    local line_c  = content / cprint
    local capture = (line_n + line_c)^0

    function lines(root)
        if not root then
            -- quit
        elseif type(root) == 'string' then
            lpeg.match(capture,root)
        elseif next(root) then
            xml.serialize(root, lines)
        end
    end

    function xml.lines(root)
        local result = { }
        flush = function()
            result[#result+1] = table.join(buffer)
            buffer = { }
        end
        buffer = {}
        lines(root)
        if #buffer > 0 then
            result[#result+1] = table.join(buffer)
        end
        return result
    end

end

function xml.text(root)
    return (root and xml.stringify(root)) or ""
end

function xml.content(root)
    return (root and root.dt and xml.tostring(root.dt)) or ""
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

function xml.tag(e)
    return e.tg or ""
end

function xml.att(e,a)
    return (e.at and e.at[a]) or ""
end

xml.attribute = xml.att

--~     local cache = { }

--~     local function f_fault   ( ) return 0 end
--~     local function f_wildcard( ) return 2 end
--~     local function f_result  (b) if b then return 1 else return 0 end end

--~     function xml.lpath(str) --maybe @rt@ special
--~         if not str or str == "" then
--~             str = "*"
--~         end
--~         local m = cache[str]
--~         if not m then
--~             -- todo: text()
--~             if type(str) == "table" then
--~                 if xml.trace_lpath then print("lpath", "table" , "inherit") end
--~                 m = str
--~             elseif str == "/" then
--~                 if xml.trace_lpath then print("lpath", "/", "root") end
--~                 m = false
--~             elseif str == "*" then
--~                 if xml.trace_lpath then print("lpath", "no string or *", "wildcard") end
--~                 m = true
--~             else
--~                 str = str:gsub("^//","") -- any
--~                 if str == "" then
--~                     if xml.trace_lpath then print("lpath", "//", "wildcard") end
--~                     m = true
--~                 else
--~                     m = { }
--~                     if not str:find("^/") then
--~                         m[1] = 2
--~                     end
--~                     for v in str:gmatch("([^/]+)") do
--~                         if v == "" or v == "*" then
--~                           if #m > 0 then -- when not, then we get problems with root being second (after <?xml ...?> (we could start at dt[2])
--~                                 if xml.trace_lpath then print("lpath", "empty or *", "wildcard") end
--~                                 m[#m+1] = 2
--~                           end
--~                         elseif v == ".." then
--~                             if xml.trace_lpath then print("lpath", "..", "ancestor") end
--~                             m[#m+1] = 3
--~                         else
--~                             local a, b = v:match("^(.+)::(.-)$")
--~                             if a and b then
--~                                 if a == "ancestor" then
--~                                     if xml.trace_lpath then print("lpath", a, "ancestor") end
--~                                     m[#m+1] = 3
--~                                     -- todo: b
--~                                 elseif a == "pi" then
--~                                     if xml.trace_lpath then print("lpath", a, "processing instruction") end
--~                                     local expr = "^" .. b .. " "
--~                                     m[#m+1] = function(e)
--~                                         if e.tg == '@pi@' and e.dt[1]:find(expr) then
--~                                             return 6
--~                                         else
--~                                             return 0
--~                                         end
--~                                     end
--~                                 end
--~                             else
--~                                 local n, a, t = v:match("^(.-)%[@(.-)=(.-)%]$")
--~                                 if n and a and t then
--~                                     -- todo: namespace, negate
--~                                     -- t = t:gsub("^\'(.*)\'$", "%1")
--~                                     -- t = t:gsub("^\"(.*)\"$", "%1")
--~                                     -- t = t:sub(2,-2) -- "" or '' mandate
--~                                     t = t:gsub("^([\'\"])(.-)%1$", "%2")
--~                                     if n:find("|") then
--~                                         local tt = n:split("|")
--~                                         if xml.trace_lpath then print("lpath", "match", t, n) end
--~                                         m[#m+1] = function(e,i)
--~                                             for i=1,#tt do
--~                                                 if e.at and e.tg == tt[i] and e.at[a] == t then return 1 end
--~                                             end
--~                                             return 0
--~                                         end
--~                                     else
--~                                         if xml.trace_lpath then print("lpath", "match", t, n) end
--~                                         m[#m+1] = function(e)
--~                                             if e.at and e.ns == s and e.tg == n and e.at[a] == t then
--~                                                 return 1
--~                                             else
--~                                                 return 0
--~                                             end
--~                                         end
--~                                     end
--~                                 else -- todo, better tracing (string.format, ook negate etc)
--~                                     local negate = v:sub(1,1) == '^'
--~                                     if negate then v = v:sub(2) end
--~                                     if v:find("|") then
--~                                         local t = { }
--~                                         for s in v:gmatch("([^|]+)") do
--~                                             local ns, tg = s:match("^(.-):(.+)$")
--~                                             if tg == "*" then
--~                                                 if xml.trace_lpath then print("lpath", "or wildcard", ns, tg) end
--~                                                 t[#t+1] = function(e) return e.ns == ns end
--~                                             elseif tg then
--~                                                 if xml.trace_lpath then print("lpath", "or match", ns, tg) end
--~                                                 t[#t+1] = function(e) return e.ns == ns and e.tg == tg end
--~                                             else
--~                                                 if xml.trace_lpath then print("lpath", "or match", s) end
--~                                                 t[#t+1] = function(e) return e.ns == "" and e.tg == s end
--~                                             end
--~                                         end
--~                                         if negate then
--~                                             m[#m+1] = function(e)
--~                                                 for i=1,#t do if t[i](e) then return 0 end end return 1
--~                                             end
--~                                         else
--~                                             m[#m+1] = function(e)
--~                                                 for i=1,#t do if t[i](e) then return 1 end end return 0
--~                                             end
--~                                         end
--~                                     else
--~                                         if xml.trace_lpath then print("lpath", "match", v) end
--~                                         local ns, tg = v:match("^(.-):(.+)$")
--~                                         if not tg then ns, tg = "", v end
--~                                         if tg == "*" then
--~                                             if ns ~= "" then
--~                                                 m[#m+1] = function(e)
--~                                                     if ns == e.ns then return 1 else return 0 end
--~                                                 end
--~                                             end
--~                                         elseif negate then
--~                                             m[#m+1] = function(e)
--~                                                 if ns == e.ns and tg == e.tg then return 0 else return 1 end
--~                                             end
--~                                         else
--~                                             m[#m+1] = function(e)
--~                                                 if ns == e.ns and tg == e.tg then return 1 else return 0 end
--~                                             end
--~                                         end
--~                                     end
--~                                 end
--~                             end
--~                         end
--~                     end
--~                 end
--~             end
--~             if xml.trace_lpath then
--~                 print("# lpath criteria:", (type(m) == "table" and #m) or "none")
--~             end
--~             cache[str] = m
--~         end
--~         return m
--~     end

--~     -- if handle returns true, then quit

--~     function xml.traverse(root,pattern,handle,reverse,index,wildcard)
--~         if not root then -- error
--~             return false
--~         elseif pattern == false then -- root
--~             handle(root,root.dt,root.ri)
--~             return false
--~         elseif pattern == true then -- wildcard
--~             local traverse = xml.traverse
--~             local rootdt = root.dt
--~             if rootdt then
--~                 local start, stop, step = 1, #rootdt, 1
--~                 if reverse then
--~                     start, stop, step = stop, start, -1
--~                 end
--~                 for k=start,stop,step do
--~                     if handle(root,rootdt,root.ri or k)            then return false end
--~                     if not traverse(rootdt[k],true,handle,reverse) then return false end
--~                 end
--~             end
--~             return false
--~         elseif root and root.dt then
--~             index = index or 1
--~             local match = pattern[index] or f_wildcard
--~             local traverse = xml.traverse
--~             local rootdt = root.dt
--~             local start, stop, step = 1, #rootdt, 1
--~             if reverse and index == #pattern then -- maybe no index test here / error?
--~                 start, stop, step = stop, start, -1
--~             end
--~             for k=start,stop,step do
--~                 local e = rootdt[k]
--~                 if e.tg then
--~                     local m = (type(match) == "function" and match(e,root)) or match
--~                     if m == 1 then -- match
--~                         if index < #pattern then
--~                             if not traverse(e,pattern,handle,reverse,index+1) then return false end
--~                         else
--~                             if handle(root,rootdt,root.ri or k) then
--~                                 return false
--~                             end
--~                             -- tricky, where do we pick up, is this ok now
--~                             if pattern[1] == 2 then -- start again with new root (we need a way to inhibit this)
--~                                 if not traverse(e,pattern,handle,reverse,1) then return false end
--~                             end
--~                         end
--~                     elseif m == 2 then -- wildcard
--~                         if index < #pattern then
--~                             -- <parent><a><b></b><c></c></a></parent> : "a" (true) "/a" (true) "b" (true) "/b" (false)
--~                             -- not good yet, we need to pick up any prev level which is 2
--~                             local p = pattern[2]
--~                             if index == 1 and p then
--~                                 local mm = (type(p) == "function" and p(e,root)) or p -- pattern[2](e,root)
--~                                 if mm == 1 then
--~                                     if #pattern == 2 then
--~                                         if handle(root,rootdt,k) then
--~                                             return false
--~                                         end
--~                                         -- hack
--~                                         if pattern[1] == 2 then -- start again with new root (we need a way to inhibit this)
--~                                             if not traverse(e,pattern,handle,reverse,1) then return false end
--~                                         end
--~                                     else
--~                                         if not traverse(e,pattern,handle,reverse,3) then return false end
--~                                     end
--~                                 else
--~                                     if not traverse(e,pattern,handle,reverse,index+1,true) then return false end
--~                                 end
--~                             else
--~                                 if not traverse(e,pattern,handle,reverse,index+1,true) then return false end
--~                             end
--~                         elseif handle(root,rootdt,k) then
--~                             return false
--~                         end
--~                     elseif m == 3 then -- ancestor
--~                         local ep = e.__p__
--~                         if index < #pattern then
--~                             if not traverse(ep,pattern,handle,reverse,index+1) then return false end
--~                         elseif handle(root,rootdt,k) then
--~                             return false
--~                         end
--~                     elseif m == 4 then -- just root
--~                         if handle(root,rootdt,k) then
--~                             return false
--~                         end
--~                     elseif m == 6 then -- pi
--~                         if handle(root,rootdt,k) then
--~                             return false
--~                         end
--~                     elseif wildcard then -- maybe two kind of wildcards: * ** //
--~                         if not traverse(e,pattern,handle,reverse,index,wildcard) then return false end
--~                     end
--~                 end
--~             end
--~         end
--~         return true
--~     end

--~ Y a/b
--~ Y /a/b
--~ Y a/*/b
--~ Y a//b
--~ Y child::
--~ Y .//
--~ Y ..
--~ N id("tag")
--~ Y parent::
--~ Y child::
--~ N preceding-sibling:: (same name)
--~ N following-sibling:: (same name)
--~ N preceding-sibling-of-self:: (same name)
--~ N following-sibling-or-self:: (same name)
--~ Y ancestor::
--~ N descendent::
--~ N preceding::
--~ N following::
--~ N self::node()
--~ N node() == alles
--~ N a[position()=5]
--~ Y a[5]
--~ Y a[-5]
--~ N a[first()]
--~ N a[last()]
--~ Y a/(b|c|d)/e/f
--~ N (c/d|e)
--~ Y a/b[@bla]
--~ Y a/b[@bla='oeps']
--~ Y a/b[@bla=='oeps']
--~ Y a/b[@bla<>'oeps']
--~ Y a/b[@bla!='oeps']
--~ Y a/b/@bla

--~ Y ^/a/c (root)
--~ Y ^^/a/c (docroot)
--~ Y root::a/c (docroot)

--~ no wild card functions (yet)

--~ s = "/a//b/*/(c|d|e)/(f|g)/h[4]/h/child::i/j/(a/b)/p[-1]/q[4]/ancestor::q/r/../s/./t[@bla='true']/k"

-- // == /**/
-- / = ^ (root)

do

    function analyze(str)
        if not str then
            return ""
        else
            local tmp, result, map, key = { }, { }, { }, str
            str = str:gsub("(%b[])", function(s) tmp[#tmp+1] = s return '[['..#tmp..']]' end)
            str = str:gsub("(%b())", function(s) tmp[#tmp+1] = s return '[['..#tmp..']]' end)
            str = str:gsub("(%^+)([^/])", "%1/%2")
            str = str:gsub("//+", "/**/")
            str = str:gsub(".*root::", "^/")
            str = str:gsub("child::", "")
            str = str:gsub("ancestor::", "../")
            str = str:gsub("self::", "./")
            str = str:gsub("^/", "^/")
            for s in str:gmatch("([^/]+)") do
                s = s:gsub("%[%[(%d+)%]%]",function(n) return tmp[tonumber(n)] end)
                result[#result+1] = s
            end
            cache[key] = result
            return result
        end
    end

    actions = {
        [10] = "stay",
        [11] = "parent",
        [12] = "subtree root",
        [13] = "document root",
        [14] = "any",
        [15] = "many",
        [16] = "initial",
        [20] = "match",
        [21] = "match one of",
        [22] = "match and attribute eq",
        [23] = "match and attribute ne",
        [23] = "match and attribute present",
        [30] = "select",
        [40] = "processing instruction",
    }

    function compose(result)
        if not result or #result == 0 then
            -- wildcard
            return true
        elseif #result == 1 then
            local r = result[1][1]
            if r == "14" or r == "15" then
                -- wildcard
                return true
            elseif r == "12" then
                -- root
                return false
            end
        end
        local map = { }
        for r=1,#result do
            local ri = result[r]
            if ri == "." then
                --  skip
            elseif ri == ".." then
                map[#map+1] = { 11 }
            elseif ri == "^" then
                map[#map+1] = { 12 }
            elseif ri == "^^" then
                map[#map+1] = { 13 }
            elseif ri == "*" then
                map[#map+1] = { 14 }
            elseif ri == "**" then
                map[#map+1] = { 15 }
            else
                local m = ri:match("^%((.*)%)$") -- (a|b|c)
                if m or ri:find('|') then
                    m = m or ri
                    if m:find("[%[%]%(%)%/]") then -- []()/
                        -- error
                    else
                        local t = { 21 }
                        for s in m:gmatch("([^|]+)") do
                            local ns, tg = s:match("^(.-):?([^:]+)$")
                            t[#t+1] = ns
                            t[#t+1] = tg
                        end
                        map[#map+1] = t
                    end
                else
                    local s, f = ri:match("^(.-)%[%s*(.+)%s*%]$") --aaa[bbb]
                    if s and f then
                        local ns, tg = s:match("^(.-):?([^:]+)$")
                        local at, op, vl = f:match("^@(.-)([!=<>]?)([^!=<>]+)$") -- [@a=='b']
                        if op and op ~= "" then
                            if op == '=' or op == '==' then
                                map[#map+1] = { 22, ns, tg, at, (vl:gsub("^([\'\"])(.*)%1$", "%2")) }
                            elseif op == '<>' or op == '!=' then
                                map[#map+1] = { 23, ns, tg, at, (vl:gsub("^([\'\"])(.*)%1$", "%2")) }
                            else
                                -- error
                            end
                        elseif f:find("^([%-%+%d]+)$")then
                            map[#map+1] = { 30, ns, tg, tonumber(f) }
                        elseif vl ~= "" then
                            map[#map+1] = { 24, ns, tg, vl }
                        end
                    else
                        local pi = ri:match("^pi::(.-)$")
                        if pi then
                            map[#map+1] = { 40, pi }
                        else
                            map[#map+1] = { 20, ri:match("^(.-):?([^:]+)$") }
                        end
                    end
                end
            end
        end
        -- if we have a symbol, we can prepend that to the string, which is faster
        local mm = map[1] or { }
        local r = mm[1] or 0
        if #map == 1 then
            if r == 14 or r == 15 then
                -- wildcard
                return true
            elseif r == 12 then
                -- root
                return false
            end
        end
        if r ~= 11 and r ~= 12 and r ~= 13 and r ~= 14 and r ~= 15 then
            table.insert(map, 1, { 16 })
        end
        return map
    end

    cache = { }

    function xml.lpath(pattern)
        if type(pattern) == "string" then
            local result = cache[pattern]
            if not result then
                result = compose(analyze(pattern))
                cache[pattern] = result
            end
            if xml.trace_lpath then
                xml.lshow(result)
            end
            return result
        else
            return pattern
        end
    end

    function xml.lshow(pattern)
        local lp = xml.lpath(pattern)
        if lp == false then
            print("root")
        elseif lp == true then
            print("wildcard")
        else
            if type(pattern) ~= "table" then
                print("pattern: " .. tostring(pattern))
            end
            for k,v in ipairs(lp) do
                print(k,actions[v[1]],table.join(v," ",2))
            end
        end
    end

    function xml.traverse(root,pattern,handle,reverse,index,wildcard)
        if not root then -- error
            return false
        elseif pattern == false then -- root
            handle(root,root.dt,root.ri)
            return false
        elseif pattern == true then -- wildcard
            local traverse = xml.traverse
            local rootdt = root.dt
            if rootdt then
                local start, stop, step = 1, #rootdt, 1
                if reverse then
                    start, stop, step = stop, start, -1
                end
                for k=start,stop,step do
                    if handle(root,rootdt,root.ri or k)            then return false end
                    if not traverse(rootdt[k],true,handle,reverse) then return false end
                end
            end
            return false
        elseif root and root.dt then
            index = index or 1
            local action = pattern[index]
            local command = action[1]
            if (command == 16 or command == 12) and index == 1 then -- initial
                wildcard = true
                index = index + 1
                action = pattern[index]
                command = action[1]
            end
            local traverse = xml.traverse
            local rootdt = root.dt
            local start, stop, step, n, dn = 1, #rootdt, 1, 0, 1
            if command == 30 then
                if action[4] < 0 then
                    start, stop, step = stop, start, -1
                    dn = -1
                end
            elseif reverse and index == #pattern then
                start, stop, step = stop, start, -1
            end
            for k=start,stop,step do
                local e = rootdt[k]
                local ns, tg = e.ns, e.tg
                if tg then
                    if command == 30 then
                        if ns == action[2] and tg == action[3] then
                            n = n + dn
                            if n == action[4] then
                                if index == #pattern then
                                    if handle(root,rootdt,root.ri or k) then return false end
                                else
                                    if not traverse(e,pattern,handle,reverse,index+1) then return false end
                                end
                                break
                            end
                        elseif wildcard then
                            if not traverse(e,pattern,handle,reverse,index,true) then return false end
                        end
                    else
                        local matched = false
                        if command == 20 then -- match
                            matched = ns == action[2] and tg == action[3]
                        elseif command == 21 then -- match one of
                            for i=2,#action,2 do
                                if ns == action[i] and tg == action[i+1] then
                                    matched = true
                                    break
                                end
                            end
                        elseif command == 22 then -- eq
                            matched = ns == action[2] and tg == action[3] and e.at[action[4]] == action[5]
                        elseif command == 23 then -- ne
                            matched = ns == action[2] and tg == action[3] and e.at[action[4]] ~= action[5]
                        elseif command == 24 then -- present
                            matched = ns == action[2] and tg == action[3] and e.at[action[4]]
                        end
                        if matched then -- combine tg test and at test
                            if index == #pattern then
                                if handle(root,rootdt,root.ri or k) then return false end
                            else
                                if not traverse(e,pattern,handle,reverse,index+1) then return false end
                            end
                        elseif command == 14 then -- any
                            if index == #pattern then
                                if handle(root,rootdt,root.ri or k) then return false end
                            else
                                if not traverse(e,pattern,handle,reverse,index+1) then return false end
                            end
                        elseif command == 15 then -- many
                            if index == #pattern then
                                if handle(root,rootdt,root.ri or k) then return false end
                            else
                                if not traverse(e,pattern,handle,reverse,index+1,true) then return false end
                            end
                        elseif command == 11 then -- parent
                            local ep = e.__p__
                            if index < #pattern then
                                if not traverse(ep,pattern,handle,reverse,index+1) then return false end
                            elseif handle(root,rootdt,k) then
                                return false
                            end
                            break
                        elseif command == 40 and tg == "@pi@" then -- pi
                            local pi = action[2]
                            if pi ~= "" then
                                local pt = e.dt[1]
                                if pt and pt:find(pi) then
                                    if handle(root,rootdt,k) then
                                        return false
                                    end
                                end
                            elseif handle(root,rootdt,k) then
                                return false
                            end
                        elseif wildcard then
                            if not traverse(e,pattern,handle,reverse,index,true) then return false end
                        end
                    end
                end
            end
        end
        return true
    end

    local traverse, lpath, convert = xml.traverse, xml.lpath, xml.convert

    xml.filters = { }

    function xml.filters.default(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.reverse(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.count(root, pattern,everything)
        local n = 0
        traverse(root, lpath(pattern), function(r,d,t)
            if everything or type(d[t]) == "table" then
                n = n + 1
            end
        end)
        return n
    end
    function xml.filters.elements(root, pattern) -- == all
        local t = { }
        traverse(root, lpath(pattern), function(r,d,k)
            local e = d[k]
            if e then
                t[#t+1] = e
            end
        end)
        return t
    end
    function xml.filters.texts(root, pattern)
        local t = { }
        traverse(root, lpath(pattern), function(r,d,k)
            local e = d[k]
            if e and e.dt then
                t[#t+1] = e.dt
            end
        end)
        return t
    end
    function xml.filters.first(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.last(root,pattern)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
        return dt and dt[dk], rt, dt, dk
    end
    function xml.filters.index(root,pattern,arguments)
        local rt, dt, dk, reverse, i = nil, nil, nil, false, tonumber(arguments or '1') or 1
        if i and i ~= 0 then
            if i < 0 then
                reverse, i = true, -i
            end
            traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk, i = r, d, k, i-1 return i == 0 end, reverse)
            if i == 0 then
                return dt and dt[dk], rt, dt, dk
            else
                return nil, nil, nil, nil
            end
        else
            return nil, nil, nil, nil
        end
    end
    function xml.filters.attributes(root,pattern,arguments)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
        local ekat = dt and dt[dk] and dt[dk].at
        if ekat then
            if arguments then
                return ekat[arguments] or "", rt, dt, dk
            else
                return ekat, rt, dt, dk
            end
        else
            return { }, rt, dt, dk
        end
    end
    function xml.filters.attribute(root,pattern,arguments)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
        local ekat = dt and dt[dk] and dt[dk].at
        return (ekat and ekat[arguments]) or ""
    end
    function xml.filters.text(root,pattern,arguments)
        local ek, dt, dk, rt = xml.filters.index(root,pattern,arguments)
        return (ek and ek.dt) or "", rt, dt, dk
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
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end, reverse)
        local ek = dt and dt[dk]
        return (ek and ek.dt) or "", rt, dt, dk
    end

    function xml.each_element(root, pattern, handle, reverse)
        local ok
        traverse(root, lpath(pattern), function(r,d,k) ok = true handle(r,d,k) end, reverse)
        return ok
    end

    function xml.get_element(root,pattern,reverse)
        local rt, dt, dk
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end, reverse)
        return dt and dt[dk], rt, dt, dk
    end

    -- these may change

    function xml.all_elements(root, pattern, ignorespaces) -- ok?
        local rr, dd = { }, { }
        traverse(root, lpath(pattern), function(r,d,k)
            local dk = d and d[k]
            if dk then
                if ignorespaces and type(dk) == "string" and dk:find("^[\s\n]*$") then
                    -- ignore
                else
                    local n = #rr+1
                    rr[n], dd[n] = r, dk
                end
            end
        end)
        return dd, rr
    end

    function xml.all_texts(root, pattern, flatten) -- crap
        local t = { } -- no r collector
        traverse(root, lpath(pattern), function(r,d,k)
            if d then
                local ek = d[k]
                local tx = ek and ek.dt
                if flatten then
                    if tx then
                        t[#t+1] = xml.tostring(tx) or ""
                    else
                        t[#t+1] = ""
                    end
                else
                    t[#t+1] = tx or ""
                end
            else
                t[#t+1] = ""
            end
        end)
        return t
    end

    function xml.inject_element(root, pattern, element, prepend)
        if root and element then
            local matches, collect = { }, nil
            if type(element) == "string" then
                element = convert(element,true)
            end
            if element then
                collect = function(r,d,k) matches[#matches+1] = { r, d, k, element } end
                traverse(root, lpath(pattern), collect)
                for i=1,#matches do
                    local m = matches[i]
                    local r, d, k, element, edt = m[1], m[2], m[3], m[4], nil
                    if element.ri then
                        element = element.dt[element.ri].dt
                    else
                        element = element.dt
                    end
                    if r.ri then
                        edt = r.dt[r.ri].dt
                    else
                        edt = d and d[k] and d[k].dt
                    end
                    if edt then
                        local be, af
                        if prepend then
                            be, af = xml.copy(element), edt
                        else
                            be, af = edt, xml.copy(element)
                        end
                        for i=1,#af do
                            be[#be+1] = af[i]
                        end
                        if r.ri then
                            r.dt[r.ri].dt = be
                        else
                            d[k].dt = be
                        end
                    else
                     -- r.dt = element.dt -- todo
                    end
                end
            end
        end
    end

    -- todo: copy !

    function xml.insert_element(root, pattern, element, before) -- todo: element als functie
        if root and element then
            if pattern == "/" then
                xml.inject_element(root, pattern, element, before) -- todo: element als functie
            else
                local matches, collect = { }, nil
                if type(element) == "string" then
                    element = convert(element,true)
                end
                if element and element.ri then
                    element = element.dt[element.ri]
                end
                if element then
                    collect = function(r,d,k) matches[#matches+1] = { r, d, k, element } end
                    traverse(root, lpath(pattern), collect)
                    for i=#matches,1,-1 do
                        local m = matches[i]
                        local r, d, k, element = m[1], m[2], m[3], m[4]
                        if not before then k = k + 1 end
                        if element.tg then
                            table.insert(d,k,element) -- untested
                        elseif element.dt then
                            for _,v in ipairs(element.dt) do -- i added
                                table.insert(d,k,v)
                                k = k + 1
                            end
                        end
                    end
                end
            end
        end
    end

    -- first, last, each

    xml.insert_element_after  =                 xml.insert_element
    xml.insert_element_before = function(r,p,e) xml.insert_element(r,p,e,true) end
    xml.inject_element_after  =                 xml.inject_element
    xml.inject_element_before = function(r,p,e) xml.inject_element(r,p,e,true) end

    function xml.delete_element(root, pattern)
        local matches, deleted = { }, { }
        local collect = function(r,d,k) matches[#matches+1] = { r, d, k } end
        traverse(root, lpath(pattern), collect)
        for i=#matches,1,-1 do
            local m = matches[i]
            deleted[#deleted+1] = table.remove(m[2],m[3])
        end
        return deleted
    end

    function xml.replace_element(root, pattern, element)
        if type(element) == "string" then
            element = convert(element,true)
        end
        if element and element.ri then
            element = element.dt[element.ri]
        end
        if element then
            traverse(root, lpath(pattern), function(rm, d, k)
                d[k] = element.dt -- maybe not clever enough
            end)
        end
    end

    function xml.process(root, pattern, handle)
        traverse(root, lpath(pattern), function(r,d,k)
            if d[k].dt then
                for k,v in ipairs(d[k].dt) do
                    if v.tg then handle(v) end
                end
            end
        end)
    end

    function xml.strip(root, pattern)
        traverse(root, lpath(pattern), function(r,d,k)
            local dkdt = d[k].dt
            if dkdt then
                local t = { }
                for i=1,#dkdt do
                    local str = dkdt[i]
                    if type(str) == "string" and str:find("^[\032\010\012\013]*$") then
                        -- stripped
                    else
                        t[#t+1] = str
                    end
                end
                d[k].dt = t
            end
        end)
    end

    --

    function xml.rename_space(root, oldspace, newspace) -- fast variant
        local ndt = #root.dt
        local rename = xml.rename_space
        for i=1,ndt or 0 do
            local e = root[i]
            if type(e) == "table" then
                if e.ns == oldspace then
                    e.ns = newspace
                end
                local edt = e.dt
                if edt then
                    rename(edt, oldspace, newspace)
                end
            end
        end
    end

    function xml.remap_tag(root, pattern, newtg)
        traverse(root, lpath(pattern), function(r,d,k)
            d[k].tg = newtg
        end)
    end
    function xml.remap_namespace(root, pattern, newns)
        traverse(root, lpath(pattern), function(r,d,k)
            d[k].ns = newns
        end)
    end

 --  function xml.process_attributes(root, pattern, handle)
 --      traverse(root, lpath(pattern), function(e,k) handle(e[k].at) end)
 --  end

    function xml.process_attributes(root, pattern, handle)
        traverse(root, lpath(pattern), function(r,d,k)
            local ek = d[k]
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

--~     function xml.strip_leading_spaces(ek, e, k) -- cosmetic, for manual
--~         if e and k and e[k-1] and type(e[k-1]) == "string" then
--~             local s = e[k-1]:match("\n(%s+)")
--~             xml.gsub(ek,"\n"..string.rep(" ",#s),"\n")
--~         end
--~     end

--~     function xml.serialize_path(root,lpath,handle)
--~         local ek, e, k = xml.first_element(root,lpath)
--~         ek = xml.copy(ek)
--~         xml.strip_leading_spaces(ek,e,k)
--~         xml.serialize(ek,handle)
--~     end

    function xml.strip_leading_spaces(dk,d,k) -- cosmetic, for manual
        if d and k and d[k-1] and type(d[k-1]) == "string" then
            local s = d[k-1]:match("\n(%s+)")
            xml.gsub(dk,"\n"..string.rep(" ",#s),"\n")
        end
    end

    function xml.serialize_path(root,lpath,handle)
        local dk, r, d, k = xml.first(root,lpath)
        dK = xml.copy(dK)
        xml.strip_leading_spaces(dk,d,k)
        xml.serialize(dk,handle)
    end

    -- http://www.lua.org/pil/9.3.html (or of course the book)
    --
    -- it's nice to have an iterator but it comes with some extra overhead
    --
    -- for r, d, k in xml.elements(xml.load('text.xml'),"title") do print(d[k]) end

    function xml.elements(root,pattern,reverse)
        return coroutine.wrap(function() traverse(root, lpath(pattern), coroutine.yield, reverse) end)
    end

    -- the iterator variant needs 1.5 times the runtime of the function variant
    --
    -- function xml.filters.first(root,pattern)
    --     for rt,dt,dk in xml.elements(root,pattern)
    --         return dt and dt[dk], rt, dt, dk
    --     end
    --     return nil, nil, nil, nil
    -- end

    -- todo xml.gmatch for text

end

xml.count    = xml.filters.count
xml.index    = xml.filters.index
xml.position = xml.filters.index
xml.first    = xml.filters.first
xml.last     = xml.filters.last

xml.each     = xml.each_element
xml.all      = xml.all_elements

xml.insert   = xml.insert_element_after
xml.inject   = xml.inject_element_after
xml.after    = xml.insert_element_after
xml.before   = xml.insert_element_before
xml.delete   = xml.delete_element
xml.replace  = xml.replace_element

-- a few helpers, the may move to lxml modules

function xml.include(xmldata,element,attribute,pathlist,collapse)
    element   = element   or 'ctx:include'
    attribute = attribute or 'name'
    pathlist  = pathlist or { '.' }
    -- todo, check op ri
    local function include(r,d,k)
        local ek = d[k]
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
                    xml.assign(d,k,xml.load(f,collapse))
                    f:close()
                    break
                else
                    xml.empty(d,k)
                end
            end
        else
            xml.empty(d,k)
        end
    end
    while xml.each(xmldata, element, include) do end
end

xml.escapes   = { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;' }
xml.unescapes = { } for k,v in pairs(xml.escapes) do xml.unescapes[v] = k end

function xml.escaped  (str) return str:gsub("(.)"   , xml.escapes  ) end
function xml.unescaped(str) return str:gsub("(&.-;)", xml.unescapes) end
function xml.cleansed (str) return str:gsub("<.->"  , ''           ) end -- "%b<>"

function xml.join(t,separator,lastseparator)
    if #t > 0 then
        local result = { }
        for k,v in pairs(t) do
            result[k] = xml.tostring(v)
        end
        if lastseparator then
            return table.join(result,separator or "",1,#result-1) .. (lastseparator or "") .. result[#result]
        else
            return table.join(result,separator)
        end
    else
        return ""
    end
end


do if utf then

    local function toutf(s)
        return utf.char(tonumber(s,16))
    end

    function xml.utfize(root)
        local d = root.dt
        for k=1,#d do
            local dk = d[k]
            if type(dk) == "string" then
                d[k] = dk:gsub("&#x(.-);",toutf)
            else
                xml.utfize(dk)
            end
        end
    end

else
    function xml.utfize()
        print("entity to utf conversion is not available")
    end

end end

--- examples

--~ for _, e in ipairs(xml.filters.elements(ctxrunner.xmldata,"ctx:message")) do
--~     print(">>>",xml.tostring(e.dt))
--~ end
