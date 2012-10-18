if not modules then modules = { } end modules ['typo-brk'] = {
    version   = 1.001,
    comment   = "companion to typo-brk.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon

local next, type, tonumber = next, type, tonumber
local utfbyte, utfchar = utf.byte, utf.char
local format = string.format

local trace_breakpoints = false  trackers.register("typesetters.breakpoints", function(v) trace_breakpoints = v end)

local report_breakpoints = logs.reporter("typesetting","breakpoints")

local nodes, node = nodes, node

local settings_to_array  = utilities.parsers.settings_to_array
local has_attribute      = node.has_attribute
local unset_attribute    = node.unset_attribute
local set_attribute      = node.set_attribute
local copy_node          = node.copy
local copy_nodelist      = node.copy_list
local free_node          = node.free
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after
local remove_node        = nodes.remove -- ! nodes
local link_nodes         = nodes.link

local texattribute       = tex.attribute
local unsetvalue         = attributes.unsetvalue

local nodepool           = nodes.pool
local tasks              = nodes.tasks

local v_reset            = interfaces.variables.reset

local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue
local new_disc           = nodepool.disc

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern

local kerning_code       = kerncodes.kerning

local typesetters        = typesetters

typesetters.breakpoints  = typesetters.breakpoints or {}
local breakpoints        = typesetters.breakpoints

breakpoints.mapping      = breakpoints.mapping or { }
breakpoints.numbers      = breakpoints.numbers or { }

breakpoints.methods      = breakpoints.methods or { }
local methods            = breakpoints.methods

local a_breakpoints      = attributes.private("breakpoint")
breakpoints.attribute    = a_breakpoints

storage.register("typesetters/breakpoints/mapping", breakpoints.mapping, "typesetters.breakpoints.mapping")

local mapping            = breakpoints.mapping
local numbers            = breakpoints.mapping

for i=1,#mapping do
    local m = mapping[i]
    numbers[m.name] = m
end

local function insert_break(head,start,before,after)
    insert_node_before(head,start,new_penalty(before))
    insert_node_before(head,start,new_glue(0))
    insert_node_after(head,start,new_glue(0))
    insert_node_after(head,start,new_penalty(after))
end

methods[1] = function(head,start)
    if start.prev and start.next then
        insert_break(head,start,10000,0)
    end
    return head, start
end

methods[2] = function(head,start) -- ( => (-
    if start.prev and start.next then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        start.attr = copy_nodelist(tmp.attr) -- todo: critical only
        start.replace = tmp
        local tmp, hyphen = copy_node(tmp), copy_node(tmp)
        hyphen.char = languages.prehyphenchar(tmp.lang)
        tmp.next, hyphen.prev = hyphen, tmp
        start.post = tmp
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[3] = function(head,start) -- ) => -)
    if start.prev and start.next then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        start.attr = copy_nodelist(tmp.attr) -- todo: critical only
        start.replace = tmp
        local tmp, hyphen = copy_node(tmp), copy_node(tmp)
        hyphen.char = languages.prehyphenchar(tmp.lang)
        tmp.prev, hyphen.next = hyphen, tmp
        start.pre = hyphen
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[4] = function(head,start) -- - => - - -
    if start.prev and start.next then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        start.attr = copy_nodelist(tmp.attr) -- todo: critical only
        start.pre, start.post, start.replace = copy_node(tmp), copy_node(tmp), tmp
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[5] = function(head,start,settings) -- x => p q r
    if start.prev and start.next then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        local attr = tmp.attr
        start.attr = copy_nodelist(attr) -- todo: critical only
        start.pre = link_nodes(settings.right,tmp,attr)
        start.post = link_nodes(settings.left,tmp,attr)
        start.replace = link_nodes(settings.middle,tmp,attr)
        free_node(tmp)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

local function process(namespace,attribute,head)
    local done, numbers = false,  languages.numbers
    local start, n = head, 0
    while start do
        local id = start.id
        if id == glyph_code then
            local attr = has_attribute(start,a_breakpoints)
            if attr and attr > 0 then
                unset_attribute(start,a_breakpoints) -- maybe test for subtype > 256 (faster)
                -- look ahead and back n chars
                local data = mapping[attr]
                if data then
                    local map = data.characters
                    local cmap = map[start.char]
                    if cmap then
                        local lang = start.lang
                        -- we do a sanity check for language
                        local smap = lang and lang >= 0 and lang < 0x7FFF and (cmap[numbers[lang]] or cmap[""])
                        if smap then
                            if n >= smap.nleft then
                                local m = smap.nright
                                local next = start.next
                                while next do -- gamble on same attribute (not that important actually)
                                    local id = next.id
                                    if id == glyph_code then -- gamble on same attribute (not that important actually)
                                        if map[next.char] then
                                            break
                                        elseif m == 1 then
                                            local method = methods[smap.type]
                                            if method then
                                                head, start = method(head,start,smap)
                                                done = true
                                            end
                                            break
                                        else
                                            m = m - 1
                                            next = next.next
                                        end
                                    elseif id == kern_code and next.subtype == kerning_code then
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
            else
             -- n = n + 1 -- if we want single char handling (|-|) then we will use grouping and then we need this
            end
        elseif id == kern_code and start.subtype == kerning_code then
            -- ignore intercharacter kerning, will go way
        else
            n = 0
        end
        start = start.next
    end
    return head, done
end

local enabled = false

function breakpoints.define(name)
    local data = numbers[name]
    if data then
        -- error
    else
        local number = #mapping + 1
        local data = {
            name       = name,
            number     = number,
            characters = { },
        }
        mapping[number] = data
        numbers[name]   = data
    end
end

function breakpoints.setreplacement(name,char,language,settings)
    char = utfbyte(char)
    local data = numbers[name]
    if data then
        local characters = data.characters
        local cmap = characters[char]
        if not cmap then
            cmap = { }
            characters[char] = cmap
        end
        local left, right, middle = settings.left, settings.right, settings.middle
        cmap[language or ""] = {
            type   = tonumber(settings.type)   or 1,
            nleft  = tonumber(settings.nleft)  or 1,
            nright = tonumber(settings.nright) or 1,
            left   = left   ~= "" and left     or nil,
            right  = right  ~= "" and right    or nil,
            middle = middle ~= "" and middle   or nil,
        } -- was { type or 1, before or 1, after or 1 }
    end
end

function breakpoints.set(n)
    if n == v_reset then
        n = unsetvalue
    else
        n = mapping[n]
        if not n then
            n = unsetvalue
        else
            if not enabled then
                if trace_breakpoints then
                    report_breakpoints("enabling breakpoints handler")
                end
                tasks.enableaction("processors","typesetters.breakpoints.handler")
            end
            n = n.number
        end
    end
    texattribute[a_breakpoints] = n
end

breakpoints.handler = nodes.installattributehandler {
    name      = "breakpoint",
    namespace = breakpoints,
    processor = process,
}

-- function breakpoints.enable()
--     tasks.enableaction("processors","typesetters.breakpoints.handler")
-- end

-- interface

commands.definebreakpoints = breakpoints.define
commands.definebreakpoint  = breakpoints.setreplacement
commands.setbreakpoints    = breakpoints.set
