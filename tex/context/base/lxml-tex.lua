if not modules then modules = { } end modules ['lxml-tst'] = {
    version   = 1.001,
    comment   = "companion to lxml-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local utfchar = utf.char
local concat, insert, remove = table.concat, table.insert, table.remove
local format, sub, gsub, find, gmatch, match = string.format, string.sub, string.gsub, string.find, string.gmatch, string.match
local type, next, tonumber, tostring = type, next, tonumber, tostring
local lpegmatch = lpeg.match
local P, S, C, Cc = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc

local tex, xml = tex, xml
local lowerchars, upperchars, lettered = characters.lower, characters.upper, characters.lettered

lxml       = lxml or { }
local lxml = lxml

local texsprint, texprint, texwrite = tex.sprint, tex.print, tex.write
local texcatcodes, ctxcatcodes, vrbcatcodes, notcatcodes = tex.texcatcodes, tex.ctxcatcodes, tex.vrbcatcodes, tex.notcatcodes

local xmlelements, xmlcollected, xmlsetproperty = xml.elements, xml.collected, xml.setproperty
local xmlwithelements = xml.withelements
local xmlserialize, xmlcollect, xmltext, xmltostring = xml.serialize, xml.collect, xml.text, xml.tostring
local xmlapplylpath = xml.applylpath

local variables = (interfaces and interfaces.variables) or { }

local insertbeforevalue, insertaftervalue = utilities.tables.insertbeforevalue, utilities.tables.insertaftervalue

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

local trace_setups   = false  trackers.register("lxml.setups",   function(v) trace_setups   = v end)
local trace_loading  = false  trackers.register("lxml.loading",  function(v) trace_loading  = v end)
local trace_access   = false  trackers.register("lxml.access",   function(v) trace_access   = v end)
local trace_comments = false  trackers.register("lxml.comments", function(v) trace_comments = v end)

local report_lxml = logs.reporter("xml","tex")

lxml.loaded  = lxml.loaded or { }
local loaded = lxml.loaded

-- print(contextdirective("context-mathml-directive function reduction yes "))
-- print(contextdirective("context-mathml-directive function "))

xml.defaultprotocol = "tex"

local finalizers  = xml.finalizers

finalizers.xml = finalizers.xml or { }
finalizers.tex = finalizers.tex or { }

-- this might look inefficient but it's actually rather efficient
-- because we avoid tokenization of leading spaces and xml can be
-- rather verbose (indented)

local newline   = lpeg.patterns.newline
local space     = lpeg.patterns.spacer
local ampersand = P("&")
local semicolon = P(";")
local spacing   = newline * space^0
local content   = C((1-spacing-ampersand)^1)
local verbose   = C((1-(space+newline))^1)
local entity    = ampersand * C((1-semicolon)^1) * semicolon

local xmltextcapture = (
    space^0 * newline^2  * Cc("")            / texprint  + -- better ^-2 ?
    space^0 * newline    * space^0 * Cc(" ") / texsprint +
    content                                  / function(str) return texsprint(notcatcodes,str) end + -- was just texsprint, current catcodes regime is notcatcodes
    entity                                   / xml.resolvedentity
)^0

local ctxtextcapture = (
    space^0 * newline^2  * Cc("")            / texprint  + -- better ^-2 ?
    space^0 * newline    * space^0 * Cc(" ") / texsprint +
    content                                  / function(str) return texsprint(ctxcatcodes,str) end + -- was just texsprint, current catcodes regime is notcatcodes
    entity                                   / xml.resolvedentity
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

--~ function lxml.rawpath(rootid)
--~     if rawroot and type(rawroot) == "table" then
--~         local text, path, rp
--~         if not rawroot.dt then
--~             text, path, rp = "text", "", rawroot[0]
--~         else
--~             path, rp = "tree", "", rawroot.__p__
--~         end
--~         while rp do
--~             local rptg = rp.tg
--~             if rptg then
--~                 path = rptg .. "/" .. path
--~             end
--~             rp = rp.__p__
--~         end
--~         return { rootid, "/" .. path, text }
--~     end
--~ end

-- cdata

local linecommand   = "\\obeyedline"
local spacecommand  = "\\obeyedspace" -- "\\strut\\obeyedspace"
local beforecommand = ""
local aftercommand  = ""

local xmlverbosecapture = (
    newline / function( ) texsprint(texcatcodes,linecommand,"{}") end +
    verbose / function(s) texsprint(vrbcatcodes,s) end +
    space   / function( ) texsprint(texcatcodes,spacecommand,"{}") end
)^0

local function toverbatim(str)
    if beforecommand then texsprint(texcatcodes,beforecommand,"{}") end
    lpegmatch(xmlverbosecapture,str)
    if aftercommand  then texsprint(texcatcodes,aftercommand,"{}")  end
end

function lxml.setverbatim(before,after,obeyedline,obeyedspace)
    beforecommand, aftercommand, linecommand, spacecommand = before, after, obeyedline, obeyedspace
end

local obeycdata = true

function lxml.setcdata()
    obeycdata = true
end

function lxml.resetcdata()
    obeycdata = false
end

-- cdata and verbatim

lxml.setverbatim("\\xmlcdatabefore", "\\xmlcdataafter", "\\xmlcdataobeyedline", "\\xmlcdataobeyedspace")

-- local capture = (space^0*newline)^0 * capture * (space+newline)^0 * -1

function lxml.toverbatim(str)
    if beforecommand then texsprint(texcatcodes,beforecommand,"{}") end
    -- todo: add this to capture
    str = gsub(str,"^[ \t]+[\n\r]+","")
    str = gsub(str,"[ \t\n\r]+$","")
    lpegmatch(xmlverbosecapture,str)
    if aftercommand  then texsprint(texcatcodes,aftercommand,"{}")  end
end

-- storage

function lxml.store(id,root,filename)
    loaded[id] = root
    xmlsetproperty(root,"name",id)
    if filename then
        xmlsetproperty(root,"filename",filename)
    end
end

local splitter = lpeg.splitat("::")

lxml.idsplitter = splitter

function lxml.splitid(id)
    local d, i = lpegmatch(splitter,id)
    if d then
        return d, i
    else
        return "", id
    end
end

local function getid(id, qualified)
    if id then
        local lid = loaded[id]
        if lid then
            return lid
        elseif type(id) == "table" then
            return id
        else
            local d, i = lpegmatch(splitter,id)
            if d then
                local ld = loaded[d]
                if ld then
                    local ldi = ld.index
                    if ldi then
                        local root = ldi[tonumber(i)]
                        if root then
                            if qualified then -- we need this else two args that confuse others
                                return root, d
                            else
                                return root
                            end
                        elseif trace_access then
                            report_lxml("'%s' has no index entry '%s'",d,i)
                        end
                    elseif trace_access then
                        report_lxml("'%s' has no index",d)
                    end
                elseif trace_access then
                    report_lxml("'%s' is not loaded",d)
                end
            elseif trace_access then
                report_lxml("'%s' is not loaded",i)
            end
        end
    elseif trace_access then
        report_lxml("invalid id (nil)")
    end
end

lxml.id    = getid -- we provide two names as locals can already use such
lxml.getid = getid -- names and we don't want clashes

function lxml.root(id)
    return loaded[id]
end

-- index

local nofindices = 0

local function addindex(name,check_sum,force)
    local root = getid(name)
    if root and (not root.index or force) then -- weird, only called once
        local n, index, maxindex, check = 0, root.index or { }, root.maxindex or 0, root.check or { }
        local function nest(root)
            local dt = root.dt
            if not root.ix then
                maxindex = maxindex + 1
                root.ix = maxindex
                check[maxindex] = root.tg -- still needed ?
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
        nofindices = nofindices + n
        --
        if type(name) ~= "string" then
            name = "unknown"
        end
        root.index = index
        root.maxindex = maxindex
        if trace_access then
            report_lxml("%s indexed, %s nodes",tostring(name),maxindex)
        end
    end
end

lxml.addindex = addindex

-- another cache

local function lxmlapplylpath(id,pattern) -- better inline, saves call
    return xmlapplylpath(getid(id),pattern)
end

lxml.filter = lxmlapplylpath

function lxml.filterlist(list,pattern)
    for s in gmatch(list,"[^, ]+") do -- we could cache a table
        xmlapplylpath(getid(s),pattern)
    end
end

function lxml.applyfunction(id,name)
    local f = xml.functions[name]
    return f and f(getid(id))
end

-- rather new, indexed storage (backward refs), maybe i will merge this

function lxml.checkindex(name)
    local root = getid(name)
    return (root and root.index) or 0
end

function lxml.withindex(name,n,command) -- will change as name is always there now
    local i, p = lpegmatch(splitter,n)
    if p then
        texsprint(ctxcatcodes,"\\xmlw{",command,"}{",n,"}")
    else
        texsprint(ctxcatcodes,"\\xmlw{",command,"}{",name,"::",n,"}")
    end
end

function lxml.getindex(name,n) -- will change as name is always there now
    local i, p = lpegmatch(splitter,n)
    if p then
        texsprint(ctxcatcodes,n)
    else
        texsprint(ctxcatcodes,name,"::",n)
    end
end

-- loading (to be redone, no overload)

xml.originalload = xml.originalload or xml.load

local noffiles, nofconverted = 0, 0

function xml.load(filename,settings)
    noffiles, nofconverted = noffiles + 1, nofconverted + 1
    starttiming(xml)
    local ok, data = resolvers.loadbinfile(filename)
    local xmltable = xml.convert((ok and data) or "",settings)
    stoptiming(xml)
    return xmltable
end

local entities = xml.entities

local function entityconverter(id,str)
    return entities[str] or "" -- -and "&"..str..";" -- feed back into tex end later
end

function lxml.convert(id,data,entities,compress)
    local settings = {
        unify_predefined_entities = true,
--~ resolve_predefined_entities = true,
    }
    if compress and compress == variables.yes then
        settings.strip_cm_and_dt = true
    end
    if entities and entities == variables.yes then
        settings.utfize_entities = true
        settings.resolve_entities = function (str) return entityconverter(id,str) end
    end
    return xml.convert(data,settings)
end

function lxml.load(id,filename,compress,entities)
    filename = commands.preparedfile(filename)
    if trace_loading then
        report_lxml("loading file '%s' as '%s'",filename,id)
    end
    noffiles, nofconverted = noffiles + 1, nofconverted + 1
 -- local xmltable = xml.load(filename)
    starttiming(xml)
    local ok, data = resolvers.loadbinfile(filename)
    local xmltable = lxml.convert(id,(ok and data) or "",compress,entities)
    stoptiming(xml)
    lxml.store(id,xmltable,filename)
    return xmltable, filename
end

function lxml.register(id,xmltable,filename)
    lxml.store(id,xmltable,filename)
    return xmltable
end

function lxml.include(id,pattern,attribute,recurse)
    starttiming(xml)
    local root = getid(id)
    xml.include(root,pattern,attribute,recurse,function(filename)
        if filename then
            filename = commands.preparedfile(filename)
            if file.dirname(filename) == "" and root.filename then
                local dn = file.dirname(root.filename)
                if dn ~= "" then
                    filename = file.join(dn,filename)
                end
            end
            if trace_loading then
                report_lxml("including file: %s",filename)
            end
            noffiles, nofconverted = noffiles + 1, nofconverted + 1
            return resolvers.loadtexfile(filename) or ""
        else
            return ""
        end
    end)
    stoptiming(xml)
end

function xml.getbuffer(name,compress,entities) -- we need to make sure that commands are processed
    if not name or name == "" then
        name = tex.jobname
    end
    nofconverted = nofconverted + 1
    local data = buffers.getcontent(name)
    xmltostring(lxml.convert(name,data,compress,entities)) -- one buffer
end

function lxml.loadbuffer(id,name,compress,entities)
--~     if not name or name == "" then
--~         name = tex.jobname
--~     end
    starttiming(xml)
    nofconverted = nofconverted + 1
    local data = buffers.collectcontent(name or id) -- name can be list
    local xmltable = lxml.convert(id,data,compress,entities)
    lxml.store(id,xmltable)
    stoptiming(xml)
    return xmltable, name or id
end

function lxml.loaddata(id,str,compress,entities)
    starttiming(xml)
    nofconverted = nofconverted + 1
    local xmltable = lxml.convert(id,str or "",compress,entities)
    lxml.store(id,xmltable)
    stoptiming(xml)
    return xmltable, id
end

function lxml.loadregistered(id)
    return loaded[id], id
end

-- e.command:
--
-- string   : setup
-- true     : text (no <self></self>)
-- false    : ignore
-- function : call

local function tex_doctype(e,handlers)
    -- ignore
end

local function tex_comment(e,handlers)
    if trace_comments then
        report_lxml("comment: %s",e.dt[1])
    end
end

local default_element_handler = xml.gethandlers("verbose").functions["@el@"]

local function tex_element(e,handlers)
    local command = e.command
    if command == nil then
        default_element_handler(e,handlers)
    elseif command == true then
        -- text (no <self></self>) / so, no mkii fallback then
        handlers.serialize(e.dt,handlers)
    elseif command == false then
        -- ignore
    else
        local tc = type(command)
        if tc == "string" then
            local rootname, ix = e.name, e.ix
            if rootname then
                if not ix then
                    addindex(rootname,false,true)
                    ix = e.ix
                end
                texsprint(ctxcatcodes,"\\xmlw{",command,"}{",rootname,"::",ix,"}")
            else
                report_lxml( "fatal error: no index for '%s'",command)
                texsprint(ctxcatcodes,"\\xmlw{",command,"}{",ix or 0,"}")
            end
        elseif tc == "function" then
            command(e)
        end
    end
end

local pihandlers = { }  xml.pihandlers = pihandlers

local category = P("context-") * C((1-P("-"))^1) * P("-directive")
local space    = S(" \n\r")
local spaces   = space^0
local class    = C((1-space)^0)
local key      = class
local value    = C(P(1-(space * -1))^0)

local parser = category * spaces * class * spaces * key * spaces * value

pihandlers[#pihandlers+1] = function(str)
    if str then
        local a, b, c, d = lpegmatch(parser,str)
        if d then
            texsprint(ctxcatcodes,"\\xmlcontextdirective{",a,"}{",b,"}{",c,"}{",d,"}")
        end
    end
end

local function tex_pi(e,handlers)
    local str = e.dt[1]
    for i=1,#pihandlers do
        pihandlers[i](str)
    end
end

local function tex_cdata(e,handlers)
    if obeycdata then
        toverbatim(e.dt[1])
    end
end

local function tex_text(e)
    lpegmatch(xmltextcapture,e)
end

local function ctx_text(e)
    lpegmatch(ctxtextcapture,e)
end

local function tex_handle(...)
--  report_lxml( "error while flushing: %s", concat { ... })
    texsprint(...) -- notcatcodes is active anyway
end

local xmltexhandler = xml.newhandlers {
    name       = "tex",
    handle     = tex_handle,
    functions  = {
     -- ["@dc@"]   = tex_document,
        ["@dt@"]   = tex_doctype,
     -- ["@rt@"]   = tex_root,
        ["@el@"]   = tex_element,
        ["@pi@"]   = tex_pi,
        ["@cm@"]   = tex_comment,
        ["@cd@"]   = tex_cdata,
        ["@tx@"]   = tex_text,
    }
}

lxml.xmltexhandler = xmltexhandler

function lxml.serialize(root)
    xmlserialize(root,xmltexhandler)
end

function lxml.setaction(id,pattern,action)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        for c=1,#collected do
            collected[c].command = action
        end
    end
end

local function sprint(root)
    if root then
        local tr = type(root)
        if tr == "string" then -- can also be result of lpath
         -- rawroot = false
            lpegmatch(xmltextcapture,root)
        elseif tr == "table" then
            if forceraw then
                rawroot = root
                texwrite(xmltostring(root))
            else
                xmlserialize(root,xmltexhandler)
            end
        end
    end
end

local function tprint(root) -- we can move sprint inline
    local tr = type(root)
    if tr == "table" then
        local n = #root
        if n == 0 then
            -- skip
        else
            for i=1,n do
                sprint(root[i])
            end
        end
    elseif tr == "string" then
        lpegmatch(xmltextcapture,root)
    end
end

local function cprint(root) -- content
    if not root then
     -- rawroot = false
        -- quit
    elseif type(root) == 'string' then
     -- rawroot = false
        lpegmatch(xmltextcapture,root)
    else
        local rootdt = root.dt
        if forceraw then
            rawroot = root
            texwrite(xmltostring(rootdt or root))
        else
            xmlserialize(rootdt or root,xmltexhandler)
        end
    end
end

xml.sprint = sprint local xmlsprint = sprint  -- redo these names
xml.tprint = tprint local xmltprint = tprint
xml.cprint = cprint local xmlcprint = cprint

-- now we can flush

function lxml.main(id)
    xmlserialize(getid(id),xmltexhandler) -- the real root (@rt@)
end

--~ -- lines (untested)
--~
--~ local buffer = { }
--~
--~ local xmllinescapture = (
--~     newline^2 / function()  buffer[#buffer+1] = "" end +
--~     newline   / function()  buffer[#buffer] = buffer[#buffer] .. " " end +
--~     content   / function(s) buffer[#buffer] = buffer[#buffer] ..  s  end
--~ )^0
--~
--~ local xmllineshandler = table.copy(xmltexhandler)
--~
--~ xmllineshandler.handle = function(...) lpegmatch(xmllinescapture,concat{ ... }) end
--~
--~ function lines(root)
--~     if not root then
--~      -- rawroot = false
--~      -- quit
--~     elseif type(root) == 'string' then
--~      -- rawroot = false
--~         lpegmatch(xmllinescapture,root)
--~     elseif next(root) then -- tr == 'table'
--~         xmlserialize(root,xmllineshandler)
--~     end
--~ end
--~
--~ function xml.lines(root) -- used at all?
--~     buffer = { "" }
--~     lines(root)
--~     return result
--~ end

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

-- setups

local setups = { }

function lxml.setcommandtotext(id)
    xmlwithelements(getid(id),to_text)
end

function lxml.setcommandtonone(id)
    xmlwithelements(getid(id),to_none)
end

function lxml.installsetup(what,document,setup,where)
    document = document or "*"
    local sd = setups[document]
    if not sd then sd = { } setups[document] = sd end
    for k=1,#sd do
        if sd[k] == setup then sd[k] = nil break end
    end
    if what == 1 then
        if trace_loading then
            report_lxml("prepending setup %s for %s",setup,document)
        end
        insert(sd,1,setup)
    elseif what == 2 then
        if trace_loading then
            report_lxml("appending setup %s for %s",setup,document)
        end
        insert(sd,setup)
    elseif what == 3 then
        if trace_loading then
            report_lxml("inserting setup %s for %s before %s",setup,document,where)
        end
        insertbeforevalue(sd,setup,where)
    elseif what == 4 then
        if trace_loading then
            report_lxml("inserting setup %s for %s after %s",setup,document,where)
        end
        insertaftervalue(sd,setup,where)
    end
end

function lxml.flushsetups(id,...)
    local done, list = { }, { ... }
    for i=1,#list do
        local document = list[i]
        local sd = setups[document]
        if sd then
            for k=1,#sd do
                local v= sd[k]
                if not done[v] then
                    if trace_loading then
                        report_lxml("applying setup %02i = %s to %s",k,v,document)
                    end
                    texsprint(ctxcatcodes,"\\xmlsetup{",id,"}{",v,"}")
                    done[v] = true
                end
            end
        elseif trace_loading then
            report_lxml("no setups for %s",document)
        end
    end
end

function lxml.resetsetups(document)
    if trace_loading then
        report_lxml("resetting all setups for %s",document)
    end
    setups[document] = { }
end

function lxml.removesetup(document,setup)
    local s = setups[document]
    if s then
        for i=1,#s do
            if s[i] == setup then
                if trace_loading then
                    report_lxml("removing setup %s for %s",setup,document)
                end
                remove(t,i)
                break
            end
        end
    end
end

function lxml.setsetup(id,pattern,setup)
    if not setup or setup == "" or setup == "*" or setup == "-" or setup == "+" then
        local collected = xmlapplylpath(getid(id),pattern)
        if collected then
            if trace_setups then
                for c=1, #collected do
                    local e = collected[c]
                    local ix = e.ix or 0
                    if setup == "-" then
                        e.command = false
                        report_lxml("lpath matched (a) %5i: %s = %s -> skipped",c,ix,setup)
                    elseif setup == "+" then
                        e.command = true
                        report_lxml("lpath matched (b) %5i: %s = %s -> text",c,ix,setup)
                    else
                        local tg = e.tg
                        if tg then -- to be sure
                            e.command = tg
                            local ns = e.rn or e.ns
                            if ns == "" then
                                report_lxml("lpath matched (c) %5i: %s = %s -> %s",c,ix,tg,tg)
                            else
                                report_lxml("lpath matched (d) %5i: %s = %s:%s -> %s",c,ix,ns,tg,tg)
                            end
                        end
                    end
                end
            else
                for c=1, #collected do
                    local e = collected[c]
                    if setup == "-" then
                        e.command = false
                    elseif setup == "+" then
                        e.command = true
                    else
                        e.command = e.tg
                    end
                end
            end
        elseif trace_setups then
            report_lxml("no lpath matches for %s",pattern)
        end
    else
        local a, b = match(setup,"^(.+:)([%*%-])$")
        if a and b then
            local collected = xmlapplylpath(getid(id),pattern)
            if collected then
                if trace_setups then
                    for c=1, #collected do
                        local e = collected[c]
                        local ns, tg, ix = e.rn or e.ns, e.tg, e.ix or 0
                        if b == "-" then
                            e.command = false
                            if ns == "" then
                                report_lxml("lpath matched (e) %5i: %s = %s -> skipped",c,ix,tg)
                            else
                                report_lxml("lpath matched (f) %5i: %s = %s:%s -> skipped",c,ix,ns,tg)
                            end
                        elseif b == "+" then
                            e.command = true
                            if ns == "" then
                                report_lxml("lpath matched (g) %5i: %s = %s -> text",c,ix,tg)
                            else
                                report_lxml("lpath matched (h) %5i: %s = %s:%s -> text",c,ix,ns,tg)
                            end
                        else
                            e.command = a .. tg
                            if ns == "" then
                                report_lxml("lpath matched (i) %5i: %s = %s -> %s",c,ix,tg,e.command)
                            else
                                report_lxml("lpath matched (j) %5i: %s = %s:%s -> %s",c,ix,ns,tg,e.command)
                            end
                        end
                    end
                else
                    for c=1, #collected do
                        local e = collected[c]
                        if b == "-" then
                            e.command = false
                        elseif b == "+" then
                            e.command = true
                        else
                            e.command = a .. e.tg
                        end
                    end
                end
            elseif trace_setups then
                report_lxml("no lpath matches for %s",pattern)
            end
        else
            local collected = xmlapplylpath(getid(id),pattern)
            if collected then
                if trace_setups then
                    for c=1, #collected do
                        local e = collected[c]
                        e.command = setup
                        local ns, tg, ix = e.rn or e.ns, e.tg, e.ix or 0
                        if ns == "" then
                            report_lxml("lpath matched (k) %5i: %s = %s -> %s",c,ix,tg,setup)
                        else
                            report_lxml("lpath matched (l) %5i: %s = %s:%s -> %s",c,ix,ns,tg,setup)
                        end
                    end
                else
                    for c=1, #collected do
                        collected[c].command = setup
                    end
                end
            elseif trace_setups then
                report_lxml("no lpath matches for %s",pattern)
            end
        end
    end
end

-- finalizers

local finalizers = xml.finalizers.tex

local function first(collected)
    if collected then
        xmlsprint(collected[1])
    end
end

local function last(collected)
    if collected then
        xmlsprint(collected[#collected])
    end
end

local function all(collected)
    if collected then
        for c=1,#collected do
            xmlsprint(collected[c])
        end
    end
end

local function reverse(collected)
    if collected then
        for c=#collected,1,-1 do
            xmlsprint(collected[c])
        end
    end
end

local function count(collected)
    texwrite((collected and #collected) or 0)
end

local function position(collected,n)
    -- todo: if not n then == match
    if collected then
        n = tonumber(n) or 0
        if n < 0 then
            n = #collected + n + 1
        end
        if n > 0 then
            xmlsprint(collected[n])
        end
    end
end

local function match(collected) -- is match in preceding collected, never change, see bibxml
    local m = collected and collected[1]
    texwrite(m and m.mi or 0)
end

local function index(collected,n)
    if collected then
        n = tonumber(n) or 0
        if n < 0 then
            n = #collected + n + 1 -- brrr
        end
        if n > 0 then
            texwrite(collected[n].ni or 0)
        end
    end
end

local function command(collected,cmd,otherwise)
    local n = collected and #collected
    if n and n > 0 then
        for c=1,n do
            local e = collected[c]
            local ix = e.ix
            if not ix then
                lxml.addindex(e.name,false,true)
                ix = e.ix
            end
            texsprint(ctxcatcodes,"\\xmlw{",cmd,"}{",e.name,"::",ix,"}")
        end
    elseif otherwise then
        texsprint(ctxcatcodes,"\\xmlw{",otherwise,"}{#1}")
    end
end

local function attribute(collected,a,default)
    if collected and #collected > 0 then
        local at = collected[1].at
        local str = (at and at[a]) or default
        if str and str ~= "" then
            texsprint(notcatcodes,str)
        end
    elseif default then
        texsprint(notcatcodes,default)
    end
end

local function chainattribute(collected,arguments) -- todo: optional levels
    if collected then
        local e = collected[1]
        while e do
            local at = e.at
            if at then
                local a = at[arguments]
                if a then
                    texsprint(notcatcodes,a)
                end
            else
                break -- error
            end
            e = e.__p__
        end
    end
end

local function text(collected)
    if collected then
        local nc = #collected
        if nc == 1 then -- hardly any gain so this will go
            cprint(collected[1])
        else for c=1,nc do
            cprint(collected[c])
        end end
    end
end

local function ctxtext(collected)
    if collected then
        for c=1,#collected do
            texsprint(ctxcatcodes,collected[1].dt)
        end
    end
end

--~     local str = xmltext(getid(id),pattern) or ""
--~     str = gsub(str,"^%s*(.-)%s*$","%1")
--~     if nolines then
--~         str = gsub(str,"%s+"," ")
--~     end

local function stripped(collected) -- tricky as we strip in place
    if collected then
        for c=1,#collected do
            cprint(xml.stripelement(collected[c]))
        end
    end
end

local function lower(collected)
    if collected then
        for c=1,#collected do
            texsprint(ctxcatcodes,lowerchars(collected[1].dt[1]))
        end
    end
end

local function upper(collected)
    if collected then
        for c=1,#collected do
            texsprint(ctxcatcodes,upperchars(collected[1].dt[1]))
        end
    end
end

local function number(collected)
    if collected then
        local n = 0
        for c=1,#collected do
            n = n + tonumber(collected[c].dt[1] or 0)
        end
        texwrite(n)
    end
end

local function concatrange(collected,start,stop,separator,lastseparator,textonly) -- test this on mml
    if collected then
        local nofcollected = #collected
        local separator = separator or ""
        local lastseparator = lastseparator or separator or ""
        start, stop = (start == "" and 1) or tonumber(start) or 1, (stop == "" and nofcollected) or tonumber(stop) or nofcollected
        if stop < 0 then stop = nofcollected + stop end -- -1 == last-1
        for i=start,stop do
            if textonly then
                xmlcprint(collected[i])
            else
                xmlsprint(collected[i])
            end
            if i == nofcollected then
                -- nothing
            elseif i == nofcollected-1 and lastseparator ~= "" then
                texsprint(ctxcatcodes,lastseparator)
            elseif separator ~= "" then
                texsprint(ctxcatcodes,separator)
            end
        end
    end
end

local function concat(collected,separator,lastseparator,textonly) -- test this on mml
    concatrange(collected,false,false,separator,lastseparator,textonly)
end

finalizers.first          = first
finalizers.last           = last
finalizers.all            = all
finalizers.reverse        = reverse
finalizers.count          = count
finalizers.command        = command
finalizers.attribute      = attribute
finalizers.text           = text
finalizers.stripped       = stripped
finalizers.lower          = lower
finalizers.upper          = upper
finalizers.ctxtext        = ctxtext
finalizers.context        = ctxtext
finalizers.position       = position
finalizers.match          = match
finalizers.index          = index
finalizers.concat         = concat
finalizers.concatrange    = concatrange
finalizers.chainattribute = chainattribute
finalizers.default        = all -- !!

local concat = table.concat

function finalizers.tag(collected)
    if collected then
        local c
        if n == 0 or not n then
            c = collected[1]
        elseif n > 1 then
            c = collected[n]
        else
            c = collected[#collected-n+1]
        end
        if c then
            texsprint(c.tg)
        end
    end
end

function finalizers.name(collected)
    if collected then
        local c
        if n == 0 or not n then
            c = collected[1]
        elseif n > 1 then
            c = collected[n]
        else
            c = collected[#collected-n+1]
        end
        if c then
            if c.ns == "" then
                texsprint(c.tg)
            else
                texsprint(c.ns,":",c.tg)
            end
        end
    end
end

function finalizers.tags(collected,nonamespace)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local ns, tg = e.ns, e.tg
            if nonamespace or ns == "" then
                texsprint(tg)
            else
                texsprint(ns,":",tg)
            end
        end
    end
end

--

local function verbatim(id,before,after)
    local root = getid(id)
    if root then
        if before then texsprint(ctxcatcodes,before,"[",root.tg or "?","]") end
        lxml.toverbatim(xmltostring(root.dt))
        if after then texsprint(ctxcatcodes,after) end
    end
end
function lxml.inlineverbatim(id)
    verbatim(id,"\\startxmlinlineverbatim","\\stopxmlinlineverbatim")
end
function lxml.displayverbatim(id)
    verbatim(id,"\\startxmldisplayverbatim","\\stopxmldisplayverbatim")
end

lxml.verbatim = verbatim

-- helpers

function lxml.first(id,pattern)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        first(collected)
    end
end

function lxml.last(id,pattern)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        last(collected)
    end
end

function lxml.all(id,pattern)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        all(collected)
    end
end

function lxml.count(id,pattern)
    -- always needs to produce a result so no test here
    count(xmlapplylpath(getid(id),pattern))
end

function lxml.attribute(id,pattern,a,default)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        attribute(collected,a,default)
    end
end

function lxml.raw(id,pattern) -- the content, untouched by commands
    local collected = (pattern and xmlapplylpath(getid(id),pattern)) or getid(id)
    if collected then
        texsprint(xmltostring(collected[1].dt))
    end
end

function lxml.context(id,pattern) -- the content, untouched by commands
    if not pattern then
        local collected = getid(id)
    --  texsprint(ctxcatcodes,collected.dt[1])
        ctx_text(collected.dt[1])
    else
        local collected = xmlapplylpath(getid(id),pattern) or getid(id)
        if collected and #collected > 0 then
            texsprint(ctxcatcodes,collected[1].dt)
        end
    end
end

function lxml.text(id,pattern)
    local collected = (pattern and xmlapplylpath(getid(id),pattern)) or getid(id)
    if collected then
        text(collected)
    end
end

lxml.content = text

function lxml.position(id,pattern,n)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        position(collected,n)
    end
end

function lxml.chainattribute(id,pattern,a,default)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        chainattribute(collected,a,default)
    end
end

function lxml.concatrange(id,pattern,start,stop,separator,lastseparator,textonly) -- test this on mml
    concatrange(xmlapplylpath(getid(id),pattern),start,stop,separator,lastseparator,textonly)
end

function lxml.concat(id,pattern,separator,lastseparator,textonly)
    concatrange(xmlapplylpath(getid(id),pattern),false,false,separator,lastseparator,textonly)
end

function lxml.element(id,n)
    position(xmlapplylpath(getid(id),"/*"),n)
end

lxml.index = lxml.position

function lxml.pos(id)
    local root = getid(id)
    texwrite((root and root.ni) or 0)
end

function lxml.att(id,a,default)
    local root = getid(id)
    if root then
        local at = root.at
        local str = (at and at[a]) or default
        if str and str ~= "" then
            texsprint(notcatcodes,str)
        end
    elseif default then
        texsprint(notcatcodes,default)
    end
end

function lxml.name(id) -- or remapped name? -> lxml.info, combine
    local r = getid(id)
    local ns = r.rn or r.ns or ""
    if ns ~= "" then
        texsprint(ns,":",r.tg)
    else
        texsprint(r.tg)
    end
end

function lxml.match(id) -- or remapped name? -> lxml.info, combine
    texsprint(getid(id).mi or 0)
end

function lxml.tag(id) -- tag vs name -> also in l-xml tag->name
    texsprint(getid(id).tg or "")
end

function lxml.namespace(id) -- or remapped name?
    local root = getid(id)
    texsprint(root.rn or root.ns or "")
end

function lxml.flush(id)
    id = getid(id)
    local dt = id and id.dt
    if dt then
        xmlsprint(dt)
    end
end

function lxml.snippet(id,i)
    local e = getid(id)
    if e then
        local edt = e.dt
        if edt then
            xmlsprint(edt[i])
        end
    end
end

function lxml.direct(id)
    xmlsprint(getid(id))
end

function lxml.command(id,pattern,cmd)
    local i, p = getid(id,true)
    local collected = xmlapplylpath(getid(i),pattern)
    if collected then
        local rootname = p or i.name
        for c=1,#collected do
            local e = collected[c]
            local ix = e.ix
            if not ix then
                addindex(rootname,false,true)
                ix = e.ix
            end
            texsprint(ctxcatcodes,"\\xmlw{",cmd,"}{",rootname,"::",ix,"}")
        end
    end
end

-- loops

function lxml.collected(id,pattern,reverse)
    return xmlcollected(getid(id),pattern,reverse)
end

function lxml.elements(id,pattern,reverse)
    return xmlelements(getid(id),pattern,reverse)
end

-- obscure ones

lxml.info = lxml.name

-- testers

local found, empty = xml.found, xml.empty

local doif, doifnot, doifelse = commands.doif, commands.doifnot, commands.doifelse

function lxml.doif         (id,pattern) doif    (found(getid(id),pattern)) end
function lxml.doifnot      (id,pattern) doifnot (found(getid(id),pattern)) end
function lxml.doifelse     (id,pattern) doifelse(found(getid(id),pattern)) end
function lxml.doiftext     (id,pattern) doif    (not empty(getid(id),pattern)) end
function lxml.doifnottext  (id,pattern) doifnot (not empty(getid(id),pattern)) end
function lxml.doifelsetext (id,pattern) doifelse(not empty(getid(id),pattern)) end

-- special case: "*" and "" -> self else lpath lookup

--~ function lxml.doifelseempty(id,pattern) doifelse(isempty(getid(id),pattern ~= "" and pattern ~= nil)) end -- not yet done, pattern

-- status info

statistics.register("xml load time", function()
    if noffiles > 0 or nofconverted > 0 then
        return format("%s seconds, %s files, %s converted", statistics.elapsedtime(xml), noffiles, nofconverted)
    else
        return nil
    end
end)

statistics.register("lxml preparation time", function()
    local calls, cached = xml.lpathcalls(), xml.lpathcached()
    if calls > 0 or cached > 0 then
        return format("%s seconds, %s nodes, %s lpath calls, %s cached calls",
            statistics.elapsedtime(lxml), nofindices, calls, cached)
    else
        return nil
    end
end)

statistics.register("lxml lpath profile", function()
    local p = xml.profiled
    if p and next(p) then
        local s = table.sortedkeys(p)
        local tested, matched, finalized = 0, 0, 0
        texio.write_nl("log","\nbegin of lxml profile\n")
        texio.write_nl("log","\n   tested    matched  finalized    pattern\n\n")
        for i=1,#s do
            local pattern = s[i]
            local pp = p[pattern]
            local t, m, f = pp.tested, pp.matched, pp.finalized
            tested, matched, finalized = tested + t, matched + m, finalized + f
            texio.write_nl("log",format("%9i  %9i  %9i    %s",t,m,f,pattern))
        end
        texio.write_nl("log","\nend of lxml profile\n")
        return format("%s patterns, %s tested, %s matched, %s finalized (see log for details)",#s,tested,matched,finalized)
    else
        return nil
    end
end)

-- misc

function lxml.nonspace(id,pattern) -- slow, todo loop
    xmltprint(xmlcollect(getid(id),pattern,true))
end

function lxml.strip(id,pattern,nolines,anywhere)
    xml.strip(getid(id),pattern,nolines,anywhere)
end

function lxml.stripped(id,pattern,nolines)
    local str = xmltext(getid(id),pattern) or ""
    str = gsub(str,"^%s*(.-)%s*$","%1")
    if nolines then
        str = gsub(str,"%s+"," ")
    end
    xmlsprint(str)
end

function lxml.delete(id,pattern)
    xml.delete(getid(id),pattern)
end

lxml.obsolete = { }

lxml.get_id = getid   lxml.obsolete.get_id = getid

-- goodies:

function xml.finalizers.tex.lettered(collected)
    if collected then
        for c=1,#collected do
            texsprint(ctxcatcodes,lettered(collected[1].dt[1]))
        end
    end
end

--~ function xml.finalizers.tex.apply(collected,what) -- to be tested
--~     if collected then
--~         for c=1,#collected do
--~             texsprint(ctxcatcodes,what(collected[1].dt[1]))
--~         end
--~     end
--~ end

function lxml.toparameters(id)
    local e = getid(id)
    if e then
        local a = e.at
        if a and next(a) then
            local setups, s = { }, 0
            for k, v in next, a do
                s = s + 1
                setups[s] = k .. "=" .. v
            end
            setups = concat(setups,",")
            -- tracing
            context(setups)
        end
    end
end

local template = '<?xml version="1.0" ?>\n\n<!-- %s -->\n\n%s'

function lxml.tofile(id,pattern,filename,comment)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        io.savedata(filename,format(template,comment or "exported fragment",tostring(collected[1])))
    else
        os.remove(filename) -- get rid of old content
    end
end
