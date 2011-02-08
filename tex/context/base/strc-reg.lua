if not modules then modules = { } end modules ['strc-reg'] = {
    version   = 1.001,
    comment   = "companion to strc-reg.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local texwrite, texcount = tex.write, tex.count
local format, gmatch = string.format, string.gmatch
local equal, concat, remove = table.are_equal, table.concat, table.remove
local utfchar = utf.char
local lpegmatch = lpeg.match
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local trace_registers = false  trackers.register("structures.registers", function(v) trace_registers = v end)

local report_registers = logs.reporter("structure","registers")

local structures      = structures
local registers       = structures.registers
local helpers         = structures.helpers
local sections        = structures.sections
local documents       = structures.documents
local pages           = structures.pages
local processors      = structures.processors
local references      = structures.references

local mappings        = sorters.mappings
local entries         = sorters.entries
local replacements    = sorters.replacements

local processor_split = processors.split

local variables       = interfaces.variables
local context         = context

local matchingtilldepth, numberatdepth = sections.matchingtilldepth, sections.numberatdepth

-- some day we will share registers and lists (although there are some conceptual
-- differences in the application of keywords)

local function filtercollected(names,criterium,number,collected,prevmode)
    if not criterium or criterium == "" then criterium = variables.all end
    local data = documents.data
    local numbers, depth = data.numbers, data.depth
    local hash, result, nofresult, all, detail = { }, { }, 0, not names or names == "" or names == variables.all, nil
    if not all then
        for s in gmatch(names,"[^, ]+") do
            hash[s] = true
        end
    end
    if criterium == variables.all or criterium == variables.text then
        for i=1,#collected do
            local v = collected[i]
            if all then
                nofresult = nofresult + 1
                result[nofresult] = v
            else
                local vmn = v.metadata and v.metadata.name
                if hash[vmn] then
                    nofresult = nofresult + 1
                    result[nofresult] = v
                end
            end
        end
    elseif criterium == variables.current then
        for i=1,#collected do
            local v = collected[i]
            local sectionnumber = sections.collected[v.references.section]
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
                            nofresult = nofresult + 1
                            result[nofresult] = v
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
                            nofresult = nofresult + 1
                            result[nofresult] = v
                        end
                    end
                end
            end
        end
    elseif criterium == variables.previous then
        for i=1,#collected do
            local v = collected[i]
            local sectionnumber = sections.collected[v.references.section]
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
                        nofresult = nofresult + 1
                        result[nofresult] = v
                    end
                end
            end
        end
    elseif criterium == variables["local"] then
        if sections.autodepth(data.numbers) == 0 then
            return filtercollected(names,variables.all,number,collected,prevmode)
        else
            return filtercollected(names,variables.current,number,collected,prevmode)
        end
    else -- sectionname, number
        -- beware, this works ok for registers
        local depth = sections.getlevel(criterium)
        local number = tonumber(number) or numberatdepth(depth) or 0
        if trace_registers then
            detail = format("depth: %s, number: %s, numbers: %s, startset: %s",depth,number,concat(sections.numbers(),".",1,depth),#collected)
        end
        if number > 0 then
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r then
                    local sectionnumber = sections.collected[r.section]
                    if sectionnumber then
                        local metadata = v.metadata
                        local cnumbers = sectionnumber.numbers
                        if cnumbers then
                            if (all or hash[metadata.name or false]) and #cnumbers >= depth and matchingtilldepth(depth,cnumbers) then
                                nofresult = nofresult + 1
                                result[nofresult] = v
                            end
                        end
                    end
                end
            end
        end
    end
    if trace_registers then
        if detail then
            report_registers("criterium: %s, %s, found: %s",criterium,detail,#result)
        else
            report_registers("criterium: %s, found: %s",criterium,#result)
        end
    end
    return result
end

local tobesaved, collected = allocate(), allocate()

registers.collected = collected
registers.tobesaved = tobesaved

registers.filtercollected = filtercollected

-- we follow a different strategy than by lists, where we have a global
-- result table; we might do that here as well but since sorting code is
-- older we delay that decision

local function initializer()
    tobesaved = mark(registers.tobesaved)
    collected = mark(registers.collected)
    local internals = references.internals
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

job.register('structures.registers.collected', tobesaved, initializer)

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

registers.define = allocate

local entrysplitter = lpeg.Ct(lpeg.splitat('+')) -- & obsolete in mkiv

local tagged = { }

local function preprocessentries(rawdata)
    local entries = rawdata.entries
    if entries then
--~ table.print(rawdata)
        local e, k = entries[1] or "", entries[2] or ""
        local et, kt, entryproc, pageproc
        if type(e) == "table" then
            et = e
        else
            entryproc, e = processor_split(e)
            et = lpegmatch(entrysplitter,e)
        end
        if type(k) == "table" then
            kt = k
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
    end
end

function registers.store(rawdata) -- metadata, references, entries
    local data = allocate(rawdata.metadata.name).entries
    local references = rawdata.references
    references.realpage = references.realpage or 0 -- just to be sure as it can be refered to
    preprocessentries(rawdata)
    data[#data+1] = rawdata
    local label = references.label
    if label and label ~= "" then tagged[label] = #data end
    texwrite(#data)
end

function registers.enhance(name,n)
    local r = tobesaved[name].entries[n]
    if r then
        r.references.realpage = texcount.realpageno
    end
end

function registers.extend(name,tag,rawdata) -- maybe do lastsection internally
    if type(tag) == "string" then
        tag = tagged[tag]
    end
    if tag then
        local r = tobesaved[name].entries[tag]
        if r then
            local rr = r.references
            rr.lastrealpage = texcount.realpageno
            rr.lastsection = sections.currentid()
            if rawdata then
                if rawdata.entries then
                    preprocessentries(rawdata)
                end
                for k,v in next, rawdata do
                    if not r[k] then
                        r[k] = v
                    else
                        local rk = r[k]
                        for kk,vv in next, v do
                            if type(vv) == "table" then
                                if next(vv) then
                                    rk[kk] = vv
                                end
                            elseif vv ~= "" then
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

function registers.compare(a,b)
    local result = compare(a,b)
    if result ~= 0 then
        return result
    else
        local ka, kb = a.metadata.kind, b.metadata.kind
        if ka == kb then
            local page_a, page_b = a.references.realpage, b.references.realpage
            if not page_a or not page_b then
                return 0
            elseif page_a < page_b then
                return -1
            elseif page_a > page_b then
                return  1
            end
        elseif ka == "see" then
            return 1
        elseif kb == "see" then
            return -1
        end
    end
    return 0
end

function registers.filter(data,options)
    data.result = registers.filtercollected(nil,options.criterium,options.number,data.entries,true)
end

local seeindex = 0

-- meerdere loops, seewords, dan words, an seewords

local function crosslinkseewords(result) -- all words
    -- collect all seewords
    local seewords = { }
    for i=1,#result do
        local data = result[i]
        local seeword = data.seeword
        if seeword then
            local seetext = seeword.text
            if seetext and not seewords[seetext] then
                seeindex = seeindex + 1
                seewords[seetext] = seeindex
                if trace_registers then
                    report_registers("see word %03i: %s",seeindex,seetext)
                end
            end
        end
    end
    -- mark seeparents
    local seeparents = { }
    for i=1,#result do
        local data = result[i]
        local word = data.list[1]
        word = word and word[1]
        if word then
            local seeindex = seewords[word]
            if seeindex then
                seeparents[word] = data
                data.references.seeparent = seeindex
                if trace_registers then
                    report_registers("see parent %03i: %s",seeindex,word)
                end
            end
        end
    end
    -- mark seewords and extend sort list
    for i=1,#result do
        local data = result[i]
        local seeword = data.seeword
        if seeword then
            local text = seeword.text
            if text then
                local seeparent = seeparents[text]
                if seeparent then
                    local seeindex = seewords[text]
                    local s, ns, d, w, l = { }, 0, data.split, seeparent.split, data.list
                    -- trick: we influence sorting by adding fake subentries
                    for i=1,#d do
                        ns = ns + 1
                        s[ns] = d[i] -- parent
                    end
                    for i=1,#w do
                        ns = ns + 1
                        s[ns] = w[i] -- see
                    end
                    data.split = s
                    -- we also register a fake extra list entry so that the
                    -- collapser works okay
                    l[#l+1] = { text, "" }
                    data.references.seeindex = seeindex
                    if trace_registers then
                        report_registers("see crosslink %03i: %s",seeindex,text)
                    end
                end
            end
        end
    end
end

local function removeemptyentries(result)
    local i, n, m = 1, #result, 0
    while i <= n do
        local entry = result[i]
        if #entry.list == 0 or #entry.split == 0 then
            remove(result,i)
            n = n - 1
            m = m + 1
        else
            i = i + 1
        end
    end
    if m > 0 then
        report_registers("%s empty entries removed in register",m)
    end
end

function registers.prepare(data)
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
        removeemptyentries(result)
        crosslinkseewords(result)
    end
end

function registers.sort(data,options)
    sorters.sort(data.result,registers.compare)
end

function registers.unique(data,options)
    local result, nofresult, prev = { }, 0, nil
    local dataresult = data.result
    for k=1,#dataresult do
        local v = dataresult[k]
        if prev then
            local pr, vr = prev.references, v.references
            if not equal(prev.list,v.list) then
                -- ok
            elseif pr.realpage ~= vr.realpage then
                -- ok
            else
                local pl, vl = pr.lastrealpage, vr.lastrealpage
                if pl or vl then
                    if not vl then
                        -- ok
                    elseif not pl then
                        -- ok
                    elseif pl ~= vl then
                        -- ok
                    else
                        v = nil
                    end
                else
                    v = nil
                end
            end
        end
        if v then
            nofresult = nofresult + 1
            result[nofresult] = v
            prev = v
        end
    end
    data.result = result
end

function registers.finalize(data,options) -- maps character to index (order)
    local result = data.result
    data.metadata.nofsorted = #result
    local split, nofsplit, lasttag, done, nofdone = { }, 0, nil, nil, 0
    local firstofsplit = sorters.firstofsplit
    for k=1,#result do
        local v = result[k]
        local entry, tag = firstofsplit(v)
        if tag ~= lasttag then
            if trace_registers then
                report_registers("splitting at %s",tag)
            end
            done, nofdone = { }, 0
            nofsplit = nofsplit + 1
            split[nofsplit] = { tag = tag, data = done }
            lasttag = tag
        end
        nofdone = nofdone + 1
        done[nofdone] = v
    end
    data.result = split
end

function registers.analyzed(class,options)
    local data = collected[class]
    if data and data.entries then
        options = options or { }
        sorters.setlanguage(options.language,options.method,options.numberorder)
        registers.filter(data,options)   -- filter entries into results (criteria)
        registers.prepare(data,options)  -- adds split table parallel to list table
        registers.sort(data,options)     -- sorts results
        registers.unique(data,options)   -- get rid of duplicates
        registers.finalize(data,options) -- split result in ranges
        data.metadata.sorted = true
        return data.metadata.nofsorted or 0
    else
        return 0
    end
end

-- todo take conversion from index

function registers.userdata(index,name)
    local data = references.internals[tonumber(index)]
    data = data and data.userdata and data.userdata[name]
    if data then
        context(data)
    end
end

-- todo: ownnumber

local function pagerange(f_entry,t_entry,is_last,prefixspec,pagespec)
    local fer, ter = f_entry.references, t_entry.references
    context.registerpagerange(
        f_entry.processors and f_entry.processors[2] or "",
        fer.internal or 0,
        fer.realpage or 0,
        function()
            helpers.prefixpage(f_entry,prefixspec,pagespec)
        end,
        ter.internal or 0,
        ter.lastrealpage or ter.realpage or 0,
        function()
            if is_last then
                helpers.prefixlastpage(t_entry,prefixspec,pagespec) -- swaps page and realpage keys
            else
                helpers.prefixpage    (t_entry,prefixspec,pagespec)
            end
        end
    )
end

local function pagenumber(entry,prefixspec,pagespec)
    local er = entry.references
    context.registeronepage(
        entry.processors and entry.processors[2] or "",
        er.internal or 0,
        er.realpage or 0,
        function() helpers.prefixpage(entry,prefixspec,pagespec) end
    )
end

local function collapsedpage(pages)
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
                remove(pages,i)
                return true
            elseif second_first == second_last and second_first_pn > first_last_pn then
                -- 2=8, 9 -> 2-9
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            elseif second_last_pn < first_last_pn then
                -- 2=8, 3-4 -> 2=8
                remove(pages,i)
                return true
            elseif first_last_pn < second_last_pn then
                -- 2=8, 3-9 -> 2-9
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            elseif first_last_pn + 1 == second_first_pn and second_last_pn > first_last_pn then
                -- 2=8, 9-11 -> 2-11
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            elseif second_first.references.lastrealpage then
                -- 2=8, 9=11 -> 2-11
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            end
        elseif second_first_last then
            second_first_pn = second_first_last
            if first_last_pn == second_first_pn then
                -- 2-4, 5=9 -> 2-9
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            end
        elseif first_last_pn == second_first_pn then
            -- 2-3, 3-4 -> 2-4
            pages[i-1] = { first_last, second_last }
            remove(pages,i)
            return true
        end
    end
    return false
end

function collapsepages(pages)
    while collapsedpage(pages) do end
    return #pages
end

function registers.flush(data,options,prefixspec,pagespec)
    local collapse_singles = options.compress == variables.yes
    local collapse_ranges  = options.compress == variables.all
    local result = data.result
    context.startregisteroutput()
    for i=1,#result do
     -- ranges need checking !
        local sublist = result[i]
        local done = { false, false, false, false }
        local data = sublist.data
        local d, n = 0, 0
        context.startregistersection(sublist.tag)
        for d=1,#data do
            local entry = data[d]
            if entry.metadata.kind == "see" then
                local list = entry.list
                list[#list] = nil
            end
        end
        while d < #data do
            d = d + 1
            local entry = data[d]
            local e = { false, false, false, false }
            local metadata = entry.metadata
            local kind = metadata.kind
            local list = entry.list
            for i=1,4 do -- max 4
                if list[i] then
                    e[i] = list[i][1]
                end
                if e[i] ~= done[i] then
                    if e[i] and e[i] ~= "" then
                        done[i] = e[i]
                        if n == i then
                            context.stopregisterentries()
                            context.startregisterentries(n)
                        else
                            while n > i do
                                n = n - 1
                                context.stopregisterentries()
                            end
                            while n < i do
                                n = n + 1
                                context.startregisterentries(n)
                            end
                        end
                        local internal  = entry.references.internal or 0
                        local seeparent = entry.references.seeparent or ""
                        local processor = entry.processors and entry.processors[1] or ""
                        if metadata then
                            context.registerentry(processor,internal,seeparent,function() helpers.title(e[i],metadata) end)
                        else -- ?
                            context.registerentry(processor,internal,seeindex,e[i])
                        end
                    else
                        done[i] = false
                    end
                end
            end
            if kind == 'entry' then
                context.startregisterpages()
                if collapse_singles or collapse_ranges then
                    -- we collapse ranges and keep existing ranges as they are
                    -- so we get prebuilt as well as built ranges
                    local first, last, prev, pages, dd, nofpages = entry, nil, entry, { }, d, 0
                    while dd < #data do
                        dd = dd + 1
                        local next = data[dd]
                        if next and next.metadata.kind == "see" then
                            dd = dd - 1
                            break
                        else
                            local el, nl = entry.list, next.list
                            if not equal(el,nl) then
                                dd = dd - 1
                            --~ first = nil
                                break
                            elseif next.references.lastrealpage then
                                nofpages = nofpages + 1
                                pages[nofpages] = first and { first, last or first } or { entry, entry }
                                nofpages = nofpages + 1
                                pages[nofpages] = { next, next }
                                first, last, prev = nil, nil, nil
                            elseif not first then
                                first, prev = next, next
                            elseif next.references.realpage - prev.references.realpage == 1 then -- 1 ?
                                last, prev = next, next
                            else
                                nofpages = nofpages + 1
                                pages[nofpages] = { first, last or first }
                                first, last, prev = next, nil, next
                            end
                        end
                    end
                    if first then
                        nofpages = nofpages + 1
                        pages[nofpages] = { first, last or first }
                    end
                    if collapse_ranges and nofpages > 1 then
                        nofpages = collapsepages(pages)
                    end
                    if nofpages > 0 then -- or 0
                        d = dd
                        for p=1,nofpages do
                            local first, last = pages[p][1], pages[p][2]
                            if first == last then
                                if first.references.lastrealpage then
                                    pagerange(first,first,true,prefixspec,pagespec)
                                else
                                    pagenumber(first,prefixspec,pagespec)
                                end
                            elseif last.references.lastrealpage then
                                pagerange(first,last,true,prefixspec,pagespec)
                            else
                                pagerange(first,last,false,prefixspec,pagespec)
                            end
                        end
                    elseif entry.references.lastrealpage then
                        pagerange(entry,entry,true,prefixspec,pagespec)
                    else
                        pagenumber(entry,prefixspec,pagespec)
                    end
                else
                    while true do
                        if entry.references.lastrealpage then
                            pagerange(entry,entry,true,prefixspec,pagespec)
                        else
                            pagenumber(entry,prefixspec,pagespec)
                        end
                        if d == #data then
                            break
                        else
                            d = d + 1
                            local next = data[d]
                            if next.metadata.kind == "see" or not equal(entry.list,next.list) then
                                d = d - 1
                                break
                            else
                                entry = next
                            end
                        end
                    end
                end
                context.stopregisterpages()
            elseif kind == 'see' then
                local t, nt = { }, 0
                while true do
                    nt = nt + 1
                    t[nt] = entry
                    if d == #data then
                        break
                    else
                        d = d + 1
                        local next = data[d]
                        if next.metadata.kind ~= "see" or not equal(entry.list,next.list) then
                            d = d - 1
                            break
                        else
                            entry = next
                        end
                    end
                end
                context.startregisterseewords()
                for i=1,nt do
                    local entry = t[i]
                    local processor = entry.processors and entry.processors[1] or ""
                    local seeindex  = entry.references.seeindex or ""
                    local seeword   = entry.seeword.text or ""
                    context.registerseeword(i,n,processor,0,seeindex,seeword)
                end
                context.stopregisterseewords()
            end
        end
        while n > 0 do
            context.stopregisterentries()
            n = n - 1
        end
        context.stopregistersection()
    end
    context.stopregisteroutput()
    -- for now, maybe at some point we will do a multipass or so
    data.result = nil
    data.metadata.sorted = false
end

function registers.analyze(class,options)
    texwrite(registers.analyzed(class,options))
end

function registers.process(class,...)
    if registers.analyzed(class,...) > 0 then
        registers.flush(collected[class],...)
    end
end

