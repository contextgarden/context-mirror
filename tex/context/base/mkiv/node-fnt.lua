if not modules then modules = { } end modules ['node-fnt'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

if not context then os.exit() end -- generic function in node-dum

local next, type = next, type
local concat, keys = table.concat, table.keys

local nodes, node, fonts = nodes, node, fonts

local trace_characters  = false  trackers.register("nodes.characters", function(v) trace_characters = v end)
local trace_fontrun     = false  trackers.register("nodes.fontrun",    function(v) trace_fontrun    = v end)
local trace_variants    = false  trackers.register("nodes.variants",   function(v) trace_variants   = v end)

-- bad namespace for directives

local force_discrun     = true   directives.register("nodes.discrun",      function(v) force_discrun     = v end)
local force_boundaryrun = true   directives.register("nodes.boundaryrun",  function(v) force_boundaryrun = v end)
local force_basepass    = true   directives.register("nodes.basepass",     function(v) force_basepass    = v end)
local keep_redundant    = false  directives.register("nodes.keepredundant",function(v) keep_redundant    = v end)

local report_fonts      = logs.reporter("fonts","processing")

local fonthashes        = fonts.hashes
local fontdata          = fonthashes.identifiers
local fontvariants      = fonthashes.variants
local fontmodes         = fonthashes.modes

local otf               = fonts.handlers.otf

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

local nodecodes         = nodes.nodecodes
local handlers          = nodes.handlers

local nuts              = nodes.nuts
local tonut             = nuts.tonut
local tonode            = nuts.tonode

local getattr           = nuts.getattr
local getid             = nuts.getid
local getfont           = nuts.getfont
local getsubtype        = nuts.getsubtype
local getchar           = nuts.getchar
local getdisc           = nuts.getdisc
local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getboth           = nuts.getboth
local getfield          = nuts.getfield
----- getdisc           = nuts.getdisc
local setchar           = nuts.setchar
local setlink           = nuts.setlink
local setfield          = nuts.setfield
local setprev           = nuts.setprev

local isglyph           = nuts.isglyph -- unchecked
local ischar            = nuts.ischar  -- checked

local traverse_id       = nuts.traverse_id
local traverse_char     = nuts.traverse_char
local protect_glyph     = nuts.protect_glyph
local flush_node        = nuts.flush

local disc_code         = nodecodes.disc
local boundary_code     = nodecodes.boundary
local word_boundary     = nodes.boundarycodes.word

local setmetatableindex = table.setmetatableindex

-- some tests with using an array of dynamics[id] and processes[id] demonstrated
-- that there was nothing to gain (unless we also optimize other parts)
--
-- maybe getting rid of the intermediate shared can save some time

local run = 0

local setfontdynamics = { }
local fontprocesses   = { }

-- setmetatableindex(setfontdynamics, function(t,font)
--     local tfmdata = fontdata[font]
--     local shared = tfmdata.shared
--     local v = shared and shared.dynamics and otf.setdynamics or false
--     t[font] = v
--     return v
-- end)

setmetatableindex(setfontdynamics, function(t,font)
    local tfmdata = fontdata[font]
    local shared = tfmdata.shared
    local f = shared and shared.dynamics and otf.setdynamics or false
    if f then
        local v = { }
        t[font] = v
        setmetatableindex(v,function(t,k)
            local v = f(font,k)
            t[k] = v
            return v
        end)
        return v
    else
        t[font] = false
        return false
    end
end)

setmetatableindex(fontprocesses, function(t,font)
    local tfmdata = fontdata[font]
    local shared = tfmdata.shared -- we need to check shared, only when same features
    local processes = shared and shared.processes
    if processes and #processes > 0 then
        t[font] = processes
        return processes
    else
        t[font] = false
        return false
    end
end)

fonts.hashes.setdynamics = setfontdynamics
fonts.hashes.processes   = fontprocesses

-- if we forget about basemode we don't need to test too much here and we can consider running
-- over sub-ranges .. this involves a bit more initializations but who cares .. in that case we
-- also need to use the stop criterium (we already use head too) ... we cannot use traverse
-- then, so i'll test it on some local clone first ... the only pitfall is changed directions
-- inside a run which means that we need to keep track of this which in turn complicates matters
-- in a way i don't like

-- we need to deal with the basemode fonts here and can only run over ranges as we
-- otherwise get luatex craches due to all kind of asserts in the disc/lig builder

local ligaturing = nuts.ligaturing
local kerning    = nuts.kerning

local expanders

function fonts.setdiscexpansion(v)
    if v == nil or v == true then
        expanders = languages and languages.expanders
    elseif type(v) == "table" then
        expanders = v
    else
        expanders = false
    end
end

function fonts.getdiscexpansion()
    return expanders and true or false
end

fonts.setdiscexpansion(true)

function handlers.characters(head)
    -- either next or not, but definitely no already processed list
    starttiming(nodes)

    local usedfonts  = { }
    local attrfonts  = { }
    local basefonts  = { }
    local a, u, b, r = 0, 0, 0, 0
    local basefont   = nil
    local prevfont   = nil
    local prevattr   = 0
    local mode       = nil
    local done       = false
    local variants   = nil
    local redundant  = nil

    if trace_fontrun then
        run = run + 1
        report_fonts()
        report_fonts("checking node list, run %s",run)
        report_fonts()
        local n = tonut(head)
        while n do
            local char, id = isglyph(n)
            if char then
                local font = getfont(n)
                local attr = getattr(n,0) or 0
                report_fonts("font %03i, dynamic %03i, glyph %C",font,attr,char)
            elseif id == disc_code then
                report_fonts("[disc] %s",nodes.listtoutf(n,true,false,n))
            elseif id == boundary_code then
                report_fonts("[boundary] %i:%i",getsubtype(n),getfield(n,"value"))
            else
                report_fonts("[%s]",nodecodes[id])
            end
            n = getnext(n)
        end
    end

    local nuthead = tonut(head)

    for n in traverse_char(nuthead) do
        local font = getfont(n)
        local attr = getattr(n,0) or 0 -- zero attribute is reserved for fonts in context
        if font ~= prevfont or attr ~= prevattr then
            prevfont = font
            prevattr = attr
            mode     = fontmodes[font] -- we can also avoid the attr check
            variants = fontvariants[font]
            if mode == "none" then
                -- skip
             -- variants = false
                protect_glyph(n)
            else
                if basefont then
                    basefont[2] = getprev(n)
                end
                if attr > 0 then
                    local used = attrfonts[font]
                    if not used then
                        used = { }
                        attrfonts[font] = used
                    end
                    if not used[attr] then
                        local fd = setfontdynamics[font]
                        if fd then
                            used[attr] = fd[attr]
                            a = a + 1
                        elseif force_basepass then
                            b = b + 1
                            basefont = { n, false }
                            basefonts[b] = basefont
                        end
                    end
                else
                    local used = usedfonts[font]
                    if not used then
                        local fp = fontprocesses[font]
                        if fp then
                            usedfonts[font] = fp
                            u = u + 1
                        elseif force_basepass then
                            b = b + 1
                            basefont = { n, false }
                            basefonts[b] = basefont
                        end
                    end
                end
            end
        end
        if variants then
            local char = getchar(n)
            if char >= 0xFE00 and (char <= 0xFE0F or (char >= 0xE0100 and char <= 0xE01EF)) then
                local hash = variants[char]
                if hash then
                    local p = getprev(n)
                    if p then
                        local char    = ischar(p) -- checked
                        local variant = hash[char]
                        if variant then
                            if trace_variants then
                                report_fonts("replacing %C by %C",char,variant)
                            end
                            setchar(p,variant)
                            if redundant then
                                r = r + 1
                                redundant[r] = n
                            else
                                r = 1
                                redundant = { n }
                            end
                        end
                    end
                elseif keep_redundant then
                    -- go on, can be used for tracing
                elseif redundant then
                    r = r + 1
                    redundant[r] = n
                else
                    r = 1
                    redundant = { n }
                end
            end
        end
    end

    if force_boundaryrun then

        -- we can inject wordboundaries and then let the hyphenator do its work
        -- but we need to get rid of those nodes in order to build ligatures
        -- and kern (a rather context thing)

        for b in traverse_id(boundary_code,nuthead) do
            if getsubtype(b) == word_boundary then
                if redundant then
                    r = r + 1
                    redundant[r] = b
                else
                    r = 1
                    redundant = { b }
                end
            end
        end

    end

    if redundant then
        for i=1,r do
            local r = redundant[i]
            local p, n = getboth(r)
            if r == nuthead then
                nuthead = n
                setprev(n)
            else
                setlink(p,n)
            end
            if b > 0 then
                for i=1,b do
                    local bi = basefonts[i]
                    if r == bi[1] then
                        bi[1] = n
                    end
                    if r == bi[2] then
                        bi[2] = n
                    end
                end
            end
            flush_node(r)
        end
    end

    local e = 0

    if force_discrun then

        -- basefont is not supported in disc only runs ... it would mean a lot of
        -- ranges .. we could try to run basemode as a separate processor run but
        -- not for now (we can consider it when the new node code is tested

     -- local prevfont  = nil
     -- local prevattr  = 0

        for d in traverse_id(disc_code,nuthead) do
            -- we could use first_glyph, only doing replace is good enough
            local _, _, r = getdisc(d)
            if r then
                for n in traverse_char(r) do
                    local font = getfont(n)
                    local attr = getattr(n,0) or 0 -- zero attribute is reserved for fonts in context
                    if font ~= prevfont or attr ~= prevattr then
                        if attr > 0 then
                            local used = attrfonts[font]
                            if not used then
                                used = { }
                                attrfonts[font] = used
                            end
                            if not used[attr] then
                                local fd = setfontdynamics[font]
                                if fd then
                                    used[attr] = fd[attr]
                                    a = a + 1
                                end
                            end
                        else
                            local used = usedfonts[font]
                            if not used then
                                local fp = fontprocesses[font]
                                if fp then
                                    usedfonts[font] = fp
                                    u = u + 1
                                end
                            end
                        end
                        prevfont = font
                        prevattr = attr
                    end
                end
                break
            elseif expanders then
                local subtype = getsubtype(d)
                if subtype == discretionary_code then
                    -- already done when replace
                else
                    expanders[subtype](d)
                    e = e + 1
                end
            end
        end

    end

    if trace_fontrun then
        report_fonts()
        report_fonts("statics : %s",u > 0 and concat(keys(usedfonts)," ") or "none")
        report_fonts("dynamics: %s",a > 0 and concat(keys(attrfonts)," ") or "none")
        report_fonts("built-in: %s",b > 0 and b or "none")
        report_fonts("removed : %s",redundant and #redundant > 0 and #redundant or "none")
    if expanders then
        report_fonts("expanded: %s",e > 0 and e or "none")
    end
        report_fonts()
    end
    -- in context we always have at least 2 processors
    if u == 0 then
        -- skip
    elseif u == 1 then
        local font, processors = next(usedfonts)
        local attr = a == 0 and false or 0 -- 0 is the savest way
        for i=1,#processors do
            local h, d = processors[i](head,font,attr)
            if d then
                head = h or head
                done = true
            end
        end
    else
        local attr = a == 0 and false or 0 -- 0 is the savest way
        for font, processors in next, usedfonts do
            for i=1,#processors do
                local h, d = processors[i](head,font,attr)
                if d then
                    head = h or head
                    done = true
                end
            end
        end
    end
    if a == 0 then
        -- skip
    elseif a == 1 then
        local font, dynamics = next(attrfonts)
        for attribute, processors in next, dynamics do -- attr can switch in between
            for i=1,#processors do
                local h, d = processors[i](head,font,attribute)
                if d then
                    head = h or head
                    done = true
                end
            end
        end
    else
        for font, dynamics in next, attrfonts do
            for attribute, processors in next, dynamics do -- attr can switch in between
                for i=1,#processors do
                    local h, d = processors[i](head,font,attribute)
                    if d then
                        head = h or head
                        done = true
                    end
                end
            end
        end
    end
    if b == 0 then
        -- skip
    elseif b == 1 then
        -- only one font
        local range = basefonts[1]
        local start = range[1]
        local stop  = range[2]
        if (start or stop) and (start ~= stop) then
            local front = nuthead == start
            if stop then
                start, stop = ligaturing(start,stop)
                start, stop = kerning(start,stop)
            elseif start then -- safeguard
                start = ligaturing(start)
                start = kerning(start)
            end
            if front then
                head = tonode(start)
            end
        end
    else
        -- multiple fonts
        for i=1,b do
            local range = basefonts[i]
            local start = range[1]
            local stop  = range[2]
            if start then
                local front = nuthead == start
                local prev, next
                if stop then
                    next = getnext(stop)
                    start, stop = ligaturing(start,stop)
                    start, stop = kerning(start,stop)
                else
                    prev  = getprev(start)
                    start = ligaturing(start)
                    start = kerning(start)
                end
                if prev then
                    setlink(prev,start)
                end
                if next then
                    setlink(stop,next)
                end
                if front and nuthead ~= start then
                    head = tonode(nuthead)
                end
            end
        end
    end
    stoptiming(nodes)
    if trace_characters then
        nodes.report(head,done)
    end
    return head, true
end

local d_protect_glyphs   = nuts.protect_glyphs
local d_unprotect_glyphs = nuts.unprotect_glyphs

handlers.protectglyphs   = function(n) return d_protect_glyphs  (tonut(n)) end
handlers.unprotectglyphs = function(n) return d_unprotect_glyphs(tonut(n)) end

-- function handlers.protectglyphs(h)
--     local h = tonut(h)
--     for n in traverse_id(disc_code,h) do
--         local pre, post, replace = getdisc(n)
--         if pre     then d_protect_glyphs(pre)     end
--         if post    then d_protect_glyphs(post)    end
--         if replace then d_protect_glyphs(replace) end
--     end
--     return d_protect_glyphs(h)
-- end
