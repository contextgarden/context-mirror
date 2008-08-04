if not modules then modules = { } end modules ['x-mathml'] = {
    version   = 1.001,
    comment   = "companion to x-mathml.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

lxml     = lxml or { }
lxml.mml = lxml.mml or { }

local texsprint = tex.sprint
local format    = string.format
local utfchar   = unicode.utf8.char
local xmlsprint = xml.sprint
local xmlcprint = xml.cprint

-- an alternative is to remap to private codes, where we can have
-- different properties .. to be done; this will move and become
-- generic

local n_replacements = {
--  [" "] = utfchar(0x2002),  -- "&textspace;" -> tricky, no &; in mkiv
    ["."] = "{.}",
    [","] = "{,}",
    [" "] = "",
}

local o_replacements = { -- in main table
    ["@l"] = "\\mmlleftdelimiter.",
    ["@r"] = "\\mmlrightdelimiter.",
    ["{"]  = "\\mmlleftdelimiter\\lbrace",
    ["}"]  = "\\mmlrightdelimiter\\rbrace",
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

[utf.char(0xF103C)] = "\\mmlleftdelimiter<",
[utf.char(0xF1026)] = "\\mmlchar{38}",
[utf.char(0xF103E)] = "\\mmlleftdelimiter>",

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

function xml.functions.remapmmlcsymbol(r,d,k)
    local dk = d[k]
    local at = dk.at
    local cd = at.cd
    if cd then
        cd = csymbols[cd]
        if cd then
            local tx = dk.dt[1]
            if tx and tx ~= "" then
                local tg = cd[tx]
                if tg then
                    at.cd = nil
                    at.cdbase = nil
                    dk.dt = { }
                    if type(tg) == "table" then
                        for k, v in pairs(tg) do
                            if k == "tag" then
                                dk.tg = v
                            else
                                at[k] = v
                            end
                        end
                    else
                        dk.tg = tg
                    end
                end
            end
        end
    end
end

function xml.functions.remapmmlbind(r,d,k)
    d[k].tg = "apply"
end

function xml.functions.remapopenmath(r,d,k)
    local dk = d[k]
    local tg = dk.tg
    if tg == "OMOBJ" then
        dk.tg = "math"
    elseif tg == "OMA" then
        dk.tg = "apply"
    elseif tg == "OMB" then
        dk.tg = "apply"
    elseif tg == "OMS" then
    --  xml.functions.remapmmlcsymbol(r,d,k)
        local at = dk.at
        dk.tg = "csymbol"
        dk.dt = { at.name or "unknown" }
        at.name = nil
    elseif tg == "OMV" then
        local at = dk.at
        dk.tg = "ci"
        dk.dt = { at.name or "unknown" }
        at.name = nil
    elseif tg == "OMI" then
        dk.tg = "ci"
    end
    dk.rn = "mml"
end

function lxml.mml.checked_operator(str)
    texsprint(tex.ctxcatcodes,(utf.gsub(str,".",o_replacements)))
end

function lxml.mml.mn(id,pattern)
    -- maybe at some point we need to interpret the number, but
    -- currently we assume an upright font
    local str = xml.content(lxml.id(id),pattern) or ""
    -- str = str:gsub("^%s*(.-)%s*$","%1")
    str = str:gsub("(%s+)",utfchar(0x205F)) -- medspace e.g.: twenty one (nbsp is not seen)
    texsprint(tex.ctxcatcodes,(str:gsub(".",n_replacements)))
end

function characters.remapentity(chr,slot)
    texsprint(format("{\\catcode%s=13\\xdef%s{\\string%s}}",slot,utfchar(slot),chr))
end

function lxml.mml.mo(id,pattern)
    local str = xml.content(lxml.id(id),pattern) or ""
    texsprint(tex.ctxcatcodes,(utf.gsub(str,".",o_replacements)))
end

function lxml.mml.mi(id,pattern)
    local str = xml.content(lxml.id(id),pattern) or ""
    -- str = str:gsub("^%s*(.-)%s*$","%1")
    local rep = i_replacements[str]
    if rep then
        texsprint(tex.ctxcatcodes,rep)
    else
        texsprint(tex.ctxcatcodes,(str:gsub(".",i_replacements)))
    end
end

function lxml.mml.mfenced(id,pattern) -- multiple separators
    id = lxml.id(id)
    local left, right, separators = id.at.open or "(", id.at.close or ")", id.at.separators or ","
    local l, r = left:find("[%(%{%<%[]"), right:find("[%)%}%>%]]")
    texsprint(tex.ctxcatcodes,"\\enabledelimiter")
    if l then
        texsprint(tex.ctxcatcodes,o_replacements[left])
    else
        texsprint(tex.ctxcatcodes,o_replacements["@l"])
        texsprint(tex.ctxcatcodes,left)
    end
    texsprint(tex.ctxcatcodes,"\\disabledelimiter")
    local n = xml.count(id,pattern)
    if n == 0 then
        -- skip
    elseif n == 1 then
        lxml.all(id,pattern)
    else
        local t = { }
        for s in utf.gmatch(separators,"[^%s]") do
            t[#t+1] = s
        end
        for i=1,n do
            lxml.idx(id,pattern,i) -- kind of slow, some day ...
            if i < n then
                local m = t[i] or t[#t] or ""
                if m == "|" then
                    m = "\\enabledelimiter\\middle|\\relax\\disabledelimiter"
                elseif m == "{" then
                    m = "\\{"
                elseif m == "}" then
                    m = "\\}"
                end
                texsprint(tex.ctxcatcodes,m)
            end
        end
    end
    texsprint(tex.ctxcatcodes,"\\enabledelimiter")
    if r then
        texsprint(tex.ctxcatcodes,o_replacements[right])
    else
        texsprint(tex.ctxcatcodes,right)
        texsprint(tex.ctxcatcodes,o_replacements["@r"])
    end
    texsprint(tex.ctxcatcodes,"\\disabledelimiter")
end

local function flush(e,tag,toggle)
 -- texsprint(tex.ctxcatcodes,(toggle and "^{") or "_{")
    if toggle then
        texsprint(tex.ctxcatcodes,"^{")
    else
        texsprint(tex.ctxcatcodes,"_{")
    end
    if tag == "none" then
        texsprint(tex.ctxcatcodes,"{}")
    else
        xmlsprint(e.dt)
    end
    if not toggle then
        texsprint(tex.ctxcatcodes,"}")
    else
        texsprint(tex.ctxcatcodes,"}{}")
    end
    return not toggle
end

function lxml.mml.mmultiscripts(id)
    local done, toggle = false, false
    id = lxml.id(id)
    -- for i=1,#id.dt do local e = id.dt[i] if type(e) == table then ...
    for r, d, k in xml.elements(id,"/*") do
        local e = d[k]
        local tag = e.tg
        if tag == "mprescripts" then
            texsprint(tex.ctxcatcodes,"{}")
            done = true
        elseif done then
            toggle = flush(e,tag,toggle)
        end
    end
    local done, toggle = false, false
    for r, d, k in xml.elements(id,"/*") do
        local e = d[k]
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
    root = lxml.id(root)
    local matrix, numbers = { }, 0
    local function collect(m,dk)
        local tag = dk.tg
        if tag == "mi" or tag == "mn" or tag == "mo" or tag == "mtext" then
            local str = xml.content(dk)
            for s in str:utfcharacters() do -- utf.gmatch(str,".") btw, the gmatch was bugged
                m[#m+1] = { tag, s }
            end
            if tag == "mn" then
                local n = utf.len(str)
                if n > numbers then
                    numbers = n
                end
            end
        elseif tag == "mspace" or tag == "mline" then
            local str = dk.at.spacing or ""
            for s in str:utfcharacters() do -- utf.gmatch(str,".") btw, the gmatch was bugged
                m[#m+1] = { tag, s }
            end
        elseif tag == "mline" then
            m[#m+1] = { tag, dk }
        end
    end
    for r, d, k in xml.elements(root,"/*") do
        local m = { }
        matrix[#matrix+1] = m
        local dk = d[k]
        if dk.tg == "mrow" then
            -- only one level
            for r, d, k in xml.elements(dk,"/*") do
                collect(m,d[k])
            end
        else
            collect(m,dk)
        end
    end
    tex.sprint(tex.ctxcatcodes,"\\halign\\bgroup\\hss$#$&$#$\\cr")
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
            tex.sprint(tex.ctxcatcodes,"\\noalign{\\obeydepth\\nointerlineskip}")
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
--~                         elseif mc:find("^[%d ]$") then -- rangecheck is faster
--~                             -- digit
--~                         elseif not mc:find("^[%.%,]$") then -- rangecheck is faster
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
                chr = "\\mmlmcolumndigitspace" -- utf.char(0x2007)
            end
            if j == numbers + 1 then
                tex.sprint(tex.ctxcatcodes,"&")
            end
            local nchr = n_replacements[chr]
            tex.sprint(tex.ctxcatcodes,nchr or chr)
        end
        tex.sprint(tex.ctxcatcodes,"\\crcr")
    end
    tex.sprint(tex.ctxcatcodes,"\\egroup")
end

function lxml.mml.mtable(root)
    root = lxml.id(root)

    -- todo: align, rowspacing, columnspacing, rowlines, columnlines

    local at           = root.at
    local rowalign     = at.rowalign
    local columnalign  = at.columnalign
    local frame        = at.frame
    local rowaligns    = rowalign    and rowalign   :split(" ") -- we have a faster one
    local columnaligns = columnalign and columnalign:split(" ") -- we have a faster one
    local frames       = frame       and frame      :split(" ") -- we have a faster one
    local framespacing = at.framespacing or "0pt"
    local framespacing = at.framespacing or "-\\ruledlinewidth" -- make this an option

--~ function texsprint(a,b) print(b) end

    texsprint(tex.ctxcatcodes, format("\\bTABLE[frame=%s,offset=%s]",frametypes[frame or "none"] or "off",framespacing))
    for r, d, k in xml.elements(root,"/(mml:mtr|mml:mlabeledtr)") do
        texsprint(tex.ctxcatcodes,"\\bTR")
        local dk = d[k]
        local at = dk.at
        local col = 0
        local rfr = at.frame       or (frames       and frames      [#frames])
        local rra = at.rowalign    or (rowaligns    and rowaligns   [#rowaligns])
        local rca = at.columnalign or (columnaligns and columnaligns[#columnaligns])
        local ignorelabel = dk.tg == "mlabeledtr"
        for rr, dd, kk in xml.elements(dk,"/mml:mtd") do
            col = col + 1
            if ignorelabel and col == 1 then
                -- get rid of label, should happen at the document level
            else
                local dk = dd[kk]
                local at = dk.at
                local rowspan, columnspan = at.rowspan or 1, at.columnspan or 1
                local cra = rowalignments   [at.rowalign    or (rowaligns    and rowaligns   [col]) or rra or "center"] or "lohi"
                local cca = columnalignments[at.columnalign or (columnaligns and columnaligns[col]) or rca or "center"] or "middle"
                local cfr = frametypes      [at.frame       or (frames       and frames      [col]) or rfr or "none"  ] or "off"
                texsprint(tex.ctxcatcodes,format("\\bTD[align={%s,%s},frame=%s,nx=%s,ny=%s]$\\ignorespaces",cra,cca,cfr,columnspan,rowspan))
                xmlcprint(dk)
                texsprint(tex.ctxcatcodes,"\\removeunwantedspaces$\\eTD") -- $
            end
        end
--~         if dk.tg == "mlabeledtr" then
--~             texsprint(tex.ctxcatcodes,"\\bTD")
--~             xmlcprint(xml.first(dk,"/!mml:mtd"))
--~             texsprint(tex.ctxcatcodes,"\\eTD")
--~         end
        texsprint(tex.ctxcatcodes,"\\eTR")
    end
    texsprint(tex.ctxcatcodes, "\\eTABLE")
end

function lxml.mml.csymbol(root)
    root = lxml.id(root)
    local encoding = root.at.encoding or ""
    local hash = url.hashed((root.at.definitionUrl or ""):lower())
    local full = hash.original or ""
    local base = hash.path or ""
    local text = string.strip(xml.content(root) or "")
    texsprint(tex.ctxcatcodes,format("\\mmlapplycsymbol{%s}{%s}{%s}{%s}",full,base,encoding,text))
end

function lxml.mml.menclosepattern(root)
    root = lxml.id(root)
    local a = root.at.notation
    if a and a ~= "" then
        texsprint("mml:enclose:"..a:gsub(" +",",mml:enclose:"))
    end
end
