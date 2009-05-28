if not modules then modules = { } end modules ['sort-ini'] = {
    version   = 1.001,
    comment   = "companion to sort-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo:
--
-- out of range
-- uppercase
-- texutil compatible
-- always expand to utf

local utf = unicode.utf8
local gsub = string.gsub
local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues

sorters              = { }
sorters.comparers    = { }
sorters.splitters    = { }
sorters.entries      = { }
sorters.mappings     = { }
sorters.replacements = { }
sorters.language     = 'en'

function sorters.comparers.basic(sort_a,sort_b)
    if #sort_a > #sort_b then
        if #sort_b == 0 then
            return 1
        else
            for i=1,#sort_b do
                local ai, bi = sort_a[i], sort_b[i]
                if ai > bi then
                    return  1
                elseif ai < bi then
                    return -1
                end
            end
            return 1
        end
    elseif #sort_a < #sort_b then
        if #sort_a == 0 then
            return -1
        else
            for i=1,#sort_a do
                local ai, bi = sort_a[i], sort_b[i]
                if ai > bi then
                    return  1
                elseif ai < bi then
                    return -1
                end
            end
            return -1
        end
    elseif #sort_a == 0 then
        return 0
    else
        for i=1,#sort_a do
            local ai, bi = sort_a[i], sort_b[i]
            if ai > bi then
                return  1
            elseif ai < bi then
                return -1
            end
        end
        return 0
    end
end

function sorters.strip(str) -- todo: only letters and such utf.gsub("([^%w%d])","")
    str = gsub(str,"\\%S*","")
    str = gsub(str,"[%s%[%](){}%$\"\']*","")
    str = gsub(str,"(%d+)",function(s) return (" "):rep(10-#s) .. s end) -- sort numbers properly
    return str
end

sorters.defaultlanguage = 'en'

function sorters.splitters.utf(str) -- brrr, todo: language
    local r = sorters.replacements[sorters.language] or sorters.replacements[sorters.defaultlanguage] or { }
    local m = sorters.mappings    [sorters.language] or sorters.mappings    [sorters.defaultlanguage] or { }
    local u = characters.uncompose
    local b = utf.byte
    local t = { }
    for _,v in next, r do
        str = gsub(str,v[1],v[2])
    end
    for c in utfcharacters(str) do
        if m[c] then
            t[#t+1] = m[c]
        elseif #c == 1 then
            t[#t+1] = b(c)
        else
            for cc in string.characters(u(c)) do -- utf ?
                t[#t+1] = m[cc] or b(cc)
            end
        end
    end
    return t
end

function sorters.sort(entries,cmp)
    table.sort(entries,function(a,b) return cmp(a,b) == -1 end)
end

-- temp workaround (is gone)

function sorters.process()
    -- gone
end

-- was:

--~ function sorters.process(kind,data)
--~     if data.entries then
--~         if not data.sorted then
--~             sorters.language = data.language or sorters.language
--~             sorters[kind].prepare(data.entries)
--~             sorters[kind].sort(data.entries)
--~             sorters[kind].unique(data.entries)
--~             data.sorted = true
--~         end
--~         return sorters[kind].flush(sorters[kind].finalize(data.entries),data.class,data.flush)
--~     else
--~         return { }
--~     end
--~ end

