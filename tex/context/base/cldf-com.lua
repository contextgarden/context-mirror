if not modules then modules = { } end modules ['cldf-com'] = {
    version   = 1.001,
    comment   = "companion to cldf-com.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tostring, type = tostring, type
local format = string.format

local context   = context
local generics  = context.generics
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

-- these will move up, just after cld definitions

function context.char(k) -- todo: if catcode == letter or other then just the utf
    if type(k) == "table" then
        for i=1,#k do
            context(format([[\char%s\relax]],k[i]))
        end
    elseif k then
        context(format([[\char%s\relax]],k))
    end
end

function context.utfchar(k)
    context(utfchar(k))
end

-- plain variants

function context.chardef(cs,u)
    context(format([[\chardef\%s=%s\relax]],k)) -- context does already do format
end

function context.par()
    context([[\par]]) -- no need to add {} there
end

function context.bgroup()
    context("{")
end

function context.egroup()
    context("}")
end

local rule = nodes.pool.rule

function context.hrule(w,h,d,dir)
    if type(w) == "table" then
        context(rule(w.width,w.height,w.depth,w.dir))
    else
        context(rule(w,h,d,dir))
    end
end

context.vrule = context.hrule

--~ local hbox, bgroup, egroup = context.hbox, context.bgroup, context.egroup

--~ function context.hbox(a,...)
--~     if type(a) == "table" then
--~         local s = { }
--~         if a.width then
--~             s[#s+1] = "to " .. a.width -- todo: check for number
--~         elseif a.spread then
--~             s[#s+1] = "spread " .. a.spread -- todo: check for number
--~         end
--~         -- todo: dir, attr etc
--~         hbox(false,table.concat(s," "))
--~         bgroup()
--~         context(string.format(...))
--~         egroup()
--~     else
--~         hbox(a,...)
--~     end
--~ end
