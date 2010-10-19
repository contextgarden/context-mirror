if not modules then modules = { } end modules ['cldf-ver'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat

local context = context

function table.tocontext(...)
    local function flush(...)
        context(concat{...,"\n"})
    end
    context.starttyping()
    context.pushcatcodes("verbatim")
    table.tohandle(flush,...)
    context.stoptyping()
    context.popcatcodes()
end
