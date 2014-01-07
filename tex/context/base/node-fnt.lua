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

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

local nodecodes         = nodes.nodecodes
local handlers          = nodes.handlers

local nuts              = nodes.nuts
local tonut             = nuts.tonut

local getattr           = nuts.getattr
local getid             = nuts.getid
local getfont           = nuts.getfont
local getsubtype        = nuts.getsubtype
local getchar           = nuts.getchar
local getnext           = nuts.getnext

local traverse_id       = nuts.traverse_id

local glyph_code        = nodecodes.glyph
local disc_code         = nodecodes.disc

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

function handlers.characters(head)
    -- either next or not, but definitely no already processed list
    starttiming(nodes)
    local usedfonts, attrfonts = { }, { }
    local a, u, prevfont, prevattr, done = 0, 0, nil, 0, false
    if trace_fontrun then
        run = run + 1
        report_fonts()
        report_fonts("checking node list, run %s",run)
        report_fonts()
        local n = tonut(head)
        while n do
            local id = getid(n)
            if id == glyph_code then
                local font = getfont(n)
                local attr = getattr(n,0) or 0
                report_fonts("font %03i, dynamic %03i, glyph %C",font,attr,getchar(n))
            elseif id == disc_code then
                report_fonts("[disc] %s",nodes.listtoutf(n,true,false,n))
            else
                report_fonts("[%s]",nodecodes[id])
            end
            n = getnext(n)
        end
    end
    for n in traverse_id(glyph_code,tonut(head)) do
     -- if getsubtype(n) <256 then -- all are 1
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
    -- end
    end
    if trace_fontrun then
        report_fonts()
        report_fonts("statics : %s",(u > 0 and concat(keys(usedfonts)," ")) or "none")
        report_fonts("dynamics: %s",(a > 0 and concat(keys(attrfonts)," ")) or "none")
        report_fonts()
    end
    -- in context we always have at least 2 processors
    if u == 0 then
        -- skip
    elseif u == 1 then
        local font, processors = next(usedfonts)
        for i=1,#processors do
            local h, d = processors[i](head,font,0)
            if d then
                head = h or head
                done = true
            end
        end
    else
        for font, processors in next, usedfonts do
            for i=1,#processors do
                local h, d = processors[i](head,font,0)
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
    stoptiming(nodes)
    if trace_characters then
        nodes.report(head,done)
    end
    return head, true
end

--     local formatters = string.formatters

