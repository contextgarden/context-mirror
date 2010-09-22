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

local lccodes     = characters.lccodes
local shcodes     = characters.shcodes
local lcchars     = characters.lcchars
local shchars     = characters.shchars

local variables   = interfaces.variables

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
    }
}

local sorters   = sorters
local constants = sorters.constants

local data, language, method
local replacements, mappings, entries, orders, lower, upper

local mte = {
    __index = function(t,k)
        local el
        if k then
            local l = lower[k] or lcchars[k]
            el = rawget(t,l)
        end
        if not el then
            local l = shchars[k]
            if l and l ~= k then
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
}

local function preparetables(data)
    local orders, lower, method, mappings = data.orders, data.lower, data.method, { }
    for i=1,#orders do
        local oi = orders[i]
        mappings[oi] = 2*i
    end
    local delta = (method == variables.before or method == variables.first or method == variables.last) and -1 or 1
    local mtm = {
        __index = function(t,k)
            local n
            if k then
                local l = lower[k] or lcchars[k]
                if l then
                    local ml = rawget(t,l)
                    if ml then
                        n = ml + delta -- first
                    end
                end
                if not n then
                    l = shchars[k]
                    if l and l ~= k then
                        local ml = rawget(t,l)
                        if ml then
                            n = ml -- first or last
                        else
                            l = lower[l] or lcchars[l]
                            if l then
                                local ml = rawget(t,l)
                                if ml then
                                    n = ml + delta
                                end
                            end
                        end
                    end
                end
                if not n then
                    n = 0
                end
            else
                n = 0
            end
            rawset(t,k,n)
            return n
        end
    }
    data.mappings = mappings
    setmetatable(data.entries,mte)
    setmetatable(data.mappings,mtm)
    return mappings
end

local function update() -- prepare parent chains, needed when new languages are added
    for language, data in next, definitions do
        local parent = data.parent or "default"
        if language ~= "default" then
            setmetatable(data,{ __index = definitions[parent] or definitions.default })
        end
        data.language = language
        data.parent   = parent
        data.mappings = { } -- free temp data
    end
end

local function setlanguage(l,m)
    language = (l ~= "" and l) or constants.defaultlanguage
    data = definitions[language or constants.defaultlanguage] or definitions[constants.defaultlanguage]
    method  = (m ~= "" and m) or data.method or constants.defaultmethod
    if trace_tests then
        report_sorters("setting language '%s', method '%s'",language,method)
    end
    data.method  = method
    replacements = data.replacements
    entries      = data.entries
    orders       = data.orders
    lower        = data.lower
    upper        = data.upper
    mappings     = preparetables(data)
    return data
end

function sorters.update()
    update()
    setlanguage(language,method) -- resync current language and method
end

function sorters.setlanguage(language,method)
    update()
    setlanguage(language,method) -- new language and method
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
        local result = basicsort(ea.m,eb.m)
        if result == 0 then
            result = basicsort(ea.c,eb.c)
        end
        if result == 0 then
            result = basicsort(ea.u,eb.u)
        end
        return result
    else
        -- complex variant, used in register (multiple words)
        local result = 0
        for i=1,nb < na and nb or na do
            local eai, ebi = ea[i], eb[i]
            if result == 0 then
                result = basicsort(eai.m,ebi.m)
            end
            if result == 0 then
                result = basicsort(eai.c,ebi.c)
            end
            if result == 0 then
                result = basicsort(eai.u,ebi.u)
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
    s = digitsoffset + tonumber(s)
    if s > digitsmaximum then
        s = digitsmaximum
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
    return entry, entries[entry] or "\000"
end

sorters.firstofsplit = firstofsplit

function splitters.utf(str) -- we could append m and u but this is cleaner, s is for tracing
    if #replacements > 0 then
        -- todo make an lpeg for this
        for k=1,#replacements do
            local v = replacements[k]
            str = gsub(str,v[1],v[2])
        end
    end
    local s, u, m, c, n = { }, { }, { }, { }, 0
    if method == variables.last then
        for sc in utfcharacters(str) do
            local b = utfbyte(sc)
            local l = lower[sc]
            l = l and utfbyte(l) or lccodes[b]
            if l ~= b then l = l - 1 end -- brrrr, can clash
            n = n + 1
            s[n], u[n], m[n], c[n] = sc, b, l, mappings[sc]
        end
    elseif method == variables.first then
        for sc in utfcharacters(str) do
            local b = utfbyte(sc)
            local l = lower[sc]
            l = l and utfbyte(l) or lccodes[b]
            if l ~= b then l = l + 1 end -- brrrr, can clash
            n = n + 1
            s[n], u[n], m[n], c[n] = sc, b, l, mappings[sc]
        end
    else
        for sc in utfcharacters(str) do
            local b = utfbyte(sc)
            n = n + 1
            s[n], u[n], m[n], c[n] = sc, b, mappings[sc], b
        end
    end
    local t = { s = s, m = m, u = u, c = c }
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
            local tt, li = { }, split[i].s
            for j=1,#li do
                local lij = li[j]
                tt[j] = utfbyte(lij) > ignoredoffset and "[]" or lij
            end
            t[i] = concat(tt)
        end
        return concat(t," + ")
    else
        local t, li = { }, split.s
        for j=1,#li do
            local lij = li[j]
            t[j] = utfbyte(lij) > ignoredoffset and "[]" or lij
        end
        return concat(t)
    end
end

function sorters.sort(entries,cmp)
    if trace_tests then
        sort(entries,function(a,b)
            local r = cmp(a,b)
            report_sorters("%s %s %s (%s)",pack(a),(not r and "?") or (r<0 and "<") or (r>0 and ">") or "=",pack(b),r)
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
