if not modules then modules = { } end modules ['spec-pdf'] = {
    version   = 1.001,
    comment   = "companion to spec-fdf.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module implements a couple of cleanup methods. We need these
in order to meet the <l n='pdf'/> specification. Watch the double
parenthesis; they are needed because otherwise we would pass more
than one argument to <l n='tex'/>.</p>
--ldx]]--

pdf = pdf or { }

function pdf.cleandestination(str)
    tex.sprint((str:gsub("[%/%#%<%>%[%]%(%)%-%s]+","-")))
end

function pdf.cleandestination(str)
    tex.sprint((str:gsub("[%/%#%<%>%[%]%(%)%-%s]+","-")))
end

function pdf.santizedstring(str)
    tex.sprint((str:gsub("([\\/#<>%[%]%(%)])","\\%1")))
end
