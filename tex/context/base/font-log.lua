if not modules then modules = { } end modules ['font-log'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, format, lower, concat = next, string.format, string.lower, table.concat

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

local report_defining = logs.reporter("fonts","defining")

local fonts  = fonts
fonts.logger = fonts.logger or { }
local logger = fonts.logger

--[[ldx--
<p>The following functions are used for reporting about the fonts
used. The message itself is not that useful in regular runs but since
we now have several readers it may be handy to know what reader is
used for which font.</p>
--ldx]]--

function logger.save(tfmtable,source,specification) -- save file name in spec here ! ! ! ! ! !
    if tfmtable and specification and specification.specification then
        local name = lower(specification.name)
        if trace_defining and not fonts.used[name] then
            report_defining("registering %s as %s (used: %s)",file.basename(specification.name),source,file.basename(specification.filename))
        end
        specification.source = source
        fonts.loaded[lower(specification.specification)] = specification
     -- fonts.used[name] = source
        fonts.used[lower(specification.filename or specification.name)] = source
    end
end

function logger.report(complete)
    local t, n = { }, 0
    for name, used in table.sortedhash(fonts.used) do
        n = n + 1
        if complete then
            t[n] = used .. "->" .. file.basename(name)
        else
            t[n] = file.basename(name)
        end
    end
    return t
end

function logger.format(name)
    return fonts.used[name] or "unknown"
end

statistics.register("loaded fonts", function()
    if next(fonts.used) then
        local t = logger.report()
        return (#t > 0 and format("%s files: %s",#t,concat(t," "))) or "none"
    else
        return nil
    end
end)
