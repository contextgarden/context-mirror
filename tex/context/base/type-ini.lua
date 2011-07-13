if not modules then modules = { } end modules ['type-ini'] = {
    version   = 1.001,
    comment   = "companion to type-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- more code will move here

local gsub = string.gsub

local patterns = { "type-imp-%s.mkiv", "type-imp-%s.tex", "type-%s.mkiv", "type-%s.tex" }

local function action(name,foundname)
    context.startreadingfile()
    context.pushendofline()
    context.unprotect()
    context.input(foundname)
    context.protect()
    context.popendofline()
    context.stopreadingfile()
end

function commands.doprocesstypescriptfile(name)
    commands.uselibrary {
        name     = gsub(name,"^type%-",""),
        patterns = patterns,
        action   = action,
    }
end


