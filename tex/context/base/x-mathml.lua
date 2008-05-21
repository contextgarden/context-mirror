if not modules then modules = { } end modules ['x-mathml'] = {
    version   = 1.001,
    comment   = "companion to x-mathml.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

lxml.mml = lxml.mml or { }

local texsprint = tex.sprint
local format    = string.format
local xmlsprint = xml.sprint
local xmlcprint = xml.cprint

-- an alternative is to remap to private codes, where we can have
-- different properties .. to be done; this will move and become
-- generic

local n_replacements = {
--  [" "] = utf.char(0x2002),  -- "&textspace;" -> tricky, no &; in mkiv
    ["."] = "{.}",
    [","] = "{,}",
    [" "] = "",
}

local o_replacements = {
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

function lxml.mml.checked_operator(str)
    texsprint(tex.ctxcatcodes,(str:gsub(".",o_replacements)))
end

function lxml.mml.mn(id,pattern)
    local str = xml.content(lxml.id(id),pattern) or ""
    texsprint(tex.ctxcatcodes,(str:gsub(".",n_replacements)))
end
function lxml.mml.mo(id,pattern)
    local str = xml.content(lxml.id(id),pattern) or ""
    tex.sprint(tex.ctxcatcodes,(str:gsub(".",o_replacements)))
end
function lxml.mml.mi(id,pattern)
    local str = xml.content(lxml.id(id),pattern) or ""
    str = str:gsub("^%s*(.*)%s*$","%1")
    local rep = i_replacements[str]
    if rep then
        tex.sprint(tex.ctxcatcodes,rep)
    else
        tex.sprint(tex.ctxcatcodes,(str:gsub(".",i_replacements)))
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
        for s in utf.gmatch(separators,"([^%s])") do
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
    local framespacing = at.framespacing or ".5ex"

    texsprint(tex.ctxcatcodes, format("\\bTABLE[frame=%s,offset=%s]",frametypes[frame or "none"] or "off",framespacing))
    for r, d, k in xml.elements(root,"/(mml:mtr|mml:mlabeledtr)") do
        texsprint(tex.ctxcatcodes,"\\bTR")
        local dk = d[k]
        local at = dk.at
        local col = 0
        local rfr = at.frame       or (frames       and frames      [#frames])
        local rra = at.rowalign    or (rowaligns    and rowaligns   [#rowaligns])
        local rca = at.columnalign or (columnaligns and columnaligns[#columnaligns])
        for rr, dd, kk in xml.elements(dk,"/mml:mtd") do
            col = col + 1
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
        if dk.tg == "mlabeledtr" then
            texsprint(tex.ctxcatcodes,"\\bTD")
            xmlcprint(xml.first(dk,"/!mml:mtd"))
            texsprint(tex.ctxcatcodes,"\\eTD")
        end
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

