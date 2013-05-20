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

local report_casing = logs.reporter("typesetting","casing")

local nodes, node = nodes, node

local traverse_id     = node.traverse_id
local copy_node       = node.copy
local end_of_math     = node.end_of_math

local texattribute    = tex.attribute
local unsetvalue      = attributes.unsetvalue

local nodecodes       = nodes.nodecodes
local skipcodes       = nodes.skipcodes
local kerncodes       = nodes.kerncodes

local glyph_code      = nodecodes.glyph
local kern_code       = nodecodes.kern
local math_code       = nodecodes.math

local kerning_code    = kerncodes.kerning
local userskip_code   = skipcodes.userskip

local tasks           = nodes.tasks

local fonthashes      = fonts.hashes
local fontdata        = fonthashes.identifiers
local fontchar        = fonthashes.characters

local variables       = interfaces.variables
local v_reset         = variables.reset

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

local uccodes = characters.uccodes
local lccodes = characters.lccodes

local function helper(start, codes, special, attribute, once)
    local char = start.char
    local dc = codes[char]
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
        if type(dc) == "table" then
            local ok = true
            for i=1,#dc do
                ok = ok and ifc[dc[i]]
            end
            if ok then
                -- tood; use generic injector
                local prev, original = start, start
                for i=1,#dc do
                    local chr = dc[i]
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
        elseif ifc[dc] then
            start.char = dc
            if once then lastfont = nil end
            return start, true
        end
    end
    if once then lastfont = nil end
    return start, false
end

local registered, n = { }, 0

local function register(name,f)
    if type(f) == "function" then
        n = n + 1
        actions[n] = f
        registered[name] = n
        return n
    else
        local n = registered[f]
        registered[name] = n
        return n
    end
end

cases.register = register

local function WORD(start,attribute)
    lastfont = nil
    return helper(start,uccodes)
end

local function word(start,attribute)
    lastfont = nil
    return helper(start,lccodes)
end

local function Word(start,attribute,attr)
    lastfont = nil
    local prev = start.prev
    if prev and prev.id == kern_code and prev.subtype == kerning_code then
        prev = prev.prev
    end
    if not prev or prev.id ~= glyph_code then
        --- only the first character is treated
        for n in traverse_id(glyph_code,start.next) do
            if n[attribute] == attr then
                n[attribute] = unsetvalue
            else
             -- break -- we can have nested mess
            end
        end
        -- we could return the last in the range and save some scanning
        -- but why bother
        return helper(start,uccodes)
    else
        return start, false
    end
end

local function Words(start,attribute)
    lastfont = nil
    local prev = start.prev
    if prev and prev.id == kern_code and prev.subtype == kerning_code then
        prev = prev.prev
    end
    if not prev or prev.id ~= glyph_code then
        return helper(start,uccodes)
    else
        return start, false
    end
end

local function capital(start,attribute) -- 3
    return helper(start,uccodes,true,attribute,true)
end

local function Capital(start,attribute) -- 4
    return helper(start,uccodes,true,attribute,false)
end

local function none(start)
    return start, false
end

local function random(start)
    lastfont = nil
    local ch = start.char
    local mr = math.random
 -- local tfm = fontdata[start.font].characters
    local tfm = fontchar[start.font]
    if lccodes[ch] then
        while true do
            local d = chardata[mr(1,0xFFFF)]
            if d then
                local uc = uccodes[d]
                if uc and tfm[uc] then -- this also intercepts tables
                    start.char = uc
                    return start, true
                end
            end
        end
    elseif uccodes[ch] then
        while true do
            local d = chardata[mr(1,0xFFFF)]
            if d then
                local lc = lccodes[d]
                if lc and tfm[lc] then -- this also intercepts tables
                    start.char = lc
                    return start, true
                end
            end
        end
    end
    return start, false
end

register(variables.WORD,    WORD)              --  1
register(variables.word,    word)              --  2
register(variables.Word,    Word)              --  3
register(variables.Words,   Words)             --  4
register(variables.capital, capital)           --  5
register(variables.Capital, Capital)           --  6
register(variables.none,    none)              --  7 (dummy)
register(variables.random,  random)            --  8

register(variables.cap,     variables.capital) -- clone
register(variables.Cap,     variables.Capital) -- clone

-- node.traverse_id_attr

local function process(namespace,attribute,head) -- not real fast but also not used on much data
    lastfont = nil
    local lastattr = nil
    local done = false
    local start = head
    while start do -- while because start can jump ahead
        local id = start.id
        if id == glyph_code then
            local attr = start[attribute]
            if attr and attr > 0 then
                if attr ~= lastattr then
                    lastfont = nil
                    lastattr = attr
                end
                start[attribute] = unsetvalue
                local action = actions[attr%100] -- map back to low number
                if action then
                    start, ok = action(start,attribute,attr)
                    done = done and ok
                    if trace_casing then
                        report_casing("case trigger %a, instance %a, result %a",attr%100,div(attr,100),ok)
                    end
                elseif trace_casing then
                    report_casing("unknown case trigger %a",attr)
                end
            end
        elseif id == math_code then
            start = end_of_math(start)
        end
        if start then -- why test
            start = start.next
        end
    end
    lastfont = nil
    return head, done
end

local m, enabled = 0, false -- a trick to make neighbouring ranges work

function cases.set(n)
    if n == v_reset then
        n = unsetvalue
    else
        n = registered[n] or tonumber(n)
        if n then
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
            n = m * 100 + n
        else
            n = unsetvalue
        end
    end
    texattribute[a_cases] = n
 -- return n -- bonus
end

cases.handler = nodes.installattributehandler {
    name      = "case",
    namespace = cases,
    processor = process,
}

-- interface

commands.setcharactercasing = cases.set
