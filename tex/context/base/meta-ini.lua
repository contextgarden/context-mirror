if not modules then modules = { } end modules ['meta-ini'] = {
    version   = 1.001,
    comment   = "companion to meta-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local format, gmatch, match, gsub = string.format, string.gmatch, string.match, string.gsub

metapost = metapost or { }

-- for the moment downward compatible

local report_metapost = logs.reporter ("metapost")
local status_metapost = logs.messenger("metapost")

local patterns = { "meta-imp-%s.mkiv", "meta-imp-%s.tex", "meta-%s.mkiv", "meta-%s.tex" } -- we are compatible

local function action(name,foundname)
    status_metapost("loaded: library '%s'",name)
    context.startreadingfile()
    context.input(foundname)
    context.stopreadingfile()
end

local function failure(name)
    report_metapost("unknown: library '%s'",name)
end

function commands.useMPlibrary(name)
    commands.uselibrary {
        name     = name,
        patterns = patterns,
        action   = action,
        failure  = failure,
        onlyonce = true,
    }
end

-- experimental

local colorhash = attributes.list[attributes.private('color')]

local validdimen = lpeg.patterns.validdimen * lpeg.P(-1)

local lpegmatch = lpeg.match
local textype   = tex.type
local MPcolor   = context.MPcolor

function commands.prepareMPvariable(v) -- slow but ok
    if v == "" then
        MPcolor("black")
    else
        local typ, var = match(v,"(.):(.*)")
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

function metapost.formatnumber(f,n) -- just lua format
    f = gsub(f,"@(%d)","%%.%1")
    f = gsub(f,"@","%%")
    f = format(f,tonumber(n) or 0)
    f = gsub(f,"e([%+%-%d]+)",function(s)
        return format("\\times10^{%s}",tonumber(s) or s) -- strips leading zeros
    end)
    context.mathematics(f)
end
