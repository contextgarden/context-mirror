if not modules then modules = { } end modules ['lxml-sor'] = {
    version   = 1.001,
    comment   = "companion to lxml-sor.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat = string.format, table.concat
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes

lxml.sorters = lxml.sorters or { }

if not lxml.splitid then
    local splitter = lpeg.C((1-lpeg.P(":"))^1) * lpeg.P("::") * lpeg.C(lpeg.P(1)^1)
    function lxml.splitid(id)
        local d, i = splitter:match(id)
        if d then
            return d, i
        else
            return "", id
        end
    end
end

local lists = { }

function lxml.sorters.reset(name)
    lists[name] = {
        sorted  = false,
        entries = { },
        reverse = { },
        results = { },
    }
end

function lxml.sorters.add(name,n,key)
    local list = lists[name]
    if list.sorted then
        -- reverse is messed up, we could regenerate it and go on
    else
        local entries = list and list.entries
        if entries then
            local reverse = list.reverse
            local e = reverse[n]
            if e then
                local keys = entries[e][2]
                keys[#keys+1] = key
            else
                entries[#entries+1] = { n, { key } }
                reverse[n] = #entries
            end
        end
    end
end

function lxml.sorters.show(name)
    local list = lists[name]
    local entries = list and list.entries
    local NC, NR, bold = context.NC, context.NR, context.bold -- somehow bold is not working
    if entries then
        context.starttabulate { "|Tr|Tr|Tl|" }
        NC() bold("n") NC() bold("id") NC() bold("entry") NR() context.HL()
        for i=1,#entries do
            local entry = entries[i]
            local document, node = lxml.splitid(entry[1])
            NC() context(i) NC() context(node) NC() context(concat(entry[2]," ")) NR()
        end
        context.stoptabulate()
    end
end

function lxml.sorters.compare(a,b)
    return sorters.comparers.basic(a.split,b.split)
end

function lxml.sorters.sort(name)
    local list = lists[name]
    local entries = list and list.entries
    if entries then
        -- filtering
        local results = { }
        list.results = results
        for i=1,#entries do
            local entry = entries[i]
            results[i] = {
                entry = entry[1],
                key = concat(entry[2], " "),
            }
        end
        -- preparation
        local strip = sorters.strip
        local splitter = sorters.splitters.utf
        for i=1, #results do
            local r = results[i]
            r.split = splitter(strip(r.key))
        end
        -- sorting
        sorters.sort(results,lxml.sorters.compare)
        -- finalizing
        list.nofsorted = #results
        local split = { }
        for k=1,#results do -- rather generic so maybe we need a function
            local v = results[k]
            local entry, tag = sorters.firstofsplit(v.split)
            local s = split[entry] -- keeps track of change
            if not s then
                s = { tag = tag, data = { } }
                split[entry] = s
            end
            s.data[#s.data+1] = v
        end
        list.results = split
        -- done
        list.sorted = true
    end
end

function lxml.sorters.flush(name,setup)
    local list = lists[name]
    local results = list and list.results
    if results and next(results) then
        for key, result in next, results do
            local tag, data = result.tag, result.data
--~             tex.sprint(ctxcatcodes,format("key=%s\\quad tag=%s\\blank",key,tag))
            for d=1,#data do
                local dr = data[d]
                texsprint(ctxcatcodes,format("\\xmls{%s}{%s}",dr.entry,setup))
            end
--~             tex.sprint(ctxcatcodes,format("\\blank"))
        end
    else
        local entries = list and list.entries
        if entries then
            for i=1,#entries do
                texsprint(ctxcatcodes,format("\\xmls{%s}{%s}",entries[i][1],setup))
            end
        end
    end
end
