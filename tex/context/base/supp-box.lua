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
local glyph_code   = nodecodes.glyph

local new_penalty  = nodes.pool.penalty
local new_hlist    = nodes.pool.hlist
local new_glue     = nodes.pool.glue

local free_node    = nodes.free
local copy_list    = nodes.copy_list
local copy_node    = nodes.copy
local find_tail    = nodes.tail

local texsetbox    = tex.setbox
local texgetbox    = tex.getbox
local texget       = tex.get

local function hyphenatedlist(list)
    while list do
        local id, next, prev = list.id, list.next, list.prev
        if id == disc_code then
            local hyphen = list.pre
            if hyphen then
                local penalty = new_penalty(-500)
                hyphen.next, penalty.prev = penalty, hyphen
                prev.next, next.prev = hyphen, penalty
                penalty.next, hyphen.prev = next, prev
                list.pre = nil
                free_node(list)
            end
        elseif id == vlist_code or id == hlist_code then
            hyphenatedlist(list.list)
        end
        list = next
    end
end

commands.hyphenatedlist = hyphenatedlist

function commands.showhyphenatedinlist(list)
    report_hyphenation("show: %s",nodes.listtoutf(list,false,true))
end

local function checkedlist(list)
    if type(list) == "number" then
        return texgetbox(list).list
    else
        return list
    end
end

local function applytochars(list,what,nested)
    local doaction = context[what or "ruledhbox"]
    local noaction = context
    local current  = checkedlist(list)
    while current do
        local id = current.id
        if nested and (id == hlist_code or id == vlist_code) then
            context.beginhbox()
            applytochars(current.list,what,nested)
            context.endhbox()
        elseif id ~= glyph_code then
            noaction(copy_node(current))
        else
            doaction(copy_node(current))
        end
        current = current.next
    end
end

local function applytowords(list,what,nested)
    local doaction = context[what or "ruledhbox"]
    local noaction = context
    local current  = checkedlist(list)
    local start
    while current do
        local id = current.id
        if id == glue_code then
            if start then
                doaction(copy_list(start,current))
                start = nil
            end
            noaction(copy_node(current))
        elseif nested and (id == hlist_code or id == vlist_code) then
            context.beginhbox()
            applytowords(current.list,what,nested)
            context.egroup()
        elseif not start then
            start = current
        end
        current = current.next
    end
    if start then
        doaction(copy_list(start))
    end
end

commands.applytochars = applytochars
commands.applytowords = applytowords

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

function commands.vboxlisttohbox(original,target,inbetween)
    local current = texgetbox(original).list
    local head = nil
    local tail = nil
    while current do
        if current.id == hlist_code then
            local list = current.list
            if head then
                if inbetween > 0 then
                    local n = new_glue(0,0,inbetween)
                    tail.next = n
                    n.prev = tail
                    tail = n
                end
                tail.next = list
                list.prev = tail
            else
                head = list
            end
            tail = find_tail(list)
            tail.next = nil
            current.list = nil
        end
        current = current.next
    end
    local result = new_hlist()
    result.list = head
    texsetbox(target,result)
end

function commands.hboxtovbox(original)
    local b = texgetbox(original)
    local factor = texget("baselineskip").width / texget("hsize")
    b.depth = 0
    b.height = b.width * factor
end

function commands.boxtostring(n)
    context.puretext(nodes.toutf(tex.box[n].list)) -- helper is defined later
end
