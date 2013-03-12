if not modules then modules = { } end modules ['math-ini'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- if needed we can use the info here to set up xetex definition files
-- the "8000 hackery influences direct characters (utf) as indirect \char's
--
-- isn't characters.data loaded already ... shortcut it here

local format = string.format
local utfchar, utfbyte = utf.char, utf.byte
local setmathcode, setdelcode = tex.setmathcode, tex.setdelcode
local texattribute = tex.attribute
local floor = math.floor

local context = context

local contextsprint = context.sprint
local contextfprint = context.fprint -- a bit inefficient

local allocate = utilities.storage.allocate

local trace_defining = false  trackers.register("math.defining", function(v) trace_defining = v end)

local report_math = logs.reporter("mathematics","initializing")

mathematics       = mathematics or { }
local mathematics = mathematics

mathematics.extrabase   = 0xFE000 -- here we push some virtuals
mathematics.privatebase = 0xFF000 -- here we push the ex

local chardata = characters.data

local families = allocate {
    mr = 0,
    mb = 1,
}

local classes = allocate {
    ord       =  0,  -- mathordcomm     mathord
    op        =  1,  -- mathopcomm      mathop
    bin       =  2,  -- mathbincomm     mathbin
    rel       =  3,  -- mathrelcomm     mathrel
    open      =  4,  -- mathopencomm    mathopen
    close     =  5,  -- mathclosecomm   mathclose
    punct     =  6,  -- mathpunctcomm   mathpunct
    alpha     =  7,  -- mathalphacomm   firstofoneargument
    accent    =  8,  -- class 0
    radical   =  9,
    xaccent   = 10,  -- class 3
    topaccent = 11,  -- class 0
    botaccent = 12,  -- class 0
    under     = 13,
    over      = 14,
    delimiter = 15,
    inner     =  0,  -- mathinnercomm   mathinner
    nothing   =  0,  -- mathnothingcomm firstofoneargument
    choice    =  0,  -- mathchoicecomm  @@mathchoicecomm
    box       =  0,  -- mathboxcomm     @@mathboxcomm
    limop     =  1,  -- mathlimopcomm   @@mathlimopcomm
    nolop     =  1,  -- mathnolopcomm   @@mathnolopcomm
    --
    ordinary    = 0, -- ord
    alphabetic  = 7, -- alpha
    unknown     = 0, -- nothing
    default     = 0, -- nothing
    punctuation = 6, -- punct
    normal      = 0, -- nothing
    opening     = 4, -- open
    closing     = 5, -- close
    binary      = 2, -- bin
    relation    = 3, -- rel
    fence       = 0, -- unknown
    diacritic   = 8, -- accent
    large       = 1, -- op
    variable    = 7, -- alphabetic
    number      = 7, -- alphabetic
}

local accents = allocate {
    topaccent = true,  [11] = true,
    botaccent = true,  [12] = true,
    under     = true,  [13] = true,
    over      = true,  [14] = true,
    unknown   = false,
}

local codes = allocate {
    ordinary       = 0, [0] = "ordinary",
    largeoperator  = 1, [1] = "largeoperator",
    binaryoperator = 2, [2] = "binaryoperator",
    relation       = 3, [3] = "relation",
    openingsymbol  = 4, [4] = "openingsymbol",
    closingsymbol  = 5, [5] = "closingsymbol",
    punctuation    = 6, [6] = "punctuation",
    variable       = 7, [7] = "variable",
}

local extensibles = allocate {
           unknown    = 0,
    l = 1, left       = 1,
    r = 2, right      = 2,
    h = 3, horizontal = 3,-- lr or rl
    u = 5, up         = 4,
    d = 5, down       = 5,
    v = 6, vertical   = 6,-- ud or du
    m = 7, mixed      = 7,
}

table.setmetatableindex(extensibles,function(t,k) t[k] = 0 return 0 end)

mathematics.extensibles     = extensibles
mathematics.classes         = classes
mathematics.codes           = codes
-----------.accents         = codes
mathematics.families        = families

-- there will be proper functions soon (and we will move this code in-line)
-- no need for " in class and family (saves space)

local function delcode(target,family,slot)
    return format('\\Udelcode%s="%X "%X ',target,family,slot)
end

local function mathchar(class,family,slot)
    return format('\\Umathchar "%X "%X "%X ',class,family,slot)
end

local function mathaccent(class,family,slot)
    return format('\\Umathaccent "%X "%X "%X ',0,family,slot) -- no class
end

local function delimiter(class,family,slot)
    return format('\\Udelimiter "%X "%X "%X ',class,family,slot)
end

local function radical(family,slot)
    return format('\\Uradical "%X "%X ',family,slot)
end

local function mathchardef(name,class,family,slot)
    return format('\\Umathchardef\\%s "%X "%X "%X ',name,class,family,slot)
end

local function mathcode(target,class,family,slot)
    return format('\\Umathcode%s="%X "%X "%X ',target,class,family,slot)
end

local function mathtopaccent(class,family,slot)
    return format('\\Umathaccent "%X "%X "%X ',0,family,slot) -- no class
end

local function mathbotaccent(class,family,slot)
    return format('\\Umathaccent bottom "%X "%X "%X ',0,family,slot) -- no class
end

local function mathtopdelimiter(class,family,slot)
    return format('\\Udelimiterover "%X "%X ',family,slot) -- no class
end

local function mathbotdelimiter(class,family,slot)
    return format('\\Udelimiterunder "%X "%X ',family,slot) -- no class
end

local escapes = characters.filters.utf.private.escapes

-- not that many so no need to reuse tables

local setmathcharacter = function(class,family,slot,unicode)
    if class <= 7 then
        setmathcode(slot,{class,family,unicode or slot})
    end
end

local setmathsynonym = function(class,family,slot,unicode,setcode)
    if setcode and class <= 7 then
        setmathcode("global",slot,{class,family,unicode})
    end
    if class == classes.open or class == classes.close then
        setdelcode("global",slot,{family,unicode,0,0})
    end
end

local setmathsymbol = function(name,class,family,slot) -- hex is nicer for tracing
    if class == classes.accent then
        contextsprint(format([[\ugdef\%s{\Umathaccent 0 "%X "%X }]],name,family,slot))
    elseif class == classes.topaccent then
        contextsprint(format([[\ugdef\%s{\Umathaccent 0 "%X "%X }]],name,family,slot))
    elseif class == classes.botaccent then
        contextsprint(format([[\ugdef\%s{\Umathbotaccent 0 "%X "%X }]],name,family,slot))
    elseif class == classes.over then
        contextsprint(format([[\ugdef\%s{\Udelimiterover "%X "%X }]],name,family,slot))
    elseif class == classes.under then
        contextsprint(format([[\ugdef\%s{\Udelimiterunder "%X "%X }]],name,family,slot))
    elseif class == classes.open or class == classes.close then
        setdelcode(slot,{family,slot,0,0})
        contextsprint(format([[\ugdef\%s{\Udelimiter "%X "%X "%X }]],name,class,family,slot))
    elseif class == classes.delimiter then
        setdelcode(slot,{family,slot,0,0})
        contextsprint(format([[\ugdef\%s{\Udelimiter 0 "%X "%X }]],name,family,slot))
    elseif class == classes.radical then
        contextsprint(format([[\ugdef\%s{\Uradical "%X "%X }]],name,family,slot))
    else
        -- beware, open/close and other specials should not end up here
     -- contextsprint(format([[\ugdef\%s{\Umathchar "%X "%X "%X }]],name,class,family,slot))
        contextsprint(format([[\Umathchardef\%s "%X "%X "%X ]],name,class,family,slot))
    end
end

local function report(class,family,unicode,name)
    local nametype = type(name)
    if nametype == "string" then
        report_math("class name %a, class %a, family %a, char %C, name %a",classname,class,family,unicode,name)
    elseif nametype == "number" then
        report_math("class name %a, class %a, family %a, char %C, number %U",classname,class,family,unicode,name)
    else
        report_math("class name %a, class %a, family %a, char %C", classname,class,family,unicode)
    end
end

-- there will be a combined \(math)chardef (tracker)

function mathematics.define(family)
    family = family or 0
    family = families[family] or family
    local data = characters.data
    for unicode, character in next, data do
        local symbol = character.mathsymbol
        local setcode = true
        if symbol then
            local other = data[symbol]
            local class = other.mathclass
            if class then
                class = classes[class] or class -- no real checks needed
                if trace_defining then
                    report(class,family,unicode,symbol)
                end
                setmathsynonym(class,family,unicode,symbol,setcode)
                setcode = false
            end
            local spec = other.mathspec
            if spec then
                for i, m in next, spec do
                    local class = m.class
                    if class then
                        class = classes[class] or class -- no real checks needed
                        setmathsynonym(class,family,unicode,symbol,setcode)
                        setcode = false
                    end
                end
            end
        end
        local mathclass = character.mathclass
        local mathspec = character.mathspec
        if mathspec then
            for i, m in next, mathspec do
                local name = m.name
                local class = m.class
                if not class then
                    class = mathclass
                elseif not mathclass then
                    mathclass = class
                end
                if class then
                    class = classes[class] or class -- no real checks needed
                    if name then
                        if trace_defining then
                            report(class,family,unicode,name)
                        end
                        setmathsymbol(name,class,family,unicode)
                    else
                        name = class == classes.variable or class == classes.number and character.adobename
                        if name then
                            if trace_defining then
                                report(class,family,unicode,name)
                            end
                        end
                    end
                    if setcode then
                        setmathcharacter(class,family,unicode,unicode)
                        setcode = false
                    end
                end
            end
        end
        if mathclass then
            local name = character.mathname
            local class = classes[mathclass] or mathclass -- no real checks needed
            if name == false then
                if trace_defining then
                    report(class,family,unicode,name)
                end
                if setcode then
                    setmathcharacter(class,family,unicode)
                end
            else
                name = name or character.contextname
                if name then
                    if trace_defining then
                        report(class,family,unicode,name)
                    end
                    setmathsymbol(name,class,family,unicode)
                else
                    if trace_defining then
                        report(class,family,unicode,character.adobename)
                    end
                end
                if setcode then
                    setmathcharacter(class,family,unicode,unicode)
                end
            end
        end
    end
end

-- needed for mathml analysis

-- we could cache

local function utfmathclass(chr, default)
    local cd = chardata[utfbyte(chr)]
    return cd and cd.mathclass or default or "unknown"
end

local function utfmathaccent(chr,default,asked)
    local cd = chardata[utfbyte(chr)]
    if not cd then
        return default or false
    end
    if asked then
        local mc = cd.mathclass
        if mc and mc == asked then
            return true
        end
        local ms = cd.mathspec
        if ms then
            for i=1,#ms do
                local msi = ms[i]
                local mc = msi.class
                if mc and mc == asked then
                    return true
                end
            end
        end
    else
        local mc = cd.mathclass
        if mc then
            return accents[mc] or default or false
        end
        local ms = cd.mathspec
        if ms then
            for i=1,#ms do
                local msi = ms[i]
                local mc = msi.class
                if mc then
                    return accents[mc] or default or false
                end
            end
        end
    end
    return default or false
end

local function utfmathstretch(chr, default) -- "h", "v", "b", ""
    local cd = chardata[utfbyte(chr)]
    return cd and cd.mathstretch or default or ""
end

local function utfmathcommand(chr,default,asked)
--     local cd = chardata[utfbyte(chr)]
--     local cmd = cd and cd.mathname
--     return cmd or default or ""
    local cd = chardata[utfbyte(chr)]
    if not cd then
        return default or ""
    end
    if asked then
        local mn = cd.mathname
        local mc = cd.mathclass
        if mn and mc and mc == asked then
            return mn
        end
        local ms = cd.mathspec
        if ms then
            for i=1,#ms do
                local msi = ms[i]
                local mn = msi.name
                if mn and msi.class == asked then
                    return mn
                end
            end
        end
    else
        local mn = cd.mathname
        if mn then
            return mn
        end
        local ms = cd.mathspec
        if ms then
            for i=1,#ms do
                local msi = ms[i]
                local mn = msi.name
                if mn then
                    return mn
                end
            end
        end
    end
    return default or ""
end

local function utfmathfiller(chr, default)
    local cd = chardata[utfbyte(chr)]
    local cmd = cd and (cd.mathfiller or cd.mathname)
    return cmd or default or ""
end

mathematics.utfmathclass   = utfmathclass
mathematics.utfmathstretch = utfmathstretch
mathematics.utfmathcommand = utfmathcommand
mathematics.utfmathfiller  = utfmathfiller

-- interfaced

function commands.utfmathclass  (...) context(utfmathclass  (...)) end
function commands.utfmathstretch(...) context(utfmathstretch(...)) end
function commands.utfmathcommand(...) context(utfmathcommand(...)) end
function commands.utfmathfiller (...) context(utfmathfiller (...)) end

function commands.doifelseutfmathaccent(chr,asked)
    commands.doifelse(utfmathaccent(chr,nil,asked))
end

-- helpers

function mathematics.big(tfmdata,unicode,n)
    local t = tfmdata.characters
    local c = t[unicode]
    if c then
        local vv = c.vert_variants or c.next and t[c.next].vert_variants
        if vv then
            local vvn = vv[n]
            return vvn and vvn.glyph or vv[#vv].glyph or unicode
        else
            local next = c.next
            while next do
                if n <= 1 then
                    return next
                else
                    n = n - 1
                    local tn = t[next].next
                    if tn then
                        next = tn
                    else
                        return next
                    end
                end
            end
        end
    end
    return unicode
end

-- experimental

-- local categories = { } -- indexed + hashed
--
-- local a_mathcategory = attributes.private("mathcategory")
--
-- local function registercategory(category,tag,data) -- always same data for tag
--     local c = categories[category]
--     if not c then
--         c = { }
--         categories[category] = c
--     end
--     local n = c[tag]
--     if not n then
--         n = #c + 1
--         c[n] = data
--         n = n * 1000 + category
--         c[tag] = n
--     end
--     return n
-- end
--
-- function mathematics.getcategory(n)
--     local category = n % 1000
--     return category, categories[category][floor(n/1000)]
-- end
--
-- mathematics.registercategory = registercategory
--
-- function commands.taggedmathfunction(tag,label)
--     if label then
--         texattribute[a_mathcategory] = registercategory(1,tag,tag)
--         context.mathlabeltext(tag)
--     else
--         texattribute[a_mathcategory] = 1
--         context(tag)
--     end
-- end

local categories       = { }
mathematics.categories = categories

local a_mathcategory = attributes.private("mathcategory")

local functions    = storage.allocate()
local noffunctions = 1000 -- offset

categories.functions = functions

function commands.taggedmathfunction(tag,label,apply)
    local delta = apply and 1000 or 0
    if label then
        local n = functions[tag]
        if not n then
            noffunctions = noffunctions + 1
            functions[noffunctions] = tag
            functions[tag] = noffunctions
            texattribute[a_mathcategory] = noffunctions + delta
        else
            texattribute[a_mathcategory] = n + delta
        end
        context.mathlabeltext(tag)
    else
        texattribute[a_mathcategory] = 1000 + delta
        context(tag)
    end
end
