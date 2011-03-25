if not modules then modules = { } end modules ['symb-ini'] = {
    version   = 1.001,
    comment   = "companion to symb-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


local variables = interfaces.variables

fonts.symbols = fonts.symbols or { }
local symbols = fonts.symbols

local report_symbols = logs.reporter ("fonts","symbols")
local status_symbols = logs.messenger("fonts","symbols")

local patterns = { "symb-imp-%s.mkiv", "symb-imp-%s.tex", "symb-%s.mkiv", "symb-%s.tex" }
local listitem = utilities.parsers.listitem

function symbols.uselibrary(name)
    if name ~= variables.reset then
        for name in listitem(name) do
            commands.uselibrary(name,patterns,function(name,foundname)
             -- context.startnointerference()
                context.startreadingfile()
                context.input(foundname)
                status_symbols("loaded: library '%s'",name)
                context.stopreadingfile()
             -- context.stopnointerference()
            end, function(name)
                report_symbols("unknown: library '%s'",name)
            end)
        end
    end
end

commands.usesymbols = symbols.uselibrary
