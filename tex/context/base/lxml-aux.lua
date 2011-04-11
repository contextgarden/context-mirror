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

local type, setmetatable, getmetatable = type, setmetatable, getmetatable
local insert, remove, fastcopy = table.insert, table.remove, table.fastcopy
local gmatch, gsub = string.gmatch, string.gsub

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
        element = xmlinheritedconvert(whatever,root)
    else
        element = whatever -- we assume a table
    end
    if element.error then
        return whatever -- string
    end
    if element then
    --~ if element.ri then
    --~     element = element.dt[element.ri].dt
    --~ else
    --~     element = element.dt
    --~ end
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
    if collected then
        for c=1,#collected do
            local e = collected[c]
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
    end
end

local function insert_element(root,pattern,whatever,before) -- todo: element als functie
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlapplylpath(root,pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local r = e.__p__
            local d, k = r.dt, e.ni
            if not before then
                k = k + 1
            end
            insert(d,k,copiedelement(element,r))
            redo_ni(d)
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
--~                 local settings = xmldata.settings
--~                 settings.parent_root = xmldata -- to be tested
--~                 local xi = xmlconvert(data,settings)
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
