if not modules then modules = { } end modules ['typo-dir'] = {
    version   = 1.001,
    comment   = "companion to typo-dir.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- When we started with this, there were some issues in luatex so we needed to take care of
-- intereferences. Some has been improved but we stil might end up with each node having a
-- dir property. Now, the biggest problem is that there is an official bidi algorithm but
-- some searching on the web shows that there are many confusing aspects and therefore
-- proposals circulate about (sometimes imcompatible ?) improvements. In the end it all boils
-- down to the lack of willingness to tag an input source. Of course tagging of each number
-- and fenced strip is somewhat over the top, but now it has to be captured in logic. Texies
-- normally have no problem with tagging but we need to handle any input. So, what we have
-- done here (over the years) is starting from what we expect to see happen, especially with
-- respect to punctation, numbers and fences. Eventually alternative algorithms will be provides
-- so that users can choose (the reason why suggestion sfor improvements circulate on the web
-- is that it is non trivial to predict the expected behaviour so one hopes that the ditor
-- and the rest of the machinery match somehow. Anyway, the fun of tex is that it has no hard
-- coded behavior. And ... we also want to have more debugging and extras and ... so we want
-- a flexible approach. In the end we will have:
--
-- = full tagging (mechanism turned off)
-- = half tagging (the current implementation)
-- = unicode version x interpretation (several depending on the evolution)

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
-- todo  : also use end_of_math here?
-- todo  : use lpeg instead of match
-- todo  : move dir info into nodes
-- todo  : swappable tables and floats i.e. start-end overloads (probably loop in builders)
-- todo  : check if we still have crashes in luatex when non-matched (used to be the case)
-- todo  : look into the (new) unicode logic (non intuitive stuff)

local next, type = next, type
local format, insert, sub, find, match = string.format, table.insert, string.sub, string.find, string.match
local utfchar = utf.char
local formatters = string.formatters

local nodes, node = nodes, node

local trace_textdirections = false  trackers.register("typesetters.directions.text", function(v) trace_textdirections = v end)
local trace_mathdirections = false  trackers.register("typesetters.directions.math", function(v) trace_mathdirections = v end)
local trace_directions     = false  trackers.register("typesetters.directions",      function(v) trace_textdirections = v trace_mathdirections = v end)

local report_textdirections = logs.reporter("typesetting","text directions")
local report_mathdirections = logs.reporter("typesetting","math directions")


local traverse_id        = node.traverse_id
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove
local end_of_math        = nodes.end_of_math

local texsetattribute    = tex.setattribute
local texsetcount        = tex.setcount
local unsetvalue         = attributes.unsetvalue

local nodecodes          = nodes.nodecodes
local whatcodes          = nodes.whatcodes
local mathcodes          = nodes.mathcodes

local tasks              = nodes.tasks

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

local directions         = typesetters.directions or { }
typesetters.directions   = directions

local a_state            = attributes.private('state')
local a_directions       = attributes.private('directions')
local a_mathbidi         = attributes.private('mathbidi')

local strip              = false

local s_isol             = fonts.analyzers.states.isol

local variables          = interfaces.variables
local v_global           = variables["global"]
local v_local            = variables["local"]
local v_on               = variables.on
local v_yes              = variables.yes

local m_enabled          = 2^6 -- 64
local m_global           = 2^7
local m_fences           = 2^8

local handlers           = { }
local methods            = { }
local lastmethod         = 0

local function installhandler(name,handler)
    local method = methods[name]
    if not method then
        lastmethod    = lastmethod + 1
        method        = lastmethod
        methods[name] = method
    end
    handlers[method] = handler
    return method
end

directions.handlers       = handlers
directions.installhandler = installhandler

local function tomode(specification)
    local scope = specification.scope
    local mode
    if scope == v_global or scope == v_on then
        mode = m_enabled + m_global
    elseif scope == v_local then
        mode = m_enabled
    else
        return 0
    end
    local method = methods[specification.method]
    if method then
        mode = mode + method
    else
        return 0
    end
    if specification.fences == v_yes then
        mode = mode + m_fences
    end
    return mode
end

local function getglobal(a)
    return a and a > 0 and hasbit(a,m_global)
end

local function getfences(a)
    return a and a > 0 and hasbit(a,m_fences)
end

local function getmethod(a)
    return a and a > 0 and a % m_enabled or 0
end

directions.tomode         = tomode
directions.getscope       = getscope
directions.getfences      = getfences
directions.getmethod      = getmethod
directions.installhandler = installhandler

function commands.getbidimode(specification)
    context(tomode(specification)) -- hash at tex end
end

local function process_direct(namespace,attribute,start)

    local head = start 

    local current, inserted = head, nil
    local finish, autodir, embedded, override, done = nil, 0, 0, 0, false
    local list, glyphs = trace_textdirections and { }, false
    local finished, finidir, finipos = nil, nil, 1
    local stack, top, obsolete = { }, 0, { }
    local lro, rlo, prevattr = false, false, 0

    local function finish_auto_before()
        local fdir = finish == "TRT" and "-TRT" or "-TLT"
        head, inserted = insert_node_before(head,current,new_textdir(fdir))
        finished, finidir, autodir = inserted, finish, 0
        if trace_textdirections then
            insert(list,#list,formatters["auto %a inserted before, autodir %a, embedded %a"](fdir,autodir,embedded))
            finipos = #list - 1
        end
        finish, done = nil, true
    end

    local function finish_auto_after()
        local fdir = finish == "TRT" and "-TRT" or "-TLT"
        head, current = insert_node_after(head,current,new_textdir(fdir))
        finished, finidir, autodir = current, finish, 0
        if trace_textdirections then
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
            if trace_textdirections then
                list[finipos] = list[finipos] .. ", deleted afterwards"
                insert(list,#list,formatters["start text dir %a, auto left before, embedded %a, autodir %a, triggered by class %a"](finish,embedded,autodir,d))
            end
        else
            head, inserted = insert_node_before(head,current,new_textdir("+"..finish))
            if trace_textdirections then
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
            if trace_textdirections then
                list[finipos] = list[finipos] .. ", deleted afterwards"
                insert(list,#list,formatters["start text dir %a, auto right before, embedded %a, autodir %a, triggered by class %a"](finish,embedded,autodir,d))
            end
        else
            head, inserted = insert_node_before(head,current,new_textdir("+"..finish))
            if trace_textdirections then
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
         --   -- too complex
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
         --     -- too complex
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
            if attr and attr > 0 then
             -- current[attribute] = unsetvalue -- slow, needed?
                if attr == 1 then
                    -- bidi parsing mode
                elseif attr ~= prevattr then
                    -- no pop, grouped driven (2=normal,3=lro,4=rlo)
                    if attr == 3 then
                        if trace_textdirections then
                            list[#list+1] = formatters["override right -> left (lro), bidi %a"](attr)
                        end
                        lro, rlo = true, false
                    elseif attr == 4 then
                        if trace_textdirections then
                            list[#list+1] = formatters["override left -> right (rlo), bidi %a"](attr)
                        end
                        lro, rlo = false, true
                    else
                        if trace_textdirections and
                            current ~= head then list[#list+1] = formatters["override reset, bidi %a"](attr)
                        end
                        lro, rlo = false, false
                    end
                    prevattr = attr
                end
            end
            if id == glyph_code then
                glyphs = true
                if attr and attr > 0 then
                    local char = current.char
                    local d = chardirections[char]
                    if rlo or override > 0 then
                        if d == "l" then
                            if trace_textdirections then
                                list[#list+1] = formatters["char %C of class %a overridden to r, bidi %a)"](char,d,attr)
                            end
                            d = "r"
                        elseif trace_textdirections then
                            if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                                list[#list+1] = formatters["override char of class %a, bidi %a"](d,attr)
                            else -- todo: rle lre
                                list[#list+1] = formatters["char %C of class %a, bidi %a"](char,d,attr)
                            end
                        end
                    elseif lro or override < 0 then
                        if d == "r" or d == "al" then
                            current[a_state] = s_isol -- maybe better have a special bidi attr value -> override (9) -> todo
                            if trace_textdirections then
                                list[#list+1] = formatters["char %C of class %a overridden to l, bidi %a, state 'isol'"](char,d,attr)
                            end
                            d = "l"
                        elseif trace_textdirections then
                            if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                                list[#list+1] = formatters["override char of class %a, bidi %a"](d,attr)
                            else -- todo: rle lre
                                list[#list+1] = formatters["char %C of class %a, bidi %a"](char,d,attr)
                            end
                        end
                    elseif trace_textdirections then
                        if d == "lro" or d == "rlo" or d == "pdf" then -- else side effects on terminal
                            list[#list+1] = formatters["override char of class %a, bidi %a"](d,attr)
                        else -- todo: rle lre
                            list[#list+1] = formatters["char %C of class %a, bidi %a"](char,d,attr)
                        end
                    end
                    if d == "on" then
                        local mirror = charmirrors[char]
                        if mirror and fontchar[current.font][mirror] then
                            -- todo: set attribute
                            local class = charclasses[char]
                            if class == "open" then
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
                            elseif class == "close" then
                                if previsright(current) then
                                    current.char = mirror
                                    done = true
                                else
                                    mirror = nil
                                end
                            elseif autodir < 0 then
                                current.char = mirror
                                done = true
                            else
                                mirror = nil
                            end
                            if trace_textdirections then
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
                        if trace_textdirections then
                            list[#list+1] = "override right -> left"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        override = -1
                        obsolete[#obsolete+1] = current
                    elseif d == "rlo" then -- Right-to-Left Override -> left becomes right
                        if trace_textdirections then
                            list[#list+1] = "override left -> right"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        override = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "lre" then -- Left-to-Right Embedding -> TLT
                        if trace_textdirections then
                            list[#list+1] = "embedding left -> right"
                        end
                        top = top + 1
                        stack[top] = { override, embedded }
                        embedded = 1
                        obsolete[#obsolete+1] = current
                    elseif d == "rle" then -- Right-to-Left Embedding -> TRT
                        if trace_textdirections then
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
                            if trace_textdirections then
                                list[#list+1] = formatters["state: override %a, embedded %a, autodir %a"](override,embedded,autodir)
                            end
                        else
                            if trace_textdirections then
                                list[#list+1] = "pop error: too many pops"
                            end
                        end
                        obsolete[#obsolete+1] = current
                    end
                elseif trace_textdirections then
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
                        if trace_textdirections then
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
                    if trace_textdirections then
                        list[#list+1] = formatters["textdir %a, autodir %a"](dir,autodir)
                    end
                end
            else
                if trace_textdirections then
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

    if trace_textdirections and glyphs then
        report_textdirections("start log")
        for i=1,#list do
            report_textdirections("%02i: %s",i,list[i])
        end
        report_textdirections("stop log")
    end

    if done and strip then
        local n = #obsolete
        if n > 0 then
            for i=1,n do
                remove_node(head,obsolete[i],true)
            end
            report_textdirections("%s character nodes removed",n)
        end
    end

    return head, done

end

installhandler(variables.default,process_direct)

function directions.process(namespace,attribute,head) -- nodes not nuts
    if not head.next then
        return head, false
    end
    local attr = head[a_directions]
    if not attr or attr == 0 then
        return head, false
    end
    local method  = getmethod(attr)
    local handler = handlers[method]
    if not handler then
        return head, false
    end
    return handler(namespace,attribute,head)
end

-- function directions.enable()
--     tasks.enableaction("processors","directions.handler")
-- end

local enabled = false

function directions.set(n) -- todo: names and numbers
    if not enabled then
        if trace_textdirections then
            report_textdirections("enabling directions handler")
        end
        tasks.enableaction("processors","typesetters.directions.handler")
        enabled = true
    end
    if not n or n == 0 then
        n = unsetvalue
        -- maybe tracing
    end
    texsetattribute(a_directions,n)
end

commands.setdirection = directions.set

directions.handler = nodes.installattributehandler {
    name      = "directions",
    namespace = directions,
    processor = directions.process,
}

-- As I'm wrapping up the updated math support (for CTX/TUG 2013) I wondered about numbers in
-- r2l math mode. Googling lead me to TUGboat, Volume 25 (2004), No. 2 where I see numbers
-- running from left to right. Makes me wonder how far we should go. And as I was looking
-- into bidi anyway, it's a nice distraction.
--
-- I first tried to hook something into noads but that gets pretty messy due to indirectness
-- char noads. If needed, I'll do it that way. With regards to spacing: as we can assume that
-- only numbers are involved we can safely swap them and the same is true for mirroring. But
-- anyway, I'm not too happy with this solution so eventually I'll do something with noads (as
-- an alternative method).

local function processmath(head)
    local current = head
    local done    = false
    local start   = nil
    local stop    = nil
    local function capsulate()
        head = insert_node_before(head,start,new_textdir("+TLT"))
        insert_node_after(head,stop,new_textdir("-TLT"))
        if trace_mathdirections then
            report_mathdirections("reversed: %s",nodes.listtoutf(start,false,false,stop))
        end
        done  = true
        start = false
        stop  = nil
    end
    while current do
        local id = current.id
        if id == glyph_code then
            local char = current.char
            local cdir = chardirections[char]
            if cdir == "en" or cdir == "an" then -- we could check for mathclass punctuation
                if not start then
                    start = current
                end
                stop = current
            else
                if not start then
                    -- nothing
                elseif start == stop then
                    start = nil
                else
                    capsulate()
                end
                if cdir == "on" then
                    local mirror = charmirrors[char]
                    if mirror then
                        local class = charclasses[char]
                        if class == "open" or class == "close" then
                            current.char = mirror
                            if trace_mathdirections then
                                report_mathdirections("mirrored: %C to %C",char,mirror)
                            end
                            done = true
                        end
                    end
                end
            end
        elseif not start then
            -- nothing
        elseif start == stop then
            start = nil
        else
            capsulate(head,start,stop)
            -- math can pack things into hlists .. we need to make sure we don't process
            -- too often: needs checking
            if id == hlist_code or id == vlist_code then
                local list, d = processmath(current.list)
                current.list = list
                if d then
                    done = true
                end
            end
        end
        current = current.next
    end
    if not start then
        -- nothing
    elseif start == stop then
        -- nothing
    else
        capsulate()
    end
    return head, done
end

local enabled = false

function directions.processmath(head) -- style, penalties
    if enabled then
        local a = head[a_mathbidi]
        if a and a > 0 then
            return processmath(head)
        end
    end
    return head, false
end

function directions.setmath(n)
    if not enabled and n and n > 0 then
        if trace_mathdirections then
            report_mathdirections("enabling directions handler")
        end
        nodes.tasks.enableaction("math","typesetters.directions.processmath")
        enabled = true
    end
end

commands.setmathdirection = directions.setmath

-- directions.mathhandler = nodes.installattributehandler {
--     name      = "directions",
--     namespace = directions,
--     processor = directions.processmath,
-- }
