if not modules then modules = { } end modules ['node-fnt'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then os.exit() end -- generic function in node-dum

local next, type = next, type

local trace_characters = false  trackers.register("nodes.characters", function(v) trace_characters = v end)

local traverse_id, has_attribute = node.traverse_id, node.has_attribute
local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

local nodecodes = nodes.nodecodes

local glyph = nodecodes.glyph

fonts     = fonts      or { }
fonts.tfm = fonts.tfm  or { }
fonts.ids = fonts.ids  or { }

local fontdata = fonts.ids

-- some tests with using an array of dynamics[id] and processes[id] demonstrated
-- that there was nothing to gain (unless we also optimize other parts)
--
-- maybe getting rid of the intermediate shared can save some time

-- potential speedup: check for subtype < 256 so that we can remove that test
-- elsewhere, danger: injected nodes will not be dealt with but that does not
-- happen often; we could consider processing sublists but that might need mor
-- checking later on; the current approach also permits variants

function nodes.process_characters(head)
    -- either next or not, but definitely no already processed list
    starttiming(nodes)
    local usedfonts, attrfonts, done = { }, { }, false
    local a, u, prevfont, prevattr = 0, 0, nil, 0
    for n in traverse_id(glyph,head) do
        local font, attr = n.font, has_attribute(n,0) -- zero attribute is reserved for fonts in context
        if attr and attr > 0 then
            if font ~= prevfont or attr ~= prevattr then
                local used = attrfonts[font]
                if not used then
                    used = { }
                    attrfonts[font] = used
                end
                if not used[attr] then
                    -- we do some testing outside the function
                    local tfmdata = fontdata[font]
                    local shared = tfmdata.shared
                    if shared then
                        local dynamics = shared.dynamics
                        if dynamics then
                            local d = shared.set_dynamics(font,dynamics,attr) -- still valid?
                            if d then
                                used[attr] = d
                                a = a + 1
                            end
                        end
                    end
                end
                prevfont, prevattr = font, attr
            end
        elseif font ~= prevfont then
            prevfont, prevattr = font, 0
            local used = usedfonts[font]
            if not used then
                local tfmdata = fontdata[font]
                if tfmdata then
                    local shared = tfmdata.shared -- we need to check shared, only when same features
                    if shared then
                        local processors = shared.processes
                        if processors and #processors > 0 then
                            usedfonts[font] = processors
                            u = u + 1
                        end
                    end
                else
                    -- probably nullfont
                end
            end
        else
            prevattr = attr
        end
    end

    -- we could combine these and just make the attribute nil
    if u == 1 then
        local font, processors = next(usedfonts)
        local n = #processors
        if n > 0 then
            local h, d = processors[1](head,font,0)
            head, done = h or head, done or d
            if n > 1 then
                for i=2,n do
                    local h, d = processors[i](head,font,0)
                    head, done = h or head, done or d
                end
            end
        end
    elseif u > 0 then
        for font, processors in next, usedfonts do
            local n = #processors
            local h, d = processors[1](head,font,0)
            head, done = h or head, done or d
            if n > 1 then
                for i=2,n do
                    local h, d = processors[i](head,font,0)
                    head, done = h or head, done or d
                end
            end
        end
    end
    if a == 1 then
        local font, dynamics = next(attrfonts)
        for attribute, processors in next, dynamics do -- attr can switch in between
            local n = #processors
            local h, d = processors[1](head,font,attribute)
            head, done = h or head, done or d
            if n > 1 then
                for i=2,n do
                    local h, d = processors[i](head,font,attribute)
                    head, done = h or head, done or d
                end
            end
        end
    elseif a > 0 then
        for font, dynamics in next, attrfonts do
            for attribute, processors in next, dynamics do -- attr can switch in between
                local n = #processors
                local h, d = processors[1](head,font,attribute)
                head, done = h or head, done or d
                if n > 1 then
                    for i=2,n do
                        local h, d = processors[i](head,font,attribute)
                        head, done = h or head, done or d
                    end
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

nodes.protect_glyphs   = node.protect_glyphs
nodes.unprotect_glyphs = node.unprotect_glyphs
