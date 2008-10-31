if not modules then modules = { } end modules ['core-reg'] = {
    version   = 1.001,
    comment   = "companion to core-reg.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

sorters          = sorters or { }
sorters.register = sorters.register or { }

-- {'e','3','','test+test+test','2--0-0-0-0-0-0-0--1','1'}

function sorters.register.compare(a,b)
    local result = 0
    for i=1,4 do
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

function sorters.register.prepare(data)
    sorters.prepare(data,sorters.splitters.utf,4)
end

function sorters.register.sort(data)
    sorters.sort(data,sorters.register.compare)
end

function sorters.register.unique(data)
    sorters.unique(data)
end

function sorters.register.cleanup(data)
    sorters.cleanup(data)
end

function sorters.register.finalize(data)
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

-- \registerpage{index}{,}{6}{2--0-0-0-0-0-0-0--1}{1}

-- for the moment we use the old structure, some day mkiv code
-- will be different: more structure, less mess

local template = {
    page = "\\registerpage{%s}{%s}{%s}{%s}{%s}",
    see = "\\registersee{%s}{%s}{%s}{%s}",
    letter = "\\registerentry{%s}{%s}",
    entry = {
        "\\registerentrya{%s}{%s}",
        "\\registerentryb{%s}{%s}",
        "\\registerentryc{%s}{%s}",
        "\\registerentryd{%s}{%s}",
    },
}

function sorters.register.flush(sorted,class)
    class = class or 'index'
    for k,v in ipairs(table.sortedkeys(sorted)) do
        local s = sorted[v]
        tex.sprint(tex.ctxcatcodes,template.letter:format(class,s.tag))
        local done = { false, false, false }
        for kk,vv in ipairs(s.data) do
            if vv[2][1] then
                local e = { false, false, false, false }
                for i=1,4,1 do
                    if vv[2][i] then
                        e[i] = vv[2][i][1]
                    end
                    if e[i] ~= done[i] then
                        if e[i] and e[i] ~= "" then
                            done[i] = e[i]
                            tex.sprint(tex.ctxcatcodes,template.entry[i]:format(class,e[i]))
                        else
                            done[i] = false
                        end
                    end
                end
                if vv[1] == 'e' then
                    -- format reference pagespec realpage
                    tex.sprint(tex.ctxcatcodes,template.page:format(class,",",vv[4],vv[5],vv[3]))
                elseif vv[1] == 's' then
                    tex.sprint(tex.ctxcatcodes,template.see:format(class,",",vv[5],vv[3]))
                end
            end
        end
    end
end

function sorters.register.process(data)
    return sorters.process('register',data)
end

-- { { entry, key }, { entry, key }, { entry, key }, { entry, key } }, kind, realpage|see, reference, pagespec

jobregisters           = jobregisters or { }
jobregisters.collected = jobregisters.collected or { }
jobregisters.tobesaved = jobregisters.tobesaved or { }

job.register('jobregisters.collected', jobregisters.tobesaved)

local function allocate(class)
    local d = jobregisters.tobesaved[class]
    if not d then
        d = {
            language = 'en',
            entries  = { },
            sorted   = false,
            class    = class
        }
        jobregisters.tobesaved[class] = d
    end
    return d
end

local function collect(class)
    return jobregisters.collected[class]
end

jobregisters.define = allocate

function jobregisters.save_entry(class,kind,reference,key,entry,page,realpage) -- realpage|see
    local data = allocate(class).entries
    if type(entry) == 'string' then
        entry = entry:splitchr('+')
    end
    if type(key) == 'string' then
        key = key:splitchr('+')
    end
    data[#data+1] = {
        kind, -- kind (e, f, t, s)
        {
            { entry[1] or "", key[1] or "" },
            { entry[2] or "", key[2] or "" },
            { entry[3] or "", key[3] or "" },
            { entry[4] or "", key[4] or "" }
        },
        realpage, -- realpage or seeword (check see)
        reference, -- reference
        page, -- pagespec
    }
end

jobregisters.save_see = jobregisters.save_entry

function jobregisters.save_variable(class,key,value)
    if key == "l" then key = "language" end
    allocate(class)[key] = value
end

function jobregisters.process(class)
    local data = collect(class)
    if data then
        return sorters.register.process(data)
    end
end
