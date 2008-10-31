if not modules then modules = { } end modules ['core-syn'] = {
    version   = 1.001,
    comment   = "companion to core-syn.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

sorters      = sorters or { }
sorters.list = sorters.list or { }

function sorters.list.compare(a,b)
    return sorters.comparers.basic(a,b,1)
end

function sorters.list.prepare(data)
    sorters.prepare(data,sorters.splitters.utf,1)
end

function sorters.list.sort(data)
    sorters.sort(data,sorters.list.compare)
end

function sorters.list.unique(data)
    sorters.unique(data)
end

function sorters.list.cleanup(data)
    sorters.cleanup(data)
end

function sorters.list.finalize(data) -- hm, this really needs documentation
    -- we use the same splitter as with indices
    local split = { }
    for k,v in ipairs(data) do
        local entry, tag = v[2][1][3][1], ""
        local se = sorters.entries[sorters.language]
        if se and se[entry] then
            if type(se[entry]) == "number" then
                entry = se[entry]
            end
            tag = se[entry]
        else
            entry = 0
            tag = "unknown"
        end
        split[entry] = split[entry] or { tag = tag, data = { } }
        split[entry].data[#split[entry].data+1] = v
    end
    return split
end

-- for the moment we use the old structure, some day mkiv code
-- will be different: more structure, less mess

local template = {
    entry = "\\synonymentry{%s}{%s}{%s}{%s}"
}

function sorters.list.flush(sorted,class)
    -- for the moment we don't add split data (letters) yet
    class = class or 'abbreviation'
    for k,v in ipairs(table.sortedkeys(sorted)) do
        for _, vv in ipairs(sorted[v].data) do
            tex.sprint(tex.ctxcatcodes,template.entry:format(class,vv[2][1][1],vv[2][1][2],vv[3]))
        end
    end
end

function sorters.list.process(data)
    return sorters.process('list',data)
end

-- interface to tex end

joblists           = joblists or { }
joblists.collected = joblists.collected or { }
joblists.tobesaved = joblists.tobesaved or { }

local collected, tobesaved = joblists.collected, joblists.tobesaved

local function initializer()
    collected, tobesaved = joblists.collected, joblists.tobesaved
end

job.register('joblists.collected', joblists.tobesaved, initializer, nil)

local function allocate(class)
    local d = tobesaved[class]
    if not d then
        d = {
            language = 'en',
            entries  = { },
            sorted   = false,
            class    = class
        }
        tobesaved[class] = d
    end
    return d
end

local function collect(class)
    return collected[class]
end

joblists.define = allocate

-- this should be more generic, i.e. userdata = { meaning = "" }
-- or at least we should get rid of the { { } } which is a quick
-- hack to share code with the indexer

function joblists.save_entry(class,kind,entry,key,meaning)
    local data = allocate(class).entries
    data[#data+1] = { kind, { { entry, key } }, meaning } -- { kind, entry, key, meaning }
end

function joblists.save_variable(class,key,value)
    if key == "l" then key = "language" end
    allocate(class)[key] = value
end

function joblists.process(class)
    local data = collect(class)
    if data then
        sorters.list.process(data)
    end
end
