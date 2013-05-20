if not modules then modules = { } end modules ['font-col'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- possible optimization: delayed initialization of vectors

local context, commands, trackers, logs = context, commands, trackers, logs
local node, nodes, fonts, characters = node, nodes, fonts, characters
local file, lpeg, table, string = file, lpeg, table, string

local type, next, toboolean = type, next, toboolean
local gmatch = string.gmatch
local fastcopy = table.fastcopy
----- P, Cc, lpegmatch = lpeg.P, lpeg.Cc, lpeg.match

local traverse_id        = node.traverse_id
local settings_to_hash   = utilities.parsers.settings_to_hash

local trace_collecting   = false  trackers.register("fonts.collecting", function(v) trace_collecting = v end)

local report_fonts       = logs.reporter("fonts","collections")

local collections        = fonts.collections or { }
fonts.collections        = collections

local definitions        = collections.definitions or { }
collections.definitions  = definitions

local vectors            = collections.vectors or { }
collections.vectors      = vectors

local fontdata           = fonts.hashes.identifiers
local glyph_code         = nodes.nodecodes.glyph
local currentfont        = font.current

local fontpatternhassize = fonts.helpers.fontpatternhassize

local list               = { }
local current            = 0
local enabled            = false

-- maybe also a copy

function collections.reset(name,font)
    if font and font ~= "" then
        local d = definitions[name]
        if d then
            d[font] = nil
            if not next(d) then
                definitions[name] = nil
            end
        end
    else
        definitions[name] = nil
    end
end

function collections.define(name,font,ranges,details)
    -- todo: details -> method=force|conditional rscale=
    -- todo: remap=name
    local d = definitions[name]
    if not d then
        d = { }
        definitions[name] = d
    end
    if name and trace_collecting then
        report_fonts("extending collection %a using %a",name,font)
    end
    details = settings_to_hash(details)
    -- todo, combine per font start/stop as arrays
    for s in gmatch(ranges,"[^, ]+") do
        local start, stop, description = characters.getrange(s)
        if start and stop then
            if trace_collecting then
                if description then
                    report_fonts("using range %a, slots %U - %U, description %a)",s,start,stop,description)
                end
                for i=1,#d do
                    local di = d[i]
                    if (start >= di.start and start <= di.stop) or (stop >= di.start and stop <= di.stop) then
                        report_fonts("overlapping ranges %U - %U and %U - %U",start,stop,di.start,di.stop)
                    end
                end
            end
            details.font, details.start, details.stop = font, start, stop
            d[#d+1] = fastcopy(details)
        end
    end
end

-- todo: provide a lua variant (like with definefont)

function collections.registermain(name)
    local last = currentfont()
    if trace_collecting then
        report_fonts("registering font %a with name %a",last,name)
    end
    list[#list+1] = last
end

function collections.clonevector(name)
    statistics.starttiming(fonts)
    local d = definitions[name]
    local t = { }
    if trace_collecting then
        report_fonts("processing collection %a",name)
    end
    for i=1,#d do
        local f = d[i]
        local id = list[i]
        local start, stop = f.start, f.stop
        if trace_collecting then
            report_fonts("remapping font %a to %a for range %U - %U",current,id,start,stop)
        end
        local check = toboolean(f.check or "false",true)
        local force = toboolean(f.force or "true",true)
        local remap = f.remap or nil
        -- check: when true, only set when present in font
        -- force: when false, then not set when already set
        local oldchars = fontdata[current].characters
        local newchars = fontdata[id].characters
        if check then
            for i=start,stop do
                if newchars[i] and (force or (not t[i] and not oldchars[i])) then
                    if remap then
                        t[i] = { id, remap[i] }
                    else
                        t[i] = id
                    end
                end
            end
        else
            for i=start,stop do
                if force or (not t[i] and not oldchars[i]) then
                    if remap then
                        t[i] = { id, remap[i] }
                    else
                        t[i] = id
                    end
                end
            end
        end
    end
    vectors[current] = t
    if trace_collecting then
        report_fonts("activating collection %a for font %a",name,current)
    end
    if not enabled then
        nodes.tasks.enableaction("processors","fonts.collections.process")
        enabled = true
    end
    statistics.stoptiming(fonts)
end

-- we already have this parser
--
-- local spec = (P("sa") + P("at") + P("scaled") + P("at") + P("mo")) * P(" ")^1 * (1-P(" "))^1 * P(" ")^0 * -1
-- local okay = ((1-spec)^1 * spec * Cc(true)) + Cc(false)
--
-- if lpegmatch(okay,name) then

function collections.prepare(name)
    current = currentfont()
    if vectors[current] then
        return
    end
    local d = definitions[name]
    if d then
        if trace_collecting then
            local filename = file.basename(fontdata[current].properties.filename or "?")
            report_fonts("applying collection %a to %a, file %a",name,current,filename)
        end
        list = { }
        context.pushcatcodes("prt") -- context.unprotect()
        context.font_fallbacks_start_cloning()
        for i=1,#d do
            local f = d[i]
            local name = f.font
            local scale = f.rscale or 1
            if fontpatternhassize(name) then
                context.font_fallbacks_clone_unique(name,scale)
            else
                context.font_fallbacks_clone_inherited(name,scale)
            end
            context.font_fallbacks_register_main(name)
        end
        context.font_fallbacks_prepare_clone_vectors(name)
        context.font_fallbacks_stop_cloning()
        context.popcatcodes() -- context.protect()
    elseif trace_collecting then
        local filename = file.basename(fontdata[current].properties.filename or "?")
        report_fonts("error while applying collection %a to %a, file %a",name,current,filename)
    end
end

function collections.report(message)
    if trace_collecting then
        report_fonts("tex: %s",message)
    end
end

function collections.process(head) -- this way we keep feature processing
    local done = false
    for n in traverse_id(glyph_code,head) do
        local v = vectors[n.font]
        if v then
            local id = v[n.char]
            if id then
                if type(id) == "table" then
                    local newid, newchar = id[1], id[2]
                    if trace_collecting then
                        report_fonts("remapping character %a in font %a to character %a in font %a",n.char,n.font,newchar,newid)
                    end
                    n.font, n.char = newid, newchar
                else
                    if trace_collecting then
                        report_fonts("remapping font %a to %a for character %a",n.font,id,n.char)
                    end
                    n.font = id
                end
            end
        end
    end
    return head, done
end

-- interface

commands.fontcollectiondefine   = collections.define
commands.fontcollectionreset    = collections.reset
commands.fontcollectionprepare  = collections.prepare
commands.fontcollectionreport   = collections.report
commands.fontcollectionregister = collections.registermain
commands.fontcollectionclone    = collections.clonevector
