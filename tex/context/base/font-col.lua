if not modules then modules = { } end modules ['font-col'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- possible optimization: delayed initialization of vectors

local gmatch, type = string.gmatch, type
local traverse_id, first_character = node.traverse_id, node.first_character
local lpegmatch = lpeg.match
local settings_to_hash = utilities.parsers.settings_to_hash

local trace_collecting = false  trackers.register("fonts.collecting", function(v) trace_collecting = v end)

local report_fonts = logs.new("fonts")

local fonts, context = fonts, context

fonts.collections       = fonts.collections or { }
local collections       = fonts.collections

collections.definitions = collections.definitions or { }
local definitions       = collections.definitions

collections.vectors     = collections.vectors or { }
local vectors           = collections.vectors

local fontdata          = fonts.ids

local glyph = node.id('glyph')

local list, current, active = { }, 0, false

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
    if d then
        if name and trace_collecting then
            report_fonts("def: extending set %s using %s",name, font)
        end
    else
        if name and trace_collecting then
            report_fonts("def: defining set %s using %s",name, font)
        end
        d = { }
        definitions[name] = d
    end
    details = settings_to_hash(details)
    -- todo, combine per font start/stop as arrays
    for s in gmatch(ranges,"([^, ]+)") do
        local start, stop, description = characters.getrange(s)
        if start and stop then
            if trace_collecting then
                if description then
                    report_fonts("def: using range %s (U+%04x-U+%04X, %s)",s,start,stop,description)
                end
                for i=1,#d do
                    local di = d[i]
                    if (start >= di.start and start <= di.stop) or (stop >= di.start and stop <= di.stop) then
                        report_fonts("def: overlapping ranges U+%04x-U+%04X and U+%04x-U+%04X",start,stop,di.start,di.stop)
                    end
                end
            end
            details.font, details.start, details.stop = font, start, stop
            d[#d+1] = table.fastcopy(details)
        end
    end
end

function collections.stage_1(name)
    local last = font.current()
    if trace_collecting then
        report_fonts("def: registering font %s with name %s",last,name)
    end
    list[#list+1] = last
end

function collections.stage_2(name)
    statistics.starttiming(fonts)
    local d = definitions[name]
    local t = { }
    if trace_collecting then
        report_fonts("def: process collection %s",name)
    end
    for i=1,#d do
        local f = d[i]
        local id = list[i]
        local start, stop = f.start, f.stop
        if trace_collecting then
            report_fonts("def: remapping font %s to %s for range U+%04X - U+%04X",current,id,start,stop)
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
        report_fonts("def: activating collection %s for font %s",name,current)
    end
    active = true
    statistics.stoptiming(fonts)
end

local P, Cc = lpeg.P, lpeg.Cc
local spec = (P("sa") + P("at") + P("scaled") + P("at") + P("mo")) * P(" ")^1 * (1-P(" "))^1 * P(" ")^0 * -1
local okay = ((1-spec)^1 * spec * Cc(true)) + Cc(false)

-- todo: check for already done

function collections.prepare(name)
    current = font.current()
    if vectors[current] then
        return
    end
    local d = definitions[name]
    if d then
        if trace_collecting then
            local filename = file.basename(fontdata[current].filename or "?")
            report_fonts("def: applying collection %s to %s (file: %s)",name,current,filename)
        end
        list = { }
        context.dostartcloningfonts() -- move this to tex \dostart...
        for i=1,#d do
            local f = d[i]
            local name = f.font
            local scale = f.rscale or 1
            if lpegmatch(okay,name) then
                context.doclonefonta(name,scale)  -- define with unique specs
            else
                context.doclonefontb(name,scale)  -- define with inherited specs
            end
            context.doclonefontstageone(name) -- registering main font
        end
        context.doclonefontstagetwo(name) -- preparing clone vectors
        context.dostopcloningfonts()
    elseif trace_collecting then
        local filename = file.basename(fontdata[current].filename or "?")
        report_fonts("def: error in applying collection %s to %s (file: %s)",name,current,filename)
    end
end

function collections.message(message)
    if trace_collecting then
        report_fonts("tex: %s",message)
    end
end

function collections.process(head)
    if active then
        local done = false
        for n in traverse_id(glyph,head) do
            local v = vectors[n.font]
            if v then
                local id = v[n.char]
                if id then
                    if type(id) == "table" then
                        local newid, newchar = id[1], id[2]
                        if trace_collecting then
                            report_fonts("lst: remapping character %s in font %s to character %s in font %s",n.char,n.font,newchar,newid)
                        end
                        n.font, n.char = newid, newchar
                    else
                        if trace_collecting then
                            report_fonts("lst: remapping font %s to %s for character %s",n.font,id,n.char)
                        end
                        n.font = id
                    end
                end
            end
        end
        return head, done
    else
        return head, false
    end
end
