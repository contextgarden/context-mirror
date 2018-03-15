if not modules then modules = { } end modules ['typo-krn'] = {
    version   = 1.001,
    comment   = "companion to typo-krn.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- glue is still somewhat suboptimal
-- components: better split on tounicode
--
-- maybe ignore when properties[n].injections.cursivex (or mark)

local next, type, tonumber = next, type, tonumber

local nodes              = nodes
local fonts              = fonts

local enableaction       = nodes.tasks.enableaction

local nuts               = nodes.nuts
local nodepool           = nuts.pool

local tonode             = nuts.tonode
local tonut              = nuts.tonut

-- check what is used

local find_node_tail     = nuts.tail
local flush_node         = nuts.flush_node
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local end_of_math        = nuts.end_of_math
local use_components     = nuts.use_components

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar
local getdisc            = nuts.getdisc
local getglue            = nuts.getglue
local getkern            = nuts.getkern
local isglyph            = nuts.isglyph

local setfield           = nuts.setfield
local getattr            = nuts.getattr
local takeattr           = nuts.takeattr
local setlink            = nuts.setlink
local setdisc            = nuts.setdisc
local setglue            = nuts.setglue
local setkern            = nuts.setkern

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local setglue            = nuts.setglue -- todo

local new_kern           = nodepool.kern
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes
local skipcodes          = nodes.skipcodes
local disccodes          = nodes.disccodes
local listcodes          = nodes.listcodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local math_code          = nodecodes.math

local box_list_code      = listcodes.box
local user_list_code     = listcodes.unknown

local discretionary_code = disccodes.discretionary
local automatic_code     = disccodes.automatic

local fontkern_code      = kerncodes.fontkern
local userkern_code      = kerncodes.userkern
local userskip_code      = skipcodes.userskip
local spaceskip_code     = skipcodes.spaceskip
local xspaceskip_code    = skipcodes.xspaceskip

local fonthashes         = fonts.hashes
local chardata           = fonthashes.characters
local quaddata           = fonthashes.quads
local markdata           = fonthashes.marks
local fontproperties     = fonthashes.properties
local fontdescriptions   = fonthashes.descriptions
local fontfeatures       = fonthashes.features

local tracers            = nodes.tracers
local setcolor           = tracers.colors.set
local resetcolor         = tracers.colors.reset

local v_max              = interfaces.variables.max
local v_auto             = interfaces.variables.auto

typesetters              = typesetters or { }
local typesetters        = typesetters

local kerns              = typesetters.kerns or { }
typesetters.kerns        = kerns

local report             = logs.reporter("kerns")
local trace_ligatures    = false  trackers.register("typesetters.kerns.ligatures",       function(v) trace_ligatures   = v end)
local trace_ligatures_d  = false  trackers.register("typesetters.kerns.ligatures.detail",function(v) trace_ligatures_d = v end)

kerns.mapping            = kerns.mapping or { }
kerns.factors            = kerns.factors or { }
local a_kerns            = attributes.private("kern")

local contextsetups      = fonts.specifiers.contextsetups

storage.register("typesetters/kerns/mapping", kerns.mapping, "typesetters.kerns.mapping")
storage.register("typesetters/kerns/factors", kerns.factors, "typesetters.kerns.factors")

local mapping = kerns.mapping
local factors = kerns.factors

-- one must use liga=no and mode=base and kern=yes
-- use more helpers
-- make sure it runs after all others
-- there will be a width adaptor field in nodes so this will change
-- todo: interchar kerns / disc nodes / can be made faster
-- todo: use insert_before etc

local gluefactor = 4 -- assumes quad = .5 enspace

kerns.keepligature = false -- just for fun (todo: control setting with key/value)
kerns.keeptogether = false -- just for fun (todo: control setting with key/value)

-- red   : kept by dynamic feature
-- green : kept by static feature
-- blue  : keep by goodie

function kerns.keepligature(n) -- might become default
    local f = getfont(n)
    local a = getattr(n,0) or 0
    if trace_ligatures then
        local c = getchar(n)
        local d = fontdescriptions[f][c].name
        if a > 0 and contextsetups[a].keepligatures == v_auto then
            if trace_ligatures_d then
                report("font %!font:name!, glyph %a, slot %X -> ligature %s, by %s feature %a",f,d,c,"kept","dynamic","keepligatures")
            end
            setcolor(n,"darkred")
            return true
        end
        local k = fontfeatures[f].keepligatures
        if k == v_auto then
            if trace_ligatures_d then
                report("font %!font:name!, glyph %a, slot %X -> ligature %s, by %s feature %a",f,d,c,"kept","static","keepligatures")
            end
            setcolor(n,"darkgreen")
            return true
        end
        if not k then
            if trace_ligatures_d then
                report("font %!font:name!, glyph %a, slot %X -> ligature %s, by %s feature %a",f,d,c,"split","static","keepligatures")
            end
            resetcolor(n)
            return false
        end
        local k = fontproperties[f].keptligatures
        if not k then
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, %s goodie specification",f,d,c,"split","no")
            resetcolor(n)
            return false
        end
        if k and k[c] then
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, %s goodie specification",f,d,c,"kept","by")
            setcolor(n,"darkblue")
            return true
        else
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, %s goodie specification",f,d,c,"split","by")
            resetcolor(n)
            return false
        end
    else
        if a > 0 and contextsetups[a].keepligatures == v_auto then
            return true
        end
        local k = fontfeatures[f].keepligatures
        if k == v_auto then
            return true
        end
        if not k then
            return false
        end
        local k = fontproperties[f].keptligatures
        if not k then
            return false
        end
        if k and k[c] then
            return true
        end
    end
end

-- can be optimized .. the prev thing .. but hardly worth the effort

local function kern_injector(fillup,kern)
    if fillup then
        local g = new_glue(kern)
        setfield(g,"stretch",kern)
        setfield(g,"stretch_order",1)
        return g
    else
        return new_kern(kern)
    end
end

-- a simple list injector, no components and such .. just disable ligatures in
-- kern mode .. maybe not even hyphenate ... anyway, the next one is for simple
-- sublists .. beware: we can have char -1

local function inject_begin(boundary,prev,keeptogether,krn,ok) -- prev is a glyph
    local char, id = isglyph(boundary)
    if id == kern_code then
        if getsubtype(boundary) == fontkern_code then
            local inject = true
            if keeptogether then
                local next = getnext(boundary)
                if not next or (getid(next) == glyph_code and keeptogether(prev,next)) then
                    inject = false
                end
            end
            if inject then
                -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                setkern(boundary,getkern(boundary) + quaddata[getfont(prev)]*krn,userkern_code)
                return boundary, true
            end
        end
    elseif char then
        if keeptogether and keeptogether(boundary,prev) then
            -- keep 'm
        else
            local prevchar = isglyph(prev)
            if prevchar and prevchar > 0 then
                local font  = getfont(boundary)
                local data  = chardata[font][prevchar]
                local kerns = data and data.kerns
                local kern  = new_kern((kerns and kerns[char] or 0) + quaddata[font]*krn)
                setlink(kern,boundary)
                return kern, true
            end
        end
    end
    return boundary, ok
end

local function inject_end(boundary,next,keeptogether,krn,ok)
    local tail = find_node_tail(boundary)
    local char, id = getid(tail)
    if id == kern_code then
        if getsubtype(tail) == fontkern_code then
            local inject = true
            if keeptogether then
                local prev = getprev(tail)
                if getid(prev) == glyph_code and keeptogether(prev,two) then
                    inject = false
                end
            end
            if inject then
                -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                setkern(tail,getkern(tail) + quaddata[getfont(next)]*krn,userkern_code)
                return boundary, true
            end
        end
    elseif char then
        if keeptogether and keeptogether(tail,two) then
            -- keep 'm
        else
            local nextchar = isglyph(tail)
            if nextchar and nextchar > 0 then
                local font  = getfont(tail)
                local data  = chardata[font][nextchar]
                local kerns = data and data.kerns
                local kern  = (kerns and kerns[char] or 0) + quaddata[font]*krn
                setlink(tail,new_kern(kern))
                return boundary, true
            end
        end
    end
    return boundary, ok
end

local function process_list(head,keeptogether,krn,font,okay)
    local start = head
    local prev  = nil
    local pid   = nil
    local kern  = 0
    local mark  = font and markdata[font]
    while start  do
        local char, id = isglyph(start)
        if char then
            if not font then
                font = getfont(start)
                mark = markdata[font]
                kern = quaddata[font]*krn
            end
            if prev then
                if mark[char] then
                    -- skip
                elseif pid == kern_code then
                    if getsubtype(prev) == fontkern_code then
                        local inject = true
                        if keeptogether then
                            local prevprev = getprev(prev)
                            if getid(prevprev) == glyph_code and keeptogether(prevprev,start) then
                                inject = false
                            end
                        end
                        if inject then
                            -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                            setkern(prev,getkern(prev) + kern,userkern_code)
                            okay = true
                        end
                    end
                elseif pid == glyph_code then
                    if keeptogether and keeptogether(prev,start) then
                        -- keep 'm
                    else
                        local prevchar = getchar(prev)
                        local data     = chardata[font][prevchar]
                        local kerns    = data and data.kerns
                     -- if kerns then
                     --     print("it happens indeed, basemode kerns not yet injected")
                     -- end
                        insert_node_before(head,start,new_kern((kerns and kerns[char] or 0) + kern))
                        okay = true
                    end
                end
            end
        end
        if start then
            prev  = start
            pid   = id
            start = getnext(start)
        end
    end
    return head, okay, prev
end

local function closest_bound(b,get)
    b = get(b)
    if b and getid(b) ~= glue_code then
        while b do
            if not getattr(b,a_kerns) then
                break
            elseif getid(b) == glyph_code then
                return b, getfont(b)
            else
                b = get(b)
            end
        end
    end
end

function kerns.handler(head)
    local head         = tonut(head)
    local start        = head
    local done         = false
    local lastfont     = nil
    local keepligature = kerns.keepligature
    local keeptogether = kerns.keeptogether
    local fillup       = false
    local bound        = false
    local prev         = nil
    local previd       = nil
    local prevchar     = nil
    local prevfont     = nil
    local prevmark     = nil
    while start do
        -- fontkerns don't get the attribute but they always sit between glyphs so
        -- are always valid bound .. disc nodes also somtimes don't get them
        local id   = getid(start)
        local attr = takeattr(start,a_kerns)
        if attr and attr > 0 then
            local krn = mapping[attr]
            if krn == v_max then
                krn    = .25
                fillup = true
            else
                fillup = false
            end
            if not krn or krn == 0 then
                bound = false
            elseif id == glyph_code then
                if keepligature and keepligature(start) then
                    -- keep 'm
                else
                    -- we could use the subtype ligature but that's also a call
                    -- todo: check tounicode and use that information to split
                    head, start = use_components(head,start)
                end
                local char = getchar(start)
                local font = getfont(start)
                local mark = markdata[font]
                if not bound then
                    -- yet
                elseif mark[char] then
                    -- skip
                elseif previd == kern_code then
                    if getsubtype(prev) == fontkern_code then
                        local inject = true
                        if keeptogether then
                            if previd == glyph_code and keeptogether(prev,start) then
                                inject = false
                            end
                        end
                        if inject then
                            -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                            setkern(prev,getkern(prev) + quaddata[font]*krn,userkern_code)
                            done = true
                        end
                    end
                elseif previd == glyph_code then
                    if prevfont == font then
                        if keeptogether and keeptogether(prev,start) then
                            -- keep 'm
                        else
                            local data  = chardata[font][prevchar]
                            local kerns = data and data.kerns
                            local kern  = (kerns and kerns[char] or 0) + quaddata[font]*krn
                            insert_node_before(head,start,kern_injector(fillup,kern))
                            done = true
                        end
                    else
                        insert_node_before(head,start,kern_injector(fillup,quaddata[font]*krn))
                        done = true
                    end
                end
                prev     = start
                prevchar = char
                prevfont = font
                prevmark = mark
                previd   = id
                bound    = true
            elseif id == disc_code then
                local prev, next, pglyph, nglyph -- delayed till needed
                local subtype = getsubtype(start)
             -- if subtype == automatic_code then
             --     -- this is kind of special, as we have already injected the
             --     -- previous kern
             --     local prev   = getprev(start)
             --     local pglyph = prev and getid(prev) == glyph_code
             --     languages.expand(start,pglyph and prev)
             --     -- we can have a different start now
             -- elseif subtype ~= discretionary_code then
             --     prev    = getprev(start)
             --     pglyph  = prev and getid(prev) == glyph_code
             --     languages.expand(start,pglyph and prev)
             -- end
                local pre, post, replace = getdisc(start)
                local indeed = false
                if pre then
                    local okay = false
                    if not prev then
                        prev   = getprev(start)
                        pglyph = prev and getid(prev) == glyph_code
                    end
                    if pglyph then
                        pre, okay = inject_begin(pre,prev,keeptogether,krn,okay)
                    end
                    pre, okay = process_list(pre,keeptogether,krn,false,okay)
                    if okay then
                        indeed = true
                    end
                end
                if post then
                    local okay = false
                    if not next then
                        next   = getnext(start)
                        nglyph = next and getid(next) == glyph_code
                    end
                    if nglyph then
                        post, okay = inject_end(post,next,keeptogether,krn,okay)
                    end
                    post, okay = process_list(post,keeptogether,krn,false,okay)
                    if okay then
                        indeed = true
                    end
                end
                if replace then
                    local okay = false
                    if not prev then
                        prev    = getprev(start)
                        pglyph  = prev and getid(prev) == glyph_code
                    end
                    if pglyph then
                        replace, okay = inject_begin(replace,prev,keeptogether,krn,okay)
                    end
                    if not next then
                        next   = getnext(start)
                        nglyph = next and getid(next) == glyph_code
                    end
                    if nglyph then
                        replace, okay = inject_end(replace,next,keeptogether,krn,okay)
                    end
                    replace, okay = process_list(replace,keeptogether,krn,false,okay)
                    if okay then
                        indeed = true
                    end
                elseif prevfont then
                    replace = new_kern(quaddata[prevfont]*krn)
                    indeed  = true
                end
                if indeed then
                    setdisc(start,pre,post,replace)
                    done = true
                end
                bound = false
            elseif id == kern_code then
                bound  = getsubtype(start) == fontkern_code
                prev   = start
                previd = id
            elseif id == glue_code then
                local subtype = getsubtype(start)
                if subtype == userskip_code or subtype == xspaceskip_code or subtype == spaceskip_code then
                    local width, stretch, shrink, stretch_order, shrink_order = getglue(start)
                    if width > 0 then
                        local w = width + gluefactor * width * krn
                        stretch = stretch * w / width
                        shrink  = shrink  * w / width
                        if fillup then
                            stretch = 2 * stretch
                            shrink  = 2 * shrink
                            stretch_order = 1
                         -- shrink_order  = 1 ?
                        end
                        setglue(start,w,stretch,shrink,stretch_order,shrink_order)
                        done = true
                    end
                end
                bound = false
            elseif id == hlist_code or id == vlist_code then
                local subtype = getsubtype(start)
                if subtype == user_list_code or subtype == box_list_code then
                    -- special case
                    local b, f = closest_bound(start,getprev)
                    if b then
                        insert_node_before(head,start,kern_injector(fillup,quaddata[f]*krn))
                        done = true
                    end
                    local b, f = closest_bound(start,getnext)
                    if b then
                        insert_node_after(head,start,kern_injector(fillup,quaddata[f]*krn))
                        done = true
                    end
                end
                bound = false
            elseif id == math_code then
                start = end_of_math(start)
                bound = false
            end
            if start then
                start = getnext(start)
            end
        elseif id == kern_code then
            bound  = getsubtype(start) == fontkern_code
            prev   = start
            previd = id
            start  = getnext(start)
        else
            bound = false
            start = getnext(start)
        end
    end
    return tonode(head), done
end

local enabled = false

function kerns.set(factor)
    if factor ~= v_max then
        factor = tonumber(factor) or 0
    end
    if factor == v_max or factor ~= 0 then
        if not enabled then
            enableaction("processors","typesetters.kerns.handler")
            enabled = true
        end
        local a = factors[factor]
        if not a then
            a = #mapping + 1
            factors[factors], mapping[a] = a, factor
        end
        factor = a
    else
        factor = unsetvalue
    end
    texsetattribute(a_kerns,factor)
    return factor
end

-- interface

interfaces.implement {
    name      = "setcharacterkerning",
    actions   = kerns.set,
    arguments = "string"
}

