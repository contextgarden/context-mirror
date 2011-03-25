if not modules then modules = { } end modules ['scrn-but'] = {
    version   = 1.001,
    comment   = "companion to scrn-but.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

function commands.registerbuttons(tag,register,language)
    local data = sorters.definitions[language]
    local orders = daya and data.orders or sorters.definitions.default.orders
    local tag = tag == "" and { "" } or { tag }
    for i=1,#orders do
        local order = orders[i]
        context.menubutton(tag,format("%s:%s",register,order),order)
    end
end
