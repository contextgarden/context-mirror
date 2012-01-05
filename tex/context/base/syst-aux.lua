if not modules then modules = { } end modules ['syst-aux'] = {
    version   = 1.001,
    comment   = "companion to syst-aux.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local settings_to_array = utilities.parsers.settings_to_array
local concat = table.concat

local setvalue = context.setvalue

function commands.getfirstcharacter(str)
    local first, rest = utf.match(str,"(.?)(.*)$")
    setvalue("firstcharacter",first)
    setvalue("remainingcharacters",rest)
end

function commands.doiffirstcharelse(chr,str)
    commands.doifelse(utf.sub(str,1,1) == chr)
end

-- function commands.addtocommalist(list,item)
--     if list == "" then
--         context(item)
--     else
--         context("%s,%s",list,item) -- using tex.print is some 10% faster
--     end
-- end
--
-- function commands.removefromcommalist(list,item)
--     if list == "" then
--         context(item)
--     else
--         -- okay, using a proper lpeg is probably faster
--         -- we could also check for #l = 1
--         local l = settings_to_array(list)
--         local t, n = { }
--         for i=1,#l do
--             if l[i] ~= item then
--                 n = n + 1
--                 t[n] = item
--             end
--         end
--         if n == 0 then
--             context(item)
--         else
--             context(concat(list,","))
--         end
--     end
-- end
