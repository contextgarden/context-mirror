-- filename : core-reg.lua
-- comment  : companion to core-reg.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions      then versions      = { } end versions['core-reg'] = 1.001
if not jobs          then jobs          = { } end
if not job           then jobs['main']  = { } end job = jobs['main']
if not job.registers then job.registers = { } end

function job.defineregister(id)
    if not job.registers[id] then
        job.registers[id] = { }
    end
end

-- {'e','3','','test+test+test','2--0-0-0-0-0-0-0--1','1'}

-- load index (we could rease the original entry afterwards, freeing memory)

-- index sorting

sorters            = sorters            or { }
sorters.index      = sorters.index      or { }
sorters.index.data = sorters.index.data or { }

do

    function sorters.index.compare(a,b)
        local result = 0
        for i=1,3 do
            if result == 0 then
                result = sorters.comparers.basic(a,b,i)
            else
                return result
            end
        end
        if a[1] ~= 's' then -- e/f/t
            local page_a, page_b = a[3], b[3]
            if page_a < page_b then
                return -1
            elseif page_a > page_b then
                return  1
            end
        end
        return 0
    end

    function sorters.index.prepare(data)
        sorters.prepare(data,sorters.splitters.utf,3)
    end

    function sorters.index.sort(data)
        sorters.sort(data,sorters.index.compare)
    end

    function sorters.index.unique(data)
        sorters.unique(data)
    end

    function sorters.index.cleanup(data)
        sorters.cleanup(data)
    end

    function sorters.index.finalize(data)
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

--~     local template = {
--~         page = "\\pageentry{%s}{%s}{%s}{%s}",
--~         start = {
--~             [0] = "\\startletter{%s}",
--~             [1] = "\\startentry{%s}",
--~             [2] = "\\startsubentry{%s}",
--~             [3] = "\\startsubsubentry{%s}"
--~         },
--~         stop = {
--~             [0] = "\\stopletter",
--~             [1] = "\\stopentry",
--~             [2] = "\\stopsubentry",
--~             [3] = "\\stopsubsubentry"
--~         }
--~     }

--~     function sorters.index.flush(sorted,class,flush)
--~         flush = flush or print
--~         class = class or 'index'
--~         local function flushpage(v)
--~             flush(string.format(template.page,v[2],v[3] or "",v[4] or "",v[5] or ""))
--~         end
--~         for _,v in ipairs(table.sortedkeys(sorted)) do
--~             local s = sorted[v]
--~             flush(string.format(template.start[0],s.tag))
--~             local done = { false, false, false }
--~             for kk,vv in ipairs(s.data) do
--~                 if vv[1][1] then
--~                     local e = { false, false, false }
--~                     for i=1,3,1 do
--~                         if vv[1][i] then e[i] = vv[1][i][1] end
--~                     end
--~                     for i=3,1,-1 do
--~                         if done[i] and e[i] ~= done[i] then
--~                             flush(template.stop[i])
--~                         end
--~                     end
--~                     for i=1,3,1 do
--~                         if e[i] ~= done[i] then
--~                             if e[i] and e[i] ~= "" then
--~                                 done[i] = e[i]
--~                                 flush(string.format(template.start[i],e[i]))
--~                             else
--~                                 done[i] = false
--~                             end
--~                         end
--~                     end
--~                     flushpage(vv)
--~                 end
--~             end
--~             for i=3,1,-1 do
--~                 if done[i] then flush(template.stop[i]) end
--~             end
--~             flush(template.stop[0])
--~         end
--~     end

    -- \registerpage{index}{,}{6}{2--0-0-0-0-0-0-0--1}{1}

    -- for the moment we use the old structure, some day mmiv code
    -- will be different: more structure, less mess

    local template = {
        page = "\\registerpage{%s}{%s}{%s}{%s}{%s}",
        letter = "\\registerentry{%s}{%s}",
        entry = {
            "\\registerentrya{%s}{%s}",
            "\\registerentryb{%s}{%s}",
            "\\registerentryc{%s}{%s}",
        },
    }

    function sorters.index.flush(sorted,class,flush)
        flush = flush or print
        class = class or 'index'
        for k,v in ipairs(table.sortedkeys(sorted)) do
            local s = sorted[v]
            flush(string.format(template.letter,class,s.tag))
            local done = { false, false, false }
            for kk,vv in ipairs(s.data) do
                if vv[2][1] then
                    local e = { false, false, false }
                    for i=1,3,1 do
                        if vv[2][i] then
                            e[i] = vv[2][i][1]
                        end
                        if e[i] ~= done[i] then
                            if e[i] and e[i] ~= "" then
                                done[i] = e[i]
                                flush(string.format(template.entry[i],class,e[i]))
                            else
                                done[i] = false
                            end
                        end
                    end
                    if vv[1] == 'e' then
                        -- format reference pagespec realpage
                        flush(string.format(template.page,class,",",vv[4],vv[5],vv[3]))
                    end
                end
            end
        end
    end

    function sorters.index.process(data)
        return sorters.process('index',data)
    end

end

-- { { entry, key }, { entry, key }, { entry, key } }, kind, realpage|see, reference, pagespec

function job.loadregister(class)
    if job.registers[class] then
        if not sorters.index.data[class] then
            sorters.index.data[class] = {
                language = 'en',
                entries  = { },
                flush    = function(s) tex.sprint(tex.ctxcatcodes,s) end,
                sorted   = false,
                class    = class
            }
            local entries = sorters.index.data[class].entries
            for k,v in ipairs(job.registers[class]) do
                if v[1] == 'l' then -- language
                    sorters.index.data[class].language = v[2]
                else
                    local key, entry = v[3], v[4]
                    if type(entry) == 'string' then
                        entry = entry:splitchr('+')
                    end
                    if type(key) == 'string' then
                        key = key:splitchr('+')
                    end
                    entries[#entries+1] = {
                        v[1], -- kind (e, f, t, s)
                        {
                            { entry[1] or "", key[1] or "" },
                            { entry[2] or "", key[2] or "" },
                            { entry[3] or "", key[3] or "" }
                        },
                        v[6], -- realpage or seeword (check see)
                        v[2], -- reference
                        v[5], -- pagespec
                    }
                end
            end
        end
        -- maybe we should also save the register result stream
        sorters.index.process(sorters.index.data[class])
    end
end
