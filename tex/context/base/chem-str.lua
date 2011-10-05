if not modules then modules = { } end modules ['chem-str'] = {
    version   = 1.001,
    comment   = "companion to chem-str.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module in incomplete and experimental.

-- We can push snippets into an mp instance.

local trace_structure = false  trackers.register("chemistry.structure",  function(v) trace_structure = v end)
local trace_textstack = false  trackers.register("chemistry.textstack",  function(v) trace_textstack = v end)

local report_chemistry = logs.reporter("chemistry")

local format, gmatch, match, lower, gsub = string.format, string.gmatch, string.match, string.lower, string.gsub
local concat, insert, remove = table.concat, table.insert, table.remove
local processor_tostring = structures.processors.tostring
local lpegmatch = lpeg.match
local settings_to_array = utilities.parsers.settings_to_array

local P, R, S, C, Cs, Ct, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc

local variables = interfaces.variables
local context   = context

chemicals = chemicals or { }
local chemicals = chemicals

chemicals.instance   = "metafun" -- "ppchtex"
chemicals.format     = "metafun"
chemicals.structures = 0

local remapper = {
    ["+"] = "p",
    ["-"] = "m",
}

local common_keys = {
    b = "line", eb = "line", db = "line", er = "line", dr = "line", br = "line",
    sb = "line", msb = "line", psb = "line",
    r = "line", pr = "line", mr = "line",
    au = "line", ad = "line",
    rb = "line", mrb = "line", prb = "line",
    rd = "line", mrd = "line", prd = "line",
    sr = "line", msr = "line", psr = "line",
    c = "line", cc = "line", cd = "line", ccd = "line",
    rn = "number", rtn = "number", rbn = "number",
    s = "line", ss = "line",  pss = "line", mss = "line",
    mid = "fixed", mids = "fixed", midz = "text",
    z = "text", rz = "text", mrz = "text", prz = "text", crz = "text",
    rt = "text", rtt = "text", rbt = "text", zt = "text", zn = "number",
    mov = "transform", rot = "transform", adj = "transform", dir = "transform", sub = "transform",
}

local front_keys = {
    b = "line", bb= "line",
    sb = "line", msb = "line", psb = "line",
    r = "line", pr = "line", mr = "line",
    z = "text", mrz = "text", prz = "text",
}

local one_keys = {
    sb = "line", db = "line", tb = "line",
    ep = "line", es = "line", ed = "line", et = "line",
    sd = "line", ldd = "line", rdd = "line",
    hb = "line", bb = "line", oe = "line", bd = "line", bw = "line",
    z = "text", cz = "text", zt = "text", zn = "number",
    zbt = "text", zbn = "number", ztt = "text", ztn = "number",
    mov = "transform", sub = "transform", dir = "transform", off = "transform",
}

local front_align = {
    mrz = { { "b","b","b","b","b","b" } },
    prz = { { "t","t","t","t","t","t" } },
}

local syntax = {
    one = {
        n = 1, max = 8, keys = one_keys,
        align = {
            z = { { "r", "r_b", "b", "l_b", "l", "l_t", "t", "r_t" } },
--~             z = { { "r", "r", "b", "l", "l", "l", "t", "r" } },
        }
    },
    three = {
        n = 3, max = 3, keys = common_keys,
        align = {
            mrz = { { "r","b","l" }, { "b","l","t" }, { "l","t","r" }, { "t","r","b" } },
            rz  = { { "r","l_b","l_t" }, { "b","l_t","r_t" }, { "l","r_t","r_b" }, { "t","r_b","l_b" } },
            prz = { { "r","l","t" }, { "b","t","r" }, { "l","r","b" }, { "t","b","l" } },
        }
    },
    four = {
        n = 4, max = 4, keys = common_keys,
        align = {
            mrz = { { "t","r","b","l" }, { "r","b","l","t" }, { "b","l","t","r" }, { "l","t","r","b" } },
            rz  = { { "r_t","r_b","l_b","l_t" }, { "r_b","l_b","l_t","r_t" }, { "l_b","l_t","r_t","r_b" }, { "l_t","r_t","r_b","l_b" } },
            prz = { { "r","b","l","t" }, { "b","l","t","r" }, { "l","t","r","b" }, { "t","r","b","l" } },
        }
    },
    five = {
        n = 5, max = 5, keys = common_keys,
        align = {
            mrz = { { "t","r","b","b","l" }, { "r","b","l","l","t" }, { "b","l","t","r","r" }, { "l","t","r","r","b" } },
            rz  = { { "r","r","b","l","t" }, { "b","b","l","t","r" }, { "l","l","t","r","b" }, { "t","t","r","b","l" } },
            prz = { { "r","b","l","t","t" }, { "b","l","t","r","r" }, { "l","t","r","b","b" }, { "t","r","b","l","l" } },
        }
    },
    six  = {
        n = 6, max = 6, keys = common_keys,
        align = {
            mrz = { { "t","t","r","b","b","l" }, { "r","b","b","l","t","t" }, { "b","b","l","t","t","r" }, { "l","t","t","r","b","b" } },
            rz  = { { "r","r","b","l","l","t" }, { "b","b","l","t","t","r" }, { "l","l","t","r","r","b" }, { "t","t","r","b","b","l" } },
            prz = { { "r","b","l","l","t","r" }, { "b","l","t","t","r","b" }, { "l","t","r","r","b","l" }, { "t","r","b","b","l","t" } },
        }
    },
    eight = {
        n = 8, max = 8, keys = common_keys,
        align = { -- todo
            mrz = { { "t","r","r","b","b","l","l","t" }, { "r","b","b","l","l","t","t","r" }, { "b","l","l","t","t","r","r","b" }, { "l","t","t","r","r","b","b","l" } },
            rz  = { { "r","r","b","b","l","l","t","t" }, { "b","b","l","l","t","t","r","r" }, { "l","l","t","t","r","r","b","b" }, { "t","t","r","r","b","b","l","l" } },
            prz = { { "r","b","b","l","l","t","t","r" }, { "b","l","l","t","t","r","r","b" }, { "l","t","t","r","r","b","b","l" }, { "t","r","r","b","b","l","l","t" } },
        }
    },
    five_front = {
        n = -5, max = 5, keys = front_keys, align = front_align,
    },
    six_front = {
        n = -6, max = 6, keys = front_keys, align = front_align,
    },
    pb           = { direct = 'chem_pb ;' },
    pe           = { direct = 'chem_pe ;' },
    save         = { direct = 'chem_save ;' },
    restore      = { direct = 'chem_restore ;' },
    space        = { direct = 'chem_symbol("\\chemicalsymbol[space]") ;' },
    plus         = { direct = 'chem_symbol("\\chemicalsymbol[plus]") ;' },
    minus        = { direct = 'chem_symbol("\\chemicalsymbol[minus]") ;' },
    gives        = { direct = 'chem_symbol("\\chemicalsymbol[gives]{%s}{%s}") ;', arguments = 2 },
    equilibrium  = { direct = 'chem_symbol("\\chemicalsymbol[equilibrium]{%s}{%s}") ;', arguments = 2 },
    mesomeric    = { direct = 'chem_symbol("\\chemicalsymbol[mesomeric]{%s}{%s}") ;', arguments = 2 },
    opencomplex  = { direct = 'chem_symbol("\\chemicalsymbol[opencomplex]") ;' },
    closecomplex = { direct = 'chem_symbol("\\chemicalsymbol[closecomplex]") ;' },
}

local definitions = { }

function chemicals.undefine(name)
    definitions[lower(name)] = nil
end

function chemicals.define(name,spec,text)
    name = lower(name)
    local dn = definitions[name]
    if not dn then dn = { } definitions[name] = dn end
    dn[#dn+1] = {
        spec = settings_to_array(lower(spec)),
        text = settings_to_array(text),
    }
end

local metacode, variant, keys, bonds, max, txt, textsize, rot, pstack
local molecule = chemicals.molecule -- or use lpegmatch(chemicals.moleculeparser,...)

local function fetch(txt)
    local st = stack[txt]
    local t = st.text[st.n]
    while not t and txt > 1 do
        txt = txt - 1
        st = stack[txt]
        t = st.text[st.n]
    end
    if t then
        if trace_textstack then
            report_chemistry("fetching from stack %s slot %s: %s",txt,st.n,t)
        end
        st.n = st.n + 1
    end
    return txt, t
end

local digit     = R("09")/tonumber
local colon     = P(":")
local equal     = P("=")
local other     = 1 - digit - colon - equal
local remapped  = S("+-") / remapper
local operation = Cs((remapped^0 * other)^1)
local amount    = digit
local single    = digit
local special   = (colon * C(other^1)) + Cc("")
local range     = digit * P("..") * digit
local set       = Ct(digit^2)
local text      = (equal * C(P(1)^0)) + Cc(false)

local pattern   =
    (amount + Cc(1)) *
    operation *
    special * (
        range * Cc(false) * text +
        Cc(false) * Cc(false) * set * text +
        single * Cc(false) * Cc(false) * text +
        Cc(false) * Cc(false) * Cc(false) * text
    )

--~ local n, operation, index, upto, set, text = lpegmatch(pattern,"RZ1357")

--~ print(lpegmatch(pattern,"RZ=x"))        1 RZ false false false  x
--~ print(lpegmatch(pattern,"RZ1=x"))       1 RZ 1     false false	x
--~ print(lpegmatch(pattern,"RZ1..3=x"))    1 RZ 1     3     false	x
--~ print(lpegmatch(pattern,"RZ13=x"))      1 RZ false false table	x

local function process(spec,text,n,rulethickness,rulecolor,offset)
    insert(stack,{ spec=spec, text=text, n=n })
    local txt = #stack
    local m = #metacode
    for i=1,#spec do
        local s = spec[i]
        local d = definitions[s]
        if d then
            for i=1,#d do
                local di = d[i]
                process(di.spec,di.text,1,rulethickness,rulecolor)
            end
        else
            local rep, operation, special, index, upto, set, text = lpegmatch(pattern,s)
            if operation == "pb" then
                insert(pstack,variant)
                m = m + 1 ; metacode[m] = syntax.pb.direct
                if keys[special] == "text" and index then
                    if keys["c"..special] == "text" then -- can be option: auto ...
                        m = m + 1 ; metacode[m] = format('chem_c%s(%s,%s,"");',special,bonds,index)
                    else
                        m = m + 1 ; metacode[m] = format('chem_%s(%s,%s,"");',special,bonds,index)
                    end
                end
            elseif operation == "save" then
                insert(pstack,variant)
                m = m + 1 ; metacode[m] = syntax.save.direct
            elseif operation == "pe" or operation == "restore" then
                variant = remove(pstack)
                local ss = syntax[variant]
                local prev = bonds or 6
                keys, bonds, max, rot = ss.keys, ss.n, ss.max, 1
                m = m + 1 ; metacode[m] = syntax[operation].direct
                m = m + 1 ; metacode[m] = format("chem_set(%s,%s) ;",prev,bonds)
            elseif operation == "front" then
                if syntax[variant .. "_front"] then
                    variant = variant .. "_front"
                    local ss = syntax[variant]
                    local prev = bonds or 6
                    keys, bonds, max, rot = ss.keys, ss.n, ss.max, 1
                    m = m + 1 ; metacode[m] = format("chem_set(%s,%s) ;",prev,bonds)
                end
            elseif operation then
                local ss = syntax[operation]
                if ss then
                    local ds = ss.direct
                    if ds then
                        local sa = ss.arguments
                        if sa == 1 then
                            local one ; txt, one = fetch(txt)
                            m = m + 1 ; metacode[m] = format(ds,one or "")
                        elseif sa ==2 then
                            local one ; txt, one = fetch(txt)
                            local two ; txt, two = fetch(txt)
                            m = m + 1 ; metacode[m] = format(ds,one or "",two or "")
                        else
                            m = m + 1 ; metacode[m] = ds
                        end
                    elseif ss.keys then
                        local prev = bonds or 6
                        variant, keys, bonds, max, rot = s, ss.keys, ss.n, ss.max, 1
                        m = m + 1 ; metacode[m] = format("chem_set(%s,%s) ;",prev,bonds)
                    end
                else
                    local what = keys[operation]
                    if what == "line" then
                        if set then
                            for i=1,#set do
                                local si = set[i]
                                m = m + 1 ; metacode[m] = format("chem_%s(%s,%s,%s,%s,%s);",operation,bonds,si,si,rulethickness,rulecolor)
                            end
                        elseif upto then
                            m = m + 1 ; metacode[m] = format("chem_%s(%s,%s,%s,%s,%s);",operation,bonds,index,upto,rulethickness,rulecolor)
                        elseif index then
                            m = m + 1 ; metacode[m] = format("chem_%s(%s,%s,%s,%s,%s);",operation,bonds,index,index,rulethickness,rulecolor)
                        else
                            m = m + 1 ; metacode[m] = format("chem_%s(%s,%s,%s,%s,%s);",operation,bonds,1,max,rulethickness,rulecolor)
                        end
                    elseif what == "number" then
                        if set then
                            for i=1,#set do
                                local si = set[i]
                                m = m + 1 ; metacode[m] = format('chem_%s(%s,%s,"\\dochemicaltext{%s}");',operation,bonds,si,si)
                            end
                        elseif upto then
                            for i=index,upto do
                                local si = set[i]
                                m = m + 1 ; metacode[m] = format('chem_%s(%s,%s,"\\dochemicaltext{%s}");',operation,bonds,si,si)
                            end
                        elseif index then
                            m = m + 1 ; metacode[m] = format('chem_%s(%s,%s,"\\dochemicaltext{%s}");',operation,bonds,index,index)
                        else
                            for i=1,max do
                                m = m + 1 ; metacode[m] = format('chem_%s(%s,%s,"\\dochemicaltext{%s}");',operation,bonds,i,i)
                            end
                        end
                    elseif what == "text" then
                        local align = syntax[variant].align
                        align = align and align[operation]
                        align = align and align[rot]
                        if set then
                            for i=1,#set do
                                local si = set[i]
                                local t = text
                                if not t then txt, t = fetch(txt) end
                                if t then
                                    local a = align and align[si]
                                    if a then a = "." .. a else a = "" end
                                    t = molecule(processor_tostring(t))
                                    m = m + 1 ; metacode[m] = format('chem_%s%s(%s,%s,"\\dochemicaltext{%s}");',operation,a,bonds,si,t)
                                end
                            end
                        elseif upto then
                            for i=index,upto do
                                local t = text
                                if not t then txt, t = fetch(txt) end
                                if t then
                                    local s = align and align[i]
                                    if s then s = "." .. s else s = "" end
                                    t = molecule(processor_tostring(t))
                                    m = m + 1 ; metacode[m] = format('chem_%s%s(%s,%s,"\\dochemicaltext{%s}");',operation,s,bonds,i,t)
                                end
                            end
                        elseif index == 0 then
                            local t = text
                            if not t then txt, t = fetch(txt) end
                            if t then
                                t = molecule(processor_tostring(t))
                                m = m + 1 ; metacode[m] = format('chem_%s_zero("\\dochemicaltext{%s}");',operation,t)
                            end
                        elseif index then
                            local t = text
                            if not t then txt, t = fetch(txt) end
                            if t then
                                local s = align and align[index]
                                if s then s = "." .. s else s = "" end
                                t = molecule(processor_tostring(t))
                                m = m + 1 ; metacode[m] = format('chem_%s%s(%s,%s,"\\dochemicaltext{%s}");',operation,s,bonds,index,t)
                            end
                        else
                            for i=1,max do
                                local t = text
                                if not t then txt, t = fetch(txt) end
                                if t then
                                    local s = align and align[i]
                                    if s then s = "." .. s else s = "" end
                                    t = molecule(processor_tostring(t))
                                    m = m + 1 ; metacode[m] = format('chem_%s%s(%s,%s,"\\dochemicaltext{%s}");',operation,s,bonds,i,t)
                                end
                            end
                        end
                    elseif what == "transform" then
                        if index then
                            for r=1,rep do
                                m = m + 1 ; metacode[m] = format('chem_%s(%s,%s);',operation,bonds,index)
                            end
                            if operation == "rot" then
                                rot = index
                            end
                        end
                    elseif what == "fixed" then
                        m = m + 1 ; metacode[m] = format("chem_%s(%s,%s,%s);",operation,bonds,rulethickness,rulecolor)
                    end
                end
            end
        end
    end
    remove(stack)
end

-- the size related values are somewhat special but we want to be
-- compatible
--
-- maybe we should default to fit
--
-- rulethickness in points

function chemicals.start(settings)
    chemicals.structures = chemicals.structures + 1
    local textsize, rulethickness, rulecolor = settings.size, settings.rulethickness, settings.rulecolor
    local width, height, scale, offset = settings.width or 0, settings.height or 0, settings.scale or "medium", settings.offset or 0
    local l, r, t, b = settings.left or 0, settings.right or 0, settings.top or 0, settings.bottom or 0
    if scale == variables.small then
        scale = 500
    elseif scale == variables.medium or scale == 0 then
        scale = 625
    elseif scale == variables.big then
        scale = 750
    else
        scale = tonumber(scale)
        if not scale or scale == 0 then
            scale = 750
        elseif scale < 500 then
            scale = 500
        end
    end
    if width == variables.fit then
        width = true
    else
        width = tonumber(width) or 0
        if l == 0 then
            if r == 0 then
                l = (width == 0 and 2000) or width/2
                r = l
            elseif width ~= 0 then
                l = width - r
            end
        elseif r == 0 and width ~= 0 then
            r = width - l
        end
        width = false
    end
    if height == variables.fit then
        height = true
    else
        height = tonumber(height) or 0
        if t == 0 then
            if b == 0 then
                t = (height == 0 and 2000) or height/2
                b = t
            elseif height ~= 0 then
                t = height - b
            end
        elseif b == 0 and height ~= 0 then
            b = height - t
        end
        height = false
    end
    scale = 0.75 * scale/625
    metacode = { format("chem_start_structure(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ;",
        chemicals.structures,
        l/25, r/25, t/25, b/25, scale,
        tostring(settings.axis == variables.on), tostring(width), tostring(height), tostring(offset)
    ) }
    variant, keys, bonds, stack, rot, pstack = "six", { }, 6, { }, 1, { }
end

function chemicals.stop()
    metacode[#metacode+1] = "chem_stop_structure ;"
    local mpcode = concat(metacode,"\n")
    if trace_structure then
        report_chemistry("metapost code:\n%s", mpcode)
    end
    metapost.graphic(chemicals.instance,chemicals.format,mpcode)
    metacode = nil
end

function chemicals.component(spec,text,settings)
    rulethickness, rulecolor, offset = settings.rulethickness, settings.rulecolor
    local spec = settings_to_array(lower(spec))
    local text = settings_to_array(text)
    metacode[#metacode+1] = "chem_start_component ;"
    process(spec,text,1,rulethickness,rulecolor)
    metacode[#metacode+1] = "chem_stop_component ;"
end

local inline = {
    ["single"]      = "\\chemicalsinglebond",  ["-"]   = "\\chemicalsinglebond",
    ["double"]      = "\\chemicaldoublebond",  ["--"]  = "\\chemicaldoublebond",
    ["triple"]      = "\\chemicaltriplebond",  ["---"] = "\\chemicaltriplebond",
    ["gives"]       = "\\chemicalgives",       ["->"]  = "\\chemicalgives",
    ["equilibrium"] = "\\chemicalequilibrium", ["<->"] = "\\chemicalequilibrium",
    ["mesomeric"]   = "\\chemicalmesomeric",   ["<>"]  = "\\chemicalmesomeric",
    ["plus"]        = "\\chemicalsplus",       ["+"]   = "\\chemicalsplus",
    ["minus"]       = "\\chemicalsminus",
    ["space"]       = "\\chemicalsspace",
}

-- todo: top / bottom

function chemicals.inline(spec)
    local spec = settings_to_array(spec)
    for i=1,#spec do
        local s = spec[i]
        local inl = inline[lower(s)]
        if inl then
            context(inl)
        else
            context.chemicalinline(molecule(s))
        end
    end
end

statistics.register("chemical formulas", function()
    if chemicals.structures > 0 then
        return format("%s chemical structure formulas",chemicals.structures) -- no timing needed, part of metapost
    end
end)
