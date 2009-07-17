if not modules then modules = { } end modules ['mlib-ctx'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- todo

local format, join = string.format, table.concat
local sprint = tex.sprint

metapost = metapost or {}
metapost.defaultformat = "metafun"

function metapost.graphic(instance,mpsformat,str,preamble,askedfig)
    local mpx = metapost.format(instance,mpsformat or metapost.defaultformat)
    metapost.graphic_base_pass(mpx,str,preamble,askedfig)
end

function metapost.filterclippath(result)
    if result then
        local figures = result.fig
        if figures and #figures > 0 then
            local figure = figures[1]
            local objects = figure:objects()
            if objects then
                for o=1,#objects do
                    local object = objects[o]
                    if object.type == "start_clip" then
                        return join(metapost.flushnormalpath(object.path,{ }),"\n")
                    end
                end
            end
        end
    end
    return ""
end

statistics.register("metapost processing time", function()
    local n =  metapost.n
    if n > 0 then
        local e = metapost.externals.n
        local str = format("%s seconds, loading: %s seconds, execution: %s seconds, n: %s",
            statistics.elapsedtime(metapost), statistics.elapsedtime(mplib),
            statistics.elapsedtime(metapost.exectime), n)
        if e > 0 then
            return format("%s, external: %s seconds (%s calls)", str, statistics.elapsedtime(metapost.externals), e)
        else
            return str
        end
    else
        return nil
    end
end)
