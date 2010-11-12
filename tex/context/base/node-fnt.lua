if not modules then modules = { } end modules ['node-fnt'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then os.exit() end -- generic function in node-dum

local next, type = next, type
local concat = table.concat

local trace_characters = false  trackers.register("nodes.characters", function(v) trace_characters = v end)
local trace_fontrun    = false  trackers.register("nodes.fontrun",    function(v) trace_fontrun    = v end)

local report_fontrun = logs.new("font run")

local nodes, node = nodes, node

fonts               = fonts or { }
fonts.tfm           = fonts.tfm or { }
fonts.identifiers   = fonts.identifiers or { }

local traverse_id   = node.traverse_id
local has_attribute = node.has_attribute
local starttiming   = statistics.starttiming
local stoptiming    = statistics.stoptiming
local nodecodes     = nodes.nodecodes
local fontdata      = fonts.identifiers
local handlers      = nodes.handlers

local glyph_code    = nodecodes.glyph

-- some tests with using an array of dynamics[id] and processes[id] demonstrated
-- that there was nothing to gain (unless we also optimize other parts)
--
-- maybe getting rid of the intermediate shared can save some time

-- potential speedup: check for subtype < 256 so that we can remove that test
-- elsewhere, danger: injected nodes will not be dealt with but that does not
-- happen often; we could consider processing sublists but that might need mor
-- checking later on; the current approach also permits variants

local run = 0

function handlers.characters(head)
    -- either next or not, but definitely no already processed list
    starttiming(nodes)
    local usedfonts, attrfonts, done = { }, { }, false
    local a, u, prevfont, prevattr = 0, 0, nil, 0
    if trace_fontrun then
        run = run + 1
        report_fontrun("")
        report_fontrun("node mode run %s",run)
        report_fontrun("")
        local n = head
        while n do
            if n.id == glyph_code then
                local font, attr = n.font, has_attribute(n,0) or 0
                report_run("font %03i dynamic %03i glyph %s",font,attr,utf.char(n.char))
            else
                report_run("[%s]",nodecodes[n.id])
            end
            n = n.next
        end
    end
    for n in traverse_id(glyph_code,head) do
        local font, attr = n.font, has_attribute(n,0) or 0 -- zero attribute is reserved for fonts in context
        if font ~= prevfont or attr ~= prevattr then
            if attr > 0 then
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
                            local d = shared.setdynamics(font,dynamics,attr)
                            if d then
                                used[attr] = d
                                a = a + 1
                            end
                        end
                    end
                end
            else
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
            end
            prevfont = font
            prevattr = attr
        end
    end
    if trace_fontrun then
        report_fontrun("")
        report_fontrun("statics : %s",(u > 0 and concat(table.keys(usedfonts)," ")) or "none")
        report_fontrun("dynamics: %s",(a > 0 and concat(table.keys(attrfonts)," ")) or "none")
        report_fontrun("")
    end
    -- we could combine these and just make the attribute nil
    if u == 1 then
        local font, processors = next(usedfonts)
        local n = #processors
        if n > 0 then
            local h, d = processors[1](head,font,0)
            head = h or head
            done = done or d
            if n > 1 then
                for i=2,n do
                    local h, d = processors[i](head,font,0)
                    head = h or head
                    done = done or d
                end
            end
        end
    elseif u > 0 then
        for font, processors in next, usedfonts do
            local n = #processors
            local h, d = processors[1](head,font,0)
            head = h or head
            done = done or d
            if n > 1 then
                for i=2,n do
                    local h, d = processors[i](head,font,0)
                    head = h or head
                    done = done or d
                end
            end
        end
    end
    if a == 1 then
        local font, dynamics = next(attrfonts)
        for attribute, processors in next, dynamics do -- attr can switch in between
            local n = #processors
            local h, d = processors[1](head,font,attribute)
            head = h or head
            done = done or d
            if n > 1 then
                for i=2,n do
                    local h, d = processors[i](head,font,attribute)
                    head = h or head
                    done = done or d
                end
            end
        end
    elseif a > 0 then
        for font, dynamics in next, attrfonts do
            for attribute, processors in next, dynamics do -- attr can switch in between
                local n = #processors
                local h, d = processors[1](head,font,attribute)
                head = h or head
                done = done or d
                if n > 1 then
                    for i=2,n do
                        local h, d = processors[i](head,font,attribute)
                        head = h or head
                        done = done or d
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

handlers.protectglyphs   = node.protect_glyphs
handlers.unprotectglyphs = node.unprotect_glyphs
