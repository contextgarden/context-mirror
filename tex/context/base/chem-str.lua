if not modules then modules = { } end modules ['chem-str'] = {
    version   = 1.001,
    comment   = "companion to chem-str.mkiv",
    author    = "Hans Hagen and Alan Braslau",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The original \PPCHTEX\ code was written in pure \TEX\, although later we made
-- the move from \PICTEX\ to \METAPOST\. The current implementation is a mix between
-- \TEX\, \LUA\ and \METAPOST. Although the first objective is to get a compatible
-- but better implementation, later versions might provide more.
--
-- Well, the later version has arrived as Alan took it upon him to make the code
-- deviate even further from the original implementation. The original (early \MKII)
-- variant operated within the boundaries of \PICTEX\ and as it supported MetaPost as
-- alternative output. As a consequence it still used a stepwise graphic construction
-- approach. As we used \TEX\ for parsing, the syntax was more rigid than it is now.
-- This new variant uses a more mathematical and metapostisch approach. In the process
-- more rendering variants have been added and alignment has been automated.. As a result
-- the current user interface is slightly different from the old one but hopefully users
-- will like the added value.

-- directive_strictorder: one might set this to off when associated texts are disordered too

local trace_structure       = false  trackers  .register("chemistry.structure",   function(v) trace_structure       = v end)
local trace_metapost        = false  trackers  .register("chemistry.metapost",    function(v) trace_metapost        = v end)
local trace_textstack       = false  trackers  .register("chemistry.textstack",   function(v) trace_textstack       = v end)
local directive_strictorder = true   directives.register("chemistry.strictorder", function(v) directive_strictorder = v end)
local directive_strictindex = false  directives.register("chemistry.strictindex", function(v) directive_strictindex = v end)

local report_chemistry = logs.reporter("chemistry")

local format, gmatch, match, lower, gsub = string.format, string.gmatch, string.match, string.lower, string.gsub
local concat, insert, remove, unique, sorted = table.concat, table.insert, table.remove, table.unique, table.sorted
local processor_tostring = typesetters and typesetters.processors.tostring
local settings_to_array = utilities.parsers.settings_to_array
local settings_to_array_with_repeat = utilities.parsers.settings_to_array_with_repeat

local lpegmatch = lpeg.match
local P, R, S, C, Cs, Ct, Cc, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc, lpeg.Cmt

local variables  = interfaces and interfaces.variables
local context    = context
local formatters = string.formatters

local v_default = variables.default
local v_small   = variables.small
local v_medium  = variables.medium
local v_big     = variables.big
local v_normal  = variables.normal
local v_fit     = variables.fit
local v_on      = variables.on

local mpnamedcolor = attributes.colors.mpnamedcolor
local topoints     = number.topoints
local todimen      = string.todimen

chemistry = chemistry or { }
local chemistry = chemistry

chemistry.instance   = "chemistry"
chemistry.format     = "metafun"
chemistry.structures = 0

local common_keys = {
    b      = "line",
    r      = "line",
    sb     = "line",
    sr     = "line",
    rd     = "line",
    rh     = "line",
    rb     = "line",
    rbd    = "line",
    cc     = "line",
    ccd    = "line",
    line   = "line",
    dash   = "line",
    arrow  = "line",
    c      = "fixed",
    cd     = "fixed",
    z      = "text",
    zt     = "text",
    zlt    = "text",
    zrt    = "text",
    rz     = "text",
    rt     = "text",
    lrt    = "text",
    rrt    = "text",
    label  = "text",
    zln    = "number",
    zrn    = "number",
    rn     = "number",
    lrn    = "number",
    rrn    = "number",
    zn     = "number",
    number = "number",
    mov    = "transform",
    mark   = "transform",
    move   = "transform",
    diff   = "transform",
    off    = "transform",
    adj    = "transform",
    sub    = "transform",
}

local front_keys = {
    bb    = "line",
    eb    = "line",
    rr    = "line",
    lr    = "line",
    lsr   = "line",
    rsr   = "line",
    lrd   = "line",
    rrd   = "line",
    lrh   = "line",
    rrh   = "line",
    lrbd  = "line",
    rrbd  = "line",
    lrb   = "line",
    rrb   = "line",
    lrz   = "text",
    rrz   = "text",
    lsub  = "transform",
    rsub  = "transform",
}

local one_keys = {
    db    = "line",
    tb    = "line",
    bb    = "line",
    dr    = "line",
    hb    = "line",
    bd    = "line",
    bw    = "line",
    oe    = "line",
    sd    = "line",
    rdb   = "line",
    ldb   = "line",
    ldd   = "line",
    rdd   = "line",
    ep    = "line",
    es    = "line",
    ed    = "line",
    et    = "line",
    cz    = "text",
    rot   = "transform",
    dir   = "transform",
    rm    = "transform",
    mir   = "transform",
}

local ring_keys = {
    db    = "line",
    br    = "line",
    lr    = "line",
    rr    = "line",
    lsr   = "line",
    rsr   = "line",
    lrd   = "line",
    rrd   = "line",
    lrb   = "line",
    rrb   = "line",
    lrh   = "line",
    rrh   = "line",
    lrbd  = "line",
    rrbd  = "line",
    dr    = "line",
    eb    = "line",
    er    = "line",
    ed    = "line",
    au    = "line",
    ad    = "line",
    s     = "line",
    ss    = "line",
    mid   = "line",
    mids  = "line",
    midz  = "text",
    lrz   = "text",
    rrz   = "text",
    crz   = "text",
    rot   = "transform",
    mir   = "transform",
    adj   = "transform",
    lsub  = "transform",
    rsub  = "transform",
    rm    = "transform",
}

-- table.setmetatableindex(front_keys,common_keys)
-- table.setmetatableindex(one_keys,common_keys)
-- table.setmetatableindex(ring_keys,common_keys)

-- or (faster but not needed here):

front_keys = table.merged(front_keys,common_keys)
one_keys   = table.merged(one_keys,common_keys)
ring_keys  = table.merged(ring_keys,common_keys)

local syntax = {
    carbon         = { max = 4, keys = one_keys, },
    alkyl          = { max = 4, keys = one_keys, },
    newmanstagger  = { max = 6, keys = one_keys, },
    newmaneclipsed = { max = 6, keys = one_keys, },
    one            = { max = 8, keys = one_keys, },
    three          = { max = 3, keys = ring_keys, },
    four           = { max = 4, keys = ring_keys, },
    five           = { max = 5, keys = ring_keys, },
    six            = { max = 6, keys = ring_keys, },
    seven          = { max = 7, keys = ring_keys, },
    eight          = { max = 8, keys = ring_keys, },
    nine           = { max = 9, keys = ring_keys, },
    fivefront      = { max = 5, keys = front_keys, },
    sixfront       = { max = 6, keys = front_keys, },
    chair          = { max = 6, keys = front_keys, },
    boat           = { max = 6, keys = front_keys, },
    pb             = { direct = 'chem_pb ;' },
    pe             = { direct = 'chem_pe ;' },
    save           = { direct = 'chem_save ;' },
    restore        = { direct = 'chem_restore ;' },
    chem           = { direct = 'chem_symbol("\\chemicaltext{%s}") ;', arguments = 1 },
    space          = { direct = 'chem_symbol("\\chemicalsymbol[space]") ;' },
    plus           = { direct = 'chem_symbol("\\chemicalsymbol[plus]") ;' },
    minus          = { direct = 'chem_symbol("\\chemicalsymbol[minus]") ;' },
    gives          = { direct = 'chem_symbol("\\chemicalsymbol[gives]{%s}{%s}") ;', arguments = 2 },
    equilibrium    = { direct = 'chem_symbol("\\chemicalsymbol[equilibrium]{%s}{%s}") ;', arguments = 2 },
    mesomeric      = { direct = 'chem_symbol("\\chemicalsymbol[mesomeric]{%s}{%s}") ;', arguments = 2 },
    opencomplex    = { direct = 'chem_symbol("\\chemicalsymbol[opencomplex]") ;' },
    closecomplex   = { direct = 'chem_symbol("\\chemicalsymbol[closecomplex]") ;' },
    reset          = { direct = 'chem_reset ;' },
    mp             = { direct = '%s', arguments = 1 }, -- backdoor MP code - dangerous!
}

chemistry.definitions = chemistry.definitions or { }
local definitions     = chemistry.definitions

storage.register("chemistry/definitions",definitions,"chemistry.definitions")

function chemistry.undefine(name)
    definitions[lower(name)] = nil
end

function chemistry.define(name,spec,text)
    name = lower(name)
    local dn = definitions[name]
    if not dn then
        dn = { }
        definitions[name] = dn
    end
    dn[#dn+1] = {
        spec = settings_to_array_with_repeat(spec,true),
        text = settings_to_array_with_repeat(text,true),
    }
end

local metacode, variant, keys, max, txt, pstack, sstack, align
local molecule = chemistry.molecule -- or use lpegmatch(chemistry.moleculeparser,...)

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
            report_chemistry("fetching from stack %a, slot %a, data %a",txt,st.n,t)
        end
        st.n = st.n + 1
    end
    return txt, t
end

local remapper = {
    ["+"] = "p",
    ["-"] = "m",
}

local dchrs     = R("09")
local sign      = S("+-")
local digit     = dchrs / tonumber
local amount    = (sign^-1 * (dchrs^0 * P('.'))^-1 * dchrs^1) / tonumber
local single    = digit
local range     = digit * P("..") * digit
local set       = Ct(digit^2)
local colon     = P(":")
local equal     = P("=")
local other     = 1 - digit - colon - equal
local remapped  = sign / remapper
local operation = Cs(other^1)
local special   = (colon * C(other^1)) + Cc("")
local text      = (equal * C(P(1)^0)) + Cc(false)

local pattern   =
    (amount + Cc(1))
  * (remapped + Cc(""))
  * Cs(operation/lower)
  * Cs(special/lower) * (
        range * Cc(false) * text +
        Cc(false) * Cc(false) * set * text +
        single * Cc(false) * Cc(false) * text +
        Cc(false) * Cc(false) * Cc(false) * text
    )

-- local n, operation, index, upto, set, text = lpegmatch(pattern,"RZ1357")

-- print(lpegmatch(pattern,"RZ=x"))        -- 1 RZ false false false x
-- print(lpegmatch(pattern,"RZ1=x"))       -- 1 RZ 1     false false x
-- print(lpegmatch(pattern,"RZ1..3=x"))    -- 1 RZ 1     3     false x
-- print(lpegmatch(pattern,"RZ13=x"))      -- 1 RZ false false table x

local f_initialize      = formatters['if unknown context_chem : input mp-chem.mpiv ; fi ;']
local f_start_structure = formatters['chem_start_structure(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s);']
local f_stop_structure  = formatters['chem_stop_structure;']
local f_start_component = formatters['chem_start_component;']
local f_stop_component  = formatters['chem_stop_component;']
local f_line            = formatters['chem_%s%s(%s,%s,%s,%s,%s);']
local f_set             = formatters['chem_set(%s);']
local f_number          = formatters['chem_%s%s(%s,%s,"\\chemicaltext{%s}");']
local f_text            = f_number
local f_empty_normal    = formatters['chem_%s(%s,%s,"");']
local f_empty_center    = formatters['chem_c%s(%s,%s,"");']
local f_transform       = formatters['chem_%s(%s,%s,%s);']

local prepareMPvariable = commands and commands.prepareMPvariable

local function process(level,spec,text,n,rulethickness,rulecolor,offset,default_variant)
    insert(stack,{ spec = spec, text = text, n = n })
    local txt = #stack
    local m = #metacode
    local saved_rulethickness = rulethickness
    local saved_rulecolor = rulecolor
    local saved_align = align
    local current_variant = default_variant or "six"
    for i=1,#spec do
        local step = spec[i]
        local s = lower(step)
        local n = current_variant .. ":" .. s
        local d = definitions[n]
        if not d then
            n = s
            d = definitions[n]
        end
        if d then
            if trace_structure then
                report_chemistry("level %a, step %a, definition %a, snippets %a",level,step,n,#d)
            end
            for i=1,#d do
                local di = d[i]
                current_variant = process(level+1,di.spec,di.text,1,rulethickness,rulecolor,offset,current_variant) -- offset?
            end
        else
            local factor, osign, operation, special, index, upto, set, text = lpegmatch(pattern,step)
            if trace_structure then
                local set = set and concat(set," ") or "-"
                report_chemistry("level %a, step %a, factor %a, osign %a, operation %a, special %a, index %a, upto %a, set %a, text %a",
                    level,step,factor,osign,operation,special,index,upto,set,text)
            end
            if operation == "rulecolor" then
                local t = text
                if not t then
                    txt, t = fetch(txt)
                end
                if t == v_default or t == v_normal or t == "" then
                    rulecolor = saved_rulecolor
                elseif t then
                    rulecolor = mpnamedcolor(t)
                end
            elseif operation == "rulethickness" then
                local t = text
                if not t then
                    txt, t = fetch(txt)
                end
                if t == v_default or t == v_normal or t == t_medium or t == "" then
                    rulethickness = saved_rulethickness
                elseif t == v_small then
                    rulethickness = topoints(1/1.2 * todimen(saved_rulethickness))
                elseif t == v_big then
                    rulethickness = topoints(1.2 * todimen(saved_rulethickness))
                elseif t then
                 -- rulethickness = topoints(todimen(t)) -- mp can't handle sp
                    rulethickness = topoints(tonumber(t) * todimen(saved_rulethickness))
                end
            elseif operation == "symalign" then
                local t = text
                if not t then
                    txt, t = fetch(txt)
                end
                if t == v_default or t == v_normal then
                    align = saved_align
                elseif t and t ~= "" then
                    align = "." .. t
                end
            elseif operation == "pb" then
                insert(pstack,variant)
                m = m + 1 ; metacode[m] = syntax.pb.direct
                if keys[special] == "text" and index then
                    if keys["c"..special] == "text" then -- can be option: auto ...
                        m = m + 1 ; metacode[m] = f_empty_center(special,variant,index)
                    else
                        m = m + 1 ; metacode[m] = f_empty_normal(special,variant,index)
                    end
                end
            elseif operation == "pe" then
                variant = remove(pstack)
                local ss = syntax[variant]
                keys, max = ss.keys, ss.max
                m = m + 1 ; metacode[m] = syntax[operation].direct
                m = m + 1 ; metacode[m] = f_set(variant)
                current_variant = variant
            elseif operation == "save" then
                insert(sstack,variant)
                m = m + 1 ; metacode[m] = syntax.save.direct
            elseif operation == "restore" then
                variant = remove(sstack)
                local ss = syntax[variant]
                keys, max = ss.keys, ss.max
                m = m + 1 ; metacode[m] = syntax[operation].direct
                m = m + 1 ; metacode[m] = f_set(variant)
                current_variant = variant
            elseif operation then
                local ss = syntax[operation]
                local what = keys[operation]
                local ns = 0
                if set then
                    local sv = syntax[current_variant]
                    local ms = sv and sv.max
                    set = unique(set)
                    ns = #set
                    if directive_strictorder then
                        if what == "line" then
                            set = sorted(set)
                        end
                        if directive_strictindex and ms then
                            for i=ns,1,-1 do
                                local si = set[i]
                                if si > ms then
                                    report_chemistry("level %a, operation %a, max nofsteps %a, ignoring %a",level,operation,ms,si)
                                    set[i] = nil
                                    ns = ns - 1
                                else
                                    break
                                end
                            end
                        end
                    else
                        if directive_strictindex and ms then
                            local t, nt = { }, 0
                            for i=1,ns do
                                local si = set[i]
                                if si > ms then
                                    report_chemistry("level %a, operation %a, max nofsteps %a, ignoring %a",level,operation,ms,si)
                                    set[i] = nil
                                else
                                    nt = nt + 1
                                    t[nt] = si
                                end
                            end
                            ns = nt
                            set = t
                        end
                    end
                end
                if ss then
                    local ds = ss.direct
                    if ds then
                        local sa = ss.arguments
                        if sa == 1 then
                            local one ; txt, one = fetch(txt)
                            m = m + 1 ; metacode[m] = format(ds,one or "")
                        elseif sa == 2 then
                            local one ; txt, one = fetch(txt)
                            local two ; txt, two = fetch(txt)
                            m = m + 1 ; metacode[m] = format(ds,one or "",two or "")
                        else
                            m = m + 1 ; metacode[m] = ds
                        end
                    elseif ss.keys then
                        variant, keys, max = s, ss.keys, ss.max
                        m = m + 1 ; metacode[m] = f_set(variant)
                        current_variant = variant
                    end
                elseif what == "line" then
                    local s = osign
                    if s ~= "" then
                        s = "." .. s
                    end
                    if set then
                        -- condense consecutive numbers in a set to a range
                        local sf, st = set[1]
                        for i=1,ns do
                            if i > 1 and set[i] ~= set[i-1]+1 then
                                m = m + 1 ; metacode[m] = f_line(operation,s,variant,sf,st,rulethickness,rulecolor)
                                sf = set[i]
                            end
                            st = set[i]
                        end
                        m = m + 1 ; metacode[m] = f_line(operation,s,variant,sf,st,rulethickness,rulecolor)
                    elseif upto then
                        m = m + 1 ; metacode[m] = f_line(operation,s,variant,index,upto,rulethickness,rulecolor)
                    elseif index then
                        m = m + 1 ; metacode[m] = f_line(operation,s,variant,index,index,rulethickness,rulecolor)
                    else
                        m = m + 1 ; metacode[m] = f_line(operation,s,variant,1,max,rulethickness,rulecolor)
                    end
                elseif what == "number" then
                    if set then
                        for i=1,ns do
                            local si = set[i]
                            m = m + 1 ; metacode[m] = f_number(operation,align,variant,si,si)
                        end
                    elseif upto then
                        for i=index,upto do
                            local si = set[i]
                            m = m + 1 ; metacode[m] = f_number(operation,align,variant,si,si)
                        end
                    elseif index then
                        m = m + 1 ; metacode[m] = f_number(operation,align,variant,index,index)
                    else
                        for i=1,max do
                            m = m + 1 ; metacode[m] = f_number(operation,align,variant,i,i)
                        end
                    end
                elseif what == "text" then
                    if set then
                        for i=1,ns do
                            local si = set[i]
                            local t = text
                            if not t then txt, t = fetch(txt) end
                            if t then
                                t = molecule(processor_tostring(t))
                                m = m + 1 ; metacode[m] = f_text(operation,align,variant,si,t)
                            end
                        end
                    elseif upto then
                        for i=index,upto do
                            local t = text
                            if not t then txt, t = fetch(txt) end
                            if t then
                                t = molecule(processor_tostring(t))
                                m = m + 1 ; metacode[m] = f_text(operation,align,variant,i,t)
                            end
                        end
                    elseif index == 0 then
                        local t = text
                        if not t then txt, t = fetch(txt) end
                        if t then
                            t = molecule(processor_tostring(t))
                            m = m + 1 ; metacode[m] = f_text(operation,align,variant,index,t)
                        end
                    elseif index then
                        local t = text
                        if not t then txt, t = fetch(txt) end
                        if t then
                            t = molecule(processor_tostring(t))
                            m = m + 1 ; metacode[m] = f_text(operation,align,variant,index,t)
                        end
                    else
                        for i=1,max do
                            local t = text
                            if not t then txt, t = fetch(txt) end
                            if t then
                                t = molecule(processor_tostring(t))
                                m = m + 1 ; metacode[m] = f_text(operation,align,variant,i,t)
                            end
                        end
                    end
                elseif what == "transform" then
                    if osign == "m" then
                        factor = -factor
                    end
                    if set then
                        for i=1,ns do
                            local si = set[i]
                            m = m + 1 ; metacode[m] = f_transform(operation,variant,si,factor)
                        end
                    elseif upto then
                        for i=index,upto do
                            m = m + 1 ; metacode[m] = f_transform(operation,variant,i,factor)
                        end
                    else
                        m = m + 1 ; metacode[m] = f_transform(operation,variant,index or 1,factor)
                    end
                elseif what == "fixed" then
                    m = m + 1 ; metacode[m] = f_transform(operation,variant,rulethickness,rulecolor)
                elseif trace_structure then
                    report_chemistry("level %a, ignoring undefined operation %s",level,operation)
                end
            end
        end
    end
    remove(stack)
    return current_variant
end

-- the size related values are somewhat special but we want to be
-- compatible
--
-- rulethickness in points

function chemistry.start(settings)
    chemistry.structures = chemistry.structures + 1
    local emwidth, rulethickness, rulecolor, axiscolor = settings.emwidth, settings.rulethickness, settings.rulecolor, settings.framecolor
    local width, height, scale, rotation, offset = settings.width or 0, settings.height or 0, settings.scale or "normal", settings.rotation or 0, settings.offset or 0
    local l, r, t, b = settings.left or 0, settings.right or 0, settings.top or 0, settings.bottom or 0
    --
    metacode = { }
    --
    align = settings.symalign or "auto"
    if trace_structure then
        report_chemistry("scale %a, rotation %a, width %a, height %a, l: %a, r: %a, t: %a, b: %a",scale,rotation,width,height,l,r,t,b)
        report_chemistry("symalign: %s", align)
    end
    if align ~= "" then align = "." .. align end
    if scale == v_small then
        scale = 1/1.2
    elseif scale == v_normal or scale == v_medium or scale == 0 then
        scale = 1
    elseif scale == v_big then
        scale = 1.2
    else
        scale = tonumber(scale)
        if not scale or scale == 0 then
            scale = 1
        elseif scale >= 10 then
            scale = scale / 1000
        elseif scale < .01 then
            scale = .01
        end
    end
    if width == v_fit then
        width = true
    else
        width = tonumber(width) or 0
        if width >= 10 then
            width = width / 1000
        end
        if l == 0 then
            if r == 0 then
                l = width == 0 and 2 or width/2
                r = l
            elseif width ~= 0 then
                if r > 10 or r < -10 then
                    r = r / 1000
                end
                l = width - r
            end
        elseif r == 0 and width ~= 0 then
            if l > 10 or l < -10 then
                l = l / 1000
            end
            r = width - l
        end
        width = false
    end
    if height == v_fit then
        height = true
    else
        height = tonumber(height) or 0
        if height >= 10 then
            height = height / 1000
        end
        if t == 0 then
            if b == 0 then
                t = height == 0 and 2 or height/2
                b = t
            elseif height ~= 0 then
                if b > 10 or b < -10 then
                    b = b / 1000
                end
                t = height - b
            end
        elseif b == 0 and height ~= 0 then
            if t > 10 or t < -10 then
                t = t / 1000
            end
            b = height - t
        end
        height = false
    end
    rotation = tonumber(rotation) or 0
    --
    metacode[#metacode+1] = f_start_structure(
        chemistry.structures,
        l, r, t, b, scale, rotation,
        tostring(width), tostring(height), tostring(emwidth), tostring(offset),
        tostring(settings.axis == v_on), tostring(rulethickness), tostring(axiscolor)
    )
    --
    variant, keys, stack, pstack, sstack = "one", { }, { }, { }, { }
end

function chemistry.stop()
    metacode[#metacode+1] = f_stop_structure()
    local mpcode = concat(metacode,"\n")
    if trace_metapost then
        report_chemistry("metapost code:\n%s", mpcode)
    end
    if metapost.instance(chemistry.instance) then
        f_initialize = nil
    end
    metapost.graphic {
        instance    = chemistry.instance,
        format      = chemistry.format,
        data        = mpcode,
        definitions = f_initialize and f_initialize(),
    }
    t_initialize = ""
    metacode = nil
end

function chemistry.component(spec,text,settings)
    rulethickness, rulecolor, offset = settings.rulethickness, settings.rulecolor
    local spec = settings_to_array_with_repeat(spec,true) -- no lower?
    local text = settings_to_array_with_repeat(text,true)
-- inspect(spec)
    metacode[#metacode+1] = f_start_component()
    process(1,spec,text,1,rulethickness,rulecolor) -- offset?
    metacode[#metacode+1] = f_stop_component()
end

statistics.register("chemical formulas", function()
    if chemistry.structures > 0 then
        return format("%s chemical structure formulas",chemistry.structures) -- no timing needed, part of metapost
    end
end)

-- interfaces

commands.undefinechemical  = chemistry.undefine
commands.definechemical    = chemistry.define
commands.startchemical     = chemistry.start
commands.stopchemical      = chemistry.stop
commands.chemicalcomponent = chemistry.component

-- todo: top / bottom
-- maybe add "=" for double and "≡" for triple?

local inline = {
    ["single"]      = "\\chemicalsinglebond",  ["-"]   = "\\chemicalsinglebond",
    ["double"]      = "\\chemicaldoublebond",  ["--"]  = "\\chemicaldoublebond",
    ["triple"]      = "\\chemicaltriplebond",  ["---"] = "\\chemicaltriplebond",
    ["gives"]       = "\\chemicalgives",       ["->"]  = "\\chemicalgives",
    ["equilibrium"] = "\\chemicalequilibrium", ["<->"] = "\\chemicalequilibrium",
    ["mesomeric"]   = "\\chemicalmesomeric",   ["<>"]  = "\\chemicalmesomeric",
    ["plus"]        = "\\chemicalplus",        ["+"]   = "\\chemicalplus",
    ["minus"]       = "\\chemicalminus",
    ["space"]       = "\\chemicalspace",
}

function commands.inlinechemical(spec)
    local spec = settings_to_array_with_repeat(spec,true)
    for i=1,#spec do
        local s = spec[i]
        local inl = inline[lower(s)]
        if inl then
            context(inl) -- could be a fast context.sprint
        else
            context.chemicalinline(molecule(s))
        end
    end
end
