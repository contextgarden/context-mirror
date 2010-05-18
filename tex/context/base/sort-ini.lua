if not modules then modules = { } end modules ['sort-ini'] = {
    version   = 1.001,
    comment   = "companion to sort-ini.mkiv",
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
local gsub, rep, sort, concat = string.gsub, string.rep, table.sort, table.concat
local utfbyte, utfchar = utf.byte, utf.char
local utfcharacters, utfvalues, strcharacters = string.utfcharacters, string.utfvalues, string.characters
local chardata = characters.data

local trace_tests = false  trackers.register("sorters.tests", function(v) trace_tests = v end)

sorters              = { }
sorters.comparers    = { }
sorters.splitters    = { }
sorters.entries      = { }
sorters.mappings     = { }
sorters.replacements = { }
sorters.language     = 'en'

local mappings     = sorters.mappings
local entries      = sorters.entries
local replacements = sorters.replacements

function sorters.comparers.basic(sort_a,sort_b,map)
    -- sm assignment is slow, will become sorters.initialize
    local sm = map or mappings[sorters.language or sorters.defaultlanguage] or mappings.en
    if #sort_a > #sort_b then
        if #sort_b == 0 then
            return 1
        else
            for i=1,#sort_b do
                local ai, bi = sort_a[i], sort_b[i]
                local am, bm = sm[ai], sm[bi]
                if am and bm then
                    if am > bm then
                        return  1
                    elseif am < bm then
                        return -1
                    end
                else
                    if ai > bi then
                        return  1
                    elseif ai < bi then
                        return -1
                    end
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
                local am, bm = sm[ai], sm[bi]
                if am and bm then
                    if am > bm then
                        return  1
                    elseif am < bm then
                        return -1
                    end
                else
                    if ai > bi then
                        return  1
                    elseif ai < bi then
                        return -1
                    end
                end
            end
            return -1
        end
    elseif #sort_a == 0 then
        return 0
    else
        for i=1,#sort_a do
            local ai, bi = sort_a[i], sort_b[i]
            local am, bm = sm[ai], sm[bi]
            if am and bm then
                if am > bm then
                    return  1
                elseif am < bm then
                    return -1
                end
            else
                if ai > bi then
                    return  1
                elseif ai < bi then
                    return -1
                end
            end
        end
        return 0
    end
end

local function padd(s) return rep(" ",10-#s) .. s end -- or format with padd

function sorters.strip(str) -- todo: only letters and such utf.gsub("([^%w%d])","")
    if str then
        str = gsub(str,"\\%S*","")
        str = gsub(str,"[%s%[%](){}%$\"\']*","")
        str = gsub(str,"(%d+)",padd) -- sort numbers properly
        return str
    else
        return ""
    end
end

function sorters.firstofsplit(split)
    -- numbers are left padded by spaces
    local se = entries[sorters.language or sorters.defaultlanguage] or entries.en -- slow, will become sorters.initialize
    local vs = split[1]
    local entry = vs and vs[1] or ""
    return entry, (se and se[entry]) or "\000"
end

sorters.defaultlanguage = 'en'

-- beware, numbers get spaces in front

function sorters.splitters.utf(str) -- brrr, todo: language
    local r = sorters.replacements[sorters.language] or sorters.replacements[sorters.defaultlanguage] or { }
 -- local m = mappings    [sorters.language] or mappings    [sorters.defaultlanguage] or { }
    local u = characters.uncompose
    local t = { }
    for _,v in next, r do
        str = gsub(str,v[1],v[2])
    end
    for c in utfcharacters(str) do -- maybe an lpeg
        t[#t+1] = c
    end
    return t
end

function table.remap(t)
    local tt = { }
    for k,v in pairs(t) do
        tt[v]  = k
    end
    return tt
end

function sorters.sort(entries,cmp)
    local language = sorters.language or sorters.defaultlanguage
    local map = mappings[language] or mappings.en
    if trace_tests then
        local function pack(l)
            local t = { }
            for i=1,#l do
                local tt, li = { }, l[i]
                for j=1,#li do
                    local lij = li[j]
                    if utfbyte(lij) > 0xFF00 then
                        tt[j] = "[]"
                    else
                        tt[j] = li[j]
                    end
                end
                t[i] = concat(tt)
            end
            return concat(t," + ")
        end
        sort(entries, function(a,b)
            local r = cmp(a,b,map)
            local as, bs = a.split, b.split
            if as and bs then
                logs.report("sorter","%s %s %s",pack(as),(not r and "?") or (r<0 and "<") or (r>0 and ">") or "=",pack(bs))
            end
            return r == -1
        end)
        local s
        for i=1,#entries do
            local split = entries[i].split
            local entry, first = sorters.firstofsplit(split)
            if first == s then
                first = "  "
            else
                s = first
                logs.report("sorter",">> %s 0x%05X (%s 0x%05X)",first,utfbyte(first),entry,utfbyte(entry))
            end
            logs.report("sorter","   %s",pack(split))
        end
    else
        sort(entries, function(a,b)
            return cmp(a,b,map) == -1
        end)
    end
end

-- some day we can have a characters.upper and characters.lower

function sorters.add_uppercase_entries(entries)
    local new = { }
    for k, v in next, entries do
        local u = chardata[utfbyte(k)].uccode
        if u then
            new[utfchar(u)] = v
        end
    end
    for k, v in next, new do
        entries[k] = v
    end
end

function sorters.add_uppercase_mappings(mappings,offset)
    local new = { }
    for k, v in next, mappings do
        local u = chardata[utfbyte(k)].uccode
        if u then
            new[utfchar(u)] = v + offset
        end
    end
    offset = offset or 0
    for k, v in next, new do
        mappings[k] = v
    end
end
