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

fonts     = fonts     or { }
fonts.tfm = fonts.tfm or { }

local tfm = fonts.tfm

fonts.loaded     = fonts.loaded    or { }
fonts.dontembed  = fonts.dontembed or { }
fonts.logger     = fonts.logger    or { }
fonts.loadtime   = 0
fonts.triggers   = fonts.triggers  or { } -- brrr

--[[ldx--
<p>The next function encapsulates the standard <l n='tfm'/> loader as
supplied by <l n='luatex'/>.</p>
--ldx]]--

tfm.resolve_vf = true -- false

function tfm.enhance(tfmdata,specification)
    local name, size = specification.name, specification.size
    local encoding, filename = name:match("^(.-)%-(.*)$") -- context: encoding-name.*
    if filename and encoding and fonts.enc.known[encoding] then
        local data = fonts.enc.load(encoding)
        if data then
            local characters = tfmdata.characters
            tfmdata.encoding = encoding
            local vector = data.vector
            local original = { }
            for k, v in pairs(characters) do
                v.name = vector[k]
                v.index = k
                original[k] = v
            end
            for k,v in pairs(data.unicodes) do
                if k ~= v then
                    if fonts.trace then
                        logs.report("define font","mapping %s onto %s",k,v)
                    end
                    characters[k] = original[v]
                end
            end
        end
    end
end

function tfm.read_from_tfm(specification)
    local fname, tfmdata = specification.filename, nil
    if fname then
        -- safeguard, we use tfm as fallback
        local suffix = file.extname(fname)
        if suffix ~= "" and suffix ~= "tfm" then
            fname = ""
        end
    end
    if not fname or fname == "" then
        fname = input.findbinfile(specification.name, 'ofm')
    else
        fname = input.findbinfile(fname, 'ofm')
    end
    if fname and fname ~= "" then
        if fonts.trace then
            logs.report("define font","loading tfm file %s at size %s",fname,specification.size)
        end
        tfmdata = font.read_tfm(fname,specification.size) -- not cached, fast enough
        if tfmdata then
            tfmdata.descriptions = tfmdata.descriptions or { }
            if tfm.resolve_vf then
                fonts.logger.save(tfmdata,file.extname(fname),specification) -- strange, why here
                fname = input.findbinfile(specification.name, 'ovf')
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
            end
            tfm.enhance(tfmdata,specification)
        end
    else
        if fonts.trace then
            logs.report("define font","loading tfm with name %s fails",specification.name)
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

    function tfm.setfactor(f)
        tfm.factor = factors[f or 'pt'] or factors.pt
    end

    tfm.setfactor()

end

function tfm.scaled(scaledpoints, designsize) -- handles designsize in sp as well
    if scaledpoints < 0 then
        if designsize then
            if designsize > tfm.factor then -- or just 1000 / when? mp?
                return (- scaledpoints/1000) * designsize -- sp's
            else
                return (- scaledpoints/1000) * designsize * tfm.factor
            end
        else
            return (- scaledpoints/1000) * 10 * tfm.factor
        end
    else
        return scaledpoints
    end
end

--[[ldx--
<p>Before a font is passed to <l n='tex'/> we scale it. Here we also need
to scale virtual characters.</p>
--ldx]]--

function tfm.get_virtual_id(tfmdata)
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

function tfm.check_virtual_id(tfmdata, id)
    if tfmdata and tfmdata.type == "virtual" then
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

fonts.trace_scaling = false

function tfm.do_scale(tfmtable, scaledpoints)
    local trace = fonts.trace_scaling
    if scaledpoints < 0 then
        scaledpoints = (- scaledpoints/1000) * tfmtable.designsize -- already in sp
    end
--~ print(">>>",tfmtable.units)
    local delta = scaledpoints/(tfmtable.units or 1000) -- brr, some open type fonts have 2048
    local t = { }
    t.factor = delta
    for k,v in pairs(tfmtable) do
        t[k] = (type(v) == "table" and { }) or v
    end
    -- new
    if tfmtable.fonts then
        t.fonts = table.fastcopy(tfmtable.fonts)
    end
    -- local zerobox = { 0, 0, 0, 0 }
    local tp = t.parameters
    local tfmp = tfmtable.parameters -- let's check for indexes
    tp.slant         = (tfmp.slant         or tfmp[1] or 0)
    tp.space         = (tfmp.space         or tfmp[2] or 0)*delta
    tp.space_stretch = (tfmp.space_stretch or tfmp[3] or 0)*delta
    tp.space_shrink  = (tfmp.space_shrink  or tfmp[4] or 0)*delta
    tp.x_height      = (tfmp.x_height      or tfmp[5] or 0)*delta
    tp.quad          = (tfmp.quad          or tfmp[6] or 0)*delta
    tp.extra_space   = (tfmp.extra_space   or tfmp[7] or 0)*delta
    local protrusionfactor = (tp.quad ~= 0 and 1000/tp.quad) or 0
    local tc = t.characters
    -- we can loop over (descriptions or characters), in which case
    -- we don't need to init characters in afm/otf (saves some mem)
    -- but then .. beware of protruding etc
    local descriptions = tfmtable.descriptions or { }
    t.descriptions = descriptions
    local nameneeded = not tfmtable.shared.otfdata --hack
