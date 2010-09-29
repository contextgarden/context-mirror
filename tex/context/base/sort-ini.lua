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
local gsub, rep, sub, sort, concat = string.gsub, string.rep, string.sub, table.sort, table.concat
local utfbyte, utfchar = utf.byte, utf.char
local utfcharacters, utfvalues, strcharacters = string.utfcharacters, string.utfvalues, string.characters
local next, type, tonumber, rawget, rawset = next, type, tonumber, rawget, rawset

local allocate = utilities.storage.allocate

local trace_tests = false  trackers.register("sorters.tests", function(v) trace_tests = v end)

local report_sorters = logs.new("sorters")

local comparers         = { }
local splitters         = { }
local definitions       = allocate()
local tracers           = allocate()
local ignoredoffset     = 0x10000 -- frozen
local replacementoffset = 0x10000 -- frozen
local digitsoffset      = 0x20000 -- frozen
local digitsmaximum     = 0xFFFFF -- frozen

local lccodes           = characters.lccodes
local lcchars           = characters.lcchars
local shchars           = characters.shchars

local variables         = interfaces.variables
local v_numbers         = variables.numbers

local validmethods      = table.tohash { "mm", "zm", "pm", "mc", "zc", "pc", "uc" }

local predefinedmethods = {
    [variables.before] = "mm,mc,uc",
    [variables.after]  = "pm,mc,uc",
    [variables.first]  = "pc,mm,uc",
    [variables.last]   = "mc,mm,uc",
}

sorters = {
    comparers   = comparers,
    splitters   = splitters,
    definitions = definitions,
    tracers     = tracers,
    constants   = {
        ignoredoffset     = ignoredoffset,
        replacementoffset = replacementoffset,
        digitsoffset      = digitsoffset,
        digitsmaximum     = digitsmaximum,
        defaultlanguage   = variables.default,
        defaultmethod     = variables.before,
        defaultdigits     = v_numbers,
    }
}

local sorters   = sorters
local constants = sorters.constants

local data, language, method, digits
local replacements, m_mappings, z_mappings, p_mappings, entries, orders, lower, upper, method, sequence

--~ local shchars = characters.specialchars -- no specials for AE and ae

local mte = {
    __index = function(t,k)
        if utfbyte(k) < digitsoffset then
            local el
            if k then
                local l = lower[k] or lcchars[k]
                el = rawget(t,l)
            end
            if not el then
                local l = shchars[k]
                if l and l ~= k then
                    if #l > 0 then
                        l = sub(l,1,1)
                    end
                    el = rawget(t,l)
                    if not el then
                        l = lower[k] or lcchars[l]
                        if l then
                            el = rawget(t,l)
                        end
                    end
                end
                el = el or k
            end
        --  rawset(t,k,el) also make a copy?
            return el
        end
    end
}

