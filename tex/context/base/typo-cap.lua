if not modules then modules = { } end modules ['typo-cap'] = {
    version   = 1.001,
    comment   = "companion to typo-cap.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format, insert = string.format, table.insert
local div = math.div

local trace_casing = false  trackers.register("typesetters.casing", function(v) trace_casing = v end)

local report_casing = logs.new("casing")

local nodes, node = nodes, node

local has_attribute   = node.has_attribute
local unset_attribute = node.unset_attribute
local set_attribute   = node.set_attribute
local traverse_id     = node.traverse_id

local texattribute    = tex.attribute

local nodecodes       = nodes.nodecodes
local skipcodes       = nodes.skipcodes
local kerncodes       = nodes.kerncodes

local glyph_code      = nodecodes.glyph
local kern_code       = nodecodes.kern

local kerning_code    = kerncodes.kerning
local userskip_code   = skipcodes.userskip

local tasks           = nodes.tasks

local fontdata        = fonts.ids
local fontchar        = fonts.chr
local chardata        = characters.data

typesetters           = typesetters or { }
local typesetters     = typesetters

typesetters.cases     = typesetters.cases or { }
local cases           = typesetters.cases

cases.actions         = { }
local actions         = cases.actions
cases.attribute       = c_cases  -- no longer needed
local a_cases         = attributes.private("case")

local lastfont        = nil

-- we use char(0) as placeholder for the larger font, so we need to remove it
-- before it can do further harm
--
-- we could do the whole glyph run here (till no more attributes match) but
-- then we end up with more code .. maybe i will clean this up anyway as the
-- lastfont hack is somewhat ugly .. on the other hand, we need to deal with
-- cases like:
--
-- \WORD {far too \Word{many \WORD{more \word{pushed} in between} useless} words}

local function helper(start, code, codes, special, attribute, once)
    local char = start.char
    local dc = chardata[char]
    if dc then
        local fnt = start.font
        if special then
            -- will become function
            if start.char == 0 then
                lastfont = fnt
                local prev, next = start.prev, start.next
                prev.next = next
                if next then
                    next.prev = prev
                end
                return prev, true
            elseif lastfont and start.prev.id ~= glyph_code then
                fnt = lastfont
                start.font = lastfont
            end
        end
        local ifc = fontchar[fnt]
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

actions[3] = function(start,attribute,attr)
    lastfont = nil
    local prev = start.prev
    if prev and prev.id == kern_code and prev.subtype == kerning_code then
        prev = prev.prev
    end
    if not prev or prev.id ~= glyph_code then
        --- only the first character is treated
        for n in traverse_id(glyph_code,start.next) do
            if has_attribute(n,attribute) == attr then
                unset_attribute(n,attribute)
            else
             -- break -- we can have nested mess
            end
        end
        -- we could return the last in the range and save some scanning
        -- but why bother
        return helper(start,'uccode','uccodes')
    else
        return start, false
    end
end

actions[4] = function(start,attribute)
    lastfont = nil
    local prev = start.prev
    if prev and prev.id == kern_code and prev.subtype == kerning_code then
        prev = prev.prev
    end
    if not prev or prev.id ~= glyph_code then
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
 -- local tfm = fontdata[start.font].characters
    local tfm = fontchar[start.font]
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
    end
    return start, false
end

-- node.traverse_id_attr

local function process(namespace,attribute,head) -- not real fast but also not used on much data
    lastfont = nil
    local lastattr = nil
    local done = false
    local start = head
    while start do -- while because start can jump ahead
        local id = start.id
        if id == glyph_code then
            local attr = has_attribute(start,attribute)
            if attr and attr > 0 then
                if attr ~= lastattr then
                    lastfont = nil
                    lastattr = attr
                end
                unset_attribute(start,attribute)
                local action = actions[attr%100] -- map back to low number
                if action then
                    start, ok = action(start,attribute,attr)
                    done = done and ok
                    if trace_casing then
                        report_casing("case trigger %s, instance %s, result %s",attr%100,div(attr,100),tostring(ok))
                    end
                elseif trace_casing then
                    report_casing("unknown case trigger %s",attr)
                end
            end
        end
        if start then
            start = start.next
        end
    end
    lastfont = nil
    return head, done
end

local m, enabled = 0, false -- a trick to make neighbouring ranges work

function cases.set(n)
    if not enabled then
        tasks.enableaction("processors","typesetters.cases.handler")
        if trace_casing then
            report_casing("enabling case handler")
        end
        enabled = true
    end
    if m == 100 then
        m = 1
    else
        m = m + 1
    end
    texattribute[a_cases] = m * 100 + n
end

cases.handler = nodes.installattributehandler {
    name      = "case",
    namespace = cases,
    processor = process,
}
