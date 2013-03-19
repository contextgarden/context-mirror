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

local report_fonts      = logs.reporter("fonts","processing")

local fonthashes        = fonts.hashes
local fontdata          = fonthashes.identifiers

local otf               = fonts.handlers.otf

local traverse_id       = node.traverse_id
local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming
local nodecodes         = nodes.nodecodes
local handlers          = nodes.handlers

local glyph_code        = nodecodes.glyph

local setmetatableindex = table.setmetatableindex

-- some tests with using an array of dynamics[id] and processes[id] demonstrated
-- that there was nothing to gain (unless we also optimize other parts)
--
-- maybe getting rid of the intermediate shared can save some time

-- potential speedup: check for subtype < 256 so that we can remove that test
-- elsewhere, danger: injected nodes will not be dealt with but that does not
-- happen often; we could consider processing sublists but that might need more
-- checking later on; the current approach also permits variants

local run = 0

local setfontdynamics = { }
local fontprocesses   = { }

setmetatableindex(setfontdynamics, function(t,font)
    local tfmdata = fontdata[font]
    local shared = tfmdata.shared
    local v = shared and shared.dynamics and otf.setdynamics or false
    t[font] = v
    return v
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

function handlers.characters(head)
    -- either next or not, but definitely no already processed list
    starttiming(nodes)
    local usedfonts, attrfonts, done = { }, { }, false
    local a, u, prevfont, prevattr = 0, 0, nil, 0
    if trace_fontrun then
        run = run + 1
        report_fonts()
        report_fonts("checking node list, run %s",run)
        report_fonts()
        local n = head
        while n do
            local id = n.id
            if id == glyph_code then
                local font = n.font
                local attr = n[0] or 0
                report_fonts("font %03i, dynamic %03i, glyph %s",font,attr,utf.char(n.char))
            else
                report_fonts("[%s]",nodecodes[n.id])
            end
            n = n.next
        end
    end
    -- todo: time a while and skip over or make a special traverse_id that skips over math
    for n in traverse_id(glyph_code,head) do
     -- if n.subtype<256 then -- all are 1
        local font = n.font
        local attr = n[0] or 0 -- zero attribute is reserved for fonts in context
        if font ~= prevfont or attr ~= prevattr then
            if attr > 0 then
                local used = attrfonts[font]
                if not used then
                    used = { }
                    attrfonts[font] = used
                end
                if not used[attr] then
                    local sd = setfontdynamics[font]
                    if sd then -- always true ?
                        local d = sd(font,attr) -- can we cache this one?
                        if d then
                            used[attr] = d
                            a = a + 1
                        else
                            -- can't happen ... otherwise best use nil/false distinction
                        end
                    end
                end
            else
                local used = usedfonts[font]
                if not used then
                    local fp = fontprocesses[font]
                    if fp then
                        usedfonts[font] = fp
                        u = u + 1
                    else
                        -- can't happen ... otherwise best use nil/false distinction
                    end
                end
            end
            prevfont = font
            prevattr = attr
        end
    -- end
    end
    if trace_fontrun then
        report_fonts()
        report_fonts("statics : %s",(u > 0 and concat(keys(usedfonts)," ")) or "none")
        report_fonts("dynamics: %s",(a > 0 and concat(keys(attrfonts)," ")) or "none")
        report_fonts()
    end
    if u == 0 then
        -- skip
    elseif u == 1 then
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
    else
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
    if a == 0 then
        -- skip
    elseif a == 1 then
        local font, dynamics = next(attrfonts)
        for attribute, processors in next, dynamics do -- attr can switch in between
            local n = #processors
            if n == 0 then
                report_fonts("no processors associated with dynamic %s",attribute)
            else
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
    else
        for font, dynamics in next, attrfonts do
            for attribute, processors in next, dynamics do -- attr can switch in between
                local n = #processors
                if n == 0 then
                    report_fonts("no processors associated with dynamic %s",attribute)
                else
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
    end
    stoptiming(nodes)
    if trace_characters then
        nodes.report(head,done)
    end
    return head, true
end

handlers.protectglyphs   = node.protect_glyphs
handlers.unprotectglyphs = node.unprotect_glyphs
