if not modules then modules = { } end modules ['strc-lst'] = {
    version   = 1.001,
    comment   = "companion to strc-lst.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when all datastructures are stable a packer will be added which will
-- bring down memory consumption a bit; we can use for instance a pagenumber,
-- section, metadata cache (internal then has to move up one level) or a
-- shared cache [we can use a fast and stupid serializer]

local format, tonumber = string.format, tonumber
local texsprint, texprint, texwrite, texcount = tex.sprint, tex.print, tex.write, tex.count

local ctxcatcodes = tex.ctxcatcodes

structure.lists     = structure.lists     or { }
structure.sections  = structure.sections  or { }
structure.helpers   = structure.helpers   or { }
structure.documents = structure.documents or { }
structure.pages     = structure.pages     or { }

local lists     = structure.lists
local sections  = structure.sections
local helpers   = structure.helpers
local documents = structure.documents
local pages     = structure.pages

lists.collected = lists.collected or { }
lists.tobesaved = lists.tobesaved or { }
lists.enhancers = lists.enhancers or { }
lists.internals = lists.internals or { }
lists.ordered   = lists.ordered   or { }

local variables = interfaces.variables

local function initializer()
    -- create a cross reference between internal references
    -- and list entries
    local collected = lists.collected
    local internals = jobreferences.internals
    local ordered   = lists.ordered
    for i=1,#collected do
        local c = collected[i]
        local m = c.metadata
        local r = c.references
        if m then
            -- access by internal reference
            local internal = r and r.internal
            if internal then
                internals[internal] = c
            end
            -- access by order in list
            local kind, name = m.kind, m.name
            if kind and name then
                local ok = ordered[kind]
                if ok then
                    local on = ok[name]
                    if on then
                        on[#on+1] = c
                    else
                        ok[name] = { c }
                    end
                else
                    ordered[kind] = { [name] = { c } }
                end
            end
        end
    end
end

if job then
    job.register('structure.lists.collected', structure.lists.tobesaved, initializer)
end

local cached = { }
local pushed = { }

function lists.push(t)
    local r = t.references
    local i = (r and r.internal) or 0 -- brrr
    local p = pushed[i]
    if not p then
        p = #cached + 1
        cached[p] = helpers.simplify(t)
        pushed[i] = p
    end
    texwrite(p)
end

function lists.doifstoredelse(n)
    commands.doifelse(cached[tonumber(n)])
end

-- this is the main pagenumber enhancer

function lists.enhance(n)
 -- todo: symbolic names for counters
    local l = cached[n]
    if l then
        --
        l.directives = nil -- might change
        -- save in the right order (happen sat shipout)
        lists.tobesaved[#lists.tobesaved+1] = l
        -- default enhancer (cross referencing)
        l.references.realpage = texcount.realpageno
        -- specific enhancer (kind of obsolete)
        local kind = l.metadata.kind
        local enhancer = kind and lists.enhancers[kind]
        if enhancer then
            enhancer(l)
        end
    end
end

-- we can use level instead but we can also decide to remove level from the metadata

-- we need level instead of cnumbers and we also need to deal with inbetween

local function filter_collected(names, criterium, number, collected)
    local numbers, depth = documents.data.numbers, documents.data.depth
    local hash, result, all = { }, { }, not names or names == "" or names == variables.all
    if not all then
        for s in names:gmatch("[^, ]+") do
            hash[s] = true
        end
    end
    if criterium == variables.all or criterium == variables.text then
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            if r then
                local sectionnumber = (r.section == 0) or jobsections.collected[r.section]
                if sectionnumber then -- and not sectionnumber.hidenumber then
                    local metadata = v.metadata
                    if metadata and not metadata.nolist and (all or hash[metadata.name or false]) then
                        result[#result+1] = v
                    end
                end
            end
        end
    elseif criterium == variables.current then
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            if r then
                local sectionnumber = jobsections.collected[r.section]
                if sectionnumber then -- and not sectionnumber.hidenumber then
                    local cnumbers = sectionnumber.numbers
                    local metadata = v.metadata
                    if cnumbers then
                        if metadata and not metadata.nolist and (all or hash[metadata.name or false]) and #cnumbers > depth then
                            local ok = true
                            for d=1,depth do
                                local cnd = cnumbers[d]
                                if not (cnd == 0 or cnd == numbers[d]) then
                                    ok = false
                                    break
                                end
                            end
                            if ok then
                                result[#result+1] = v
                            end
                        end
                    end
                end
            end
        end
    elseif criterium == variables.here then
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            if r then
                local sectionnumber = jobsections.collected[r.section]
                if sectionnumber then -- and not sectionnumber.hidenumber then
                    local cnumbers = sectionnumber.numbers
                    local metadata = v.metadata
                    if cnumbers then
                        if metadata and not metadata.nolist and (all or hash[metadata.name or false]) and #cnumbers >= depth then
                            local ok = true
                            for d=1,depth do
                                local cnd = cnumbers[d]
                                if not (cnd == 0 or cnd == numbers[d]) then
                                    ok = false
                                    break
                                end
                            end
                            if ok then
                                result[#result+1] = v
                            end
                        end
                    end
                end
            end
        end
    elseif criterium == variables.previous then
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            if r then
                local sectionnumber = jobsections.collected[r.section]
                if sectionnumber then -- and not sectionnumber.hidenumber then
                    local cnumbers = sectionnumber.numbers
                    local metadata = v.metadata
                    if cnumbers then
                        if metadata and not metadata.nolist and (all or hash[metadata.name or false]) and #cnumbers >= depth then
                            local ok = true
                            for d=1,depth-1 do
                                local cnd = cnumbers[d]
                                if not (cnd == 0 or cnd == numbers[d]) then
                                    ok = false
                                    break
                                end
                            end
                            if ok then
                                result[#result+1] = v
                            end
                        end
                    end
                end
            end
        end
    elseif criterium == variables["local"] then
        if sections.autodepth(documents.data.numbers) == 0 then
            return filter_collected(names,variables.all,number,collected)
        else
            return filter_collected(names,variables.current,number,collected)
        end
    else -- sectionname, number
        local depth = sections.getlevel(criterium)
        local number = tonumber(number) or 0
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            if r then
                local sectionnumber = jobsections.collected[r.section]
                if sectionnumber then -- and not sectionnumber.hidenumber then
                    local cnumbers = sectionnumber.numbers
                    local metadata = v.metadata
                    if cnumbers then
--                      if metadata and not metadata.nolist and (all or hash[metadata.name or false]) and #cnumbers >= depth and cnumbers[depth] == number then
                        if metadata and not metadata.nolist and (all or hash[metadata.name or false]) and #cnumbers >= depth and (number == 0 or cnumbers[depth] == number) then
                            result[#result+1] = v
                        end
                    end
                end
            end
        end
    end
    return result
end

lists.filter_collected = filter_collected

function lists.filter(names, criterium, number)
    return filter_collected(names, criterium, number, lists.collected)
end

lists.result = { }

function lists.process(...)
    lists.result = lists.filter(...)
    for i=1,#lists.result do
        local r = lists.result[i]
        local m = r.metadata
        texsprint(ctxcatcodes,format("\\processlistofstructure{%s}{%s}{%i}",m.name,m.kind,i))
    end
end

function lists.analyze(...)
    lists.result = lists.filter(...)
end

function lists.userdata(name,r,tag) -- to tex
    local str = lists.result[r]
    str = str and str.userdata
    str = str and str[tag]
    if str then
        texsprint(ctxcatcodes,str)
    end
end

function lists.uservalue(name,r,tag,default) -- to lua
    local str = lists.result[r]
    str = str and str.userdata
    str = str and str[tag]
    return str or default
end

function lists.size()
    texprint(#lists.result)
end

function lists.location(name,n)
    local l = lists.result[n]
    texsprint(l.references.internal or n)
end

function lists.sectionnumber(name,n,spec)
    local data = lists.result[n]
    local sectiondata = jobsections.collected[data.references.section]
    -- hm, prefixnumber?
    sections.typesetnumber(sectiondata,"prefix",spec,sectiondata) -- data happens to contain the spec too
end

-- some basics (todo: helpers for pages)

function lists.title(name,n,tag) -- tag becomes obsolete
    local data = lists.result[n]
    if data then
        local titledata = data.titledata
        if titledata then
            texsprint(ctxcatcodes,titledata[tag] or titledata.list or titledata.title or "")
        end
    end
end

function lists.savedtitle(name,n,tag)
    local data = cached[tonumber(n)]
    if data then
        local titledata = data.titledata
        if titledata then
            texsprint(ctxcatcodes,titledata[tag] or titledata.title or "")
        end
    end
end

function lists.savednumber(name,n)
    local data = cached[tonumber(n)]
    if data then
        local numberdata = data.numberdata
        if numberdata then
            sections.typesetnumber(numberdata,"number",numberdata or false)
        end
    end
end

function lists.savedprefixednumber(name,n)
    local data = cached[tonumber(n)]
    if data then
        helpers.prefix(data,data.prefixdata)
        local numberdata = data.numberdata
        if numberdata then
            sections.typesetnumber(numberdata,"number",numberdata or false)
        end
    end
end

function lists.prefix(name,n,spec)
    helpers.prefix(lists.result[n],spec)
end

function lists.page(name,n,pagespec)
    helpers.page(lists.result[n],pagespec)
end

function lists.prefixedpage(name,n,prefixspec,pagespec)
    helpers.prefixpage(lists.result[n],prefixspec,pagespec)
end

function lists.realpage(name,n)
    local data = lists.result[n]
    if data then
        local references = data.references
        texsprint(references and references.realpage or 0)
    else
        texsprint(0)
    end
end

-- numbers stored in entry.numberdata + entry.numberprefix

function lists.number(name,n,spec)
    local data = lists.result[n]
    if data then
        local numberdata = data.numberdata
        if numberdata then
            sections.typesetnumber(numberdata,"number",spec or false,numberdata or false)
        end
    end
end

function lists.prefixednumber(name,n,prefixspec,numberspec)
    local data = lists.result[n]
    if data then
        helpers.prefix(data,prefixspec)
        local numberdata = data.numberdata
        if numberdata then
            sections.typesetnumber(numberdata,"number",spec or false,numberdata or false)
        end
    end
end