local function preparetables(data)
    local orders, lower, m_mappings, z_mappings, p_mappings = data.orders, data.lower, { }, { }, { }
    for i=1,#orders do
        local oi = orders[i]
        local n = { 2 * i }
        m_mappings[oi], z_mappings[oi], p_mappings[oi] = n, n, n
    end
    local mtm = {
        __index = function(t,k)
            local n
            if k then
                if trace_tests then
                    report_sorters("simplifing character 0x%04x %s",utfbyte(k),k)
                end
                local l = lower[k] or lcchars[k]
                if l then
                    if trace_tests then
                        report_sorters(" 1 lower: %s",l)
                    end
                    local ml = rawget(t,l)
                    if ml then
                        n = { }
                        for i=1,#ml do
                            n[#n+1] = ml[i] + (t.__delta or 0)
                        end
                        if trace_tests then
                            report_sorters(" 2 order: %s",concat(n," "))
                        end
                    end
                end
                if not n then
                    local s = shchars[k]
                    if s and s ~= k then -- weird test
                        if trace_tests then
                            report_sorters(" 3 shape: %s",s)
                        end
                        n = { }
                        for l in utfcharacters(s) do
                            local ml = rawget(t,l)
                            if ml then
                                if trace_tests then
                                    report_sorters(" 4 keep: %s",l)
                                end
                                if ml then
                                    for i=1,#ml do
                                        n[#n+1] = ml[i]
                                    end
                                end
                            else
                                l = lower[l] or lcchars[l]
                                if l then
                                    if trace_tests then
                                        report_sorters(" 5 lower: %s",l)
                                    end
                                    local ml = rawget(t,l)
                                    if ml then
                                        for i=1,#ml do
                                            n[#n+1] = ml[i] + (t.__delta or 0)
                                        end
                                    end
                                end
                            end
                        end
                        if trace_tests then
                            report_sorters(" 6 order: %s",concat(n," "))
                        end
                    end
                    if not n then
                        n = { 0 }
                        if trace_tests then
                            report_sorters(" 7 order: 0")
                        end
                    end
                end
            else
                n =  { 0 }
                if trace_tests then
                    report_sorters(" 8 order: 0")
                end
            end
            rawset(t,k,n)
            return n
        end
    }
    data.m_mappings = m_mappings
    data.z_mappings = z_mappings
    data.p_mappings = p_mappings
    m_mappings.__delta = -1
    z_mappings.__delta =  0
    p_mappings.__delta =  1
    setmetatable(data.entries,mte)
    setmetatable(data.m_mappings,mtm)
    setmetatable(data.z_mappings,mtm)
    setmetatable(data.p_mappings,mtm)
end

local function update() -- prepare parent chains, needed when new languages are added
    for language, data in next, definitions do
        local parent = data.parent or "default"
        if language ~= "default" then
            setmetatable(data,{ __index = definitions[parent] or definitions.default })
        end
        data.language   = language
        data.parent     = parent
        data.m_mappings = { } -- free temp data
        data.z_mappings = { } -- free temp data
        data.p_mappings = { } -- free temp data
    end
end

local function setlanguage(l,m,d)
    language = (l ~= "" and l) or constants.defaultlanguage
    data = definitions[language or constants.defaultlanguage] or definitions[constants.defaultlanguage]
    method = (m ~= "" and m) or data.method or constants.defaultmethod
    digits =  (d ~= "" and d) or data.digits or constants.defaultdigits
    if trace_tests then
        report_sorters("setting language '%s', method '%s', digits '%s'",language,method,digits)
    end
    replacements = data.replacements
    entries      = data.entries
    orders       = data.orders
    lower        = data.lower
    upper        = data.upper
    preparetables(data)
    m_mappings   = data.m_mappings
    z_mappings   = data.z_mappings
    p_mappings   = data.p_mappings
    --
    method = predefinedmethods[method] or method
    data.method  = method
    --
    data.digits  = digite
    --
    local seq = utilities.parsers.settings_to_array(method or "") -- check the list
    sequence = { }
    for i=1,#seq do
        local s = seq[i]
        if validmethods[s] then
            sequence[#sequence+1] = s
        else
            report_sorters("invalid sorter method '%s' in '%s'",s,method)
        end
    end
    data.sequence = sequence
    report_sorters("using sort sequence: %s",concat(sequence," "))
    --
    return data
end

function sorters.update()
    update()
    setlanguage(language,method,numberorder) -- resync current language and method
end

function sorters.setlanguage(language,method,numberorder)
    update()
    setlanguage(language,method,numberorder) -- new language and method
end

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

function comparers.basic(a,b) -- trace ea and eb
    local ea, eb = a.split, b.split
    local na, nb = #ea, #eb
    if na == 0 and nb == 0 then
        -- simple variant (single word)
        local result = 0
        for j=1,#sequence do
            local m = sequence[j]
            result = basicsort(ea[m],eb[m])
            if result ~= 0 then
                return result
            end
        end
        return result
    else
        -- complex variant, used in register (multiple words)
        local result = 0
        for i=1,nb < na and nb or na do
            local eai, ebi = ea[i], eb[i]
            for j=1,#sequence do
                local m = sequence[j]
                result = basicsort(eai[m],ebi[m])
                if result ~= 0 then
                    return result
                end
            end
            if result ~= 0 then
                return result
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

-- local function numify(s)
--     return rep(" ",10-#s) .. s -- or format with padd
-- end

local function numify(s)
    s = digitsoffset + tonumber(s) -- alternatively we can create a consecutive range
    if s > digitsmaximum then
        s = digitsmaximum
    end
    return utfchar(s)
end

function sorters.strip(str) -- todo: only letters and such utf.gsub("([^%w%d])","")
    if str then
        str = gsub(str,"\\%S*","")
        str = gsub(str,"%s","\001") -- can be option
        str = gsub(str,"[%s%[%](){}%$\"\']*","")
        if digits == v_numbers then
            str = gsub(str,"(%d+)",numify) -- sort numbers properly
        end
        return str
    else
        return ""
    end
end

local function firstofsplit(entry)
    -- numbers are left padded by spaces
    local split = entry.split
    if #split > 0 then
        split = split[1].ch
    else
        split = split.ch
    end
    local entry = split and split[1] or ""
    local tag = entries[entry] or "\000"
    return entry, tag
end

sorters.firstofsplit = firstofsplit

-- for the moment we use an inefficient bunch of tables but once
-- we know what combinations make sense we can optimize this

function splitters.utf(str) -- we could append m and u but this is cleaner, s is for tracing
    if #replacements > 0 then
        -- todo make an lpeg for this
        for k=1,#replacements do
            local v = replacements[k]
            str = gsub(str,v[1],v[2])
        end
    end

    local m_case, z_case, p_case, m_mapping, z_mapping, p_mapping, char, byte, n = { }, { }, { }, { }, { }, { }, { }, { }, 0
    for sc in utfcharacters(str) do
        local b = utfbyte(sc)
        if b >= digitsoffset then
            if n == 0 then
                -- we need to force number to the top
                z_case[1] = 0
                m_case[1] = 0
                p_case[1] = 0
                char[1] = sc
                byte[1] = 0
                m_mapping[1] = 0
                z_mapping[1] = 0
                p_mapping[1] = 0
                n = 2
            else
                n = n + 1
            end
            z_case[n] = b
            m_case[n] = b
            p_case[n] = b
            char[n] = sc
            byte[n] = b
            m_mapping[#m_mapping+1] = b
            z_mapping[#z_mapping+1] = b
            p_mapping[#p_mapping+1] = b
        else
            local l = lower[sc]
            n = n + 1
            l = l and utfbyte(l) or lccodes[b]
            z_case[n] = l
            if l ~= b then
                m_case[n] = l - 1
                p_case[n] = l + 1
            else
                m_case[n] = l
                p_case[n] = l
            end
            char[n], byte[n] = sc, b
            local msc = m_mappings[sc]
            for i=1,#msc do
                m_mapping[#m_mapping+1] = msc[i]
            end
            local zsc = z_mappings[sc]
            for i=1,#zsc do
                z_mapping[#z_mapping+1] = zsc[i]
            end
            local psc = p_mappings[sc]
            for i=1,#psc do
                p_mapping[#p_mapping+1] = psc[i]
            end
        end
    end

    local t = {
        ch = char,
        uc = byte,
        mc = m_case,
        zc = z_case,
        pc = p_case,
        mm = m_mapping,
        zm = z_mapping,
        pm = p_mapping,
    }

 -- table.print(t)

    return t
end


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
            local tt, li = { }, split[i].ch
            for j=1,#li do
                local lij = li[j]
                tt[j] = utfbyte(lij) > ignoredoffset and "[]" or lij
            end
            t[i] = concat(tt)
        end
        return concat(t," + ")
    else
        local t, li = { }, split.ch
        for j=1,#li do
            local lij = li[j]
            t[j] = utfbyte(lij) > ignoredoffset and "[]" or lij
        end
        return concat(t)
    end
end

function sorters.sort(entries,cmp)
    if trace_tests then
        for i=1,#entries do
            report_sorters("entry %s",table.serialize(entries[i].split,i))
        end
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
