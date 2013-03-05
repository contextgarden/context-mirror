if not modules then modules = { } end modules ['scrn-hlp'] = {
    version   = 1.001,
    comment   = "companion to scrn-hlp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local help           = { }
interactions.help    = help

local a_help         = attributes.private("help")

local copy_nodelist  = node.copy_list
local hpack_nodelist = node.hpack

local register_list  = nodes.pool.register

local nodecodes      = nodes.nodecodes

local hlist_code     = nodecodes.hlist
local vlist_code     = nodecodes.vlist

local data, references = { }, { }

local helpscript = [[
    function Hide_All_Help(prefix) {
        var n = 0
        while (true) {
            n += 1 ;
            v = this.getField(prefix + n) ;
            if (v) {
                v.hidden = true ;
                this.dirty = false ;
            } else {
                return ;
            }
        }
    }
]]

local template = "javascript(Hide_All_Help{help:}),action(show{help:%s})"

function help.register(number,name,box)
    if helpscript then
        interactions.javascripts.setpreamble("HelpTexts",helpscript)
        helpscript = false
    end
    local b = copy_nodelist(tex.box[box])
    register_list(b)
    data[number] = b
    if name and name ~= "" then
        references[name] = number
        structures.references.define("",name,format(template,number))
    end
end

local function collect(head,used)
    while head do
        local id = head.id
        if id == hlist_code then
            local a = head[a_help]
            if a then
                if not used then
                    used = { a }
                else
                    used[#used+1] = a
                end
            else
                used = collect(head.list,used)
            end
        elseif id == vlist_code then
            used = collect(head.list,used)
        end
        head = head.next
    end
    return used
end

function help.collect(box)
    if next(data) then
        return collect(tex.box[box].list)
    end
end

commands.registerhelp = help.register

function commands.collecthelp(box)
    local used = help.collect(box)
    if used then
        local done = { }
        context.startoverlay()
        for i=1,#used do
            local d = data[used[i]]
            if d and not done[d] then
                local box = hpack_nodelist(copy_nodelist(d))
                context(false,box)
                done[d] = true
            else
                -- error
            end
        end
        context.stopoverlay()
    end
end

function help.reference(name)
    return references[name] or tonumber(name) or 0
end

function commands.helpreference(name)
    context(references[name] or tonumber(name) or 0)
end

function commands.helpaction(name)
    context(template,references[name] or tonumber(name) or 0)
end
