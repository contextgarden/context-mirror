-- filename : luat-uni.lua
-- comment  : companion to luat-uni.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-uni'] = 1.001

function unicode.utf8.split(str)
    lst = { }
 -- for snippet in unicode.utf8.gfind(str,".") do
    for snippet in string.utfcharacters(str) do
        table.insert(lst,snippet)
    end
    return lst
end

function unicode.utf8.each(str,fnc)
 -- for snippet in unicode.utf8.gfind(str,".") do
    for snippet in string.utfcharacters(str) do
        fnc(snippet)
    end
end
