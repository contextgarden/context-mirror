if not modules then modules = { } end modules ['mlib-ctx'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- todo

local format, concat = string.format, table.concat
local sprint = tex.sprint

local report_metapost = logs.reporter("metapost")

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

local mplib = mplib

metapost       = metapost or {}
local metapost = metapost

metapost.defaultformat = "metafun"

function metapost.graphic(instance,mpsformat,str,initializations,preamble,askedfig)
    local mpx = metapost.format(instance,mpsformat or metapost.defaultformat)
    metapost.graphic_base_pass(mpx,str,initializations,preamble,askedfig)
end

function metapost.getclippath(instance,mpsformat,data,initializations,preamble)
    local mpx = metapost.format(instance,mpsformat or metapost.defaultformat)
    if mpx and data then
        starttiming(metapost)
        starttiming(metapost.exectime)
        local result = mpx:execute(format("%s;beginfig(1);%s;%s;endfig;",preamble or "",initializations or "",data))
        stoptiming(metapost.exectime)
        if result.status > 0 then
            report_metapost("%s: %s", result.status, result.error or result.term or result.log)
            result = nil
        else
            result = metapost.filterclippath(result)
        end
        stoptiming(metapost)
        return result
    end
end

function metapost.filterclippath(result)
    if result then
        local figures = result.fig
        if figures and #figures > 0 then
            local figure = figures[1]
            local objects = figure:objects()
            if objects then
                local lastclippath
                for o=1,#objects do
                    local object = objects[o]
                    if object.type == "start_clip" then
                        lastclippath = object.path
                    end
                end
                return lastclippath
            end
        end
    end
end

function metapost.theclippath(...)
    local result = metapost.getclippath(...)
    if result then -- we could just print the table
        result = concat(metapost.flushnormalpath(result),"\n")
        sprint(result)
    end
end

statistics.register("metapost processing time", function()
    local n =  metapost.n
    if n and n > 0 then
        local e, t = metapost.makempy.nofconverted, statistics.elapsedtime
        local str = format("%s seconds, loading: %s seconds, execution: %s seconds, n: %s",
            t(metapost), t(mplib), t(metapost.exectime), n)
        if e > 0 then
            return format("%s, external: %s seconds (%s calls)", str, t(metapost.makempy), e)
        else
            return str
        end
    else
        return nil
    end
end)

-- only used in graphictexts

metapost.tex = metapost.tex or { }

local environments = { }

function metapost.tex.set(str)
    environments[#environments+1] = str
end
function metapost.tex.reset()
    environments = { }
end
function metapost.tex.get()
    return concat(environments,"\n")
end
