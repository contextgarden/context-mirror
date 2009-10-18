if not modules then modules = { } end modules ['lxml-aux'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- not all functions here make sense anymore vbut we keep them for
-- compatibility reasons

local xmlparseapply, xmlconvert, xmlcopy = xml.parse_apply, xml.convert, xml.copy

local type = type
local insert, remove = table.insert, table.remove
local gmatch, gsub = string.gmatch, string.gsub

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

function xml.each_element(root, pattern, handle, reverse)
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

function xml.process_attributes(root, pattern, handle)
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
<p>We've now arrives at the functions that manipulate the tree.</p>
--ldx]]--

local no_root = { no_root = true }

function xml.inject_element(root, pattern, element, prepend)
    if root and element then
        if type(element) == "string" then
            element = xmlconvert(element,no_root)
        end
        if element then
            local collected = xmlparseapply({ root },pattern)
            if collected then
                for c=1,#collected do
                    local e = collected[c]
                    local r = e.__p__
                    local d = r.dt
                    local k = e.ni
                    if element.ri then
                        element = element.dt[element.ri].dt
                    else
                        element = element.dt
                    end
                    local edt
                    if r.ri then
                        edt = r.dt[r.ri].dt
                    else
                        edt = d and d[k] and d[k].dt
                    end
                    if edt then
                        local be, af
                        if prepend then
                            be, af = xmlcopy(element), edt
                        else
                            be, af = edt, xmlcopy(element)
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
end

-- todo: copy !

function xml.insert_element(root, pattern, element, before) -- todo: element als functie
    if root and element then
        if pattern == "/" then
            xml.inject_element(root, pattern, element, before)
        else
            local matches, collect = { }, nil
            if type(element) == "string" then
                element = xmlconvert(element,true)
            end
            if element and element.ri then
                element = element.dt[element.ri]
            end
            if element then
                local collected = xmlparseapply({ root },pattern)
                if collected then
                    for c=1,#collected do
                        local e = collected[c]
                        local r = e.__p__
                        local d = r.dt
                        local k = e.ni
                        if not before then
                            k = k + 1
                        end
                        if element.tg then
                            insert(d,k,element) -- untested
                        else
                            local edt = element.dt
                            if edt then
                                for i=1,#edt do
                                    insert(d,k,edt[i])
                                    k = k + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

xml.insert_element_after  =                 xml.insert_element
xml.insert_element_before = function(r,p,e) xml.insert_element(r,p,e,true) end
xml.inject_element_after  =                 xml.inject_element
xml.inject_element_before = function(r,p,e) xml.inject_element(r,p,e,true) end

function xml.delete_element(root, pattern)
    local collected = xmlparseapply({ root },pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            remove(e.__p__.dt,e.ni)
            e.ni = nil
        end
    end
    return collection
end

function xml.replace_element(root, pattern, element)
    if type(element) == "string" then
        element = xmlconvert(element,true)
    end
    if element and element.ri then
        element = element.dt[element.ri]
    end
    if element then
        local collected = xmlparseapply({ root },pattern)
        if collected then
            for c=1,#collected do
                local e = collected[c]
                e.__p__.dt[e.ni] = element.dt -- maybe not clever enough
            end
        end
    end
end

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
                local settings = xmldata.settings
                settings.parent_root = xmldata -- to be tested
                local xi = xmlconvert(data,settings)
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
