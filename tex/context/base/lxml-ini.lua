if not modules then modules = { } end modules ['lxml-ini'] = {
    version   = 1.001,
    comment   = "companion to lxml-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texsprint, texprint = tex.sprint or print, tex.print or print
local format, concat, insert, remove = string.format, table.concat, table.insert, table.remove
local type, next, tonumber = type, next, tonumber

-- for the moment here

function table.insert_before_value(t,value,extra)
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

function table.insert_after_value(t,value,extra)
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

-- todo: speed up: remember last index/match combination

local traverse, lpath = xml.traverse, xml.lpath

local xmlfilter, xmlfirst, xmllast, xmlall = xml.filter, xml.first, xml.last, xml.all
local xmlcollect, xmlcontent, xmlcollect_texts, xmlcollect_tags, xmlcollect_elements = xml.collect, xml.content, xml.collect_texts, xml.collect_tags, xml.collect_elements
local xmlattribute, xmlindex = xml.filters.attribute, xml.filters.index
local xmlelements = xml.elements

document     = document or { }
document.xml = document.xml or { }

-- todo: loaded and myself per document so that we can garbage collect buffers

lxml         = lxml or { }
lxml.loaded  = { }
lxml.myself  = { }

local loaded   = lxml.loaded
local myself   = lxml.myself
local stack    = lxml.stack

lxml.self = myself -- be backward compatible for a while

local function get_id(id)
    return (type(id) == "table" and id) or loaded[id] or myself[tonumber(id)] -- no need for tonumber if we pass without ""
end

lxml.id = get_id

function lxml.root(id)
    return loaded[id]
end

do

    xml.specialhandler   = xml.specialhandler or { }

    local specialhandler = xml.specialhandler
    local serialize      = xml.serialize

    local crlf    = lpeg.P("\r\n")
    local cr      = lpeg.P("\r")
    local lf      = lpeg.P("\n")
    local space   = lpeg.S(" \t\f\v")
    local newline = crlf + cr + lf
    local spacing = space^0 * newline  * space^0
    local content = lpeg.C((1-spacing)^1)
    local verbose = lpeg.C((1-(space+newline))^1)

    local capture  = (
        newline^2  * lpeg.Cc("")  / texprint +
        newline    * lpeg.Cc(" ") / texsprint +
        content                   / texsprint
    )^0

--~     local capture  = (
--~         newline^2  * lpeg.Cc("")  / function(s) texprint (tex.xmlcatcodes,s) end +
--~         newline    * lpeg.Cc(" ") / function(s) texsprint(tex.xmlcatcodes,s) end +
--~         content                   / function(s) texsprint(tex.xmlcatcodes,s) end
--~     )^0

    local forceraw, rawroot = false, nil

    function lxml.startraw()
        forceraw = true
    end
    function lxml.stopraw()
        forceraw = false
    end
    function lxml.rawroot()
        return rawroot
    end
    function lxml.rawpath(rootid)
        if rawroot and type(rawroot) == "table" then
            local text, path, rp
            if not rawroot.dt then
                text, path, rp = "text", "", rawroot[0]
            else
                path, rp = "tree", "", rawroot.__p__
            end
            while rp do
                local rptg = rp.tg
                if rptg then
                    path = rptg .. "/" .. path
                end
                rp = rp.__p__
            end
            return { rootid, "/" .. path, text }
        end
    end

    local function sprint(root)
        if not root then
--~             rawroot = false
            -- quit
        else
            local tr = type(root)
            if tr == "string" then -- can also be result of lpath
--~                 rawroot = false
                capture:match(root)
            elseif tr == "table" then
                rawroot = forceraw and root
                serialize(root,sprint,nil,nil,specialhandler,forceraw)
            end
        end
    end

    xml.sprint = sprint

    function xml.tprint(root) -- we can move sprint inline
        local tr = type(root)
        if tr == "table" then
            local n = #root
            if n == 0 then
                sprint("") -- empty element, else no setup triggered (check this! )
            else
                for i=1,n do
                    sprint(root[i])
                end
            end
        elseif tr == "string" then
            sprint(root)
        end
    end

    function xml.cprint(root) -- content
        if not root then
--~             rawroot = false
            -- quit
        elseif type(root) == 'string' then
--~             rawroot = false
            capture:match(root)
        else
            local rootdt = root.dt
            rawroot = forceraw and root
            if rootdt then -- the main one
                serialize(rootdt,sprint,nil,nil,specialhandler,forceraw)
            else -- probably dt
                serialize(root,sprint,nil,nil,specialhandler,forceraw)
            end
        end
    end

    -- lines (untested)

    local buffer = { }

    local capture  = (
        newline^2 / function()  buffer[#buffer+1] = "" end +
        newline   / function()  buffer[#buffer] = buffer[#buffer] .. " " end +
        content   / function(s) buffer[#buffer] = buffer[#buffer] ..  s  end
    )^0

    function lines(root)
        if not root then
--~             rawroot = false
            -- quit
        elseif type(root) == 'string' then
--~             rawroot = false
            capture:match(root)
        elseif next(root) then -- tr == 'table'
            rawroot = forceraw and root
            serialize(root,lines,forceraw)
        end
    end

    function xml.lines(root)
        buffer = { "" }
        lines(root)
        return result
    end

    -- cdata

    local linecommand   = "\\obeyedline"
    local spacecommand  = "\\obeyedspace" -- "\\strut\\obeyedspace"
    local beforecommand = ""
    local aftercommand  = ""

    local capture  = (
        newline / function( ) texsprint(tex.texcatcodes,linecommand  .. "{}") end +
        verbose / function(s) texsprint(tex.vrbcatcodes,s) end +
        space   / function( ) texsprint(tex.texcatcodes,spacecommand .. "{}") end
    )^0

    local function toverbatim(str)
        if beforecommand then texsprint(tex.texcatcodes,beforecommand .. "{}") end
        capture:match(str)
        if aftercommand  then texsprint(tex.texcatcodes,aftercommand  .. "{}")  end
    end

    function lxml.set_verbatim(before,after,obeyedline,obeyedspace)
        beforecommand, aftercommand, linecommand, spacecommand = before, after, obeyedline, obeyedspace
    end

    function lxml.set_cdata()
        specialhandler['@cd@'] = toverbatim
    end

    function lxml.reset_cdata()
        specialhandler['@cd@'] = nil
    end

    -- local capture = (space^0*newline)^0 * capture * (space+newline)^0 * -1

    local function toverbatim(str)
        if beforecommand then texsprint(tex.texcatcodes,beforecommand .. "{}") end
        -- todo: add this to capture
        str = str:gsub("^[ \t]+[\n\r]+","")
        str = str:gsub("[ \t\n\r]+$","")
        capture:match(str)
        if aftercommand  then texsprint(tex.texcatcodes,aftercommand  .. "{}")  end
    end

    function lxml.verbatim(id,before,after)
        local root = get_id(id)
        if root then
            if before then texsprint(tex.ctxcatcodes,format("%s[%s]",before,root.tg)) end
        --  serialize(root.dt,toverbatim,nil,nil,nil,true)  -- was root
            local t = { }
            serialize(root.dt,function(s) t[#t+1] = s end,nil,nil,nil,true)  -- was root
            toverbatim(table.concat(t,""))
            if after then texsprint(tex.ctxcatcodes,after) end
        end
    end
    function lxml.inlineverbatim(id)
        lxml.verbatim(id,"\\startxmlinlineverbatim","\\stopxmlinlineverbatim")
    end
    function lxml.displayverbatim(id)
        lxml.verbatim(id,"\\startxmldisplayverbatim","\\stopxmldisplayverbatim")
    end

    local pihandlers = { }

    specialhandler['@pi@'] = function(str)
        for i=1,#pihandlers do
            pihandlers[i](str)
        end
    end

    xml.pihandlers = pihandlers

    local kind   = lpeg.P("context-") * lpeg.C((1-lpeg.P("-"))^1) * lpeg.P("-directive")
    local space  = lpeg.S(" \n\r")
    local spaces = space^0
    local class  = lpeg.C((1-space)^0)
    local key    = class
    local value  = lpeg.C(lpeg.P(1-(space * -1))^0)

    local parser = kind * spaces * class * spaces * key * spaces * value

    pihandlers[#pihandlers+1] = function(str)
    --  local kind, class, key, value = parser:match(str)
        if str then
            local a, b, c, d = parser:match(str)
            if d then
                texsprint(tex.ctxcatcodes,format("\\xmlcontextdirective{%s}{%s}{%s}{%s}",a,b,c,d))
            end
        end
    end

    -- print(contextdirective("context-mathml-directive function reduction yes yes "))
    -- print(contextdirective("context-mathml-directive function "))

    function lxml.main(id)
        serialize(get_id(id),sprint,nil,nil,specialhandler) -- the real root (@rt@)
    end

    specialhandler['@dt@'] = function()
        -- nothing
    end

end

local xmlsprint = xml.sprint
local xmltprint = xml.tprint

-- redefine xml load

xml.originalload = xml.originalload or xml.load

function xml.load(filename)
    input.starttiming(xml)
    local xmldata = xml.convert((filename and input.loadtexfile(filename)) or "")
    input.stoptiming(xml)
    return xmldata
end

function lxml.load(id,filename)
    filename = commands.preparedfile(filename)
    if lxml.trace_load then
        ctx.writestatus("lxml","loading file: %s",filename)
    end
    loaded[id] = xml.load(filename)
    return loaded[id], filename
end

function lxml.include(id,pattern,attribute,recurse)
    input.starttiming(xml)
    xml.include(get_id(id),pattern,attribute,recurse,function(filename)
        if filename then
            filename = commands.preparedfile(filename)
            if lxml.trace_load then
                ctx.writestatus("lxml","including file: %s",filename)
            end
            return input.loadtexfile(filename) or ""
        else
            return ""
        end
    end)
    input.stoptiming(xml)
end

function lxml.utfize(id)
    xml.utfize(get_id(id))
end

function lxml.filter(id,pattern)
    xmlsprint(xmlfilter(get_id(id),pattern))
end
function lxml.first(id,pattern)
    xmlsprint(xmlfirst(get_id(id),pattern))
end
function lxml.last(id,pattern)
    xmlsprint(xmllast(get_id(id),pattern))
end
function lxml.all(id,pattern)
 -- xmltprint(xmlcollect(get_id(id),pattern))
    traverse(get_id(id), lpath(pattern), function(r,d,k)
        -- to be checked for root::
        xmlsprint(d[k])
        return false
    end)
end

function lxml.nonspace(id,pattern) -- slow, todo loop
    xmltprint(xmlcollect(get_id(id),pattern,true))
end

--~ function lxml.content(id)
--~     xmlsprint(xmlcontent(get_id(id)) or "")
--~ end

function lxml.strip(id,pattern,nolines)
    xml.strip(get_id(id),pattern,nolines)
end

function lxml.text(id,pattern)
    xmltprint(xmlcollect_texts(get_id(id),pattern) or {})
end

function lxml.tags(id,pattern)
    local tags = xmlcollect_tags(get_id(id),pattern)
    if tags then
        texsprint(concat(tags,","))
    end
end

function lxml.raw(id,pattern) -- the content, untouched by commands
    local c = xmlfilter(get_id(id),pattern)
    if c then
        xml.serialize(c.dt,texsprint,nil,nil,nil,true)
    end
end

function lxml.snippet(id,i)
    local e = get_id(id)
    if e then
        local edt = e.dt
        if edt then
            xmlsprint(edt[i])
        end
    end
end

function xml.element(e,n)
    if e then
        local edt = e.dt
        if edt then
            if n > 0 then
                for i=1,#edt do
                    local ei = edt[i]
                    if type(ei) == "table" then
                        if n == 1 then
                            xmlsprint(ei)
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
                            xmlsprint(ei)
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

function lxml.element(id,n)
    xml.element(get_id(id),n)
end

function lxml.stripped(id,pattern,nolines)
    local str = xmlcontent(get_id(id),pattern) or ""
    str = str:gsub("^%s*(.-)%s*$","%1")
    if nolines then
        str = str:gsub("%s+"," ")
    end
    xmlsprint(str)
end

function lxml.flush(id)
    id = get_id(id)
    local dt = id and id.dt
    if dt then
        xmlsprint(dt)
    end
end

--~ function lxml.strip(id,flush)
--~     local dt = get_id(id).dt
--~     local str = dt[1]
--~     if type(str) == "string" then
--~         dt[1] = str:gsub("^ *","")
--~     end
--~     str = dt[#dt]
--~     if type(str) == "string" then
--~         dt[#dt] = str:gsub(" *$","")
--~     end
--~     if flush then
--~         xmlsprint(dt)
--~     end
--~ end

function lxml.direct(id)
    xmlsprint(get_id(id))
end

function lxml.index(id,pattern,i)
    xmlsprint((xmlindex(get_id(id),pattern,i)))
end

function lxml.attribute(id,pattern,a,default) --todo: snelle xmlatt
    local str = xmlattribute(get_id(id),pattern,a) or ""
    texsprint((str == "" and default) or str)
end

function lxml.count(id,pattern)
    texsprint(xml.count(get_id(id),pattern) or 0)
end
function lxml.nofelements(id)
    local e = get_id(id)
    local edt = e.dt
    if edt and type(edt) == "table" then
        local n = 0
        for i=1,#edt do
            if type(edt[i]) == "table" then
                n = n + 1
            end
        end
        texsprint(n)
    else
        texsprint(0)
    end
end
function lxml.name(id) -- or remapped name? -> lxml.info, combine
    local r = get_id(id)
    local ns = r.rn or r.ns or ""
    if ns ~= "" then
        texsprint(ns .. ":" .. r.tg)
    else
        texsprint(r.tg)
    end
end
function lxml.tag(id) -- tag vs name -> also in l-xml tag->name
    texsprint(get_id(id).tg or "")
end
function lxml.namespace(id) -- or remapped name?
    local root = get_id(id)
    texsprint(root.rn or root.ns or "")
end

--~ function lxml.concat(id,what,separator,lastseparator)
--~     texsprint(concat(xml.collect_texts(get_id(id),what,true),separator or ""))
--~ end

function lxml.concatrange(id,what,start,stop,separator,lastseparator) -- test this on mml
    local t = xmlcollect_elements(lxml.id(id),what,true) -- ignorespaces
    local separator = separator or ""
    local lastseparator = lastseparator or separator or ""
    start, stop = (start == "" and 1) or tonumber(start) or 1, (stop == "" and #t) or tonumber(stop) or #t
    if stop < 0 then stop = #t + stop end -- -1 == last-1
    for i=start,stop do
        xmlsprint(t[i])
        if i == #t then
            -- nothing
        elseif i == #t-1 and lastseparator ~= "" then
            texsprint(tex.ctxcatcodes,lastseparator)
        elseif separator ~= "" then
            texsprint(tex.ctxcatcodes,separator)
        end
    end
end

function lxml.concat(id,what,separator,lastseparator)
    lxml.concatrange(id,what,false,false,separator,lastseparator)
end

-- string   : setup
-- true     : text (no <self></self>)
-- false    : ignore
-- function : call

-- todo: free self after usage, i.e. after the setup, which
-- means a call to lua; we can also choose a proper maximum
-- and cycle or maybe free on demand

-- problems with empty elements
-- we use a real tex.sprint, else spaces go wrong
-- maybe just a .. because this happens often

function xml.command(root, command)
    local tc = type(command)
    if tc == "string" then
        -- setup
        local n = #myself + 1
        myself[n] = root
        texsprint(tex.ctxcatcodes,format("\\xmlsetup{%i}{%s}",n,command))
    elseif tc == "function" then
        -- function
        command(root)
    elseif command == true then
        -- text (no <self></self>) / so, no mkii fallback then
        xmltprint(root.dt)
    elseif command == false then
        -- ignore
    else
        -- fuzzy, so ignore too
    end
end

function lxml.setaction(id,pattern,action)
    for rt, dt, dk in xmlelements(get_id(id),pattern) do
        dt[dk].command = action
    end
end

lxml.trace_setups = false
lxml.trace_load   = false

function lxml.setsetup(id,pattern,setup)
    local trace = lxml.trace_setups
    if not setup or setup == "" or setup == "*" or setup == "-" or setup == "+" then
        for rt, dt, dk in xmlelements(get_id(id),pattern) do
            local dtdk = dt and dt[dk] or rt
            local ns, tg = dtdk.rn or dtdk.ns, dtdk.tg
            if tg then -- to be sure
                local command = (ns == "" and tg) or (ns .. ":" .. tg)
                if setup == "-" then
                    dtdk.command = false
                    if trace then
                        texio.write_nl(format("lpath matched -> %s -> skipped", command))
                    end
                elseif setup == "+" then
                    dtdk.command = true
                    if trace then
                        texio.write_nl(format("lpath matched -> %s -> text", command))
                    end
                else
                    dtdk.command = command
                    if trace then
                        texio.write_nl(format("lpath matched -> %s -> %s", command, command))
                    end
                end
            end
        end
    else
        local a, b = setup:match("^(.+:)([%*%-])$")
        if a and b then
            for rt, dt, dk in xmlelements(get_id(id),pattern) do
                local dtdk = (dt and dt[dk]) or rt
                local ns, tg = dtdk.rn or dtdk.ns, dtdk.tg
                if b == "-" then
                    dtdk.command = false
                    if trace then
                        if ns == "" then
                            texio.write_nl(format("lpath matched -> %s -> skipped", tg))
                        else
                            texio.write_nl(format("lpath matched -> %s:%s -> skipped", ns, tg))
                        end
                    end
                elseif b == "+" then
                    dtdk.command = true
                    if trace then
                        if ns == "" then
                            texio.write_nl(format("lpath matched -> %s -> text", tg))
                        else
                            texio.write_nl(format("lpath matched -> %s:%s -> text", ns, tg))
                        end
                    end
                else
                    dtdk.command = a .. tg
                    if trace then
                        if ns == "" then
                            texio.write_nl(format("lpath matched -> %s -> %s", tg, dtdk.command))
                        else
                            texio.write_nl(format("lpath matched -> %s:%s -> %s", ns, tg, dtdk.command))
                        end
                    end
                end
            end
        else
            if trace then
                texio.write_nl(format("lpath pattern -> %s -> %s", pattern, setup))
            end
            for rt, dt, dk in xmlelements(get_id(id),pattern) do
                local dtdk = (dt and dt[dk]) or rt
                dtdk.command = setup
                if trace then
                    local ns, tg = dtdk.rn or dtdk.ns, dtdk.tg
                    if ns == "" then
                        texio.write_nl(format("lpath matched -> %s -> %s", tg, setup))
                    else
                        texio.write_nl(format("lpath matched -> %s:%s -> %s", ns, tg, setup))
                    end
                end
            end
        end
    end
end

function lxml.idx(id,pattern,i) -- hm, hashed, needed?
    local r = get_id(id)
    if r then
        local rp = r.patterns
        if not rp then
            rp = { }
            r.patterns = rp
        end
        if not rp[pattern] then
            rp[pattern] = xmlcollect_elements(r,pattern) -- dd, rr
        end
        local rpi = rp[pattern] and rp[pattern][i]
        if rpi then
            xmlsprint(rpi)
        end
    end
end

function lxml.info(id)
    id = get_id(id)
    local ns, tg = id.ns, id.tg
    if ns and ns ~= "" then -- best make a function
        tg = ns .. ":" .. tg
    else
        tg = tg or "?"
    end
    texsprint(tg)
end


local function command(root,pattern,cmd) -- met zonder ''
    cmd = cmd:gsub("^([\'\"])(.-)%1$", "%2")
    traverse(root, lpath(pattern), function(r,d,k)
        -- this can become pretty large
        local m = (d and d[k]) or r -- brrr this r, maybe away
        if type(m) == "table" then -- probably a bug
            local n = #myself + 1
            myself[n] = m
            texsprint(tex.ctxcatcodes,format("\\xmlsetup{%s}{%s}",n,cmd))
        end
    end)
end

xml.filters.command = command

function lxml.command(id,pattern,cmd)
    command(get_id(id),pattern,cmd)
end

local function dofunction(root,pattern,fnc)
    traverse(root, lpath(pattern), xml.functions[fnc]) -- r, d, t
end

xml.filters["function"] = dofunction

do

    --~ <?xml version="1.0" standalone="yes"?>
    --~ <!-- demo.cdx -->
    --~ <directives>
    --~ <!--
    --~     <directive attribute='id' value="100" setup="cdx:100"/>
    --~     <directive attribute='id' value="101" setup="cdx:101"/>
    --~ -->
    --~ <!--
    --~     <directive attribute='cdx' value="colors"   element="cals:table" setup="cdx:cals:table:colors"/>
    --~     <directive attribute='cdx' value="vertical" element="cals:table" setup="cdx:cals:table:vertical"/>
    --~     <directive attribute='cdx' value="noframe"  element="cals:table" setup="cdx:cals:table:noframe"/>
    --~ -->
    --~ <directive attribute='cdx' value="*" element="cals:table" setup="cdx:cals:table:*"/>
    --~ </directives>

    lxml.directives = { }

    local data = {
        setup  = { },
        before = { },
        after  = { }
    }

    function lxml.directives.load(filename)
        if texmf then
            local fullname = input.find_file(filename) or ""
            if fullname ~= "" then
                filename = fullname
            end
        end
        local root = xml.load(filename)
        for r, d, k in xmlelements(root,"directive") do
            local dk = d[k]
            local at = dk.at
            local attribute, value, element = at.attribute or "", at.value or "", at.element or '*'
            local setup, before, after = at.setup or "", at.before or "", at.after or ""
            if attribute ~= "" and value ~= "" then
                local key = format("%s::%s::%s",element,attribute,value)
                local t = data[key] or { }
                if setup  ~= "" then t.setup  = setup  end
                if before ~= "" then t.before = before end
                if after  ~= "" then t.after  = after  end
                data[key] = t
            end
        end
    end

    function lxml.directives.setup(root,attribute,element)
        lxml.directives.handle_setup('setup',root,attribute,element)
    end
    function lxml.directives.before(root,attribute,element)
        lxml.directives.handle_setup('before',root,attribute,element)
    end
    function lxml.directives.after(root,attribute,element)
        lxml.directives.handle_setup('after',root,attribute,element)
    end

    function lxml.directives.handle_setup(category,root,attribute,element)
        root = get_id(root)
        attribute = attribute
        if attribute then
            local value = root.at[attribute]
            if value then
                if not element then
                    local ns, tg = root.rn or root.ns, root.tg
                    if ns == "" then
                        element = tg
                    else
                        element = ns .. ':' .. tg
                    end
                end
                local setup = data[format("%s::%s::%s",element,attribute,value)]
                if setup then
                    setup = setup[category]
                end
                if setup then
                    texsprint(tex.ctxcatcodes,format("\\directsetup{%s}",setup))
                else
                    setup = data[format("%s::%s::*",element,attribute)]
                    if setup then
                        setup = setup[category]
                    end
                    if setup then
                        texsprint(tex.ctxcatcodes,format("\\directsetup{%s}",setup:gsub('%*',value)))
                    end
                end
            end
        end
    end

end

function xml.getbuffer(name) -- we need to make sure that commands are processed
    if not name or name == "" then
        name = tex.jobname
    end
    xml.tostring(xml.convert(concat(buffers.data[name] or {},"")))
end

function lxml.loadbuffer(id,name)
    if not name or name == "" then
        name = tex.jobname
    end
    input.starttiming(xml)
    loaded[id] = xml.convert(buffers.collect(name or id,"\n"))
    input.stoptiming(xml)
    return loaded[id], name or id
end

function lxml.loaddata(id,str)
    input.starttiming(xml)
    loaded[id] = xml.convert(str or "")
    input.stoptiming(xml)
    return loaded[id], id
end

-- for the moment here:

lxml.set_verbatim("\\xmlcdatabefore", "\\xmlcdataafter", "\\xmlcdataobeyedline", "\\xmlcdataobeyedspace")
lxml.set_cdata()

do

    local traced = { }

    function lxml.trace_text_entities(str)
        return str:gsub("&(.-);",function(s)
            traced[s] = (traced[s] or 0) + 1
            return "["..s.."]"
        end)
    end

    function lxml.show_text_entities()
        for k,v in ipairs(table.sortedkeys(traced)) do
            local h = v:match("^#x(.-)$")
            if h then
                local d = tonumber(h,16)
                local u = unicode.utf8.char(d)
                texio.write_nl(format("entity: %s / %s / %s / n=%s",h,d,u,traced[v]))
            else
                texio.write_nl(format("entity: %s / n=%s",v,traced[v]))
            end
        end
    end

end

-- yes or no ...

do

     local function with_elements_only(e,handle)
        if e and handle then
            local etg = e.tg
            if etg then
                if e.special and etg ~= "@rt@" then
                    if resthandle then
                        resthandle(e)
                    end
                else
                    local edt = e.dt
                    if edt then
                        for i=1,#edt do
                            local e = edt[i]
                            if type(e) == "table" then
                                handle(e)
                                with_elements_only(e,handle)
                            end
                        end
                    end
                end
            end
        end
    end

     local function with_elements_only(e,handle,depth)
        if e and handle then
            local edt = e.dt
            if edt then
                depth = depth or 0
                for i=1,#edt do
                    local e = edt[i]
                    if type(e) == "table" then
                        handle(e,depth)
                        with_elements_only(e,handle,depth+1)
                    end
                end
            end
        end
    end

    xml.with_elements_only = with_elements_only

    local function to_text(e)
        if e.command == nil then
            local etg = e.tg
            if etg and e.special and etg ~= "@rt@" then
                e.command = false -- i.e. skip
            else
                e.command = true  -- i.e. no <self></self>
            end
        end
    end
    local function to_none(e)
        if e.command == nil then
            e.command = false -- i.e. skip
        end
    end

    -- can be made faster: just recurse over whole table, todo

    function lxml.set_command_to_text(id)
        xml.with_elements_only(get_id(id),to_text)
    end

    function lxml.set_command_to_none(id)
        xml.with_elements_only(get_id(id),to_none)
    end

    function lxml.get_command_status(id)
        local status, stack = {}, {}
        local function get(e,d)
            local ns, tg = e.ns, e.tg
            local name = tg
            if ns ~= "" then name = ns .. ":" .. tg end
            stack[d] = name
            local ec = e.command
            if ec == true then
                ec = "system: text"
            elseif ec == false then
                ec = "system: skip"
            elseif ec == nil then
                ec = "system: not set"
            elseif type(ec) == "string" then
                ec = "setup: " .. ec
            else -- function
                ec = tostring(ec)
            end
            local tag = table.concat(stack," => ",1,d)
            local s = status[tag]
            if not s then
                s = { }
                status[tag] = s
            end
            s[ec] = (s[ec] or 0) + 1
        end
        if id then
            xml.with_elements_only(get_id(id),get)
            return status
        else
            local t = { }
            for id, _ in pairs(loaded) do
                t[id] = lxml.get_command_status(id)
            end
            return t
        end
    end

end

local setups = { }

function lxml.installsetup(what,document,setup,where)
    document = document or "*"
    local sd = setups[document]
    if not sd then sd = { } setups[document] = sd end
    for k=1,#sd do
        if sd[k] == setup then sd[k] = nil break end
    end
    if what == 1 then
        if lxml.trace_load then
            ctx.writestatus("lxml","prepending setup %s for %s",setup,document)
        end
        insert(sd,1,setup)
    elseif what == 2 then
        if lxml.trace_load then
            ctx.writestatus("lxml","appending setup %s for %s",setup,document)
        end
        insert(sd,setup)
    elseif what == 3 then
        if lxml.trace_load then
            ctx.writestatus("lxml","inserting setup %s for %s before %s",setup,document,where)
        end
        table.insert_before_value(sd,setup,where)
    elseif what == 4 then
        if lxml.trace_load then
            ctx.writestatus("lxml","inserting setup %s for %s after %s",setup,document,where)
        end
        table.insert_after_value(sd,setup,where)
    end
end

function lxml.flushsetups(...)
    local done = { }
    for _, document in ipairs({...}) do
        local sd = setups[document]
        if sd then
            local tc = tex.ctxcatcodes
            for k=1,#sd do
                local v= sd[k]
                if not done[v] then
                    if lxml.trace_load then
                        ctx.writestatus("lxml","applying setup %02i = %s to %s",k,v,document)
                    end
                    texsprint(tc,format("\\directsetup{%s}",v))
                    done[v] = true
                end
            end
        elseif lxml.trace_load then
            ctx.writestatus("lxml","no setups for %s",document)
        end
    end
end

function lxml.resetsetups(document)
    if lxml.trace_load then
        ctx.writestatus("lxml","resetting all setups for %s",document)
    end
    setups[document] = { }
end

function lxml.removesetup(document,setup)
    local s = setups[document]
    if s then
        for i=1,#s do
            if s[i] == setup then
                if lxml.trace_load then
                    ctx.writestatus("lxml","removing setup %s for %s",setup,document)
                end
                remove(t,i)
                break
            end
        end
    end
end

local found, isempty = xml.found, xml.isempty

function lxml.doif         (id,pattern) commands.doif    (found(get_id(id),pattern,false)) end
function lxml.doifnot      (id,pattern) commands.doifnot (found(get_id(id),pattern,false)) end
function lxml.doifelse     (id,pattern) commands.doifelse(found(get_id(id),pattern,false)) end

-- todo: if no second arg or second arg == "" then quick test

function lxml.doiftext     (id,pattern) commands.doif    (found  (get_id(id),pattern,true)) end
function lxml.doifnottext  (id,pattern) commands.doifnot (found  (get_id(id),pattern,true)) end
function lxml.doifelsetext (id,pattern) commands.doifelse(found  (get_id(id),pattern,true)) end

-- special case: "*" and "" -> self else lpath lookup

function lxml.doifelseempty(id,pattern) commands.doifelse(isempty(get_id(id),pattern ~= "" and pattern ~= nil)) end -- not yet done, pattern
