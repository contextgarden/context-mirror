if not modules then modules = { } end modules ['sort-ini'] = {
    version   = 1.001,
    comment   = "companion to sort-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- It took a while to get there, but with Fleetwood Mac's "Don't Stop"
-- playing in the background we sort of got it done.

-- todo: cleanup splits (in other modules)

local utf = unicode.utf8
local gsub, rep, sort, concat = string.gsub, string.rep, table.sort, table.concat
local utfbyte, utfchar = utf.byte, utf.char
local utfcharacters, utfvalues, strcharacters = string.utfcharacters, string.utfvalues, string.characters
local chardata = characters.data
local next, type, tonumber = next, type, tonumber

local trace_tests = false  trackers.register("sorters.tests", function(v) trace_tests = v end)

local report_sorters = logs.new("sorters")

sorters              = { }
sorters.comparers    = { }
sorters.splitters    = { }
sorters.entries      = { }
sorters.mappings     = { }
sorters.replacements = { }

sorters.ignored_offset     = 0x10000
sorters.replacement_offset = 0x10000
sorters.digits_offset      = 0x20000
sorters.digits_maximum     = 0xFFFFF

local ignored_offset = sorters.ignored_offset
local digits_offset  = sorters.digits_offset
local digits_maximum = sorters.digits_maximum

local mappings     = sorters.mappings
local entries      = sorters.entries
local replacements = sorters.replacements

local language, defaultlanguage, dummy = 'en', 'en', { }

local currentreplacements, currentmappings, currententries

function sorters.setlanguage(lang)
    language = lang or language or defaultlanguage
    currentreplacements = replacements[language] or replacements[defaultlanguage] or dummy
    currentmappings     = mappings    [language] or mappings    [defaultlanguage] or dummy
    currententries      = entries     [language] or entries     [defaultlanguage] or dummy
    return currentreplacements, currentmappings, currententries
end

sorters.setlanguage()

-- maybe inline code if it's too slow

local function basicsort(sort_a,sort_b)
    if not sort_a or not sort_b then
        return 0
    elseif #sort_a > #sort_b then
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

function sorters.comparers.basic(a,b)
    local ea, eb = a.split, b.split
    local na, nb = #ea, #eb
    if na == 0 and nb == 0 then
        -- simple variant (single word)
        local result = basicsort(ea.e,eb.e)
        return result == 0 and result or basicsort(ea.m,eb.m)
    else
        -- complex variant, used in register (multiple words)
        local result = 0
        for i=1,nb < na and nb or na do
            local eai, ebi = ea[i], eb[i]
            result = basicsort(eai.e,ebi.e)
            if result == 0 then
                result = basicsort(eai.m,ebi.m) -- only needed it there are m's
            end
            if result ~= 0 then
                break
            end
        end
        if result ~= 0 then
            return result
        elseif na > nb then
            return 1
        elseif nb > na then
            return -1
        else
            return 0
        end
    end
end

local function numify(s)
    return rep(" ",10-#s) .. s -- or format with padd
end

local function numify(s)
    s = digits_offset + tonumber(s)
    if s > digits_maximum then
        s = digits_maximum
    end
    return utfchar(s)
end

function sorters.strip(str) -- todo: only letters and such utf.gsub("([^%w%d])","")
    if str then
        str = gsub(str,"\\%S*","")
        str = gsub(str,"[%s%[%](){}%$\"\']*","")
        str = gsub(str,"(%d+)",numify) -- sort numbers properly
        return str
    else
        return ""
    end
end

local function firstofsplit(entry)
    -- numbers are left padded by spaces
    local split = entry.split
    if #split > 0 then
        split = split[1].s
    else
        split = split.s
    end
    local entry = split and split[1] or ""
    return entry, currententries[entry] or "\000"
end

sorters.firstofsplit = firstofsplit

-- beware, numbers get spaces in front

function sorters.splitters.utf(str)
    if #currentreplacements > 0 then
        for k=1,#currentreplacements do
            local v = currentreplacements[k]
            str = gsub(str,v[1],v[2])
        end
    end
    local s, e, m, n = { }, { }, { }, 0
    for sc in utfcharacters(str) do -- maybe an lpeg
        local ec, mc = currententries[sc], currentmappings[sc] or utfbyte(sc)
        n = n + 1
        s[n] = sc
        e[n] = currentmappings[ec] or mc
        m[n] = mc
    end
    return { s = s, e = e, m = m }
end

-- we can use one array instead (sort of like in mkii)
-- but for the moment we do it this way as it is more
-- handy for tracing

-- function sorters.splitters.utf(str)
--     if #currentreplacements > 0 then
--         for k=1,#currentreplacements do
--             local v = currentreplacements[k]
--             str = gsub(str,v[1],v[2])
--         end
--     end
--     local s, e, m, n = { }, { }, { }, 0
--     for sc in utfcharacters(str) do -- maybe an lpeg
--         local ec, mc = currententries[sc], currentmappings[sc] or utfbyte(sc)
--         n = n + 1
--         ec = currentmappings[ec] or mc
--         s[n] = sc
--         e[n] = ec
--         if ec ~= mc then
--             n = n + 1
--             e[n] = mc
--         end
--     end
--     return { s = s, e = e }
-- end

function table.remap(t)
    local tt = { }
    for k,v in next, t do
        tt[v]  = k
    end
    return tt
end

local function pack(entry)
    local t = { }
    local split = entry.split
    if #split > 0 then
        for i=1,#split do
            local tt, li = { }, split[i].s
            for j=1,#li do
                local lij = li[j]
                tt[j] = utfbyte(lij) > ignored_offset and "[]" or lij
            end
            t[i] = concat(tt)
        end
        return concat(t," + ")
    else
        local t, li = { }, split.s
        for j=1,#li do
            local lij = li[j]
            t[j] = utfbyte(lij) > ignored_offset and "[]" or lij
        end
        return concat(t)
    end
end

function sorters.sort(entries,cmp)
    if trace_tests then
        sort(entries,function(a,b)
            local r = cmp(a,b)
            report_sorters("%s %s %s",pack(a),(not r and "?") or (r<0 and "<") or (r>0 and ">") or "=",pack(b))
            return r == -1
        end)
        local s
        for i=1,#entries do
            local entry = entries[i]
            local letter, first = firstofsplit(entry)
            if first == s then
                first = "  "
            else
                s = first
                report_sorters(">> %s 0x%05X (%s 0x%05X)",first,utfbyte(first),letter,utfbyte(letter))
            end
            report_sorters("   %s",pack(entry))
        end
    else
        sort(entries,function(a,b)
            return cmp(a,b) == -1
        end)
    end
end

-- some day we can have a characters.upper and characters.lower

function sorters.add_uppercase_replacements(what)
    local rep, new = replacements[what], { }
    for i=1,#rep do
        local r = rep[i]
        local u = chardata[utfbyte(r[1])].uccode
        if u then
            new[utfchar(u)] = r[2]
        end
    end
    for k, v in next, new do
        rep[k] = v
    end
end

function sorters.add_uppercase_entries(what)
    local ent, new = entries[what], { }
    for k, v in next, ent do
        local u = chardata[utfbyte(k)].uccode
        if u then
            new[utfchar(u)] = v
        end
    end
    for k, v in next, new do
        ent[k] = v
    end
end

function sorters.add_uppercase_mappings(what,offset)
    local map, new, offset = mappings[what], { }, offset or 0
    for k, v in next, map do
        local u = chardata[utfbyte(k)].uccode
        if u then
            new[utfchar(u)] = v + offset
        end
    end
    for k, v in next, new do
        map[k] = v
    end
end
