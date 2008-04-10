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

function metapost.graphic(mpsformat,str,preamble)
    local mpx = metapost.format(mpsformat or metapost.defaultformat)
    metapost.graphic_base_pass(mpx,str,preamble)
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
                        return join(flushnormalpath(object.path,{ }),"\n")
                    end
                end
            end
        end
    end
    return ""
end
