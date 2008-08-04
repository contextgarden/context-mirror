-- filename : luat-uni.lua
-- comment  : companion to luat-uni.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-uni'] = 1.001

function unicode.utf8.split(str)
    local t = { }
    for snippet in str:utfcharacters() do
        t[#t+1] = snippet
    end
    return t
end

function unicode.utf8.each(str,fnc)
    for snippet in str:utfcharacters() do
        fnc(snippet)
    end
end
