if not modules then modules = { } end modules ['luatex-fonts-cbk'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then
    texio.write_nl("fatal error: this module is not for context")
    os.exit()
end

local fonts = fonts
local nodes = nodes

-- Fonts: (might move to node-gef.lua)

local traverse_id = node.traverse_id
local free_node   = node.free
local remove_node = node.remove

local glyph_code  = nodes.nodecodes.glyph
local disc_code   = nodes.nodecodes.disc

-- from now on we apply ligaturing and kerning here because it might interfere with complex
-- opentype discretionary handling where the base ligature pass expect some weird extra
-- pointers (which then confuse the tail slider that has some checking built in)

local ligaturing    = node.ligaturing
local kerning       = node.kerning

local basepass      = true

local function l_warning() texio.write_nl("warning: node.ligaturing called directly") l_warning = nil end
local function k_warning() texio.write_nl("warning: node.kerning called directly")    k_warning = nil end

function node.ligaturing(...)
    if basepass and l_warning then
        l_warning()
    end
    return ligaturing(...)
end

function node.kerning(...)
    if basepass and k_warning then
        k_warning()
    end
    return kerning(...)
end

function nodes.handlers.setbasepass(v)
    basepass = v
end

function nodes.handlers.nodepass(head)
    local fontdata = fonts.hashes.identifiers
    if fontdata then
        local usedfonts = { }
        local basefonts = { }
        local prevfont  = nil
        local basefont  = nil
        local variants  = nil
        local redundant = nil
        for n in traverse_id(glyph_code,head) do
            local font = n.font
            if font ~= prevfont then
                if basefont then
                    basefont[2] = n.prev
                end
                prevfont = font
                local used = usedfonts[font]
                if not used then
                    local tfmdata = fontdata[font] --
                    if tfmdata then
                        local shared = tfmdata.shared -- we need to check shared, only when same features
                        if shared then
                            local processors = shared.processes
                            if processors and #processors > 0 then
                                usedfonts[font] = processors
                            elseif basepass then
                                basefont = { n, nil }
                                basefonts[#basefonts+1] = basefont
                            end
                        end
                        local resources = tfmdata.resources
                        variants  = resources and resources.variants
                        variants = variants and next(variants) and variants or false
                    end
                else
                    local tfmdata = fontdata[prevfont]
                    if tfmdata then
                        local resources = tfmdata.resources
                        variants = resources and resources.variants
                        variants = variants and next(variants) and variants or false
                    end
                end
            end
            if variants then
                local char = n.char
                if char >= 0xFE00 and (char <= 0xFE0F or (char >= 0xE0100 and char <= 0xE01EF)) then
                    local hash = variants[char]
                    if hash then
                        local p = n.prev
                        if p and p.id == glyph_code then
                            local variant = hash[p.char]
                            if variant then
                                p.char = variant
                                if not redundant then
                                    redundant = { n }
                                else
                                    redundant[#redundant+1] = n
                                end
                            end
                        end
                    end
                end
            end
        end
        if redundant then
            for i=1,#redundant do
                local n = redundant[i]
                remove_node(head,n)
                free_node(n)
            end
        end
        for d in traverse_id(disc_code,head) do
            local r = d.replace
            if r then
                for n in traverse_id(glyph_code,r) do
                    local font = n.font
                    if font ~= prevfont then
                        prevfont = font
                        local used = usedfonts[font]
                        if not used then
                            local tfmdata = fontdata[font] --
                            if tfmdata then
                                local shared = tfmdata.shared -- we need to check shared, only when same features
                                if shared then
                                    local processors = shared.processes
                                    if processors and #processors > 0 then
                                        usedfonts[font] = processors
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if next(usedfonts) then
            for font, processors in next, usedfonts do
                for i=1,#processors do
                    head = processors[i](head,font,0) or head
                end
            end
        end
        if basepass and #basefonts > 0 then
            for i=1,#basefonts do
                local range = basefonts[i]
                local start = range[1]
                local stop  = range[2]
                -- maybe even: if start and start ~= stop then
                if start or stop then
                    local prev  = nil
                    local next  = nil
                    local front = start == head
                    if stop then
                        next  = stop.next
                        start, stop = ligaturing(start,stop)
                        start, stop = kerning(start,stop)
                    elseif start then
                        prev  = start.prev
                        start = ligaturing(start)
                        start = kerning(start)
                    end
                    if prev then
                        start.prev = prev
                        prev.next  = start
                    end
                    if next then
                        stop.next  = next
                        next.prev  = stop
                    end
                    if front then
                        head = start
                    end
                end
            end
        end
        return head, true
    else
        return head, false
    end
end

function nodes.handlers.basepass(head)
    if basepass then
        head = ligaturing(head)
        head = kerning(head)
    end
    return head, true
end

local nodepass    = nodes.handlers.nodepass
local basepass    = nodes.handlers.basepass
local injectpass  = nodes.injections.handler
local protectpass = nodes.handlers.protectglyphs

function nodes.simple_font_handler(head)
    if head then
        head = nodepass(head)
        head = injectpass(head)
        head = basepass(head)
        protectpass(head)
        return head, true
    else
        return head, false
    end
end
