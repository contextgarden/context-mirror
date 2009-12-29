if not modules then modules = { } end modules ['x-mathml'] = {
    version   = 1.001,
    comment   = "companion to x-mathml.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, pairs = type, pairs
local utf = unicode.utf8
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
local format, lower, find, gsub = string.format, string.lower, string.find, string.gsub
local utfchar, utffind, utfgmatch, utfgsub  = utf.char, utf.find, utf.gmatch, utf.gsub
local xmlsprint, xmlcprint, xmltext, xmlcontent = xml.sprint, xml.cprint, xml.text, xml.content
local lxmltext, get_id = lxml.text, lxml.get_id
local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues
local lpegmatch = lpeg.match

lxml.mml = lxml.mml or { }

-- an alternative is to remap to private codes, where we can have
-- different properties .. to be done; this will move and become
-- generic

-- todo: handle opening/closing mo's here ... presentation mml is such a mess ...

local doublebar = utfchar(0x2016)

local n_replacements = {
--  [" "] = utfchar(0x2002),  -- "&textspace;" -> tricky, no &; in mkiv
    ["."] = "{.}",
    [","] = "{,}",
    [" "] = "",
}

local l_replacements = { -- in main table
    ["|"]  = "\\mmlleftdelimiter\\vert",
    ["{"]  = "\\mmlleftdelimiter\\lbrace",
    ["("]  = "\\mmlleftdelimiter(",
    ["["]  = "\\mmlleftdelimiter[",
    ["<"]  = "\\mmlleftdelimiter<",
    [doublebar] = "\\mmlleftdelimiter\\Vert",
}
local r_replacements = { -- in main table
    ["|"]  = "\\mmlrightdelimiter\\vert",
    ["}"]  = "\\mmlrightdelimiter\\rbrace",
    [")"]  = "\\mmlrightdelimiter)",
    ["]"]  = "\\mmlrightdelimiter]",
    [">"]  = "\\mmlrightdelimiter>",
    [doublebar] = "\\mmlrightdelimiter\\Vert",
}

local o_replacements = { -- in main table
    ["@l"] = "\\mmlleftdelimiter.",
    ["@r"] = "\\mmlrightdelimiter.",
    ["{"]  = "\\mmlleftdelimiter\\lbrace",
    ["}"]  = "\\mmlrightdelimiter\\rbrace",
    ["|"]  = "\\mmlleftorrightdelimiter\\vert",
    [doublebar]  = "\\mmlleftorrightdelimiter\\Vert",
    ["("]  = "\\mmlleftdelimiter(",
    [")"]  = "\\mmlrightdelimiter)",
    ["["]  = "\\mmlleftdelimiter[",
    ["]"]  = "\\mmlrightdelimiter]",
    ["<"]  = "\\mmlleftdelimiter<",
    [">"]  = "\\mmlrightdelimiter>",
    ["#"]  = "\\mmlchar{35}",
    ["$"]  = "\\mmlchar{36}", -- $
    ["%"]  = "\\mmlchar{37}",
    ["&"]  = "\\mmlchar{38}",
    ["^"]  = "\\mmlchar{94}{}", -- strange, sometimes luatex math sees the char instead of \char
    ["_"]  = "\\mmlchar{95}{}", -- so we need the {}
    ["~"]  = "\\mmlchar{126}",
    [" "]  = "",
    ["°"]  = "^\\circ", -- hack

    [utfchar(0xF103C)] = "\\mmlleftdelimiter<",
    [utfchar(0xF1026)] = "\\mmlchar{38}",
    [utfchar(0xF103E)] = "\\mmlleftdelimiter>",

}

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

local csymbols = {
    arith1 = {
        lcm = "lcm",
        big_lcm = "lcm",
        gcd = "gcd",
        big_gcd = "big_gcd",
        plus = "plus",
        unary_minus = "minus",
        minus = "minus",
        times = "times",
        divide = "divide",
        power = "power",
        abs = "abs",
        root = "root",
        sum = "sum",
        product  ="product",
    },
    fns = {
        domain = "domain",
        range = "codomain",
        image = "image",
        identity = "ident",
--~         left_inverse = "",
--~         right_inverse = "",
        inverse = "inverse",
        left_compose = "compose",
        lambda = "labmda",
    },
    linalg1 = {
        vectorproduct = "vectorproduct",
        scalarproduct = "scalarproduct",
        outerproduct = "outerproduct",
        transpose = "transpose",
        determinant = "determinant",
        vector_selector = "selector",
--~         matrix_selector = "matrix_selector",
    },
    logic1 = {
        equivalent = "equivalent",
        ["not"] = "not",
        ["and"] = "and",
--~         big_and = "",
        ["xor"] = "xor",
--~         big_xor = "",
        ["or"] = "or",
--~         big-or= "",
        implies = "implies",
        ["true"] = "true",
        ["false"] = "false",
    },
    nums1 = {
--~         based_integer = "based_integer"
        rational = "rational",
        inifinity = "infinity",
        e = "expenonentiale",
        i ="imaginaryi",
        pi = "pi",
        gamma = "gamma",
        NaN, "NaN",
    },
    relation1 = {
        eq = "eq",
        lt = "lt",
        gt = "gt",
        neq = "neq",
        leq = "leq",
        geq = "geq",
        approx = "approx",
    },
    set1 = {
        cartesian_product = "cartesianproduct",
        empty_set = "emptyset",
        map = "map",
        size = "card",
--~         suchthat = "suchthat",
        set = "set",
        intersect = "intersect",
--~         big_intersect = "",
        union = "union",
--~         big_union = "",
        setdiff = "setdiff",
        subset = "subset",
        ["in"] = "in",
        notin = "notin",
        prsubset = "prsubset",
        notsubset = "notsubset",
        notprsubset = "notprsubset",
    },
    veccalc1 = {
        divergence = "divergence",
        grad = "grad",
        curl = "curl",
        Laplacian = "laplacian",
    },
    calculus1 = {
        diff = "diff",
--~         nthdiff = "",
        partialdiff = "partialdiff",
        int = "int",
--~         defint = "defint",
    },
    integer1 = {
        factorof = "factorof",
        factorial = "factorial",
        quotient = "quotient",
        remainder = "rem",
    },
    linalg2 = {
        vector = "vector",
        matrix = "matrix",
        matrixrow = "matrixrow",
    },
    mathmkeys = {
--~         equiv = "",
--~         contentequiv =  "",
--~         contentequiv_strict = "",
    },
    rounding1 = {
        ceiling = "ceiling",
        floor = "floor",
--~         trunc = "trunc",
--~         round = "round",
    },
    setname1 = {
        P = "primes",
        N = "naturalnumbers",
        Z = "integers",
        rationals = "rationals",
        R = "reals",
        complexes = "complexes",
    },
    complex1 = {
--~         complex_cartesian = "complex_cartesian", -- ci ?
        real = "real",
        imaginary = "imaginary",
--~         complex_polar = "complex_polar", -- ci ?
        argument = "arg",
        conjugate = "conjugate",
    },
    interval1 = { -- not an apply
--~         "integer_interval" = "integer_interval",
        interval = "interval",
        interval_oo = { tag = "interval", closure = "open" },
        interval_cc = { tag = "interval", closure = "closed" },
        interval_oc = { tag = "interval", closure = "open-closed" },
        interval_co = { tag = "interval", closure = "closed-open" },
    },
    linalg3 = {
--~         vector = "vector.column",
--~         matrixcolumn = "matrixcolumn",
--~         matrix = "matrix.column",
    },
    minmax1 = {
        min = "min",
--~         big_min = "",
        max = "max",
--~         big_max = "",
    },
    piece1 = {
        piecewise = "piecewise",
        piece = "piece",
        otherwise = "otherwise",
    },
    error1 = {
--~         unhandled_symbol = "",
--~         unexpected_symbol = "",
--~         unsupported_CD = "",
    },
    limit1 = {
--~         limit = "limit",
--~         both_sides = "both_sides",
--~         above = "above",
--~         below = "below",
--~         null = "null",
        tendsto = "tendsto",
    },
    list1 = {
--~         map = "",
--~         suchthat = "",
--~         list = "list",
    },
    multiset1 = {
        size = { tag = "card", type="multiset"  },
        cartesian_product = { tag =  "cartesianproduct", type="multiset" },
        empty_set = { tag =  "emptyset", type="multiset" },
--~         multi_set = { tag =  "multiset", type="multiset" },
        intersect = { tag =  "intersect", type="multiset" },
--~         big_intersect = "",
        union = { tag =  "union", type="multiset" },
--~         big_union = "",
        setdiff = { tag =  "setdiff", type="multiset" },
        subset = { tag =  "subset", type="multiset" },
        ["in"] = { tag =  "in", type="multiset" },
        notin = { tag =  "notin", type="multiset" },
        prsubset = { tag =  "prsubset", type="multiset" },
        notsubset = { tag =  "notsubset", type="multiset" },
        notprsubset = { tag =  "notprsubset", type="multiset" },
    },
    quant1 = {
        forall = "forall",
        exists = "exists",
    },
    s_dist = {
--~         mean = "mean.dist",
--~         sdev = "sdev.dist",
--~         variance = "variance.dist",
--~         moment = "moment.dist",
    },
    s_data = {
        mean = "mean",
        sdev = "sdev",
        variance = "vriance",
        mode = "mode",
        median = "median",
        moment = "moment",
    },
    transc1 = {
        log = "log",
        ln = "ln",
        exp = "exp",
        sin = "sin",
        cos = "cos",
        tan = "tan",
        sec = "sec",
        csc = "csc",
        cot = "cot",
        sinh = "sinh",
        cosh = "cosh",
        tanh = "tanh",
        sech = "sech",
        csch = "cscs",
        coth = "coth",
        arcsin = "arcsin",
        arccos = "arccos",
        arctan = "arctan",
        arcsec = "arcsec",
        arcscs = "arccsc",
        arccot = "arccot",
        arcsinh = "arcsinh",
        arccosh = "arccosh",
        arctanh = "arstanh",
        arcsech = "arcsech",
        arccsch = "arccsch",
        arccoth = "arccoth",
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
                        for k, v in pairs(tg) do
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

function lxml.mml.checked_operator(str)
    texsprint(ctxcatcodes,(utfgsub(str,".",o_replacements)))
end

function lxml.mml.stripped(str)
    tex.sprint(ctxcatcodes,str:strip())
end

function table.keys_as_string(t)
    local k = { }
    for k,_ in pairs(t) do
        k[#k+1] = k
    end
    return concat(k,"")
end

--~ local leftdelimiters  = "[" .. table.keys_as_string(l_replacements) .. "]"
--~ local rightdelimiters = "[" .. table.keys_as_string(r_replacements) .. "]"

function characters.remapentity(chr,slot)
    texsprint(format("{\\catcode%s=13\\xdef%s{\\string%s}}",slot,utfchar(slot),chr))
end

function lxml.mml.mn(id,pattern)
    -- maybe at some point we need to interpret the number, but
    -- currently we assume an upright font
    local str = xmlcontent(get_id(id)) or ""
    str = gsub(str,"(%s+)",utfchar(0x205F)) -- medspace e.g.: twenty one (nbsp is not seen)
    texsprint(ctxcatcodes,(gsub(str,".",n_replacements)))
end

function lxml.mml.mo(id)
    local str = xmlcontent(get_id(id)) or ""
    texsprint(ctxcatcodes,(utfgsub(str,".",o_replacements)))
end

function lxml.mml.mi(id)
    local str = xmlcontent(get_id(id)) or ""
    -- str = gsub(str,"^%s*(.-)%s*$","%1")
    local rep = i_replacements[str]
    if rep then
        texsprint(ctxcatcodes,rep)
    else
        texsprint(ctxcatcodes,(gsub(str,".",i_replacements)))
    end
end

function lxml.mml.mfenced(id) -- multiple separators
    id = get_id(id)
    local left, right, separators = id.at.open or "(", id.at.close or ")", id.at.separators or ","
    local l, r = l_replacements[left], r_replacements[right]
    texsprint(ctxcatcodes,"\\enabledelimiter")
    if l then
        texsprint(ctxcatcodes,l_replacements[left] or o_replacements[left] or "")
    else
        texsprint(ctxcatcodes,o_replacements["@l"])
        texsprint(ctxcatcodes,left)
    end
    texsprint(ctxcatcodes,"\\disabledelimiter")
    local collected = lxml.filter(id,"/*") -- check the *
    if collected then
        local n = #collected
        if n == 0 then
            -- skip
        elseif n == 1 then
            xmlsprint(collected[1]) -- to be checked
--~             lxml.all(id,"/*")
        else
            local t = { }
            for s in utfgmatch(separators,"[^%s]") do
                t[#t+1] = s
            end
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
                    texsprint(ctxcatcodes,m)
                end
            end
        end
    end
    texsprint(ctxcatcodes,"\\enabledelimiter")
    if r then
        texsprint(ctxcatcodes,r_replacements[right] or o_replacements[right] or "")
    else
        texsprint(ctxcatcodes,right)
        texsprint(ctxcatcodes,o_replacements["@r"])
    end
    texsprint(ctxcatcodes,"\\disabledelimiter")
end

local function flush(e,tag,toggle)
 -- texsprint(ctxcatcodes,(toggle and "^{") or "_{")
    if toggle then
        texsprint(ctxcatcodes,"^{")
    else
        texsprint(ctxcatcodes,"_{")
    end
    if tag == "none" then
        texsprint(ctxcatcodes,"{}")
    else
        xmlsprint(e.dt)
    end
    if not toggle then
        texsprint(ctxcatcodes,"}")
    else
        texsprint(ctxcatcodes,"}{}")
    end
    return not toggle
end

function lxml.mml.mmultiscripts(id)
    local done, toggle = false, false
    for e in lxml.collected(id,"/*") do
        local tag = e.tg
        if tag == "mprescripts" then
            texsprint(ctxcatcodes,"{}")
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

function lxml.mml.mcolumn(root)
    root = get_id(root)
    local matrix, numbers = { }, 0
    local function collect(m,e)
        local tag = e.tg
        if tag == "mi" or tag == "mn" or tag == "mo" or tag == "mtext" then
            local str = xmltext(e)
            for s in utfcharacters(str) do -- utf.gmatch(str,".") btw, the gmatch was bugged
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
            for s in utfcharacters(str) do -- utf.gmatch(str,".") btw, the gmatch was bugged
                m[#m+1] = { tag, s }
            end
        elseif tag == "mline" then
            m[#m+1] = { tag, e }
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
    tex.sprint(ctxcatcodes,"\\halign\\bgroup\\hss$#$&$#$\\cr")
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
            tex.sprint(ctxcatcodes,"\\noalign{\\obeydepth\\nointerlineskip}")
        end
        for j=1,#m do
            local mm = m[j]
            local tag, chr = mm[1], mm[2]
            if tag == "mline" then
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
                tex.sprint(ctxcatcodes,"&")
            end
            local nchr = n_replacements[chr]
            tex.sprint(ctxcatcodes,nchr or chr)
        end
        tex.sprint(ctxcatcodes,"\\crcr")
    end
    tex.sprint(ctxcatcodes,"\\egroup")
end

local spacesplitter = lpeg.Ct(lpeg.splitat(" "))

function lxml.mml.mtable(root)
    -- todo: align, rowspacing, columnspacing, rowlines, columnlines
    root = get_id(root)
    local at           = root.at
    local rowalign     = at.rowalign
    local columnalign  = at.columnalign
    local frame        = at.frame
    local rowaligns    = rowalign    and lpegmatch(spacesplitter,rowalign)
    local columnaligns = columnalign and lpegmatch(spacesplitter,columnalign)
    local frames       = frame       and lpegmatch(spacesplitter,frame)
    local framespacing = at.framespacing or "0pt"
    local framespacing = at.framespacing or "-\\ruledlinewidth" -- make this an option

    texsprint(ctxcatcodes, format("\\bTABLE[frame=%s,offset=%s]",frametypes[frame or "none"] or "off",framespacing))
--~ context.bTABLE { frame = frametypes[frame or "none"] or "off", offset = framespacing }
    for e in lxml.collected(root,"/(mml:mtr|mml:mlabeledtr)") do
        texsprint(ctxcatcodes,"\\bTR")
--~ context.bTR()
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
                texsprint(ctxcatcodes,format("\\bTD[align={%s,%s},frame=%s,nx=%s,ny=%s]$\\ignorespaces",cra,cca,cfr,columnspan,rowspan))
--~ texfprint("\\bTD[align={%s,%s},frame=%s,nx=%s,ny=%s]$\\ignorespaces",cra,cca,cfr,columnspan,rowspan)
--~ context.bTD { align = format("{%s,%s}",cra,cca), frame = cfr, nx = columnspan, ny = rowspan }
--~ context.bmath()
--~ context.ignorespaces()
                xmlcprint(e)
                texsprint(ctxcatcodes,"\\removeunwantedspaces$\\eTD") -- $
--~ context.emath()
--~ context.removeunwantedspaces()
--~ context.eTD()
            end
        end
--~         if e.tg == "mlabeledtr" then
--~             texsprint(ctxcatcodes,"\\bTD")
--~             xmlcprint(xml.first(e,"/!mml:mtd"))
--~             texsprint(ctxcatcodes,"\\eTD")
--~         end
        texsprint(ctxcatcodes,"\\eTR")
--~ context.eTR()
    end
    texsprint(ctxcatcodes, "\\eTABLE")
--~ context.eTABLE()
end

function lxml.mml.csymbol(root)
    root = get_id(root)
    local at = root.at
    local encoding = at.encoding or ""
    local hash = url.hashed(lower(at.definitionUrl or ""))
    local full = hash.original or ""
    local base = hash.path or ""
    local text = string.strip(lxmltext(root))
--~     texsprint(ctxcatcodes,format("\\mmlapplycsymbol{%s}{%s}{%s}{%s}",full,base,encoding,text))
    texsprint(ctxcatcodes,"\\mmlapplycsymbol{",full,"}{",base,"}{",encoding,"}{",text,"}")
end

function lxml.mml.menclosepattern(root)
    root = get_id(root)
    local a = root.at.notation
    if a and a ~= "" then
        texsprint("mml:enclose:",gsub(a," +",",mml:enclose:"))
    end
end
