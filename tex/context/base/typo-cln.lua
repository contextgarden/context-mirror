if not modules then modules = { } end modules ['typo-cap'] = {
    version   = 1.001,
    comment   = "companion to typo-cap.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This quick and dirty hack took less time than listening to a CD (In
-- this case Dream Theaters' Octavium. Of course extensions will take
-- more time.

local utfbyte = utf.byte

local trace_cleaners = false  trackers.register("typesetters.cleaners",         function(v) trace_cleaners = v end)
local trace_autocase = false  trackers.register("typesetters.cleaners.autocase",function(v) trace_autocase = v end)

local report_cleaners = logs.reporters("nodes","cleaners")
local report_autocase = logs.reporters("nodes","autocase")

typesetters.cleaners  = typesetters.cleaners or { }
local cleaners        = typesetters.cleaners

local nodecodes       = nodes.nodecodes
local tasks           = nodes.tasks

local texattribute    = tex.attribute

local has_attribute   = node.has_attribute
local traverse_id     = node.traverse_id

local glyph_code      = nodecodes.glyph
local uccodes         = characters.uccodes

local a_cleaner      = attributes.private("cleaner")

local resetter = { -- this will become an entry in char-def
    [utfbyte(".")] = true
}

-- Contrary to the casing code we need to keep track of a state.
-- We could extend the casing code with a status tracker but on
-- the other hand we might want to apply casing afterwards. So,
-- cleaning comes first.

local function process(namespace,attribute,head)
    local inline, done = false, false
    for n in traverse_id(glyph_code,head) do
        local char = n.char
        if resetter[char] then
            inline = false
        elseif not inline then
            local a = has_attribute(n,attribute)
            if a == 1 then -- currently only one cleaner so no need to be fancy
                local upper = uccodes[char]
                n.char = upper
                inline = true
                done = true
                if trace_autocase then
                    report_autocase("")
                end
            end
        end
    end
    return head, done
end

-- see typo-cap for a more advanced settings handler .. now needed now

local enabled = false

function cleaners.set(n)
    if not enabled then
        tasks.enableaction("processors","typesetters.cleaners.handler")
        if trace_cleaners then
            report_cleaners("enabling cleaners")
        end
        enabled = true
    end
    texattribute[a_cleaner] = n
end

cleaners.handler = nodes.installattributehandler {
    name      = "cleaner",
    namespace = cleaners,
    processor = process,
}
