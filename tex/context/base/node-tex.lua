if not modules then modules = { } end modules ['node-tex'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

builders        = builders        or { }
builders.kernel = builders.kernel or { }
local kernel    = builders.kernel

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming
local hyphenate, ligaturing, kerning = lang.hyphenate, node.ligaturing, node.kerning

function kernel.hyphenation(head)
    --  starttiming(kernel)
    local done = hyphenate(head)
    --  stoptiming(kernel)
    return head, done
end

function kernel.ligaturing(head)
    --  starttiming(kernel)
    local head, tail, done = ligaturing(head) -- todo: check what is returned
    --  stoptiming(kernel)
    return head, done
end

function kernel.kerning(head)
    --  starttiming(kernel)
    local head, tail, done = kerning(head) -- todo: check what is returned
    --  stoptiming(kernel)
    return head, done
end

callbacks.register('hyphenate' , false, "normal hyphenation routine, called elsewhere")
callbacks.register('ligaturing', false, "normal ligaturing routine, called elsewhere")
callbacks.register('kerning'   , false, "normal kerning routine, called elsewhere")
