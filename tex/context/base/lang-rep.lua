if not modules then modules = { } end modules ['lang-rep'] = {
    version   = 1.001,
    comment   = "companion to lang-rep.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A BachoTeX 2013 experiment, probably not that useful. Eventually I used a simpler
-- more generic example.

local utfbyte, utfsplit = utf.byte, utf.split

local trace_replacements = false  trackers.register("languages.replacements",        function(v) trace_replacements = v end)
local trace_detail       = false  trackers.register("languages.replacements.detail", function(v) trace_detail       = v end)

local report_replacement = logs.reporter("languages","replacements")

local glyph_code         = nodes.nodecodes.glyph

local insert_node_before = nodes.insert_before
local remove_node        = nodes.remove
local copy_node          = nodes.copy

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local v_reset            = interfaces.variables.reset

local replacements       = languages.replacements or { }
languages.replacements   = replacements

local a_replacements     = attributes.private("replacements")

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

local function add(root,word,replacement)
    local list = utfsplit(word,true)
    for i=1,#list do
        local l = utfbyte(list[i])
        if not root[l] then
            root[l] = { }
        end
        if i == #list then
            local newlist = utfsplit(replacement,true)
            for i=1,#newlist do
                newlist[i] = utfbyte(newlist[i])
            end
            root[l].final = {
                word        = word,
                replacement = replacement,
                oldlength   = #list,
                newcodes    = newlist,
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
        local root = tree[head.char]
        if root then
            local current   = head.next
            local lastrun   = false
            local lastfinal = false
            while current and current.id == glyph_code do
                local newroot = root[current.char]
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
                current = current.next
            end
            if lastrun then
                return lastrun, lastfinal
            end
        end
    end
end

function replacements.handler(head)
    local current = head
    local done    = false
    while current do
        if current.id == glyph_code then
            local a = getattr(current,a_replacements)
            if a then
                local last, final = hit(a,current)
                if last then
                    local oldlength = final.oldlength
                    local newcodes  = final.newcodes
                    local newlength = #newcodes
                    if report_replacement then
                        report_replacement("replacing word %a by %a",final.word,final.replacement)
                    end
                    if oldlength == newlength then -- #old == #new
                        for i=1,newlength do
                            current.char = newcodes[i]
                            current = current.next
                        end
                    elseif oldlength < newlength then -- #old < #new
                        for i=1,newlength-oldlength do
                            local n = copy_node(current)
                            n.char = newcodes[i]
                            head, current = insert_node_before(head,current,n)
                            current = current.next
                        end
                        for i=newlength-oldlength+1,newlength do
                            current.char = newcodes[i]
                            current = current.next
                        end
                    else -- #old > #new
                        for i=1,oldlength-newlength do
                            head, current = remove_node(head,current,true)
                        end
                        for i=1,newlength do
                            current.char = newcodes[i]
                            current = current.next
                        end
                    end
                    done = true
                end
            end
        end
        current = current.next
    end
    return head, done
end

local enabled = false

function replacements.set(n) -- number or 'reset'
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

commands.setreplacements = replacements.set
commands.addreplacements = replacements.add

nodes.tasks.prependaction("processors","words","languages.replacements.handler")
nodes.tasks.disableaction("processors","languages.replacements.handler")
