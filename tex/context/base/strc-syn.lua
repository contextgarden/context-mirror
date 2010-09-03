if not modules then modules = { } end modules ['str-syn'] = {
    version   = 1.001,
    comment   = "companion to str-syn.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local texwrite, texsprint, format = tex.write, tex.sprint, string.format
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local ctxcatcodes = tex.ctxcatcodes

-- interface to tex end

local structures    = structures
local synonyms      = structures.synonyms

local collected, tobesaved = allocate(), allocate()

synonyms.collected = collected
synonyms.tobesaved = tobesaved

local function initializer()
    collected = mark(synonyms.collected)
    tobesaved = mark(synonyms.tobesaved)
end

local function finalizer()
    for entry, data in next, tobesaved do
        data.hash = nil
    end
end

job.register('structures.synonyms.collected', tobesaved, initializer, finalizer)

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

function synonyms.define(class,kind)
    local data = allocate(class)
    data.metadata.kind = kind
end

function synonyms.register(class,kind,spec)
    local data = allocate(class)
    data.metadata.kind = kind -- runtime, not saved in format (yet)
    if not data.hash[spec.definition.tag or ""] then
        data.entries[#data.entries+1] = spec
        data.hash[spec.definition.tag or ""] = spec
    end
end

function synonyms.registerused(class,tag)
    local data = allocate(class)
    local dht = data.hash[tag]
    if dht then
        dht.definition.used = true
    end
end

function synonyms.synonym(class,tag)
    local data = allocate(class).hash
    local d = data[tag]
    if d then
        local de = d.definition
        de.used = true
        texsprint(ctxcatcodes,de.synonym)
    end
end

function synonyms.meaning(class,tag)
    local data = allocate(class).hash
    local d = data[tag]
    if d then
        local de = d.definition
        de.used = true
        texsprint(ctxcatcodes,de.meaning)
    end
end

synonyms.compare = sorters.comparers.basic -- (a,b)

function synonyms.filter(data,options)
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

function synonyms.prepare(data)
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

function synonyms.sort(data,options)
    sorters.sort(data.result,synonyms.compare)
end

function synonyms.finalize(data,options)
    local result = data.result
    data.metadata.nofsorted = #result
    local split = { }
    for k=1,#result do
        local v = result[k]
        local entry, tag = sorters.firstofsplit(v)
        local s = split[entry] -- keeps track of change
        if not s then
            s = { tag = tag, data = { } }
            split[entry] = s
        end
        s.data[#s.data+1] = v
    end
    data.result = split
end

function synonyms.flush(data,options) -- maybe pass the settings differently
    local kind = data.metadata.kind   -- hack, will be done better
--~     texsprint(ctxcatcodes,format("\\start%soutput",kind))
    local result = data.result
    local sorted = table.sortedkeys(result)
    for k=1,#sorted do
        local letter = sorted[k]
        local sublist = result[letter]
        local data = sublist.data
--~         texsprint(ctxcatcodes,format("\\start%ssection{%s}",kind,sublist.tag))
        for d=1,#data do
            local entry = data[d].definition
            texsprint(ctxcatcodes,format("\\%sentry{%s}{%s}{%s}{%s}",kind,d,entry.tag,entry.synonym,entry.meaning or ""))
        end
--~         texsprint(ctxcatcodes,format("\\stop%ssection",kind))
    end
--~     texsprint(ctxcatcodes,format("\\stop%soutput",kind))
    -- for now, maybe at some point we will do a multipass or so
    data.result = nil
    data.metadata.sorted = false
end

function synonyms.analyzed(class,options)
    local data = synonyms.collected[class]
    if data and data.entries then
        options = options or { }
        sorters.setlanguage(options.language)
        synonyms.filter(data,options)   -- filters entries to result
        synonyms.prepare(data,options)  -- adds split table parallel to list table
        synonyms.sort(data,options)     -- sorts entries in result
        synonyms.finalize(data,options) -- do things with data.entries
        data.metadata.sorted = true
    end
    return data and data.metadata.sorted and data.result and next(data.result)
end

function synonyms.process(class,options)
    if synonyms.analyzed(class,options) then
        synonyms.flush(synonyms.collected[class],options)
    end
end

