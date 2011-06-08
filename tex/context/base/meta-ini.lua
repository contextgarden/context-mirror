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

local report_metapost    = logs.reporter ("metapost")
local status_metapost = logs.messenger("metapost")

local patterns = { "meta-imp-%s.mkiv", "meta-imp-%s.tex", "meta-%s.mkiv", "meta-%s.tex" } -- we are compatible

function metapost.uselibrary(name)
    commands.uselibrary(name,patterns,function(name,foundname)
        context.startreadingfile()
        status_metapost("loaded: library '%s'",name)
        context.input(foundname)
        context.stopreadingfile()
    end, function(name)
        report_metapost("unknown: library '%s'",name)
    end)
end

-- experimental

local colorhash = attributes.list[attributes.private('color')]

local validdimen = lpeg.patterns.validdimen * lpeg.P(-1)

local lpegmatch = lpeg.match
local gmatch    = string.gmatch
local textype   = tex.type
local MPcolor   = context.MPcolor

function commands.prepareMPvariable(v) -- slow but ok
    if v == "" then
        MPcolor("black")
    else
        local typ, var = string.match(v,"(.):(.*)")
        if not typ then
            -- parse
            if colorhash[v] then
                MPcolor(v)
            elseif tonumber(v) then
                context(v)
            elseif lpegmatch(validdimen,v) then
                return context("\\the\\dimexpr %s",v)
            else
                for s in gmatch(v,"\\(.-)") do
                    local t = textype(s)
                    if t == "dimen" then
                        return context("\\the\\dimexpr %s",v)
                    elseif t == "count" then
                        return context("\\the\\numexpr %s",v)
                    end
                end
                return context("\\number %s",v) -- 0.4 ...
            end
        elseif typ == "d" then
            -- dimension
            context("\\the\\dimexpr %s",var)
        elseif typ == "n" then
            -- number
            context("\\the\\numexpr %s",var)
        elseif typ == "s" then
            -- string
            context(var)
        elseif typ == "c" then
            -- color
            MPcolor(var)
        else
            context(var)
        end
    end
end
