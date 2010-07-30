if not modules then modules = { } end modules ['math-tag'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local has_attribute  = nodes.has_attribute
local set_attribute  = nodes.set_attribute
local set_attributes = nodes.set_attributes

local traverse_nodes = node.traverse

local math_noad      = node.id("noad")           -- attr nucleus sub sup
local math_noad      = node.id("noad")           -- attr nucleus sub sup
local math_accent    = node.id("accent")         -- attr nucleus sub sup accent
local math_radical   = node.id("radical")        -- attr nucleus sub sup left degree
local math_fraction  = node.id("fraction")       -- attr nucleus sub sup left right
local math_box       = node.id("sub_box")        -- attr list
local math_sub       = node.id("sub_mlist")      -- attr list
local math_char      = node.id("math_char")      -- attr fam char
local math_text_char = node.id("math_text_char") -- attr fam char
local math_delim     = node.id("delim")          -- attr small_fam small_char large_fam large_char
local math_style     = node.id("style")          -- attr style
local math_choice    = node.id("choice")         -- attr display text script scriptscript
local math_fence     = node.id("fence")          -- attr subtype

local hlist          = node.id("hlist")
local vlist          = node.id("vlist")
local glyph          = node.id("glyph")

local a_tagged = attributes.private('tagged')

local start_tagged = structure.tags.start
local stop_tagged  = structure.tags.stop
local chardata     = characters.data

local process

local function processsubsup(start)
    local nucleus, sup, sub = start.nucleus, start.sup, start.sub
    if sub then
        if sup then
            set_attribute(start,a_tagged,start_tagged("msubsup"))
            process(nucleus)
            process(sup)
            process(sub)
            stop_tagged()
        else
            set_attribute(start,a_tagged,start_tagged("msub"))
            process(nucleus)
            process(sub)
            stop_tagged()
        end
    elseif sup then
        set_attribute(start,a_tagged,start_tagged("msup"))
        process(nucleus)
        process(sup)
        stop_tagged()
    else
        process(nucleus)
    end
end

process = function(start) -- we cannot use the processor as we have no finalizers (yet)
    while start do
        local id = start.id
        if id == math_char then
            -- check for code
            local ch = chardata[start.char]
            local mc = ch and ch.mathclass
            if mc == "number" then
                set_attribute(start,a_tagged,start_tagged("mn"))
            elseif mc == "variable" or not mc then -- variable is default
                set_attribute(start,a_tagged,start_tagged("mi"))
            else
                set_attribute(start,a_tagged,start_tagged("mo"))
            end
            stop_tagged()
            break
        elseif id == math_text_char then
            -- check for code
            set_attribute(start,a_tagged,start_tagged("ms"))
            stop_tagged()
            break
        elseif id == math_delim then
            -- check for code
            set_attribute(start,a_tagged,start_tagged("mo"))
            stop_tagged()
            break
        elseif id == math_style then
            -- has a next
        elseif id == math_noad then
            processsubsup(start)
        elseif id == math_box or id == hlist or id == vlist then
            -- keep an eye on math_box and see what ends up in there
            local attr = has_attribute(start,a_tagged)
            local text = start_tagged("mtext")
            set_attribute(start,a_tagged,text)
            local list = start.list
            if not list then
                -- empty list
            elseif not attr then
                -- box comes from strange place
                set_attributes(list,a_tagged,text)
            else
                -- Beware, the first node in list is the actual list so we definitely
                -- need to nest. This approach is a hack, maybe I'll make a proper
                -- nesting feature to deal with this at another level. Here we just
                -- fake structure by enforcing the inner one.
                local taglist = structure.tags.taglist
                local tagdata = taglist[attr]
                local common = #tagdata + 1
                local function runner(list) -- quite inefficient
                    local cache = { } -- we can have nested unboxed mess so best local to runner
                    for n in traverse_nodes(list) do
                        local id = n.id
                        if id == hlist or id == vlist then
                            runner(n.list)
                        elseif id == glyph then
                            local aa = has_attribute(n,a_tagged) -- only glyph needed
                            if aa then
                                local ac = cache[aa]
                                if not ac then
                                    local tagdata = taglist[aa]
                                    local extra = #tagdata
                                    if common <= extra then
                                        for i=common,extra do
                                            ac = start_tagged(tagdata[i]) -- can be made faster
                                        end
                                        for i=common,extra do
                                            stop_tagged() -- can be made faster
                                        end
                                    else
                                        ac = text
                                    end
                                    cache[aa] = ac
                                end
                                set_attribute(n,a_tagged,ac)
                            else
                                set_attribute(n,a_tagged,text)
                            end
                        end
                    end
                end
                runner(list)
            end
            stop_tagged()
        elseif id == math_sub then
            local list = start.list
            if list then
                set_attribute(start,a_tagged,start_tagged("mrow"))
                process(list)
                stop_tagged()
            end
        elseif id == math_fraction then
            local num, denom, left, right = start.num, start.denom, start.left, start.right
            if left then
               set_attribute(left,a_tagged,start_tagged("mo"))
               process(left)
               stop_tagged()
            end
            set_attribute(start,a_tagged,start_tagged("mfrac"))
            process(num)
            process(denom)
            stop_tagged()
            if right then
                set_attribute(right,a_tagged,start_tagged("mo"))
                process(right)
                stop_tagged()
            end
        elseif id == math_choice then
            local display, text, script, scriptscript = start.display, start.text, start.script, start.scriptscript
            if display then
                process(display)
            end
            if text then
                process(text)
            end
            if script then
                process(script)
            end
            if scriptscript then
                process(scriptscript)
            end
        elseif id == math_fence then
            local delim = start.delim
            if delim then
                set_attribute(start,a_tagged,start_tagged("mo"))
                process(delim)
                stop_tagged()
            end
        elseif id == math_radical then
            local left, degree = start.left, start.degree
            if left then
                process(left) -- mrow needed ?
            end
            if degree then
                set_attribute(start,a_tagged,start_tagged("mroot"))
                processsubsup(start)
                process(degree)
                stop_tagged()
            else
                set_attribute(start,a_tagged,start_tagged("msqrt"))
                processsubsup(start)
                stop_tagged()
            end
        elseif id == math_accent then
            local accent, bot_accent = start.accent, start.bot_accent
            if bot_accent then
                if accent then
                    set_attribute(start,a_tagged,start_tagged("munderover"))
                    process(accent)
                    processsubsup(start)
                    process(bot_accent)
                    stop_tagged()
                else
                    set_attribute(start,a_tagged,start_tagged("munder"))
                    processsubsup(start)
                    process(bot_accent)
                    stop_tagged()
                end
            elseif accent then
                set_attribute(start,a_tagged,start_tagged("mover"))
                process(accent)
                processsubsup(start)
                stop_tagged()
            else
                processsubsup(start)
            end
        else
            set_attribute(start,a_tagged,start_tagged("merror"))
            stop_tagged()
        end
        start = start.next
    end
end

function noads.add_tags(head,style,penalties)
    set_attribute(head,a_tagged,start_tagged("math"))
    set_attribute(head,a_tagged,start_tagged("mrow"))
    process(head)
    stop_tagged()
    stop_tagged()
    return true
end
