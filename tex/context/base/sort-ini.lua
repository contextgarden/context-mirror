-- filename : sort-ini.lua
-- comment  : companion to sort-ini.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- todo:
--
-- out of range
-- uppercase
-- texutil compatible
-- always expand to utf

if not versions then versions = { } end versions['sort-ini'] = 1.001

sorters              = { }
sorters.comparers    = { }
sorters.splitters    = { }
sorters.entries      = { }
sorters.mappings     = { }
sorters.replacements = { }
sorters.language     = 'en'

function sorters.comparers.basic(a,b,i) -- [2] has entry, key, cmp
    local sort_a, sort_b = a[2][i][3], b[2][i][3]
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
            return -1
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
            return 1
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
        sort_a, sort_b = a[2][i][2], b[2][i][2]
        if sort_a == "" then sort_a = a[2][i][1] end
        if sort_b == "" then sort_b = b[2][i][1] end
        if sort_a < sort_b then
            return -1
        elseif sort_a > sort_b then
            return 1
        else
            return 0
        end
    end
end

function sorters.prepare(data,split,n)
    local strip = sorters.strip
    for k,v in ipairs(data) do
        for i=1,n do
            local vv = v[2][i]
            if vv then
                if vv[2] then
                    if vv[2] ~= "" then
                        vv[3] = split(strip(vv[2]))
                    else
                        vv[3] = split(strip(vv[1]))
                    end
                else
                    vv[2] = { }
                    vv[3] = split(strip(vv[1]))
                end
            else
                v[2][i] = { {}, {}, {} }
            end
        end
    end
end

function sorters.strip(str) -- todo: only letters and such utf.gsub("([^%w%d])","")
    str = str:gsub("\\%S*","")
    str = str:gsub("[%s%[%](){}%$\"\']*","")
    str = str:gsub("(%d+)",function(s) return (" "):rep(10-#s) .. s end) -- sort numbers properly
    return str
end

function sorters.splitters.utf(str)
    local r = sorters.replacements[sorters.language] or { }
    local m = sorters.mappings[sorters.language] or { }
    local u = characters.uncompose
    local t = { }
    for _,v in pairs(r) do
        str = str:gsub(v[1],v[2])
    end
    for c in string.utfcharacters(str) do
        if m[c] then
            t[#t+1] = m[c]
        else
            for cc in string.characters(u(c)) do
                t[#t+1] = m[cc] or cc
            end
        end
    end
    return t
end

function sorters.sort(data,cmp)
    table.sort(data,function(a,b) return cmp(a,b) == -1 end)
end

function sorters.cleanup(data)
    for k,v in ipairs(data) do
        for kk,vv in ipairs(v[2]) do
            if vv and #vv[1] == 0 then
                v[1][kk] = nil
            else
                vv[3] = nil
            end
        end
        for kk,vv in pairs(v) do
            if vv == "" then
                v[kk] = nil
            end
        end
    end
end

function sorters.unique(data)
    local prev, last = nil, 0
    for _,v in ipairs(data) do
        if not prev or not table.are_equal(prev,v,2,3) then -- check range
            last = last + 1
            data[last] = v
            prev = v
        end
    end
    for i=last+1,#data do
        data[i] = nil
    end
end

function sorters.process(kind,data)
    if data.entries then
        if not data.sorted then
            sorters.language = data.language or sorters.language
            sorters[kind].prepare(data.entries)
            sorters[kind].sort(data.entries)
            sorters[kind].unique(data.entries)
            data.sorted = true
        end
        return sorters[kind].flush(sorters[kind].finalize(data.entries),data.class,data.flush)
    else
        return { }
    end
end
