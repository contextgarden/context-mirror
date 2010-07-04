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

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local find_node_tail     = node.tail or node.slide
local free_node          = node.free
local copy_node          = node.copy
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local make_glue_spec     = nodes.glue_spec
local make_kern_node     = nodes.kern

local glyph = node.id("glyph")
local kern  = node.id("kern")
local disc  = node.id('disc')
local glue  = node.id('glue')
local hlist = node.id('hlist')
local vlist = node.id('vlist')

local fontdata = fonts.identifiers
local chardata = fonts.characters
local quaddata = fonts.quads

kerns           = kerns or { }
kerns.mapping   = kerns.mapping or { }
kerns.factors   = kerns.factors or { }
kerns.attribute = attributes.private("kern")

storage.register("kerns/mapping", kerns.mapping, "kerns.mapping")
storage.register("kerns/factors", kerns.factors, "kerns.factors")

local mapping = kerns.mapping
local factors = kerns.factors

function kerns.setspacing(factor)
    local a = factors[factor]
    if not a then
        a = #mapping + 1
        factors[factors], mapping[a] = a, factor
    end
    tex.attribute[kerns.attribute] = a
    return a
end

-- one must use liga=no and mode=base and kern=yes
-- use more helpers
-- make sure it runs after all others
-- there will be a width adaptor field in nodes so this will change
-- todo: interchar kerns / disc nodes / can be made faster

local function process(namespace,attribute,head,force)
    local scale = tex.scale -- will go
    local start, done, lastfont = head, false, nil
    while start do
        -- faster to test for attr first
        local attr = force or has_attribute(start,attribute)
        if attr and attr > 0 then
            unset_attribute(start,attribute)
            local krn = mapping[attr]
            if krn and krn ~= 0 then
                local id = start.id
                if id == glyph then
                    lastfont = start.font
                    local c = start.components
                    if c then
                        local s = start
                        local tail = find_node_tail(c)
                        if s.prev then
                            s.prev.next = c
                            c.prev = s.prev
                        else
                            head = c
                        end
                        if s.next then
                            s.next.prev = tail
                        end
                        tail.next = s.next
                        start = c
                        start.attr = s.attr
                        s.attr = nil
                        s.components = nil
                        free_node(s)
                        done = true
                    end
                    local prev = start.prev
                    if prev then
                        local pid = prev.id
                        if not pid then
                            -- nothing
                        elseif pid == kern and prev.subtype == 0 then
                            prev.subtype = 1
                            prev.kern = prev.kern + scale(quaddata[lastfont],krn)
                            done = true
                        elseif pid == glyph then
                            if prev.font == lastfont then
                                local prevchar, lastchar = prev.char, start.char
                                local kerns = chardata[lastfont][prevchar].kerns
                                local kern = kerns and kerns[lastchar] or 0
                                krn = scale(kern+quaddata[lastfont],krn)
                            else
                                krn = scale(quaddata[lastfont],krn)
                            end
                            insert_node_before(head,start,make_kern_node(krn))
                            done = true
                        elseif pid == disc then
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
                                pre = process(namespace,attribute,before,attr)
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
                                post = process(namespace,attribute,post,attr)
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
                                replace = process(namespace,attribute,before,attr)
                                replace = replace.next
                                replace.prev = nil
                                after.prev.next = nil
                                disc.replace = replace
                                free_node(after)
                                free_node(before)
                            else
                                if prv and prv.id == glyph and prv.font == lastfont then
                                    local prevchar, lastchar = prv.char, start.char
                                    local kerns = chardata[lastfont][prevchar].kerns
                                    local kern = kerns and kerns[lastchar] or 0
                                    krn = scale(kern+quaddata[lastfont],krn)
                                else
                                    krn = scale(quaddata[lastfont],krn)
                                end
                                disc.replace = make_kern_node(krn)
                            end
                        end
                    end
                elseif id == glue and start.subtype == 0 then
                    local s = start.spec
                    local w = s.width
                    if w > 0 then
                        local width, stretch, shrink = w+2*scale(w,krn), s.stretch, s.shrink
                        start.spec = make_glue_spec(width,scale(stretch,width/w),scale(shrink,width/w))
                    --  local width, stretch, shrink = w+2*w*krn, s.stretch, s.shrink
                    --  start.spec = make_glue_spec(width,stretch*width/w,shrink*width/w))
                        done = true
                    end
                elseif false and id == kern and start.subtype == 0 then -- handle with glyphs
                    local sk = start.kern
                    if sk > 0 then
                    --  start.kern = scale(sk,krn)
                        start.kern = sk*krn
                        done = true
                    end
                elseif lastfont and (id == hlist or id == vlist) then -- todo: lookahead
                    if start.prev then
                        insert_node_before(head,start,make_kern_node(scale(quaddata[lastfont],krn)))
                        done = true
                    end
                    if start.next then
                        insert_node_after(head,start,make_kern_node(scale(quaddata[lastfont],krn)))
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

kerns.process = function(namespace,attribute,head)
    return process(namespace,attribute,head)  -- no direct map, because else fourth argument is tail == true
end

lists.handle_kerning = nodes.install_attribute_handler {
    name = "kern",
    namespace = kerns,
    processor = kerns.process,
}

function kerns.enable()
    tasks.enableaction("processors","lists.handle_kerning")
end
