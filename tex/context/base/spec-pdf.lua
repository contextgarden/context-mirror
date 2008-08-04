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

local char, byte, format = string.char, string.byte, string.format
local texsprint, texwrite = tex.sprint, tex.write

pdf = pdf or { }

function pdf.cleandestination(str)
    texsprint((str:gsub("[%/%#%<%>%[%]%(%)%-%s]+","-")))
end

function pdf.cleandestination(str)
    texsprint((str:gsub("[%/%#%<%>%[%]%(%)%-%s]+","-")))
end

function pdf.sanitizedstring(str)
    texsprint((str:gsub("([\\/#<>%[%]%(%)])","\\%1")))
end

--~ function pdf.hexify(str)
--~     texwrite("feff" .. utf.gsub(str,".",function(c)
--~         local b = byte(c)
--~ 		if b < 0x10000 then
--~             return ("%04x"):format(b)
--~         else
--~             return ("%04x%04x"):format(b/1024+0xD800,b%1024+0xDC00)
--~         end
--~     end))
--~ end

function pdf.hexify(str)
    texwrite("feff")
    for b in str:utfvalues() do
		if b < 0x10000 then
            texwrite(("%04x"):format(b))
        else
            texwrite(("%04x%04x"):format(b/1024+0xD800,b%1024+0xDC00))
        end
    end
end

function pdf.utf8to16(s,offset) -- derived from j. sauter's post on the list
    offset = (offset and 0x110000) or 0 -- so, only an offset when true
	texwrite(char(offset+254,offset+255))
	for c in string.utfvalues(s) do
		if c < 0x10000 then
			texwrite(char(offset+c/256,offset+c%256))
		else
			c = c - 0x10000
			local c1, c2 = c / 1024 + 0xD800, c % 1024 + 0xDC00
			texwrite(char(offset+c1/256,offset+c1%256,offset+c2/256,offset+c2%256))
		end
	end
end
