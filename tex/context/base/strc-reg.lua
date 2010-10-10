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
local ctxcatcodes  = tex.ctxcatcodes
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local trace_registers = false  trackers.register("structures.registers", function(v) trace_registers = v end)

local report_registers = logs.new("registers")

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

local matchingtilldepth, numberatdepth = sections.matchingtilldepth, sections.numberatdepth

-- some day we will share registers and lists (although there are some conceptual
-- differences in the application of keywords)

local function filtercollected(names,criterium,number,collected,prevmode)
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
                        result[#result+1] = v
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
    else
        rawdata.list = { { "", "" } } -- br
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

function registers.compare(a,b)
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

function registers.filter(data,options)
    data.result = registers.filtercollected(nil,options.criterium,options.number,data.entries,true)
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
    end
end

function registers.sort(data,options)
    sorters.sort(data.result,registers.compare)
end

function registers.unique(data,options)
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

function registers.finalize(data,options)
    local result = data.result
    data.metadata.nofsorted = #result
    local split, lasttag, s, d = { }, nil, nil, nil
    -- maps character to index (order)
    for k=1,#result do
        local v = result[k]
        local entry, tag = sorters.firstofsplit(v)
        if tag ~= lasttag then
            if trace_registers then
                report_registers("splitting at %s",tag)
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
        texsprint(ctxcatcodes,data)
    end
end

-- proc can be wrapped

local seeindex = 0

function registers.flush(data,options,prefixspec,pagespec)
    local equal = table.are_equal
    -- local usedtags = { }
    -- for i=1,#result do
    --     usedtags[#usedtags+1] = result[i].tag
    -- end
    --
    -- texsprint(ctxcatcodes,"\\def\\usedregistertags{",concat(usedtags,","),"}") -- todo: { } and escape special chars
    --
    texsprint(ctxcatcodes,"\\startregisteroutput")
    local collapse_singles = options.compress == interfaces.variables.yes
    local collapse_ranges  = options.compress == interfaces.variables.all
    local result = data.result
    -- todo ownnumber
    local function pagenumber(entry)
        local er = entry.references
        local proc = entry.processors and entry.processors[2]
        texsprint(ctxcatcodes,"\\registeronepage{",er.internal or 0,"}{",er.realpage or 0,"}{") -- internal realpage content
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
        local proc = f_entry.processors and f_entry.processors[2]
        texsprint(ctxcatcodes,"\\registerpagerange{",er.internal or 0,"}{",er.realpage or 0,"}{")
        if proc then
            texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{")
            helpers.prefixpage(f_entry,prefixspec,pagespec)
            texsprint(ctxcatcodes,"}")
        else
            helpers.prefixpage(f_entry,prefixspec,pagespec)
        end
        local er = t_entry.references
        texsprint(ctxcatcodes,"}{",er.internal or 0,"}{",er.lastrealpage or er.realpage or 0,"}{")
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
    --
    -- maybe we can nil the splits and save memory
    --
    do
        -- hash words (potential see destinations)
        local words = { }
        for i=1,#result do
            local data = result[i].data
            for j=1,#data do
                local d = data[j]
                local word = d.list[1][1]
                words[word] = d
            end
        end
        -- link seewords to words and tag destination
        for i=1,#result do
            local data = result[i].data
            for j=1,#data do
                local d = data[j]
                local seeword = d.seeword
                if seeword then
                    local text = seeword.text
                    if text then
                        local w = words[text]
                        if w then
                            local wr = w.references -- the referred word
                            local dr = d.references -- the see word
                            if wr.seeparent then
                                dr.seeindex = wr.seeparent
                            else
                                seeindex = seeindex + 1
                                wr.seeparent = seeindex
                                dr.seeindex = seeindex
                            end
                        end
                    end
                end
            end
        end
    end
    --
    for i=1,#result do
     -- ranges need checking !
        local sublist = result[i]
        local done = { false, false, false, false }
        local data = sublist.data
        local d, n = 0, 0
        texsprint(ctxcatcodes,"\\startregistersection{",sublist.tag,"}")
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
                            texsprint(ctxcatcodes,"\\stopregisterentries\\startregisterentries{",n,"}")
                        else
                            while n > i do
                                n = n - 1
                                texsprint(ctxcatcodes,"\\stopregisterentries")
                            end
                            while n < i do
                                n = n + 1
                                texsprint(ctxcatcodes,"\\startregisterentries{",n,"}")
                            end
                        end
                        local internal = entry.references.internal or 0
                        local seeparent = entry.references.seeparent or ""
                        if metadata then
                            texsprint(ctxcatcodes,"\\registerentry{",internal,"}{",seeparent,"}{")
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
                                texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{\\registerentry{",internal,"}{",seeindex,"}{",e[i],"}}")
                            else
                                texsprint(ctxcatcodes,"\\registerentry{",internal,"}{",seeindex,"}{",e[i],"}")
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
                local seeindex = entry.references.seeindex or ""
                local seetext = entry.seeword.text or ""
                local proc = entry.processors and entry.processors[1]
                -- todo: metadata like normal entries
                if proc then
                    texsprint(ctxcatcodes,"\\applyprocessor{",proc,"}{\\registeroneword{0}{",seeindex,"}{",seetext,"}}")
                else
                    texsprint(ctxcatcodes,"\\registeroneword{0}{",seeindex,"}{",seetext,"}")
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

function registers.analyze(class,options)
    texwrite(registers.analyzed(class,options))
end

function registers.process(class,...)
    if registers.analyzed(class,...) > 0 then
        registers.flush(collected[class],...)
    end
end

