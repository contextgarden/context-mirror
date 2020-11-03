if not modules then modules = { } end modules ['lang-rep'] = {
    version   = 1.001,
    comment   = "companion to lang-rep.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A BachoTeX 2013 experiment, probably not that useful. Eventually I used a simpler
-- more generic example. I'm sure no one ever notices of even needs this code.
--
-- As a follow up on a question by Alan about special treatment of dropped caps I wonder
-- if I can make this one more clever (probably in a few more dev steps). For instance
-- injecting nodes or replacing nodes. It's a prelude to a kind of lpeg for nodes,
-- although (given experiences so far) we don't really need that. After all, each problem
-- is somewhat unique.

local type, tonumber, next = type, tonumber, next
local gmatch, gsub = string.gmatch, string.gsub
local utfbyte, utfsplit = utf.byte, utf.split
local P, C, U, Cc, Ct, Cs, lpegmatch = lpeg.P, lpeg.C, lpeg.patterns.utf8character, lpeg.Cc, lpeg.Ct, lpeg.Cs, lpeg.match
local find = string.find

local zwnj     =  0x200C
local grouped  = P("{") * ( Ct((U/utfbyte-P("}"))^1) + Cc(false) ) * P("}")-- grouped
local splitter = Ct((
                    #P("{") * (
                        P("{}") / function() return zwnj end
                      + Ct(Cc("discretionary") * grouped * grouped * grouped)
                      + Ct(Cc("noligature")    * grouped)
                    )
                  + U/utfbyte
                )^1)

local stripper = P("{") * Cs((1-P(-2))^0) * P("}") * P(-1)

local trace_replacements = false  trackers.register("languages.replacements",         function(v) trace_replacements = v end)
local trace_details      = false  trackers.register("languages.replacements.details", function(v) trace_details      = v end)

local report_replacement = logs.reporter("languages","replacements")

local glyph_code         = nodes.nodecodes.glyph
local glue_code          = nodes.nodecodes.glue

local spaceskip_code     = nodes.gluecodes.spaceskip
local xspaceskip_code    = nodes.gluecodes.xspaceskip

local nuts               = nodes.nuts

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getattr            = nuts.getattr
local getid              = nuts.getid
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar
local isglyph            = nuts.isglyph

local setattr            = nuts.setattr
local setlink            = nuts.setlink
local setnext            = nuts.setnext
local setprev            = nuts.setprev
local setchar            = nuts.setchar
local setattrlist        = nuts.setattrlist

local insert_node_before = nuts.insert_before
local remove_node        = nuts.remove
local copy_node          = nuts.copy
local flush_list         = nuts.flush_list
local insert_after       = nuts.insert_after

local nodepool           = nuts.pool
local new_disc           = nodepool.disc

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local enableaction       = nodes.tasks.enableaction

local v_reset            = interfaces.variables.reset

local implement          = interfaces.implement

local processors         = typesetters.processors
local splitprocessor     = processors.split

local replacements       = languages.replacements or { }
languages.replacements   = replacements

local a_replacements     = attributes.private("replacements")
local a_noligature       = attributes.private("noligature")      -- to be adapted to lmtx !

local lists = { }
local last  = 0
local trees = { }

table.setmetatableindex(lists,function(lists,name)
    last = last + 1
    local list = { }
    local data = { name = name, list = list, attribute = last }
    lists[last] = data
    lists[name] = data
    trees[last] = list
    return data
end)

lists[v_reset].attribute = unsetvalue -- so we discard 0

-- todo: glue kern attr

local function add(root,word,replacement)
    local processor, replacement = splitprocessor(replacement,true) -- no check
    replacement = lpegmatch(stripper,replacement) or replacement
    local list = utfsplit(word) -- ,true)
    local size = #list
    for i=1,size do
        local l = utfbyte(list[i])
        if not root[l] then
            root[l] = { }
        end
        if i == size then
            local special = find(replacement,"{",1,true)
            local newlist = lpegmatch(splitter,replacement)
            root[l].final = {
                word        = word,
                replacement = replacement,
                processor   = processor,
                oldlength   = size,
                newcodes    = newlist,
                special     = special,
            }
        end
        root = root[l]
    end
