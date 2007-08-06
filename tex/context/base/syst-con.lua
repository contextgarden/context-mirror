-- filename : syst-con.lua
-- comment  : companion to syst-con.tex (in ConTeXt)
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- remark   : compact version

if not versions then versions = { } end versions['syst-con'] = 1.001
if not convert  then convert  = { } end

-- For raw 8 bit characters, the offset is 0x110000 (bottom of plane 18)
-- at the top of luatex's char range but outside the unicode range.

function convert.lchexnumber      (n) tex.sprint(string.format("%x"  ,n)) end
function convert.uchexnumber      (n) tex.sprint(string.format("%X"  ,n)) end
function convert.lchexnumbers     (n) tex.sprint(string.format("%02x",n)) end
function convert.uchexnumbers     (n) tex.sprint(string.format("%02X",n)) end
function convert.octnumber        (n) tex.sprint(string.format("%03o",n)) end
function convert.hexstringtonumber(n) tex.sprint(tonumber(n,16))          end
function convert.octstringtonumber(n) tex.sprint(tonumber(n, 8))          end
function convert.rawcharacter     (n) tex.sprint(unicode.utf8.char(0x110000+n))  end

do
    local char  = unicode.utf8.char
    local flush = tex.sprint

    function convert.rawcharacter(n) flush(char(0x110000+n)) end

end
