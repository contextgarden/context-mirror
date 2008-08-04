if not modules then modules = { } end modules ['supp-fil'] = {
    version   = 1.001,
    comment   = "companion to supp-fil.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

commands                   = commands or { }
commands.trace_prepfiles   = false

local list, suffix, islocal, found = { }, "prep", false, false

function commands.loadctxpreplist()
    local ctlname = file.replacesuffix(tex.jobname,"ctl")
    if lfs.isfile(ctlname) then
        local x = xml.load(ctlname)
        if x then
            islocal = xml.found(x,"ctx:preplist[@local=='yes']")
            if commands.trace_prepfiles then
                if islocal then
                    ctx.writestatus("systems","loading ctx log file (local)") -- todo: m!systems
                else
                    ctx.writestatus("systems","loading ctx log file (specified)") -- todo: m!systems
                end
            end
            for r, d, k in xml.elements(x,"ctx:prepfile") do
                local dk = d[k]
                local name = xml.content(dk)
                if islocal then
                    name = file.basename(name)
                end
                local done = dk.at['done'] or 'no'
                if commands.trace_prepfiles then
                    ctx.writestatus("systems","registering %s -> %s",done)
                end
                found = true
                list[name] = done -- 'yes' or 'no'
            end
        end
    end
end

local function resolve(name)
    local function found(name)
        local prepname = name .. "." .. suffix
        local done = list[name]
        if done then
            if lfs.isfile(prepname) then
                if commands.trace_prepfiles then
                    ctx.writestatus("systems", "preprocessing: using %s",prepname)
                end
                return prepname
            end
        end
        return false
    end
    local filename = file.collapse_path(name)
    local prepname = islocal and found(file.basename(name))
    if prepname then
        return prepname
    end
    local prepname = found(filename)
    if prepname then
        return prepname
    end
    return false
end

--~ support.doiffileexistelse(name)

local processfile       = commands.processfile
local doifinputfileelse = commands.doifinputfileelse

function commands.processfile(name,depth)
    local prepname = found and resolve(name)
    if prepname then
        return processfile(prepname,0)
    end
    return processfile(name,depth)
end

function commands.doifinputfileelse(name,depth)
    local prepname = found and resolve(name)
    if prepname then
        return doifinputfileelse(prepname,0)
    end
    return doifinputfileelse(name,depth)
end

function commands.preparedfile(name)
    return (found and resolve(name)) or name
end
