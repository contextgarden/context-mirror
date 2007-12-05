-- filename : core-syn.lua
-- comment  : companion to core-syn.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions        then versions        = { } end versions['core-syn'] = 1.001
if not jobs            then jobs            = { } end
if not job             then jobs['main']    = { } end job = jobs['main']
if not job.sortedlists then job.sortedlists = { } end

function job.definesortedlist(id)
    if not job.sortedlists[id] then
        job.sortedlists[id] = { }
    end
end

sorters           = sorters           or { }
sorters.list      = sorters.list      or { }
sorters.list.data = sorters.list.data or { }

do

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

    function sorters.list.finalize(data)
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

    function sorters.list.flush(sorted,class,flush)
        -- for the moment we don't add split data (letters) yet
        flush = flush or print
        class = class or 'abbreviation'
        for k,v in ipairs(table.sortedkeys(sorted)) do
            for _, vv in ipairs(sorted[v].data) do
                flush(string.format(template.entry,class,vv[2][1][1],vv[2][1][2],vv[3]))
            end
        end
    end

    function sorters.list.process(data)
        return sorters.process('list',data)
    end

end

-- { { entry, key } }, meaning

function job.loadsortedlist(class)
    if job.sortedlists[class] then
        if not sorters.list.data[class] then
            sorters.list.data[class] = {
                language = 'en',
                entries  = { },
                flush    = function(s) tex.sprint(tex.ctxcatcodes,s) end,
                sorted   = false,
                class    = class
            }
            local entries = sorters.list.data[class].entries
            for k,v in ipairs(job.sortedlists[class]) do
                if v[1] == 'l' then -- language
                    sorters.list.data[class].language = v[2]
                else
                    entries[#entries+1] = {
                        v[1],               -- kind (e)
                        { { v[3], v[2] } }, -- entry, key
                        v[4]                -- optional meaning
                    }
                end
            end
        end
        sorters.list.process(sorters.list.data[class])
    end
end
