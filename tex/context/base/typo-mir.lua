if not modules then modules = { } end modules ['typo-mir'] = {
    version   = 1.001,
    comment   = "companion to typo-mir.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local next, type = next, type
local format, insert = string.format, table.insert
local utfchar = utf.char

-- vertical space handler

local trace_mirroring     = false  trackers.register("nodes.mirroring",     function(v) trace_mirroring     = v end)

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local set_attribute      = node.set_attribute
local traverse_id        = node.traverse_id
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove

local glyph   = node.id("glyph")
local whatsit = node.id("whatsit")
local mthnode = node.id('math')

local fontdata = fonts.ids
local chardata = characters.data

--~ Analysis by Idris:
--~
--~ 1. Assuming the reading- vs word-order distinction (bidi-char types) is governing;
--~ 2. Assuming that 'ARAB' represents an actual arabic string in raw input order, not word-order;
--~ 3. Assuming that 'BARA' represent the correct RL word order;
--~
--~ Then we have, with input: LATIN ARAB
--~
--~ \textdir TLT LATIN ARAB => LATIN BARA
--~ \textdir TRT LATIN ARAB => LATIN BARA
--~ \textdir TRT LRO LATIN ARAB => LATIN ARAB
--~ \textdir TLT LRO LATIN ARAB => LATIN ARAB
--~ \textdir TLT RLO LATIN ARAB => NITAL ARAB
--~ \textdir TRT RLO LATIN ARAB => NITAL ARAB

--  elseif d == "es"  then -- European Number Separator
--  elseif d == "et"  then -- European Number Terminator
--  elseif d == "cs"  then -- Common Number Separator
--  elseif d == "nsm" then -- Non-Spacing Mark
--  elseif d == "bn"  then -- Boundary Neutral
--  elseif d == "b"   then -- Paragraph Separator
--  elseif d == "s"   then -- Segment Separator
--  elseif d == "ws"  then -- Whitespace
--  elseif d == "on"  then -- Other Neutrals

mirror         = mirror or { }
mirror.enabled = false
mirror.strip   = false

local state   = attributes.private('state')
local mirrora = attributes.private('mirror')

local directions = characters.directions -- maybe make a special mirror table

-- todo: delayed inserts here
-- todo: get rid of local functions here

-- beware, math adds whatsits afterwards so that will mess things up

local skipmath = true

local finish, autodir, embedded, override, done = nil, 0, 0, 0, false
local list, glyphs = nil, false
local finished, finidir, finipos = nil, nil, 1
local head, current, inserted = nil, nil, nil

local function finish_auto_before()
    head, inserted = insert_node_before(head,current,nodes.textdir("-"..finish))
    finished, finidir = inserted, finish
    if trace_mirroring then
        insert(list,#list,format("finish %s",finish))
        finipos = #list-1
    end
    finish, autodir, done = nil, 0, true
end

local function finish_auto_after()
    head, current = insert_node_after(head,current,nodes.textdir("-"..finish))
    finished, finidir = current, finish
    if trace_mirroring then
        list[#list+1] = format("finish %s",finish)
        finipos = #list
    end
    finish, autodir, done = nil, 0, true
end

local function force_auto_left_before()
    if finish then
        finish_auto_before()
    end
    if embedded >= 0 then
        finish, autodir, done = "TLT", 1, true
    else
        finish, autodir, done = "TRT", -1, true
    end
    if finidir == finish then
        remove_node(head,finished,true)
        if trace_mirroring then
            list[finipos] = list[finipos].." (deleted)"
            insert(list,#list,format("start %s (deleted)",finish))
        end
    else
        head, inserted = insert_node_before(head,current,nodes.textdir("+"..finish))
        if trace_mirroring then
            insert(list,#list,format("start %s",finish))
        end
    end
end

local function force_auto_right_before()
    if finish then
        finish_auto_before()
    end
    if embedded <= 0 then
        finish, autodir, done = "TRT", -1, true
    else
        finish, autodir, done = "TLT", 1, true
    end
    if finidir == finish then
        remove_node(head,finished,true)
        if trace_mirroring then
            list[finipos] = list[finipos].." (deleted)"
            insert(list,#list,format("start %s (deleted)",finish))
        end
    else
        head, inserted = insert_node_before(head,current,nodes.textdir("+"..finish))
        if trace_mirroring then
            insert(list,#list,format("start %s",finish))
        end
    end
end

function mirror.process(namespace,attribute,start) -- todo: make faster
    if not start.next then
        return start, false
    end
    head, current, inserted = start, start, nil
    finish, autodir, embedded, override, done = nil, 0, 0, 0, false
    list, glyphs = trace_mirroring and { }, false
    finished, finidir, finipos = nil, nil, 1
    local stack, top, obsolete = { }, 0, { }
    local lro, rlo, prevattr, inmath = false, false, 0, false
    while current do
        local id = current.id
        if skipmath and id == mthnode then
            local subtype = current.subtype
            if subtype == 0 then
                -- begin math
                inmath = true
            elseif subtype == 1 then
                inmath = false
            else
                -- todo
            end
            current = current.next
        elseif inmath then
            current = current.next
        else
            local attr = has_attribute(current,attribute)
            if attr and attr > 0 then
                unset_attribute(current,attribute) -- slow, needed?
            --~ set_attribute(current,attribute,0) -- might be faster
                if attr == 1 then
                    -- bidi parsing mode
                elseif attr ~= prevattr then
                    -- no pop, grouped driven (2=normal,3=lro,4=rlo)
                    if attr == 3 then
                        if trace_mirroring then
                            list[#list+1] = format("override right -> left (lro) (bidi=%s)",attr)
                        end
                        lro, rlo = true, false
                    elseif attr == 4 then
                        if trace_mirroring then
                            list[#list+1] = format("override left -> right (rlo) (bidi=%s)",attr)
                        end
                        lro, rlo = false, true
                    else
                        if trace_mirroring and
                            current ~= head then list[#list+1] = format("override reset (bidi=%s)",attr)
                        end
                        lro, rlo = false, false
                    end
                    prevattr = attr
                end
            end
            if id == glyph then
                glyphs = true
                if attr and attr > 0 then
                    local char = current.char
                    local d = directions[char]
                    if rlo or override > 0 then
                        if d == "l" then
                            if trace_mirroring then
                                list[#list+1] = format("char %s (%s / U+%04X) of class %s overidden to r (bidi=%s)",utfchar(char),char,char,d,attr)
                            end
                            d = "r"
                        elseif trace_mirroring then
                            if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                                list[#list+1] = format("override char of class %s (bidi=%s)",d,attr)
                            else -- todo: rle lre
                                list[#list+1] = format("char %s (%s / U+%04X) of class %s (bidi=%s)",utfchar(char),char,char,d,attr)
                            end
                        end
                    elseif lro or override < 0 then
                        if d == "r" or d == "al" then
                            set_attribute(current,state,4) -- maybe better have a special bidi attr value -> override (9) -> todo
                            if trace_mirroring then
                                list[#list+1] = format("char %s (%s / U+%04X) of class %s overidden to l (bidi=%s) (state=isol)",utfchar(char),char,char,d,attr)
                            end
                            d = "l"
                        elseif trace_mirroring then
                            if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                                list[#list+1] = format("override char of class %s (bidi=%s)",d,attr)
                            else -- todo: rle lre
                                list[#list+1] = format("char %s (%s / U+%04X) of class %s (bidi=%s)",utfchar(char),char,char,d,attr)
                            end
                        end
                    elseif trace_mirroring then
                        if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                            list[#list+1] = format("override char of class %s (bidi=%s)",d,attr)
                        else -- todo: rle lre
                            list[#list+1] = format("char %s (%s / U+%04X) of class %s (bidi=%s)",utfchar(char),char,char,d,attr)
                        end
                    end
                    if d == "on" then
                        local mirror = chardata[char].mirror -- maybe make a special mirror table
                        if mirror and fontdata[current.font].characters[mirror] then
                            -- todo: set attribute
                            if autodir < 0 then
                                current.char = mirror
                                done = true
                            --~ elseif left or autodir > 0 then
                            --~     if not is_right(current.prev) then
                            --~         current.char = mirror
                            --~         done = true
                            --~     end
                            end
                        end
                    elseif d == "l" or d == "en" then -- european number
                        if autodir <= 0 then
                            force_auto_left_before()
                        end
                    elseif d == "r" or d == "al" or d == "an" then -- arabic left, arabic number
                        if autodir >= 0 then
                            force_auto_right_before()
                        end
                    elseif d == "lro" then -- Left-to-Right Override -> right becomes left
                        if trace_mirroring then
                            list[#list+1] = "override right -> left"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        override = -1
                        obsolete[#obsolete+1] = current
                    elseif d == "rlo" then -- Right-to-Left Override -> left becomes right
                        if trace_mirroring then
                            list[#list+1] = "override left -> right"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        override = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "lre" then -- Left-to-Right Embedding -> TLT
                        if trace_mirroring then
                            list[#list+1] = "embedding left -> right"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        embedded = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "rle" then -- Right-to-Left Embedding -> TRT
                        if trace_mirroring then
                            list[#list+1] = "embedding right -> left"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        embedded = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "pdf" then -- Pop Directional Format
                    --  override = 0
                        if top > 0 then
                            local s = stack[top]
                            override, embedded = s[1], s[2]
                            top = top - 1
                            if trace_mirroring then
                                list[#list+1] = format("state: override: %s, embedded: %s, autodir: %s",override,embedded,autodir)
                            end
                        else
                            if trace_mirroring then
                                list[#list+1] = "pop (error, too many pops)"
                            end
                        end
                        obsolete[#obsolete+1] = current
                    end
                else
                    if trace_mirroring then
                        local char = current.char
                        local d = directions[char]
                        list[#list+1] = format("char %s (%s / U+%04X) of class %s (no bidi)",utfchar(char),char,char,d)
                    end
                end
            elseif id == whatsit then
                if finish then
                    finish_auto_before()
                end
                local subtype = current.subtype
                if subtype == 6 then
                    local dir = current.dir
                    local d = dir:sub(2,2)
                    if dir:find(".R.") then
                        autodir = -1
                    else
                        autodir = 1
                    end
                    embeddded = autodir
                    if trace_mirroring then
                        list[#list+1] = format("pardir %s",dir)
                    end
                elseif subtype == 7 then
                    local dir = current.dir
                    local sign = dir:sub(1,1)
                    local dire = dir:sub(3,3)
                    if dire == "R" then
                        if sign == "+" then
                            finish, autodir = "TRT", -1
                        else
                            finish, autodir = nil, 0
                        end
                    else
                        if sign == "+" then
                            finish, autodir = "TLT", 1
                        else
                            finish, autodir = nil, 0
                        end
                    end
                    if trace_mirroring then
                        list[#list+1] = format("textdir %s",dir)
                    end
                end
            else
                if trace_mirroring then
                    list[#list+1] = format("node %s (subtype %s)",node.type(id),current.subtype)
                end
                if finish then
                    finish_auto_before()
                end
            end
            local cn = current.next
            if not cn then
                if finish then
                    finish_auto_after()
                end
            end
            current = cn
        end
    end
    if trace_mirroring and glyphs then
        logs.report("bidi","start log")
        for i=1,#list do
            logs.report("bidi","%02i: %s",i,list[i])
        end
        logs.report("bidi","stop log")
    end
    if done and mirror.strip then
        local n = #obsolete
        if n > 0 then
            for i=1,n do
                remove_node(head,obsolete[i],true)
            end
            logs.report("bidi","%s character nodes removed",n)
        end
    end
    return head, done
end

--~         local function is_right(n) -- keep !
--~             if n then
--~                 local id = n.id
--~                 if id == glyph then
--~                     local attr = has_attribute(n,attribute)
--~                     if attr and attr > 0 then
--~                         local d = directions[n.char]
--~                         if d == "r" or d == "al" then -- override
--~                             return true
--~                         end
--~                     end
--~                 end
--~             end
--~             return false
--~         end

chars.handle_mirroring = nodes.install_attribute_handler {
    name = "mirror",
    namespace = mirror,
    processor = mirror.process,
}
