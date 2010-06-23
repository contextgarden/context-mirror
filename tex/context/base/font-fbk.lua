if not modules then modules = { } end modules ['font-fbk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local cos, tan, rad, format = math.cos, math.tan, math.rad, string.format

local trace_combining = false  trackers.register("fonts.combining", function(v) trace_combining = v end)

--[[ldx--
<p>This is very experimental code!</p>
--ldx]]--

fonts.fallbacks = fonts.fallbacks or { }

local vf  = fonts.vf
local tfm = fonts.tfm

vf.aux.combine.commands["enable-tracing"] = function(g,v)
    trace_combining = true
end

vf.aux.combine.commands["disable-tracing"] = function(g,v)
    trace_combining = false
end

vf.aux.combine.commands["set-tracing"] = function(g,v)
    if v[2] == nil then
        trace_combining = true
    else
        trace_combining = v[2]
    end
end

function vf.aux.combine.initialize_trace()
    if trace_combining then
        return "special", "pdf: .8 0 0 rg .8 0 0 RG", "pdf: 0 .8 0 rg 0 .8 0 RG", "pdf: 0 0 .8 rg 0 0 .8 RG", "pdf: 0 g 0 G"
    else
        return "comment", "", "", "", ""
    end
end

vf.aux.combine.force_fallback = false

vf.aux.combine.commands["fake-character"] = function(g,v) -- g, nr, fallback_id
    local index, fallback = v[2], v[3]
    if vf.aux.combine.force_fallback or not g.characters[index] then
        if fonts.fallbacks[fallback] then
            g.characters[index], g.descriptions[index] = fonts.fallbacks[fallback](g)
        end
    end
end

fonts.fallbacks['textcent'] = function (g)
    local c = ("c"):byte()
    local t = table.fastcopy(g.characters[c])
    local a = - tan(rad(g.italicangle or 0))
    local special, red, green, blue, black = vf.aux.combine.initialize_trace()
    local quad = g.parameters.quad
    if a == 0 then
        t.commands = {
            {"push"}, {"slot", 1, c}, {"pop"},
            {"right", .5*t.width},
            {"down",  .2*t.height},
            {special, green},
            {"rule", 1.4*t.height, .02*quad},
            {special, black},
        }
    else
        t.commands = {
            {"push"},
            {"right", .5*t.width-.025*quad},
            {"down",  .2*t.height},
            {"special",format("pdf: q 1 0 %s 1 0 0 cm",a)},
            {special, green},
            {"rule", 1.4*t.height, .025*quad},
            {special, black},
            {"special","pdf: Q"},
            {"pop"},
            {"slot", 1, c} -- last else problems with cm
        }
    end
    -- somehow the width is messed up now
    -- todo: set height
    t.height = 1.2*t.height
    t.depth  = 0.2*t.height
    g.virtualized = true
    local d = g.descriptions
    return t, d and d[c]
end

fonts.fallbacks['texteuro'] = function (g)
    local c = ("C"):byte()
    local t = table.fastcopy(g.characters[c])
    local d = cos(rad(90+(g.italicangle)))
    local special, red, green, blue, black = vf.aux.combine.initialize_trace()
    local quad = g.parameters.quad
    t.width = 1.05*t.width
    t.commands = {
        {"right", .05*t.width},
        {"push"}, {"slot", 1, c}, {"pop"},
        {"right", .5*t.width*d},
        {"down", -.5*t.height},
        {special, green},
        {"rule", .05*quad, .4*quad},
        {special, black},
    }
    g.virtualized = true
    return t, g.descriptions[c]
end

-- maybe store llx etc instead of bbox in tfm blob / more efficient

vf.aux.combine.force_composed = false

local push, pop = { "push" }, { "pop" }

local cache = { } -- we could make these weak

function vf.aux.compose_characters(g) -- todo: scaling depends on call location
    -- this assumes that slot 1 is self, there will be a proper self some day
    local chars, descs = g.characters, g.descriptions
    local X = ("X"):byte()
    local xchar = chars[X]
    local xdesc = descs[X]
    if xchar and xdesc then
        local scale = g.factor or 1
        local cap_lly = scale*xdesc.boundingbox[4]
        local ita_cor = cos(rad(90+(g.italicangle or 0)))
        local force = vf.aux.combine.force_composed
        local fallbacks = characters.fallbacks
        local special, red, green, blue, black
        if trace_combining then
            special, red, green, blue, black = vf.aux.combine.initialize_trace()
            red, green, blue, black = { special, red }, { special, green }, { special, blue }, { special, black }
        end
        local done = false
        for i,c in next, characters.data do
            if force or not chars[i] then
                local s = c.specials
                if s and s[1] == 'char' then
                    local chr = s[2]
                    local charschr = chars[chr]
                    if charschr then
                        local cc = c.category
                        if cc == 'll' or cc == 'lu' or cc == 'lt' then
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
                            if not charsacc then
                                acc = fallbacks[acc]
                                charsacc = acc and chars[acc]
                            end
                            if charsacc then
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
                                if cb and ab then
                                    -- can be sped up for scale == 1
                                    local c_llx, c_lly, c_urx, c_ury = scale*cb[1], scale*cb[2], scale*cb[3], scale*cb[4]
                                    local a_llx, a_lly, a_urx, a_ury = scale*ab[1], scale*ab[2], scale*ab[3], scale*ab[4]
                                    local dx = (c_urx - a_urx - a_llx + c_llx)/2
                                    local dd = (c_urx - c_llx)*ita_cor
                                    if a_ury < 0  then
                                        if trace_combining then
                                            t.commands = {
                                                push,
                                                {"right", dx-dd},
                                                red,
                                                acc_t,
                                                black,
                                                pop,
                                                chr_t,
                                            }
                                        else
                                            t.commands = {
                                                push,
                                                {"right", dx-dd},
                                                acc_t,
                                                pop,
                                                chr_t,
                                            }
                                        end
                                    elseif c_ury > a_lly then
                                        local dy = cap_lly-a_lly
                                        if trace_combining then
                                            t.commands = {
                                                push,
                                                {"right", dx+dd},
                                                {"down", -dy},
                                                green,
                                                acc_t,
                                                black,
                                                pop,
                                                chr_t,
                                            }
                                        else
                                            t.commands = {
                                                push,
                                                {"right", dx+dd},
                                                {"down", -dy},
                                                acc_t,
                                                pop,
                                                chr_t,
                                            }
                                        end
                                    else
                                        if trace_combining then
                                            t.commands = {
                                                {"push"},
                                                {"right", dx+dd},
                                                blue,
                                                acc_t,
                                                black,
                                                {"pop"},
                                                chr_t,
                                            }
                                        else
                                            t.commands = {
                                                {"push"},
                                                {"right", dx+dd},
                                                acc_t,
                                                {"pop"},
                                                chr_t,
                                            }
                                        end
                                    end
                                    done = true
                                end
                            end
                            chars[i] = t
                            local d = { }
                            for k, v in next, descs[chr] do
                                d[k] = v
                            end
                            d.name = c.adobename or "unknown"
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

vf.aux.combine.commands["complete-composed-characters"] = function(g,v)
    vf.aux.compose_characters(g)
end

--~         {'special', 'pdf: q ' .. s .. ' 0 0 '.. s .. ' 0 0 cm'},
--~         {'special', 'pdf: q 1 0 0 1 ' .. -w .. ' ' .. -h .. ' cm'},
--~     --  {'special', 'pdf: /Fm\XX\space Do'},
--~         {'special', 'pdf: Q'},
--~         {'special', 'pdf: Q'},

-- for documentation purposes we provide:

fonts.define.methods.install("fallback", { -- todo: auto-fallback with loop over data.characters
    { "fake-character", 0x00A2, 'textcent' },
    { "fake-character", 0x20AC, 'texteuro' }
})

vf.aux.combine.commands["enable-force"] = function(g,v)
    vf.aux.combine.force_composed = true
    vf.aux.combine.force_fallback = true
end
vf.aux.combine.commands["disable-force"] = function(g,v)
    vf.aux.combine.force_composed = false
    vf.aux.combine.force_fallback = false
end

fonts.define.methods.install("demo-2", {
    { "enable-tracing" },
    { "enable-force" },
    { "initialize" },
    { "include-method", "fallback" },
    { "complete-composed-characters" },
    { "disable-tracing" },
    { "disable-force" },
})

fonts.define.methods.install("demo-3", {
    { "enable-tracing" },
    { "initialize" },
    { "complete-composed-characters" },
    { "disable-tracing" },
})
