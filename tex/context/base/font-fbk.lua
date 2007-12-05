if not modules then modules = { } end modules ['font-fbk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is very experimental code!</p>
--ldx]]--

fonts.fallbacks            = { }
fonts.vf.aux.combine.trace = false

fonts.vf.aux.combine.commands["enable-tracing"] = function(g,v)
    fonts.vf.aux.combine.trace = true
end

fonts.vf.aux.combine.commands["disable-tracing"] = function(g,v)
    fonts.vf.aux.combine.trace = false
end

fonts.vf.aux.combine.commands["set-tracing"] = function(g,v)
    if v[2] == nil then
        fonts.vf.aux.combine.trace = true
    else
        fonts.vf.aux.combine.trace = v[2]
    end
end

function fonts.vf.aux.combine.initialize_trace()
    if fonts.vf.aux.combine.trace then
        return "special", "pdf: .8 0 0 rg .8 0 0 RG", "pdf: 0 .8 0 rg 0 .8 0 RG", "pdf: 0 0 .8 rg 0 0 .8 RG", "pdf: 0 g 0 G"
    else
        return "comment", "", "", "", ""
    end
end

fonts.vf.aux.combine.force_fallback = false

fonts.vf.aux.combine.commands["fake-character"] = function(g,v) -- g, nr, fallback_id
    local index, fallback = v[2], v[3]
    if fonts.vf.aux.combine.force_fallback or not g.characters[index] then
        if fonts.fallbacks[fallback] then
            g.characters[index] = fonts.fallbacks[fallback](g)
        end
    end
end

fonts.fallbacks['textcent'] = function (g)
    local c = string.byte("c")
    local t = table.fastcopy(g.characters[c])
--~     local s = fonts.tfm.scaled(g.specification.size or g.size or g.private.size)
--~     local s = fonts.tfm.scaled(g.size or g.private.size)
    local s = fonts.tfm.scaled(g.specification.size or g.size)
    local a = - math.tan(math.rad(g.italicangle))
    local special, red, green, blue, black = fonts.vf.aux.combine.initialize_trace()
    if a == 0 then
        t.commands = {
            {"push"}, {"slot", 1, c}, {"pop"},
            {"right", .5*t.width},
            {"down",  .2*t.height},
            {special, green},
            {"rule", 1.4*t.height, .02*s},
            {special, black},
        }
    else
        t.commands = {
            {"push"},
            {"right", .5*t.width-.025*s},
            {"down",  .2*t.height},
            {"special",string.format("pdf: q 1 0 %s 1 0 0 cm",a)},
            {special, green},
            {"rule", 1.4*t.height, .025*s},
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
    return t
end

fonts.fallbacks['texteuro'] = function (g)
    local c = string.byte("C")
    local t = table.fastcopy(g.characters[c])
--~     local s = fonts.tfm.scaled(g.specification.size or g.size or g.private.size)
--~     local s = fonts.tfm.scaled(g.size or g.private.size)
    local s = fonts.tfm.scaled(g.specification.size or g.size)
    local d = math.cos(math.rad(90+g.italicangle))
    local special, red, green, blue, black = fonts.vf.aux.combine.initialize_trace()
    t.width = 1.05*t.width
    t.commands = {
        {"right", .05*t.width},
        {"push"}, {"slot", 1, c}, {"pop"},
        {"right", .5*t.width*d},
        {"down", -.5*t.height},
        {special, green},
        {"rule", .05*s, .4*s},
        {special, black},
    }
    return t
end

-- maybe store llx etc instead of bbox in tfm blob / more efficient

fonts.vf.aux.combine.force_composed = false

 fonts.vf.aux.combine.commands["complete-composed-characters"] = function(g,v)
    local chars = g.characters
    local cap_lly = chars[string.byte("X")].boundingbox[4]
    local ita_cor = math.cos(math.rad(90+g.italicangle))
    local force = fonts.vf.aux.combine.force_composed
    local special, red, green, blue, black = fonts.vf.aux.combine.initialize_trace()
    for i,c in pairs(characters.data) do
        if force or not chars[i] then
            local s = c.specials
            if s and s[1] == 'char' then
                local chr = s[2]
                if chars[chr] then
                    local cc = c.category
                    if (cc == 'll') or (cc == 'lu') or (cc == 'lt') then
                        local acc = s[3]
                        local t = table.fastcopy(chars[chr])
t.name = ""
t.index = i
t.unicode = i
                        if chars[acc] then
                            local cb = chars[chr].boundingbox
                            local ab = chars[acc].boundingbox
                            local c_llx, c_lly, c_urx, c_ury = cb[1], cb[2], cb[3], cb[4]
                            local a_llx, a_lly, a_urx, a_ury = ab[1], ab[2], ab[3], ab[4]
                         -- local dx = (c_urx-a_urx) - (c_urx-c_llx-a_urx+a_llx)/2
                         -- local dx = (c_urx-a_urx) - (c_urx-a_urx-c_llx+a_llx)/2
                            local dx = (c_urx - a_urx - a_llx + c_llx)/2
                         -- local dd = chars[chr].width*ita_cor
                            local dd = (c_urx-c_llx)*ita_cor
                            if a_ury < 0  then
                                local dy = cap_lly-a_lly
                                t.commands = {
                                    {"push"},
                                    {"right", dx-dd},
                                    {"down", -dy}, -- added
                                    {special, red},
                                    {"slot", 1, acc},
                                    {special, black},
                                    {"pop"},
                                    {"slot", 1, chr},
                                }
                            elseif c_ury > a_lly then
                                local dy = cap_lly-a_lly
                                t.commands = {
                                    {"push"},
                                    {"right", dx+dd},
                                    {"down", -dy},
                                    {special, green},
                                    {"slot", 1, acc},
                                    {special, black},
                                    {"pop"},
                                    {"slot", 1, chr},
                                }
                            else
                                t.commands = {
                                    {"push"},
                                    {"right", dx+dd},
                                    {special, blue},
                                    {"slot", 1, acc},
                                    {special, black},
                                    {"pop"},
                                    {"slot", 1, chr},
                                }
                            end
                            chars[i] = t
                        end
                    end
                end
            end
        end
    end
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

fonts.vf.aux.combine.commands["enable-force"] = function(g,v)
    fonts.vf.aux.combine.force_composed = true
    fonts.vf.aux.combine.force_fallback = true
end
fonts.vf.aux.combine.commands["disable-force"] = function(g,v)
    fonts.vf.aux.combine.force_composed = false
    fonts.vf.aux.combine.force_fallback = false
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
