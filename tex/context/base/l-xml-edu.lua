if not modules then modules = { } end modules ['l-xml-edu'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module contains older code thatwe keep around for educational
purposes. Here you find the find based xml and lpath parsers.</p>
--ldx]]--

if false then

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
            if data:find("<!%[CDATA%[") then
                data = data:gsub("<!%[CDATA%[(.-)%]%]>", function(txt)
                    text[#text+1] = txt or ""
                    return string.format("<@cd@>%s</@cd@>",#text)
                end)
            end
            -- DOCTYPE
            if data:find("<!DOCTYPE ") then
                data = data:gsub("^(.-)(<[^!?])", function(a,b)
                    if a:find("<!DOCTYPE ") then -- ?
                        for _,v in ipairs(doctype_patterns) do
                            a = a:gsub(v, function(d)
                                text[#text+1] = d or ""
                                return string.format("<@dt@>%s</@dt@>",#text)
                            end)
                        end
                    end
                    return a .. b
                end,1)
            end
            -- comment / does not catch doctype
            if data:find("<!%-%-") then
                data = data:gsub("<!%-%-(.-)%-%->", function(txt)
                    text[#text+1] = txt or ""
                    return string.format("<@cm@>%s</@cm@>",#text)
                end)
            end
            -- processing instructions / altijd 1
            if data:find("<%?") then
                data = data:gsub("<%?(.-)%?>", function(txt)
                    text[#text+1] = txt or ""
                    return string.format("<@pi@>%s</@pi@>",#text)
                end)
            end
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
            local mt = { __tostring = xml.text }
            local xmlns = { }
            while true do
                local ni, first, attributes, last, fulltag, resolved
                ni, j, first, fulltag, attributes, last = data:find("<(/-)([^%s>/]+)%s*([^>]-)%s*(/-)>", j)
                if not ni then break end
                local namespace, tag = fulltag:match("^(.-):(.+)$")
                if attributes ~= "" then
                    local t = {}
                    for ns, tag, _, value in attributes:gmatch("(.-):?(.+)=([\"\'])(.-)%3") do -- . was %w
                        if tag == "xmlns" then -- not ok yet
                            xmlns[#xmlns+1] = xml.resolvens(value)
                            t[tag] = value
                        elseif ns == "xmlns" then
                            xml.checkns(tag,value)
                            t["xmlns:" .. tag] = value
                        else
                            t[tag] = value
                        end
                    end
                    attributes = t
                else
                    attributes = { }
                end
                if namespace then -- realtime remapping
                    resolved = nsremap[namespace] or namespace
                else
                    namespace, tag = "", fulltag
                    resolved = xmlns[#xmlns]
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
                    if attributes.xmlns then
                        remove(xmlns) -- ?
                    end
                elseif last == "/" then
                    -- empty element tag
                    dt[#dt+1] = { ns = namespace, rn = resolved, tg = tag, dt = { }, at = attributes, __p__ = top }
                    setmetatable(top, mt)
                else
                    -- begin tag
                    top = { ns = namespace, rn = resolved, tg = tag, dt = { }, at = attributes, __p__ = stack[#stack] }
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
                setmetatable(stack, mt)
            end
            if no_root then
                return stack[1]
            else
                local t = { ns = "", tg = '@rt@', dt = stack[1].dt }
                setmetatable(t, mt)
                for k,v in ipairs(t.dt) do
                    if type(v) == "table" and v.tg ~= "@pi@" and v.tg ~= "@dt@" and v.tg ~= "@cm@" then
                        t.ri = k -- rootindex
                        break
                    end
                end
                return t
            end
        end

    end

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
    --~ N ancestor::
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
    --~ Y a/!(b|c|d)/e/f
    --~ N (c/d|e)
    --~ Y a/b[@bla]
    --~ Y a/b[@bla='oeps']
    --~ Y a/b[@bla=='oeps']
    --~ Y a/b[@bla<>'oeps']
    --~ Y a/b[@bla!='oeps']
    --~ Y a/b/@bla
    --~ Y a['string']
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
                str = str:gsub("parent::", "../")
                str = str:gsub("self::", "./")
                str = str:gsub("^/", "^/")
                for s in str:gmatch("([^/]+)") do
                    s = s:gsub("%[%[(%d+)%]%]",function(n) return tmp[tonumber(n)] end)
                    result[#result+1] = s
                end
                return result
            end
        end

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
                    local negate, m = ri:match("^(!*)%((.*)%)$") -- (a|b|c)
                    if m or ri:find('|') then
                        m = m or ri
                        if m:find("[%[%]%(%)/]") then -- []()/
                            -- error
                        else
                            local t = { (negate and #negate>0 and 25) or 21 }
                            for s in m:gmatch("([^|]+)") do
                                local ns, tg = s:match("^(.-):?([^:]+)$")
                                if ns == "*" then ns = true end
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
                            if ns == "*" then ns = true end
                            if vl then
                                if op and op ~= "" then
                                    if op == '=' or op == '==' then
                                        map[#map+1] = { 22, ns, tg, at, (vl:gsub("^([\'\"])(.*)%1$","%2")) }
                                    elseif op == '<>' or op == '!=' then
                                        map[#map+1] = { 23, ns, tg, at, (vl:gsub("^([\'\"])(.*)%1$","%2")) }
                                    else
                                        -- error
                                    end
                                elseif vl ~= "" then -- [@whatever]
                                    map[#map+1] = { 26, ns, tg, vl }
                                else
                                    -- error
                                end
                        --  elseif f:find("^([%-%+%d]+)$") then -- [123]
                            elseif f:find("^([-+%d]+)$") then -- [123]
                                map[#map+1] = { 30, ns, tg, tonumber(f) }
                            else -- [whatever]
                                map[#map+1] = { 27, ns, tg, (f:gsub("^([\'\"])(.*)%1$","%2")) }
                            end
                        else
                            local pi = ri:match("^pi::(.-)$")
                            if pi then
                                map[#map+1] = { 40, pi }
                            else
                                local negate, ns, tg = ri:match("^(!-)(.-):?([^:]+)$")
                                map[#map+1] = { (negate and #negate>0 and 24) or 20, ns, tg }
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

    end

end
