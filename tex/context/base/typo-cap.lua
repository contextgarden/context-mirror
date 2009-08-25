if not modules then modules = { } end modules ['typo-cap'] = {
    version   = 1.001,
    comment   = "companion to typo-cap.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format, insert = string.format, table.insert

local trace_casing = false  trackers.register("nodes.casing", function(v) trace_casing = v end)

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local set_attribute      = node.set_attribute
local traverse_id        = node.traverse_id

local glyph = node.id("glyph")
local kern  = node.id("kern")

local fontdata = fonts.ids
local chardata = characters.data

cases           = cases or { }
cases.enabled   = false
cases.actions   = { }
cases.attribute = attributes.private("case")

local actions  = cases.actions
local lastfont = nil

-- we use char0 as placeholder for the larger font

local function helper(start, code, codes, special, attribute, once)
    local char = start.char
    local dc = chardata[char]
    if dc then
        local fnt = start.font
        if special then
            if start.char == 0 then
                lastfont = fnt
                local prev, next = start.prev, start.next
                prev.next = next
                if next then
                    next.prev = prev
                end
                return prev, true
            elseif lastfont and start.prev.id ~= glyph then
                fnt = lastfont
                start.font = lastfont
            end
        end
        local ifc = fontdata[fnt].characters
        local ucs = dc[codes]
        if ucs then
            local ok = true
            for i=1,#ucs do
                ok = ok and ifc[ucs[i]]
            end
            if ok then
                local prev, original = start, start
                for i=1,#ucs do
                    local chr = ucs[i]
                    prev = start
                    if i == 1 then
                        start.char = chr
                    else
                        local g = copy_node(original)
                        g.char = chr
                        local next = start.next
                        g.prev = start
                        if next then
                            g.next = next
                            start.next = g
                            next.prev = g
                        end
                        start = g
                    end
                end
                if once then lastfont = nil end
                return prev, true
            end
            if once then lastfont = nil end
            return start, false
        end
        local uc = dc[code]
        if uc and ifc[uc] then
            start.char = uc
            if once then lastfont = nil end
            return start, true
        end
    end
    if once then lastfont = nil end
    return start, false
end

actions[1] = function(start,attribute)
    lastfont = nil
    return helper(start,'uccode','uccodes')
end

actions[2] = function(start,attribute)
    lastfont = nil
    return helper(start,'lccode','lccodes')
end

actions[3] = function(start,attribute)
    lastfont = nil
    local prev = start.prev
    if prev and prev.id == kern and prev.subtype == 0 then
        prev = prev.prev
    end
    if not prev or prev.id ~= glyph then
        --- only the first character is treated
        for n in traverse_id(glyph,start.next) do
            if has_attribute(n,attribute) then
                unset_attribute(n,attribute)
            end
        end
        return helper(start,'uccode','uccodes')
    else
        return start, false
    end
end

actions[4] = function(start,attribute)
    lastfont = nil
    local prev = start.prev
    if prev and prev.id == kern and prev.subtype == 0 then
        prev = prev.prev
    end
    if not prev or prev.id ~= glyph then
        return helper(start,'uccode','uccodes')
    else
        return start, false
    end
end

actions[5] = function(start,attribute) -- 3
    return helper(start,'uccode','uccodes',true,attribute,true)
end

actions[6] = function(start,attribute) -- 4
    return helper(start,'uccode','uccodes',true,attribute,false)
end

actions[8] = function(start)
    lastfont = nil
    local ch = start.char
    local mr = math.random
    local tfm = fontdata[start.font].characters
    if chardata[ch].lccode then
        while true do
            local d = chardata[mr(1,0xFFFF)]
            if d then
                local uc = d.uccode
                if uc and tfm[uc] then
                    start.char = uc
                    return start, true
                end
            end
        end
    elseif chardata[ch].uccode then
        while true do
            local d = chardata[mr(1,0xFFFF)]
            if d then
                local lc = d.lccode
                if lc and tfm[lc] then
                    start.char = lc
                    return start, true
                end
            end
        end
    else
        return start, false
    end
end

-- node.traverse_id_attr

function cases.process(namespace,attribute,head) -- not real fast but also not used on much data
    lastfont = nil
    local done = false
    for start in traverse_id(glyph,head) do
        local attr = has_attribute(start,attribute)
        if attr and attr > 0 then
            unset_attribute(start,attribute)
            local action = actions[attr]
            if action then
                local _, ok = action(start,attribute)
                done = done and ok
            end
        end
    end
    lastfont = nil
    return head, done
end

chars.handle_casing = nodes.install_attribute_handler {
    name = "case",
    namespace = cases,
    processor = cases.process,
}
