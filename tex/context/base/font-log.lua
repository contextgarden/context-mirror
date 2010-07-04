if not modules then modules = { } end modules ['font-log'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, format, lower, concat = next, string.format, string.lower, table.concat

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

fonts.logger = fonts.logger or { }

--[[ldx--
<p>The following functions are used for reporting about the fonts
used. The message itself is not that useful in regular runs but since
we now have several readers it may be handy to know what reader is
used for which font.</p>
--ldx]]--

function fonts.logger.save(tfmtable,source,specification) -- save file name in spec here ! ! ! ! ! !
    if tfmtable and specification and specification.specification then
        local name = lower(specification.name)
        if trace_defining and not fonts.used[name] then
            logs.report("define font","registering %s as %s (used: %s)",file.basename(specification.name),source,file.basename(specification.filename))
        end
        specification.source = source
        fonts.loaded[lower(specification.specification)] = specification
     -- fonts.used[name] = source
        fonts.used[lower(specification.filename or specification.name)] = source
    end
end

function fonts.logger.report(complete)
    local t = { }
    for name, used in table.sortedhash(fonts.used) do
        if complete then
            t[#t+1] = used .. "->" .. file.basename(name)
        else
            t[#t+1] = file.basename(name)
        end
    end
    return t
end

function fonts.logger.format(name)
    return fonts.used[name] or "unknown"
end

statistics.register("loaded fonts", function()
    if next(fonts.used) then
        local t = fonts.logger.report()
        return (#t > 0 and format("%s files: %s",#t,concat(t,separator or " "))) or "none"
    else
        return nil
    end
end)
