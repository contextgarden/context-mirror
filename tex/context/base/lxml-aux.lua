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

local report_xml = logs.new("xml")

local xmlparseapply, xmlconvert, xmlcopy, xmlname = xml.parse_apply, xml.convert, xml.copy, xml.name
local xmlinheritedconvert = xml.inheritedconvert

local type = type
local insert, remove = table.insert, table.remove
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

xml.elements_only = xml.collected

function xml.each_element(root,pattern,handle,reverse)
    local collected = xmlparseapply({ root },pattern)
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

xml.process_elements = xml.each_element

function xml.process_attributes(root,pattern,handle)
    local collected = xmlparseapply({ root },pattern)
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

function xml.collect_elements(root, pattern)
    return xmlparseapply({ root },pattern)
end

function xml.collect_texts(root, pattern, flatten) -- todo: variant with handle
    local collected = xmlparseapply({ root },pattern)
    if collected and flatten then
        local xmltostring = xml.tostring
        for c=1,#collected do
            collected[c] = xmltostring(collected[c].dt)
        end
    end
    return collected or { }
end

function xml.collect_tags(root, pattern, nonamespace)
    local collected = xmlparseapply({ root },pattern)
    if collected then
        local t = { }
        for c=1,#collected do
            local e = collected[c]
            local ns, tg = e.ns, e.tg
            if nonamespace then
                t[#t+1] = tg
            elseif ns == "" then
                t[#t+1] = tg
            else
                t[#t+1] = ns .. ":" .. tg
            end
        end
        return t
    end
end

--[[ldx--
<p>We've now arrived at the functions that manipulate the tree.</p>
--ldx]]--

local no_root = { no_root = true }

function xml.redo_ni(d)
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

function xml.delete_element(root,pattern)
    local collected = xmlparseapply({ root },pattern)
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
                xml.redo_ni(d) -- can be made faster and inlined
            end
        end
    end
end

function xml.replace_element(root,pattern,whatever)
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlparseapply({ root },pattern)
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
                xml.redo_ni(d) -- probably not needed
            end
        end
    end
end

local function inject_element(root,pattern,whatever,prepend)
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlparseapply({ root },pattern)
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
                for i=1,#af do
                    be[#be+1] = af[i]
                end
                if rri then
                    r.dt[rri].dt = be
                else
                    d[k].dt = be
                end
                xml.redo_ni(d)
            end
        end
    end
end

local function insert_element(root,pattern,whatever,before) -- todo: element als functie
    local element = root and xmltoelement(whatever,root)
    local collected = element and xmlparseapply({ root },pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local r = e.__p__
            local d, k = r.dt, e.ni
            if not before then
                k = k + 1
            end
            insert(d,k,copiedelement(element,r))
            xml.redo_ni(d)
        end
    end
end

xml.insert_element        =                 insert_element
xml.insert_element_after  =                 insert_element
xml.insert_element_before = function(r,p,e) insert_element(r,p,e,true) end
xml.inject_element        =                 inject_element
xml.inject_element_after  =                 inject_element
xml.inject_element_before = function(r,p,e) inject_element(r,p,e,true) end

local function include(xmldata,pattern,attribute,recursive,loaddata)
    -- parse="text" (default: xml), encoding="" (todo)
    -- attribute = attribute or 'href'
    pattern = pattern or 'include'
    loaddata = loaddata or io.loaddata
    local collected = xmlparseapply({ xmldata },pattern)
    if collected then
        for c=1,#collected do
            local ek = collected[c]
            local name = nil
            local ekdt = ek.dt
            local ekat = ek.at
            local epdt = ek.__p__.dt
            if not attribute or attribute == "" then
                name = (type(ekdt) == "table" and ekdt[1]) or ekdt -- ckeck, probably always tab or str
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

--~ local function manipulate(xmldata,pattern,manipulator) -- untested and might go away
--~     local collected = xmlparseapply({ xmldata },pattern)
--~     if collected then
--~         local xmltostring = xml.tostring
--~         for c=1,#collected do
--~             local e = collected[c]
--~             local data = manipulator(xmltostring(e))
--~             if data == "" then
--~                 epdt[e.ni] = ""
--~             else
--~                 local xi = xmlinheritedconvert(data,xmldata)
--~                 if not xi then
--~                     epdt[e.ni] = ""
--~                 else
--~                     epdt[e.ni] = xml.body(xi) -- xml.assign(d,k,xi)
--~                 end
--~             end
--~         end
--~     end
--~ end

--~ xml.manipulate = manipulate

function xml.strip_whitespace(root, pattern, nolines) -- strips all leading and trailing space !
    local collected = xmlparseapply({ root },pattern)
    if collected then
        for i=1,#collected do
            local e = collected[i]
            local edt = e.dt
            if edt then
                local t = { }
                for i=1,#edt do
                    local str = edt[i]
                    if type(str) == "string" then
                        if str == "" then
                            -- stripped
                        else
                            if nolines then
                                str = gsub(str,"[ \n\r\t]+"," ")
                            end
                            if str == "" then
                                -- stripped
                            else
                                t[#t+1] = str
                            end
                        end
                    else
        --~                         str.ni = i
                        t[#t+1] = str
                    end
                end
                e.dt = t
            end
        end
    end
end

function xml.strip_whitespace(root, pattern, nolines, anywhere) -- strips all leading and trailing spacing
    local collected = xmlparseapply({ root },pattern) -- beware, indices no longer are valid now
    if collected then
        for i=1,#collected do
            local e = collected[i]
            local edt = e.dt
            if edt then
                if anywhere then
                    local t = { }
                    for e=1,#edt do
                        local str = edt[e]
                        if type(str) ~= "string" then
                            t[#t+1] = str
                        elseif str ~= "" then
                            -- todo: lpeg for each case
                            if nolines then
                                str = gsub(str,"%s+"," ")
                            end
                            str = gsub(str,"^%s*(.-)%s*$","%1")
                            if str ~= "" then
                                t[#t+1] = str
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
                    if #edt > 1 then
                        -- strip end
                        local str = edt[#edt]
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
                                edt[#edt] = str
                            end
                        end
                    end
                end
            end
        end
    end
end

local function rename_space(root, oldspace, newspace) -- fast variant
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
                rename_space(edt, oldspace, newspace)
            end
        end
    end
end

xml.rename_space = rename_space

function xml.remap_tag(root, pattern, newtg)
    local collected = xmlparseapply({ root },pattern)
    if collected then
        for c=1,#collected do
            collected[c].tg = newtg
        end
    end
end

function xml.remap_namespace(root, pattern, newns)
    local collected = xmlparseapply({ root },pattern)
    if collected then
        for c=1,#collected do
            collected[c].ns = newns
        end
    end
end

function xml.check_namespace(root, pattern, newns)
    local collected = xmlparseapply({ root },pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            if (not e.rn or e.rn == "") and e.ns == "" then
                e.rn = newns
            end
        end
    end
end

function xml.remap_name(root, pattern, newtg, newns, newrn)
    local collected = xmlparseapply({ root },pattern)
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

xml.each     = xml.each_element
xml.process  = xml.process_element
xml.strip    = xml.strip_whitespace
xml.collect  = xml.collect_elements
xml.all      = xml.collect_elements

xml.insert   = xml.insert_element_after
xml.inject   = xml.inject_element_after
xml.after    = xml.insert_element_after
xml.before   = xml.insert_element_before
xml.delete   = xml.delete_element
xml.replace  = xml.replace_element
