if not modules then modules = { } end modules ['syst-aux'] = {
    version   = 1.001,
    comment   = "companion to syst-aux.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

function commands.getfirstcharacter(str)
    local first, rest = utf.match(str,"(.?)(.*)$")
    context.setvalue("firstcharacter",first)
    context.setvalue("remainingcharacters",rest)
end

function commands.doiffirstcharelse(chr,str)
    commands.doifelse(utf.sub(str,1,1) == chr)
end