end

function replacements.add(category,word,replacement)
    local root = lists[category].list
    if type(word) == "table" then
        for word, replacement in next, word do
            add(root,word,replacement)
        end
    else
        add(root,word,replacement or "")
    end
end

-- local strip = lpeg.stripper("{}")

function languages.replacements.addlist(category,list)
    local root = lists[category].list
    if type(list) == "string" then
        for new in gmatch(list,"%S+") do
            local old = gsub(new,"[{}]","")
         -- local old = lpegmatch(strip,new)
            add(root,old,new)
        end
    else
        for i=1,#list do
            local new = list[i]
            local old = gsub(new,"[{}]","")
         -- local old = lpegmatch(strip,new)
            add(root,old,new)
        end
    end
end

local function tonodes(list,template)
    local head, current
    for i=1,#list do
        local new = copy_node(template)
        setchar(new,list[i])
        if head then
            head, current = insert_after(head,current,new)
        else
            head, current = new, new
        end
    end
    return head
end

local is_punctuation = characters.is_punctuation

-- We can try to be clever and use the fact that there is no match to skip
-- over to the next word but it is gives fuzzy code so for now I removed
-- that optimization (when I really need a high performance version myself
-- I will look into it (but so far I never used this mechanism myself).
--
-- We used to have the hit checker as function but is got messy when checks
-- for punctuation was added.

local function replace(head,first,last,final,hasspace,overload)
    local current   = first
    local prefirst  = getprev(first) or head
    local postlast  = getnext(last)
    local oldlength = final.oldlength
    local newcodes  = final.newcodes
    local newlength = newcodes and #newcodes or 0
    if trace_replacements then
        report_replacement("replacing word %a by %a",final.word,final.replacement)
    end
    if hasspace or final.special then
        -- It's easier to delete and insert so we do just that. On the todo list is
        -- turn injected spaces into glue but easier might be to let the char break
        -- handler do that ...
        local prev = getprev(current)
        local next = getnext(last)
        local list = current
        setnext(last)
        setlink(prev,next)
        current = prev
        if not current then
            head = nil
        end
        local i = 1
        while i <= newlength do
            local codes = newcodes[i]
            if type(codes) == "table" then
                local method = codes[1]
                if method == "discretionary" then
                    local pre, post, replace = codes[2], codes[3], codes[4]
                    if pre then
                        pre = tonodes(pre,first)
                    end
                    if post then
                        post = tonodes(post,first)
                    end
                    if replace then
                        replace = tonodes(replace,first)
                    end
                    -- todo: also set attr
                    local new = new_disc(pre,post,replace)
                    setattrlist(new,first)
                    head, current = insert_after(head,current,new)
                elseif method == "noligature" then
                    -- not that efficient to copy but ok for testing
                    local list = codes[2]
                    if list then
                        for i=1,#list do
                            local new = copy_node(first)
                            setchar(new,list[i])
                            setattr(new,a_noligature,1)
                            head, current = insert_after(head,current,new)
                        end
                    else
                        local new = copy_node(first)
                        setchar(new,zwnj)
                        head, current = insert_after(head,current,new)
                    end
                else
                    report_replacement("unknown method %a",method or "?")
                end
            else
                local new = copy_node(first)
                setchar(new,codes)
                head, current = insert_after(head,current,new)
            end
            i = i + 1
        end
        flush_list(list)
    elseif newlength == 0 then
        -- we overload
    elseif oldlength == newlength then
        if final.word ~= final.replacement then
            for i=1,newlength do
                setchar(current,newcodes[i])
                current = getnext(current)
            end
        end
        current = getnext(final)
    elseif oldlength < newlength then
        for i=1,newlength-oldlength do
            local n = copy_node(current)
            setchar(n,newcodes[i])
            head, current = insert_node_before(head,current,n)
            current = getnext(current)
        end
        for i=newlength-oldlength+1,newlength do
            setchar(current,newcodes[i])
            current = getnext(current)
        end
    else
        for i=1,oldlength-newlength do
            head, current = remove_node(head,current,true)
        end
        for i=1,newlength do
            setchar(current,newcodes[i])
            current = getnext(current)
        end
    end
    if overload then
        overload(final,getnext(prefirst),getprev(postlast))
    end
    return head, postlast
end

-- we handle just one space

function replacements.handler(head)
    local current   = head
    local overload  = attributes.applyoverloads
    local mode      = false -- we're in word or punctuation mode
    local wordstart = false
    local wordend   = false
    local prevend   = false
    local prevfinal = false
    local tree      = false
    local root      = false
    local hasspace  = false
    while current do
        local id = getid(current) -- or use the char getter
        if id == glyph_code then
            local a = getattr(current,a_replacements)
            if a then
                -- we have a run
                tree = trees[a]
                if tree then
                    local char = getchar(current)
                    local punc = is_punctuation[char]
                    if mode == "punc" then
                        if not punc then
                            if root then
                                local final = root.final
                                if final then
                                    head = replace(head,wordstart,wordend,final,hasspace,overload)
                                elseif prevfinal then
                                    head = replace(head,wordstart,prevend,prevfinal,hasspace,overload)
                                end
                                prevfinal = false
                                root = false
                            end
                            mode = "word"
                        end
                    elseif mode == "word" then
                        if punc then
                            if root then
                                local final = root.final
                                if final then
                                    head = replace(head,wordstart,wordend,final,hasspace,overload)
                                elseif prevfinal then
                                    head = replace(head,wordstart,prevend,prevfinal,hasspace,overload)
                                end
                                prevfinal = false
                                root = false
                            end
                            mode = "punc"
                        end
                    else
                        mode = punc and "punc" or "word"
                    end
                    if root then
                        root = root[char]
                        if root then
                            wordend = current
                        end
                    else
                        if prevfinal then
                            head = replace(head,wordstart,prevend,prevfinal,hasspace,overload)
                            prevfinal = false
                        end
                        root = tree[char]
                        if root then
                            wordstart = current
                            wordend   = current
                            prevend   = false
                            hasspace  = false
                        end
                    end
                else
                    root= false
                end
            else
                tree = false
            end
            current = getnext(current)
        elseif root then
            local final = root.final
            if mode == "word" and id == glue_code then
                local s = getsubtype(current)
                if s == spaceskip_code or s == xspaceskip_code then
                    local r = root[32] -- maybe more types
                    if r then
                        if not prevend then
                            local f = root.final
                            if f then
                                prevend   = wordend
                                prevfinal = f
                            end
                        end
                        wordend  = current
                        root     = r
                        hasspace = true
                        goto moveon
                    end
                end
            end
            if final then
                head, current = replace(head,wordstart,wordend,final,hasspace,overload)
            elseif prevfinal then
                head, current = replace(head,wordstart,prevend,prevfinal,hasspace,overload)
            end
            prevfinal = false
            root = false
          ::moveon::
            current = getnext(current)
        else
            current = getnext(current)
        end
    end
    if root then
        local final = root.final
        if final then
            head = replace(head,wordstart,wordend,final,hasspace,overload)
        elseif prevfinal then
            head = replace(head,wordstart,prevend,prevfinal,hasspace,overload)
        end
    end
    return head
end

local enabled = false

function replacements.set(n)
    if n == v_reset then
        n = unsetvalue
    else
        n = lists[n].attribute
        if not enabled then
            enableaction("processors","languages.replacements.handler")
            if trace_replacements then
                report_replacement("enabling replacement handler")
            end
            enabled = true
        end
    end
    texsetattribute(a_replacements,n)
end

-- interface

implement {
    name      = "setreplacements",
    actions   = replacements.set,
    arguments = "string"
}

implement {
    name      = "addreplacements",
    actions   = replacements.add,
    arguments = "3 strings",
}

implement {
    name      = "addreplacementslist",
    actions   = replacements.addlist,
    arguments = "2 strings",
}