-- loop over descriptions
    -- afm and otf have descriptions, tfm not
    for k,v in pairs(tfmtable.characters) do
        local description = descriptions[k] or v
        local chr
        -- there is no need (yet) to assign a value to chr.tonunicode
        if nameneeded then
            chr = {
                name      = description.name, -- is this used at all?
                index     = description.index or k,
                width     = delta*(description.width  or 0),
                height    = delta*(description.height or 0),
                depth     = delta*(description.depth  or 0),
            }
        else
            chr = {
                index     = description.index or k,
                width     = delta*(description.width  or 0),
                height    = delta*(description.height or 0),
                depth     = delta*(description.depth  or 0),
            }
        end
        if trace then
            logs.report("define font","t=%s, u=%s, i=%s, n=%s c=%s",k,chr.tounicode or k,description.index,description.name or '-',description.class or '-')
        end
        local ve = v.expansion_factor
        if ve then
            chr.expansion_factor = ve*1000 -- expansionfactor
        end
        local vl = v.left_protruding
        if vl then
            chr.left_protruding  = protrusionfactor*chr.width*vl
        end
        local vr = v.right_protruding
        if vr then
            chr.right_protruding  = protrusionfactor*chr.width*vr
        end
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
            local ok = false
            for i=1,#vc do
                local key = vc[i][1]
            --  if key == "right" or key == "left" or key == "down" or key == "up" then
                if key == "right" or key == "down" then
                    ok = true
                    break
                end
            end
            if ok then
                local tt = { }
                for i=1,#vc do
                    local ivc = vc[i]
                    local key = ivc[1]
                --  if key == "right" or key == "left" or key == "down" or key == "up" then
                    if key == "right" or key == "down" then
                        tt[#tt+1] = { key, ivc[2]*delta }
                    else -- not comment
                        tt[#tt+1] = ivc -- shared since in cache and untouched
                    end
                end
                chr.commands = tt
            else
                chr.commands = vc
            end
        end
        tc[k] = chr
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

tfm.auto_cleanup = true

local lastfont = nil

-- we can get rid of the tfm instance when we hav efast access to the
-- scaled character dimensions at the tex end, e.g. a fontobject.width

function tfm.cleanup_table(tfmdata) -- we need a cleanup callback, now we miss the last one
    if tfm.auto_cleanup then  -- ok, we can hook this into everyshipout or so ... todo
        if tfmdata.type == 'virtual' then
            for k, v in pairs(tfmdata.characters) do
                if v.commands then v.commands = nil end
            end
        end
    end
end

function tfm.cleanup(tfmdata) -- we need a cleanup callback, now we miss the last one
end

function tfm.scale(tfmtable, scaledpoints)
    local t, factor = tfm.do_scale(tfmtable, scaledpoints)
    t.factor    = factor
    t.ascender  = factor*(tfmtable.ascender  or 0)
    t.descender = factor*(tfmtable.descender or 0)
    t.shared    = tfmtable.shared or { }
    t.unique    = table.fastcopy(tfmtable.unique or {})
--~ print("scaling", t.name, t.factor) -- , tfm.hash_features(tfmtable.specification))
    tfm.cleanup(t)
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
            logs.report("define font","registering %s as %s",specification.name,source)
        end
        specification.source = source
        fonts.loaded[specification.specification] = specification
        fonts.used[specification.name] = source
    end
end

--~ function fonts.logger.report(separator)
--~     local s = table.sortedkeys(fonts.loaded)
--~     if #s > 0 then
--~         local t = { }
--~         for _,v in ipairs(s) do
--~             t[#t+1] = v .. ":" .. fonts.loaded[v].source
--~         end
--~         return table.concat(t,separator or " ")
--~     else
--~         return "none"
--~     end
--~ end

function fonts.logger.report(separator)
    local s = table.sortedkeys(fonts.used)
    if #s > 0 then
        local t = { }
        for _,v in ipairs(s) do
            t[#t+1] = v .. ":" .. fonts.used[v]
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
            local afmdata = tfmdata.shared.afmdata
            if afmdata then
                local encodingfile = value .. '.enc'
                local encoding = fonts.enc.load(encodingfile)
                if encoding then
                    local vector = encoding.vector
                    local characters = tfmdata.characters
                    local unicodes = afmdata.luatex.unicodes
                    local function remap(pattern,name)
                        local p = pattern:match(name)
                        if p then
                            local oldchr, newchr = unicodes[p], unicodes[name]
                            if oldchr and newchr and type(oldchr) == "number" and type(newchr) == "number" then
                             -- logs.report("encoding","%s (%s) -> %s (%s)",p,oldchr or -1,name,newchr or -1)
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
    end

    -- when needed we can provide this as features in e.g. afm files

    function fonts.initializers.common.remap(tfmdata,value,pattern) -- will go away
        if value then
            local afmdata = tfmdata.shared.afmdata
            if afmdata then
                local characters = tfmdata.characters
                local descriptions = tfmdata.descriptions
                local unicodes = afmdata.luatex.unicodes
                local done = false
                for u, _ in pairs(characters) do
                    local name = descriptions[u].name
                    if name then
                        local p = pattern:match(name)
                        if p then
                            local oldchr, newchr = unicodes[p], unicodes[name]
                            if oldchr and newchr and type(oldchr) == "number" and type(newchr) == "number" then
                                characters[oldchr] = characters[newchr]
                            end
                        end
                    end
                end
            end
        end
    end

    function fonts.initializers.common.oldstyle(tfmdata,value)
        fonts.initializers.common.remap(tfmdata,value,oldstyle)
    end
    function fonts.initializers.common.smallcaps(tfmdata,value)
        fonts.initializers.common.remap(tfmdata,value,smallcaps)
    end

    function fonts.initializers.common.fakecaps(tfmdata,value)
        if value then
            -- todo: scale down
            local afmdata = tfmdata.shared.afmdata
            if afmdata then
                local characters = tfmdata.characters
                local descriptions = tfmdata.descriptions
                local unicodes = afmdata.luatex.unicodes
                for u, _ in pairs(characters) do
                    local name = descriptions[u].name
                    if name then
                        local p = name:lower()
                        if p then
                            local oldchr, newchr = unicodes[p], unicodes[name]
                            if oldchr and newchr and type(oldchr) == "number" and type(newchr) == "number" then
                                characters[oldchr] = characters[newchr]
                            end
                        end
                    end
                end
            end
        end
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
    local fontdata        = tfm.id
    local set_attribute   = node.set_attribute
--  local unset_attribute = node.unset_attribute
--  local has_attribute   = node.has_attribute

    local state = attributes.numbers['state'] or 100

    -- todo: analyzers per script/lang, cross font, so we need an font id hash -> script
    -- e.g. latin -> hyphenate, arab -> 1/2/3 analyze

    -- an example analyzer

    function fonts.analyzers.aux.setstate(head,font)
        local tfmdata = fontdata[font]
        local characters = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local first, last, current, n, done = nil, nil, head, 0, false -- maybe make n boolean
        while current do
            if current.id == glyph and current.font == font then
                local d = descriptions[current.char]
                if d then
                    if d.class == "mark" then
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
    local fontdata      = tfm.id
    local marknumber    = attributes.numbers['mark'] or 200
    local set_attribute = node.set_attribute

    function fonts.pushmarks(head,font)
        local tfmdata = fontdata[font]
        local characters = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local current, last, done, n = head, nil, false, 0
        while current do
            if current.id == glyph and current.font == font then
                local d = descriptions[current.char]
                if d and d.class == "mark" then
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
        local current, done, characters, descriptions = head, false, tfmdata.characters, tfmdata.descriptions
        while current do
            if current.id == glyph and current.font == font and descriptions[current.char].class == "mark" then
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

function tfm.replacements(tfm,value)
 -- tfm.characters[0x0022] = table.fastcopy(tfm.characters[0x201D])
 -- tfm.characters[0x0027] = table.fastcopy(tfm.characters[0x2019])
 -- tfm.characters[0x0060] = table.fastcopy(tfm.characters[0x2018])
 -- tfm.characters[0x0022] = tfm.characters[0x201D]
    tfm.characters[0x0027] = tfm.characters[0x2019]
 -- tfm.characters[0x0060] = tfm.characters[0x2018]
end

-- auto complete font with missing composed characters

table.insert(fonts.manipulators,"compose")

function fonts.initializers.common.compose(tfmdata,value)
    if value then
        fonts.vf.aux.compose_characters(tfmdata)
    end
end

-- tfm features, experimental

tfm.features         = tfm.features         or { }
tfm.features.list    = tfm.features.list    or { }
tfm.features.default = tfm.features.default or { }

function tfm.enhance(tfmdata,specification)
    -- we don't really share tfm data because we always reload
    -- but this is more in sycn with afm and such
    local features = (specification.features and specification.features.normal ) or { }
    tfmdata.shared = tfmdata.shared or { }
    tfmdata.shared.features = features
    --  tfmdata.shared.tfmdata = tfmdata -- circular
tfmdata.filename = specification.name
    if not features.encoding then
        local name, size = specification.name, specification.size
        local encoding, filename = name:match("^(.-)%-(.*)$") -- context: encoding-name.*
        if filename and encoding and fonts.enc.known[encoding] then
            features.encoding = encoding
        end
    end
    tfm.set_features(tfmdata)
end

function tfm.set_features(tfmdata)
    local shared = tfmdata.shared
--  local tfmdata = shared.tfmdata
    local features = shared.features
    if not table.is_empty(features) then
        local mode = tfmdata.mode or fonts.mode
        local fi = fonts.initializers[mode]
        if fi and fi.tfm then
            local function initialize(list) -- using tex lig and kerning
                if list then
                    for _, f in ipairs(list) do
                        local value = features[f]
                        if value and fi.tfm[f] then -- brr
                            if tfm.trace_features then
                                logs.report("define tfm","initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown',tfmdata.name or 'unknown')
                            end
                            fi.tfm[f](tfmdata,value)
                            mode = tfmdata.mode or fonts.mode
                            fi = fonts.initializers[mode]
                        end
                    end
                end
            end
            initialize(fonts.triggers)
            initialize(tfm.features.list)
            initialize(fonts.manipulators)
        end
        local fm = fonts.methods[mode]
        if fm and fm.tfm then
            local function register(list) -- node manipulations
                if list then
                    for _, f in ipairs(list) do
                        if features[f] and fm.tfm[f] then -- brr
                            if not shared.processors then -- maybe also predefine
                                shared.processors = { fm.tfm[f] }
                            else
                                shared.processors[#shared.processors+1] = fm.tfm[f]
                            end
                        end
                    end
                end
            end
            register(tfm.features.list)
        end
    end
end

function tfm.features.register(name,default)
    tfm.features.list[#tfm.features.list+1] = name
    tfm.features.default[name] = default
end

function tfm.reencode(tfmdata,encoding)
    if encoding and fonts.enc.known[encoding] then
        local data = fonts.enc.load(encoding)
        if data then
            local characters, original, vector = tfmdata.characters, { }, data.vector
            tfmdata.encoding = encoding -- not needed
            for k, v in pairs(characters) do
                v.name, v.index, original[k] = vector[k], k, v
            end
            for k,v in pairs(data.unicodes) do
                if k ~= v then
                    if fonts.trace then
                        logs.report("define font","reencoding %04X to %04X",k,v)
                    end
                    characters[k] = original[v]
                end
            end
        end
    end
end

tfm.features.register('reencode')

fonts.initializers.base.tfm.reencode = tfm.reencode
fonts.initializers.node.tfm.reencode = tfm.reencode

fonts.enc            = fonts.enc            or { }
fonts.enc.remappings = fonts.enc.remappings or { }

function tfm.remap(tfmdata,remapping)
    local vector = remapping and fonts.enc.remappings[remapping]
    if vector then
        local characters, original = tfmdata.characters, { }
        for k, v in pairs(characters) do
            original[k], characters[k] = v, nil
        end
        for k,v in pairs(vector) do
            if k ~= v then
                if fonts.trace then
                    logs.report("define font","remapping %04X to %04X",k,v)
                end
                local c = original[k]
                characters[v] = c
                c.index = k
            end
        end
        tfmdata.encodingbytes = 2
        tfmdata.format = 'type1'
    end
end

tfm.features.register('remap')

fonts.initializers.base.tfm.remap = tfm.remap
fonts.initializers.node.tfm.remap = tfm.remap
