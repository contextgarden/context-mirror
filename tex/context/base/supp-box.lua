if not modules then modules = { } end modules ['supp-box'] = {
    version   = 1.001,
    comment   = "companion to supp-box.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is preliminary code, use insert_before etc

local report_hyphenation = logs.reporter("languages","hyphenation")

local tex          = tex
local context      = context
local commands     = commands
local nodes        = nodes

local splitstring  = string.split

local nodecodes    = nodes.nodecodes

local disc_code    = nodecodes.disc
local hlist_code   = nodecodes.hlist
local vlist_code   = nodecodes.vlist
local glue_code    = nodecodes.glue
local kern_code    = nodecodes.kern
local glyph_code   = nodecodes.glyph

local nuts         = nodes.nuts
local tonut        = nuts.tonut
local tonode       = nuts.tonode

local getfield     = nuts.getfield
local getnext      = nuts.getnext
local getprev      = nuts.getprev
local getid        = nuts.getid
local getlist      = nuts.getlist
local getattribute = nuts.getattribute
local getbox       = nuts.getbox

local setfield     = nuts.setfield
local setbox       = nuts.setbox

local free_node    = nuts.free
local copy_list    = nuts.copy_list
local copy_node    = nuts.copy
local find_tail    = nuts.tail

local listtoutf    = nodes.listtoutf

local nodepool     = nuts.pool
local new_penalty  = nodepool.penalty
local new_hlist    = nodepool.hlist
local new_glue     = nodepool.glue

local texget       = tex.get

local function hyphenatedlist(head)
    local current = head and tonut(head)
    while current do
        local id   = getid(current)
        local next = getnext(current)
        local prev = getprev(current)
        if id == disc_code then
            local hyphen = getfield(current,"pre")
            if hyphen then
                local penalty = new_penalty(-500)
                -- insert_after etc
                setfield(hyphen,"next",penalty)
                setfield(penalty,"prev",hyphen)
                setfield(prev,"next",hyphen)
                setfield(next,"prev", penalty)
                setfield(penalty,"next",next)
                setfield(hyphen,"prev",prev)
                setfield(current,"pre",nil)
                free_node(current)
            end
        elseif id == vlist_code or id == hlist_code then
            hyphenatedlist(getlist(current))
        end
        current = next
    end
end

commands.hyphenatedlist = hyphenatedlist

function commands.showhyphenatedinlist(list)
    report_hyphenation("show: %s",listtoutf(tonut(list),false,true))
end

local function checkedlist(list)
    if type(list) == "number" then
        return getlist(getbox(tonut(list)))
    else
        return tonut(list)
    end
end

local function applytochars(current,doaction,noaction,nested)
    while current do
        local id = getid(current)
        if nested and (id == hlist_code or id == vlist_code) then
            context.beginhbox()
            applytochars(getlist(current),what,nested)
            context.endhbox()
        elseif id ~= glyph_code then
            noaction(tonode(copy_node(current)))
        else
            doaction(tonode(copy_node(current)))
        end
        current = getnext(current)
    end
end

local function applytowords(current,doaction,noaction,nested)
    local start
    while current do
        local id = getid(current)
        if id == glue_code then
            if start then
                doaction(tonode(copy_list(start,current)))
                start = nil
            end
            noaction(tonode(copy_node(current)))
        elseif nested and (id == hlist_code or id == vlist_code) then
            context.beginhbox()
            applytowords(getlist(current),what,nested)
            context.egroup()
        elseif not start then
            start = current
        end
        current = getnext(current)
    end
    if start then
        doaction(tonode(copy_list(start)))
    end
end

commands.applytochars = function(list,what,nested) applytochars(checkedlist(list),context[what or "ruledhbox"],context,nested) end
commands.applytowords = function(list,what,nested) applytowords(checkedlist(list),context[what or "ruledhbox"],context,nested) end

local split_char = lpeg.Ct(lpeg.C(1)^0)
local split_word = lpeg.tsplitat(lpeg.patterns.space)
local split_line = lpeg.tsplitat(lpeg.patterns.eol)

function commands.processsplit(str,command,how,spaced)
    how = how or "word"
    if how == "char" then
        local words = lpeg.match(split_char,str)
        for i=1,#words do
            local word = words[i]
            if word == " " then
                if spaced then
                    context.space()
                end
            elseif command then
                context[command](word)
            else
                context(word)
            end
        end
    elseif how == "word" then
        local words = lpeg.match(split_word,str)
        for i=1,#words do
            local word = words[i]
            if spaced and i > 1 then
                context.space()
            end
            if command then
                context[command](word)
            else
                context(word)
            end
        end
    elseif how == "line" then
        local words = lpeg.match(split_line,str)
        for i=1,#words do
            local word = words[i]
            if spaced and i > 1 then
                context.par()
            end
            if command then
                context[command](word)
            else
                context(word)
            end
        end
    else
        context(str)
    end
end

local a_vboxtohboxseparator = attributes.private("vboxtohboxseparator")

function commands.vboxlisttohbox(original,target,inbetween)
    local current = getlist(getbox(original))
    local head = nil
    local tail = nil
    while current do
        local id   = getid(current)
        local next = getnext(current)
        if id == hlist_code then
            local list = getlist(current)
            if head then
                if inbetween > 0 then
                    local n = new_glue(0,0,inbetween)
                    setfield(tail,"next",n)
                    setfield(n,"prev",tail)
                    tail = n
                end
                setfield(tail,"next",list)
                setfield(list,"prev",tail)
            else
                head = list
            end
            tail = find_tail(list)
            -- remove last separator
            if getid(tail) == hlist_code and getattribute(tail,a_vboxtohboxseparator) == 1 then
                local temp = tail
                local prev = getprev(tail)
                if next then
                    local list = getlist(tail)
                    setfield(prev,"next",list)
                    setfield(list,"prev",prev)
                    setfield(tail,"list",nil)
                    tail = find_tail(list)
                else
                    tail = prev
                end
                free_node(temp)
            end
            -- done
            setfield(tail,"next",nil)
            setfield(current,"list",nil)
        end
        current = next
    end
    local result = new_hlist()
    setfield(result,"list",head)
    setbox(target,result)
end

function commands.hboxtovbox(original)
    local b = getbox(original)
    local factor = texget("baselineskip").width / texget("hsize")
    setfield(b,"depth",0)
    setfield(b,"height",getfield(b,"width") * factor)
end

function commands.boxtostring(n)
    context.puretext(nodes.toutf(tex.box[n].list)) -- helper is defined later
end
