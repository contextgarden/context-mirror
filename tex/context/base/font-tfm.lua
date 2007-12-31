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

--[[ldx--
<p>The next function encapsulates the standard <l n='tfm'/> loader as
supplied by <l n='luatex'/>.</p>
--ldx]]--

fonts.tfm.resolve_vf = true -- false

function fonts.tfm.enhance(tfmdata,specification)
    local name, size = specification.name, specification.size
    local encoding, filename = name:match("^(.-)%-(.*)$") -- context: encoding-name.*
    if filename and encoding and fonts.enc.known[encoding] then
        local data = fonts.enc.load(encoding)
        if data then
            local characters = tfmdata.characters
            tfmdata.encoding = encoding
            local vector = data.vector
            for k, v in pairs(characters) do
                v.name = vector[k]
                v.index = k
            end
            for k,v in pairs(data.unicodes) do
                if k ~= v then
                --  if not characters[k] then
                        if fonts.trace then
                            logs.report("define font",string.format("mapping %s onto %s",k,v))
                        end
                        characters[k] = characters[v]
                --  end
                end
            end
        end
    end
end

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
        tfmdata = font.read_tfm(fname,specification.size) -- not cached, fast enough
        if tfmdata then
            if fonts.tfm.resolve_vf then
                fonts.logger.save(tfmdata,file.extname(fname),specification) -- strange, why here
                fname = input.findbinfile(texmf.instance, specification.name, 'ovf')
                if fname and fname ~= "" then
                    local vfdata = font.read_vf(fname,specification.size) -- not cached, fast enough
                    if vfdata then
                        local chars = tfmdata.characters
                        for k,v in pairs(vfdata.characters) do -- no ipairs, can have holes
                            chars[k].commands = v.commands
                        end
                        tfmdata.type = 'virtual'
                        tfmdata.fonts = vfdata.fonts
                    end
                end
--~ print(table.serialize(tfmdata))
            end
            fonts.tfm.enhance(tfmdata,specification)
        end
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

do

    local factors = {
        pt = 65536.0,
        bp = 65781.8,
    }

    function fonts.tfm.setfactor(f)
        fonts.tfm.factor = factors[f or 'pt'] or factors.pt
    end

    fonts.tfm.setfactor()

end

function fonts.tfm.scaled(scaledpoints, designsize) -- handles designsize in sp as well
    if scaledpoints < 0 then
        if designsize then
            if designsize > fonts.tfm.factor then -- or just 1000 / when? mp?
                return (- scaledpoints/1000) * designsize -- sp's
            else
                return (- scaledpoints/1000) * designsize * fonts.tfm.factor
            end
        else
            return (- scaledpoints/1000) * 10 * fonts.tfm.factor
        end
    else
        return scaledpoints
    end
end

--~ function fonts.tfm.scaled(scaledpoints, designsize)
--~     if scaledpoints < 0 then
--~         return (- scaledpoints/1000) * (designsize or 10) * fonts.tfm.factor
--~     else
--~         return scaledpoints
--~     end
--~ end

--[[ldx--
<p>Before a font is passed to <l n='tex'/> we scale it. Here we also need
to scale virtual characters.</p>
--ldx]]--

