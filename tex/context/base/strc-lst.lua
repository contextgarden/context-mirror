if not modules then modules = { } end modules ['strc-lst'] = {
    version   = 1.001,
    comment   = "companion to strc-lst.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when all datastructures are stable a packer will be added which will
-- bring down memory consumption a bit; we can use for instance a pagenumber,
-- section, metadata cache (internal then has to move up one level) or a
-- shared cache [we can use a fast and stupid serializer]

local format, gmatch, gsub = string.format, string.gmatch, string.gsub
local tonumber = tonumber
local texsprint, texprint, texwrite, texcount = tex.sprint, tex.print, tex.write, tex.count
local concat, insert, remove = table.concat, table.insert, table.remove
local lpegmatch = lpeg.match

local trace_lists = false  trackers.register("structure.lists", function(v) trace_lists = v end)

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
local matching_till_depth, number_at_depth = sections.matching_till_depth, sections.number_at_depth

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

local cached, pushed = { }, { }

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
        -- save in the right order (happens at shipout)
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

local nesting = { }

function lists.pushnesting(i)
    local r = lists.result[i]
    local name = r.metadata.name
    local numberdata = r and r.numberdata
    local n = (numberdata and numberdata.numbers[sections.getlevel(name)]) or 0
    insert(nesting, { number = n, name = name, result = lists.result, parent = r })
end

function lists.popnesting()
    local old = remove(nesting)
    lists.result = old.result
end

-- will be split

local function filter_collected(names, criterium, number, collected, nested)
    local numbers, depth = documents.data.numbers, documents.data.depth
    local hash, result, all, detail = { }, { }, not names or names == "" or names == variables.all, nil
    names, criterium = gsub(names," ",""), gsub(criterium," ","")
    if trace_lists then
        logs.report("lists","filtering names: %s, criterium: %s, number: %s",names,criterium,number or "-")
    end
    if not all then
        for s in gmatch(names,"[^, ]+") do -- sort of settings to hash
            hash[s] = true
        end
    end
    if criterium == variables.intro then
        -- special case, no structure yet
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            if r and r.section == 0 then
                result[#result+1] = v
            end
        end
    elseif criterium == variables.all or criterium == variables.text then
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
        if depth == 0 then
            return filter_collected(names,variables.intro,number,collected)
        else
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
        end
    elseif criterium == variables.here then
        -- this is quite dirty ... as cnumbers is not sparse we can misuse #cnumbers
        if depth == 0 then
            return filter_collected(names,variables.intro,number,collected)
        else
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r then
                    local sectionnumber = jobsections.collected[r.section]
                    if sectionnumber then -- and not sectionnumber.hidenumber then
                        local cnumbers = sectionnumber.numbers
                        local metadata = v.metadata
                        if cnumbers then
--~ print(#cnumbers, depth, table.concat(cnumbers))
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
        end
    elseif criterium == variables.previous then
        if depth == 0 then
            return filter_collected(names,variables.intro,number,collected)
        else
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
        end
    elseif criterium == variables["local"] then -- not yet ok
        local nested = nesting[#nesting]
        if nested then
            return filter_collected(names,nested.name,nested.number,collected,nested)
        elseif sections.autodepth(documents.data.numbers) == 0 then
            return filter_collected(names,variables.all,number,collected)
        else
            return filter_collected(names,variables.current,number,collected)
        end
    else -- sectionname, number
        -- not the same as register
        local depth = sections.getlevel(criterium)
        local number = tonumber(number) or number_at_depth(depth) or 0
        if trace_lists then
            local t = sections.numbers()
            detail = format("depth: %s, number: %s, numbers: %s, startset: %s",depth,number,(#t>0 and concat(t,".",1,depth)) or "?",#collected)
        end
        if number > 0 then
            local parent = nested and nested.parent and nested.parent.numberdata.numbers -- so local as well as nested
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r then
                    local sectionnumber = jobsections.collected[r.section]
                    if sectionnumber then
                        local metadata = v.metadata
                        local cnumbers = sectionnumber.numbers
                        if cnumbers then
                            if (all or hash[metadata.name or false]) and #cnumbers >= depth and matching_till_depth(depth,cnumbers,parent) then
                                result[#result+1] = v
                            end
                        end
                    end
                end
            end
        end
    end
    if trace_lists then
        if detail then
            logs.report("lists","criterium: %s, %s, found: %s",criterium,detail,#result)
        else
            logs.report("lists","criterium: %s, found: %s",criterium,#result)
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
--~         context.processlistofstructure(m.name,m.kind,i)
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

function lists.location(n)
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
            helpers.title(titledata[tag] or titledata.list or titledata.title or "",data.metadata)
        end
    end
end

function lists.savedtitle(name,n,tag)
    local data = cached[tonumber(n)]
    if data then
        local titledata = data.titledata
        if titledata then
            helpers.title(titledata[tag] or titledata.title or "",data.metadata)
--~             texsprint(ctxcatcodes,titledata[tag] or titledata.title or "")
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
--~ print(name,n,table.serialize(numberdata))
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
--~     print(table.serialize(numberspec))
            sections.typesetnumber(numberdata,"number",numberspec or false,numberdata or false)
        end
    end
end

-- todo, do this in references namespace ordered instead (this is an experiment)
--
-- also see lpdf-ano (maybe move this there)

local splitter = lpeg.splitat(":")

function jobreferences.specials.order(var,actions) -- jobreferences.specials !
    local operation = var.operation
    if operation then
        local kind, name, n = lpegmatch(splitter,operation)
        local order = lists.ordered[kind]
        order = order and order[name]
        local v = order[tonumber(n)]
        local r = v and v.references.realpage
        if r then
            actions.realpage = r
            var.operation = r -- brrr, but test anyway
            return jobreferences.specials.page(var,actions)
        end
    end
end
