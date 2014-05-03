if not modules then modules = { } end modules ['typo-tal'] = {
    version   = 1.001,
    comment   = "companion to typo-tal.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- I'll make it a bit more efficient and provide named instances too.

local next, type = next, type
local div = math.div
local utfbyte = utf.byte

local nodecodes            = nodes.nodecodes
local glyph_code           = nodecodes.glyph
local glue_code            = nodecodes.glue

local fontcharacters       = fonts.hashes.characters
local unicodes             = fonts.hashes.unicodes
local categories           = characters.categories -- nd

local insert_node_before   = nodes.insert_before
local insert_node_after    = nodes.insert_after
local traverse_list_by_id  = nodes.traverse_id
local dimensions_of_list   = nodes.dimensions
local first_glyph          = nodes.first_glyph

local nodepool             = nodes.pool
local new_kern             = nodepool.kern
local new_gluespec         = nodepool.gluespec

local tracers              = nodes.tracers
local setcolor             = tracers.colors.set
local tracedrule           = tracers.pool.nodes.rule

local characteralign       = { }
typesetters.characteralign = characteralign

local trace_split          = false  trackers.register("typesetters.characteralign", function(v) trace_split = true end)
local report               = logs.reporter("aligning")

local a_characteralign     = attributes.private("characteralign")
local a_character          = attributes.private("characters")

local enabled              = false

local datasets             = false

local comma                = 0x002C
local period               = 0x002E
local punctuationspace     = 0x2008

local validseparators = {
    [comma]            = true,
    [period]           = true,
    [punctuationspace] = true,
}

local validsigns = {
    [0x002B] = 0x002B, -- plus
    [0x002D] = 0x2212, -- hyphen
    [0x00B1] = 0x00B1, -- plusminus
    [0x2212] = 0x2212, -- minus
    [0x2213] = 0x2213, -- minusplus
}

local function traced_kern(w)
    return tracedrule(w,nil,nil,"darkgray")
end

function characteralign.handler(head,where)
    if not datasets then
        return head, false
    end
 -- local first = first_glyph(head) -- we could do that once
    local first
    for n in traverse_list_by_id(glyph_code,head) do
        first = n
        break
    end
    if not first then
        return head, false
    end
    local a = first[a_characteralign]
    if not a or a == 0 then
        return head, false
    end
    local column    = div(a,100)
    local row       = a % 100
    local dataset   = datasets and datasets[column] or setcharacteralign(column)
    local separator = dataset.separator
    local list      = dataset.list
    local b_start   = nil
    local b_stop    = nil
    local a_start   = nil
    local a_stop    = nil
    local c         = nil
    local current   = first
    local sign      = nil
    -- we can think of constraints
    while current do
        local id = current.id
        if id == glyph_code then
            local char = current.char
            local font = current.font
            local unicode = unicodes[font][char]
            if not unicode then
                -- no unicode so forget about it
            elseif unicode == separator then
                c = current
                if trace_split then
                    setcolor(current,"darkred")
                end
                dataset.hasseparator = true
            elseif categories[unicode] == "nd" or validseparators[unicode] then
                if c then
                    if not a_start then
                        a_start = current
                    end
                    a_stop = current
                    if trace_split then
                        setcolor(current,validseparators[unicode] and "darkcyan" or "darkblue")
                    end
                else
                    if not b_start then
                        if sign then
                            b_start = sign
                            local new = validsigns[sign.char]
                            if char == new or not fontcharacters[sign.font][new] then
                                if trace_split then
                                    setcolor(sign,"darkyellow")
                                end
                            else
                                sign.char = new
                                if trace_split then
                                    setcolor(sign,"darkmagenta")
                                end
                            end
                            sign = nil
                            b_stop = current
                        else
                            b_start = current
                            b_stop = current
                            if trace_split then
                                setcolor(current,validseparators[unicode] and "darkcyan" or "darkblue")
                            end
                        end
                    else
                        b_stop = current
                        if trace_split then
                            setcolor(current,validseparators[unicode] and "darkcyan" or "darkblue")
                        end
                    end
                end
            elseif not b_start then
                sign = validsigns[unicode] and current
            end
        elseif (b_start or a_start) and id == glue_code then
            -- somewhat inefficient
            local next = current.next
            local prev = current.prev
            if next and prev and next.id == glyph_code and prev.id == glyph_code then -- too much checking
                local width = fontcharacters[b_start.font][separator or period].width
             -- local spec = current.spec
             -- nodes.free(spec) -- hm, we leak but not that many specs
                current.spec = new_gluespec(width)
                current[a_character] = punctuationspace
                if a_start then
                    a_stop = current
                elseif b_start then
                    b_stop = current
                end
            end
        end
        current = current.next
    end
    local entry = list[row]
    if entry then
        if not dataset.collected then
         -- print("[maxbefore] [maxafter]")
            local maxbefore = 0
            local maxafter  = 0
            for k, v in next, list do
                local before = v.before
                local after  = v.after
                if before and before > maxbefore then
                    maxbefore = before
                end
                if after and after > maxafter then
                    maxafter = after
                end
            end
            dataset.maxbefore = maxbefore
            dataset.maxafter  = maxafter
            dataset.collected = true
        end
        local maxbefore = dataset.maxbefore
        local maxafter  = dataset.maxafter
        local before    = entry.before or 0
        local after     = entry.after  or 0
        local new_kern = trace_split and traced_kern or new_kern
        if b_start then
            if before < maxbefore then
                head = insert_node_before(head,b_start,new_kern(maxbefore-before))
            end
            if not c then
             -- print("[before]")
                if dataset.hasseparator then
                    local width = fontcharacters[b_stop.font][separator].width
                    insert_node_after(head,b_stop,new_kern(maxafter+width))
                end
            elseif a_start then
             -- print("[before] [separator] [after]")
                if after < maxafter then
                    insert_node_after(head,a_stop,new_kern(maxafter-after))
                end
            else
             -- print("[before] [separator]")
                if maxafter > 0 then
                    insert_node_after(head,c,new_kern(maxafter))
                end
            end
        elseif a_start then
            if c then
             -- print("[separator] [after]")
                if maxbefore > 0 then
                    head = insert_node_before(head,c,new_kern(maxbefore))
                end
            else
             -- print("[after]")
                local width = fontcharacters[b_stop.font][separator].width
                head = insert_node_before(head,a_start,new_kern(maxbefore+width))
            end
            if after < maxafter then
                insert_node_after(head,a_stop,new_kern(maxafter-after))
            end
        elseif c then
         -- print("[separator]")
            if maxbefore > 0 then
                head = insert_node_before(head,c,new_kern(maxbefore))
            end
            if maxafter > 0 then
                insert_node_after(head,c,new_kern(maxafter))
            end
        end
    else
        entry = {
            before = b_start and dimensions_of_list(b_start,b_stop.next) or 0,
            after  = a_start and dimensions_of_list(a_start,a_stop.next) or 0,
        }
        list[row] = entry
    end
    return head, true
end

function setcharacteralign(column,separator)
    if not enabled then
        nodes.tasks.enableaction("processors","typesetters.characteralign.handler")
        enabled = true
    end
    if not datasets then
        datasets = { }
    end
    local dataset = datasets[column] -- we can use a metatable
    if not dataset then
        dataset = {
            separator = separator and utfbyte(separator) or comma,
            list      = { },
            maxafter  = 0,
            maxbefore = 0,
            collected = false,
        }
        datasets[column] = dataset
        used = true
    end
    return dataset
end

local function resetcharacteralign()
    datasets = false
end

characteralign.setcharacteralign   = setcharacteralign
characteralign.resetcharacteralign = resetcharacteralign

commands.setcharacteralign         = setcharacteralign
commands.resetcharacteralign       = resetcharacteralign

