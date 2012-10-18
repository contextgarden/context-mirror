if not modules then modules = { } end modules ['cldf-com'] = {
    version   = 1.001,
    comment   = "companion to cldf-com.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tostring  = tostring
local context   = context
local generics  = context.generics -- needs documentation
local variables = interfaces.variables

generics.starttabulate = "start" .. variables.tabulate -- todo: e!start
generics.stoptabulate  = "stop"  .. variables.tabulate -- todo: e!stop

local NC, NR = context.NC, context.NR

local function tabulaterow(how,...)
    local t = { ... }
    for i=1,#t do
        local ti = tostring(t[i])
        NC()
        if how then
            context[how](ti)
        else
            context(ti)
        end
    end
    NC()
    NR()
end

function context.tabulaterow    (...) tabulaterow(false, ...) end
function context.tabulaterowbold(...) tabulaterow("bold",...) end
function context.tabulaterowtype(...) tabulaterow("type",...) end
function context.tabulaterowtyp (...) tabulaterow("typ", ...) end
