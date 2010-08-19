if not modules then modules = { } end modules ['meta-fun'] = {
    version   = 1.001,
    comment   = "companion to meta-fun.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- very experimental, actually a joke ... see metafun manual for usage

local format, loadstring, type = string.format, loadstring, type
local texwrite = tex.write

local metapost = metapost

metapost.metafun = metapost.metafun or { }
local metafun    = metapost.metafun

function metafun.topath(t,connector)
    texwrite("(")
    if #t > 0 then
        for i=1,#t do
            if i > 1 then
                texwrite(connector or "..")
            end
            local ti = t[i]
            if type(ti) == "string" then
                texwrite(ti)
            else
                texwrite(format("(%s,%s)",ti.x or ti[1] or 0,ti.y or ti[2] or 0))
            end
        end
    else
        texwrite("origin")
    end
    texwrite(")")
end

function metafun.interpolate(f,b,e,s,c)
    local done = false
    texwrite("(")
    for i=b,e,(e-b)/s do
        local d = loadstring(format("return function(x) return %s end",f))
        if d then
            d = d()
            if done then
                texwrite(c or "...")
            else
                done = true
            end
            texwrite(format("(%s,%s)",i,d(i)))
        end
    end
    if not done then
        texwrite("origin")
    end
    texwrite(")")
end
