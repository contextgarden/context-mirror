if not modules then modules = { } end modules ['cldf-ver'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat, tohandle = table.concat, table.tohandle
local tostring, type = tostring, type

local context = context

local function flush(...)
    context(concat{...,"\n"})
end

local function t_tocontext(...)
    context.starttyping { "typing" } -- else [1] is intercepted
    context.pushcatcodes("verbatim")
    tohandle(flush,...)
    context.stoptyping()
    context.popcatcodes()
end

local function s_tocontext(...) -- we need to catch {\}
    context.type()
    context("{")
    context.pushcatcodes("verbatim")
    context(concat({...}," "))
    context.popcatcodes()
    context("}")
end

local function b_tocontext(b)
    s_tocontext(tostring(b))
end

table  .tocontext = t_tocontext
string .tocontext = s_tocontext
boolean.tocontext = b_tocontext

function tocontext(first,...)
    local t = type(first)
    if t == "string" then
        s_tocontext(first,...)
    elseif t == "table" then
        t_tocontext(first,...)
    elseif t == "boolean" then
        b_tocontext(first,...)
    end
end
