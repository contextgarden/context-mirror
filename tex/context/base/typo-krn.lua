if not modules then modules = { } end modules ['typo-krn'] = {
    version   = 1.001,
    comment   = "companion to typo-krn.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8

local next, type = next, type
local utfchar = utf.char

local nodes, node, fonts = nodes, node, fonts

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local find_node_tail     = node.tail or node.slide
local free_node          = node.free
local free_nodelist      = node.flush_list
local copy_node          = node.copy
local copy_nodelist      = node.copy_list
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

local texattribute       = tex.attribute

local nodepool           = nodes.pool
local tasks              = nodes.tasks

local new_gluespec       = nodepool.gluespec
local new_kern           = nodepool.kern

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes
local skipcodes          = nodes.skipcodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local kerning_code       = kerncodes.kerning
local userkern_code      = kerncodes.userkern
local userskip_code      = skipcodes.userskip

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local chardata           = fonthashes.characters
local quaddata           = fonthashes.quads

typesetters              = typesetters or { }
local typesetters        = typesetters

typesetters.kerns        = typesetters.kerns or { }
local kerns              = typesetters.kerns

kerns.mapping            = kerns.mapping or { }
kerns.factors            = kerns.factors or { }
local a_kerns            = attributes.private("kern")
kerns.attribute          = kerns.attribute

storage.register("typesetters/kerns/mapping", kerns.mapping, "typesetters.kerns.mapping")
storage.register("typesetters/kerns/factors", kerns.factors, "typesetters.kerns.factors")

local mapping = kerns.mapping
local factors = kerns.factors

-- one must use liga=no and mode=base and kern=yes
-- use more helpers
-- make sure it runs after all others
-- there will be a width adaptor field in nodes so this will change
-- todo: interchar kerns / disc nodes / can be made faster

local gluefactor = 4 -- assumes quad = .5 enspace

kerns.keepligature = false -- just for fun (todo: control setting with key/value)
kerns.keeptogether = false -- just for fun (todo: control setting with key/value)

-- can be optimized .. the prev thing .. but hardly worth the effort

local function do_process(namespace,attribute,head,force) -- todo: glue so that we can fully stretch
    local start, done, lastfont = head, false, nil
local keepligature = kerns.keepligature
local keeptogether = kerns.keeptogether
    while start do
        -- faster to test for attr first
        local attr = force or has_attribute(start,attribute)
        if attr and attr > 0 then
            unset_attribute(start,attribute)
            local krn = mapping[attr]
            if krn and krn ~= 0 then
                local id = start.id
                if id == glyph_code then
                    lastfont = start.font
                    local c = start.components
                    if c then
if keepligature and keepligature(start) then
    -- keep 'm
else
                        c = do_process(namespace,attribute,c,attr)
                        local s = start
                        local p, n = s.prev, s.next
                        local tail = find_node_tail(c)
                        if p then
                            p.next = c
                            c.prev = p
                        else
                            head = c
                        end
                        if n then
                            n.prev = tail
                        end
                        tail.next = n
                        start = c
                        s.components = nil
                        -- we now leak nodes !
                    --  free_node(s)
                        done = true
end
                    end
                    local prev = start.prev
                    if prev then
                        local pid = prev.id
                        if not pid then
                            -- nothing
                        elseif pid == kern_code and prev.subtype == kerning_code then
if keeptogether and prev.prev.id == glyph_code and keeptogether(prev.prev,start) then -- we could also pass start
    -- keep 'm
else
                            prev.subtype = userkern_code
                            prev.kern = prev.kern + quaddata[lastfont]*krn -- here
                            done = true
end
                        elseif pid == glyph_code then
                            if prev.font == lastfont then
                                local prevchar, lastchar = prev.char, start.char
if keeptogether and keeptogether(prev,start) then
    -- keep 'm
else
                                local kerns = chardata[lastfont][prevchar].kerns
                                local kern = kerns and kerns[lastchar] or 0
                                krn = kern + quaddata[lastfont]*krn -- here
                                insert_node_before(head,start,new_kern(krn))
                                done = true
end
                            else
                                krn = quaddata[lastfont]*krn -- here
                                insert_node_before(head,start,new_kern(krn))
                                done = true
                            end
                        elseif pid == disc_code then
                            -- a bit too complicated, we can best not copy and just calculate
                            -- but we could have multiple glyphs involved so ...
                            local disc = prev -- disc
                            local pre, post, replace = disc.pre, disc.post, disc.replace
                            local prv, nxt = disc.prev, disc.next
                            if pre and prv then -- must pair with start.prev
                                -- this one happens in most cases
                                local before = copy_node(prv)
                                pre.prev = before
                                before.next = pre
                                before.prev = nil
                                pre = do_process(namespace,attribute,before,attr)
                                pre = pre.next
                                pre.prev = nil
                                disc.pre = pre
                                free_node(before)
                            end
                            if post and nxt then  -- must pair with start
                                local after = copy_node(nxt)
                                local tail = find_node_tail(post)
                                tail.next = after
                                after.prev = tail
                                after.next = nil
                                post = do_process(namespace,attribute,post,attr)
                                tail.next = nil
                                disc.post = post
                                free_node(after)
                            end
                            if replace and prv and nxt then -- must pair with start and start.prev
                                local before = copy_node(prv)
                                local after = copy_node(nxt)
                                local tail = find_node_tail(replace)
                                replace.prev = before
                                before.next = replace
                                before.prev = nil
                                tail.next = after
                                after.prev = tail
                                after.next = nil
                                replace = do_process(namespace,attribute,before,attr)
                                replace = replace.next
                                replace.prev = nil
                                after.prev.next = nil
                                disc.replace = replace
                                free_node(after)
                                free_node(before)
                            else
                                if prv and prv.id == glyph_code and prv.font == lastfont then
                                    local prevchar, lastchar = prv.char, start.char
                                    local kerns = chardata[lastfont][prevchar].kerns
                                    local kern = kerns and kerns[lastchar] or 0
                                    krn = kern + quaddata[lastfont]*krn -- here
                                else
                                    krn = quaddata[lastfont]*krn -- here
                                end
                                disc.replace = new_kern(krn)
                            end
                        end
                    end
                elseif id == glue_code and start.subtype == userskip_code then
                    local s = start.spec
                    local w = s.width
                    if w > 0 then
                        local width, stretch, shrink = w+gluefactor*w*krn, s.stretch, s.shrink
                        start.spec = new_gluespec(width,stretch*width/w,shrink*width/w)
                        done = true
                    end
                elseif false and id == kern_code and start.subtype == kerning_code then -- handle with glyphs
                    local sk = start.kern
                    if sk > 0 then
                        start.kern = sk*krn
                        done = true
                    end
                elseif lastfont and (id == hlist_code or id == vlist_code) then -- todo: lookahead
                    local p = start.prev
                    if p and p.id ~= glue_code then
                        insert_node_before(head,start,new_kern(quaddata[lastfont]*krn))
                        done = true
                    end
                    local n = start.next
                    if n and n.id ~= glue_code then
                        insert_node_after(head,start,new_kern(quaddata[lastfont]*krn))
                        done = true
                    end
                end
            end
        end
        if start then
            start = start.next
        end
    end
    return head, done
end

local enabled = false

function kerns.set(factor)
    if not enabled then
        tasks.enableaction("processors","typesetters.kerns.handler")
        enabled = true
    end
    if factor ~= 0 then
        local a = factors[factor]
        if not a then
            a = #mapping + 1
            factors[factors], mapping[a] = a, factor
        end
        factor = a
    end
    texattribute[a_kerns] = factor
    return factor
end

local function process(namespace,attribute,head)
    return do_process(namespace,attribute,head)  -- no direct map, because else fourth argument is tail == true
end

kerns.handler = nodes.installattributehandler {
    name     = "kern",
    namespace = kerns,
    processor = process,
}
