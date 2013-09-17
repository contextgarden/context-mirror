if not modules then modules = { } end modules ['typo-cap'] = {
    version   = 1.001,
    comment   = "companion to typo-cap.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
    }

local next, type = next, type
local format, insert = string.format, table.insert
local div, randomnumber = math.div, math.random

local trace_casing = false  trackers.register("typesetters.casing", function(v) trace_casing = v end)

local report_casing = logs.reporter("typesetting","casing")

local nodes, node = nodes, node

local traverse_id     = nodes.traverse_id
local copy_node       = nodes.copy
local end_of_math     = nodes.end_of_math
local free_node       = nodes.free
local remove_node     = nodes.remove

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
local texsetattribute = tex.setattribute
local unsetvalue      = attributes.unsetvalue

typesetters           = typesetters or { }
local typesetters     = typesetters

typesetters.cases     = typesetters.cases or { }
local cases           = typesetters.cases

cases.actions         = { }
local actions         = cases.actions
local a_cases         = attributes.private("case")

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

-- true false true == mixed

local function helper(head,start,attr,lastfont,codes,special,once,keepother)
    local char = start.char
    local dc = codes[char]
    if dc then
        local fnt = start.font
        if special then
            -- will become function
            if char == 0 then
                lastfont[attr] = fnt
                head, start = remove_node(head,start,true)
                return head, start and start.prev or head, true
            elseif lastfont[attr] and start.prev.id ~= glyph_code then
                fnt = lastfont[attr]
                start.font = fnt
            end
        elseif char == 0 then
         -- print("removing",char)
         -- head, start = remove_node(head,start,true)
         -- return head, start and getprev(start) or head, true
        end
        if keepother and dc == char then
            if lastfont[attr] then
                start.font = lastfont[attr]
                return head, start, true
            else
                return head, start, false
            end
        else
            local ifc = fontchar[fnt]
            if type(dc) == "table" then
                local ok = true
                for i=1,#dc do
                    -- could be cached in font
                    if not ifc[dc[i]] then
                        ok = false
                        break
                    end
                end
                if ok then
                    -- todo: use generic injector
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
                    if once then
                        lastfont[attr] = nil
                    end
                    return head, prev, true
                end
                if once then
                    lastfont[attr] = nil
                end
                return head, start, false
            elseif ifc[dc] then
                start.char = dc
                if once then
                    lastfont[attr] = nil
                end
                return head, start, true
            end
        end
    end
    if once then
        lastfont[attr] = nil
    end
    return head, start, false
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

local function WORD(head,start,attr,lastfont)
    lastfont[attr] = nil
    return helper(head,start,attr,lastfont,uccodes)
end

local function word(head,start,attr,lastfont)
    lastfont[attr] = nil
    return helper(head,start,attr,lastfont,lccodes)
end

local function Word(head,start,attr,lastfont)
    lastfont[attr] = nil
    local prev = start.prev
    if prev and prev.id == kern_code and prev.subtype == kerning_code then
        prev = prev.prev
    end
    if not prev or prev.id ~= glyph_code then
        -- only the first character is treated
        for n in traverse_id(glyph_code,start.next) do
            if n[a_cases] == attr then
                n[a_cases] = unsetvalue
            else
             -- break -- we can have nested mess
            end
        end
        -- we could return the last in the range and save some scanning
        -- but why bother
        return helper(head,start,attr,lastfont,uccodes)
    else
        return head, start, false
    end
end

local function Words(head,start,attr,lastfont)
    lastfont[attr] = nil
    local prev = start.prev
    if prev and prev.id == kern_code and prev.subtype == kerning_code then
        prev = prev.prev
    end
    if not prev or prev.id ~= glyph_code then
        return helper(head,start,attr,lastfont,uccodes)
    else
        return head, start, false
    end
end

local function capital(head,start,attr,lastfont) -- 3
    return helper(head,start,attr,lastfont,uccodes,true,true)
end

local function Capital(head,start,attr,lastfont) -- 4
    return helper(head,start,attr,lastfont,uccodes,true,false)
end

local function mixed(head,start,attr,lastfont)
    return helper(head,start,attr,lastfont,uccodes,true,false,true)
end

local function none(head,start,attr,lastfont)
    return head, start, false
end

local function random(head,start,attr,lastfont)
    lastfont[attr] = nil
    local ch  = start.char
    local tfm = fontchar[start.font]
    if lccodes[ch] then
        while true do
            local d = chardata[randomnumber(1,0xFFFF)]
            if d then
                local uc = uccodes[d]
                if uc and tfm[uc] then -- this also intercepts tables
                    start.char = uc
                    return head, start, true
                end
            end
        end
    elseif uccodes[ch] then
        while true do
            local d = chardata[randomnumber(1,0xFFFF)]
            if d then
                local lc = lccodes[d]
                if lc and tfm[lc] then -- this also intercepts tables
                    start.char = lc
                    return head, start, true
                end
            end
        end
    end
    return head, start, false
end

register(variables.WORD,    WORD)              --  1
register(variables.word,    word)              --  2
register(variables.Word,    Word)              --  3
register(variables.Words,   Words)             --  4
register(variables.capital, capital)           --  5
register(variables.Capital, Capital)           --  6
register(variables.none,    none)              --  7 (dummy)
register(variables.random,  random)            --  8
register(variables.mixed,   mixed)             --  9

register(variables.cap,     variables.capital) -- clone
register(variables.Cap,     variables.Capital) -- clone

function cases.handler(head) -- not real fast but also not used on much data
    local lastfont = { }
    local lastattr = nil
    local done     = false
    local start    = head
    while start do -- while because start can jump ahead
        local id = start.id
        if id == glyph_code then
            local attr = start[a_cases]
            if attr and attr > 0 then
                if attr ~= lastattr then
                    lastattr = attr
                end
                start[a_cases] = unsetvalue
                local action = actions[attr%100] -- map back to low number
                if action then
                    head, start, ok = action(head,start,attr,lastfont)
                    if ok then
                        done = true
                    end
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
    texsetattribute(a_cases,n)
 -- return n -- bonus
end

-- interface

commands.setcharactercasing = cases.set
