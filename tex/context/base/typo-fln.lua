if not modules then modules = { } end modules ['typo-fln'] = {
    version   = 1.001,
    comment   = "companion to typo-fln.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- When I ran into the following experimental code again, I figured that it dated
-- from the early days of mkiv, so I updates it a bit to fit into todays context.
-- In the process I might have messed up things. For instance we had a diffent
-- wrapper then using head and tail.

-- todo: only letters (no punctuation)
-- todo: nuts

local trace_firstlines  = false  trackers.register("typesetters.firstlines", function(v) trace_firstlines = v end)

local report_firstlines = logs.reporter("nodes","firstlines")

local nodes             = nodes
local tasks             = nodes.tasks

local nodecodes         = nodes.nodecodes
local glyph             = nodecodes.glyph
local rule              = nodecodes.rule
local disc              = nodecodes.disc

local traverse_id       = nodes.traverse_id
local free_node_list    = nodes.flush_list
local copy_node_list    = nodes.copy_list
local insert_node_after = nodes.insert_after
local hpack_node_list   = nodes.hpack

local hpack_filter      = nodes.processors.hpack_filter

local newpenalty        = nodes.pool.penalty

typesetters.firstlines  = typesetters.firstlines or { }
local firstlines        = typesetters.firstlines

local actions           = { }
firstlines.actions      = actions

local busy              = false
local settings          = { }

local a_firstline       = attributes.private('firstline')
local a_color           = attributes.private('color')
local a_transparency    = attributes.private('transparency')
local a_colorspace      = attributes.private('colormodel')

local unsetvalue        = attributes.unsetvalue

local variables         = interfaces.variables

----- is_letter         = characters.is_letter
----- categories        = characters.categories

firstlines.actions[variables.line] = function(head,setting)
 -- local attribute = fonts.specifiers.contextnumber(setting.feature) -- was experimental
    local dynamic = setting.dynamic
    local font    = setting.font
    -- make copy with dynamic feature attribute set
    local list = copy_node_list(head)
    for g in traverse_id(glyph,list) do
        if dynamic > 0 then
            g[0] = dynamic
        end
        g.font = font
    end
    local words        = 0
    local nofchars     = 0
    local nofwords     = 1
    local going        = true
    local lastnofchars = 0
    local hsize        = tex.hsize - tex.parindent - tex.leftskip.width - tex.rightskip.width -- can be a helper
    while going do
        -- (slow) stepwise pass (okay, we could do do a vsplit and stitch but why do difficult)
        local temp   = copy_node_list(list)
        local start  = temp
        local ok     = false
        lastnofchars = nofchars
        nofchars     = 0
        words        = 0
        local quit   = false
        while start do
            -- also nicely quits on dics node
            local id = start.id
            if id == glyph then
             -- if not is_letter[categories[start.char]] then
             --     quit = true
             -- elseif not ok then
                if not ok then
                    words = words + 1
                    ok = true
                end
                nofchars = nofchars + 1
            elseif id == disc then
                -- this could be an option
            else
                quit = true
            end
            if quit then
                ok = false
                if words == nofwords then
                    local f = start.next
                    start.next = nil
                    free_node_list(f)
                    break
                end
                quit = false
            end
            start = start.next
        end
        if not start then
            going = false
        end
        local pack = hpack_node_list(hpack_filter(temp))
        if pack.width > hsize then
            nofchars = lastnofchars
            break
        else
            nofwords = nofwords + 1
        end
        free_node_list(pack)
    end
    -- set dynamic attribute in real list
    local start = head
    local ma    = setting.ma or 0
    local ca    = setting.ca
    local ta    = setting.ta
    while start do
        local id = start.id
        if id == glyph then -- or id == disc then
            if nofchars > 0 then
                if dynamic > 0 then
                    start[0] = dynamic
                end
                start.font = font
                if ca and ca > 0 then
                    start[a_colorspace] = ma == 0 and 1 or ma
                    start[a_color]      = ca
                end
                if ta and ta > 0 then
                    start[a_transparency] = ta
                end
                nofchars = nofchars - 1
                if nofchars == 0 then
                    insert_node_after(head,start,newpenalty(-10000)) -- break
                end
            else
                break
            end
        end
        start = start.next
    end
    -- variant (no disc nodes)
 -- if false then
 --     for g in traverse_id(glyph,head) do
 --         if nofchars > 0 then
 --             if dynamic > 0 then
 --                 g[0] = dynamic
 --             end
 --             g.font = font
 --             nofchars = nofchars - 1
 --             if nofchars == 0 then
 --                 insert_node_after(head,g,newpenalty(-10000)) -- break
 --             end
 --         end
 --     end
 -- end
    return head, true
end

firstlines.actions[variables.word] = function(head,setting)
 -- local attribute = fonts.specifiers.contextnumber(setting.feature) -- was experimental
    local dynamic = setting.dynamic
    local font    = setting.font
    local words    = 0
    local nofwords = setting.n or 1
    local start    = head
    local ok       = false
    local ma       = setting.ma or 0
    local ca       = setting.ca
    local ta       = setting.ta
    while start do
        local id = start.id
        -- todo: delete disc nodes
        if id == glyph then
            if not ok then
                words = words + 1
                ok = true
            end
            if ca and ca > 0 then
                start[a_colorspace] = ma == 0 and 1 or ma
                start[a_color]      = ca
            end
            if ta and ta > 0 then
                start[a_transparency] = ta
            end
            if dynamic > 0 then
                start[0] = dynamic
            end
            start.font = font
        elseif id == disc then
            -- continue
        else
            ok = false
            if words == nofwords then
                break
            end
        end
        start = start.next
    end
    return head, true
end

local function process(namespace,attribute,head)
    if not busy then
        local start, attr = head, nil
        while start do
            attr = start[attribute]
            if attr or start.id == glyph then
                break
            else
                start = start.next
            end
        end
        if attr then
            local setting = settings[attr]
            if setting then
                local action = actions[setting.alternative]
                if action then
                    busy = true
                    head, done = action(head,setting)
                    busy = false
                end
            end
            for g in traverse_id(glyph,head) do
                -- inefficient: we could quit at unset
                g[attribute] = unsetvalue
            end
            return head, true
        end
    end
    return head, false
end

-- local enabled = false

-- function firstlines.set(n)
--     if n == variables.reset or not tonumber(n) or n == 0 then
--         texsetattribute(a_firstline,unsetvalue)
--     else
--         if not enabled then
--             tasks.enableaction("processors","typesetters.firstlines.handler")
--             if trace_paragraphs then
--                 report_firstlines("enabling firstlines")
--             end
--             enabled = true
--         end
--         texsetattribute(a_firstline,n)
--     end
-- end

firstlines.attribute = a_firstline

firstlines.handler = nodes.installattributehandler {
    name      = "firstlines",
    namespace = firstlines,
    processor = process,
}

function firstlines.define(setting)
    local n = #settings + 1
    settings[n] = setting
    tasks.enableaction("processors","typesetters.firstlines.handler")
    return n
end

function commands.definefirstline(setting)
    context(firstlines.define(setting))
end
