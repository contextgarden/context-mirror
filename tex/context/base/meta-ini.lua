if not modules then modules = { } end modules ['meta-ini'] = {
    version   = 1.001,
    comment   = "companion to meta-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

metapost = metapost or { }

-- for the moment downward compatible

local patterns = { "meta-imp-%s.mkiv", "meta-imp-%s.tex", "meta-%s.mkiv", "meta-%s.tex" } -- we are compatible

function metapost.uselibrary(name)
    commands.uselibrary(name,patterns,function(name,foundname)
        context.startreadingfile()
        context.showmessage("metapost",1,name)
        context.input(foundname)
        context.stopreadingfile()
    end)
end
