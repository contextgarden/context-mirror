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
    local char, flush, format = unicode.utf8.char, tex.sprint, string.format

    function converters.hexstringtonumber(n) flush(tonumber(n,16))   end
    function converters.octstringtonumber(n) flush(tonumber(n, 8))   end
    function converters.rawcharacter     (n) flush(char(0x110000+n)) end

    function converters.lchexnumber      (n) flush(format("%x"  ,n)) end
    function converters.uchexnumber      (n) flush(format("%X"  ,n)) end
    function converters.lchexnumbers     (n) flush(format("%02x",n)) end
    function converters.uchexnumbers     (n) flush(format("%02X",n)) end
    function converters.octnumber        (n) flush(format("%03o",n)) end

    function converters.lchexnumber      (n) flush(("%x"  ):format(n)) end
    function converters.uchexnumber      (n) flush(("%X"  ):format(n)) end
    function converters.lchexnumbers     (n) flush(("%02x"):format(n)) end
    function converters.uchexnumbers     (n) flush(("%02X"):format(n)) end
    function converters.octnumber        (n) flush(("%03o"):format(n)) end

end
