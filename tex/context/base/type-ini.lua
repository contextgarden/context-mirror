if not modules then modules = { } end modules ['type-ini'] = {
    version   = 1.001,
    comment   = "companion to type-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- more code will move here

local format, gsub = string.format, string.gsub

local patterns = { "type-imp-%s.mkiv", "type-imp-%s.tex", "type-%s.mkiv", "type-%s.tex" }

function commands.doprocesstypescriptfile(name)
    name = gsub(name,"^type%-","")
    for i=1,#patterns do
        local filename = format(patterns[i],name)
        local foundname = resolvers.finders.doreadfile("any",".",filename)
        if foundname ~= "" then
            context.startreadingfile()
            context.pushendofline()
            context.unprotect()
            context.input(foundname)
            context.protect()
            context.popendofline()
            context.stopreadingfile()
            return
        end
    end
end
