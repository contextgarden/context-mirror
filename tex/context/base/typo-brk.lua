if not modules then modules = { } end modules ['typo-brk'] = {
    version   = 1.001,
    comment   = "companion to typo-brk.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon

local next, type = next, type
local format = string.format

local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local set_attribute      = node.set_attribute
local copy_node          = node.copy
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local make_penalty_node  = nodes.penalty
local make_glue_node     = nodes.glue
local make_disc_node     = nodes.disc

local glyph   = node.id("glyph")
local kern    = node.id("kern")

breakpoints         = breakpoints         or { }
breakpoints.mapping = breakpoints.mapping or { }
breakpoints.methods = breakpoints.methods or { }
breakpoints.enabled = false

storage.register("breakpoints/mapping", breakpoints.mapping, "breakpoints.mapping")

local mapping = breakpoints.mapping

function breakpoints.setreplacement(id,char,kind,before,after,language)
    local map = mapping[id]
    if not map then
        map = { }
        mapping[id] = map
    end
    local cmap = map[char]
    if not cmap then
        cmap = { }
        map[char] = cmap
    end
    cmap[language or ""] = { kind or 1, before or 1, after or 1 }
end

breakpoints.methods[1] = function(head,start)
    if start.prev and start.next then
        insert_node_before(head,start,make_penalty_node(10000))
        insert_node_before(head,start,make_glue_node(0))
        insert_node_after(head,start,make_glue_node(0))
        insert_node_after(head,start,make_penalty_node(0))
    end
    return head, start
end
breakpoints.methods[2] = function(head,start) -- ( => (-
    if start.prev and start.next then
        local tmp = start
        start = make_disc_node()
        start.prev, start.next = tmp.prev, tmp.next
        tmp.prev.next, tmp.next.prev = start, start
        tmp.prev, tmp.next = nil, nil
        start.replace = tmp
        local tmp, hyphen = copy_node(tmp), copy_node(tmp)
        hyphen.char = languages.prehyphenchar(tmp.lang)
        tmp.next, hyphen.prev = hyphen, tmp
        start.post = tmp
        insert_node_before(head,start,make_penalty_node(10000))
        insert_node_before(head,start,make_glue_node(0))
        insert_node_after(head,start,make_glue_node(0))
        insert_node_after(head,start,make_penalty_node(10000))
    end
    return head, start
end
breakpoints.methods[3] = function(head,start) -- ) => -)
    if start.prev and start.next then
        local tmp = start
        start = make_disc_node()
        start.prev, start.next = tmp.prev, tmp.next
        tmp.prev.next, tmp.next.prev = start, start
        tmp.prev, tmp.next = nil, nil
        start.replace = tmp
        local tmp, hyphen = copy_node(tmp), copy_node(tmp)
        hyphen.char = languages.prehyphenchar(tmp.lang)
        tmp.prev, hyphen.next = hyphen, tmp
        start.pre = hyphen
        insert_node_before(head,start,make_penalty_node(10000))
        insert_node_before(head,start,make_glue_node(0))
        insert_node_after(head,start,make_glue_node(0))
        insert_node_after(head,start,make_penalty_node(10000))
    end
    return head, start
end
breakpoints.methods[4] = function(head,start) -- - => - - -
    if start.prev and start.next then
        local tmp = start
        start = make_disc_node()
        start.prev, start.next = tmp.prev, tmp.next
        tmp.prev.next, tmp.next.prev = start, start
        tmp.prev, tmp.next = nil, nil
        -- maybe prehyphenchar etc
        start.pre = copy_node(tmp)
        start.post = copy_node(tmp)
        start.replace = tmp
        insert_node_before(head,start,make_penalty_node(10000))
        insert_node_before(head,start,make_glue_node(0))
        insert_node_after(head,start,make_glue_node(0))
        insert_node_after(head,start,make_penalty_node(10000))
    end
    return head, start
end

function breakpoints.process(namespace,attribute,head)
    local done, numbers = false,  languages.numbers
    local start, n = head, 0
    while start do
        local id = start.id
        if id == glyph then
            local attr = has_attribute(start,attribute)
            if attr and attr > 0 then
                unset_attribute(start,attribute) -- maybe test for subtype > 256 (faster)
                -- look ahead and back n chars
                local map = mapping[attr]
                if map then
                    local cmap = map[start.char]
                    if cmap then
                        local smap = cmap[numbers[start.lang]] or cmap[""]
                        if smap then
                            if n >= smap[2] then
                                local m = smap[3]
                                local next = start.next
                                while next do -- gamble on same attribute
                                    local id = next.id
                                    if id == glyph then -- gamble on same attribute
                                        if map[next.char] then
                                            break
                                        elseif m == 1 then
                                            local method = breakpoints.methods[smap[1]]
                                            if method then
                                                head, start = method(head,start)
                                                done = true
                                            end
                                            break
                                        else
                                            m = m - 1
                                            next = next.next
                                        end
                                    elseif id == kern and next.subtype == 0 then
                                        next = next.next
                                        -- ignore intercharacter kerning, will go way
                                    else
                                        -- we can do clever and set n and jump ahead but ... not now
                                        break
                                    end
                                end
                            end
                            n = 0
                        else
                            n = n + 1
                        end
                    else
                         n = n + 1
                    end
                else
                    n = 0
                end
            end
        elseif id == kern and start.subtype == 0 then
            -- ignore intercharacter kerning, will go way
        else
            n = 0
        end
        start = start.next
    end
    return head, done
end

chars.handle_breakpoints = nodes.install_attribute_handler {
    name = "breakpoint",
    namespace = breakpoints,
    processor = breakpoints.process,
    }
