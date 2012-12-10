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

local trace_structure = false  trackers.register("chemistry.structure",  function(v) trace_structure = v end)
local trace_metapost  = false  trackers.register("chemistry.metapost",   function(v) trace_metapost  = v end)
local trace_textstack = false  trackers.register("chemistry.textstack",  function(v) trace_textstack = v end)

local report_chemistry = logs.reporter("chemistry")

local format, gmatch, match, lower, gsub = string.format, string.gmatch, string.match, string.lower, string.gsub
local concat, insert, remove = table.concat, table.insert, table.remove
local processor_tostring = typesetters and typesetters.processors.tostring
local settings_to_array = utilities.parsers.settings_to_array
local settings_to_array_with_repeat = utilities.parsers.settings_to_array_with_repeat

local lpegmatch = lpeg.match
local P, R, S, C, Cs, Ct, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc

local variables = interfaces and interfaces.variables
local context   = context

chemistry = chemistry or { }
local chemistry = chemistry

chemistry.instance   = "chemistry"
chemistry.format     = "metafun"
chemistry.structures = 0

local common_keys = {
    b     = "line",
    r     = "line",
    sb    = "line",
    sr    = "line",
    rd    = "line",
    rh    = "line",
    cc    = "line",
    ccd   = "line",
    line  = "line",
    dash  = "line",
    arrow = "line",
    c     = "fixed",
    cd    = "fixed",
    z     = "text",
    zt    = "text",
    zlt   = "text",
    zrt   = "text",
    rz    = "text",
    rt    = "text",
    lrt   = "text",
    rrt   = "text",
    zln   = "number",
    zrn   = "number",
    rn    = "number",
    lrn   = "number",
    rrn   = "number",
    zn    = "number",
    mov   = "transform",
    mark  = "transform",
    move  = "transform",
    off   = "transform",
    adj   = "transform",
    sub   = "transform",
}

local front_keys = {
    bb    = "line",
    eb    = "line",
    rr    = "line",
    lr    = "line",
    lsr   = "line",
    rsr   = "line",
    lrz   = "text",
    rrz   = "text",
    lsub  = "transform",
    rsub  = "transform",
}

