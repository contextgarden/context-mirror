-- filename : spec-pdf.lua
-- comment  : companion to spec-fdf.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not pdf then pdf = { } end

function pdf.cleandestination(str)
    tex.sprint((string.gsub(str,"[%/%#%<%>%[%]%(%)%-%s]+","-")))
end

if not pdf then pdf = { } end

function pdf.cleandestination(str)
    tex.sprint((string.gsub(str,"[%/%#%<%>%[%]%(%)%-%s]+","-")))
end

function pdf.santizedstring(str)
    tex.sprint((string.gsub(str,"([\\/#<>%[%]%(%)])","\\%1")))
end