--     local function make(processors,font,attribute)
--         _G.__temp = processors
--         local t = { }
--         for i=1,#processors do
--             if processors[i] then
--                 t[#t+1] = formatters["local p_%s = _G.__temp[%s]"](i,i)
--             end
--         end
--         t[#t+1] = "return function(head,done)"
--         if #processors == 1 then
--             t[#t+1] = formatters["return p_%s(head,%s,%s)"](1,font,attribute or 0)
--         else
--             for i=1,#processors do
--                 if processors[i] then
--                     t[#t+1] = formatters["local h,d=p_%s(head,%s,%s) if d then head=h or head done=true end"](i,font,attribute or 0)
--                 end
--             end
--             t[#t+1] = "return head, done"
--         end
--         t[#t+1] = "end"
--         t = concat(t,"\n")
--         t = load(t)(processors)
--         _G.__temp = nil
--         return t
--     end

--     setmetatableindex(fontprocesses, function(t,font)
--         local tfmdata = fontdata[font]
--         local shared = tfmdata.shared -- we need to check shared, only when same features
--         local processes = shared and shared.processes
--         if processes and #processes > 0 then
--             processes = make(processes,font,0)
--             t[font] = processes
--             return processes
--         else
--             t[font] = false
--             return false
--         end
--     end)

--     setmetatableindex(setfontdynamics, function(t,font)
--         local tfmdata = fontdata[font]
--         local shared = tfmdata.shared
--         local f = shared and shared.dynamics and otf.setdynamics or false
--         if f then
--             local v = { }
--             t[font] = v
--             setmetatableindex(v,function(t,k)
--                 local v = f(font,k)
--                 v = make(v,font,k)
--                 t[k] = v
--                 return v
--             end)
--             return v
--         else
--             t[font] = false
--             return false
--         end
--     end)

--     function handlers.characters(head)
--         -- either next or not, but definitely no already processed list
--         starttiming(nodes)
--         local usedfonts, attrfonts
--         local a, u, prevfont, prevattr, done = 0, 0, nil, 0, false
--         if trace_fontrun then
--             run = run + 1
--             report_fonts()
--             report_fonts("checking node list, run %s",run)
--             report_fonts()
--             local n = head
--             while n do
--                 local id = n.id
--                 if id == glyph_code then
--                     local font = n.font
--                     local attr = n[0] or 0
--                     report_fonts("font %03i, dynamic %03i, glyph %s",font,attr,utf.char(n.char))
--                 else
--                     report_fonts("[%s]",nodecodes[n.id])
--                 end
--                 n = n.next
--             end
--         end
--         for n in traverse_id(glyph_code,head) do
--          -- if n.subtype<256 then -- all are 1
--             local font = n.font
--             local attr = n[0] or 0 -- zero attribute is reserved for fonts in context
--             if font ~= prevfont or attr ~= prevattr then
--                 if attr > 0 then
--                     if not attrfonts then
--                         attrfonts = {
--                             [font] = {
--                                 [attr] = setfontdynamics[font][attr]
--                             }
--                         }
--                         a = 1
--                     else
--                         local used = attrfonts[font]
--                         if not used then
--                             attrfonts[font] = {
--                                 [attr] = setfontdynamics[font][attr]
--                             }
--                             a = a + 1
--                         elseif not used[attr] then
--                             used[attr] = setfontdynamics[font][attr]
--                             a = a + 1
--                         end
--                     end
--                 else
--                     if not usedfonts then
--                         local fp = fontprocesses[font]
--                         if fp then
--                             usedfonts = {
--                                 [font] = fp
--                             }
--                             u = 1
--                         end
--                     else
--                         local used = usedfonts[font]
--                         if not used then
--                             local fp = fontprocesses[font]
--                             if fp then
--                                 usedfonts[font] = fp
--                                 u = u + 1
--                             end
--                         end
--                     end
--                 end
--                 prevfont = font
--                 prevattr = attr
--             end
--         -- end
--         end
--         if trace_fontrun then
--             report_fonts()
--             report_fonts("statics : %s",(u > 0 and concat(keys(usedfonts)," ")) or "none")
--             report_fonts("dynamics: %s",(a > 0 and concat(keys(attrfonts)," ")) or "none")
--             report_fonts()
--         end
--         if not usedfonts then
--             -- skip
--         elseif u == 1 then
--             local font, processors = next(usedfonts)
--             head, done = processors(head,done)
--         else
--             for font, processors in next, usedfonts do
--                 head, done = processors(head,done)
--             end
--         end
--         if not attrfonts then
--             -- skip
--         elseif a == 1 then
--             local font, dynamics = next(attrfonts)
--             for attribute, processors in next, dynamics do
--                 head, done = processors(head,done)
--             end
--         else
--             for font, dynamics in next, attrfonts do
--                 for attribute, processors in next, dynamics do
--                     head, done = processors(head,done)
--                 end
--             end
--         end
--         stoptiming(nodes)
--         if trace_characters then
--             nodes.report(head,done)
--         end
--         return head, true
--     end

local d_protect_glyphs   = nuts.protect_glyphs
local d_unprotect_glyphs = nuts.unprotect_glyphs

handlers.protectglyphs   = function(n) return d_protect_glyphs  (tonut(n)) end
handlers.unprotectglyphs = function(n) return d_unprotect_glyphs(tonut(n)) end
