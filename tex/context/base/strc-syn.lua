if not modules then modules = { } end modules ['str-syn'] = {
    version   = 1.001,
    comment   = "companion to str-syn.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local texwrite, texsprint, format = tex.write, tex.sprint, string.format

local ctxcatcodes = tex.ctxcatcodes

-- interface to tex end

joblists           = joblists or { }
joblists.collected = joblists.collected or { }
joblists.tobesaved = joblists.tobesaved or { }

local collected, tobesaved = joblists.collected, joblists.tobesaved

local function initializer()
    collected, tobesaved = joblists.collected, joblists.tobesaved
end

local function finalizer()
    for entry, data in next, tobesaved do
        data.hash = nil
    end
end

job.register('joblists.collected', joblists.tobesaved, initializer, finalizer)

local function allocate(class)
    local d = tobesaved[class]
    if not d then
        d = {
            metadata = {
                language = 'en',
                sorted   = false,
                class    = class
            },
            entries  = {
            },
            hash = {
            }
        }
        tobesaved[class] = d
    end
    return d
end

function joblists.define(class,kind)
    local data = allocate(class)
    data.metadata.kind = kind
end

function joblists.register(class,kind,spec)
    local data = allocate(class)
    data.metadata.kind = kind -- runtime, not saved in format (yet)
    data.entries[#data.entries+1] = spec
    data.hash[spec.definition.tag or ""] = spec
end

function joblists.synonym(class,tag)
    local data = allocate(class).hash
    local d = data[tag]
    if d then
        local de = d.definition
        de.used = true
        texsprint(ctxcatcodes,de.synonym)
    end
end

function joblists.meaning(class,tag)
    local data = allocate(class).hash
    local d = data[tag]
    if d then
        local de = d.definition
        de.used = true
        texsprint(ctxcatcodes,de.meaning)
    end
end

function joblists.compare(a,b)
    return sorters.comparers.basic(a.split,b.split)
end

function joblists.filter(data,options)
    local result = { }
    local entries = data.entries
    local all = options and options.criterium == interfaces.variables.all
    for i=1,#entries do
        local entry = entries[i]
        if all or entry.definition.used then
            result[#result+1] = entry
        end
    end
    data.result = result
end

function joblists.prepare(data)
    local strip = sorters.strip
    local splitter = sorters.splitters.utf
    local result = data.result
    if result then
        for i=1, #result do
            local r = result[i]
            local rd = r.definition
            if rd then
                local rt = rd.tag
                local sortkey = (rt and rt ~= "" and rt) or rd.synonym
                r.split = splitter(strip(sortkey))
            end
        end
    end
end

function joblists.sort(data,options)
    sorters.sort(data.result,joblists.compare)
end

function joblists.finalize(data,options)
    local result = data.result
    data.metadata.nofsorted = #result
    local split = { }
    for k=1,#result do
        local v = result[k]
        local entry, tag = sorters.firstofsplit(v.split)
        local s = split[entry] -- keeps track of change
        if not s then
            s = { tag = tag, data = { } }
            split[entry] = s
        end
        s.data[#s.data+1] = v
    end
    data.result = split
end

function joblists.flush(data,options) -- maybe pass the settings differently
    local kind = data.metadata.kind   -- hack, will be done better
--~     texsprint(ctxcatcodes,format("\\start%soutput",kind))
    local result = data.result
    for k, letter in ipairs(table.sortedkeys(result)) do
        local sublist = result[letter]
        local data = sublist.data
--~         texsprint(ctxcatcodes,format("\\start%ssection{%s}",kind,sublist.tag))
        for d=1,#data do
            local entry = data[d].definition
            texsprint(ctxcatcodes,format("\\%sentry{%s}{%s}{%s}",kind,d,entry.synonym,entry.meaning))
        end
--~         texsprint(ctxcatcodes,format("\\stop%ssection",kind))
    end
--~     texsprint(ctxcatcodes,format("\\stop%soutput",kind))
    -- for now, maybe at some point we will do a multipass or so
    data.result = nil
    data.metadata.sorted = false
end

function joblists.analysed(class,options)
    local data = joblists.collected[class]
    if data and data.entries then
        joblists.filter(data,options)   -- filters entries to result
        joblists.prepare(data,options)  -- adds split table parallel to list table
        joblists.sort(data,options)     -- sorts entries in result
        joblists.finalize(data,options) -- do things with data.entries
        data.metadata.sorted = true
    end
    return data and data.metadata.sorted and data.result and next(data.result)
end

function joblists.process(class,options)
    if joblists.analysed(class,options) then
        joblists.flush(joblists.collected[class],options)
    end
end

