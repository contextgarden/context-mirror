if not modules then modules = { } end modules ['font-tfm'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Here we only implement a few helper functions.</p>
--ldx]]--

fonts            = fonts            or { }
fonts.loaded     = fonts.loaded     or { }
fonts.dontembed  = fonts.dontembed  or { }
fonts.logger     = fonts.logger     or { }
fonts.loadtime   = 0
fonts.tfm        = fonts.tfm        or { }
fonts.triggers   = fonts.triggers   or { } -- brrr
fonts.trace      = false

--[[ldx--
<p>The next function encapsulates the standard <l n='tfm'/> loader as
supplied by <l n='luatex'/>.</p>
--ldx]]--

function fonts.tfm.read_from_tfm(specification)
    local fname, tfmdata = specification.filename, nil
    if fname then
        -- safeguard, we use tfm as fallback
        local suffix = file.extname(fname)
        if suffix ~= "" and suffix ~= "tfm" then
            fname = ""
        end
    end
    if not fname or fname == "" then
        fname = input.findbinfile(texmf.instance, specification.name, 'ofm')
    else
        fname = input.findbinfile(texmf.instance, fname, 'ofm')
    end
    if fname and fname ~= "" then
        if fonts.trace then
            logs.report("define font",string.format("loading tfm file %s at size %s",fname,specification.size))
        end
        tfmdata = font.read_tfm(fname,specification.size)
    else
        if fonts.trace then
            logs.report("define font",string.format("loading tfm with name %s fails",specification.name))
        end
    end
    return tfmdata
end

--[[ldx--
<p>We need to normalize the scale factor (in scaled points). This has to
do with the fact that <l n='tex'/> uses a negative multiple of 1000 as
a signal for a font scaled based on the design size.</p>
--ldx]]--

function fonts.tfm.scaled(scaledpoints, designsize) -- handles designsize in sp as well
    if scaledpoints < 0 then
        if designsize then
            if designsize > 65536 then -- or just 1000
                return (- scaledpoints/1000) * designsize -- sp's
            else
                return (- scaledpoints/1000) * designsize * 65536
            end
        else
            return (- scaledpoints/1000) * 10 * 65536
        end
    else
        return scaledpoints
    end
end

--[[ldx--
<p>Before a font is passed to <l n='tex'/> we scale it.</p>
--ldx]]--

function fonts.tfm.scale(tfmtable, scaledpoints)
    -- 65536 = 1pt
    -- 1000 units per designsize (not always)
    local scale, round = tex.scale, tex.round -- replaces math.floor(n*m+0.5)
    local delta
    if scaledpoints < 0 then
        scaledpoints = (- scaledpoints/1000) * tfmtable.designsize -- already in sp
    end
    delta = scaledpoints/(tfmtable.units or 1000) -- brr, some open type fonts have 2048
    local t = { }
    t.factor = delta
    for k,v in pairs(tfmtable) do
        if type(v) == "table" then
            t[k] = { }
        else
            t[k] = v
        end
    end
    local tc = t.characters
    for k,v in pairs(tfmtable.characters) do
        local chr = {
            unicode     = v.unicode,
            name        = v.name,
            index       = v.index or k,
            width       = scale(v.width , delta),
            height      = scale(v.height, delta),
            depth       = scale(v.depth , delta),
            class       = v.class
        }
        local b = v.boundingbox -- maybe faster to have llx etc not in table
        if b then
            chr.boundingbox = scale(v.boundingbox,delta)
        end
        if v.italic then
            chr.italic = scale(v.italic,delta)
        end
        if v.kerns then
            chr.kerns = scale(v.kerns,delta)
        end
        if v.ligatures then
            local tt = { }
            for kk,vv in pairs(v.ligatures) do
                tt[kk] = vv
            end
            chr.ligatures = tt
        end
        tc[k] = chr
    end
    local tp = t.parameters
    for k,v in pairs(tfmtable.parameters) do
        if k == 1 then
            tp[k] = round(v)
        else
            tp[k] = scale(v,delta)
        end
    end
--~     t.encodingbytes = tfmtable.encodingbytes or 2
    t.size          = scaledpoints
    t.italicangle   = tfmtable.italicangle
    t.ascender      = scale(tfmtable.ascender  or 0,delta)
    t.descender     = scale(tfmtable.descender or 0,delta)
    -- new / some data will move here
    t.shared = tfmtable.shared or { }
    if t.unique then
        t.unique = table.fastcopy(tfmtable.unique)
    else
        t.unique = { }
    end
    return t
end

--[[ldx--
<p>The following functions are used for reporting about the fonts
used. The message itself is not that useful in regular runs but since
we now have several readers it may be handy to know what reader is
used for which font.</p>
--ldx]]--

