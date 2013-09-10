if not modules then modules = { } end modules ['typo-dha'] = {
    version   = 1.001,
    comment   = "companion to typo-dir.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Some analysis by Idris:
--
-- 1. Assuming the reading- vs word-order distinction (bidi-char types) is governing;
-- 2. Assuming that 'ARAB' represents an actual arabic string in raw input order, not word-order;
-- 3. Assuming that 'BARA' represent the correct RL word order;
--
-- Then we have, with input: LATIN ARAB
--
-- \textdir TLT LATIN ARAB => LATIN BARA
-- \textdir TRT LATIN ARAB => LATIN BARA
-- \textdir TRT LRO LATIN ARAB => LATIN ARAB
-- \textdir TLT LRO LATIN ARAB => LATIN ARAB
-- \textdir TLT RLO LATIN ARAB => NITAL ARAB
-- \textdir TRT RLO LATIN ARAB => NITAL ARAB

-- elseif d == "es"  then -- European Number Separator
-- elseif d == "et"  then -- European Number Terminator
-- elseif d == "cs"  then -- Common Number Separator
-- elseif d == "nsm" then -- Non-Spacing Mark
-- elseif d == "bn"  then -- Boundary Neutral
-- elseif d == "b"   then -- Paragraph Separator
-- elseif d == "s"   then -- Segment Separator
-- elseif d == "ws"  then -- Whitespace
-- elseif d == "on"  then -- Other Neutrals

-- todo  : delayed inserts here
-- todo  : get rid of local functions here
-- beware: math adds whatsits afterwards so that will mess things up
-- todo  : use new dir functions
-- todo  : make faster
-- todo  : move dir info into nodes
-- todo  : swappable tables and floats i.e. start-end overloads (probably loop in builders)
-- todo  : check if we still have crashes in luatex when non-matched (used to be the case)

local nodes, node = nodes, node

local trace_directions   = false  trackers.register("typesetters.directions.default", function(v) trace_directions = v end)

local report_directions  = logs.reporter("typesetting","text directions")

local hasbit             = number.hasbit
local formatters         = string.formatters
local insert             = table.insert

local insert_node_before = nodes.insert_before
local insert_node_after  = nodes.insert_after
local remove_node        = nodes.remove
local end_of_math        = nodes.end_of_math

local nodecodes          = nodes.nodecodes
local whatcodes          = nodes.whatcodes
local mathcodes          = nodes.mathcodes

local glyph_code         = nodecodes.glyph
local whatsit_code       = nodecodes.whatsit
local math_code          = nodecodes.math
local penalty_code       = nodecodes.penalty
local kern_code          = nodecodes.kern
local glue_code          = nodecodes.glue
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local localpar_code      = whatcodes.localpar
local dir_code           = whatcodes.dir

local nodepool           = nodes.pool

local new_textdir        = nodepool.textdir

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local fontchar           = fonthashes.characters

local chardirections     = characters.directions
local charmirrors        = characters.mirrors
local charclasses        = characters.textclasses

local directions         = typesetters.directions
local getglobal          = directions.getglobal

local a_state            = attributes.private('state')
local a_directions       = attributes.private('directions')

local strip              = false

local s_isol             = fonts.analyzers.states.isol

local function process(namespace,attribute,start)

    local head = start

    local current, inserted = head, nil
    local finish, autodir, embedded, override, done = nil, 0, 0, 0, false
    local list, glyphs = trace_directions and { }, false
    local finished, finidir, finipos = nil, nil, 1
    local stack, top, obsolete = { }, 0, { }
    local lro, rlo, prevattr = false, false, 0
    local fences = { }

    local function finish_auto_before()
        local fdir = finish == "TRT" and "-TRT" or "-TLT"
        head, inserted = insert_node_before(head,current,new_textdir(fdir))
        finished, finidir, autodir = inserted, finish, 0
        if trace_directions then
            insert(list,#list,formatters["auto %a inserted before, autodir %a, embedded %a"](fdir,autodir,embedded))
            finipos = #list - 1
        end
        finish, done = nil, true
    end

    local function finish_auto_after()
        local fdir = finish == "TRT" and "-TRT" or "-TLT"
        head, current = insert_node_after(head,current,new_textdir(fdir))
        finished, finidir, autodir = current, finish, 0
        if trace_directions then
            list[#list+1] = formatters["auto %a inserted after, autodir %a, embedded %a"](fdir,autodir,embedded)
            finipos = #list
        end
        finish, done = nil, true
    end

    local function force_auto_left_before(d)
        if finish then
            finish_auto_before()
        end
        if embedded >= 0 then
            finish, autodir = "TLT",  1
        else
            finish, autodir = "TRT", -1
        end
        done = true
        if finidir == finish then
            head = remove_node(head,finished,true)
            if trace_directions then
                list[finipos] = list[finipos] .. ", deleted afterwards"
                insert(list,#list,formatters["start text dir %a, auto left before, embedded %a, autodir %a, triggered by class %a"](finish,embedded,autodir,d))
            end
        else
            head, inserted = insert_node_before(head,current,new_textdir("+"..finish))
            if trace_directions then
                insert(list,#list,formatters["start text dir %a, auto left before, embedded %a, autodir %a, triggered by class %a"](finish,embedded,autodir,d))
            end
        end
    end

    local function force_auto_right_before(d)
        if finish then
            finish_auto_before()
        end
        if embedded <= 0 then
            finish, autodir, done = "TRT", -1
        else
            finish, autodir, done = "TLT",  1
        end
        done = true
        if finidir == finish then
            head = remove_node(head,finished,true)
            if trace_directions then
                list[finipos] = list[finipos] .. ", deleted afterwards"
                insert(list,#list,formatters["start text dir %a, auto right before, embedded %a, autodir %a, triggered by class %a"](finish,embedded,autodir,d))
            end
        else
            head, inserted = insert_node_before(head,current,new_textdir("+"..finish))
            if trace_directions then
                insert(list,#list,formatters["start text dir %a, auto right before, embedded %a, autodir %a, triggered by class %a"](finish,embedded,autodir,d))
            end
        end
    end

    local function nextisright(current)
     -- repeat
            current = current.next
            local id = current.id
            if id == glyph_code then
                local char = current.char
                local d = chardirections[char]
                return d == "r" or d == "al" or d == "an"
         -- elseif id == glue_code or id == kern_code or id == penalty_code then
         --   -- too complex and doesn't cover bounds anyway
     --     else
     --         return
            end
     -- until not current
    end

    local function previsright(current)
     -- repeat
            current = current.prev
            local id = current.id
            if id == glyph_code then
                local char = current.char
                local d = chardirections[char]
                return d == "r" or d == "al" or d == "an"
         -- elseif id == glue_code or id == kern_code or id == penalty_code then
         --   -- too complex and doesn't cover bounds anyway
     --     else
     --         return
            end
     -- until not current
    end

    while current do
        local id = current.id
     -- list[#list+1] = formatters["state: node %a, finish %a, autodir %a, embedded %a"](nutstring(current),finish or "unset",autodir,embedded)
        if id == math_code then
            current = end_of_math(current.next).next
        else
            local attr = current[attribute]
            if attr and attr > 0 and attr ~= prevattr then
                if getglobal(a) then
                    -- bidi parsing mode
                else
                    -- local
                    if trace_directions and
                        current ~= head then list[#list+1] = formatters["override reset, bidi %a"](attr)
                    end
                    lro, rlo = false, false
                end
                prevattr = attr
            end
         -- if attr and attr > 0 then
         --     if attr == 1 then
         --         -- bidi parsing mode
         --     elseif attr ~= prevattr then
         --         -- no pop, grouped driven (2=normal,3=lro,4=rlo)
         --         if attr == 3 then
         --             if trace_directions then
         --                 list[#list+1] = formatters["override right -> left (lro), bidi %a"](attr)
         --             end
         --             lro, rlo = true, false
         --         elseif attr == 4 then
         --             if trace_directions then
         --                 list[#list+1] = formatters["override left -> right (rlo), bidi %a"](attr)
         --             end
         --             lro, rlo = false, true
         --         else
         --             if trace_directions and
         --                 current ~= head then list[#list+1] = formatters["override reset, bidi %a"](attr)
         --             end
         --             lro, rlo = false, false
         --         end
         --         prevattr = attr
         --     end
         -- end
            if id == glyph_code then
                glyphs = true
                if attr and attr > 0 then
                    local char = current.char
                    local d = chardirections[char]
                    if rlo or override > 0 then
                        if d == "l" then
                            if trace_directions then
                                list[#list+1] = formatters["char %C of class %a overridden to r, bidi %a)"](char,d,attr)
                            end
                            d = "r"
                        elseif trace_directions then
                            if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                                list[#list+1] = formatters["override char of class %a, bidi %a"](d,attr)
                            else -- todo: rle lre
                                list[#list+1] = formatters["char %C of class %a, bidi %a"](char,d,attr)
                            end
                        end
                    elseif lro or override < 0 then
                        if d == "r" or d == "al" then
                            current[a_state] = s_isol -- maybe better have a special bidi attr value -> override (9) -> todo
                            if trace_directions then
                                list[#list+1] = formatters["char %C of class %a overridden to l, bidi %a, state 'isol'"](char,d,attr)
                            end
                            d = "l"
                        elseif trace_directions then
                            if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                                list[#list+1] = formatters["override char of class %a, bidi %a"](d,attr)
                            else -- todo: rle lre
                                list[#list+1] = formatters["char %C of class %a, bidi %a"](char,d,attr)
                            end
                        end
                    elseif trace_directions then
                        if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                            list[#list+1] = formatters["override char of class %a, bidi %a"](d,attr)
                        else -- todo: rle lre
                            list[#list+1] = formatters["char %C of class %a, bidi %a"](char,d,attr)
                        end
                    end
                    if d == "on" then
                        local mirror = charmirrors[char]
                        if mirror and fontchar[current.font][mirror] then
                            -- for the moment simple stacking
                            local class = charclasses[char]
                            if class == "open" then
                                fences[#fences+1] = autodir
                                if nextisright(current) then
                                    if autodir >= 0 then
                                        force_auto_right_before(d)
                                    end
                                    current.char = mirror
                                    done = true
                                else
                                    mirror = nil
                                    if autodir <= 0 then
                                        force_auto_left_before(d)
                                    end
                                end
                            elseif class == "close" and #fences > 0 then
                                local prevdir = fences[#fences]
                                fences[#fences] = nil
                                if prevdir < 0 then
                                    current.char = mirror
                                    done = true
                                    if autodir >= 0 then
                                        -- a bit tricky but ok for simple cases
                                        force_auto_right_before(d)
                                    end
                                else
                                    mirror = nil
                                end
                            elseif autodir < 0 then
                                current.char = mirror
                                done = true
                            else
                                mirror = nil
                            end
                            if trace_directions then
                                if mirror then
                                    list[#list+1] = formatters["mirroring char %C of class %a to %C, autodir %a, bidi %a"](char,d,mirror,autodir,attr)
                                else
                                    list[#list+1] = formatters["not mirroring char %C of class %a, autodir %a, bidi %a"](char,d,autodir,attr)
                                end
                            end
                        end
                    elseif d == "l" or d == "en" then -- european number
                        if autodir <= 0 then -- could be option
                            force_auto_left_before(d)
                        end
                    elseif d == "r" or d == "al" then -- arabic number
                        if autodir >= 0 then
                            force_auto_right_before(d)
                        end
                    elseif d == "an" then -- arabic number
                        -- actually this is language dependent ...
                     -- if autodir <= 0 then
                     --     force_auto_left_before(d)
                     -- end
                        if autodir >= 0 then
                            force_auto_right_before(d)
                        end
                    elseif d == "lro" then -- Left-to-Right Override -> right becomes left
                        if trace_directions then
                            list[#list+1] = "override right -> left"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        override = -1
                        obsolete[#obsolete+1] = current
                    elseif d == "rlo" then -- Right-to-Left Override -> left becomes right
                        if trace_directions then
                            list[#list+1] = "override left -> right"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        override = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "lre" then -- Left-to-Right Embedding -> TLT
                        if trace_directions then
                            list[#list+1] = "embedding left -> right"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        embedded = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "rle" then -- Right-to-Left Embedding -> TRT
                        if trace_directions then
                            list[#list+1] = "embedding right -> left"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        embedded = -1 -- was 1
                        obsolete[#obsolete+1] = current
                    elseif d == "pdf" then -- Pop Directional Format
                     -- override = 0
                        if top > 0 then
                            local s = stack[top]
                            override, embedded = s[1], s[2]
                            top = top - 1
                            if trace_directions then
                                list[#list+1] = formatters["state: override %a, embedded %a, autodir %a"](override,embedded,autodir)
                            end
                        else
                            if trace_directions then
                                list[#list+1] = "pop error: too many pops"
                            end
                        end
                        obsolete[#obsolete+1] = current
                    end
                elseif trace_directions then
                    local char = current.char
                    local d = chardirections[char]
                    list[#list+1] = formatters["char %C of class %a, bidi %a"](char,d or "?")
                end
            elseif id == whatsit_code then
                -- we have less directions now so we can do hard checks for strings instead of splitting into pieces
                if finish then
                    finish_auto_before()
                end
                local subtype = current.subtype
                if subtype == localpar_code then
                 -- if false then
                        local dir = current.dir
                        if dir == 'TRT' then
                            autodir = -1
                        elseif dir == 'TLT' then
                            autodir = 1
                        end
                    -- embedded = autodir
                        if trace_directions then
                            list[#list+1] = formatters["pardir %a"](dir)
                        end
                 -- end
                elseif subtype == dir_code then
                    local dir = current.dir
                    if dir == "+TRT" then
                        finish, autodir = "TRT", -1
                    elseif dir == "-TRT" then
                        finish, autodir = nil, 0
                    elseif dir == "+TLT" then
                        finish, autodir = "TLT", 1
                    elseif dir == "-TLT" then
                        finish, autodir = nil, 0
                    end
                    if trace_directions then
                        list[#list+1] = formatters["textdir %a, autodir %a"](dir,autodir)
                    end
                end
            else
                if trace_directions then
                    list[#list+1] = formatters["node %a, subtype %a"](nodecodes[id],current.subtype)
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

    if trace_directions and glyphs then
        report_directions("start log")
        for i=1,#list do
            report_directions("%02i: %s",i,list[i])
        end
        report_directions("stop log")
    end

    if done and strip then
        local n = #obsolete
        if n > 0 then
            for i=1,n do
                remove_node(head,obsolete[i],true)
            end
            report_directions("%s character nodes removed",n)
        end
    end

    return head, done

end

directions.installhandler(interfaces.variables.default,process)

