if not modules then modules = { } end modules ['node-acc'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local nodecodes      = nodes.nodecodes
local tasks          = nodes.tasks

local traverse_nodes = node.traverse
local traverse_id    = node.traverse_id
local copy_node      = node.copy
local free_nodelist  = node.flush_list

local glue_code      = nodecodes.glue
local kern_code      = nodecodes.kern
local glyph_code     = nodecodes.glyph
local hlist_code     = nodecodes.hlist
local vlist_code     = nodecodes.vlist

local a_characters   = attributes.private("characters")

local threshold      = 65536

-- todo: nbsp etc
-- todo: collapse kerns

local function injectspaces(head)
    local p
    local n = head
    while n do
        local id = n.id
        if id == glue_code then -- todo: check for subtype related to spacing (13/14 but most seems to be 0)
       -- if n.spec.width > 0 then -- threshold
            if p and p.id == glyph_code then
                local g = copy_node(p)
                local c = g.components
                if c then -- it happens that we copied a ligature
                    free_nodelist(c)
                    g.components = nil
                    g.subtype = 256
                end
                local a = n[a_characters]
                local s = copy_node(n.spec)
                g.char, n.spec = 32, s
                p.next, g.prev = g, p
                g.next, n.prev = n, g
                s.width = s.width - g.width
                if a then
                    g[a_characters] = a
                end
                s[a_characters] = 0
                n[a_characters] = 0
            end
       -- end
        elseif id == hlist_code or id == vlist_code then
            injectspaces(n.list,attribute)
     -- elseif id == kern_code then -- the backend already collapses
     --     local first = n
     --     while true do
     --         local nn = n.next
     --         if nn and nn.id == kern_code then
     --          -- maybe we should delete kerns but who cares at this stage
     --             first.kern = first.kern + nn.kern
     --             nn.kern = 0
     --             n = nn
     --         else
     --             break
     --         end
     --     end
        end
        p = n
        n = n.next
    end
    return head, true
end

nodes.handlers.accessibility = injectspaces

-- todo:

-- local a_hyphenated = attributes.private('hyphenated')
--
-- local hyphenated, codes = { }, { }
--
-- local function compact(n)
--     local t = { }
--     for n in traverse_id(glyph_code,n) do
--         t[#t+1] = utfchar(n.char) -- check for unicode
--     end
--     return concat(t,"")
-- end
--
-- local function injectspans(head)
--     for n in traverse_nodes(head) do
--         local id = n.id
--         if id == disc then
--             local r, p = n.replace, n.pre
--             if r and p then
--                 local str = compact(r)
--                 local hsh = hyphenated[str]
--                 if not hsh then
--                     hsh = #codes + 1
--                     hyphenated[str] = hsh
--                     codes[hsh] = str
--                 end
--                 n[a_hyphenated] = hsh
--             end
--         elseif id == hlist_code or id == vlist_code then
--             injectspans(n.list)
--         end
--     end
--     return head, true
-- end
--
-- nodes.injectspans = injectspans
--
-- tasks.appendaction("processors", "words", "nodes.injectspans")
--
-- local function injectspans(head)
--     for n in traverse_nodes(head) do
--         local id = n.id
--         if id == disc then
--             local a = n[a_hyphenated]
--             if a then
--                 local str = codes[a]
--                 local b = new_pdfliteral(format("/Span << /ActualText %s >> BDC", lpdf.tosixteen(str)))
--                 local e = new_pdfliteral("EMC")
--                 node.insert_before(head,n,b)
--                 node.insert_after(head,n,e)
--             end
--         elseif id == hlist_code or id == vlist_code then
--             injectspans(n.list)
--         end
--     end
-- end
