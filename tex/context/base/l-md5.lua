-- filename : l-md5.lua
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-md5'] = 1.001

if md5 then do

    local function convert(str,fmt)
        return (string.gsub(md5.sum(str),".",function(chr) return string.format(fmt,string.byte(chr)) end))
    end

    if not md5.HEX then function md5.HEX(str) return convert(str,"%02X") end end
    if not md5.hex then function md5.hex(str) return convert(str,"%02x") end end
    if not md5.dec then function md5.dec(str) return convert(str,"%03i") end end

end end
