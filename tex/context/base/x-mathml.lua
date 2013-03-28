if not modules then modules = { } end modules ['x-mathml'] = {
    version   = 1.001,
    comment   = "companion to x-mathml.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This needs an upgrade to the latest greatest mechanisms.

local type, next = type, next
local format, lower, find, gsub = string.format, string.lower, string.find, string.gsub
local strip = string.strip
local xmlsprint, xmlcprint, xmltext, xmlcontent = xml.sprint, xml.cprint, xml.text, xml.content
local getid = lxml.getid
local utfchar, utfcharacters, utfvalues = utf.char, utf.characters, utf.values
local lpegmatch = lpeg.match

local mathml      = { }
moduledata.mathml = mathml
lxml.mathml       = mathml -- for the moment

-- an alternative is to remap to private codes, where we can have
-- different properties .. to be done; this will move and become
-- generic; we can then make the private ones active in math mode

-- todo: handle opening/closing mo's here ... presentation mml is such a mess ...

characters.registerentities()

local doublebar = utfchar(0x2016)

local n_replacements = {
--  [" "]              = utfchar(0x2002),  -- "&textspace;" -> tricky, no &; in mkiv
    ["."]              = "{.}",
    [","]              = "{,}",
    [" "]              = "",
}

local l_replacements = { -- in main table
    ["|"]              = "\\mmlleftdelimiter\\vert",
    ["{"]              = "\\mmlleftdelimiter\\lbrace",
    ["("]              = "\\mmlleftdelimiter(",
    ["["]              = "\\mmlleftdelimiter[",
    ["<"]              = "\\mmlleftdelimiter<",
    [doublebar]        = "\\mmlleftdelimiter\\Vert",
}
local r_replacements = { -- in main table
    ["|"]              = "\\mmlrightdelimiter\\vert",
    ["}"]              = "\\mmlrightdelimiter\\rbrace",
    [")"]              = "\\mmlrightdelimiter)",
    ["]"]              = "\\mmlrightdelimiter]",
    [">"]              = "\\mmlrightdelimiter>",
    [doublebar]        = "\\mmlrightdelimiter\\Vert",
}

-- todo: play with asciimode and avoid mmlchar

local o_replacements = { -- in main table
    ["@l"]             = "\\mmlleftdelimiter.",
    ["@r"]             = "\\mmlrightdelimiter.",
    ["{"]              = "\\mmlleftdelimiter \\lbrace",
    ["}"]              = "\\mmlrightdelimiter\\rbrace",
    ["|"]              = "\\mmlleftorrightdelimiter\\vert",
    [doublebar]        = "\\mmlleftorrightdelimiter\\Vert",
    ["("]              = "\\mmlleftdelimiter(",
    [")"]              = "\\mmlrightdelimiter)",
    ["["]              = "\\mmlleftdelimiter[",
    ["]"]              = "\\mmlrightdelimiter]",
 -- ["<"]              = "\\mmlleftdelimiter<",
 -- [">"]              = "\\mmlrightdelimiter>",
    ["#"]              = "\\mmlchar{35}",
    ["$"]              = "\\mmlchar{36}", -- $
    ["%"]              = "\\mmlchar{37}",
    ["&"]              = "\\mmlchar{38}",
    ["^"]              = "\\mmlchar{94}{}", -- strange, sometimes luatex math sees the char instead of \char
    ["_"]              = "\\mmlchar{95}{}", -- so we need the {}
    ["~"]              = "\\mmlchar{126}",
    [" "]              = "",
    ["°"]              = "^\\circ", -- hack

 -- [utfchar(0xF103C)] = "\\mmlleftdelimiter<",
    [utfchar(0xF1026)] = "\\mmlchar{38}",
 -- [utfchar(0xF103E)] = "\\mmlleftdelimiter>",

}

local simpleoperatorremapper = utf.remapper(o_replacements)

--~ languages.data.labels.functions

local i_replacements = {
    ["sin"]         = "\\mathopnolimits{sin}",
    ["cos"]         = "\\mathopnolimits{cos}",
    ["abs"]         = "\\mathopnolimits{abs}",
    ["arg"]         = "\\mathopnolimits{arg}",
    ["codomain"]    = "\\mathopnolimits{codomain}",
    ["curl"]        = "\\mathopnolimits{curl}",
    ["determinant"] = "\\mathopnolimits{det}",
    ["divergence"]  = "\\mathopnolimits{div}",
    ["domain"]      = "\\mathopnolimits{domain}",
    ["gcd"]         = "\\mathopnolimits{gcd}",
    ["grad"]        = "\\mathopnolimits{grad}",
    ["identity"]    = "\\mathopnolimits{id}",
    ["image"]       = "\\mathopnolimits{image}",
    ["lcm"]         = "\\mathopnolimits{lcm}",
    ["lim"]         = "\\mathopnolimits{lim}",
    ["max"]         = "\\mathopnolimits{max}",
    ["median"]      = "\\mathopnolimits{median}",
    ["min"]         = "\\mathopnolimits{min}",
    ["mode"]        = "\\mathopnolimits{mode}",
    ["mod"]         = "\\mathopnolimits{mod}",
    ["polar"]       = "\\mathopnolimits{Polar}",
    ["exp"]         = "\\mathopnolimits{exp}",
    ["ln"]          = "\\mathopnolimits{ln}",
    ["log"]         = "\\mathopnolimits{log}",
    ["sin"]         = "\\mathopnolimits{sin}",
    ["arcsin"]      = "\\mathopnolimits{arcsin}",
    ["sinh"]        = "\\mathopnolimits{sinh}",
    ["arcsinh"]     = "\\mathopnolimits{arcsinh}",
    ["cos"]         = "\\mathopnolimits{cos}",
    ["arccos"]      = "\\mathopnolimits{arccos}",
    ["cosh"]        = "\\mathopnolimits{cosh}",
    ["arccosh"]     = "\\mathopnolimits{arccosh}",
    ["tan"]         = "\\mathopnolimits{tan}",
    ["arctan"]      = "\\mathopnolimits{arctan}",
    ["tanh"]        = "\\mathopnolimits{tanh}",
    ["arctanh"]     = "\\mathopnolimits{arctanh}",
    ["cot"]         = "\\mathopnolimits{cot}",
    ["arccot"]      = "\\mathopnolimits{arccot}",
    ["coth"]        = "\\mathopnolimits{coth}",
    ["arccoth"]     = "\\mathopnolimits{arccoth}",
    ["csc"]         = "\\mathopnolimits{csc}",
    ["arccsc"]      = "\\mathopnolimits{arccsc}",
    ["csch"]        = "\\mathopnolimits{csch}",
    ["arccsch"]     = "\\mathopnolimits{arccsch}",
    ["sec"]         = "\\mathopnolimits{sec}",
    ["arcsec"]      = "\\mathopnolimits{arcsec}",
    ["sech"]        = "\\mathopnolimits{sech}",
    ["arcsech"]     = "\\mathopnolimits{arcsech}",
    [" "]           = "",

    ["false"]       = "{\\mr false}",
    ["notanumber"]  = "{\\mr NaN}",
    ["otherwise"]   = "{\\mr otherwise}",
    ["true"]        = "{\\mr true}",
    ["declare"]     = "{\\mr declare}",
    ["as"]          = "{\\mr as}",
}

-- we could use a metatable or when accessing fallback on the
-- key but at least we now have an overview

local csymbols = {
    arith1 = {
        lcm                 = "lcm",
        big_lcm             = "lcm",
        gcd                 = "gcd",
        big_gcd             = "big_gcd",
        plus                = "plus",
        unary_minus         = "minus",
        minus               = "minus",
        times               = "times",
        divide              = "divide",
        power               = "power",
        abs                 = "abs",
        root                = "root",
        sum                 = "sum",
        product             = "product",
    },
    fns = {
        domain              = "domain",
        range               = "codomain",
        image               = "image",
        identity            = "ident",
     -- left_inverse        = "",
     -- right_inverse       = "",
        inverse             = "inverse",
        left_compose        = "compose",
        lambda              = "labmda",
    },
    linalg1 = {
        vectorproduct       = "vectorproduct",
        scalarproduct       = "scalarproduct",
        outerproduct        = "outerproduct",
        transpose           = "transpose",
        determinant         = "determinant",
        vector_selector     = "selector",
     -- matrix_selector     = "matrix_selector",
    },
    logic1 = {
        equivalent          = "equivalent",
        ["not"]             = "not",
        ["and"]             = "and",
     -- big_and             = "",
        ["xor"]             = "xor",
     -- big_xor             = "",
        ["or"]              = "or",
     -- big-or              =  "",
        implies             = "implies",
        ["true"]            = "true",
        ["false"]           = "false",
    },
    nums1 = {
     -- based_integer       = "based_integer"
        rational            = "rational",
        inifinity           = "infinity",
        e                   = "expenonentiale",
        i                   = "imaginaryi",
        pi                  = "pi",
        gamma               = "gamma",
        NaN                 = "NaN",
    },
    relation1 = {
        eq                  = "eq",
        lt                  = "lt",
        gt                  = "gt",
        neq                 = "neq",
        leq                 = "leq",
        geq                 = "geq",
        approx              = "approx",
    },
    set1 = {
        cartesian_product   = "cartesianproduct",
        empty_set           = "emptyset",
        map                 = "map",
        size                = "card",
    -- suchthat             = "suchthat",
        set                 = "set",
        intersect           = "intersect",
    -- big_intersect        = "",
        union               = "union",
    -- big_union            = "",
        setdiff             = "setdiff",
        subset              = "subset",
        ["in"]              = "in",
        notin               = "notin",
        prsubset            = "prsubset",
        notsubset           = "notsubset",
        notprsubset         = "notprsubset",
    },
    veccalc1 = {
        divergence          = "divergence",
        grad                = "grad",
        curl                = "curl",
        laplacian           = "laplacian",
        Laplacian           = "laplacian",
    },
    calculus1 = {
        diff                = "diff",
     -- nthdiff             = "",
        partialdiff         = "partialdiff",
        int                 = "int",
     -- defint              = "defint",
    },
    integer1 = {
        factorof            = "factorof",
        factorial           = "factorial",
        quotient            = "quotient",
        remainder           = "rem",
    },
    linalg2 = {
        vector              = "vector",
        matrix              = "matrix",
        matrixrow           = "matrixrow",
    },
    mathmkeys = {
     -- equiv               = "",
     -- contentequiv        =  "",
     -- contentequiv_strict = "",
    },
    rounding1 = {
        ceiling             = "ceiling",
        floor               = "floor",
     -- trunc               = "trunc",
     -- round               = "round",
    },
    setname1 = {
        P                   = "primes",
        N                   = "naturalnumbers",
        Z                   = "integers",
        rationals           = "rationals",
        R                   = "reals",
        complexes           = "complexes",
    },
    complex1 = {
     -- complex_cartesian   = "complex_cartesian", -- ci ?
        real                = "real",
        imaginary           = "imaginary",
     -- complex_polar       = "complex_polar", -- ci ?
        argument            = "arg",
        conjugate           = "conjugate",
    },
    interval1 = { -- not an apply
     -- integer_interval    = "integer_interval",
        interval            = "interval",
        interval_oo         = { tag = "interval", closure = "open" },
        interval_cc         = { tag = "interval", closure = "closed" },
        interval_oc         = { tag = "interval", closure = "open-closed" },
        interval_co         = { tag = "interval", closure = "closed-open" },
    },
    linalg3 = {
     -- vector              = "vector.column",
     -- matrixcolumn        = "matrixcolumn",
     -- matrix              = "matrix.column",
    },
    minmax1 = {
        min                 = "min",
     -- big_min             = "",
        max                 = "max",
     -- big_max             = "",
    },
    piece1 = {
        piecewise           = "piecewise",
        piece               = "piece",
        otherwise           = "otherwise",
    },
    error1 = {
     -- unhandled_symbol    = "",
     -- unexpected_symbol   = "",
     -- unsupported_CD      = "",
    },
    limit1 = {
     -- limit               = "limit",
     -- both_sides          = "both_sides",
     -- above               = "above",
     -- below               = "below",
     -- null                = "null",
        tendsto             = "tendsto",
    },
    list1 = {
     -- map                 = "",
     -- suchthat            = "",
     -- list                = "list",
    },
    multiset1 = {
        size                = { tag = "card",             type = "multiset" },
        cartesian_product   = { tag = "cartesianproduct", type = "multiset" },
        empty_set           = { tag = "emptyset",         type = "multiset" },
     -- multi_set           = { tag = "multiset",         type = "multiset" },
        intersect           = { tag = "intersect",        type = "multiset" },
     -- big_intersect       = "",
        union               = { tag = "union",            type = "multiset" },
     -- big_union           = "",
        setdiff             = { tag = "setdiff",          type = "multiset" },
        subset              = { tag = "subset",           type = "multiset" },
        ["in"]              = { tag = "in",               type = "multiset" },
        notin               = { tag = "notin",            type = "multiset" },
        prsubset            = { tag = "prsubset",         type = "multiset" },
        notsubset           = { tag = "notsubset",        type = "multiset" },
        notprsubset         = { tag = "notprsubset",      type = "multiset" },
    },
    quant1 = {
        forall              = "forall",
        exists              = "exists",
    },
    s_dist = {
     -- mean                = "mean.dist",
     -- sdev                = "sdev.dist",
     -- variance            = "variance.dist",
     -- moment              = "moment.dist",
    },
    s_data = {
        mean                = "mean",
        sdev                = "sdev",
        variance            = "vriance",
        mode                = "mode",
        median              = "median",
        moment              = "moment",
    },
    transc1 = {
        log                 = "log",
        ln                  = "ln",
        exp                 = "exp",
        sin                 = "sin",
        cos                 = "cos",
        tan                 = "tan",
        sec                 = "sec",
        csc                 = "csc",
        cot                 = "cot",
        sinh                = "sinh",
        cosh                = "cosh",
        tanh                = "tanh",
        sech                = "sech",
        csch                = "cscs",
        coth                = "coth",
        arcsin              = "arcsin",
        arccos              = "arccos",
        arctan              = "arctan",
        arcsec              = "arcsec",
        arcscs              = "arccsc",
        arccot              = "arccot",
        arcsinh             = "arcsinh",
        arccosh             = "arccosh",
        arctanh             = "arstanh",
        arcsech             = "arcsech",
        arccsch             = "arccsch",
        arccoth             = "arccoth",
    },
}

function xml.functions.remapmmlcsymbol(e)
    local at = e.at
    local cd = at.cd
    if cd then
        cd = csymbols[cd]
        if cd then
            local tx = e.dt[1]
            if tx and tx ~= "" then
                local tg = cd[tx]
                if tg then
                    at.cd = nil
                    at.cdbase = nil
                    e.dt = { }
                    if type(tg) == "table" then
                        for k, v in next, tg do
                            if k == "tag" then
                                e.tg = v
                            else
                                at[k] = v
                            end
                        end
                    else
                        e.tg = tg
                    end
                end
            end
        end
    end
end

function xml.functions.remapmmlbind(e)
    e.tg = "apply"
end

function xml.functions.remapopenmath(e)
    local tg = e.tg
    if tg == "OMOBJ" then
        e.tg = "math"
    elseif tg == "OMA" then
        e.tg = "apply"
    elseif tg == "OMB" then
        e.tg = "apply"
    elseif tg == "OMS" then
        local at = e.at
        e.tg = "csymbol"
        e.dt = { at.name or "unknown" }
        at.name = nil
    elseif tg == "OMV" then
        local at = e.at
        e.tg = "ci"
        e.dt = { at.name or "unknown" }
        at.name = nil
    elseif tg == "OMI" then
        e.tg = "ci"
    end
    e.rn = "mml"
end

function mathml.checked_operator(str)
    context(simpleoperatorremapper(str))
end

function mathml.stripped(str)
    context(strip(str))
end

function mathml.mn(id,pattern)
    -- maybe at some point we need to interpret the number, but
    -- currently we assume an upright font
    local str = xmlcontent(getid(id)) or ""
    local rep = gsub(str,"&.-;","")
    local rep = gsub(rep,"(%s+)",utfchar(0x205F)) -- medspace e.g.: twenty one (nbsp is not seen)
    local rep = gsub(rep,".",n_replacements)
    context.mn(rep)
end

function mathml.mo(id)
    local str = xmlcontent(getid(id)) or ""
    local rep = gsub(str,"&.-;","") -- todo
    context(simpleoperatorremapper(rep))
end

function mathml.mi(id)
    -- we need to strip comments etc .. todo when reading in tree
    local e = getid(id)
    local str = e.dt
    if type(str) == "string" then
        local n = #str
        if n == 0 then
            -- nothing to do
        elseif n == 1 then
            local str = gsub(str[1],"&.-;","") -- bah
            local rep = i_replacements[str]
            if not rep then
                rep = gsub(str,".",i_replacements)
            end
            context(rep)
         -- context.mi(rep)
        else
            context.xmlflush(id) -- xmlsprint or so
        end
    else
        context.xmlflush(id) -- xmlsprint or so
    end
end

function mathml.mfenced(id) -- multiple separators
    id = getid(id)
    local left, right, separators = id.at.open or "(", id.at.close or ")", id.at.separators or ","
    local l, r = l_replacements[left], r_replacements[right]
    context.enabledelimiter()
    if l then
        context(l_replacements[left] or o_replacements[left] or "")
    else
        context(o_replacements["@l"])
        context(left)
    end
    context.disabledelimiter()
    local collected = lxml.filter(id,"/*") -- check the *
    if collected then
        local n = #collected
        if n == 0 then
            -- skip
        elseif n == 1 then
            xmlsprint(collected[1]) -- to be checked
        else
            local t = utf.split(separators,true)
            for i=1,n do
                xmlsprint(collected[i]) -- to be checked
                if i < n then
                    local m = t[i] or t[#t] or ""
                    if m == "|" then
                        m = "\\enabledelimiter\\middle|\\relax\\disabledelimiter"
                    elseif m == doublebar then
                        m = "\\enabledelimiter\\middle|\\relax\\disabledelimiter"
                    elseif m == "{" then
                        m = "\\{"
                    elseif m == "}" then
                        m = "\\}"
                    end
                    context(m)
                end
            end
        end
    end
    context.enabledelimiter()
    if r then
        context(r_replacements[right] or o_replacements[right] or "")
    else
        context(right)
        context(o_replacements["@r"])
    end
    context.disabledelimiter()
end

--~ local function flush(e,tag,toggle)
--~     if toggle then
--~         context("^{")
--~     else
--~         context("_{")
--~     end
--~     if tag == "none" then
--~         context("{}")
--~     else
--~         xmlsprint(e.dt)
--~     end
--~     if not toggle then
--~         context("}")
--~     else
--~         context("}{}")
--~     end
--~     return not toggle
--~ end

local function flush(e,tag,toggle)
    if tag == "none" then
     -- if not toggle then
        context("{}") -- {} starts a new ^_ set
     -- end
    elseif toggle then
        context("^{")
        xmlsprint(e.dt)
        context("}{}") -- {} starts a new ^_ set
    else
        context("_{")
        xmlsprint(e.dt)
        context("}")
    end
    return not toggle
end

function mathml.mmultiscripts(id)
    local done, toggle = false, false
    for e in lxml.collected(id,"/*") do
        local tag = e.tg
        if tag == "mprescripts" then
            context("{}")
            done = true
        elseif done then
            toggle = flush(e,tag,toggle)
        end
    end
    local done, toggle = false, false
    for e in lxml.collected(id,"/*") do
        local tag = e.tg
        if tag == "mprescripts" then
            break
        elseif done then
            toggle = flush(e,tag,toggle)
        else
            xmlsprint(e.dt)
            done = true
        end
    end
end

local columnalignments = {
    left   = "flushleft",
    right  = "flushright",
    center = "middle",
}

local rowalignments = {
    top      = "high",
    bottom   = "low",
    center   = "lohi",
    baseline = "top",
    axis     = "lohi",
}

local frametypes = {
    none   = "off",
    solid  = "on",
    dashed = "on",
}

-- crazy element ... should be a proper structure instead of such a mess

function mathml.mcolumn(root)
    root = getid(root)
    local matrix, numbers = { }, 0
    local function collect(m,e)
        local tag = e.tg
        if tag == "mi" or tag == "mn" or tag == "mo" or tag == "mtext" then
            local str = xmltext(e)
            str = gsub(str,"&.-;","")
            for s in utfcharacters(str) do
                m[#m+1] = { tag, s }
            end
            if tag == "mn" then
                local n = utf.len(str)
                if n > numbers then
                    numbers = n
                end
            end
        elseif tag == "mspace" or tag == "mline" then
            local str = e.at.spacing or ""
            for s in utfcharacters(str) do
                m[#m+1] = { tag, s }
            end
     -- elseif tag == "mline" then
     --     m[#m+1] = { tag, e }
        end
    end
    for e in lxml.collected(root,"/*") do
        local m = { }
        matrix[#matrix+1] = m
        if e.tg == "mrow" then
            -- only one level
            for e in lxml.collected(e,"/*") do
                collect(m,e)
            end
        else
            collect(m,e)
        end
    end
    context.halign()
    context.bgroup()
    context([[\hss\startimath\alignmark\stopimath\aligntab\startimath\alignmark\stopimath\cr]])
    for i=1,#matrix do
        local m = matrix[i]
        local mline = true
        for j=1,#m do
            if m[j][1] ~= "mline" then
                mline = false
                break
            end
        end
        if mline then
            context.noalign([[\obeydepth\nointerlineskip]])
        end
        for j=1,#m do
            local mm = m[j]
            local tag, chr = mm[1], mm[2]
            if tag == "mline" then
                -- This code is under construction ... I need some real motivation
                -- to deal with this kind of crap.
--~                 local n, p = true, true
--~                 for c=1,#matrix do
--~                     local mc = matrix[c][j]
--~                     if mc then
--~                         mc = mc[2]
--~                         if type(mc) ~= "string" then
--~                             n, p = false, false
--~                             break
--~                         elseif find(mc,"^[%d ]$") then -- rangecheck is faster
--~                             -- digit
--~                         elseif not find(mc,"^[%.%,]$") then -- rangecheck is faster
--~                             -- punctuation
--~                         else
--~                             n = false
--~                             break
--~                         end
--~                     end
--~                 end
--~                 if n then
--~                     chr = "\\mmlmcolumndigitrule"
--~                 elseif p then
--~                     chr = "\\mmlmcolumnpunctuationrule"
--~                 else
--~                     chr = "\\mmlmcolumnsymbolrule" -- should be widest char
--~                 end
                chr = "\\hrulefill"
            elseif tag == "mspace" then
                chr = "\\mmlmcolumndigitspace" -- utfchar(0x2007)
            end
            if j == numbers + 1 then
                context("\\aligntab")
            end
            local nchr = n_replacements[chr]
            context(nchr or chr)
        end
        context.crcr()
    end
    context.egroup()
end

local spacesplitter = lpeg.tsplitat(" ")

function mathml.mtable(root)
    -- todo: align, rowspacing, columnspacing, rowlines, columnlines
    root = getid(root)
    local at           = root.at
    local rowalign     = at.rowalign
    local columnalign  = at.columnalign
    local frame        = at.frame
    local rowaligns    = rowalign    and lpegmatch(spacesplitter,rowalign)
    local columnaligns = columnalign and lpegmatch(spacesplitter,columnalign)
    local frames       = frame       and lpegmatch(spacesplitter,frame)
    local framespacing = at.framespacing or "0pt"
    local framespacing = at.framespacing or "-\\ruledlinewidth" -- make this an option

    context.bTABLE { frame = frametypes[frame or "none"] or "off", offset = framespacing }
    for e in lxml.collected(root,"/(mml:mtr|mml:mlabeledtr)") do
        context.bTR()
        local at = e.at
        local col = 0
        local rfr = at.frame       or (frames       and frames      [#frames])
        local rra = at.rowalign    or (rowaligns    and rowaligns   [#rowaligns])
        local rca = at.columnalign or (columnaligns and columnaligns[#columnaligns])
        local ignorelabel = e.tg == "mlabeledtr"
        for e in lxml.collected(e,"/mml:mtd") do -- nested we can use xml.collected
            col = col + 1
            if ignorelabel and col == 1 then
                -- get rid of label, should happen at the document level
            else
                local at = e.at
                local rowspan, columnspan = at.rowspan or 1, at.columnspan or 1
                local cra = rowalignments   [at.rowalign    or (rowaligns    and rowaligns   [col]) or rra or "center"] or "lohi"
                local cca = columnalignments[at.columnalign or (columnaligns and columnaligns[col]) or rca or "center"] or "middle"
                local cfr = frametypes      [at.frame       or (frames       and frames      [col]) or rfr or "none"  ] or "off"
                context.bTD { align = format("{%s,%s}",cra,cca), frame = cfr, nx = columnspan, ny = rowspan }
                context.startimath()
                context.ignorespaces()
                xmlcprint(e)
                context.stopimath()
                context.removeunwantedspaces()
                context.eTD()
            end
        end
     -- if e.tg == "mlabeledtr" then
     --     context.bTD()
     --     xmlcprint(xml.first(e,"/!mml:mtd"))
     --     context.eTD()
     -- end
        context.eTR()
    end
    context.eTABLE()
end

function mathml.csymbol(root)
    root = getid(root)
    local at = root.at
    local encoding = at.encoding or ""
    local hash = url.hashed(lower(at.definitionUrl or ""))
    local full = hash.original or ""
    local base = hash.path or ""
    local text = strip(xmltext(root) or "")
    context.mmlapplycsymbol(full,base,encoding,text)
end

function mathml.menclosepattern(root)
    root = getid(root)
    local a = root.at.notation
    if a and a ~= "" then
        context("mml:enclose:",(gsub(a," +",",mml:enclose:")))
    end
end

function xml.is_element(e,name)
    return type(e) == "table" and (not name or e.tg == name)
end

function mathml.cpolar_a(root)
    root = getid(root)
    local dt = root.dt
    context.mathopnolimits("Polar")
    context.left(false,"(")
    for k=1,#dt do
        local dk = dt[k]
        if xml.is_element(dk,"sep") then
            context(",")
        else
            xmlsprint(dk)
        end
    end
    context.right(false,")")
end
