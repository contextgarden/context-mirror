if not modules then modules = { } end modules ['lxml-ini'] = {
    version   = 1.001,
    comment   = "companion to lxml-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local tex = tex or {}

local texsprint, texprint, texwrite, utfchar = tex.sprint or print, tex.print or print, tex.write or print, utf.char
local concat, insert, remove, gsub, find = table.concat, table.insert, table.remove
local format, sub, gsub, find = string.format, string.sub, string.gsub, string.find
local type, next, tonumber, tostring = type, next, tonumber, tostring

local ctxcatcodes = tex.ctxcatcodes
local texcatcodes = tex.texcatcodes
local vrbcatcodes = tex.vrbcatcodes

local trace_setups  = false  trackers.register("lxml.setups",  function(v) trace_setups  = v end)
local trace_loading = false  trackers.register("lxml.loading", function(v) trace_loading = v end)
local trace_access  = false  trackers.register("lxml.access",  function(v) trace_access  = v end)

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
local xmlattribute, xmlindex, xmlchainattribute = xml.filters.attribute, xml.filters.index, xml.filters.chainattribute

local xmlelements = xml.elements

document     = document or { }
document.xml = document.xml or { }

-- todo: loaded and myself per document so that we can garbage collect buffers

lxml              = lxml or { }
lxml.loaded       = { }
lxml.paths        = { }
lxml.myself       = { }
lxml.noffiles     = 0
lxml.nofconverted = 0
lxml.nofindices   = 0

local loaded = lxml.loaded
local paths  = lxml.paths
local myself = lxml.myself
local stack  = lxml.stack

--~ lxml.self = myself -- be backward compatible for a while

--~ local function get_id(id)
--~     return (type(id) == "table" and id) or loaded[id] or myself[tonumber(id)] -- no need for tonumber if we pass without ""
--~ end

-- experiment

local currentdocuments, currentloaded, currentdocument, defaultdocument = { }, { }, "", ""

function lxml.pushdocument(name) -- catches double names
    if #currentdocuments == 0 then
        defaultdocument = name
    end
    currentdocument = name
    insert(currentdocuments,currentdocument)
    insert(currentloaded,loaded[currentdocument])
    if trace_access then
        logs.report("lxml","pushed: %s",currentdocument)
    end
end

function lxml.popdocument()
    currentdocument = remove(currentdocuments)
    if not currentdocument or currentdocument == "" then
        currentdocument = defaultdocument
    end
    loaded[currentdocument] = remove(currentloaded)
    if trace_access then
        logs.report("lxml","popped: %s",currentdocument)
    end
end

--~ local splitter = lpeg.splitat("::")
local splitter = lpeg.C((1-lpeg.P(":"))^1) * lpeg.P("::") * lpeg.C(lpeg.P(1)^1)

local function get_id(id)
    if type(id) == "table" then
        return id
    else
        local lid = loaded[id]
        if lid then
            return lid
        else
            local d, i = splitter:match(id)
            if d then
                local ld = loaded[d]
                if ld then
                    local ldi = ld.index
                    if ldi then
                        local root = ldi[tonumber(i)]
                        if root then
                            return root
                        elseif trace_access then
                            logs.report("lxml","'%s' has no index entry '%s'",d,i)
                        end
                    elseif trace_access then
                        logs.report("lxml","'%s' has no index",d)
                    end
                elseif trace_access then
                    logs.report("lxml","'%s' is not loaded",d)
                end
            else
                local ld = loaded[currentdocument]
                if ld then
                    local ldi = ld.index
                    if ldi then
                        local root = ldi[tonumber(id)]
                        if root then
                            return root
                        elseif trace_access then
                            logs.report("lxml","current document '%s' has no index entry '%s'",currentdocument,id)
                        end
                    elseif trace_access then
                        logs.report("lxml","current document '%s' has no index",currentdocument)
                    end
                elseif trace_access then
                    logs.report("lxml","current document '%s' not loaded",currentdocument)
                end
            end
        end
    end
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
    local spacing = newline  * space^0
    local content = lpeg.C((1-spacing)^1)
    local verbose = lpeg.C((1-(space+newline))^1)

    -- local capture  = (
    --     newline^2  * lpeg.Cc("")  / texprint +
    --     newline    * lpeg.Cc(" ") / texsprint +
    --     content                   / texsprint
    -- )^0

    local capture  = (
        space^0 * newline^2  * lpeg.Cc("")            / texprint  +
        space^0 * newline    * space^0 * lpeg.Cc(" ") / texsprint +
        content                                       / texsprint
    )^0

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
        --~ rawroot = false
            -- quit
        else
            local tr = type(root)
            if tr == "string" then -- can also be result of lpath
            --~ rawroot = false
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
        newline / function( ) texsprint(texcatcodes,linecommand,"{}") end +
        verbose / function(s) texsprint(vrbcatcodes,s) end +
        space   / function( ) texsprint(texcatcodes,spacecommand,"{}") end
    )^0

    local function toverbatim(str)
        if beforecommand then texsprint(texcatcodes,beforecommand,"{}") end
        capture:match(str)
        if aftercommand  then texsprint(texcatcodes,aftercommand,"{}")  end
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
        if beforecommand then texsprint(texcatcodes,beforecommand,"{}") end
        -- todo: add this to capture
        str = gsub(str,"^[ \t]+[\n\r]+","")
        str = gsub(str,"[ \t\n\r]+$","")
        capture:match(str)
        if aftercommand  then texsprint(texcatcodes,aftercommand,"{}")  end
    end

    function lxml.verbatim(id,before,after)
        local root = get_id(id)
        if root then
            if before then texsprint(ctxcatcodes,format("%s[%s]",before,root.tg)) end
        --  serialize(root.dt,toverbatim,nil,nil,nil,true)  -- was root
            local t = { }
            serialize(root.dt,function(s) t[#t+1] = s end,nil,nil,nil,true)  -- was root
            toverbatim(table.concat(t,""))
            if after then texsprint(ctxcatcodes,after) end
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
                texsprint(ctxcatcodes,format("\\xmlcontextdirective{%s}{%s}{%s}{%s}",a,b,c,d))
            end
        end
    end

    -- print(contextdirective("context-mathml-directive function reduction yes "))
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

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

--~ function xml.load(filename)
--~     lxml.noffiles = lxml.noffiles + 1
--~     starttiming(xml)
--~     local xmldata = xml.convert((filename and resolvers.loadtexfile(filename)) or "")
--~     stoptiming(xml)
--~     return xmldata
--~ end

function xml.load(filename)
    lxml.noffiles = lxml.noffiles + 1
    lxml.nofconverted = lxml.nofconverted + 1
    starttiming(xml)
    local ok, data = resolvers.loadbinfile(filename)
    local xmldata = xml.convert((ok and data) or "")
    stoptiming(xml)
    return xmldata
end

function lxml.load(id,filename)
    filename = commands.preparedfile(filename)
    if trace_loading then
        commands.writestatus("lxml","loading file '%s' as '%s'",filename,id)
    end
    local root = xml.load(filename)
    loaded[id], paths[id]= root, filename
    return root, filename
end

function lxml.register(id,xmltable)
    loaded[id] = xmltable
    return xmltable
end

function lxml.include(id,pattern,attribute,recurse)
    starttiming(xml)
    xml.include(get_id(id),pattern,attribute,recurse,function(filename)
        if filename then
            filename = commands.preparedfile(filename)
if file.dirname(filename) == "" then
    filename = file.join(file.dirname(paths[currentdocument]),filename)
end
            if trace_loading then
                commands.writestatus("lxml","including file: %s",filename)
            end
            lxml.noffiles = lxml.noffiles + 1
            lxml.nofconverted = lxml.nofconverted + 1
            return resolvers.loadtexfile(filename) or ""
        else
            return ""
        end
    end)
    stoptiming(xml)
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
        if d then
            xmlsprint(d[k])
        else -- new, maybe wrong
--~             xmlsprint(r)
        end
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
    str = gsub(str,"^%s*(.-)%s*$","%1")
    if nolines then
        str = gsub(str,"%s+"," ")
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

function lxml.chainattribute(id,pattern,a,default) --todo: snelle xmlatt
    local str = xmlchainattribute(get_id(id),pattern,a) or ""
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
        texsprint(ns,":",r.tg)
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
            texsprint(ctxcatcodes,lastseparator)
        elseif separator ~= "" then
            texsprint(ctxcatcodes,separator)
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
--~         local n = #myself + 1
--~         myself[n] = root
--~         texsprint(ctxcatcodes,format("\\xmlsetup{%i}{%s}",n,command))
        texsprint(ctxcatcodes,format("\\xmlsetup{%s}{%s}",root.ix,command))
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

function lxml.setsetup(id,pattern,setup)
    if not setup or setup == "" or setup == "*" or setup == "-" or setup == "+" then
        for rt, dt, dk in xmlelements(get_id(id),pattern) do
            local dtdk = dt and dt[dk] or rt
            local ns, tg = dtdk.rn or dtdk.ns, dtdk.tg
            if tg then -- to be sure
                local command = (ns == "" and tg) or (ns .. ":" .. tg)
                if setup == "-" then
                    dtdk.command = false
                    if trace then
                        logs.report("lxml","lpath matched -> %s -> skipped", command)
                    end
                elseif setup == "+" then
                    dtdk.command = true
                    if trace_setups then
                        logs.report("lxml","lpath matched -> %s -> text", command)
                    end
                else
                    dtdk.command = command
                    if trace_setups then
                        logs.report("lxml","lpath matched -> %s -> %s", command, command)
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
                    if trace_setups then
                        if ns == "" then
                            logs.report("lxml","lpath matched -> %s -> skipped", tg)
                        else
                            logs.report("lxml","lpath matched -> %s:%s -> skipped", ns, tg)
                        end
                    end
                elseif b == "+" then
                    dtdk.command = true
                    if trace_setups then
                        if ns == "" then
                            logs.report("lxml","lpath matched -> %s -> text", tg)
                        else
                            logs.report("lxml","lpath matched -> %s:%s -> text", ns, tg)
                        end
                    end
                else
                    dtdk.command = a .. tg
                    if trace_setups then
                        if ns == "" then
                            logs.report("lxml","lpath matched -> %s -> %s", tg, dtdk.command)
                        else
                            logs.report("lxml","lpath matched -> %s:%s -> %s", ns, tg, dtdk.command)
                        end
                    end
                end
            end
        else
            if trace_setups then
                logs.report("lxml","lpath pattern -> %s -> %s", pattern, setup)
            end
            for rt, dt, dk in xmlelements(get_id(id),pattern) do
                local dtdk = (dt and dt[dk]) or rt
                dtdk.command = setup
                if trace_setups then
                    local ns, tg = dtdk.rn or dtdk.ns, dtdk.tg
                    if ns == "" then
                        logs.report("lxml","lpath matched -> %s -> %s", tg, setup)
                    else
                        logs.report("lxml","lpath matched -> %s:%s -> %s", ns, tg, setup)
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
--~     cmd = gsub(cmd,"^([\'\"])(.-)%1$", "%2")
    if find(cmd,"^[\'\"]") then
        cmd = sub(cmd,2,-2)
    end
    traverse(root, lpath(pattern), function(r,d,k)
        -- this can become pretty large
        local m = (d and d[k]) or r -- brrr this r, maybe away
        if type(m) == "table" then -- probably a bug
--~             local n = #myself + 1
--~             myself[n] = m
--~             texsprint(ctxcatcodes,format("\\xmlsetup{%s}{%s}",n,cmd))
            texsprint(ctxcatcodes,format("\\xmlsetup{%s}{%s}",tostring(m.ix),cmd))
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
    local fullname = resolvers.find_file(filename) or ""
    if fullname ~= "" then
        filename = fullname
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
                texsprint(ctxcatcodes,format("\\directsetup{%s}",setup))
            else
                setup = data[format("%s::%s::*",element,attribute)]
                if setup then
                    setup = setup[category]
                end
                if setup then
                    texsprint(ctxcatcodes,format("\\directsetup{%s}",gsub(setup,'%*',value)))
                end
            end
        end
    end
end

function xml.getbuffer(name) -- we need to make sure that commands are processed
    if not name or name == "" then
        name = tex.jobname
    end
    lxml.nofconverted = lxml.nofconverted + 1
    xml.tostring(xml.convert(concat(buffers.data[name] or {},"")))
end

function lxml.loadbuffer(id,name)
    if not name or name == "" then
        name = tex.jobname
    end
    starttiming(xml)
    lxml.nofconverted = lxml.nofconverted + 1
    loaded[id] = xml.convert(buffers.collect(name or id,"\n"))
    stoptiming(xml)
    return loaded[id], name or id
end

function lxml.loaddata(id,str)
    starttiming(xml)
    lxml.nofconverted = lxml.nofconverted + 1
    loaded[id] = xml.convert(str or "")
    stoptiming(xml)
    return loaded[id], id
end

function lxml.loadregistered(id)
    return loaded[id], id
end

-- for the moment here:

lxml.set_verbatim("\\xmlcdatabefore", "\\xmlcdataafter", "\\xmlcdataobeyedline", "\\xmlcdataobeyedspace")
lxml.set_cdata()

local traced = { }

function lxml.trace_text_entities(str)
    return gsub(str,"&(.-);",function(s)
        traced[s] = (traced[s] or 0) + 1
        return "["..s.."]"
    end)
end

function lxml.show_text_entities()
    for k,v in ipairs(table.sortedkeys(traced)) do
        local h = v:match("^#x(.-)$")
        if h then
            local d = tonumber(h,16)
            local u = utfchar(d)
            logs.report("lxml","entity: %s / %s / %s / n=%s",h,d,u,traced[v])
        else
            logs.report("lxml","entity: %s / n=%s",v,traced[v])
        end
    end
end

local error_entity_handler   = function(s) return format("[%s]",s) end
local element_entity_handler = function(s) return format("<ctx:e n='%s'/>",s) end

function lxml.set_mkii_entityhandler()
    xml.entity_handler = error_entity_handler
    xml.set_text_cleanup()
end
function lxml.set_mkiv_entityhandler()
    xml.entity_handler = element_entity_handler
    xml.set_text_cleanup(xml.resolve_text_entities)
end
function lxml.reset_entityhandler()
    xml.entity_handler = error_entity_handler
    xml.set_text_cleanup()
end

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

local setups = { }

function lxml.installsetup(what,document,setup,where)
    document = document or "*"
    local sd = setups[document]
    if not sd then sd = { } setups[document] = sd end
    for k=1,#sd do
        if sd[k] == setup then sd[k] = nil break end
    end
    if what == 1 then
        if trace_loading then
            commands.writestatus("lxml","prepending setup %s for %s",setup,document)
        end
        insert(sd,1,setup)
    elseif what == 2 then
        if trace_loading then
            commands.writestatus("lxml","appending setup %s for %s",setup,document)
        end
        insert(sd,setup)
    elseif what == 3 then
        if trace_loading then
            commands.writestatus("lxml","inserting setup %s for %s before %s",setup,document,where)
        end
        table.insert_before_value(sd,setup,where)
    elseif what == 4 then
        if trace_loading then
            commands.writestatus("lxml","inserting setup %s for %s after %s",setup,document,where)
        end
        table.insert_after_value(sd,setup,where)
    end
end

function lxml.flushsetups(...)
    local done = { }
    for _, document in ipairs({...}) do
        local sd = setups[document]
        if sd then
            for k=1,#sd do
                local v= sd[k]
                if not done[v] then
                    if trace_loading then
                        commands.writestatus("lxml","applying setup %02i = %s to %s",k,v,document)
                    end
                    texsprint(ctxcatcodes,format("\\directsetup{%s}",v))
                    done[v] = true
                end
            end
        elseif trace_loading then
            commands.writestatus("lxml","no setups for %s",document)
        end
    end
end

function lxml.resetsetups(document)
    if trace_loading then
        commands.writestatus("lxml","resetting all setups for %s",document)
    end
    setups[document] = { }
end

function lxml.removesetup(document,setup)
    local s = setups[document]
    if s then
        for i=1,#s do
            if s[i] == setup then
                if trace_loading then
                    commands.writestatus("lxml","removing setup %s for %s",setup,document)
                end
                remove(t,i)
                break
            end
        end
    end
end

-- rather new, indexed storage (backward refs), maybe i will merge this

function lxml.addindex(name,check_sum,force)
    local root = get_id(name)
    if root and (not root.index or force) then -- weird, only called once
        local index, maxindex, check = root.index or { }, root.maxindex or 0, root.check or { }
        local n = 0
        local function nest(root)
            local dt = root.dt
            if not root.ix then
                maxindex = maxindex + 1
                root.ix = maxindex
                check[maxindex] = root.tg
                index[maxindex] = root
                n = n + 1
            end
            if dt then
                for k=1,#dt do
                    local dk = dt[k]
                    if type(dk) == "table" then
                        nest(dk)
                    end
                end
            end
        end
        nest(root)
        lxml.nofindices = lxml.nofindices + n
        --
        if type(name) ~= "string" then
            name = "unknown"
        end
        -- todo: checksum at the end, when tuo saved
--~         if root.checksum then
--~             -- extension mode
--~             root.index = index
--~             root.maxindex = maxindex
--~             commands.writestatus("lxml",format("checksum adapted for %s",tostring(name)))
--~         elseif check_sum then
--~             local tag = format("lxml:%s:checksum",name)
--~             local oldchecksum = jobvariables.collected[tag]
--~             local newchecksum = md5.HEX(concat(check,".")) -- maybe no "." needed
--~             jobvariables.tobesaved[tag] = newchecksum
--~             --
--~             if oldchecksum and oldchecksum ~= "" and oldchecksum ~= newchecksum then
--~                 root.index = { }
--~                 root.maxindex = 0
--~                 root.checksum = newchecksum
--~                 commands.writestatus("lxml",format("checksum mismatch for %s (extra run needed)",tostring(name)))
--~             else
--~                 root.index = index
--~                 root.maxindex = maxindex
--~                 root.checksum = newchecksum
--~                 commands.writestatus("lxml",format("checksum match for %s: %s",tostring(name),newchecksum))
--~             end
--~         else
            root.index = index
            root.maxindex = maxindex
--~         end
        if trace_access then
            commands.writestatus("lxml",format("%s loaded, %s index entries",tostring(name),maxindex))
        end
    end
end

local include= lxml.include

function lxml.include(id,...)
    include(id,...)
    lxml.addindex(currentdocument,false,true)
end

-- we can share the index

function lxml.checkindex(name)
    local root = get_id(name)
    return (root and root.index) or 0
end

function lxml.withindex(name,n,command)
    texsprint(ctxcatcodes,format("\\xmlsetup{%s::%s}{%s}",name,n,command))
end

function lxml.getindex(name,n)
    texsprint(ctxcatcodes,format("%s::%s",name,n))
end

--

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

-- status info

statistics.register("xml load time", function()
    local noffiles, nofconverted = lxml.noffiles, lxml.nofconverted
    if noffiles > 0 or nofconverted > 0 then
        return format("%s seconds, %s files, %s converted", statistics.elapsedtime(xml), noffiles, nofconverted)
    else
        return nil
    end
end)

--~ statistics.register("lxml preparation time", function()
--~     local n = #lxml.self
--~     if n > 0 then
--~         local stats = xml.statistics()
--~         return format("%s seconds, %s backreferences, %s lpath calls, %s cached calls", statistics.elapsedtime(xml), n, stats.lpathcalls, stats.lpathcached)
--~     else
--~         return nil
--~     end
--~ end)

statistics.register("lxml preparation time", function()
    local noffiles, nofconverted = lxml.noffiles, lxml.nofconverted
    if noffiles > 0 or nofconverted > 0 then
        local stats = xml.statistics()
        return format("%s seconds, %s nodes, %s lpath calls, %s cached calls", statistics.elapsedtime(lxml), lxml.nofindices, stats.lpathcalls, stats.lpathcached)
    else
        return nil
    end
end)
