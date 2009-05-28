if not modules then modules = { } end modules ['node-tex'] = {
    version   = 1.001,
    comment   = "companion to node-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

kernel = kernel or { }

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming
local hyphenate, ligaturing, kerning = lang.hyphenate, node.ligaturing, node.kerning

function kernel.hyphenation(head,tail) -- lang.hyphenate returns done
    if head == tail then
        return head, tail, false
    else
    --  starttiming(kernel)
    --  local done = hyphenate(head,tail)
    --  stoptiming(kernel)
    --  return head, tail, done
        return head, tail, hyphenate(head,tail)
    end
end

function kernel.ligaturing(head,tail) -- node.ligaturing returns head,tail,done
    if head == tail then
        return head, tail, false
    else
    --  starttiming(kernel)
    --  local head, tail, done = ligaturing(head,tail)
    --  stoptiming(kernel)
    --  return head, tail, done
        return ligaturing(head,tail)
    end
end

function kernel.kerning(head,tail) -- node.kerning returns head,tail,done
    if head == tail then
        return head, tail, false
    else
    --  starttiming(kernel)
    --  local head, tail, done = kerning(head,tail)
    --  stoptiming(kernel)
    --  return head, tail, done
        return kerning(head,tail)
    end
end

callback.register('hyphenate' , false)
callback.register('ligaturing', false)
callback.register('kerning'   , false)
