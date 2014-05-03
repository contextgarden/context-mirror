-- for the moment here:

local utfchar = utf.char
local concat = table.concat

local nodecodes     = nodes.nodecodes
local hlist_code    = nodecodes.hlist
local vlist_code    = nodecodes.vlist
local glyph_code    = nodecodes.glyph
local kern_code     = nodecodes.kern
local setnodecolor  = nodes.tracers.colors.set
local parameters    = fonts.hashes.parameters
local basepoints    = number.basepoints

-- definecolor[hz:positive] [r=0.6]
-- definecolor[hz:negative] [g=0.6]
-- definecolor[hz:zero]     [b=0.6]

-- scale = multiplier + ef/multiplier

local trace_both    = false  trackers.register("builders.paragraphs.expansion.both",    function(v) trace_verbose = false trace_both  = v end)
local trace_verbose = false  trackers.register("builders.paragraphs.expansion.verbose", function(v) trace_verbose = v     trace_color = v end)

local report_verbose = logs.reporter("fonts","expansion")

local function colorize(n)
    local size, font, ef, width, list, flush, length
    if trace_verbose then
        width  = 0
        length = 0
        list   = { }
        flush  = function()
            if length > 0 then
                report_verbose("%0.3f : %10s  %10s  %s",ef/1000,basepoints(width),basepoints(width*ef/1000000),concat(list,"",1,length))
                width  = 0
                length = 0
            end
        end
    else
        length = 0
    end
    -- tricky: the built-in method creates dummy fonts and the last line normally has the
    -- original font and that one then has ex.auto set
    while n do
        local id = n.id
        if id == glyph_code then
            local ne = n.expansion_factor
            if ne == 0 then
                if length > 0 then flush() end
                setnodecolor(n,"hz:zero")
            else
                local f = n.font
                if f ~= font then
                    if length > 0 then
                        flush()
                    end
                    local pf = parameters[f]
                    local ex = pf.expansion
                    if ex and ex.auto then
                        size = pf.size
                        font = f -- save lookups
                    else
                        size = false
                    end
                end
                if size then
                    if ne ~= ef then
                        if length > 0 then
                            flush()
                        end
                        ef = ne
                    end
                    if ef > 1 then
                        setnodecolor(n,"hz:plus")
                    elseif ef < 1 then
                        setnodecolor(n,"hz:minus")
                    else
                        setnodecolor(n,"hz:zero")
                    end
                    if trace_verbose then
                        length = length + 1
                        list[length] = utfchar(n.char)
                        width = width + n.width -- no kerning yet
                    end
                end
            end
        elseif id == hlist_code or id == vlist_code then
            if length > 0 then
                flush()
            end
            colorize(n.list,flush)
        else -- nothing to show on kerns
            if length > 0 then
                flush()
            end
        end
        n = n.next
    end
    if length > 0 then
        flush()
    end
end

builders.paragraphs.expansion = builders.paragraphs.expansion or { }

function builders.paragraphs.expansion.trace(head)
    colorize(head,true)
    return head
end

local tasks = nodes.tasks

tasks.prependaction("shipouts","normalizers","builders.paragraphs.expansion.trace")
tasks.disableaction("shipouts","builders.paragraphs.expansion.trace")

local function set(v)
    if v then
        tasks.enableaction("shipouts","builders.paragraphs.expansion.trace")
    else
        tasks.disableaction("shipouts","builders.paragraphs.expansion.trace")
    end
end

trackers.register("builders.paragraphs.expansion.verbose",set)
trackers.register("builders.paragraphs.expansion.both",set)