function fonts.logger.save(tfmtable,source,specification)
    if tfmtable and specification and specification.specification then
        specification.source = source
        fonts.loaded[specification.specification] = specification
        fonts.used[specification.name] = source
    end
end

function fonts.logger.report(separator)
    local t = { }
    for _,v in pairs(table.sortedkeys(fonts.loaded)) do
        t[#t+1] = v .. ":" .. fonts.loaded[v].source
    end
    return table.concat(t,separator or " ")
end

function fonts.logger.format(name)
    return fonts.used[name] or "unknown"
end

--[[ldx--
<p>When we implement functions that deal with features, most of them
will depend of the font format. Here we define the few that are kind
of neutral.</p>
--ldx]]--

fonts.initializers        = fonts.initializers        or { }
fonts.initializers.common = fonts.initializers.common or { }

--[[ldx--
<p>This feature will remove inter-digit kerns.</p>
--ldx]]--

table.insert(fonts.triggers,"equaldigits")

function fonts.initializers.common.equaldigits(tfmdata,value)
    if value then
        local chr = tfmdata.characters
        for i = utf.byte('0'), utf.byte('9') do
            local c = chr[i]
            if c then
                c.kerns = nil
            end
        end
    end
end

--[[ldx--
<p>This feature will give all glyphs an equal height and/or depth. Valid
values are <type>none</type>, <type>height</type>, <type>depth</type> and
<type>both</type>.</p>
--ldx]]--

table.insert(fonts.triggers,"lineheight")

function fonts.initializers.common.lineheight(tfmdata,value)
    if value and type(value) == "string" then
        if value == "none" then
            for _,v in pairs(tfmdata.characters) do
                v.height, v.depth = 0, 0
            end
        else
            local ascender, descender = tfmdata.ascender, tfmdata.descender
            if ascender and descender then
                local ht, dp = ascender or 0, descender or 0
                if value == "height" then
                    dp = 0
                elseif value == "depth" then
                    ht = 0
                end
                if ht > 0 then
                    if dp > 0 then
                        for _,v in pairs(tfmdata.characters) do
                            v.height, v.depth = ht, dp
                        end
                    else
                        for _,v in pairs(tfmdata.characters) do
                            v.height = ht
                        end
                    end
                elseif dp > 0 then
                    for _,v in pairs(tfmdata.characters) do
                        v.depth  = dp
                    end
                end
            end
        end
    end
end

--[[ldx--
<p>It does not make sense any more to support messed up encoding vectors
so we stick to those that implement oldstyle and small caps. After all,
we move on. We can extend the next function on demand. This features is
only used with <l n='afm'/> files.</p>
--ldx]]--

do

    local smallcaps = lpeg.P(".sc") + lpeg.P(".smallcaps") + lpeg.P(".caps") + lpeg.P("small")
    local oldstyle  = lpeg.P(".os") + lpeg.P(".oldstyle")  + lpeg.P(".onum")

    smallcaps = lpeg.Cs((1-smallcaps)^1) * smallcaps^1
    oldstyle  = lpeg.Cs((1-oldstyle )^1) * oldstyle ^1

    function fonts.initializers.common.encoding(tfmdata,value)
        if value then
            local encodingfile = value .. '.enc'
            local encoding = fonts.enc.load(encodingfile)
            if encoding then
            --  tfmdata.encoding = value
                local vector = encoding.vector
                local afmdata = tfmdata.shared.afmdata
                local characters = tfmdata.characters
                local unicodes = afmdata.luatex.unicodes
                local function remap(pattern,name)
                    local p = lpeg.match(pattern,name)
                    if p then
                        local oldchr, newchr = unicodes[p], unicodes[name]
                        if oldchr and newchr then
                         -- texio.write_nl(string.format("%s (%s) -> %s (%s)",p,oldchr or -1,name,newchr or -1))
                            characters[oldchr] = characters[newchr]
                        end
                    end
                    return p
                end
                for _, name in pairs(vector) do
                    local ok = remap(smallcaps,name) or remap(oldstyle,name)
                end
                if fonts.map.data[tfmdata.name] then
                    fonts.map.data[tfmdata.name].encoding = encodingfile
                end
            end
        end
    end

    -- when needed we can provide this as features in e.g. afm files

    function fonts.initializers.common.remap(tfmdata,value,pattern)
        if value then
            local afmdata = tfmdata.shared.afmdata
            local characters = tfmdata.characters
            local unicodes = afmdata.luatex.unicodes
            local function remap(pattern,name)
                local p = lpeg.match(pattern,name)
                if p then
                    local oldchr, newchr = unicodes[p], unicodes[name]
                    if oldchr and newchr then
                        characters[oldchr] = characters[newchr]
                    end
                end
                return p
            end
            for _, blob in pairs(characters) do
                remap(pattern,blob.name)
            end
        end
    end

    function fonts.initializers.common.oldstyle(tfmdata,value)
        fonts.initializers.common.remap(tfmdata,value,oldstyle)
    end
    function fonts.initializers.common.smallcaps(tfmdata,value)
        fonts.initializers.common.remap(tfmdata,value,smallcaps)
    end

end

--~ function fonts.initializers.common.install(format,feature) -- 'afm','lineheight'
--~     fonts.initializers.base[format][feature] = fonts.initializers.common[feature]
--~     fonts.initializers.node[format][feature] = fonts.initializers.common[feature]
--~ end

--[[ldx--
<p>Analyzers run per script and/or language and are needed in order to
process features right.</p>
--ldx]]--

fonts.analyzers              = fonts.analyzers              or { }
fonts.analyzers.aux          = fonts.analyzers.aux          or { }
fonts.analyzers.methods      = fonts.analyzers.methods      or { }
fonts.analyzers.initializers = fonts.analyzers.initializers or { }

do

    local glyph           = node.id('glyph')
    local fontdata        = fonts.tfm.id
    local set_attribute   = node.set_attribute
    local unset_attribute = node.unset_attribute
    local has_attribute   = node.has_attribute

    local state = attributes.numbers['state'] or 100

    -- todo: analyzers per script/lang, cross font, so we need an font id hash -> script
    -- e.g. latin -> hyphenate, arab -> 1/2/3 analyze

    -- an example analyzer

    function fonts.analyzers.aux.setstate(head,font)
        local characters = fontdata[font].characters
        local first, last, current, n, done = nil, nil, head, 0, false -- maybe make n boolean
        local function finish()
            if first and first == last then
                set_attribute(last,state,4) -- isol
            elseif last then
                set_attribute(last,state,3) -- fina
            end
            first, last, n = nil, nil, 0
        end
        while current do
            if current.id == glyph and current.font == font then
                if characters[current.char].class == "mark" then
                    done = true
                    set_attribute(current,state,5) -- mark
                elseif n == 0 then
                    first, last, n = current, current, 1
                    set_attribute(current,state,1) -- init
                else
                    last, n = current, n+1
                    set_attribute(current,state,2) -- medi
                end
            else
                finish()
            end
            current = current.next
        end
        finish()
        return head, done
    end

end


--[[ldx--
<p>We move marks into the components list. This saves much nasty testing later on.</p>
--ldx]]--

do

    local glyph         = node.id('glyph')
    local fontdata      = fonts.tfm.id
    local marknumber    = attributes.numbers['mark'] or 200
    local set_attribute = node.set_attribute

    function fonts.pushmarks(head,font)
        local tfmdata = fontdata[font]
        local characters = tfmdata.characters
        local current, last, done, n = head, nil, false, 0
        while current do
            if current.id == glyph and current.font == font then
                if characters[current.char].class == "mark" then
                    -- check if head
                    if last and not last.components then
                        last.components = current
                        last.components.prev = nil
                        done = true
                        n = 1
                    else
                        n = n + 1
                    end
                    set_attribute(current,marknumber,n)
                    current = current.next
                elseif last and last.components then
                    -- finish 'm
                    current.prev.next = nil
                    current.prev = last
                    last.next = current
                    last = current
                    last = nil
                else
                    last = current
                    current = current.next
                end
            elseif last and last.components then
                current.prev.next = nil
                current.prev = last
                last.next = current
                last = nil
            else
                last = nil
                current = current.next
            end
        end
        if last and last.components then
            last.next = nil
        end
        tfmdata.shared.markspushed = done
        return head, done
    end

    function fonts.removemarks(head,font)
        local current, done, characters = head, false, tfmdata.characters
        while current do
            if current.id == glyph and current.font == font and characters[current.char].class == "mark" then
                local next, prev = current.next, current.prev
                if next then
                    next.prev = prev
                end
                if prev then
                    prev.next = next
                else
                    head = next
                end
                node.free(current)
                current = next
                done = true
            else
                current = current.next
            end
        end
        return head, done
    end

    function fonts.popmarks(head,font)
        local tfmdata = fontdata[font]
        if tfmdata.shared.markspushed then
            local current, done, characters = head, false, tfmdata.characters
            while current do
                if current.id == glyph and current.font == font then
                    local components = current.components
                    if components then
                        local last, next = components, current.next
                        while last.next do last = last.next end
                        if next then
                            next.prev = last
                        end
                        last.next= next
                        current.next = components
                        components.prev = current
                        current.components = nil
                        current = last.next
                        done = true
                    else
                        current = current.next
                    end
                else
                    current = current.next
                end
            end
            return head, done
        else
            return head, false
        end
    end

end
