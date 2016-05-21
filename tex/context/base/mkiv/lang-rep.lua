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

local type, tonumber = type, tonumber
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

local trace_replacements = false  trackers.register("languages.replacements",        function(v) trace_replacements = v end)
local trace_detail       = false  trackers.register("languages.replacements.detail", function(v) trace_detail       = v end)

local report_replacement = logs.reporter("languages","replacements")

local glyph_code         = nodes.nodecodes.glyph

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local tonode             = nuts.tonode

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getattr            = nuts.getattr
local getid              = nuts.getid
local getchar            = nuts.getchar
local isglyph            = nuts.isglyph

local setfield           = nuts.setfield
local setattr            = nuts.setattr
local setlink            = nuts.setlink
local setnext            = nuts.setnext
local setprev            = nuts.setprev
local setchar            = nuts.setchar

local insert_node_before = nuts.insert_before
local remove_node        = nuts.remove
local copy_node          = nuts.copy
local flush_list         = nuts.flush_list
local insert_after       = nuts.insert_after

local nodepool           = nuts.pool
local new_disc           = nodepool.disc

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local v_reset            = interfaces.variables.reset

local implement          = interfaces.implement

local replacements       = languages.replacements or { }
languages.replacements   = replacements

local a_replacements     = attributes.private("replacements")
local a_noligature       = attributes.private("noligature")

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
    local replacement = lpegmatch(stripper,replacement) or replacement
    local list = utfsplit(word,true)
    local size = #list
    for i=1,size do
        local l = utfbyte(list[i])
        if not root[l] then
            root[l] = { }
        end
        if i == size then
         -- local newlist = utfsplit(replacement,true)
         -- for i=1,#newlist do
         --     newlist[i] = utfbyte(newlist[i])
         -- end
            local special = find(replacement,"{",1,true)
            local newlist = lpegmatch(splitter,replacement)
            --
            root[l].final = {
                word        = word,
                replacement = replacement,
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

local function hit(a,head)
    local tree = trees[a]
    if tree then
        local root = tree[getchar(head)]
        if root then
            local current   = getnext(head)
            local lastrun   = false
            local lastfinal = false
            while current do
                local char = isglyph(current)
                if char then
                    local newroot = root[char]
                    if not newroot then
                        return lastrun, lastfinal
                    else
                        local final = newroot.final
                        if final then
                            if trace_detail then
                                report_replacement("hitting word %a, replacement %a",final.word,final.replacement)
                            end
                            lastrun   = current
                            lastfinal = final
                        else
                            root = newroot
                        end
                    end
                    current = getnext(current)
                else
                    break
                end
            end
            if lastrun then
                return lastrun, lastfinal
            end
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


function replacements.handler(head)
    head = tonut(head)
    local current = head
    local done    = false
    while current do
        if getid(current) == glyph_code then
            local a = getattr(current,a_replacements)
            if a then
                local last, final = hit(a,current)
                if last then
                    local oldlength = final.oldlength
                    local newcodes  = final.newcodes
                    local newlength = #newcodes
                    if trace_replacement then
                        report_replacement("replacing word %a by %a",final.word,final.replacement)
                    end
                    if final.special then
                        -- easier is to delete and insert (a simple callout to tex would be more efficient)
                        -- maybe just walk over a replacement string instead
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
                            local new = nil
                            if type(codes) == "table" then
                                local method = codes[1]
                                if method == "discretionary" then
                                    local pre, post, replace = codes[2], codes[3], codes[4]
                                    new = new_disc()
                                    if pre then
                                        setfield(new,"pre",tonodes(pre,last))
                                    end
                                    if post then
                                        setfield(new,"post",tonodes(post,last))
                                    end
                                    if replace then
                                        setfield(new,"replace",tonodes(replace,last))
                                    end
                                    head, current = insert_after(head,current,new)
                                elseif method == "noligature" then
                                    -- not that efficient to copy but ok for testing
                                    local list = codes[2]
                                    if list then
                                        for i=1,#list do
                                            new = copy_node(last)
                                            setchar(new,list[i])
                                            setattr(new,a_noligature,1)
                                            head, current = insert_after(head,current,new)
                                        end
                                    else
                                        new = copy_node(last)
                                        setchar(new,zwnj)
                                        head, current = insert_after(head,current,new)
                                    end
                                else
                                    -- todo
                                end
                            else
                                new = copy_node(last)
                                setchar(new,codes)
                                head, current = insert_after(head,current,new)
                            end
                            i = i + 1
                        end
                        flush_list(list)
                    elseif oldlength == newlength then -- #old == #new
                        if final.word == final.replacement then
                            -- nothing to do but skip
                        else
                            for i=1,newlength do
                                setchar(current,newcodes[i])
                                current = getnext(current)
                            end
                        end
                    elseif oldlength < newlength then -- #old < #new
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
                    else -- #old > #new
                        for i=1,oldlength-newlength do
                            head, current = remove_node(head,current,true)
                        end
                        for i=1,newlength do
                            setchar(current,newcodes[i])
                            current = getnext(current)
                        end
                    end
                    done = true
                end
            end
        end
        current = getnext(current)
    end
    return tonode(head), done
end

local enabled = false

function replacements.set(n)
    if n == v_reset then
        n = unsetvalue
    else
        n = lists[n].attribute
        if not enabled then
            nodes.tasks.enableaction("processors","languages.replacements.handler")
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
    arguments = { "string", "string", "string" }
}
