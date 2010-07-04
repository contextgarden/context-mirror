if not modules then modules = { } end modules ['strc-reg'] = {
    version   = 1.001,
    comment   = "companion to strc-reg.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local texwrite, texsprint, texcount = tex.write, tex.sprint, tex.count
local format, gmatch, concat = string.format, string.gmatch, table.concat
local utfchar = utf.char
local lpegmatch = lpeg.match

local trace_registers = false  trackers.register("structure.registers", function(v) trace_registers = v end)

local ctxcatcodes = tex.ctxcatcodes

local variables = interfaces.variables

local helpers    = structure.helpers
local sections   = structure.sections
local documents  = structure.documents
local pages      = structure.pages
local processors = structure.processors

local mappings     = sorters.mappings
local entries      = sorters.entries
local replacements = sorters.replacements

local processor_split = processors.split

local matching_till_depth, number_at_depth = sections.matching_till_depth, sections.number_at_depth

-- some day we will share registers and lists (although there are some conceptual
-- differences in the application of keywords)

local function filter_collected(names,criterium,number,collected,prevmode)
    if not criterium or criterium == "" then criterium = variables.all end
    local data = documents.data
    local numbers, depth = data.numbers, data.depth
    local hash, result, all, detail = { }, { }, not names or names == "" or names == variables.all, nil
    if not all then
        for s in gmatch(names,"[^, ]+") do
            hash[s] = true
        end
    end
    if criterium == variables.all or criterium == variables.text then
        for i=1,#collected do
            local v = collected[i]
            if all then
                result[#result+1] = v
            else
                local vmn = v.metadata and v.metadata.name
                if hash[vmn] then
                    result[#result+1] = v
                end
            end
        end
    elseif criterium == variables.current then
        for i=1,#collected do
            local v = collected[i]
            local sectionnumber = jobsections.collected[v.references.section]
            if sectionnumber then
                local cnumbers = sectionnumber.numbers
                if prevmode then
                    if (all or hash[v.metadata.name]) and #cnumbers >= depth then -- is the = ok for lists as well?
                        local ok = true
                        for d=1,depth do
                            if not (cnumbers[d] == numbers[d]) then -- no zero test
                                ok = false
                                break
                            end
                        end
                        if ok then
                            result[#result+1] = v
                        end
                    end
                else
                    if (all or hash[v.metadata.name]) and #cnumbers > depth then
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
    elseif criterium == variables.previous then
        for i=1,#collected do
            local v = collected[i]
            local sectionnumber = jobsections.collected[v.references.section]
            if sectionnumber then
                local cnumbers = sectionnumber.numbers
                if (all or hash[v.metadata.name]) and #cnumbers >= depth then
                    local ok = true
                    if prevmode then
                        for d=1,depth do
                            if not (cnumbers[d] == numbers[d]) then
                                ok = false
                                break
                            end
                        end
                    else
                        for d=1,depth do
                            local cnd = cnumbers[d]
                            if not (cnd == 0 or cnd == numbers[d]) then
                                ok = false
                                break
                            end
                        end
                    end
                    if ok then
                        result[#result+1] = v
                    end
                end
            end
        end
    elseif criterium == variables["local"] then
        if sections.autodepth(data.numbers) == 0 then
            return filter_collected(names,variables.all,number,collected,prevmode)
        else
            return filter_collected(names,variables.current,number,collected,prevmode)
        end
    else -- sectionname, number
        -- beware, this works ok for registers
        local depth = sections.getlevel(criterium)
        local number = tonumber(number) or number_at_depth(depth) or 0
        if trace_registers then
            detail = format("depth: %s, number: %s, numbers: %s, startset: %s",depth,number,concat(sections.numbers(),".",1,depth),#collected)
        end
        if number > 0 then
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r then
                    local sectionnumber = jobsections.collected[r.section]
                    if sectionnumber then
                        local metadata = v.metadata
                        local cnumbers = sectionnumber.numbers
                        if cnumbers then
                            if (all or hash[metadata.name or false]) and #cnumbers >= depth and matching_till_depth(depth,cnumbers) then
                                result[#result+1] = v
                            end
                        end
                    end
                end
            end
        end
    end
    if trace_registers then
        if detail then
            logs.report("registers","criterium: %s, %s, found: %s",criterium,detail,#result)
        else
            logs.report("registers","criterium: %s, found: %s",criterium,#result)
        end
    end
    return result
end

jobregisters           = jobregisters or { }
jobregisters.collected = jobregisters.collected or { }
jobregisters.tobesaved = jobregisters.tobesaved or { }

jobregisters.filter_collected = filter_collected

-- we follow a different strategy than by lists, where we have a global
-- result table; we might do that here as well but since sorting code is
-- older we delay that decision

local tobesaved, collected = jobregisters.tobesaved, jobregisters.collected

local function initializer()
    tobesaved, collected = jobregisters.tobesaved, jobregisters.collected
    local internals = jobreferences.internals
    for name, list in next, collected do
        local entries = list.entries
        for e=1,#entries do
            local entry = entries[e]
            local r = entry.references
            if r then
                local internal = r and r.internal
                if internal then
                    internals[internal] = entry
                end
            end
        end
    end
end

job.register('jobregisters.collected', jobregisters.tobesaved, initializer)

local function allocate(class)
    local d = tobesaved[class]
    if not d then
        d = {
            metadata = {
                language = 'en',
                sorted   = false,
                class    = class
            },
            entries  = { },
        }
        tobesaved[class] = d
    end
    return d
end

jobregisters.define = allocate

local entrysplitter = lpeg.Ct(lpeg.splitat('+')) -- & obsolete in mkiv

local tagged = { }

local function preprocessentries(rawdata)
    local entries = rawdata.entries
    if entries then
        local e, k = entries[1] or "", entries[2] or ""
        local et, kt, entryproc, pageproc
        if type(e) == "table" then
            et = e
        else
            entryproc, e = processor_split(e)
            et = lpegmatch(entrysplitter,e)
        end
        if type(k) == "table" then
            kt = e
        else
            pageproc, k = processor_split(k)
            kt = lpegmatch(entrysplitter,k)
        end
        entries = { }
        for k=1,#et do
            entries[k] = { et[k] or "", kt[k] or "" }
        end
        for k=#et,1,-1 do
            if entries[k][1] ~= "" then
                break
            else
                entries[k] = nil
            end
        end
        rawdata.list = entries
        if pageproc or entryproc then
            rawdata.processors = { entryproc, pageproc }
        end
        rawdata.entries = nil
    else
        rawdata.list = { { "", "" } } -- br
    end
end

function jobregisters.store(rawdata) -- metadata, references, entries
    local data = allocate(rawdata.metadata.name).entries
    local references = rawdata.references
    references.realpage = references.realpage or 0 -- just to be sure as it can be refered to
    preprocessentries(rawdata)
    data[#data+1] = rawdata
    local label = references.label
    if label and label ~= "" then tagged[label] = #data end
    texwrite(#data)
end

function jobregisters.enhance(name,n)
    local r = tobesaved[name].entries[n]
    if r then
        r.references.realpage = texcount.realpageno
    end
end

function jobregisters.extend(name,tag,rawdata) -- maybe do lastsection internally
    if type(tag) == "string" then
        tag = tagged[tag]
    end
    if tag then
        local r = tobesaved[name].entries[tag]
        if r then
            local rr = r.references
            rr.lastrealpage = texcount.realpageno
            rr.lastsection = structure.sections.currentid()
            if rawdata then
                preprocessentries(rawdata)
                for k,v in next, rawdata do
                    if not r[k] then
                        r[k] = v
                    else
                        local rk = r[k]
                        for kk,vv in next, v do
                            if vv ~= "" then
                                rk[kk] = vv
                            end
                        end
                    end
                end
            end
        end
    end
end

-- sorting and rendering

local compare = sorters.comparers.basic

function jobregisters.compare(a,b)
    local result = compare(a,b)
    if result ~= 0 then
        return result
    elseif a.metadata.kind == 'entry' then -- e/f/t
        local page_a, page_b = a.references.realpage, b.references.realpage
        if not page_a or not page_b then
            return 0
        elseif page_a < page_b then
            return -1
        elseif page_a > page_b then
            return  1
        end
    end
    return 0
end

function jobregisters.filter(data,options)
    data.result = jobregisters.filter_collected(nil,options.criterium,options.number,data.entries,true)
end

function jobregisters.prepare(data)
    -- data has 'list' table
    local strip = sorters.strip
    local splitter = sorters.splitters.utf
    local result = data.result
    if result then
        for i=1, #result do
            local entry, split = result[i], { }
            local list = entry.list
            if list then
                for l=1,#list do
                    local ll = list[l]
                    local word, key = ll[1], ll[2]
                    if not key or key == "" then
                        key = word
                    end
                    split[l] = splitter(strip(key))
                end
            end
            entry.split = split
        end
    end
end

function jobregisters.sort(data,options)
    sorters.sort(data.result,jobregisters.compare)
end

function jobregisters.unique(data,options)
    local result, prev, equal = { }, nil, table.are_equal
    local dataresult = data.result
    for k=1,#dataresult do
        local v = dataresult[k]
        if not prev then
            result[#result+1], prev = v, v
        else
            local pr, vr = prev.references, v.references
            if not equal(prev.list,v.list) then
                result[#result+1], prev = v, v
            elseif pr.realpage ~= vr.realpage then
                result[#result+1], prev = v, v
            else
                local pl, vl = pr.lastrealpage, vr.lastrealpage
                if pl or vl then
                    if not vl then
                        result[#result+1], prev = v, v
                    elseif not pl then
                        result[#result+1], prev = v, v
                    elseif pl ~= vl then
                        result[#result+1], prev = v, v
                    end
                end
            end
        end
    end
    data.result = result
end

function jobregisters.finalize(data,options)
    local result = data.result
    data.metadata.nofsorted = #result
    local split, lasttag, s, d = { }, nil, nil, nil
    -- maps character to index (order)
    for k=1,#result do
        local v = result[k]
        local entry, tag = sorters.firstofsplit(v)
        if tag ~= lasttag then
            if trace_registers then
                logs.report("registers","splitting at %s",tag)
            end
            d = { }
            s = { tag = tag, data = d }
            split[#split+1] = s
            lasttag = tag
        end
        d[#d+1] = v
    end
    data.result = split
end

function jobregisters.analysed(class,options)
    local data = collected[class]
    if data and data.entries then
        options = options or { }
        sorters.setlanguage(options.language)
        jobregisters.filter(data,options)   -- filter entries into results (criteria)
        jobregisters.prepare(data,options)  -- adds split table parallel to list table
        jobregisters.sort(data,options)     -- sorts results
        jobregisters.unique(data,options)   -- get rid of duplicates
        jobregisters.finalize(data,options) -- split result in ranges
        data.metadata.sorted = true
        return data.metadata.nofsorted or 0
    else
        return 0
    end
end

-- todo take conversion from index

function jobregisters.userdata(index,name)
    local data = jobreferences.internals[tonumber(index)]
    data = data and data.userdata and data.userdata[name]
    if data then
        texsprint(ctxcatcodes,data)
    end
end

-- proc can be wrapped

function jobregisters.flush(data,options,prefixspec,pagespec)
    local equal = table.are_equal
    texsprint(ctxcatcodes,"\\startregisteroutput")
    local collapse_singles = options.compress == interfaces.variables.yes
    local collapse_ranges  = options.compress == interfaces.variables.all
    local result = data.result
    -- todo ownnumber
    local function pagenumber(entry)
        local er = entry.references
        texsprint(ctxcatcodes,format("\\registeronepage{%s}{%s}{",er.internal or 0,er.realpage or 0)) -- internal realpage content
        local proc = entry.processors and entry.processors[2]
        if proc then
            texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{")
            helpers.prefixpage(entry,prefixspec,pagespec)
            texsprint(ctxcatcodes,"}")
        else
            helpers.prefixpage(entry,prefixspec,pagespec)
        end
        texsprint(ctxcatcodes,"}")
    end
    local function pagerange(f_entry,t_entry,is_last)
        local er = f_entry.references
        texsprint(ctxcatcodes,format("\\registerpagerange{%s}{%s}{",er.internal or 0,er.realpage or 0))
        local proc = f_entry.processors and f_entry.processors[2]
        if proc then
            texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{")
            helpers.prefixpage(f_entry,prefixspec,pagespec)
            texsprint(ctxcatcodes,"}")
        else
            helpers.prefixpage(f_entry,prefixspec,pagespec)
        end
        local er = t_entry.references
        texsprint(ctxcatcodes,format("}{%s}{%s}{",er.internal or 0,er.lastrealpage or er.realpage or 0))
        if is_last then
            if proc then
                texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{")
                helpers.prefixlastpage(t_entry,prefixspec,pagespec) -- swaps page and realpage keys
                texsprint(ctxcatcodes,"}")
            else
                helpers.prefixlastpage(t_entry,prefixspec,pagespec) -- swaps page and realpage keys
            end
        else
            if proc then
                texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{")
                helpers.prefixpage(t_entry,prefixspec,pagespec)
                texsprint(ctxcatcodes,"}")
            else
                helpers.prefixpage(t_entry,prefixspec,pagespec)
            end
        end
        texsprint(ctxcatcodes,"}")
    end
    -- ranges need checking !
    for i=1,#result do
        local sublist = result[i]
        local done = { false, false, false, false }
        local data = sublist.data
        local d, n = 0, 0
        texsprint(ctxcatcodes,format("\\startregistersection{%s}",sublist.tag))
        while d < #data do
            d = d + 1
            local entry = data[d]
            local e = { false, false, false, false }
            local metadata = entry.metadata
            for i=1,4 do -- max 4
                if entry.list[i] then
                    e[i] = entry.list[i][1]
                end
                if e[i] ~= done[i] then
                    if e[i] and e[i] ~= "" then
                        done[i] = e[i]
                        if n == i then
                            texsprint(ctxcatcodes,format("\\stopregisterentries\\startregisterentries{%s}",n))
                        else
                            while n > i do
                                n = n - 1
                                texsprint(ctxcatcodes,"\\stopregisterentries")
                            end
                            while n < i do
                                n = n + 1
                                texsprint(ctxcatcodes,format("\\startregisterentries{%s}",n))
                            end
                        end
                        if metadata then
                            texsprint(ctxcatcodes,"\\registerentry{")
                            local proc = entry.processors and entry.processors[1]
                            if proc then
                                texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{")
                                helpers.title(e[i],metadata)
                                texsprint(ctxcatcodes,"}")
                            else
                                helpers.title(e[i],metadata)
                            end
                            texsprint(ctxcatcodes,"}")
                        else
                            local proc = entry.processors and entry.processors[1]
                            if proc then
                                texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{")
                                texsprint(ctxcatcodes,format("\\registerentry{%s}",e[i]))
                                texsprint(ctxcatcodes,"}")
                            else
                                texsprint(ctxcatcodes,format("\\registerentry{%s}",e[i]))
                            end
                        end
                    else
                        done[i] = false
                    end
                end
            end
            local kind = entry.metadata.kind
            if kind == 'entry' then
                texsprint(ctxcatcodes,"\\startregisterpages")
            --~ collapse_ranges = true
                if collapse_singles or collapse_ranges then
                    -- we collapse ranges and keep existing ranges as they are
                    -- so we get prebuilt as well as built ranges
                    local first, last, prev = entry, nil, entry
                    local pages = { }
                    local dd = d
                    while dd < #data do
                        dd = dd + 1
                        local next = data[dd]
                        local el, nl = entry.list, next.list
                        if not equal(el,nl) then
                            dd = dd - 1
                        --~ first = nil
                            break
                        elseif next.references.lastrealpage then
                            if first then
                                pages[#pages+1] = { first, last or first }
                            else
                                pages[#pages+1] = { entry, entry }
                            end
                            pages[#pages+1] = { next, next }
                            first, last, prev = nil, nil, nil
                        elseif not first then
                            first, prev = next, next
                        elseif next.references.realpage - prev.references.realpage == 1 then -- 1 ?
                            last, prev = next, next
                        else
                            pages[#pages+1] = { first, last or first }
                            first, last, prev = next, nil, next
                        end
                    end
                    if first then
                        pages[#pages+1] = { first, last or first }
                    end
                    if collapse_ranges and #pages > 1 then
                        -- ok, not that efficient
                        local function doit()
                            local function bubble(i)
                                for j=i,#pages-1 do
                                    pages[j] = pages[j+1]
                                end
                                pages[#pages] = nil
                            end
                            for i=2,#pages do
                                local first, second = pages[i-1], pages[i]
                                local first_first, first_last, second_first, second_last = first[1], first[2], second[1], second[2]
                                local first_last_pn     = first_last  .references.realpage
                                local second_first_pn   = second_first.references.realpage
                                local second_last_pn    = second_last .references.realpage
                                local first_last_last   = first_last  .references.lastrealpage
                                local second_first_last = second_first.references.lastrealpage
                                if first_last_last then
                                    first_last_pn = first_last_last
                                    if second_first == second_last and second_first_pn <= first_last_pn then
                                        -- 2=8, 5 -> 12=8
                                        bubble(i)
                                        return true
                                    elseif second_first == second_last and second_first_pn > first_last_pn then
                                        -- 2=8, 9 -> 2-9
                                        pages[i-1] = { first_first, second_last }
                                        bubble(i)
                                        return true
                                    elseif second_last_pn < first_last_pn then
                                        -- 2=8, 3-4 -> 2=8
                                        bubble(i)
                                        return true
                                    elseif first_last_pn < second_last_pn then
                                        -- 2=8, 3-9 -> 2-9
                                        pages[i-1] = { first_first, second_last }
                                        bubble(i)
                                        return true
                                    elseif first_last_pn + 1 == second_first_pn and second_last_pn > first_last_pn then
                                        -- 2=8, 9-11 -> 2-11
                                        pages[i-1] = { first_first, second_last }
                                        bubble(i)
                                        return true
                                    elseif second_first.references.lastrealpage then
                                        -- 2=8, 9=11 -> 2-11
                                        pages[i-1] = { first_first, second_last }
                                        bubble(i)
                                        return true
                                    end
                                elseif second_first_last then
                                    second_first_pn = second_first_last
                                    if first_last_pn == second_first_pn then
                                        -- 2-4, 5=9 -> 2-9
                                        pages[i-1] = { first_first, second_last }
                                        bubble(i)
                                        return true
                                    end
                                elseif first_last_pn == second_first_pn then
                                    -- 2-3, 3-4 -> 2-4
                                    pages[i-1] = { first_last, second_last }
                                    bubble(i)
                                    return true
                                end
                            end
                            return false
                        end
                        while doit() do end
                    end
                    --
                    if #pages > 0 then -- or 0
                        d = dd
                        for p=1,#pages do
                            local first, last = pages[p][1], pages[p][2]
                            if first == last then
                                if first.references.lastrealpage then
                                    pagerange(first,first,true)
                                else
                                    pagenumber(first)
                                end
                            elseif last.references.lastrealpage then
                                pagerange(first,last,true)
                            else
                                pagerange(first,last,false)
                            end
                        end
                    else
                        if entry.references.lastrealpage then
                            pagerange(entry,entry,true)
                        else
                            pagenumber(entry)
                        end
                    end
                else
                    while true do
                        if entry.references.lastrealpage then
                            pagerange(entry,entry,true)
                        else
                            pagenumber(entry)
                        end
                        if d == #data then
                            break
                        else
                            d = d + 1
                            local next = data[d]
                            if not equal(entry.list,next.list) then
                                d = d - 1
                                break
                            else
                                entry = next
                            end
                        end
                    end
                end
                texsprint(ctxcatcodes,"\\stopregisterpages")
            elseif kind == 'see' then
                -- maybe some day more words
                texsprint(ctxcatcodes,"\\startregisterseewords")
                local proc = entry.processors and entry.processors[1]
                if proc then
                    texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{")
                    texsprint(ctxcatcodes,format("\\registeroneword{0}{0}{%s}",entry.seeword.text)) -- todo: internal
                    texsprint(ctxcatcodes,"}")
                else
                    texsprint(ctxcatcodes,format("\\registeroneword{0}{0}{%s}",entry.seeword.text)) -- todo: internal
                end
                texsprint(ctxcatcodes,"\\stopregisterseewords")
            end
        end
        while n > 0 do
            texsprint(ctxcatcodes,"\\stopregisterentries")
            n = n - 1
        end
        texsprint(ctxcatcodes,"\\stopregistersection")
    end
    texsprint(ctxcatcodes,"\\stopregisteroutput")
    -- for now, maybe at some point we will do a multipass or so
    data.result = nil
    data.metadata.sorted = false
end

function jobregisters.analyse(class,options)
    texwrite(jobregisters.analysed(class,options))
end

function jobregisters.process(class,...)
    if jobregisters.analysed(class,...) > 0 then
        jobregisters.flush(collected[class],...)
    end
end
