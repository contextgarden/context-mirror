if not modules then modules = { } end modules ['font-col'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

fonts = fonts or { }
nodes = nodes or { }

local format, texsprint = string.format, tex.sprint
local traverse_id, glyph = node.traverse_id, node.id('glyph')

fonts.collections             = fonts.collections or { }
fonts.collections.definitions = fonts.collections.definitions or { }
fonts.collections.vectors     = fonts.collections.vectors or { }
fonts.collections.trace       = false

local definitions = fonts.collections.definitions
local vectors     = fonts.collections.vectors

local list, current, active = { }, 0, false

-- maybe also a copy

function fonts.collections.reset(name,font)
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

function fonts.collections.define(name,font,ranges,details)
    -- todo: details -> method=force|conditional rscale=
    -- todo: remap=name
    local d = definitions[name]
    if not d then
        d = { }
        definitions[name] = d
    end
    details = aux.settings_to_hash(details)
    for s in ranges:gmatch("([^, ]+)") do
        local start, stop = characters.getrange(s)
        if start and stop then
            details.font, details.start, details.stop = font, start, stop
            d[#d+1] = details
        end
    end
end

function fonts.collections.stage_1(name)
    local last = font.current() -- fonts.define.last
    if fonts.collections.trace then
        logs.report("fonts","registering font %s as id %s",name,last)
    end
    list[name] = last
end

function fonts.collections.stage_2(name)
    local d = definitions[name]
    local t = { }
    local ids = fonts.tfm.id
    for i=1,#d do
        local f = d[i]
        local id = list[f.font]
        local start, stop = f.start, f.stop
        if fonts.collections.trace then
            logs.report("fonts","remapping font %s to %s for range 0x%04X - 0x%04X",current,id,start,stop)
        end
        local check = toboolean(f.check or "false")
        local force = toboolean(f.force or "true")
        local remap = f.remap or nil
        -- check: when true, only set when present in font
        -- force: when false, then not set when already set
        local oldchars = ids[current].characters
        local newchars = ids[id].characters
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
    active = true
end

local P, Cc = lpeg.P, lpeg.Cc
local spec = (P("sa") + P("at") + P("scaled") + P("at") + P("mo")) * P(" ")^1 * (1-P(" "))^1 * P(" ")^0 * -1
local okay = ((1-spec)^1 * spec * Cc(true)) + Cc(false)

function fonts.collections.prepare(name)
    local d = definitions[name]
    if d then
        list, current = { }, fonts.define.last
        texsprint(tex.ctxcatcodes,"\\dostartcloningfonts") -- move this to tex \dostart...
        for i=1,#d do
            local f = d[i]
            local name = f.font
            if not list[name] then
                local scale = f.rscale or 1
                if okay:match(name) then
                    texsprint(tex.ctxcatcodes,format("\\doclonefonta{%s}{%s}",name,scale))  -- define with unique specs
                else
                    texsprint(tex.ctxcatcodes,format("\\doclonefontb{%s}{%s}",name,scale))  -- define with inherited specs
                end
                texsprint(tex.ctxcatcodes,format("\\ctxlua{fonts.collections.stage_1('%s')}",name)) -- registering main font
                list[name] = true
            end
        end
        texsprint(tex.ctxcatcodes,format("\\ctxlua{fonts.collections.stage_2('%s')}",name)) -- preparing clone vectors
        texsprint(tex.ctxcatcodes,"\\dostopcloningfonts")
    end
end

function fonts.collections.normalize(head)
    if active then
        local done = false
        local trace = fonts.collections.trace
        for n in traverse_id(glyph,head) do
            local v = vectors[n.font]
            if v then
                local id = v[n.char]
                if id then
                    if type(id) == "table" then
                        local newid, newchar = id[1], id[2]
                        if trace then
                            logs.report("fonts","remapping character %s in font %s to character %s in font %s",n.char,n.font,newchar,newid)
                        end
                        n.font, n.char = newid, newchar
                    else
                        if trace then
                            logs.report("fonts","remapping font %s to %s for character %s",n.font,id,n.char)
                        end
                        n.font = id
                    end
                end
            end
        end
    end
    return head, done
end

nodes.normalize_fonts = fonts.collections.normalize
