if not modules then modules = { } end modules ['lxml-tex'] = {
    version   = 1.001,
    comment   = "companion to lxml-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Because we split and resolve entities we use the direct printing
-- interface and not the context one. If we ever do that there will
-- be an cldf-xml helper library.

local utfchar = utf.char
local concat, insert, remove = table.concat, table.insert, table.remove
local format, sub, gsub, find, gmatch, match = string.format, string.sub, string.gsub, string.find, string.gmatch, string.match
local type, next, tonumber, tostring, select = type, next, tonumber, tostring, select
local lpegmatch = lpeg.match
local P, S, C, Cc = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc

local tex, xml = tex, xml
local lowerchars, upperchars, lettered = characters.lower, characters.upper, characters.lettered

lxml = lxml or { }
local lxml = lxml

local catcodenumbers = catcodes.numbers
local ctxcatcodes    = catcodenumbers.ctxcatcodes -- todo: use different method
local notcatcodes    = catcodenumbers.notcatcodes -- todo: use different method

local context        = context
local contextsprint  = context.sprint             -- with catcodes (here we use fast variants, but with option for tracing)

local xmlelements, xmlcollected, xmlsetproperty = xml.elements, xml.collected, xml.setproperty
local xmlwithelements = xml.withelements
local xmlserialize, xmlcollect, xmltext, xmltostring = xml.serialize, xml.collect, xml.text, xml.tostring
local xmlapplylpath = xml.applylpath
local xmlunprivatized, xmlprivatetoken, xmlprivatecodes = xml.unprivatized, xml.privatetoken, xml.privatecodes

local variables = (interfaces and interfaces.variables) or { }

local insertbeforevalue, insertaftervalue = utilities.tables.insertbeforevalue, utilities.tables.insertaftervalue

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

local trace_setups   = false  trackers.register("lxml.setups",   function(v) trace_setups   = v end)
local trace_loading  = false  trackers.register("lxml.loading",  function(v) trace_loading  = v end)
local trace_access   = false  trackers.register("lxml.access",   function(v) trace_access   = v end)
local trace_comments = false  trackers.register("lxml.comments", function(v) trace_comments = v end)
local trace_entities = false  trackers.register("xml.entities",  function(v) trace_entities = v end)

local report_lxml = logs.reporter("xml","tex")
local report_xml  = logs.reporter("xml","tex")

local forceraw, rawroot = false, nil

-- tex entities
--
-- todo: unprivatize attributes

lxml.entities = lxml.entities or { }

storage.register("lxml/entities",lxml.entities,"lxml.entities")

--~ xml.placeholders.unknown_any_entity = nil -- has to be per xml

local xmlentities  = xml.entities
local texentities  = lxml.entities
local parsedentity = xml.parsedentitylpeg

function lxml.registerentity(key,value)
    texentities[key] = value
    if trace_entities then
        report_xml("registering tex entity %a as %a",key,value)
    end
end

function lxml.resolvedentity(str)
    if forceraw then
        if trace_entities then
            report_xml("passing entity %a as &%s;",str,str)
        end
        context("&%s;",str)
    else
        local e = texentities[str]
        if e then
            local te = type(e)
            if te == "function" then
                if trace_entities then
                    report_xml("passing entity %a using function",str)
                end
                e(str)
            elseif e then
                if trace_entities then
                    report_xml("passing entity %a as %a using %a",str,e,"ctxcatcodes")
                end
                context(e)
            end
            return
        end
        local e = xmlentities[str]
        if e then
            local te = type(e)
            if te == "function" then
                e = e(str)
            end
            if e then
                if trace_entities then
                    report_xml("passing entity %a as %a using %a",str,e,"notcatcodes")
                end
                contextsprint(notcatcodes,e)
                return
            end
        end
        -- resolve hex and dec, todo: escape # & etc for ctxcatcodes
        -- normally this is already solved while loading the file
        local chr, err = lpegmatch(parsedentity,str)
        if chr then
            if trace_entities then
                report_xml("passing entity %a as %a using %a",str,chr,"ctxcatcodes")
            end
            context(chr)
        elseif err then
            if trace_entities then
                report_xml("passing faulty entity %a as %a",str,err)
            end
            context(err)
        else
            local tag = upperchars(str)
            if trace_entities then
                report_xml("passing entity %a to \\xmle using tag %a",str,tag)
            end
            context.xmle(str,tag) -- we need to use our own upper
        end
    end
end

-- tex interface

lxml.loaded  = lxml.loaded or { }
local loaded = lxml.loaded

-- print(contextdirective("context-mathml-directive function reduction yes "))
-- print(contextdirective("context-mathml-directive function "))

xml.defaultprotocol = "tex"

local finalizers  = xml.finalizers

finalizers.xml = finalizers.xml or { }
finalizers.tex = finalizers.tex or { }

local xmlfinalizers = finalizers.xml
local texfinalizers = finalizers.tex

-- serialization with entity handling

local ampersand = P("&")
local semicolon = P(";")
local entity    = ampersand * C((1-semicolon)^1) * semicolon / lxml.resolvedentity -- context.bold

local _, xmltextcapture = context.newtexthandler {
    exception = entity,
    catcodes  = notcatcodes,
}

local _, xmlspacecapture = context.newtexthandler {
    endofline  = context.xmlcdataobeyedline,
    emptyline  = context.xmlcdataobeyedline,
    simpleline = context.xmlcdataobeyedline,
    space      = context.xmlcdataobeyedspace,
    exception  = entity,
    catcodes   = notcatcodes,
}

local _, xmllinecapture = context.newtexthandler {
    endofline  = context.xmlcdataobeyedline,
    emptyline  = context.xmlcdataobeyedline,
    simpleline = context.xmlcdataobeyedline,
    exception  = entity,
    catcodes   = notcatcodes,
}

local _, ctxtextcapture = context.newtexthandler {
    exception = entity,
    catcodes  = ctxcatcodes,
}

-- cdata

local toverbatim = context.newverbosehandler {
    line   = context.xmlcdataobeyedline,
    space  = context.xmlcdataobeyedspace,
    before = context.xmlcdatabefore,
    after  = context.xmlcdataafter,
}

lxml.toverbatim = context.newverbosehandler {
    line   = context.xmlcdataobeyedline,
    space  = context.xmlcdataobeyedspace,
    before = context.xmlcdatabefore,
    after  = context.xmlcdataafter,
    strip  = true,
}

-- raw flushing

function lxml.startraw()
    forceraw = true
end

function lxml.stopraw()
    forceraw = false
end

function lxml.rawroot()
    return rawroot
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
                            report_lxml("%a has no index entry %a",d,i)
                        end
                    elseif trace_access then
                        report_lxml("%a has no index",d)
                    end
                elseif trace_access then
                    report_lxml("%a is not loaded",d)
                end
            elseif trace_access then
                report_lxml("%a is not loaded",i)
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
            report_lxml("indexed entries %a, found nodes %a",tostring(name),maxindex)
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
        contextsprint(ctxcatcodes,"\\xmlw{",command,"}{",n,"}")
    else
        contextsprint(ctxcatcodes,"\\xmlw{",command,"}{",name,"::",n,"}")
    end
end

function lxml.getindex(name,n) -- will change as name is always there now
    local i, p = lpegmatch(splitter,n)
    if p then
        contextsprint(ctxcatcodes,n)
    else
        contextsprint(ctxcatcodes,name,"::",n)
    end
end

-- loading (to be redone, no overload) .. best use different methods and
-- keep raw xml (at least as option)

xml.originalload = xml.originalload or xml.load

local noffiles, nofconverted = 0, 0

function xml.load(filename,settings)
    noffiles, nofconverted = noffiles + 1, nofconverted + 1
    starttiming(xml)
    local ok, data = resolvers.loadbinfile(filename)
    settings = settings or { }
    settings.currentresource = filename
    local xmltable = xml.convert((ok and data) or "",settings)
    settings.currentresource = nil
    stoptiming(xml)
    return xmltable
end

local function entityconverter(id,str)
    return xmlentities[str] or xmlprivatetoken(str) or "" -- roundtrip handler
end

function lxml.convert(id,data,entities,compress,currentresource)
    local settings = { -- we're now roundtrip anyway
        unify_predefined_entities   = true,
        utfize_entities             = true,
        resolve_predefined_entities = true,
        resolve_entities            = function(str) return entityconverter(id,str) end, -- needed for mathml
        currentresource             = tostring(currentresource or id),
    }
    if compress and compress == variables.yes then
        settings.strip_cm_and_dt = true
    end
 -- if entities and entities == variables.yes then
 --     settings.utfize_entities = true
 --  -- settings.resolve_entities = function (str) return entityconverter(id,str) end
 -- end
    return xml.convert(data,settings)
end

function lxml.load(id,filename,compress,entities)
    filename = commands.preparedfile(filename) -- not commands!
    if trace_loading then
        report_lxml("loading file %a as %a",filename,id)
    end
    noffiles, nofconverted = noffiles + 1, nofconverted + 1
 -- local xmltable = xml.load(filename)
    starttiming(xml)
    local ok, data = resolvers.loadbinfile(filename)
    local xmltable = lxml.convert(id,(ok and data) or "",compress,entities,format("id: %s, file: %s",id,filename))
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
                report_lxml("including file %a",filename)
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
    xmltostring(lxml.convert(name,data,compress,entities,format("buffer: %s",tostring(name or "?")))) -- one buffer
end

function lxml.loadbuffer(id,name,compress,entities)
    starttiming(xml)
    nofconverted = nofconverted + 1
    local data = buffers.collectcontent(name or id) -- name can be list
    local xmltable = lxml.convert(id,data,compress,entities,format("buffer: %s",tostring(name or id or "?")))
    lxml.store(id,xmltable)
    stoptiming(xml)
    return xmltable, name or id
end

function lxml.loaddata(id,str,compress,entities)
    starttiming(xml)
    nofconverted = nofconverted + 1
    local xmltable = lxml.convert(id,str or "",compress,entities,format("id: %s",id))
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
        report_lxml("comment %a",e.dt[1])
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
             -- faster than context.xmlw
                contextsprint(ctxcatcodes,"\\xmlw{",command,"}{",rootname,"::",ix,"}")
            else
                report_lxml("fatal error: no index for %a",command)
                contextsprint(ctxcatcodes,"\\xmlw{",command,"}{",ix or 0,"}")
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
            contextsprint(ctxcatcodes,"\\xmlcontextdirective{",a,"}{",b,"}{",c,"}{",d,"}")
        end
    end
end

local function tex_pi(e,handlers)
    local str = e.dt[1]
    for i=1,#pihandlers do
        pihandlers[i](str)
    end
end

local obeycdata = true

function lxml.setcdata()
    obeycdata = true
end

function lxml.resetcdata()
    obeycdata = false
end

local function tex_cdata(e,handlers)
    if obeycdata then
        toverbatim(e.dt[1])
    end
end

local function tex_text(e)
    e = xmlunprivatized(e)
    lpegmatch(xmltextcapture,e)
end

local function ctx_text(e) -- can be just context(e) as we split there
    lpegmatch(ctxtextcapture,e)
end

local function tex_handle(...)
    contextsprint(ctxcatcodes,...) -- notcatcodes is active anyway
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

-- begin of test

local function tex_space(e)
    e = xmlunprivatized(e)
    lpegmatch(xmlspacecapture,e)
end

local xmltexspacehandler = xml.newhandlers {
    name       = "texspace",
    handle     = tex_handle,
    functions  = {
        ["@dt@"]   = tex_doctype,
        ["@el@"]   = tex_element,
        ["@pi@"]   = tex_pi,
        ["@cm@"]   = tex_comment,
        ["@cd@"]   = tex_cdata,
        ["@tx@"]   = tex_space,
    }
}

local function tex_line(e)
    e = xmlunprivatized(e)
    lpegmatch(xmllinecapture,e)
end

local xmltexlinehandler = xml.newhandlers {
    name       = "texline",
    handle     = tex_handle,
    functions  = {
        ["@dt@"]   = tex_doctype,
        ["@el@"]   = tex_element,
        ["@pi@"]   = tex_pi,
        ["@cm@"]   = tex_comment,
        ["@cd@"]   = tex_cdata,
        ["@tx@"]   = tex_line,
    }
}

function lxml.flushspacewise(id) -- keeps spaces and lines
    id = getid(id)
    local dt = id and id.dt
    if dt then
        xmlserialize(dt,xmltexspacehandler)
    end
end

function lxml.flushlinewise(id) -- keeps lines
    id = getid(id)
    local dt = id and id.dt
    if dt then
        xmlserialize(dt,xmltexlinehandler)
    end
end

-- end of test

function lxml.serialize(root)
    xmlserialize(root,xmltexhandler)
end

function lxml.setaction(id,pattern,action)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                collected[c].command = action
            end
        end
    end
end

local function sprint(root) -- check rawroot usage
    if root then
        local tr = type(root)
        if tr == "string" then -- can also be result of lpath
         -- rawroot = false -- ?
            root = xmlunprivatized(root)
            lpegmatch(xmltextcapture,root)
        elseif tr == "table" then
            if forceraw then
                rawroot = root
             -- contextsprint(ctxcatcodes,xmltostring(root)) -- goes wrong with % etc
                root = xmlunprivatized(xmltostring(root))
                lpegmatch(xmltextcapture,root) -- goes to toc
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
        root = xmlunprivatized(root)
        lpegmatch(xmltextcapture,root)
    end
end

local function cprint(root) -- content
    if not root then
     -- rawroot = false
        -- quit
    elseif type(root) == 'string' then
     -- rawroot = false
        root = xmlunprivatized(root)
        lpegmatch(xmltextcapture,root)
    else
        local rootdt = root.dt
        if forceraw then
            rawroot = root
         -- contextsprint(ctxcatcodes,xmltostring(rootdt or root))
            root = xmlunprivatized(xmltostring(root))
            lpegmatch(xmltextcapture,root) -- goes to toc
        else
            xmlserialize(rootdt or root,xmltexhandler)
        end
    end
end

xml.sprint = sprint local xmlsprint = sprint  -- calls ct mathml   -> will be replaced
xml.tprint = tprint local xmltprint = tprint  -- only used here
xml.cprint = cprint local xmlcprint = cprint  -- calls ct  mathml  -> will be replaced

-- now we can flush

function lxml.main(id)
    xmlserialize(getid(id),xmltexhandler) -- the real root (@rt@)
end

-- -- lines (untested)
--
-- local buffer = { }
--
-- local xmllinescapture = (
--     newline^2 / function()  buffer[#buffer+1] = "" end +
--     newline   / function()  buffer[#buffer] = buffer[#buffer] .. " " end +
--     content   / function(s) buffer[#buffer] = buffer[#buffer] ..  s  end
-- )^0
--
-- local xmllineshandler = table.copy(xmltexhandler)
--
-- xmllineshandler.handle = function(...) lpegmatch(xmllinescapture,concat{ ... }) end
--
-- function lines(root)
--     if not root then
--      -- rawroot = false
--      -- quit
--     elseif type(root) == 'string' then
--      -- rawroot = false
--         lpegmatch(xmllinescapture,root)
--     elseif next(root) then -- tr == 'table'
--         xmlserialize(root,xmllineshandler)
--     end
-- end
--
-- function xml.lines(root) -- used at all?
--     buffer = { "" }
--     lines(root)
--     return result
-- end

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
            report_lxml("prepending setup %a for %a",setup,document)
        end
        insert(sd,1,setup)
    elseif what == 2 then
        if trace_loading then
            report_lxml("appending setup %a for %a",setup,document)
        end
        insert(sd,setup)
    elseif what == 3 then
        if trace_loading then
            report_lxml("inserting setup %a for %a before %a",setup,document,where)
        end
        insertbeforevalue(sd,setup,where)
    elseif what == 4 then
        if trace_loading then
            report_lxml("inserting setup %a for %a after %a",setup,document,where)
        end
        insertaftervalue(sd,setup,where)
    end
end

function lxml.flushsetups(id,...)
    local done = { }
    for i=1,select("#",...) do
        local document = select(i,...)
        local sd = setups[document]
        if sd then
            for k=1,#sd do
                local v= sd[k]
                if not done[v] then
                    if trace_loading then
                        report_lxml("applying setup %02i : %a to %a",k,v,document)
                    end
                    contextsprint(ctxcatcodes,"\\xmlsetup{",id,"}{",v,"}")
                    done[v] = true
                end
            end
        elseif trace_loading then
            report_lxml("no setups for %a",document)
        end
    end
end

function lxml.resetsetups(document)
    if trace_loading then
        report_lxml("resetting all setups for %a",document)
    end
    setups[document] = { }
end

function lxml.removesetup(document,setup)
    local s = setups[document]
    if s then
        for i=1,#s do
            if s[i] == setup then
                if trace_loading then
                    report_lxml("removing setup %a for %a",setup,document)
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
            local nc = #collected
            if nc > 0 then
                if trace_setups then
                    for c=1,nc do
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
                    for c=1,nc do
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
                report_lxml("%s lpath matches for pattern: %s","zero",pattern)
            end
        elseif trace_setups then
            report_lxml("%s lpath matches for pattern: %s","no",pattern)
        end
    else
        local a, b = match(setup,"^(.+:)([%*%-])$")
        if a and b then
            local collected = xmlapplylpath(getid(id),pattern)
            if collected then
                local nc = #collected
                if nc > 0 then
                    if trace_setups then
                        for c=1,nc do
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
                        for c=1,nc do
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
                    report_lxml("%s lpath matches for pattern: %s","zero",pattern)
                end
            elseif trace_setups then
                report_lxml("%s lpath matches for pattern: %s","no",pattern)
            end
        else
            local collected = xmlapplylpath(getid(id),pattern)
            if collected then
                local nc = #collected
                if nc > 0 then
                    if trace_setups then
                        for c=1,nc do
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
                        for c=1,nc do
                            collected[c].command = setup
                        end
                    end
                elseif trace_setups then
                    report_lxml("%s lpath matches for pattern: %s","zero",pattern)
                end
            elseif trace_setups then
                report_lxml("%s lpath matches for pattern: %s","no",pattern)
            end
        end
    end
end

-- finalizers

local function first(collected)
    if collected and #collected > 0 then
        xmlsprint(collected[1])
    end
end

local function last(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            xmlsprint(collected[nc])
        end
    end
end

local function all(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                xmlsprint(collected[c])
            end
        end
    end
end

local function reverse(collected)
    if collected then
        local nc = #collected
        if nc >0 then
            for c=nc,1,-1 do
                xmlsprint(collected[c])
            end
        end
    end
end

local function count(collected)
    contextsprint(ctxcatcodes,(collected and #collected) or 0) -- why ctxcatcodes
end

local function position(collected,n)
    -- todo: if not n then == match
    if collected then
        local nc = #collected
        if nc > 0 then
            n = tonumber(n) or 0
            if n < 0 then
                n = nc + n + 1
            end
            if n > 0 then
                local cn = collected[n]
                if cn then
                    xmlsprint(cn)
                    return
                end
            end
        end
    end
end

local function match(collected) -- is match in preceding collected, never change, see bibxml
    local m = collected and collected[1]
    contextsprint(ctxcatcodes,m and m.mi or 0) -- why ctxcatcodes
end

local function index(collected,n)
    if collected then
        local nc = #collected
        if nc > 0 then
            n = tonumber(n) or 0
            if n < 0 then
                n = nc + n + 1 -- brrr
            end
            if n > 0 then
                local cn = collected[n]
                if cn then
                    contextsprint(ctxcatcodes,cn.ni or 0) -- why ctxcatcodes
                    return
                end
            end
        end
    end
    contextsprint(ctxcatcodes,0) -- why ctxcatcodes
end

local function command(collected,cmd,otherwise)
    local n = collected and #collected
    if n and n > 0 then
        local wildcard = find(cmd,"%*")
        for c=1,n do -- maybe optimize for n=1
            local e = collected[c]
            local ix = e.ix
            local name = e.name
            if not ix then
                lxml.addindex(name,false,true)
                ix = e.ix
            end
            if wildcard then
                contextsprint(ctxcatcodes,"\\xmlw{",(gsub(cmd,"%*",e.tg)),"}{",name,"::",ix,"}")
            else
                contextsprint(ctxcatcodes,"\\xmlw{",cmd,"}{",name,"::",ix,"}")
            end
        end
    elseif otherwise then
        contextsprint(ctxcatcodes,"\\xmlw{",otherwise,"}{#1}")
    end
end

local function attribute(collected,a,default)
    if collected and #collected > 0 then
        local at = collected[1].at
        local str = (at and at[a]) or default
        if str and str ~= "" then
            contextsprint(notcatcodes,str)
        end
    elseif default then
        contextsprint(notcatcodes,default)
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
                    contextsprint(notcatcodes,a)
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
        if nc == 0 then
            -- nothing
        elseif nc == 1 then -- hardly any gain so this will go
            cprint(collected[1])
        else for c=1,nc do
            cprint(collected[c])
        end end
    end
end

local function ctxtext(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                contextsprint(ctxcatcodes,collected[c].dt)
            end
        end
    end
end

local function stripped(collected) -- tricky as we strip in place
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                cprint(xml.stripelement(collected[c]))
            end
        end
    end
end

local function lower(collected)
    if not collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                contextsprint(ctxcatcodes,lowerchars(collected[c].dt[1]))
            end
        end
    end
end

local function upper(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                contextsprint(ctxcatcodes,upperchars(collected[c].dt[1]))
            end
        end
    end
end

local function number(collected)
    local nc = collected and #collected or 0
    local n = 0
    if nc > 0 then
        for c=1,nc do
            n = n + tonumber(collected[c].dt[1] or 0)
        end
    end
    contextsprint(ctxcatcodes,n)
end

local function concatrange(collected,start,stop,separator,lastseparator,textonly) -- test this on mml
    if collected then
        local nofcollected = #collected
        if nofcollected > 0 then
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
                    contextsprint(ctxcatcodes,lastseparator)
                elseif separator ~= "" then
                    contextsprint(ctxcatcodes,separator)
                end
            end
        end
    end
end

local function concat(collected,separator,lastseparator,textonly) -- test this on mml
    concatrange(collected,false,false,separator,lastseparator,textonly)
end

texfinalizers.first          = first
texfinalizers.last           = last
texfinalizers.all            = all
texfinalizers.reverse        = reverse
texfinalizers.count          = count
texfinalizers.command        = command
texfinalizers.attribute      = attribute
texfinalizers.text           = text
texfinalizers.stripped       = stripped
texfinalizers.lower          = lower
texfinalizers.upper          = upper
texfinalizers.ctxtext        = ctxtext
texfinalizers.context        = ctxtext
texfinalizers.position       = position
texfinalizers.match          = match
texfinalizers.index          = index
texfinalizers.concat         = concat
texfinalizers.concatrange    = concatrange
texfinalizers.chainattribute = chainattribute
texfinalizers.default        = all -- !!

local concat = table.concat

function texfinalizers.tag(collected,n)
    if collected then
        local nc = #collected
        if nc > 0 then
            n = tonumber(n) or 0
            local c
            if n == 0 then
                c = collected[1]
            elseif n > 1 then
                c = collected[n]
            else
                c = collected[nc-n+1]
            end
            if c then
                contextsprint(ctxcatcodes,c.tg)
            end
        end
    end
end

function texfinalizers.name(collected,n)
    if collected then
        local nc = #collected
        if nc > 0 then
            local c
            if n == 0 or not n then
                c = collected[1]
            elseif n > 1 then
                c = collected[n]
            else
                c = collected[nc-n+1]
            end
            if c then
                if c.ns == "" then
                    contextsprint(ctxcatcodes,c.tg)
                else
                    contextsprint(ctxcatcodes,c.ns,":",c.tg)
                end
            end
        end
    end
end

function texfinalizers.tags(collected,nonamespace)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                local e = collected[c]
                local ns, tg = e.ns, e.tg
                if nonamespace or ns == "" then
                    contextsprint(ctxcatcodes,tg)
                else
                    contextsprint(ctxcatcodes,ns,":",tg)
                end
            end
        end
    end
end

--

local function verbatim(id,before,after)
    local root = getid(id)
    if root then
        if before then contextsprint(ctxcatcodes,before,"[",root.tg or "?","]") end
        lxml.toverbatim(xmltostring(root.dt))
--~         lxml.toverbatim(xml.totext(root.dt))
        if after then contextsprint(ctxcatcodes,after) end
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
    if collected and #collected > 0 then
        contextsprint(notcatcodes,xmltostring(collected[1].dt))
    end
end

function lxml.context(id,pattern) -- the content, untouched by commands
    if pattern then
        local collected = xmlapplylpath(getid(id),pattern) or getid(id)
        if collected and #collected > 0 then
            contextsprint(ctxcatcodes,collected[1].dt)
        end
    else
        local collected = getid(id)
        if collected then
            local dt = collected.dt
            if #dt > 0 then
                ctx_text(dt[1])
            end
        end
    end
end

function lxml.text(id,pattern)
    local collected = (pattern and xmlapplylpath(getid(id),pattern)) or getid(id)
    if collected and #collected > 0 then
        text(collected)
    end
end

lxml.content = text

function lxml.position(id,pattern,n)
    position(xmlapplylpath(getid(id),pattern),n)
end

function lxml.chainattribute(id,pattern,a,default)
    chainattribute(xmlapplylpath(getid(id),pattern),a,default)
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
    contextsprint(ctxcatcodes,(root and root.ni) or 0)
end

function lxml.att(id,a,default)
    local root = getid(id)
    if root then
        local at = root.at
        local str = (at and at[a]) or default
        if str and str ~= "" then
            contextsprint(notcatcodes,str)
        end
    elseif default then
        contextsprint(notcatcodes,default)
    end
end

function lxml.name(id) -- or remapped name? -> lxml.info, combine
    local r = getid(id)
    local ns = r.rn or r.ns or ""
    if ns ~= "" then
        contextsprint(ctxcatcodes,ns,":",r.tg)
    else
        contextsprint(ctxcatcodes,r.tg)
    end
end

function lxml.match(id) -- or remapped name? -> lxml.info, combine
    contextsprint(ctxcatcodes,getid(id).mi or 0)
end

function lxml.tag(id) -- tag vs name -> also in l-xml tag->name
    contextsprint(ctxcatcodes,getid(id).tg or "")
end

function lxml.namespace(id) -- or remapped name?
    local root = getid(id)
    contextsprint(ctxcatcodes,root.rn or root.ns or "")
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
        local nc = #collected
        if nc > 0 then
            local rootname = p or i.name
            for c=1,nc do
                local e = collected[c]
                local ix = e.ix
                if not ix then
                    addindex(rootname,false,true)
                    ix = e.ix
                end
                contextsprint(ctxcatcodes,"\\xmlw{",cmd,"}{",rootname,"::",ix,"}")
            end
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
        logs.pushtarget("logfile")
        logs.writer("\nbegin of lxml profile\n")
        logs.writer("\n   tested    matched  finalized    pattern\n\n")
        for i=1,#s do
            local pattern = s[i]
            local pp = p[pattern]
            local t, m, f = pp.tested, pp.matched, pp.finalized
            tested, matched, finalized = tested + t, matched + m, finalized + f
            logs.writer(format("%9i  %9i  %9i    %s",t,m,f,pattern))
        end
        logs.writer("\nend of lxml profile\n")
        logs.poptarget()
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

function texfinalizers.lettered(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                contextsprint(ctxcatcodes,lettered(collected[c].dt[1]))
            end
        end
    end
end

--~ function texfinalizers.apply(collected,what) -- to be tested
--~     if collected then
--~         for c=1,#collected do
--~             contextsprint(ctxcatcodes,what(collected[c].dt[1]))
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

texfinalizers.upperall = xmlfinalizers.upperall
texfinalizers.lowerall = xmlfinalizers.lowerall