function fonts.tfm.get_virtual_id(tfmdata)
    --  since we don't know the id yet, we use 0 as signal
    if not tfmdata.fonts then
        tfmdata.type = "virtual"
        tfmdata.fonts = { { id = 0 } }
        return 1
    else
        tfmdata.fonts[#tfmdata.fonts+1] = { id = 0 }
        return #tfmdata.fonts
    end
end

function fonts.tfm.check_virtual_id(tfmdata, id)
    if tfmdata.type == "virtual" then
        if not tfmdata.fonts or #tfmdata.fonts == 0 then
            tfmdata.type, tfmdata.fonts = "real", nil
        else
            for k,v in ipairs(tfmdata.fonts) do
                if v.id and v.id == 0 then
                    v.id = id
                end
            end
        end
    end
end

--[[ldx--
<p>Beware, the boundingbox is passed as reference so we may not overwrite it
in the process; numbers are of course copies. Here 65536 equals 1pt. (Due to
excessive memory usage in CJK fonts, we no longer pass the boundingbox.)</p>
--ldx]]--

local xxx = 0

function fonts.tfm.do_scale(tfmtable, scaledpoints)
    if scaledpoints < 0 then
        scaledpoints = (- scaledpoints/1000) * tfmtable.designsize -- already in sp
    end
    local delta = scaledpoints/(tfmtable.units or 1000) -- brr, some open type fonts have 2048
    local t = { }
    t.factor = delta
    for k,v in pairs(tfmtable) do
        t[k] = (type(v) == "table" and { }) or v
    end
    local tc = t.characters
    local trace = fonts.trace
 -- local zerobox = { 0, 0, 0, 0 }
    for k,v in pairs(tfmtable.characters) do
        local description = v.description or v -- shared data
        local chr = {
            unicode = description.unicode,
            name    = description.name,
            index   = description.index or k,
            width   = delta*(description.width  or 0),
            height  = delta*(description.height or 0),
            depth   = delta*(description.depth  or 0),
            class   = description.class
        }
        if trace then
            logs.report("define font", string.format("n=%s, u=%s, i=%s, n=%s c=%s",k,description.unicode,description.index,description.name or '-',description.class or '-'))
        end
    --  local vb = v.boundingbox
    --  if vb then
    --      chr.boundingbox = { vb[1]*delta, vb[2]*delta, vb[3]*delta, vb[4]*delta }
    --  else
    --  --  chr.boundingbox = zerobox -- most afm en otf files have bboxes so ..
    --  end
        local vi = description.italic
        if vi then
            chr.italic = vi*delta
        end
        local vk = v.kerns
        if vk then
            local tt = {}
            for k,v in pairs(vk) do tt[k] = v*delta end
            chr.kerns = tt
        end
        local vl = v.ligatures
        if vl then
            if true then
                chr.ligatures = vl -- shared
            else
                local tt = { }
                for i,l in pairs(vl) do
                    tt[i] = l
                end
                chr.ligatures = tt
            end
        end
        local vc = v.commands
        if vc then
            -- we assume non scaled commands here
            local tt = { }
            for i=1,#vc do
                local ivc = vc[i]
                local key = ivc[1]
                if key == "right" or key == "left" or key == "down" or key == "up" then
                    tt[#tt+1] = { key, ivc[2]*delta }
                else
                    tt[#tt+1] = ivc -- shared since in cache and untouched
                end
            end
            chr.commands = tt
        end
        tc[k] = chr
    end
    local tp = t.parameters
    for k,v in pairs(tfmtable.parameters) do
        if k == 1 then
            tp[k] = v
        else
            tp[k] = v*delta
        end
    end
    -- t.encodingbytes, t.filename, t.fullname, t.name: elsewhere
    t.size = scaledpoints
    if t.fonts then
        t.fonts = table.fastcopy(t.fonts) -- maybe we virtualize more afterwards
    end
    return t, delta
end

--[[ldx--
<p>The reason why the scaler is split, is that for a while we experimented
with a helper function. However, in practice the <l n='api'/> calls are too slow to
make this profitable and the <l n='lua'/> based variant was just faster. A days
wasted day but an experience richer.</p>
--ldx]]--

function fonts.tfm.scale(tfmtable, scaledpoints)
    local t, factor = fonts.tfm.do_scale(tfmtable, scaledpoints)
    t.factor    = factor
    t.ascender  = factor*(tfmtable.ascender  or 0)
    t.descender = factor*(tfmtable.descender or 0)
    t.shared    = tfmtable.shared or { }
    t.unique    = table.fastcopy(tfmtable.unique or {})
--~ print("scaling", t.name, t.factor) -- , fonts.tfm.hash_features(tfmtable.specification))
    return t
end

--[[ldx--
<p>The following functions are used for reporting about the fonts
used. The message itself is not that useful in regular runs but since
we now have several readers it may be handy to know what reader is
used for which font.</p>
--ldx]]--

function fonts.logger.save(tfmtable,source,specification) -- save file name in spec here ! ! ! ! ! !
    if tfmtable and specification and specification.specification then
        if fonts.trace then
            logs.report("define font",string.format("registering %s as %s",specification.name,source))
        end
        specification.source = source
        fonts.loaded[specification.specification] = specification
        fonts.used[specification.name] = source
    end
end

function fonts.logger.report(separator)
    local s = table.sortedkeys(fonts.loaded)
    if #s > 0 then
        local t = { }
        for _,v in ipairs(s) do
            t[#t+1] = v .. ":" .. fonts.loaded[v].source
        end
        return table.concat(t,separator or " ")
    else
        return "none"
    end
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
<p>The following feature is kind of experimental and deals with fallback characters.</p>
--ldx]]--

fonts.initializers.complements      = fonts.initializers.complements      or { }
fonts.initializers.complements.data = fonts.initializers.complements.data or { }

function fonts.initializers.complements.load(pattern)
    local data = fonts.initializers.complements.data[pattern]
    if not data then
        data = { }
        for k,v in pairs(characters.data) do
            local vd = v.description
            if vd and vd:find(pattern) then
                local vs = v.specials
                if vs and vs[1] == "compat" then
                    data[#data+1] = k
                end
            end
        end
        fonts.initializers.complements.data[pattern] = data
    end
    return data
end

function fonts.initializers.common.complement(tfmdata,value) -- todo: value = latin:compat,....
    if value then
        local chr, index, data, get_virtual_id = tfmdata.characters, nil, characters.data, fonts.tfm.get_virtual_id
        local selection = fonts.initializers.complements.load("LATIN") -- will be value
    --  for _, k in ipairs(selection) do
        for i=1,#selection do
            local k = selection[i]
            if not chr[k] then
                local dk = data[k]
                local vs, name = dk.specials, dk.adobename
                index = index or get_virtual_id(tfmdata)
                local ok, t, w, h, d, krn, pre = true, {}, 0, 0, 0, nil, nil
                for i=2,#vs do
                    local vsi = vs[i]
                    local c = chr[vsi]
                    if c then
                        local k = krn and krn[vsi]
                        if k then
                            t[#t+1] = { 'right', k }
                            w = w + k
                        end
                        t[#t+1] = { 'slot', index, vsi }
                        w = w + c.width
                        h = h + c.height
                        d = d + c.depth
                        krn = c.kerns
                    else
                        ok = false
                        break
                    end
                end
                if ok then
                    chr[k] = {
                        unicode  = k,
                        name     = name,
                        commands = t,
                        width    = w,
                        height   = h,
                        depth    = d,
                        kerns    = krn
                    }
                    local c = vs[2]
                    for k,v in pairs(chr) do -- slow
                        local krn = v.kerns
                        if krn then
                            krn[k] = krn[c]
                        end
                    end
                end
            end
        end
    end
end

table.insert(fonts.triggers,"complement")

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
--  local unset_attribute = node.unset_attribute
--  local has_attribute   = node.has_attribute

    local state = attributes.numbers['state'] or 100

    -- todo: analyzers per script/lang, cross font, so we need an font id hash -> script
    -- e.g. latin -> hyphenate, arab -> 1/2/3 analyze

    -- an example analyzer

    function fonts.analyzers.aux.setstate(head,font)
        local characters = fontdata[font].characters
        local first, last, current, n, done = nil, nil, head, 0, false -- maybe make n boolean
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
            else -- finish
                if first and first == last then
                    set_attribute(last,state,4) -- isol
                elseif last then
                    set_attribute(last,state,3) -- fina
                end
                first, last, n = nil, nil, 0
            end
            current = current.next
        end
        if first and first == last then
            set_attribute(last,state,4) -- isol
        elseif last then
            set_attribute(last,state,3) -- fina
        end
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
                        current.prev = nil -- last.components.prev = nil
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

function fonts.tfm.replacements(tfm,value)
--~     tfm.characters[0x0022] = table.fastcopy(tfm.characters[0x201D])
--~     tfm.characters[0x0027] = table.fastcopy(tfm.characters[0x2019])
--~     tfm.characters[0x0060] = table.fastcopy(tfm.characters[0x2018])
    tfm.characters[0x0022] = tfm.characters[0x201D]
    tfm.characters[0x0027] = tfm.characters[0x2019]
    tfm.characters[0x0060] = tfm.characters[0x2018]
end