local one_keys = {
    db    = "line",
    tb    = "line",
    bb    = "line",
    rb    = "line",
    dr    = "line",
    hb    = "line",
    bd    = "line",
    bw    = "line",
    oe    = "line",
    sd    = "line",
    ld    = "line",
    rd    = "line",
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
    rb    = "line",
    lrb   = "line",
    rrb   = "line",
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

local definitions = { }

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

local metacode, variant, keys, max, txt, pstack, sstack
local molecule = chemistry.molecule -- or use lpegmatch(chemistry.moleculeparser,...)

local function fetch(txt)
    local st = stack[txt]
    local t = st.text[st.n]
-- inspect(stack)
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
    (amount + Cc(1)) *
    (remapped + Cc("")) *
    Cs(operation/lower) *
    Cs(special/lower) * (
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

local t_initialize      = 'if unknown context_chem : input mp-chem.mpiv ; fi ;'
local t_start_structure = 'chem_start_structure(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s);'
local t_stop_structure  = 'chem_stop_structure;'
local t_start_component = 'chem_start_component;'
local t_stop_component  = 'chem_stop_component;'
local t_line            = 'chem_%s%s(%s,%s,%s,%s,%s);'
local t_set             = 'chem_set(%s);'
local t_number          = 'chem_%s(%s,%s,"\\chemicaltext{%s}");'
local t_text            = t_number
local t_empty_normal    = 'chem_%s(%s,%s,"");'
local t_empty_center    = 'chem_c%s(%s,%s,"");'
local t_transform       = 'chem_%s(%s,%s,%s);'

local function process(spec,text,n,rulethickness,rulecolor,offset)
    insert(stack,{ spec=spec, text=text, n=n })
    local txt = #stack
    local m = #metacode
    for i=1,#spec do
        local step = spec[i]
        local s = lower(step)
        local d = definitions[s]
        if d then
            if trace_structure then
                report_chemistry("%s => definition: %s",step,s)
            end
            for i=1,#d do
                local di = d[i]
                process(di.spec,di.text,1,rulethickness,rulecolor) -- offset?
            end
        else
            --~local rep, operation, special, index, upto, set, text = lpegmatch(pattern,step)
            local factor, osign, operation, special, index, upto, set, text = lpegmatch(pattern,step)
            if trace_structure then
                local set = set and concat(set," ") or "-"
                report_chemistry("%s => factor: %s, osign: %s operation: %s, special: %s, index: %s, upto: %s, set: %s, text: %s",
                    step,factor or "",osign or "",operation or "-",special and special ~= "" or "-",index or "-",upto or "-",set or "-",text or "-")
            end
            if operation == "pb" then
                insert(pstack,variant)
                m = m + 1 ; metacode[m] = syntax.pb.direct
                if keys[special] == "text" and index then
                    if keys["c"..special] == "text" then -- can be option: auto ...
                        m = m + 1 ; metacode[m] = format(t_empty_center,special,variant,index)
                    else
                        m = m + 1 ; metacode[m] = format(t_empty_normal,special,variant,index)
                    end
                end
            elseif operation == "pe" then
                variant = remove(pstack)
                local ss = syntax[variant]
                keys, max = ss.keys, ss.max
                m = m + 1 ; metacode[m] = syntax[operation].direct
                m = m + 1 ; metacode[m] = format(t_set,variant)
            elseif operation == "save" then
                insert(sstack,variant)
                m = m + 1 ; metacode[m] = syntax.save.direct
            elseif operation == "restore" then
                variant = remove(sstack)
                local ss = syntax[variant]
                keys, max = ss.keys, ss.max
                m = m + 1 ; metacode[m] = syntax[operation].direct
                m = m + 1 ; metacode[m] = format(t_set,variant)
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
                        variant, keys, max = s, ss.keys, ss.max
                        m = m + 1 ; metacode[m] = format(t_set,variant)
                    end
                else
                    local what = keys[operation]
                    if what == "line" then
                        local s = osign
                        if s ~= "" then s = "." .. s end
                        if set then
                            -- condense consecutive numbers in a set to a range
                            -- (numbers modulo max are currently not dealt with...)
                            table.sort(set)
                            local sf, st = set[1]
                            for i=1,#set do
                                if i > 1 and set[i] ~= set[i-1]+1 then
                                    m = m + 1 ; metacode[m] = format(t_line,operation,s,variant,sf,st,rulethickness,rulecolor)
                                    sf = set[i]
                                end
                                st = set[i]
                            end
                            m = m + 1 ; metacode[m] = format(t_line,operation,s,variant,sf,st,rulethickness,rulecolor)
                        elseif upto then
                            m = m + 1 ; metacode[m] = format(t_line,operation,s,variant,index,upto,rulethickness,rulecolor)
                        elseif index then
                            m = m + 1 ; metacode[m] = format(t_line,operation,s,variant,index,index,rulethickness,rulecolor)
                        else
                            m = m + 1 ; metacode[m] = format(t_line,operation,s,variant,1,max,rulethickness,rulecolor)
                        end
                    elseif what == "number" then
                        if set then
                            for i=1,#set do
                                local si = set[i]
                                m = m + 1 ; metacode[m] = format(t_number,operation,variant,si,si)
                            end
                        elseif upto then
                            for i=index,upto do
                                local si = set[i]
                                m = m + 1 ; metacode[m] = format(t_number,operation,variant,si,si)
                            end
                        elseif index then
                            m = m + 1 ; metacode[m] = format(t_number,operation,variant,index,index)
                        else
                            for i=1,max do
                                m = m + 1 ; metacode[m] = format(t_number,operation,variant,i,i)
                            end
                        end
                    elseif what == "text" then
                        if set then
                            for i=1,#set do
                                local si = set[i]
                                local t = text
                                if not t then txt, t = fetch(txt) end
                                if t then
                                    t = molecule(processor_tostring(t))
                                    m = m + 1 ; metacode[m] = format(t_text,operation,variant,si,t)
                                end
                            end
                        elseif upto then
                            for i=index,upto do
                                local t = text
                                if not t then txt, t = fetch(txt) end
                                if t then
                                    t = molecule(processor_tostring(t))
                                    m = m + 1 ; metacode[m] = format(t_text,operation,variant,i,t)
                                end
                            end
                        elseif index == 0 then
                            local t = text
                            if not t then txt, t = fetch(txt) end
                            if t then
                                t = molecule(processor_tostring(t))
                                m = m + 1 ; metacode[m] = format(t_text,operation,variant,index,t)
                            end
                        elseif index then
                            local t = text
                            if not t then txt, t = fetch(txt) end
                            if t then
                                t = molecule(processor_tostring(t))
                                m = m + 1 ; metacode[m] = format(t_text,operation,variant,index,t)
                            end
                        else
                            for i=1,max do
                                local t = text
                                if not t then txt, t = fetch(txt) end
                                if t then
                                    t = molecule(processor_tostring(t))
                                    m = m + 1 ; metacode[m] = format(t_text,operation,variant,i,t)
                                end
                            end
                        end
                    elseif what == "transform" then
                        if osign == "m" then factor = -factor end
                        if set then
                            for i=1,#set do
                                local si = set[i]
                                m = m + 1 ; metacode[m] = format(t_transform,operation,variant,si,factor)
                            end
                        elseif upto then
                            for i=index,upto do
                                m = m + 1 ; metacode[m] = format(t_transform,operation,variant,i,factor)
                            end
                        else
                            m = m + 1 ; metacode[m] = format(t_transform,operation,variant,index or 1,factor)
                        end
                    elseif what == "fixed" then
                        m = m + 1 ; metacode[m] = format(t_transform,operation,variant,rulethickness,rulecolor)
                    elseif trace_structure then
                        report_chemistry("warning: undefined operation %s ignored here", operation or "")
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
-- rulethickness in points

function chemistry.start(settings)
    chemistry.structures = chemistry.structures + 1
    local emwidth, rulethickness, rulecolor, axiscolor = settings.emwidth, settings.rulethickness, settings.rulecolor, settings.framecolor
    local width, height, scale, offset = settings.width or 0, settings.height or 0, settings.scale or "normal", settings.offset or 0
    local l, r, t, b = settings.left or 0, settings.right or 0, settings.top or 0, settings.bottom or 0
    --
    metacode = { }
    --
    if trace_structure then
        report_chemistry("scale: %s, width: %s, height: %s, l: %s, r: %s, t: %s, b: %s", scale, width, height, l, r, t, b)
    end
    if scale == variables.small then
        scale = 1/1.2
    elseif scale == variables.normal or scale == variables.medium or scale == 0 then
        scale = 1
    elseif scale == variables.big then
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
    if width == variables.fit then
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
    if height == variables.fit then
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
    --
    metacode[#metacode+1] = format(t_start_structure,
        chemistry.structures,
        l, r, t, b, scale,
        tostring(width), tostring(height), tostring(emwidth), tostring(offset),
        tostring(settings.axis == variables.on), tostring(rulethickness), tostring(axiscolor)
    )
    --
    variant, keys, stack, pstack, sstack = "one", { }, { }, { }, { }
end

function chemistry.stop()
    metacode[#metacode+1] = t_stop_structure
    local mpcode = concat(metacode,"\n")
    if trace_metapost then
        report_chemistry("metapost code:\n%s", mpcode)
    end
    if metapost.instance(chemistry.instance) then
        t_initialize = ""
    end
    metapost.graphic {
        instance    = chemistry.instance,
        format      = chemistry.format,
        data        = mpcode,
        definitions = t_initialize,
    }
    t_initialize = ""
    metacode = nil
end

function chemistry.component(spec,text,settings)
    rulethickness, rulecolor, offset = settings.rulethickness, settings.rulecolor
    local spec = settings_to_array_with_repeat(spec,true) -- no lower?
    local text = settings_to_array_with_repeat(text,true)
-- inspect(spec)
    metacode[#metacode+1] = t_start_component
    process(spec,text,1,rulethickness,rulecolor) -- offset?
    metacode[#metacode+1] = t_stop_component
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
