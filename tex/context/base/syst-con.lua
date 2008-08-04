if not modules then modules = { } end modules ['syst-con'] = {
    version   = 1.001,
    comment   = "companion to syst-con.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

converters = converters or { }

--[[ldx--
<p>For raw 8 bit characters, the offset is 0x110000 (bottom of plane 18) at
the top of <l n='luatex'/>'s char range but outside the unicode range.</p>
--ldx]]--

do
    local char, texsprint, format = unicode.utf8.char, tex.sprint, string.format

    function converters.hexstringtonumber(n) texsprint(tonumber(n,16))   end
    function converters.octstringtonumber(n) texsprint(tonumber(n, 8))   end
    function converters.rawcharacter     (n) texsprint(char(0x110000+n)) end

    function converters.lchexnumber      (n) texsprint(format("%x"  ,n)) end
    function converters.uchexnumber      (n) texsprint(format("%X"  ,n)) end
    function converters.lchexnumbers     (n) texsprint(format("%02x",n)) end
    function converters.uchexnumbers     (n) texsprint(format("%02X",n)) end
    function converters.octnumber        (n) texsprint(format("%03o",n)) end

    function converters.lchexnumber      (n) texsprint(("%x"  ):format(n)) end
    function converters.uchexnumber      (n) texsprint(("%X"  ):format(n)) end
    function converters.lchexnumbers     (n) texsprint(("%02x"):format(n)) end
    function converters.uchexnumbers     (n) texsprint(("%02X"):format(n)) end
    function converters.octnumber        (n) texsprint(("%03o"):format(n)) end

end
