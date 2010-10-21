if not modules then modules = { } end modules ['font-fbk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local cos, tan, rad, format = math.cos, math.tan, math.rad, string.format
local utfbyte, utfchar = utf.byte, utf.char

local trace_combining     = false  trackers.register("fonts.combining",     function(v) trace_combining     = v end)
local trace_combining_all = false  trackers.register("fonts.combining.all", function(v) trace_combining_all = v end)

trackers.register("fonts.composing", "fonts.combining")

local report_combining = logs.new("combining")

local allocate = utilities.storage.allocate

--[[ldx--
<p>This is very experimental code!</p>
--ldx]]--

local fonts = fonts
local vf    = fonts.vf
local tfm   = fonts.tfm

fonts.fallbacks = allocate()
local fallbacks = fonts.fallbacks
local commands  = vf.aux.combine.commands

local push, pop = { "push" }, { "pop" }

commands["enable-tracing"] = function(g,v)
    trace_combining = true
end

commands["disable-tracing"] = function(g,v)
    trace_combining = false
end

commands["set-tracing"] = function(g,v)
    if v[2] == nil then
        trace_combining = true
    else
        trace_combining = v[2]
    end
end

-- maybe store llx etc instead of bbox in tfm blob / more efficient

local force_composed = false

local cache    = { }  -- we could make these weak
local fraction = 0.15 -- 30 units for lucida

function vf.aux.compose_characters(g) -- todo: scaling depends on call location
    -- this assumes that slot 1 is self, there will be a proper self some day
    local chars, descs = g.characters, g.descriptions
    local Xdesc, xdesc = descs[utfbyte("X")], descs[utfbyte("x")]
    if Xdesc and xdesc then
        local scale = g.factor or 1
        local deltaxheight = scale * (Xdesc.boundingbox[4] - xdesc.boundingbox[4])
        local extraxheight = fraction * deltaxheight -- maybe use compose value
     -- local cap_ury = scale*xdesc.boundingbox[4]
        local ita_cor = cos(rad(90+(g.italicangle or 0)))
        local fallbacks = characters.fallbacks
        local vfspecials = backends.tables.vfspecials
        local red, green, blue, black
        if trace_combining then
            red, green, blue, black = vfspecials.red, vfspecials.green, vfspecials.blue, vfspecials.black
        end
        local compose = fonts.goodies.getcompositions(g)
        if compose and trace_combining then
            report_combining("using compose information from goodies file")
        end
        local done = false
        for i,c in next, characters.data do -- loop over all characters ... not that efficient but a specials hash takes memory
            if force_composed or not chars[i] then
                local s = c.specials
                if s and s[1] == 'char' then
                    local chr = s[2]
                    local charschr = chars[chr]
                    if charschr then
                        local cc = c.category
                        if cc == 'll' or cc == 'lu' or cc == 'lt' then -- characters.is_letter[cc]
                            local acc = s[3]
                            local t = { }
                            for k, v in next, charschr do
                                if k ~= "commands" then
                                    t[k] = v
                                end
                            end
                            local charsacc = chars[acc]
                        --~ local ca = charsacc.category
                        --~ if ca == "mn" then
                        --~     -- mark nonspacing
                        --~ elseif ca == "ms" then
                        --~     -- mark spacing combining
                        --~ elseif ca == "me" then
                        --~     -- mark enclosing
                        --~ else
                            if not charsacc then -- fallback accents
                                acc = fallbacks[acc]
                                charsacc = acc and chars[acc]
                            end
                            if charsacc then
                                if trace_combining_all then
                                    report_combining("%s (0x%05X) = %s (0x%05X) + %s (0x%05X)",utfchar(i),i,utfchar(chr),chr,utfchar(acc),acc)
                                end
                                local chr_t = cache[chr]
                                if not chr_t then
                                    chr_t = {"slot", 1, chr}
                                    cache[chr] = chr_t
                                end
                                local acc_t = cache[acc]
                                if not acc_t then
                                    acc_t = {"slot", 1, acc}
                                    cache[acc] = acc_t
                                end
                                local cb = descs[chr].boundingbox
                                local ab = descs[acc].boundingbox
                                -- todo: adapt height
                                if cb and ab then
                                    -- can be sped up for scale == 1
                                    local c_llx, c_lly, c_urx, c_ury = scale*cb[1], scale*cb[2], scale*cb[3], scale*cb[4]
                                    local a_llx, a_lly, a_urx, a_ury = scale*ab[1], scale*ab[2], scale*ab[3], scale*ab[4]
                                    local dx = (c_urx - a_urx - a_llx + c_llx)/2
                                    local dd = (c_urx - c_llx)*ita_cor
                                    if a_ury < 0  then
                                        if trace_combining then
                                            t.commands = { push, {"right", dx-dd}, red, acc_t, black, pop, chr_t }
                                        else
                                            t.commands = { push, {"right", dx-dd},      acc_t,        pop, chr_t }
                                        end
                                    elseif c_ury > a_lly then -- messy test
                                        -- local dy = cap_ury - a_lly
                                        local dy
                                        if compose then
                                            -- experimental: we could use sx but all that testing
                                            -- takes time and code
                                            dy = compose[i]
                                            if dy then
                                                dy = dy.DY
                                            end
                                            if not dy then
                                                dy = compose[acc]
                                                if dy then
                                                    dy = dy and dy.DY
                                                end
                                            end
                                            if not dy then
                                                dy = compose.DY
                                            end
                                            if not dy then
                                                dy = - deltaxheight + extraxheight
                                            elseif dy > -1.5 and dy < 1.5 then
                                                -- we assume a fraction of (percentage)
                                                dy = - dy * deltaxheight
                                            else
                                                -- we assume fontunits (value smaller than 2 make no sense)
                                                dy = - dy * scale
                                            end
                                        else
                                            dy = - deltaxheight + extraxheight
                                        end
                                        if trace_combining then
                                            t.commands = { push, {"right", dx+dd}, {"down", dy}, green, acc_t, black, pop, chr_t }
                                        else
                                            t.commands = { push, {"right", dx+dd}, {"down", dy},        acc_t,        pop, chr_t }
                                        end
                                    else
                                        if trace_combining then
                                            t.commands = { push, {"right", dx+dd},               blue,  acc_t, black, pop, chr_t }
                                        else
                                            t.commands = { push, {"right", dx+dd},                      acc_t,        pop, chr_t }
                                        end
                                    end
                                    done = true
                                end
                            elseif trace_combining_all then
                                report_combining("%s (0x%05X) = %s (0x%05X)",utfchar(i),i,utfchar(chr),chr)
                            end
                            chars[i] = t
                            local d = { }
                            for k, v in next, descs[chr] do
                                d[k] = v
                            end
                        --  d.name = c.adobename or "unknown" -- TOO TRICKY ! CAN CLASH WITH THE SUBSETTER
                        --  d.unicode = i
                            descs[i] = d
                        end
                    end
                end
            end
        end
        if done then
            g.virtualized = true
        end
    end
end

commands["complete-composed-characters"] = function(g,v)
    vf.aux.compose_characters(g)
end

-- {'special', 'pdf: q ' .. s .. ' 0 0 '.. s .. ' 0 0 cm'},
-- {'special', 'pdf: q 1 0 0 1 ' .. -w .. ' ' .. -h .. ' cm'},
-- {'special', 'pdf: /Fm\XX\space Do'},
-- {'special', 'pdf: Q'},
-- {'special', 'pdf: Q'},

local force_fallback = false

commands["fake-character"] = function(g,v) -- g, nr, fallback_id
    local index, fallback = v[2], v[3]
    if (force_fallback or not g.characters[index]) and fallbacks[fallback] then
        g.characters[index], g.descriptions[index] = fallbacks[fallback](g)
    end
end

commands["enable-force"] = function(g,v)
    force_composed = true
    force_fallback = true
end

commands["disable-force"] = function(g,v)
    force_composed = false
    force_fallback = false
end

local install = fonts.definers.methods.install

-- these are just examples used in the manuals, so they will end up in
-- modules eventually

fallbacks['textcent'] = function (g)
    local c = utfbyte("c")
    local t = table.fastcopy(g.characters[c],true)
    local a = - tan(rad(g.italicangle or 0))
    local vfspecials = backends.tables.vfspecials
    local green, black
    if trace_combining then
        green, black = vfspecials.green, vfspecials.black
    end
    local startslant, stopslant = vfspecials.startslant, vfspecials.stopslant
    local quad = g.parameters.quad
    if a == 0 then
        if trace_combining then
            t.commands = {
                push, {"slot", 1, c}, pop,
                {"right", .5*t.width},
                {"down",  .2*t.height},
                green,
                {"rule", 1.4*t.height, .02*quad},
                black,
            }
        else
            t.commands = {
                push, {"slot", 1, c}, pop,
                {"right", .5*t.width},
                {"down",  .2*t.height},
                {"rule", 1.4*t.height, .02*quad},
            }
        end
    else
        if trace_combining then
            t.commands = {
                push,
                {"right", .5*t.width-.025*quad},
                {"down",  .2*t.height},
                startslant(a),
                green,
                {"rule", 1.4*t.height, .025*quad},
                black,
                stopslant,
                pop,
                {"slot", 1, c} -- last else problems with cm
            }
        else
            t.commands = {
                push,
                {"right", .5*t.width-.025*quad},
                {"down",  .2*t.height},
                startslant(a),
                {"rule", 1.4*t.height, .025*quad},
                stopslant,
                pop,
                {"slot", 1, c} -- last else problems with cm
            }
        end
    end
    -- somehow the width is messed up now
    -- todo: set height
    t.height = 1.2*t.height
    t.depth  = 0.2*t.height
    g.virtualized = true
    local d = g.descriptions
    return t, d and d[c]
end

fallbacks['texteuro'] = function (g)
    local c = utfbyte("C")
    local t = table.fastcopy(g.characters[c],true)
    local d = cos(rad(90+(g.italicangle)))
    local vfspecials = backends.tables.vfspecials
    local green, black
    if trace_combining then
        green, black = vfspecials.green, vfspecials.black
    end
    local quad = g.parameters.quad
    t.width = 1.05*t.width
    if trace_combining then
        t.commands = {
            {"right", .05*t.width},
            push, {"slot", 1, c}, pop,
            {"right", .5*t.width*d},
            {"down", -.5*t.height},
            green,
            {"rule", .05*quad, .4*quad},
            black,
        }
    else
        t.commands = {
            {"right", .05*t.width},
            push, {"slot", 1, c}, pop,
            {"right", .5*t.width*d},
            {"down", -.5*t.height},
            {"rule", .05*quad, .4*quad},
        }
    end
    g.virtualized = true
    return t, g.descriptions[c]
end


install("fallback", { -- todo: auto-fallback with loop over data.characters
    { "fake-character", 0x00A2, 'textcent' },
    { "fake-character", 0x20AC, 'texteuro' }
})

install("demo-2", {
    { "enable-tracing" },
    { "enable-force" },
    { "initialize" },
    { "include-method", "fallback" },
    { "complete-composed-characters" },
    { "disable-tracing" },
    { "disable-force" },
})

install("demo-3", {
    { "enable-tracing" },
    { "initialize" },
    { "complete-composed-characters" },
    { "disable-tracing" },
})

-- end of examples
